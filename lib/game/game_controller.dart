import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

import '../data/game_assets.dart';
import '../data/save_store.dart';
import '../engine/events.dart';
import '../engine/game.dart';
import '../engine/orders.dart';
import '../engine/rules.dart';
import '../engine/state.dart';
import '../engine/world.dart';
import '../map/map_camera.dart';
import '../map/map_painters.dart';
import '../map/map_scene.dart';
import '../theme.dart';

/// What a tap on the map means right now.
enum InputMode {
  /// Tapping selects a province.
  browse,

  /// A source is selected; tapping a highlighted province picks the target.
  pickTarget,

  /// Source and target are set; the sheet asks how many units to send.
  moveAmount,

  /// The sheet asks how many units to raise in the selected province.
  recruitAmount,

  /// The sheet offers what can be built in the selected province.
  build,
}

/// How the land is coloured.
enum MapMode {
  /// By owner.
  political,

  /// By how each nation stands with the player.
  diplomacy,

  /// By what each province yields.
  economy,
}

/// How a nation stands with the player, in the order the checks are made:
/// the player first, then an ally, an enemy, a truce, plain peace.
enum Relation {
  you(AtlasColors.mapYou, 'You'),
  ally(AtlasColors.mapAlly, 'Allies'),
  war(AtlasColors.mapEnemy, 'At war'),
  truce(AtlasColors.mapTruce, 'Truce'),
  peace(AtlasColors.mapNeutral, 'Peace');

  const Relation(this.color, this.legend);

  /// Fill on the diplomacy map.
  final Color color;

  /// What the map legend calls it.
  final String legend;
}

/// A standing order to walk [count] units from [at] to [to], one province a
/// turn through the player's own land. Each turn it becomes one ordinary
/// move, [step], which the player can cancel to call the march off.
class March {
  March(this.at, this.to, this.count);

  int at;
  final int to;
  int count;
  MoveOrder? step;

  /// The road from the end of [step] to [to].
  List<int> ahead = const [];

  List<int> toJson() => [at, to, count, step?.to ?? -1];
}

/// The player's side of a running game: the orders being written this turn,
/// what is selected, and what the map should show for it.
class GameController extends ChangeNotifier {
  GameController({required this.assets, required this.saves, required this.game, Orders? orders, List<List<int>> marches = const []})
      : orders = orders ?? Orders(),
        scene = MapScene(assets.geometry, game.world),
        camera = MapCamera(assets.geometry.size) {
    _newTurn();
    // A saved march finds this turn's step again among the saved orders.
    for (final [at, to, count, next] in marches) {
      final march = March(at, to, count)..step = this.orders.moves.where((m) => m.from == at && m.to == next).firstOrNull;
      if (march.step == null) continue;
      march.ahead = game.pathThroughOwnLand(human, next, to) ?? const [];
      this.marches.add(march);
    }
    _sync();
  }

  /// Marches under way.
  final List<March> marches = [];

  final GameAssets assets;
  final SaveStore saves;
  final Game game;
  final MapScene scene;
  final MapCamera camera;
  final MapOverlay overlay = MapOverlay();

  Orders orders;
  int selected = -1;
  MapMode mapMode = MapMode.political;
  InputMode mode = InputMode.browse;
  int moveTarget = -1;
  TurnReport? lastReport;

  /// Set when the last autosave could not be written.
  String? saveError;

  // Worked out once a turn: none of it changes with the orders.
  List<bool>? _sight;
  List<Color>? _fills;
  int _income = 0;
  int _upkeep = 0;
  int _army = 0;

  World get world => game.world;
  GameState get state => game.state;
  int get human => state.human;

  /// False once the player is out of the game and only watching.
  bool get commanding => human >= 0 && state.alive[human];

  // ------------------------------------------------------------ what the player sees

  /// Whether the player can see the army in [p]. Without fog of war, or
  /// once the player is only watching, every army is in sight.
  bool canSee(int p) => _sight?[p] ?? true;

  /// Units in [p] as far as the player knows, or null when fog hides them.
  int? unitsSeen(int p) => canSee(p) ? state.units[p] : null;

