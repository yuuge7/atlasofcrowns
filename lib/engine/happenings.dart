/// Things that happen to a nation by chance: harvests, strikes, fires,
/// breakthroughs. Some ask the nation how to answer.
library;

import 'dart:math' as math;

import 'events.dart';
import 'game.dart';
import 'orders.dart';
import 'rng.dart';
import 'rules.dart';

enum Happening {
  /// A bumper harvest in a province: gold.
  harvest(0.02),

  /// Customs and taxes come in above the estimate: a turn's income.
  windfall(0.01),

  /// Sickness in a province: some of its units die.
  epidemic(0.01),

  /// Volunteers flock to the colours, at war: units in the capital.
  volunteers(0.03),

  /// A breakthrough in the laboratories: research towards the next level.
  breakthrough(0.01),

  /// A scandal at court: gold lost.
  scandal(0.01),

  /// Fire in the capital: a level of development lost, or gold.
  fire(0.006),

  /// A new railway: a level of development in a province.
  railway(0.015),

  /// Unpaid troops mutiny, at war with an empty treasury: units lost.
  mutiny(0.03),

  /// A border incident with a neighbour: relations fall.
  incident(0.012),

  /// A state visit from another court: relations rise.
  visit(0.012),

  /// Workers strike in a rich province. Pay them, or send in the troops.
  strike(0.03, choices: 2),

  /// Refugees from the war reach a province. Shelter them, or turn them away.
  refugees(0.04, choices: 2),

  /// An inventor offers a design. Fund it, or show him the door.
  inventor(0.03, choices: 2);

  const Happening(this.chance, {this.choices = 0});

  /// Chance each turn, for a nation it can happen to.
  final double chance;

  /// Answers the nation chooses between; 0 for none.
  final int choices;
}

/// Relations lost to a border incident and won by a state visit.
const int incidentRelation = -20;
const int visitRelation = 15;

/// A happening waiting for an answer, as kept in [GameState.pending].
(Happening, int) decodePending(int code) => (Happening.values[code ~/ 1000], code % 1000);

int encodePending(Happening h, int province) => h.index * 1000 + province;

/// Rolls this turn's happenings, at most one a nation, and carries them out.
/// The player's choices wait in [GameState.pending] for an answer with next
/// turn's orders; the AI answers at once.
void rollHappenings(Game g, Rng rng, List<GameEvent> events) {
  final s = g.state;
  final neighbors = g.neighborsOfAll();
  for (var n = 0; n < s.alive.length; n++) {
    if (!s.alive[n] || s.pending.containsKey(n) || g.world.isWild(n)) continue;
    final mine = g.provincesOf(n);
    final atWar = s.wars.any((key) => key >> 8 == n || key & 0xFF == n);
    final rivals = [
      for (final m in neighbors[n].toList()..sort())
        if (!g.atWar(n, m) && !g.world.isWild(m)) m,
    ];
    for (final h in Happening.values) {
      final possible = switch (h) {
        Happening.volunteers || Happening.refugees => atWar,
        Happening.mutiny => atWar && s.gold[n] < g.incomeOf(n),
        Happening.incident => rivals.isNotEmpty,
        _ => true,
      };
      if (!possible || !rng.chance(h.chance)) continue;
      final province = _provinceFor(g, h, n, mine, rng);
      final other = switch (h) {
        Happening.incident => rivals[rng.nextInt(rivals.length)],
        Happening.visit => _visitor(g, n, rng),
        _ => -1,
      };
      if (h == Happening.visit && other < 0) break;
      if (h.choices > 0 && n == s.human) {
        s.pending[n] = encodePending(h, province);
        events.add(GameEvent(EventKind.happening, a: n, province: province, n1: h.index, n2: -1));
      } else {
        answerHappening(g, n, h, province, h.choices > 0 ? _aiAnswer(g, n, h, province) : 0, events, other: other);
      }
      break;
    }
  }
}

/// Carries out the happening waiting for [n] with the answer in [orders],
/// or with the last answer, which costs nothing, when there is none.
void answerPending(Game g, int n, Orders? orders, List<GameEvent> events) {
  final code = g.state.pending.remove(n);
  if (code == null) return;
  final (h, province) = decodePending(code);
  if (g.state.owner[province] != n) return;
  final choice = (orders?.answer ?? h.choices - 1).clamp(0, h.choices - 1);
  answerHappening(g, n, h, province, choice, events);
}

