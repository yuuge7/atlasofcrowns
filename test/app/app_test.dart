import 'dart:convert';
import 'dart:io';

import 'package:atlasofcrowns/data/game_assets.dart';
import 'package:atlasofcrowns/data/save_store.dart';
import 'package:atlasofcrowns/engine/game.dart';
import 'package:atlasofcrowns/engine/happenings.dart';
import 'package:atlasofcrowns/engine/orders.dart';
import 'package:atlasofcrowns/engine/rules.dart';
import 'package:atlasofcrowns/engine/state.dart';
import 'package:atlasofcrowns/game/game_controller.dart';
import 'package:atlasofcrowns/map/map_camera.dart';
import 'package:atlasofcrowns/map/map_scene.dart';
import 'package:atlasofcrowns/map/map_view.dart';
import 'package:atlasofcrowns/theme.dart';
import 'package:atlasofcrowns/ui/main_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

GameAssets loadAssets() => GameAssets.read((path) => jsonDecode(File(path).readAsStringSync()));

void main() {
  final assets = loadAssets();
  final world = assets.world;
  final geometry = assets.geometry;
  int nation(String tag) => world.nations.firstWhere((n) => n.tag == tag).id;
  int province(String name) => world.provinces.firstWhere((p) => p.name == name).id;

  late Directory temp;
  late SaveStore saves;
  setUp(() {
    temp = Directory.systemTemp.createTempSync('atlas_saves');
    saves = SaveStore(directory: temp);
  });
  tearDown(() async {
    // Let an autosave still on its way to disk land before the folder goes.
    await saves.list().timeout(const Duration(seconds: 2), onTimeout: () => const []);
    try {
      temp.deleteSync(recursive: true);
    } on FileSystemException {
      // A write that started under the widget tester's fake clock may still
      // hold the folder; the OS clears its temp directory in time.
    }
  });

  GameController newController(String tag) => GameController(assets: assets, saves: saves, game: Game.start(world, human: nation(tag), seed: 7));

  group('map geometry', () {
    test('a tap on any province label finds that province', () {
      for (final p in geometry.provinces) {
        expect(geometry.provinceAt(p.label), p.id, reason: world.provinces[p.id].name);
      }
    });

    test('open sea is nobody', () {
      // Bay of Biscay.
      expect(geometry.provinceAt(Offset(geometry.size.width * 0.12, geometry.size.height * 0.72)), -1);
    });

    test('every sea link has a crossing to draw', () {
      final links = world.provinces.fold(0, (sum, p) => sum + p.sea.length) ~/ 2;
      expect(links, greaterThan(15));
      expect(geometry.crossings.length, links);
    });

    test('every border arc separates two different provinces', () {
      for (final arc in geometry.borders) {
        expect(arc.a, isNot(arc.b));
        expect(world.provinces[arc.a].adj, contains(arc.b));
      }
    });
  });

  group('camera', () {
    MapCamera camera() => MapCamera(const Size(2000, 2400))..setViewport(const Size(400, 800));

    test('starts zoomed out as far as the map still covers the screen', () {
      final c = camera();
      expect(c.scale, c.minScale);
      expect(c.minScale, closeTo(800 / 2400, 1e-9));
    });

    test('never shows past the edge of the map', () {
      final c = camera()..zoomAround(const Offset(200, 400), 2);
      c.panBy(const Offset(99999, 99999));
      expect(c.offset, Offset.zero);
      c.panBy(const Offset(-99999, -99999));
      expect(c.toMap(const Offset(400, 800)), const Offset(2000, 2400));
    });

    test('zooming keeps the point under the fingers in place', () {
      final c = camera()..zoomAround(const Offset(200, 400), 1);
      final before = c.toMap(const Offset(150, 300));
      c.zoomAround(const Offset(150, 300), 3);
      expect((c.toMap(const Offset(150, 300)) - before).distance, lessThan(1e-6));
    });

    test('reveal brings a point out from under the HUD', () {
      final c = camera()
        ..zoomAround(const Offset(200, 400), 2)
        ..setInsets(top: 100, bottom: 300);
      const point = Offset(1000, 2390);
      c.centerOn(const Offset(1000, 400));
      c.reveal(point);
      final at = c.toScreen(point);
      expect(at.dy, lessThanOrEqualTo(800 - 300));
      expect(at.dy, greaterThanOrEqualTo(100));
    });
  });

  group('orders', () {
    test('recruiting spends the free gold and respects the province cap', () {
      final c = newController('GER');
      final berlin = province('Berlin');
      final gold = c.goldFree;
      c.tapProvince(berlin);
      c.beginRecruit();
      expect(c.mode, InputMode.recruitAmount);
      c.confirmRecruit(5);
      c.tapProvince(berlin);
      c.beginRecruit();
      c.confirmRecruit(999);
      expect(c.orders.recruits.single.count, c.game.recruitCap(berlin));
      expect(c.goldFree, gold - c.game.recruitCap(berlin) * Rules.unitCost);
      expect(c.recruitRoom(berlin), 0);
      expect(c.overlay.recruits[berlin], c.game.recruitCap(berlin));
    });

    test('nothing can be raised in a province of someone else', () {
      final c = newController('GER');
      final paris = province('Paris');
      expect(c.recruitRoom(paris), 0);
      c.tapProvince(paris);
      c.beginRecruit();
      expect(c.mode, InputMode.browse);
      c.confirmRecruit(3);
      expect(c.orders.recruits, isEmpty);
    });

    test('a move goes source, target, amount, and can be cancelled', () {
      final c = newController('GER');
      final posen = province('Posen');
      final lodz = province('Łódź');
      final units = c.state.units[posen];
      c.tapProvince(posen);
      c.beginMove();
      expect(c.overlay.targets, contains(lodz));
      expect(c.overlay.targets, isNot(contains(province('Paris'))));
      c.tapProvince(lodz);
      expect(c.mode, InputMode.moveAmount);
      c.confirmMove(4);
      expect(c.movable(posen), units - 4);
      expect(c.overlay.arrows.single.hostile, isTrue);
      expect(c.overlay.units![posen], units - 4);
      c.cancelMove(c.orders.moves.single);
      expect(c.movable(posen), units);
    });

    test('coasts across the sea are offered apart from the land targets', () {
      final c = newController('UKG');
      final london = province('London');
      c.tapProvince(london);
      c.beginMove();
      expect(c.overlay.landings, isNotEmpty);
      expect(c.overlay.landings.intersection(c.overlay.targets), isEmpty);
      final hamburg = province('Hamburg');
      expect(c.overlay.landings, contains(hamburg), reason: 'London and Hamburg share the North Sea');
      c.tapProvince(hamburg);
      expect(c.mode, InputMode.moveAmount);
      c.confirmMove(5);
      expect(c.overlay.arrows.single.naval, isTrue);
    });

    test('provinces of a nation at peace are not offered as targets', () {
      final c = newController('GER');
      final hamburg = province('Hamburg');
      c.tapProvince(hamburg);
      c.beginMove();
      expect(c.overlay.targets, isNot(contains(province('Aarhus'))));
    });

    test('ending the turn resolves the orders and clears them', () {
      final c = newController('GER');
      final berlin = province('Berlin');
      final before = c.state.units[berlin];
      c.tapProvince(berlin);
      c.beginRecruit();
      c.confirmRecruit(3);
      final report = c.endTurn();
      expect(report.turn, 0);
      expect(c.state.turn, 1);
      expect(c.orders.isEmpty, isTrue);
      expect(c.state.units[berlin], greaterThanOrEqualTo(before + 3));
      expect(c.lastReport, same(report));
    });

    test('a fort is ordered once per province and paid from the free gold', () {
      final c = newController('GER');
      final berlin = province('Berlin');
      final gold = c.goldFree;
      c.tapProvince(berlin);
      c.beginBuild();
      expect(c.mode, InputMode.build);
      final cost = c.game.buildCost(berlin, Project.fortify);
      c.orderBuild(Project.fortify);
      expect(c.mode, InputMode.browse);
      expect(c.goldFree, gold - cost);
      expect(c.canBuild(berlin, Project.develop), isFalse);
      c.beginBuild();
      expect(c.mode, InputMode.browse);
      c.cancelBuild(c.buildAt(berlin)!);
      expect(c.goldFree, gold);
      c.tapProvince(province('Paris'));
      c.beginBuild();
      expect(c.mode, InputMode.browse);
    });

    test('alliances are offered and left from the controller', () {
      final c = newController('GER');
      final austria = nation('AUS');
      final denmark = nation('DEN');
      expect(c.game.allied(c.human, austria), isTrue);
      c.setAllianceOffered(austria, true);
      expect(c.orders.offerAlliance, isEmpty);
      c.setAllianceOffered(denmark, true);
      expect(c.orders.offerAlliance, {denmark});
      c.setAllianceBroken(denmark, true);
      expect(c.orders.breakAlliance, isEmpty);
      c.setAllianceBroken(austria, true);
      expect(c.orders.breakAlliance, {austria});
    });

    test('a research plan is a change to the standing one, or nothing', () {
      final c = newController('GER');
      final field = c.researchField;
      final share = c.researchShare;
      final other = Field.values.firstWhere((f) => f != field);
      final gold = c.goldFree;
      c.setResearch(other, 30);
      expect(c.orders.research?.field, other);
      expect(c.researchSpend, c.income * 30 ~/ 100);
      expect(c.goldFree, gold, reason: 'research is paid at the end of the turn, from what is left');
      c.setResearch(field, share);
      expect(c.orders.research, isNull);
      c.setResearch(field, 7);
      expect(c.orders.research, isNull);
      c.setResearch(Field.industry, 20);
      c.endTurn();
      expect(c.game.state.researchShare[c.human], 20);
      expect(c.researchField, Field.industry);
    });

    test('fog of war hides the armies far from the player', () {
      final game = Game.start(world, human: nation('GER'), seed: 1, fog: true);
      final c = GameController(assets: assets, saves: saves, game: game);
      final paris = province('Paris');
      final posen = province('Posen');
      final prague = province('Prague');
      expect(c.canSee(paris), isFalse);
      expect(c.overlay.units![paris], -1);
      expect(c.canSee(posen), isTrue);
      expect(c.canSee(prague), isTrue, reason: 'Austria-Hungary is an ally');
      expect(c.overlay.units![prague], c.state.units[prague]);
      expect(newController('GER').canSee(paris), isTrue);
      expect(c.unitsSeen(paris), isNull);
      expect(c.armyOf(nation('FRA')), isNull);
      expect(c.armyOf(nation('AUS')), c.game.unitsOf(nation('AUS')));
      expect(c.armyOf(nation('GER')), c.game.unitsOf(nation('GER')));
    });

    test('map modes recolour the land and keep the borders', () {
      final c = newController('GER');
      final berlin = province('Berlin');
      final paris = province('Paris');
      final prague = province('Prague');
      expect(c.scene.lettered, isTrue);
      c.setMapMode(MapMode.diplomacy);
      expect(c.scene.lettered, isFalse);
      expect(c.scene.fillOf(berlin), AtlasColors.mapYou);
      expect(c.scene.fillOf(paris), AtlasColors.mapEnemy);
      expect(c.scene.fillOf(prague), AtlasColors.mapAlly);
      c.setMapMode(MapMode.relations);
      expect(c.scene.fillOf(berlin), AtlasColors.mapYou);
      expect(c.scene.fillOf(prague), relationColor(Rules.alliedRelation));
      expect(c.scene.fillOf(paris), relationColor(Rules.warRelation));
      c.setMapMode(MapMode.economy);
      expect(c.scene.fillOf(berlin), incomeColor(c.game.provinceIncome(berlin)));
      c.setMapMode(MapMode.political);
      expect(c.scene.fillOf(berlin), Color(world.nations[nation('GER')].color));
    });

    test('a turn is replayed over the position before it, then shown as it stands', () {
      final c = newController('GER');
      final before = List.of(c.state.owner);
      final berlin = province('Berlin');
      final units = c.state.units[berlin];
      c.tapProvince(berlin);
      c.beginMove();
      c.tapProvince(c.targetsFrom(berlin).first);
      c.confirmMove(5);
      c.endTurn();
      final replay = c.replay!;
      expect(replay.owners, before);
      expect(replay.units[berlin], units - 5);
      expect(replay.movements.where((m) => m.from == berlin && m.count == 5), isNotEmpty);
      expect(c.scene.owners, before);
      expect(c.overlay.movements, same(replay.movements));
      expect(c.overlay.arrows, isEmpty);
      c.setReplay(march: 0.5, battle: 1);
      expect(c.overlay.march, 0.5);
      c.endReplay();
      expect(c.replay, isNull);
      expect(c.scene.owners, c.state.owner);
      expect(c.overlay.movements, isEmpty);
      expect(c.overlay.units![berlin], c.state.units[berlin]);
    });

    test('a march walks one province a turn to a far province of yours', () {
      final c = newController('GER');
      final berlin = province('Berlin');
      final munich = province('Munich');
      final path = c.game.pathThroughOwnLand(c.human, berlin, munich)!;
      expect(path.first, berlin);
      expect(path.last, munich);
      expect(path.length, greaterThan(2));
      final before = c.state.units[munich];

      c.tapProvince(berlin);
      c.beginMove();
      expect(c.overlay.targets, isNot(contains(munich)));
      c.tapProvince(munich);
      expect(c.mode, InputMode.moveAmount);
      expect(c.canMarch(berlin, munich), isTrue);
      c.confirmMove(5);
      expect(c.marches, hasLength(1));
      expect(c.orders.moves.single.to, path[1]);
      expect(c.overlay.marches.single.last, munich);

      for (var turn = 1; turn < path.length; turn++) {
        c.endTurn();
        if (turn < path.length - 1) {
          expect(c.marches.single.at, path[turn]);
          expect(c.orders.moves.single.from, path[turn]);
        }
      }
      expect(c.marches, isEmpty);
      expect(c.orders.moves, isEmpty);
      expect(c.state.units[munich], greaterThanOrEqualTo(before + 5));
    });

    test('cancelling its step calls the march off', () {
      final c = newController('GER');
      c.tapProvince(province('Berlin'));
      c.beginMove();
      c.tapProvince(province('Munich'));
      c.confirmMove(3);
      c.cancelMove(c.orders.moves.single);
      expect(c.marches, isEmpty);
      c.endTurn();
      expect(c.orders.moves, isEmpty);
    });

    test('a march survives a save', () async {
      final c = newController('GER');
      c.tapProvince(province('Berlin'));
      c.beginMove();
      c.tapProvince(province('Munich'));
      c.confirmMove(4);
      await c.autosave();
      final loaded = await saves.load(SaveStore.autosaveId, assets);
      final back = GameController(assets: assets, saves: saves, game: loaded.game, orders: loaded.orders, marches: loaded.marches);
      expect(back.marches.single.to, province('Munich'));
      expect(back.marchOf(back.orders.moves.single), same(back.marches.single));
    });

    test('peace is offered on terms, and an offer with demands is accepted as it stands', () {
      final c = newController('GER');
      final france = nation('FRA');
      c.offerPeace(france, Terms.reparations);
      expect(c.orders.offerPeace, {france});
      expect(c.orders.peaceTerms[france], Terms.reparations);
      c.offerPeace(france, null);
      expect(c.orders.offerPeace, isEmpty);
      expect(c.orders.peaceTerms, isEmpty);
      c.state.peaceOffers[directedKey(france, c.human)] = c.state.turn + 2;
      c.state.peaceTerms[directedKey(france, c.human)] = Terms.vassal.index;
      c.setPeaceOffered(france, true);
      expect(c.orders.peaceTerms[france], Terms.accept);
    });

    test('envoys, gifts and pacts are ordered from the diplomacy sheet and paid from the free gold', () {
      final c = newController('GER');
      final denmark = nation('DEN');
      final france = nation('FRA');
      final free = c.goldFree;
      c.setEnvoy(denmark, true);
      expect(c.goldFree, free - c.game.envoyCost(denmark));
      c.setEnvoy(france, true);
      expect(c.orders.envoys, {denmark}, reason: 'no envoys to an enemy');
      c.setGift(denmark, 30);
      expect(c.goldFree, free - c.game.envoyCost(denmark) - 30);
      c.setGift(denmark, 1 << 20);
      expect(c.goldFree, 0, reason: 'a gift is capped by the free gold');
      c.setGift(denmark, 0);
      expect(c.orders.gifts, isEmpty);
      c.setPactOffered(denmark, true);
      expect(c.orders.offerPact, {denmark});
      c.setPactOffered(france, true);
      expect(c.orders.offerPact, {denmark});
      c.endTurn();
      expect(c.state.relation(c.human, denmark), greaterThanOrEqualTo(Rules.envoyGain - 1));
    });

    test('a happening waits for an answer, which sets its gold aside', () {
      final c = newController('GER');
      final berlin = province('Berlin');
      c.state.pending[c.human] = encodePending(Happening.strike, berlin);
      expect(c.pendingHappening, (Happening.strike, berlin));
      final free = c.goldFree;
      c.answerHappening(0);
      expect(c.orders.answer, 0);
      expect(c.goldFree, free - c.game.provinceIncome(berlin) * 3);
      c.answerHappening(1);
      expect(c.goldFree, free);
      c.endTurn();
      expect(c.pendingHappening, isNull);
      expect(c.orders.answer, isNull);
    });

    test('war is declared from the province sheet and can be called off', () {
      final c = newController('GER');
      final denmark = nation('DEN');
      c.setWarDeclared(denmark, true);
      expect(c.orders.declareWar, {denmark});
      c.setWarDeclared(denmark, false);
      expect(c.orders.declareWar, isEmpty);
      // Already at war: nothing to declare.
      c.setWarDeclared(nation('FRA'), true);
      expect(c.orders.declareWar, isEmpty);
    });
  });

  group('saves', () {
    test('a game comes back as it was saved, orders included', () async {
      final game = Game.start(world, human: nation('FRA'), seed: 5);
      for (var i = 0; i < 4; i++) {
        game.endTurn(null);
      }
      final orders = Orders()..recruits.add(RecruitOrder(province('Paris'), 2));
      await saves.autosave(game, orders);
      final id = await saves.saveNew(game, orders);

      final list = await saves.list();
      expect(list.map((s) => s.id), unorderedEquals([SaveStore.autosaveId, id]));
      expect(list.first.turn, 4);
      expect(list.first.date, 'Dec 1914');
      expect(list.first.nation, nation('FRA'));

      final loaded = await saves.load(id, assets);
      expect(jsonEncode(loaded.game.toJson()), jsonEncode(game.toJson()));
      expect(loaded.orders.recruits.single.count, 2);

      await saves.delete(id);
      expect((await saves.list()).single.isAutosave, isTrue);
    });

    test('a save opens in the scenario it was made in', () async {
      final modern = assets.scenario('modern');
      final game = Game.start(modern, human: 1, seed: 5);
      game.endTurn(null);
      final id = await saves.saveNew(game, Orders());
      final info = (await saves.list()).single;
      expect(info.scenario, 'modern');
      final loaded = await saves.load(id, assets);
      expect(loaded.game.world, same(modern));
      expect(() => assets.scenario('1066'), throwsFormatException);
    });

    test('a damaged or missing save says so', () async {
      File('${temp.path}/broken.json').writeAsStringSync('{"game": 3');
      expect((await saves.list()), isEmpty);
      expect(() => saves.load('broken', assets), throwsFormatException);
      expect(() => saves.load('nothing', assets), throwsFormatException);
    });

    test('ending a turn autosaves', () async {
      final c = newController('ITA');
      c.endTurn();
      final list = await saves.list();
      expect(list.single.isAutosave, isTrue);
      expect(list.single.turn, 1);
    });
  });

  testWidgets('the map pans with one finger, zooms with two and reports taps', (tester) async {
    await tester.binding.setSurfaceSize(const Size(411, 914));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final scene = MapScene(geometry, world)..setOwners(world.startOwners);
    final camera = MapCamera(geometry.size);
    final berlin = province('Berlin');
    final taps = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: MapView(scene: scene, camera: camera, onTapProvince: taps.add, initialFocus: geometry.provinces[berlin].label, initialZoom: 3),
    ));
    final centre = tester.getCenter(find.byType(MapView));
    expect((camera.toScreen(geometry.provinces[berlin].label) - centre).distance, lessThan(1));

    await tester.tapAt(centre);
    expect(taps, [berlin]);

    final before = camera.offset;
    await tester.dragFrom(centre, const Offset(-60, 40));
    await tester.pumpAndSettle();
    expect(camera.offset.dx, lessThan(before.dx - 30));
    expect(camera.offset.dy, greaterThan(before.dy + 20));

    final zoom = camera.scale;
    final left = await tester.startGesture(centre - const Offset(40, 0));
    final right = await tester.startGesture(centre + const Offset(40, 0));
    await left.moveBy(const Offset(-50, 0));
    await right.moveBy(const Offset(50, 0));
    await tester.pump();
    await left.up();
    await right.up();
    await tester.pumpAndSettle();
    // The first few pixels of a pinch are spent telling it from a tap.
    expect(camera.scale, greaterThan(zoom * 1.3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('from the title screen into a game', (tester) async {
    await tester.binding.setSurfaceSize(const Size(411, 914));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(theme: buildAtlasTheme(), home: MainMenu(assets: assets, saves: saves)));
    expect(find.text('ATLAS'), findsOneWidget);

    await tester.tap(find.text('NEW GAME'));
    await tester.pumpAndSettle();
    expect(find.text('Choose your crown'), findsOneWidget);
    expect(find.text('PLAY AS GERMANY'), findsOneWidget);

    // Germany is in both scenarios and stays picked across the switch.
    await tester.tap(find.text('Europe today'));
    await tester.pumpAndSettle();
    expect(find.text('Federal Republic of Germany'), findsOneWidget);
    expect(find.text('PLAY AS GERMANY'), findsOneWidget);
    await tester.tap(find.text('The Great War'));
    await tester.pumpAndSettle();
    expect(find.text('German Empire'), findsOneWidget);

    await tester.tap(find.text('PLAY AS GERMANY'));
    await tester.pumpAndSettle();
    expect(find.text('END TURN'), findsOneWidget);
    // The full name, or the short one where the full one does not fit.
    expect(find.byWidgetPredicate((w) => w is Text && (w.data == 'German Empire' || w.data == 'Germany')), findsOneWidget);
    expect(find.text('Aug 1914, turn 1'), findsOneWidget);

    await tester.tap(find.text('END TURN'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Sep 1914, turn 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
