import 'dart:collection';
import 'dart:math' as math;

import 'game.dart';
import 'orders.dart';
import 'rng.dart';
import 'rules.dart';
import 'state.dart';

/// What every AI nation sees the same way in a turn, worked out once for
/// all of them: orders do not change the state until the turn resolves.
class Outlook {
  Outlook(Game g)
      : power = List.filled(g.world.nations.length, 0),
        neighbors = g.neighborsOfAll(),
        allies = List.generate(g.world.nations.length, (_) => <int>[]) {
    final s = g.state;
    // Strength: units in the field plus what the gold could buy, each worth
    // what its army technology makes it.
    for (var p = 0; p < s.owner.length; p++) {
      power[s.owner[p]] += s.units[p];
    }
    for (var n = 0; n < power.length; n++) {
      power[n] = ((power[n] + s.gold[n] ~/ Rules.unitCost) * g.armyFactor(n)).round();
    }
    for (final key in s.alliances.toList()..sort()) {
      final (a, b) = pairOf(key);
      allies[a].add(b);
      allies[b].add(a);
    }
  }

  final List<int> power;

  /// [Game.neighborsOfAll].
  final List<Set<int>> neighbors;

  /// [Game.alliesOf] for every nation, in id order.
  final List<List<int>> allies;
}

class _Target {
  _Target(this.province, this.need, this.score, this.sources, this.bySea);

  final int province;

  /// Strength to send, in units marching overland.
  final int need;
  final double score;

  /// My provinces that can reach it, overland first.
  final List<int> sources;

  /// Those of [sources] that would have to land from the sea.
  final Set<int> bySea;

  /// What a unit from [p] counts for in the attack.
  double weight(int p) => bySea.contains(p) ? Rules.landingFactor : 1;
}

/// Share of the armies across the sea that a coastal province guards
/// against: they could land, but weaker and not everywhere at once.
const double _seaThreat = 0.4;

