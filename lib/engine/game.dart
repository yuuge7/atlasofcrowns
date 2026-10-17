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
  factory Game.start(
    World world, {
    required int human,
    required int seed,
    double winFraction = Rules.defaultWinFraction,
    int difficulty = Rules.normalDifficulty,
    bool fog = false,
  }) {
    final nations = world.nations.length;
    final state = GameState(
      seed: seed,
      human: human,
      winFraction: winFraction,
      difficulty: difficulty,
      fog: fog,
      owner: List.of(world.startOwners),
      units: List.filled(world.provinces.length, 0),
      gold: List.filled(nations, 0),
      alive: List.filled(nations, true),
      capital: [for (final n in world.nations) n.capital],
      rngState: seed,
      forts: List.of(world.startForts),
      tech: [for (final n in world.nations) List.of(n.tech)],
      researchFocus: [for (final n in world.nations) n.tech[Field.army.index] <= n.tech[Field.industry.index] ? Field.army.index : Field.industry.index],
      researchShare: List.filled(nations, 10),
    );
    for (final war in world.startWars) {
      state.openWar(war[0], war[1], 0);
    }
    for (final alliance in world.startAlliances) {
      state.alliances.add(pairKey(alliance[0], alliance[1]));
    }
    final game = Game(world, state);
    for (var n = 0; n < nations; n++) {
      final mine = game.provincesOf(n);
      if (mine.isEmpty) {
        state.alive[n] = false;
        state.capital[n] = -1;
        continue;
      }
      // Difficulty changes what the AI earns from here on, not the position
      // it starts from.
      final income = game.incomeOf(n, difficulty: false);
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

  bool allied(int a, int b) => a != b && state.alliances.contains(pairKey(a, b));

  /// Allies of [n], in id order.
  List<int> alliesOf(int n) => [
        for (var other = 0; other < world.nations.length; other++)
          if (allied(n, other)) other,
      ];

  bool canDeclareWar(int a, int b) {
    if (a == b || a < 0 || b < 0 || b >= world.nations.length) return false;
    if (!state.alive[a] || !state.alive[b] || atWar(a, b) || allied(a, b)) return false;
    return state.turn >= (state.truceUntil[pairKey(a, b)] ?? 0);
  }

  /// Allies of [b] who would join if [a] declared war on it now: those not
  /// already at war with [a], not allied to it as well and not bound by a
  /// truce with it. [allies] is [alliesOf] of [b], when already at hand.
  List<int> wouldDefend(int a, int b, [List<int>? allies]) => [
        for (final ally in allies ?? alliesOf(b))
          if (canDeclareWar(ally, a)) ally,
      ];

  /// Whether [a] and [b] may become allies: both standing, at peace and
  /// not yet allied, and neither at war with an ally of the other.
  bool canOfferAlliance(int a, int b) {
    if (a == b || a < 0 || b < 0 || b >= world.nations.length) return false;
    if (!state.alive[a] || !state.alive[b] || atWar(a, b) || allied(a, b)) return false;
    for (var other = 0; other < world.nations.length; other++) {
      if ((allied(a, other) && atWar(b, other)) || (allied(b, other) && atWar(a, other))) return false;
    }
    return true;
  }

  /// Turns left before [a] and [b] may fight again, 0 when there is no truce.
  int truceLeft(int a, int b) => math.max(0, (state.truceUntil[pairKey(a, b)] ?? 0) - state.turn);

  /// True while [from] has an unanswered peace offer to [to].
  bool hasPeaceOffer(int from, int to) => state.peaceOffers.containsKey(directedKey(from, to));

  /// True while [from] has an unanswered alliance offer to [to].
  bool hasAllianceOffer(int from, int to) => state.allianceOffers.containsKey(directedKey(from, to));

  /// True when [from] offered [to] an alliance in the last
  /// [Rules.aiAllianceRetryTurns] turns: older offers are forgotten at the
  /// end of each turn.
  bool askedRecently(int from, int to) => state.allianceAsked.containsKey(directedKey(from, to));

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

  /// Gold earned per turn, before upkeep, industry included, and the
  /// difficulty's share for an AI nation unless [difficulty] is false.
  int incomeOf(int n, {bool difficulty = true}) {
    var total = Rules.baseIncome;
    for (var p = 0; p < state.owner.length; p++) {
      if (state.owner[p] == n) total += provinceIncome(p);
    }
    final share = difficulty && state.human >= 0 && n != state.human ? Rules.aiIncome[state.difficulty] : 1.0;
    return (total * (1 + Rules.industryTechBonus * techLevel(n, Field.industry)) * share).floor();
  }

  /// For every nation, the nations whose land touches its own.
  List<Set<int>> neighborsOfAll() {
    final touches = List.generate(world.nations.length, (_) => <int>{});
    for (var p = 0; p < state.owner.length; p++) {
      for (final q in world.provinces[p].links) {
        if (state.owner[q] != state.owner[p]) touches[state.owner[p]].add(state.owner[q]);
      }
    }
    return touches;
  }

  /// The shortest way from [from] to [to] through [n]'s own land, both ends
  /// included, or null when there is none.
  List<int>? pathThroughOwnLand(int n, int from, int to) {
    if (state.owner[from] != n || state.owner[to] != n) return null;
    final previous = <int, int>{from: from};
    final queue = [from];
    for (var i = 0; i < queue.length && !previous.containsKey(to); i++) {
      for (final q in world.provinces[queue[i]].links) {
        if (state.owner[q] != n || previous.containsKey(q)) continue;
        previous[q] = queue[i];
        queue.add(q);
      }
    }
    if (!previous.containsKey(to)) return null;
    final path = [to];
    while (path.last != from) {
      path.add(previous[path.last]!);
    }
    return path.reversed.toList();
  }

  /// Provinces whose armies [n] can see: its own and its allies', and
  /// every province next to them.
  List<bool> sightOf(int n) {
    final seen = List.filled(state.owner.length, false);
    for (var p = 0; p < state.owner.length; p++) {
      final o = state.owner[p];
      if (o != n && !allied(n, o)) continue;
      seen[p] = true;
      for (final q in world.provinces[p].links) {
        seen[q] = true;
      }
    }
    return seen;
  }

  int techLevel(int n, Field field) => state.tech[n][field.index];

  /// What every unit of [n] counts for in battle.
  double armyFactor(int n) => 1 + Rules.armyTechBonus * techLevel(n, Field.army);

  /// Gold the next level in [field] costs [n], or -1 at the top level.
  /// [income] is [incomeOf] of [n], when already at hand.
  int researchCost(int n, Field field, {int? income}) {
    final level = techLevel(n, field);
    return level >= Rules.maxTech ? -1 : Rules.techCost * (level + 1) * math.max(10, income ?? incomeOf(n));
  }

  /// Gold [n] puts into research each turn, if the treasury has it, at its
  /// own share or at [share] percent. [income] is [incomeOf] of [n], when
  /// already at hand.
  int researchSpend(int n, {int? share, int? income}) => (income ?? incomeOf(n)) * (share ?? state.researchShare[n]) ~/ 100;

  /// What [p] yields to an owner who has held it long enough.
  int fullIncome(int p) => world.provinces[p].income + state.development[p];

  /// True while [p] is held by someone other than its scenario owner and
  /// not yet part of the new owner's realm.
  bool isOccupied(int p) => world.startOwners[p] != state.owner[p] && state.turn - state.heldSince[p] < Rules.integrationTurns;

  /// What [p] yields its owner now: all of [fullIncome] in the owner's own
  /// land, less in land taken recently from someone else.
  int provinceIncome(int p) {
    final full = fullIncome(p);
    if (!isOccupied(p)) return full;
    final held = state.turn - state.heldSince[p];
    return (full * (Rules.occupiedShare + (1 - Rules.occupiedShare) * held / Rules.integrationTurns)).floor();
  }

  /// Chance that [p] revolts at the end of this turn: only occupied land
  /// whose old owner is fallen or at war with the holder, and only while the
  /// garrison is weaker than the militia.
  double revoltChance(int p) {
    if (!isOccupied(p)) return 0;
    final old = world.startOwners[p];
    if (state.alive[old] && !atWar(old, state.owner[p])) return 0;
    final guard = militia(p);
    if (state.units[p] >= guard) return 0;
    return Rules.revoltChance * (1 - state.units[p] / guard);
  }

  int fortsOf(int n) {
    var total = 0;
    for (var p = 0; p < state.owner.length; p++) {
      if (state.owner[p] == n) total += state.forts[p];
    }
    return total;
  }

  int upkeepOf(int n) => unitsOf(n) ~/ Rules.unitsPerUpkeepGold + fortsOf(n) * Rules.fortUpkeep;

  /// Most units province [p] can raise in a single turn.
  int recruitCap(int p) => Rules.recruitBase + provinceIncome(p);

  bool isCapital(int p) => state.capital[state.owner[p]] == p;

  /// Militia standing with the owner's units whenever [p] is attacked.
  int militia(int p) => Rules.militiaBase + (provinceIncome(p) * Rules.militiaPerIncome).floor();

  /// What a defender's strength in [p] is multiplied by.
  double defenseMultiplier(int p) => Rules.defenseBonus + state.forts[p] * Rules.fortBonus + (isCapital(p) ? Rules.capitalBonus : 0);

  /// Gold the next level of [project] costs in [p], or -1 when it is at
  /// its highest level.
  int buildCost(int p, Project project) => switch (project) {
        Project.fortify => state.forts[p] >= Rules.maxFort ? -1 : Rules.fortCost * (state.forts[p] + 1),
        Project.develop => state.development[p] >= Rules.maxDevelop ? -1 : Rules.developCost + Rules.developStep * state.development[p],
      };

  /// Strength an attack on [p] has to beat, before either side rolls.
  int defenseStrength(int p) => ((state.units[p] + militia(p)) * defenseMultiplier(p) * armyFactor(state.owner[p])).ceil();

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
    final outlook = Outlook(this);
    for (var n = 0; n < orders.length; n++) {
      if (!state.alive[n]) continue;
      orders[n] = n == state.human && !autoPlayHuman ? humanOrders : planAi(this, n, rng, outlook);
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
      var weight = 1.0 + world.provinces[p].income / 4 + state.forts[p];
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