  /// The whole army of [nation] as far as the player knows: always without
  /// fog of war, and under it only for themselves and their allies.
  int? armyOf(int nation) => !state.fog || !commanding || nation == human || game.allied(human, nation) ? game.unitsOf(nation) : null;

  /// How [nation] stands with the player.
  Relation relationTo(int nation) {
    if (nation == human) return Relation.you;
    if (game.allied(human, nation)) return Relation.ally;
    if (game.atWar(human, nation)) return Relation.war;
    if (game.truceLeft(human, nation) > 0) return Relation.truce;
    return Relation.peace;
  }

  /// Map modes that make sense for this game.
  List<MapMode> get mapModes => [MapMode.political, if (commanding) MapMode.diplomacy, MapMode.economy];

  void setMapMode(MapMode mode) {
    mapMode = mode;
    _fills = _fillsFor(mode);
    _sync();
  }

  List<Color>? _fillsFor(MapMode mode) {
    switch (mode) {
      case MapMode.political:
        return null;
      case MapMode.diplomacy:
        final colors = [for (var n = 0; n < world.nations.length; n++) relationTo(n).color];
        return [for (final o in state.owner) colors[o]];
      case MapMode.economy:
        return [for (var p = 0; p < state.owner.length; p++) incomeColor(game.provinceIncome(p))];
    }
  }

  // ------------------------------------------------------------ treasury

  int get gold => commanding ? state.gold[human] : 0;

  /// Gold not yet promised to recruits or building ordered this turn.
  int get goldFree =>
      gold - orders.recruits.fold<int>(0, (sum, r) => sum + r.count * Rules.unitCost) - orders.builds.fold<int>(0, (sum, b) => sum + game.buildCost(b.province, b.project));

  int get income => _income;
  int get upkeep => _upkeep;

  /// Units in the player's whole army.
  int get army => _army;

  // ------------------------------------------------------------ armies

  /// Units already ordered out of [p] this turn.
  int leaving(int p) => orders.moves.where((m) => m.from == p).fold(0, (sum, m) => sum + m.count);

  /// Units in [p] still waiting for orders.
  int movable(int p) => state.owner[p] == human ? state.units[p] - leaving(p) : 0;

  /// Units already ordered into [p] this turn, from anywhere.
  int headingTo(int p) => orders.moves.where((m) => m.to == p).fold(0, (sum, m) => sum + m.count);

  int recruitsAt(int p) => orders.recruits.where((r) => r.province == p).fold(0, (sum, r) => sum + r.count);

  /// What is being built in [p] this turn, if anything.
  BuildOrder? buildAt(int p) => orders.builds.where((b) => b.province == p).firstOrNull;

  /// Whether [project] can be ordered in [p] with the gold left.
  bool canBuild(int p, Project project) {
    if (!commanding || state.owner[p] != human || buildAt(p) != null) return false;
    final cost = game.buildCost(p, project);
    return cost > 0 && cost <= goldFree;
  }

  /// How many more units [p] can raise this turn with the gold left.
  int recruitRoom(int p) {
    if (!commanding || state.owner[p] != human) return 0;
    return math.max(0, math.min(game.recruitCap(p) - recruitsAt(p), goldFree ~/ Rules.unitCost));
  }

  /// Where units in [p] may be sent.
  List<int> targetsFrom(int p) => [
        for (final q in world.provinces[p].links)
          if (game.canMove(human, p, q)) q,
      ];

  bool isHostile(int p) => state.owner[p] != human && game.atWar(human, state.owner[p]);

  /// Nations with a peace offer waiting for the player's answer.
  List<int> get peaceOffers => [
        if (commanding)
          for (var n = 0; n < world.nations.length; n++)
            if (game.hasPeaceOffer(n, human) && game.atWar(n, human)) n,
      ];

  /// Nations with an alliance offer waiting for the player's answer.
  List<int> get allianceOffers => [
        if (commanding)
          for (var n = 0; n < world.nations.length; n++)
            if (game.hasAllianceOffer(n, human) && game.canOfferAlliance(human, n)) n,
      ];

  // ------------------------------------------------------------ input

  void tapProvince(int p) {
    if (mode == InputMode.pickTarget && (overlay.targets.contains(p) || canMarch(selected, p))) {
      moveTarget = p;
      mode = InputMode.moveAmount;
    } else {
      selected = p;
      mode = InputMode.browse;
      moveTarget = -1;
    }
    _sync();
  }

