import 'dart:math' as math;

import 'events.dart';
import 'game.dart';
import 'happenings.dart';
import 'orders.dart';
import 'rng.dart';
import 'rules.dart';
import 'state.dart';

/// One nation's units converging on one province.
class _Attack {
  _Attack(this.nation);

  final int nation;
  int count = 0;

  /// What the units count for: less than [count] when some come by sea.
  double strength = 0;

  /// Where the units came from, so they can fall back.
  final Map<int, int> origins = {};

  void add(int from, int units, {required bool bySea}) {
    count += units;
    strength += bySea ? units * Rules.landingFactor : units;
    origins[from] = (origins[from] ?? 0) + units;
  }
}

/// Resolves one turn for every nation at once and advances [Game.state].
///
/// Order of play: answers to last turn's happenings, diplomacy, recruitment
/// and building, movement, battles, unrest, eliminations, economy, this
/// turn's happenings, victory. [orders] is indexed by nation; null means no
/// orders. Orders the rules do not allow are skipped without failing the
/// turn.
TurnReport resolveTurn(Game g, List<Orders?> orders, Rng rng) {
  final w = g.world;
  final s = g.state;
  final events = <GameEvent>[];
  final turn = s.turn;
  final nationCount = w.nations.length;
  final provinceCount = w.provinces.length;

  Iterable<(int, Orders)> each() sync* {
    for (var n = 0; n < nationCount; n++) {
      final o = orders[n];
      if (o != null && s.alive[n]) yield (n, o);
    }
  }

  // ---------------------------------------------------------- 0. relations
  // Allies grow closer and enemies further apart; the rest forget. This
  // comes first so that what the turn brings is felt in full until the next.
  for (final key in s.relations.keys.toList()) {
    if (s.wars.contains(key) || s.alliances.contains(key) || turn % Rules.relationDriftTurns != 0) continue;
    final (a, b) = pairOf(key);
    s.changeRelation(a, b, -s.relation(a, b).sign);
  }
  for (final key in s.alliances) {
    final (a, b) = pairOf(key);
    if (s.relation(a, b) < Rules.alliedRelation) s.changeRelation(a, b, 1);
  }
  for (final key in s.wars) {
    final (a, b) = pairOf(key);
    s.changeRelation(a, b, -1);
  }

  // ---------------------------------------------------------- 0b. answers
  // What the player chose for last turn's happening, paid before anything
  // else.
  for (final n in s.pending.keys.toList()..sort()) {
    answerPending(g, n, orders[n], events);
  }

  // ---------------------------------------------------------- 1. diplomacy
  // History first: alliances are signed on the spot and wars go ahead of
  // this turn's declarations, as long as they still make sense. The player
  // is never made to go to war, only offered the alliance.
  // A vassal that throws off its overlord is at war with it at once.
  for (final (n, o) in each()) {
    final lord = s.overlord[n];
    if (!o.declareIndependence || lord < 0) continue;
    s.overlord[n] = -1;
    s.openWar(n, lord, turn);
    events.add(GameEvent(EventKind.independence, a: n, b: lord));
  }

  final declarations = <(int, int)>[];
  for (var i = 0; i < w.history.length; i++) {
    final h = w.history[i];
    if (h.turn != turn) continue;
    var happened = false;
    for (final (a, b) in h.alliances) {
      if (!g.canOfferAlliance(a, b)) continue;
      happened = true;
      if (a != s.human && b != s.human) {
        s.alliances.add(pairKey(a, b));
        continue;
      }
      final offer = a == s.human ? directedKey(b, a) : directedKey(a, b);
      s.allianceOffers[offer] = turn + Rules.peaceOfferTurns;
      s.allianceAsked[offer] = turn;
      final (from, to) = pairOf(offer);
      events.add(GameEvent(EventKind.allianceOffered, a: from, b: to));
    }
    for (final (a, b) in h.wars) {
      if (a == s.human || !g.canDeclareWar(a, b)) continue;
      happened = true;
      declarations.add((a, b));
    }
    if (happened) events.add(GameEvent(EventKind.history, n1: i));
  }
  for (final (n, o) in each()) {
    declarations.addAll([for (final target in o.declareWar.toList()..sort()) (n, target)]);
  }

  // A war declared now opens the border next turn, so the attacked side
  // always gets one turn to react. The allies of the attacked side join at
  // once, on the same terms.
  final warsBefore = Set.of(s.wars);
  for (final (n, target) in declarations) {
    if (!g.canDeclareWar(n, target)) continue;
    final defenders = g.wouldDefend(n, target);
    s.openWar(n, target, turn);
    events.add(GameEvent(EventKind.warDeclared, a: n, b: target));
    for (final ally in defenders) {
      s.openWar(ally, n, turn);
      events.add(GameEvent(EventKind.calledToArms, a: ally, b: n, n1: target));
    }
  }
  // Leaving an alliance comes after the declarations, so nobody can break
  // with an ally and attack it in the same turn.
  for (final (n, o) in each()) {
    for (final ally in o.breakAlliance.toList()..sort()) {
      if (!g.allied(n, ally)) continue;
      s.alliances.remove(pairKey(n, ally));
      s.changeRelation(n, ally, Rules.brokenRelation);
      events.add(GameEvent(EventKind.allianceBroken, a: n, b: ally));
    }
  }
  _matchOffers(
    g,
    [for (final (n, o) in each()) (n, o.offerAlliance)],
    s.allianceOffers,
    s.allianceAsked,
    g.canOfferAlliance,
    (key) => s.alliances.add(key),
    EventKind.allianceSigned,
    EventKind.allianceOffered,
    events,
  );
  _matchOffers(
    g,
    [for (final (n, o) in each()) (n, o.offerPact)],
    s.pactOffers,
    s.pactAsked,
    g.canOfferPact,
    (key) => s.pacts[key] = turn + 1 + Rules.pactTurns,
    EventKind.pactSigned,
    EventKind.pactOffered,
    events,
  );

  // Envoys and gifts, paid before the recruits.
  for (final (n, o) in each()) {
    for (final target in o.envoys.toList()..sort()) {
      final cost = g.envoyCost(target);
      if (!g.canCourt(n, target) || s.gold[n] < cost) continue;
      s.gold[n] -= cost;
      s.changeRelation(n, target, Rules.envoyGain);
      events.add(GameEvent(EventKind.envoy, a: n, b: target, n1: cost, n2: Rules.envoyGain));
    }
    for (final target in o.gifts.keys.toList()..sort()) {
      final gold = math.min(o.gifts[target]!, s.gold[n]);
      if (!g.canCourt(n, target) || gold <= 0) continue;
      final gain = g.giftGain(target, gold);
      s.gold[n] -= gold;
      s.gold[target] += gold;
      s.changeRelation(n, target, gain);
      events.add(GameEvent(EventKind.gift, a: n, b: target, n1: gold, n2: gain));
    }
  }

  for (final (n, o) in each()) {
    final plan = o.research;
    if (plan == null || !Rules.researchShares.contains(plan.share)) continue;
    s.researchFocus[n] = plan.field.index;
    s.researchShare[n] = plan.share;
  }

  final freshOffers = <int>{};
  for (final (n, o) in each()) {
    for (final target in o.offerPeace) {
      if (target < 0 || target >= nationCount) continue;
      final key = pairKey(n, target);
      if (!warsBefore.contains(key) || !s.wars.contains(key)) continue;
      final terms = o.peaceTerms[target] ?? Terms.white;
      if (!g.canDemand(n, target, terms)) continue;
      final offer = directedKey(n, target);
      if (!s.peaceOffers.containsKey(offer) || g.peaceTermsOf(n, target) != terms) freshOffers.add(offer);
      s.peaceOffers[offer] = turn + Rules.peaceOfferTurns;
      if (terms == Terms.white) {
        s.peaceTerms.remove(offer);
      } else {
        s.peaceTerms[offer] = terms.index;
      }
    }
  }
  // Peace is signed when the two offers agree: both white, or one asks and
  // the other accepts.
  for (final key in s.wars.toList()..sort()) {
    final (a, b) = pairOf(key);
    final ab = directedKey(a, b);
    final ba = directedKey(b, a);
    final agreed = s.peaceOffers.containsKey(ab) && s.peaceOffers.containsKey(ba) ? _agreement(g.peaceTermsOf(a, b), g.peaceTermsOf(b, a)) : null;
    if (agreed == null) {
      if (freshOffers.contains(ab)) events.add(GameEvent(EventKind.peaceOffered, a: a, b: b, n1: g.peaceTermsOf(a, b).index));
      if (freshOffers.contains(ba)) events.add(GameEvent(EventKind.peaceOffered, a: b, b: a, n1: g.peaceTermsOf(b, a).index));
      continue;
    }
    // The side whose terms were met, if any.
    final winner = agreed == Terms.white ? -1 : (g.peaceTermsOf(a, b) == agreed ? a : b);
    final loser = winner == a ? b : a;
    s.closeWar(a, b, turn, Rules.truceTurns);
    if (winner >= 0) s.changeRelation(a, b, Rules.termsRelation);
    switch (agreed) {
      case Terms.reparations:
        s.tribute[directedKey(loser, winner)] = turn + 1 + Rules.reparationTurns;
      case Terms.vassal:
        s.overlord[loser] = winner;
        s.alliances.removeWhere((k) {
          final (x, y) = pairOf(k);
          return x == loser || y == loser;
        });
      case Terms.white || Terms.accept:
        break;
    }
    events.add(GameEvent(EventKind.peaceSigned, a: a, b: b, n1: agreed.index, n2: winner));
  }

  // Vassals follow their overlords into every war, and fight none of their
  // own.
  for (var v = 0; v < nationCount; v++) {
    final lord = s.overlord[v];
    if (lord < 0 || !s.alive[v] || !s.alive[lord]) continue;
    for (final key in s.wars.toList()..sort()) {
      final (a, b) = pairOf(key);
      final enemy = a == lord ? b : (b == lord ? a : -1);
      if (enemy < 0 || enemy == v || g.atWar(v, enemy)) continue;
      s.openWar(v, enemy, turn);
      events.add(GameEvent(EventKind.calledToArms, a: v, b: enemy, n1: lord));
    }
    for (final key in s.wars.toList()..sort()) {
      final (a, b) = pairOf(key);
      final enemy = a == v ? b : (b == v ? a : -1);
      if (enemy < 0 || g.atWar(lord, enemy)) continue;
      s.closeWar(v, enemy, turn, Rules.truceTurns);
      events.add(GameEvent(EventKind.peaceSigned, a: math.min(v, enemy), b: math.max(v, enemy), n2: -1));
    }
  }

  // ---------------------------------------------------------- 2. recruitment and building
  // New units stand in their province this turn and can defend it, but only
  // units that began the turn there may march.
  final startUnits = List.of(s.units);
  final recruited = List.filled(provinceCount, 0);
  for (final (n, o) in each()) {
    for (final r in o.recruits) {
      final p = r.province;
      if (p < 0 || p >= provinceCount || s.owner[p] != n) continue;
      final count = math.min(math.min(r.count, g.recruitCap(p) - recruited[p]), s.gold[n] ~/ Rules.unitCost);
      if (count <= 0) continue;
      s.units[p] += count;
      s.gold[n] -= count * Rules.unitCost;
      recruited[p] += count;
    }
  }

  // Building, one project per province, paid after the recruits.
  final built = List.filled(provinceCount, false);
  for (final (n, o) in each()) {
    for (final b in o.builds) {
      final p = b.province;
      if (p < 0 || p >= provinceCount || s.owner[p] != n || built[p]) continue;
      final cost = g.buildCost(p, b.project);
      if (cost < 0 || s.gold[n] < cost) continue;
      s.gold[n] -= cost;
      built[p] = true;
      switch (b.project) {
        case Project.fortify:
          s.forts[p]++;
        case Project.develop:
          s.development[p]++;
      }
    }
  }

  // ---------------------------------------------------------- 3. movement
  final moved = List.filled(provinceCount, 0);
  final arrivals = List.filled(provinceCount, 0);
  final attacks = <int, Map<int, _Attack>>{};
  final movements = <Movement>[];
  for (final (n, o) in each()) {
    for (final m in o.moves) {
      if (m.from < 0 || m.from >= provinceCount || m.to < 0 || m.to >= provinceCount) continue;
      if (s.owner[m.from] != n || !w.reaches(m.from, m.to)) continue;
      final bySea = !w.provinces[m.from].links.contains(m.to);
      final count = math.min(m.count, startUnits[m.from] - moved[m.from]);
      if (count <= 0) continue;
      final target = s.owner[m.to];
      if (target == n) {
        arrivals[m.to] += count;
      } else {
        final key = pairKey(n, target);
        if (!warsBefore.contains(key) || !s.wars.contains(key)) continue;
        attacks.putIfAbsent(m.to, () => {}).putIfAbsent(n, () => _Attack(n)).add(m.from, count, bySea: bySea);
      }
      moved[m.from] += count;
      s.units[m.from] -= count;
      movements.add(Movement(n, m.from, m.to, count, hostile: target != n, bySea: bySea));
    }
  }
  // Reinforcements arrive before the enemy does.
  for (var p = 0; p < provinceCount; p++) {
    s.units[p] += arrivals[p];
  }

  // ---------------------------------------------------------- 4. battles
  for (final p in attacks.keys.toList()..sort()) {
    final attackers = attacks[p]!.values.toList()..sort((x, y) => x.count != y.count ? y.count - x.count : x.nation - y.nation);
    final original = s.owner[p];
    var holder = original;
    var holderUnits = s.units[p];
    for (final a in attackers) {
      if (!s.wars.contains(pairKey(a.nation, holder))) {
        // Someone they are not fighting got there first: fall back, if home
        // is still theirs.
        for (final origin in a.origins.entries) {
          if (s.owner[origin.key] == a.nation) s.units[origin.key] += origin.value;
        }
        continue;
      }
      // Only the side that held the province all along is dug in and has
      // the locals on its side.
      final dugIn = holder == original;
      final militia = dugIn ? g.militia(p) : 0;
      final defenders = holderUnits + militia;
      if (defenders == 0) {
        holder = a.nation;
        holderUnits = a.count;
        continue;
      }
      final cover = dugIn ? g.defenseMultiplier(p) : 1.0;
      final rollA = rng.range(1 - Rules.combatSpread, 1 + Rules.combatSpread) * g.armyFactor(a.nation);
      final rollD = rng.range(1 - Rules.combatSpread, 1 + Rules.combatSpread) * g.armyFactor(holder);
      final attack = a.strength * rollA;
      final defense = defenders * cover * rollD;
      final attackerWon = attack > defense;
      final int survivors;
      if (attackerWon) {
        // What is left of the attack, in units: its unspent share.
        survivors = (a.count * (attack - defense) / attack).round().clamp(1, a.count);
      } else {
        survivors = ((defense - attack) / (cover * rollD)).round().clamp(1, defenders);
      }
      events.add(GameEvent(EventKind.battle, a: a.nation, b: holder, province: p, n1: a.count, n2: defenders, n3: survivors, flag: attackerWon));
      if (attackerWon) {
        holder = a.nation;
        holderUnits = survivors;
      } else {
        // Losses fall on regulars and militia alike.
        holderUnits = (holderUnits * survivors / defenders).round();
      }
    }
    s.units[p] = holderUnits;
    if (holder != original) {
      s.owner[p] = holder;
      s.heldSince[p] = turn;
      // A siege leaves the walls a level lower.
      if (s.forts[p] > 0) s.forts[p]--;
      s.lastGain[pairKey(holder, original)] = turn;
      s.gains.update(directedKey(holder, original), (n) => n + 1, ifAbsent: () => 1);
      events.add(GameEvent(EventKind.captured, a: holder, b: original, province: p));
    }
  }

  // ---------------------------------------------------------- 4b. unrest
  // Land taken recently and left unguarded may rise: back to its old owner
  // at war with the holder, or as the old owner itself, risen from defeat.
  for (var p = 0; p < provinceCount; p++) {
    if (s.heldSince[p] == turn) continue;
    final chance = g.revoltChance(p);
    if (chance <= 0 || !rng.chance(chance)) continue;
    final holder = s.owner[p];
    final rebel = w.startOwners[p];
    final reborn = !s.alive[rebel];
    final rebels = (g.militia(p) * Rules.rebelsPerMilitia).ceil();
    s.owner[p] = rebel;
    s.units[p] = rebels;
    s.heldSince[p] = turn;
    if (reborn) {
      s.alive[rebel] = true;
      s.capital[rebel] = p;
      s.gold[rebel] = 0;
      s.openWar(rebel, holder, turn);
    } else {
      s.lastGain[pairKey(rebel, holder)] = turn;
      s.gains.update(directedKey(rebel, holder), (n) => n + 1, ifAbsent: () => 1);
    }
    events.add(GameEvent(EventKind.revolt, a: rebel, b: holder, province: p, n1: rebels, flag: reborn));
  }

  // ---------------------------------------------------------- 5. eliminations
  final held = List.filled(nationCount, 0);
  for (final o in s.owner) {
    held[o]++;
  }
  for (var n = 0; n < nationCount; n++) {
    if (!s.alive[n]) continue;
    if (held[n] == 0) {
      final conqueror = events.lastWhere((e) => (e.kind == EventKind.captured || e.kind == EventKind.revolt) && e.b == n, orElse: () => const GameEvent(EventKind.captured)).a;
      s.alive[n] = false;
      s.gold[n] = 0;
      s.capital[n] = -1;
      s.forgetNation(n);
      events.add(GameEvent(EventKind.eliminated, a: n, b: conqueror));
    } else if (s.owner[s.capital[n]] != n) {
      var best = -1;
      for (var p = 0; p < provinceCount; p++) {
        if (s.owner[p] == n && (best < 0 || g.provinceIncome(p) > g.provinceIncome(best))) best = p;
      }
      s.capital[n] = best;
      events.add(GameEvent(EventKind.capitalMoved, a: n, province: best));
    }
  }

  // ---------------------------------------------------------- 6. economy
  // Reparations and tribute come out of the income before upkeep.
  final incomes = [for (var n = 0; n < nationCount; n++) s.alive[n] ? g.incomeOf(n) : 0];
  for (var n = 0; n < nationCount; n++) {
    if (!s.alive[n]) continue;
    final income = incomes[n];
    s.gold[n] += income - g.tributeOwed(n, incomes) - g.upkeepOf(n);
    if (s.gold[n] >= 0) {
      _payResearch(g, n, income, events);
      continue;
    }
    // Unpaid soldiers go home: one unit for every gold piece missing.
    final total = g.unitsOf(n);
    final leaving = math.min(-s.gold[n], total);
    s.gold[n] = 0;
    if (leaving == 0) continue;
    // Every province loses its share; what rounding leaves over comes off
    // the largest stacks, one unit at a time.
    var left = leaving;
    final stacks = <int>[];
    for (var p = 0; p < provinceCount; p++) {
      if (s.owner[p] != n) continue;
      final cut = s.units[p] * leaving ~/ total;
      s.units[p] -= cut;
      left -= cut;
      stacks.add(p);
    }
    stacks.sort((a, b) => s.units[b] != s.units[a] ? s.units[b] - s.units[a] : a - b);
    for (var i = 0; left > 0; i = (i + 1) % stacks.length) {
      if (s.units[stacks[i]] == 0) continue;
      s.units[stacks[i]]--;
      left--;
    }
    events.add(GameEvent(EventKind.desertion, a: n, n1: leaving));
  }

  // ---------------------------------------------------------- 6b. happenings
  if (s.randomEvents) rollHappenings(g, rng, events);

  // ---------------------------------------------------------- 7. victory
  if (!s.ended && !s.sandbox) {
    // A vassal's land counts for its overlord, and only a free nation wins.
    final realm = List.of(held);
    for (var n = 0; n < nationCount; n++) {
      if (s.alive[n] && s.overlord[n] >= 0) realm[s.overlord[n]] += held[n];
    }
    var leader = -1;
    var free = 0;
    for (var n = 0; n < nationCount; n++) {
      if (!s.alive[n] || s.overlord[n] >= 0) continue;
      free++;
      if (leader < 0 || realm[n] > realm[leader]) leader = n;
    }
    if (realm[leader] >= g.winTarget || free == 1) {
      s.ended = true;
      s.winner = leader;
      events.add(GameEvent(EventKind.gameOver, a: leader));
    } else if (s.human >= 0 && !s.alive[s.human]) {
      s.ended = true;
      s.winner = -1;
      events.add(const GameEvent(EventKind.gameOver));
    }
  }

  s.turn = turn + 1;
  s.peaceOffers.removeWhere((_, lapses) => lapses <= s.turn);
  s.allianceOffers.removeWhere((_, lapses) => lapses <= s.turn);
  s.allianceAsked.removeWhere((_, asked) => asked + Rules.aiAllianceRetryTurns <= s.turn);
  s.pactOffers.removeWhere((_, lapses) => lapses <= s.turn);
  s.pactAsked.removeWhere((_, asked) => asked + Rules.aiAllianceRetryTurns <= s.turn);
  s.pacts.removeWhere((_, until) => until <= s.turn);
  s.tribute.removeWhere((_, until) => until <= s.turn);
  for (final key in s.wars) {
    final (a, b) = pairOf(key);
    s.lastWar[a] = s.turn;
    s.lastWar[b] = s.turn;
  }
  g.recordChronicle();
  return TurnReport(turn, events, movements);
}