/// Gold answer [choice] to [h] costs [n], where it costs any.
int happeningCost(Game g, int n, Happening h, int province, int choice) => switch ((h, choice)) {
      (Happening.strike, 0) => g.provinceIncome(province) * 3,
      (Happening.refugees, 0) => math.max(1, g.incomeOf(n) ~/ 2),
      (Happening.inventor, 0) => math.max(1, g.incomeOf(n)),
      _ => 0,
    };

/// Share of the next research level an inventor's design is worth, and a
/// breakthrough.
const double inventorShare = 0.4;
const double breakthroughShare = 0.3;

void answerHappening(Game g, int n, Happening h, int province, int choice, List<GameEvent> events, {int other = -1}) {
  final s = g.state;
  final income = g.incomeOf(n);
  final cost = happeningCost(g, n, h, province, choice);
  // An answer the treasury cannot pay for is the one that costs nothing.
  if (cost > s.gold[n]) choice = h.choices - 1;
  var amount = 0;
  int research(double share) {
    final field = Field.values[s.researchFocus[n]];
    final next = g.researchCost(n, field);
    if (next <= 0) return 0;
    final gain = (next * share).floor();
    s.research[n][field.index] += gain;
    return gain;
  }

  int loseUnits(double share) {
    final lost = (s.units[province] * share).floor();
    s.units[province] -= lost;
    return lost;
  }

  void develop(int by) => s.development[province] = (s.development[province] + by).clamp(0, Rules.maxDevelop);

  switch (h) {
    case Happening.harvest:
      amount = g.provinceIncome(province) * 3;
      s.gold[n] += amount;
    case Happening.windfall:
      amount = income;
      s.gold[n] += amount;
    case Happening.epidemic:
      amount = loseUnits(0.3);
    case Happening.volunteers:
      amount = g.militia(province);
      s.units[province] += amount;
    case Happening.breakthrough:
      amount = research(breakthroughShare);
    case Happening.scandal:
      amount = math.min(s.gold[n], income);
      s.gold[n] -= amount;
    case Happening.fire:
      if (s.development[province] > 0) {
        develop(-1);
      } else {
        amount = math.min(s.gold[n], income);
        s.gold[n] -= amount;
      }
    case Happening.railway:
      develop(1);
    case Happening.mutiny:
      amount = loseUnits(0.2);
    case Happening.incident:
      s.changeRelation(n, other, incidentRelation);
    case Happening.visit:
      s.changeRelation(n, other, visitRelation);
    case Happening.strike:
      if (choice == 0) {
        amount = cost;
        s.gold[n] -= cost;
      } else if (s.development[province] > 0) {
        // Put down: the province loses a level of development, or troops.
        develop(-1);
      } else {
        amount = loseUnits(0.2);
      }
    case Happening.refugees:
      if (choice == 0) {
        amount = cost;
        s.gold[n] -= cost;
        develop(1);
      }
    case Happening.inventor:
      if (choice == 0) {
        s.gold[n] -= cost;
        amount = research(inventorShare);
      }
  }
  events.add(GameEvent(EventKind.happening, a: n, b: other, province: province, n1: h.index, n2: choice, n3: amount));
}

/// Where [h] strikes [n]: the capital for what happens at court, the
/// richest of a few provinces for a strike, the largest army for a mutiny,
/// anywhere for the rest.
int _provinceFor(Game g, Happening h, int n, List<int> mine, Rng rng) {
  final s = g.state;
  switch (h) {
    case Happening.volunteers || Happening.fire || Happening.scandal || Happening.windfall || Happening.breakthrough || Happening.visit || Happening.inventor:
      return s.capital[n];
    case Happening.mutiny:
      return mine.reduce((a, b) => s.units[b] > s.units[a] ? b : a);
    case Happening.strike:
      final sample = [for (var i = 0; i < 3; i++) mine[rng.nextInt(mine.length)]];
      return sample.reduce((a, b) => g.provinceIncome(b) > g.provinceIncome(a) ? b : a);
    case Happening.harvest || Happening.epidemic || Happening.railway || Happening.refugees || Happening.incident:
      return mine[rng.nextInt(mine.length)];
  }
}

/// A court at peace with [n] that pays it a visit, or -1.
int _visitor(Game g, int n, Rng rng) {
  final courts = [
    for (var m = 0; m < g.state.alive.length; m++)
      if (m != n && g.state.alive[m] && !g.atWar(n, m) && !g.world.isWild(m)) m,
  ];
  return courts.isEmpty ? -1 : courts[rng.nextInt(courts.length)];
}

/// The AI pays when it can well afford to.
int _aiAnswer(Game g, int n, Happening h, int province) => g.state.gold[n] >= 2 * happeningCost(g, n, h, province, 0) ? 0 : 1;