/// Plans one turn for nation [me].
///
/// The plan in order: make peace where a war leads nowhere, seek allies
/// against a shared threat, pick on the weakest neighbor when strong enough, attack every enemy province that can
/// be overwhelmed (or mass the army opposite one that cannot yet), walk rear
/// units to the front (or to the border in peacetime) and spend the treasury
/// on the most threatened provinces.
///
/// [outlook] is shared by every nation planning on the same position; it is
/// worked out here when not given.
Orders planAi(Game g, int me, Rng rng, [Outlook? outlook]) {
  final w = g.world;
  final s = g.state;
  final orders = Orders();
  final mine = g.provincesOf(me);
  if (mine.isEmpty) return orders;
  final nationCount = w.nations.length;
  final view = outlook ?? Outlook(g);
  final power = view.power;

  bool hostile(int p) => s.wars.contains(pairKey(me, s.owner[p]));

  // My provinces by what they touch, overland and across the sea.
  final threat = <int, int>{};
  final front = <int>[];
  final border = <int>{};
  final neighbors = <int>{};
  final reach = <int>{};
  for (final p in mine) {
    var danger = 0.0;
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
    for (final q in w.landings[p]) {
      final other = s.owner[q];
      if (other == me) continue;
      reach.add(other);
      if (hostile(q)) {
        touchesEnemy = true;
        danger += s.units[q] * _seaThreat;
      }
    }
    threat[p] = danger.round();
    if (touchesEnemy) front.add(p);
  }
  reach.addAll(neighbors);

  final enemies = [
    for (var n = 0; n < nationCount; n++)
      if (n != me && s.alive[n] && g.atWar(me, n)) n,
  ];

  // ------------------------------------------------------------ vassalage
  // A vassal fights its overlord's wars and makes no peace of its own; it
  // throws the overlord off once strong enough.
  final lord = s.overlord[me];
  if (lord >= 0 && power[me] > Rules.aiIndependence * power[lord] && rng.chance(0.15)) orders.declareIndependence = true;

  // ------------------------------------------------------------ peace
  final myProvinces = mine.length;
  for (final e in lord >= 0 ? const <int>[] : enemies) {
    final key = pairKey(me, e);
    final fought = s.turn - (s.warStart[key] ?? s.turn);
    final quiet = s.turn - (s.lastGain[key] ?? s.turn);
    final score = g.warScore(me, e);
    final theirs = g.hasPeaceOffer(e, me) ? g.peaceTermsOf(e, me) : null;

    // Asked for terms: give in only when beaten.
    if (theirs == Terms.reparations || theirs == Terms.vassal) {
      final beaten = theirs == Terms.reparations ? (score <= -2 && power[me] < power[e]) || power[me] * 2 < power[e] : power[me] * 3 < power[e] && myProvinces <= 4;
      if (beaten) {
        orders.offerPeace.add(e);
        orders.peaceTerms[e] = Terms.accept;
      }
      continue;
    }

    // Winning: ask for terms once the war has run a while.
    var demand = Terms.white;
    if (score >= 3 && power[me] > 1.5 * power[e]) demand = Terms.reparations;
    if (power[e] * 3 < power[me] && g.provinceCount(e) <= 3 && g.canDemand(me, e, Terms.vassal)) demand = Terms.vassal;
    if (demand != Terms.white && fought >= Rules.aiMinWarTurns && (quiet >= 4 || theirs != null)) {
      orders.offerPeace.add(e);
      orders.peaceTerms[e] = demand;
      continue;
    }

    var wantPeace = false;
    if (fought >= Rules.aiMinWarTurns) {
      wantPeace = !reach.contains(e) || quiet >= Rules.aiStalemateTurns || power[e] > 2 * power[me];
    }
    if (!wantPeace && theirs != null) {
      wantPeace = fought >= 3 && power[me] < 1.3 * power[e];
    }
    if (wantPeace) orders.offerPeace.add(e);
  }

  // ------------------------------------------------------------ alliances
  // [t] worries [n] when they are at war or [t] is a stronger neighbor.
  final neighborhood = view.neighbors;
  bool worries(int t, int n) => g.atWar(n, t) || (power[t] > power[n] && neighborhood[n].contains(t));
  final allies = view.allies[me];
  final worriers = [
    for (var t = 0; t < nationCount; t++)
      if (t != me && s.alive[t] && worries(t, me)) t,
  ];
  // A weak neighbor may be worth a war one day: no pact or alliance with it.
  bool prey(int c) => neighborhood[me].contains(c) && power[me] > Rules.aiWarRatio * (power[c] + 1);
  // A partner is worth having when something worries us both, or, when it
  // [asked], when it is a friend. Never one at war with an ally, never one
  // disliked, and never prey.
  bool worthAllying(int c, {bool asked = false}) {
    for (final a in allies) {
      if (g.atWar(a, c)) return false;
    }
    final liking = s.relation(me, c);
    if (prey(c) || liking < Rules.aiAllyRelation) return false;
    if (asked && liking >= Rules.aiFriendRelation) return true;
    for (final t in worriers) {
      if (t != c && worries(t, c)) return true;
    }
    return false;
  }

  // The cheap tests go first: canOfferAlliance looks at every nation.
  var allyCount = allies.length;
  for (var c = 0; c < nationCount; c++) {
    if (allyCount >= Rules.aiMaxAlliances) break;
    if (g.hasAllianceOffer(c, me) && worthAllying(c, asked: true) && g.canOfferAlliance(me, c)) {
      orders.offerAlliance.add(c);
      allyCount++;
    }
  }
  if (allyCount < Rules.aiMaxAlliances && rng.chance(0.15)) {
    var partner = -1;
    for (var c = 0; c < nationCount; c++) {
      if (g.askedRecently(me, c) || orders.offerAlliance.contains(c) || !worthAllying(c) || !g.canOfferAlliance(me, c)) continue;
      if (partner < 0 || power[c] > power[partner]) partner = c;
    }
    if (partner >= 0) orders.offerAlliance.add(partner);
  }
  // An alliance that no longer guards against anything does not outlast a
  // long peace: sooner or later the restless side lets it go.
  final restless = s.turn - s.lastWar[me];
  for (final a in allies) {
    if (enemies.isEmpty && restless >= 12 && !worthAllying(a) && rng.chance(0.1)) orders.breakAlliance.add(a);
  }

  // ------------------------------------------------------------ pacts
  // A pact with a stronger neighbor buys time. One is signed with anyone
  // liked well enough who asks, while a war elsewhere needs the flank kept
  // quiet or the asker is the stronger; never with prey, and never just to
  // tie my own hands.
  for (var c = 0; c < nationCount; c++) {
    if (!g.hasPactOffer(c, me) || prey(c) || s.relation(me, c) < Rules.aiPactRelation || !g.canOfferPact(me, c)) continue;
    if (enemies.isNotEmpty || power[c] > power[me]) orders.offerPact.add(c);
  }
  if (lord < 0 && rng.chance(0.1)) {
    var partner = -1;
    for (final c in neighborhood[me].toList()..sort()) {
      if (power[c] <= power[me] || orders.offerPact.contains(c) || g.askedPactRecently(me, c) || s.relation(me, c) < Rules.aiPactRelation || !g.canOfferPact(me, c)) continue;
      if (partner < 0 || power[c] > power[partner]) partner = c;
    }
    if (partner >= 0) orders.offerPact.add(partner);
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
    var victim = -1;
    var bestOdds = Rules.aiWarRatio * (1 - math.min(Rules.aiRestlessMax, restless * Rules.aiRestlessPerTurn));
    for (final n in neighbors.toList()..sort()) {
      if (!g.canDeclareWar(me, n)) continue;
      // A neighbor already fighting others is an easier meal, above all one
      // fighting my allies. Its own allies come to its aid, at full weight
      // when they can reach me.
      var distracted = 0;
      var withAllies = false;
      for (var other = 0; other < nationCount; other++) {
        if (other == me || !s.alive[other] || !g.atWar(n, other)) continue;
        distracted++;
        if (g.allied(me, other)) withAllies = true;
      }
      var defence = power[n].toDouble();
      for (final ally in g.wouldDefend(me, n, view.allies[n])) {
        defence += power[ally] * (neighborhood[me].contains(ally) ? 1 : 0.3);
      }
      // Friends are spared, and old enemies sought out.
      final grudge = 1 - s.relation(me, n) / (4 * Rules.maxRelation);
      final odds = power[me] / (defence + 1) * (1 + 0.2 * math.min(distracted, 2)) * (withAllies ? 1.3 : 1) / (1 + 0.5 * fronts) * grudge * rng.range(0.9, 1.1);
      if (odds > bestOdds) {
        bestOdds = odds;
        victim = n;
      }
    }
    final eagerness = (enemies.isEmpty ? math.min(0.5, 0.12 + restless * 0.01) : 0.04) * w.aggression;
    if (victim >= 0 && rng.chance(eagerness)) orders.declareWar.add(victim);
  }

  // ------------------------------------------------------------ attacks
  final free = {for (final p in mine) p: s.units[p]};
  final targets = <int>{};
  for (final p in front) {
    for (final q in [...w.provinces[p].links, ...w.landings[p]]) {
      if (s.owner[q] != me && hostile(q)) targets.add(q);
    }
  }
  final plans = <_Target>[];
  for (final t in targets.toList()..sort()) {
    final overland = [
      for (final q in w.provinces[t].links)
        if (s.owner[q] == me) q,
    ];
    final bySea = {
      for (final q in w.landings[t])
        if (s.owner[q] == me) q,
    };
    final need = (g.defenseStrength(t) * Rules.aiAttackMargin / g.armyFactor(me)).ceil() + 1;
    final value = g.fullIncome(t) * 2.0 + (g.isCapital(t) ? 12 : 0) + overland.length * 1.5 + bySea.length * 0.5 + rng.nextDouble();
    plans.add(_Target(t, need, value / (need + 3), [...overland, ...bySea.toList()..sort()], bySea));
  }
  plans.sort((a, b) => b.score.compareTo(a.score));
  for (final plan in plans) {
    // Leave half of what the other enemy neighbors could throw at a source.
    int spare(int p) {
      final others = threat[p]! - s.units[plan.province];
      return math.max(0, free[p]! - (others * 0.5).ceil());
    }

    var pool = 0.0;
    for (final p in plan.sources) {
      pool += spare(p) * plan.weight(p);
    }
    if (pool < plan.need) continue;
    // Overland first, then the largest spare.
    var toSend = math.min(pool, plan.need * 1.5);
    final order = List.of(plan.sources)
      ..sort((a, b) {
        if (plan.weight(a) != plan.weight(b)) return plan.weight(b).compareTo(plan.weight(a));
        return spare(b) != spare(a) ? spare(b) - spare(a) : a - b;
      });
    for (final p in order) {
      if (toSend <= 0) break;
      final take = math.min(spare(p), (toSend / plan.weight(p)).ceil());
      if (take <= 0) continue;
      orders.moves.add(MoveOrder(p, plan.province, take));
      free[p] = free[p]! - take;
      toSend -= take * plan.weight(p);
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
    // Fresh conquests need a garrison as strong as the militia, or they rise.
    if (g.isOccupied(p)) keep = math.max(keep, g.militia(p));
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

  // ------------------------------------------------------------ research
  // Arms while threatened, industry while safe, and less of either at war.
  final income = g.incomeOf(me);
  var threatened = enemies.isNotEmpty;
  for (final n in neighbors) {
    if (power[n] > power[me] && !g.allied(me, n)) threatened = true;
  }
  final army = g.techLevel(me, Field.army);
  final industry = g.techLevel(me, Field.industry);
  final field = threatened ? (army <= industry + 1 ? Field.army : Field.industry) : (industry <= army + 1 ? Field.industry : Field.army);
  final share = enemies.isEmpty ? Rules.aiResearchPeace : Rules.aiResearchWar;
  if (field.index != s.researchFocus[me] || share != s.researchShare[me]) orders.research = ResearchPlan(field, share);

  // ------------------------------------------------------------ envoys
  // At peace with gold to spare, court the strongest power that worries
  // me, or an ally, while they are not yet friends.
  var purse = s.gold[me];
  if (enemies.isEmpty && purse > income * 4 && rng.chance(0.15)) {
    var courted = -1;
    for (final c in [...worriers, ...allies]..sort()) {
      if (s.relation(me, c) >= Rules.aiFriendRelation || !g.canCourt(me, c)) continue;
      if (courted < 0 || power[c] > power[courted]) courted = c;
    }
    if (courted >= 0) {
      orders.envoys.add(courted);
      purse -= g.envoyCost(courted);
    }
  }

  // ------------------------------------------------------------ recruiting
  // Fill up towards the army what the income can pay for once research and
  // forts are paid; in peacetime hold back and let the treasury grow.
  var troops = 0;
  var forts = 0;
  for (final p in mine) {
    troops += s.units[p];
    forts += s.forts[p];
  }
  final mobilised = enemies.isNotEmpty || s.gold[me] > income * Rules.aiFullTreasuryTurns;
  final payable = income - g.researchSpend(me, share: share, income: income) - forts * Rules.fortUpkeep;
  final ceiling = (payable * Rules.unitsPerUpkeepGold * (mobilised ? Rules.aiWarArmy : Rules.aiPeaceArmy)).floor();
  var budget = math.min(purse ~/ Rules.unitCost, ceiling - troops);
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
      purse -= count * Rules.unitCost;
      if (budget == 0) break;
    }
  }

  // ------------------------------------------------------------ building
  // What the army leaves over, less a month's income kept in hand, goes into
  // the land: walls where the enemy masses beyond what the garrison can
  // hold, and development in the quiet heartland.
  purse -= income;
  var bestFort = -1;
  var bestDanger = 0.8;
  for (final p in mine) {
    final danger = threat[p]! / (g.defenseStrength(p) + 1) * (g.isCapital(p) ? 2 : 1);
    if (danger > bestDanger && g.buildCost(p, Project.fortify) > 0) {
      bestDanger = danger;
      bestFort = p;
    }
  }
  if (bestFort >= 0 && g.buildCost(bestFort, Project.fortify) <= purse) {
    orders.builds.add(BuildOrder(bestFort, Project.fortify));
    purse -= g.buildCost(bestFort, Project.fortify);
  }
  final quiet = [
    for (final p in mine)
      if (threat[p] == 0 && !g.isOccupied(p) && g.buildCost(p, Project.develop) > 0 && p != bestFort) p,
  ]..sort((a, b) {
      final ca = g.buildCost(a, Project.develop);
      final cb = g.buildCost(b, Project.develop);
      if (ca != cb) return ca - cb;
      if (g.fullIncome(a) != g.fullIncome(b)) return g.fullIncome(b) - g.fullIncome(a);
      return a - b;
    });
  for (final p in quiet.take(enemies.isEmpty ? 3 : 1)) {
    final cost = g.buildCost(p, Project.develop);
    if (cost > purse) break;
    orders.builds.add(BuildOrder(p, Project.develop));
    purse -= cost;
  }

  return orders;
}