/// Records this turn's offers of one kind, [wanted] by each nation, and
/// signs every pair whose offers cross while [allowed]; [sign] takes the
/// pair's [pairKey]. New offers that are not signed yet are reported.
void _matchOffers(
  Game g,
  List<(int, Set<int>)> wanted,
  Map<int, int> offers,
  Map<int, int> asked,
  bool Function(int, int) allowed,
  void Function(int key) sign,
  EventKind signedKind,
  EventKind offeredKind,
  List<GameEvent> events,
) {
  final turn = g.state.turn;
  final fresh = <int>{};
  for (final (n, targets) in wanted) {
    for (final target in targets) {
      if (!allowed(n, target)) continue;
      final offer = directedKey(n, target);
      if (!offers.containsKey(offer)) fresh.add(offer);
      offers[offer] = turn + Rules.peaceOfferTurns;
      asked[offer] = turn;
    }
  }
  final signed = <int>{};
  for (final offer in offers.keys.toList()..sort()) {
    final (from, to) = pairOf(offer);
    final key = pairKey(from, to);
    if (signed.contains(key)) continue;
    if (offers.containsKey(directedKey(to, from)) && allowed(from, to)) {
      signed.add(key);
      sign(key);
      offers.remove(offer);
      offers.remove(directedKey(to, from));
      events.add(GameEvent(signedKind, a: math.min(from, to), b: math.max(from, to)));
    } else if (fresh.contains(offer)) {
      events.add(GameEvent(offeredKind, a: from, b: to));
    }
  }
}