  void beginMove() {
    if (selected < 0 || movable(selected) <= 0) return;
    mode = InputMode.pickTarget;
    _sync();
  }

  void beginRecruit() {
    if (selected < 0 || recruitRoom(selected) <= 0) return;
    mode = InputMode.recruitAmount;
    _sync();
  }

  void beginBuild() {
    if (selected < 0 || !commanding || state.owner[selected] != human || buildAt(selected) != null) return;
    mode = InputMode.build;
    _sync();
  }

  void orderBuild(Project project) {
    if (selected >= 0 && canBuild(selected, project)) orders.builds.add(BuildOrder(selected, project));
    cancelInput();
  }

  void cancelBuild(BuildOrder order) {
    orders.builds.remove(order);
    _sync();
  }

  void cancelInput() {
    mode = InputMode.browse;
    moveTarget = -1;
    _sync();
  }

  void confirmMove(int count) {
    final from = selected;
    final to = moveTarget;
    final send = math.min(count, movable(from));
    if (send > 0 && game.canMove(human, from, to)) {
      final index = orders.moves.indexWhere((m) => m.from == from && m.to == to && marchOf(m) == null);
      if (index >= 0) {
        orders.moves[index] = MoveOrder(from, to, orders.moves[index].count + send);
      } else {
        orders.moves.add(MoveOrder(from, to, send));
      }
    } else if (send > 0 && canMarch(from, to)) {
      final march = March(from, to, send);
      if (_step(march)) marches.add(march);
    }
    cancelInput();
  }

  void confirmRecruit(int count) {
    final p = selected;
    final raise = math.min(count, recruitRoom(p));
    if (raise > 0) {
      final index = orders.recruits.indexWhere((r) => r.province == p);
      if (index >= 0) {
        orders.recruits[index] = RecruitOrder(p, orders.recruits[index].count + raise);
      } else {
        orders.recruits.add(RecruitOrder(p, raise));
      }
    }
    cancelInput();
  }

  /// Cancels a move, and the march it is a step of.
  void cancelMove(MoveOrder order) {
    orders.moves.remove(order);
    marches.removeWhere((m) => identical(m.step, order));
    _sync();
  }

  void cancelRecruit(RecruitOrder order) {
    orders.recruits.remove(order);
    _sync();
  }

  // ------------------------------------------------------------ marches

  /// Turns a march from [from] to [to] takes through the player's own land,
  /// or 0 when units there cannot march to it: it is the same province, a
  /// neighbour (an ordinary move) or out of reach.
  int marchTurns(int from, int to) {
    if (!commanding || from < 0 || to < 0 || from == to || world.provinces[from].links.contains(to)) return 0;
    return (game.pathThroughOwnLand(human, from, to)?.length ?? 1) - 1;
  }

  bool canMarch(int from, int to) => marchTurns(from, to) > 0;

  /// The march whose step this turn is [move], if any.
  March? marchOf(MoveOrder move) => marches.where((m) => identical(m.step, move)).firstOrNull;

  /// Orders this turn's step of [march]. False when it cannot go on.
  bool _step(March march) {
    final path = game.pathThroughOwnLand(human, march.at, march.to);
    final send = math.min(march.count, movable(march.at));
    if (path == null || path.length < 2 || send <= 0) return false;
    march
      ..count = send
      ..step = MoveOrder(march.at, path[1], send)
      ..ahead = path.sublist(1);
    orders.moves.add(march.step!);
    return true;
  }

  /// Moves every march a province on after the turn [resolved] carried
  /// their steps out, and orders the next steps.
  void _advanceMarches(Orders resolved) {
    for (final march in List.of(marches)) {
      final step = march.step;
      march.step = null;
      final arrived = step != null && resolved.moves.contains(step) && state.owner[step.to] == human;
      if (arrived) march.at = step.to;
      if (!arrived || march.at == march.to || !_step(march)) marches.remove(march);
    }
  }

  List<List<int>> get marchesToJson => [for (final m in marches) m.toJson()];

  // ------------------------------------------------------------ diplomacy

