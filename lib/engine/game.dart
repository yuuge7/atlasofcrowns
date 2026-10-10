import 'dart:math' as math;

import 'ai.dart';
import 'events.dart';
import 'orders.dart';
import 'resolve.dart';
import 'rng.dart';
import 'rules.dart';
import 'state.dart';
import 'world.dart';

/// One game in progress: the fixed [world] plus the changing [state], and the
/// questions both the UI and the AI ask about them.
class Game {
  Game(this.world, this.state);

  /// Sets up turn one of the scenario. [human] is the player's nation, or -1
  /// to let the AI play every side.
  factory Game.start(World world, {required int human, required int seed, double winFraction = Rules.defaultWinFraction}) {
    final nations = world.nations.length;
    final state = GameState(
      seed: seed,
      human: human,
      winFraction: winFraction,
      owner: List.of(world.startOwners),
      units: List.filled(world.provinces.length, 0),
      gold: List.filled(nations, 0),
      alive: List.filled(nations, true),
      capital: [for (final n in world.nations) n.capital],
      rngState: seed,
    );
    for (final war in world.startWars) {
      final key = pairKey(war[0], war[1]);
      state.wars.add(key);
      state.warStart[key] = 0;
      state.lastGain[key] = 0;
    }
    final game = Game(world, state);
    for (var n = 0; n < nations; n++) {
      final mine = game.provincesOf(n);
      if (mine.isEmpty) {
        state.alive[n] = false;
        state.capital[n] = -1;
        continue;
      }
      final income = game.incomeOf(n);
      state.gold[n] = income * Rules.startGoldPerIncome;
      final army = (income * Rules.startArmyPerIncome + mine.length * Rules.startArmyPerProvince) * world.nations[n].readiness;
      game._deployStartingArmy(n, mine, army.round());
    }
    return game;
  }

  /// Restores a saved game. Throws [FormatException] when the save belongs to
  /// another scenario or an older build of the map.
  factory Game.fromJson(World world, Map<String, dynamic> json) {
    if (json['scenario'] != world.scenarioId || json['mapBuild'] != world.mapBuild) {
      throw FormatException('Save is for ${json['scenario']} on map ${json['mapBuild']}, this is ${world.scenarioId} on ${world.mapBuild}');
    }
    final state = GameState.fromJson(json['state'] as Map<String, dynamic>);
    if (state.owner.length != world.provinces.length || state.gold.length != world.nations.length) {
      throw const FormatException('Save does not match the map');
    }
    return Game(world, state);
  }

  final World world;
  final GameState state;

  Map<String, dynamic> toJson() => {
        'scenario': world.scenarioId,
        'mapBuild': world.mapBuild,
        'state': state.toJson(),
      };

  // ------------------------------------------------------------ questions

  bool atWar(int a, int b) => a != b && state.wars.contains(pairKey(a, b));

  bool canDeclareWar(int a, int b) {
    if (a == b || a < 0 || b < 0 || b >= world.nations.length) return false;
    if (!state.alive[a] || !state.alive[b] || atWar(a, b)) return false;
    return state.turn >= (state.truceUntil[pairKey(a, b)] ?? 0);
  }

  /// Turns left before [a] and [b] may fight again, 0 when there is no truce.
  int truceLeft(int a, int b) => math.max(0, (state.truceUntil[pairKey(a, b)] ?? 0) - state.turn);

  /// True while [from] has an unanswered peace offer to [to].
  bool hasPeaceOffer(int from, int to) => state.peaceOffers.containsKey(directedKey(from, to));

  List<int> provincesOf(int n) => [
        for (var p = 0; p < state.owner.length; p++)
          if (state.owner[p] == n) p,
      ];

  int provinceCount(int n) {
    var count = 0;
    for (final o in state.owner) {
      if (o == n) count++;
    }
    return count;
  }

  int unitsOf(int n) {
    var total = 0;
    for (var p = 0; p < state.owner.length; p++) {
      if (state.owner[p] == n) total += state.units[p];
    }
    return total;
  }

  /// Gold earned per turn, before upkeep.
  int incomeOf(int n) {
    var total = Rules.baseIncome;
    for (var p = 0; p < state.owner.length; p++) {
      if (state.owner[p] == n) total += world.provinces[p].income;
    }
    return total;
  }

  int upkeepOf(int n) => unitsOf(n) ~/ Rules.unitsPerUpkeepGold;

  /// Most units province [p] can raise in a single turn.
  int recruitCap(int p) => Rules.recruitBase + world.provinces[p].income;

  bool isCapital(int p) => state.capital[state.owner[p]] == p;

  /// Militia standing with the owner's units whenever [p] is attacked.
  int militia(int p) => Rules.militiaBase + (world.provinces[p].income * Rules.militiaPerIncome).floor();

  /// What a defender's strength in [p] is multiplied by.
  double defenseMultiplier(int p) => Rules.defenseBonus + (isCapital(p) ? Rules.capitalBonus : 0);

  /// Strength an attack on [p] has to beat, before either side rolls.
  int defenseStrength(int p) => ((state.units[p] + militia(p)) * defenseMultiplier(p)).ceil();

  /// Provinces a nation must hold to win.
  int get winTarget => (state.winFraction * world.provinces.length).ceil();

  /// Whether [n] may order units from [from] into [to] this turn.
  bool canMove(int n, int from, int to) {
    if (state.owner[from] != n || !world.provinces[from].links.contains(to)) return false;
    final target = state.owner[to];
    return target == n || atWar(n, target);
  }

  // ------------------------------------------------------------ turn

  /// Lets every AI nation plan, then resolves all orders at once. Pass the
  /// player's orders, or null for no orders. With [autoPlayHuman] the AI
  /// plans for the player as well.
  TurnReport endTurn(Orders? humanOrders, {bool autoPlayHuman = false}) {
    final rng = Rng(state.rngState);
    final orders = List<Orders?>.filled(world.nations.length, null);
    for (var n = 0; n < orders.length; n++) {
      if (!state.alive[n]) continue;
      orders[n] = n == state.human && !autoPlayHuman ? humanOrders : planAi(this, n, rng);
    }
    final report = resolveTurn(this, orders, rng);
    state.rngState = rng.state;
    return report;
  }

  /// Spreads [total] units over [mine], weighted towards the capital, the
  /// borders and above all the fronts of wars already running.
  void _deployStartingArmy(int n, List<int> mine, int total) {
    final weights = <double>[];
    for (final p in mine) {
      var weight = 1.0 + world.provinces[p].income / 4;
      var border = false;
      var front = false;
      for (final q in world.provinces[p].links) {
        final other = state.owner[q];
        if (other == n) continue;
        border = true;
        if (atWar(n, other)) front = true;
      }
      if (border) weight += 1;
      if (front) weight += 4;
      if (state.capital[n] == p) weight += 2;
      weights.add(weight);
    }
    final sum = weights.fold(0.0, (a, b) => a + b);
    var placed = 0;
    for (var i = 0; i < mine.length; i++) {
      final share = (total * weights[i] / sum).floor();
      state.units[mine[i]] = share;
      placed += share;
    }
    // Whatever rounding left over goes to the heaviest provinces first.
    final order = [for (var i = 0; i < mine.length; i++) i]..sort((a, b) => weights[b].compareTo(weights[a]));
    for (var i = 0; placed < total; i = (i + 1) % order.length) {
      state.units[mine[order[i]]]++;
      placed++;
    }
  }
}