/// The terms two peace offers agree on, or null when they do not: both
/// white, or one side asks and the other accepts. Accepting a white offer is
/// white peace.
Terms? _agreement(Terms ab, Terms ba) {
  bool demands(Terms t) => t == Terms.reparations || t == Terms.vassal;
  if (demands(ab) && demands(ba)) return null;
  if (demands(ab)) return ba == Terms.accept ? ab : null;
  if (demands(ba)) return ab == Terms.accept ? ba : null;
  return Terms.white;
}

/// Pays [n]'s research out of what the treasury holds after upkeep, so it
/// never sends anyone home, and raises the level when it is paid for.
void _payResearch(Game g, int n, int income, List<GameEvent> events) {
  final s = g.state;
  final field = Field.values[s.researchFocus[n]];
  final spend = math.min(g.researchSpend(n, income: income), s.gold[n]);
  final cost = g.researchCost(n, field, income: income);
  if (spend <= 0 || cost < 0) return;
  s.gold[n] -= spend;
  s.research[n][field.index] += spend;
  if (s.research[n][field.index] < cost) return;
  s.research[n][field.index] -= cost;
  s.tech[n][field.index]++;
  events.add(GameEvent(EventKind.techAdvanced, a: n, n1: field.index, n2: s.tech[n][field.index]));
}
