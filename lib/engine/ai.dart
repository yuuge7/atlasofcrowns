import 'dart:collection';
import 'dart:math' as math;

import 'game.dart';
import 'orders.dart';
import 'rng.dart';
import 'rules.dart';
import 'state.dart';

class _Target {
  _Target(this.province, this.need, this.score, this.sources);

  final int province;
  final int need;
  final double score;
  final List<int> sources;
}

/// Plans one turn for nation [me].
///
/// The plan in order: make peace where a war leads nowhere, pick on the
/// weakest neighbor when strong enough, attack every enemy province that can
/// be overwhelmed (or mass the army opposite one that cannot yet), walk rear
/// units to the front (or to the border in peacetime) and spend the treasury
/// on the most threatened provinces.
Orders planAi(Game g, int me, Rng rng) {
  final w = g.world;
  final s = g.state;
  final orders = Orders();
  final mine = g.provincesOf(me);
  if (mine.isEmpty) return orders;
  final nationCount = w.nations.length;

  // Strength of every nation: units in the field plus what its gold could buy.
  final power = List.filled(nationCount, 0);
  for (var p = 0; p < s.owner.length; p++) {
    power[s.owner[p]] += s.units[p];
  }
  for (var n = 0; n < nationCount; n++) {
    power[n] += s.gold[n] ~/ Rules.unitCost;
  }

  bool hostile(int p) => s.wars.contains(pairKey(me, s.owner[p]));

  // My provinces by what they touch.
  final threat = <int, int>{};
  final front = <int>[];
  final border = <int>{};
  final neighbors = <int>{};
  for (final p in mine) {
    var danger = 0;
    var touchesEnemy = false;
    for (final q in w.provinces[p].links) {
      final other = s.owner[q];
      if (other == me) continue;
      border.add(p);
      neighbors.add(other);
      if (hostile(q)) {
        touchesEnemy = true;
        danger += s.units[q];
      }
    }
    threat[p] = danger;
    if (touchesEnemy) front.add(p);
  }

  final enemies = [
    for (var n = 0; n < nationCount; n++)
      if (n != me && s.alive[n] && g.atWar(me, n)) n,
  ];

  // ------------------------------------------------------------ peace
  for (final e in enemies) {
    final key = pairKey(me, e);
    final fought = s.turn - (s.warStart[key] ?? s.turn);
    final quiet = s.turn - (s.lastGain[key] ?? s.turn);
    var wantPeace = false;
    if (fought >= Rules.aiMinWarTurns) {
      wantPeace = !neighbors.contains(e) || quiet >= Rules.aiStalemateTurns || power[e] > 2 * power[me];
    }
    if (!wantPeace && g.hasPeaceOffer(e, me)) {
      wantPeace = fought >= 3 && power[me] < 1.3 * power[e];
    }
    if (wantPeace) orders.offerPeace.add(e);
  }

  // ------------------------------------------------------------ war
  var facing = 0;
  var fronts = 0;
  for (final e in enemies) {
    if (!neighbors.contains(e)) continue;
    facing += power[e];
    fronts++;
  }
  if (power[me] > 1.6 * facing) {
    // The longer the peace, the worse the odds it will go to war on.
    final restless = s.turn - s.lastWar[me];
    var victim = -1;
    var bestOdds = Rules.aiWarRatio * (1 - math.min(Rules.aiRestlessMax, restless * Rules.aiRestlessPerTurn));
    for (final n in neighbors.toList()..sort()) {
      if (!g.canDeclareWar(me, n)) continue;
      // A neighbor already fighting others is an easier meal.
      var distracted = 0;
      for (var other = 0; other < nationCount; other++) {
        if (other != me && s.alive[other] && g.atWar(n, other)) distracted++;
      }
      final odds = power[me] / (power[n] + 1) * (1 + 0.2 * math.min(distracted, 2)) / (1 + 0.5 * fronts) * rng.range(0.9, 1.1);
      if (odds > bestOdds) {
        bestOdds = odds;
        victim = n;
      }
    }
    if (victim >= 0 && rng.chance(enemies.isEmpty ? math.min(0.5, 0.12 + restless * 0.01) : 0.04)) orders.declareWar.add(victim);
  }

  // ------------------------------------------------------------ attacks
  final free = {for (final p in mine) p: s.units[p]};
  final targets = <int>{};
  for (final p in front) {
    for (final q in w.provinces[p].links) {
      if (s.owner[q] != me && hostile(q)) targets.add(q);
    }
  }
  final plans = <_Target>[];
  for (final t in targets.toList()..sort()) {
    final sources = [
      for (final q in w.provinces[t].links)
        if (s.owner[q] == me) q,
    ];
    final need = (g.defenseStrength(t) * Rules.aiAttackMargin).ceil() + 1;
    final value = w.provinces[t].income * 2.0 + (g.isCapital(t) ? 12 : 0) + sources.length * 1.5 + rng.nextDouble();
    plans.add(_Target(t, need, value / (need + 3), sources));
  }
  plans.sort((a, b) => b.score.compareTo(a.score));
  for (final plan in plans) {
    // Leave half of what the other enemy neighbors could throw at a source.
    int spare(int p) {
      final others = threat[p]! - s.units[plan.province];
      return math.max(0, free[p]! - (others * 0.5).ceil());
    }

    var pool = 0;
    for (final p in plan.sources) {
      pool += spare(p);
    }
    if (pool < plan.need) continue;
    var toSend = math.min(pool, (plan.need * 1.5).ceil());
    final bySpare = List.of(plan.sources)..sort((a, b) => spare(b) != spare(a) ? spare(b) - spare(a) : a - b);
    for (final p in bySpare) {
      final take = math.min(spare(p), toSend);
      if (take <= 0) continue;
      orders.moves.add(MoveOrder(p, plan.province, take));
      free[p] = free[p]! - take;
      toSend -= take;
    }
  }

  // At war but nowhere strong enough to attack: gather the army opposite the
  // softest enemy province until it is. Without this, two equal powers would
  // line their borders evenly and never move again.
  var staging = -1;
  if (plans.isNotEmpty && orders.moves.isEmpty) {
    final softest = plans.reduce((a, b) => a.need < b.need || (a.need == b.need && a.province < b.province) ? a : b);
    for (final p in softest.sources) {
      if (staging < 0 || free[p]! > free[staging]!) staging = p;
    }
  }

  // ------------------------------------------------------------ marching
  // Steps through my own land to the staging province, else to the nearest
  // front, else (at peace) to the nearest border.
  final goals = staging >= 0 ? [staging] : (front.isNotEmpty ? front : border.toList());
  final distance = <int, int>{for (final p in goals) p: 0};
  final queue = Queue<int>.of(goals);
  while (queue.isNotEmpty) {
    final p = queue.removeFirst();
    for (final q in w.provinces[p].links) {
      if (s.owner[q] != me || distance.containsKey(q)) continue;
      distance[q] = distance[p]! + 1;
      queue.add(q);
    }
  }
  for (final p in mine) {
    final steps = distance[p];
    if (steps == null || steps == 0) continue;
    var keep = border.contains(p) ? 2 : 0;
    if (s.capital[me] == p) keep = 3;
    // The rest of the front stays half as strong as what faces it.
    if (threat[p]! > 0) keep = math.max(keep, (threat[p]! * 0.5).ceil());
    final send = free[p]! - keep;
    if (send <= 0) continue;
    var next = -1;
    for (final q in w.provinces[p].links) {
      if (s.owner[q] != me || distance[q] != steps - 1) continue;
      if (next < 0 || threat[q]! > threat[next]!) next = q;
    }
    if (next < 0) continue;
    orders.moves.add(MoveOrder(p, next, send));
    free[p] = free[p]! - send;
  }

  // ------------------------------------------------------------ recruiting
  // Fill up towards the army the income can pay for; in peacetime hold back
  // and let the treasury grow.
  final income = g.incomeOf(me);
  final mobilised = enemies.isNotEmpty || s.gold[me] > income * Rules.aiFullTreasuryTurns;
  final ceiling = (income * Rules.unitsPerUpkeepGold * (mobilised ? Rules.aiWarArmy : Rules.aiPeaceArmy)).floor();
  var budget = math.min(s.gold[me] ~/ Rules.unitCost, ceiling - g.unitsOf(me));
  if (budget > 0) {
    int gap(int p) => threat[p]! - s.units[p];
    final byNeed = List.of(mine)
      ..sort((a, b) {
        final da = distance[a] ?? 99;
        final db = distance[b] ?? 99;
        if (da != db) return da - db;
        if (gap(a) != gap(b)) return gap(b) - gap(a);
        return a - b;
      });
    for (final p in byNeed) {
      final count = math.min(budget, g.recruitCap(p));
      orders.recruits.add(RecruitOrder(p, count));
      budget -= count;
      if (budget == 0) break;
    }
  }

  return orders;
}
