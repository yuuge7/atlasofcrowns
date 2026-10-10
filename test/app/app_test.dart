import 'dart:convert';
import 'dart:io';

import 'package:atlasofcrowns/data/game_assets.dart';
import 'package:atlasofcrowns/data/save_store.dart';
import 'package:atlasofcrowns/engine/game.dart';
import 'package:atlasofcrowns/engine/orders.dart';
import 'package:atlasofcrowns/engine/rules.dart';
import 'package:atlasofcrowns/engine/world.dart';
import 'package:atlasofcrowns/game/game_controller.dart';
import 'package:atlasofcrowns/map/map_camera.dart';
import 'package:atlasofcrowns/map/map_geometry.dart';
import 'package:atlasofcrowns/map/map_scene.dart';
import 'package:atlasofcrowns/map/map_view.dart';
import 'package:atlasofcrowns/theme.dart';
import 'package:atlasofcrowns/ui/main_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

GameAssets loadAssets() {
  final map = jsonDecode(File('assets/map/europe.json').readAsStringSync()) as Map<String, dynamic>;
  final scenario = jsonDecode(File('assets/scenarios/1914.json').readAsStringSync()) as Map<String, dynamic>;
  return GameAssets(World.fromJson(map, scenario), MapGeometry.fromJson(map));
}

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

  GameController newController(String tag) =>
      GameController(assets: assets, saves: saves, game: Game.start(world, human: nation(tag), seed: 7));

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

      final loaded = await saves.load(id, world);
      expect(jsonEncode(loaded.game.toJson()), jsonEncode(game.toJson()));
      expect(loaded.orders.recruits.single.count, 2);

      await saves.delete(id);
      expect((await saves.list()).single.isAutosave, isTrue);
    });

    test('a damaged or missing save says so', () async {
      File('${temp.path}/broken.json').writeAsStringSync('{"game": 3');
      expect((await saves.list()), isEmpty);
      expect(() => saves.load('broken', world), throwsFormatException);
      expect(() => saves.load('nothing', world), throwsFormatException);
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

    await tester.tap(find.text('PLAY AS GERMANY'));
    await tester.pumpAndSettle();
    expect(find.text('END TURN'), findsOneWidget);
    expect(find.text('German Empire'), findsOneWidget);
    expect(find.text('Aug 1914, turn 1'), findsOneWidget);

    await tester.tap(find.text('END TURN'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Sep 1914, turn 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
