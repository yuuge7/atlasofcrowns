import 'dart:math' as math;

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
}

/// The player's side of a running game: the orders being written this turn,
/// what is selected, and what the map should show for it.
class GameController extends ChangeNotifier {
  GameController({required this.assets, required this.saves, required this.game, Orders? orders})
      : orders = orders ?? Orders(),
        scene = MapScene(assets.geometry, assets.world),
        camera = MapCamera(assets.geometry.size) {
    _sync();
  }

  final GameAssets assets;
  final SaveStore saves;
  final Game game;
  final MapScene scene;
  final MapCamera camera;
  final MapOverlay overlay = MapOverlay();

  Orders orders;
  int selected = -1;
  InputMode mode = InputMode.browse;
  int moveTarget = -1;
  TurnReport? lastReport;

  /// Set when the last autosave could not be written.
  String? saveError;

  World get world => game.world;
  GameState get state => game.state;
  int get human => state.human;

  /// False once the player is out of the game and only watching.
  bool get commanding => human >= 0 && state.alive[human];

  // ------------------------------------------------------------ treasury

  int get gold => commanding ? state.gold[human] : 0;

  /// Gold not yet promised to recruits ordered this turn.
  int get goldFree => gold - orders.recruits.fold(0, (sum, r) => sum + r.count * Rules.unitCost);

  int get income => game.incomeOf(human);
  int get upkeep => game.upkeepOf(human);

  // ------------------------------------------------------------ armies

  /// Units already ordered out of [p] this turn.
  int leaving(int p) => orders.moves.where((m) => m.from == p).fold(0, (sum, m) => sum + m.count);

  /// Units in [p] still waiting for orders.
  int movable(int p) => state.owner[p] == human ? state.units[p] - leaving(p) : 0;

  /// Units already ordered into [p] this turn, from anywhere.
  int headingTo(int p) => orders.moves.where((m) => m.to == p).fold(0, (sum, m) => sum + m.count);

  int recruitsAt(int p) => orders.recruits.where((r) => r.province == p).fold(0, (sum, r) => sum + r.count);

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

  // ------------------------------------------------------------ input

  void tapProvince(int p) {
    if (mode == InputMode.pickTarget && overlay.targets.contains(p)) {
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
      final index = orders.moves.indexWhere((m) => m.from == from && m.to == to);
      if (index >= 0) {
        orders.moves[index] = MoveOrder(from, to, orders.moves[index].count + send);
      } else {
        orders.moves.add(MoveOrder(from, to, send));
      }
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

  void cancelMove(MoveOrder order) {
    orders.moves.remove(order);
    _sync();
  }

  void cancelRecruit(RecruitOrder order) {
    orders.recruits.remove(order);
    _sync();
  }

  void setWarDeclared(int nation, bool declared) {
    if (declared) {
      if (game.canDeclareWar(human, nation)) orders.declareWar.add(nation);
    } else {
      orders.declareWar.remove(nation);
    }
    _sync();
  }

  void setPeaceOffered(int nation, bool offered) {
    if (offered) {
      if (game.atWar(human, nation)) orders.offerPeace.add(nation);
    } else {
      orders.offerPeace.remove(nation);
    }
    _sync();
  }

  // ------------------------------------------------------------ turn

  /// Resolves the turn with the orders written so far and autosaves.
  TurnReport endTurn() {
    final report = game.endTurn(commanding ? orders : null);
    orders = Orders();
    mode = InputMode.browse;
    moveTarget = -1;
    lastReport = report;
    overlay.flashing = {
      for (final e in report.events)
        if (e.kind == EventKind.captured) e.province,
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
      await saves.autosave(game, orders);
      saveError = null;
    } on Object catch (e) {
      saveError = '$e';
    }
  }

  /// Pushes the current game and orders into the map layers.
  void _sync() {
    scene.setOwners(state.owner);
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
      ..units = [
        for (var p = 0; p < state.units.length; p++) state.owner[p] == human ? state.units[p] - leaving(p) : state.units[p],
      ]
      ..recruits = {for (final r in orders.recruits) r.province: r.count}
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