  /// Adds [nation] to or takes it out of one of this turn's diplomatic
  /// orders. It only goes in while [allowed].
  void _setOrder(Set<int> order, int nation, bool on, bool allowed) {
    if (!on) {
      order.remove(nation);
    } else if (allowed) {
      order.add(nation);
    }
    _sync();
  }

  void setWarDeclared(int nation, bool declared) => _setOrder(orders.declareWar, nation, declared, game.canDeclareWar(human, nation));

  void setPeaceOffered(int nation, bool offered) => _setOrder(orders.offerPeace, nation, offered, game.atWar(human, nation));

  void setAllianceOffered(int nation, bool offered) => _setOrder(orders.offerAlliance, nation, offered, game.canOfferAlliance(human, nation));

  void setAllianceBroken(int nation, bool broken) => _setOrder(orders.breakAlliance, nation, broken, game.allied(human, nation));

  // ------------------------------------------------------------ research

  /// The field research goes into, with this turn's change if any.
  Field get researchField => orders.research?.field ?? Field.values[state.researchFocus[human]];

  /// Percent of income going into research, with this turn's change if any.
  int get researchShare => orders.research?.share ?? state.researchShare[human];

  /// Gold research takes each turn at [researchShare].
  int get researchSpend => commanding ? game.researchSpend(human, share: researchShare, income: income) : 0;

  void setResearch(Field field, int share) {
    if (!commanding || !Rules.researchShares.contains(share)) return;
    final unchanged = field.index == state.researchFocus[human] && share == state.researchShare[human];
    orders.research = unchanged ? null : ResearchPlan(field, share);
    _sync();
  }

  // ------------------------------------------------------------ turn

  /// Resolves the turn with the orders written so far and autosaves.
  TurnReport endTurn() {
    final resolved = orders;
    final report = game.endTurn(commanding ? orders : null);
    orders = Orders();
    _newTurn();
    if (commanding) {
      _advanceMarches(resolved);
    } else {
      marches.clear();
    }
    mode = InputMode.browse;
    moveTarget = -1;
    lastReport = report;
    overlay.flashing = {
      for (final e in report.events)
        if (e.kind == EventKind.captured || e.kind == EventKind.revolt) e.province,
    };
    _sync();
    autosave();
    return report;
  }

  /// Carries on after the game is decided, with no further victory checks.
  void keepPlaying() {
    state.sandbox = true;
    state.ended = false;
    notifyListeners();
    autosave();
  }

  Future<void> autosave() async {
    try {
      await saves.autosave(game, orders, marches: marchesToJson);
      saveError = null;
    } on Object catch (e) {
      saveError = '$e';
    }
  }

  /// Works out what only a new turn can change.
  void _newTurn() {
    _sight = state.fog && commanding ? game.sightOf(human) : null;
    if (!mapModes.contains(mapMode)) mapMode = MapMode.political;
    _fills = _fillsFor(mapMode);
    if (commanding) {
      _income = game.incomeOf(human);
      _upkeep = game.upkeepOf(human);
      _army = game.unitsOf(human);
    }
  }

  /// Pushes the current game and orders into the map layers.
  void _sync() {
    scene.setOwners(state.owner, fills: _fills);
    overlay
      ..selected = selected
      ..targets = switch (mode) {
        InputMode.pickTarget => targetsFrom(selected).toSet(),
        InputMode.moveAmount => {moveTarget},
        _ => const {},
      }
      ..arrows = [
        for (final m in orders.moves) MapArrow(m.from, m.to, m.count, hostile: state.owner[m.to] != human),
      ]
      ..marches = [
        for (final m in marches) m.ahead,
      ]
      ..units = [
        for (var p = 0; p < state.units.length; p++) state.owner[p] == human ? state.units[p] - leaving(p) : unitsSeen(p) ?? -1,
      ]
      ..recruits = {for (final r in orders.recruits) r.province: r.count}
      ..forts = state.forts
      ..capitals = {
        for (final c in state.capital)
          if (c >= 0) c,
      }
      ..changed();
    notifyListeners();
  }

  @override
  void dispose() {
    scene.dispose();
    camera.dispose();
    overlay.dispose();
    super.dispose();
  }
}
