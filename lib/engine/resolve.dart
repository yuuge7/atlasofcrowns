import 'dart:math' as math;

import 'events.dart';
import 'game.dart';
import 'orders.dart';
import 'rng.dart';
import 'rules.dart';
import 'state.dart';

/// One nation's units converging on one province.
class _Attack {
  _Attack(this.nation);

  final int nation;
  int count = 0;

  /// Where the units came from, so they can fall back.
  final Map<int, int> origins = {};

  void add(int from, int units) {
    count += units;
    origins[from] = (origins[from] ?? 0) + units;
  }
}

/// Resolves one turn for every nation at once and advances [Game.state].
///
/// Order of play: diplomacy, recruitment, movement, battles, eliminations,
/// economy, victory. [orders] is indexed by nation; null means no orders.
/// Orders the rules do not allow are skipped without failing the turn.
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

  // ---------------------------------------------------------- 1. diplomacy
  // A war declared now opens the border next turn, so the attacked side
  // always gets one turn to react.
  final warsBefore = Set.of(s.wars);
  for (final (n, o) in each()) {
    for (final target in o.declareWar) {
      if (!g.canDeclareWar(n, target)) continue;
      final key = pairKey(n, target);
      s.wars.add(key);
      s.warStart[key] = turn;
      s.lastGain[key] = turn;
      s.peaceOffers.remove(directedKey(n, target));
      s.peaceOffers.remove(directedKey(target, n));
      events.add(GameEvent(EventKind.warDeclared, a: n, b: target));
    }
  }
  final freshOffers = <int>{};
  for (final (n, o) in each()) {
    for (final target in o.offerPeace) {
      if (target < 0 || target >= nationCount) continue;
      final key = pairKey(n, target);
      if (!warsBefore.contains(key) || !s.wars.contains(key)) continue;
      final offer = directedKey(n, target);
      if (!s.peaceOffers.containsKey(offer)) freshOffers.add(offer);
      s.peaceOffers[offer] = turn + Rules.peaceOfferTurns;
    }
  }
  for (final key in s.wars.toList()..sort()) {
    final a = key >> 8;
    final b = key & 0xFF;
    final ab = directedKey(a, b);
    final ba = directedKey(b, a);
    if (s.peaceOffers.containsKey(ab) && s.peaceOffers.containsKey(ba)) {
      s.wars.remove(key);
      s.warStart.remove(key);
      s.lastGain.remove(key);
      s.peaceOffers.remove(ab);
      s.peaceOffers.remove(ba);
      s.truceUntil[key] = turn + 1 + Rules.truceTurns;
      events.add(GameEvent(EventKind.peaceSigned, a: a, b: b));
    } else {
      if (freshOffers.contains(ab)) events.add(GameEvent(EventKind.peaceOffered, a: a, b: b));
      if (freshOffers.contains(ba)) events.add(GameEvent(EventKind.peaceOffered, a: b, b: a));
    }
  }

  // ---------------------------------------------------------- 2. recruitment
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

  // ---------------------------------------------------------- 3. movement
  final moved = List.filled(provinceCount, 0);
  final arrivals = List.filled(provinceCount, 0);
  final attacks = <int, Map<int, _Attack>>{};
  for (final (n, o) in each()) {
    for (final m in o.moves) {
      if (m.from < 0 || m.from >= provinceCount || m.to < 0 || m.to >= provinceCount) continue;
      if (s.owner[m.from] != n || !w.provinces[m.from].links.contains(m.to)) continue;
      final count = math.min(m.count, startUnits[m.from] - moved[m.from]);
      if (count <= 0) continue;
      final target = s.owner[m.to];
      if (target == n) {
        arrivals[m.to] += count;
      } else {
        final key = pairKey(n, target);
        if (!warsBefore.contains(key) || !s.wars.contains(key)) continue;
        attacks.putIfAbsent(m.to, () => {}).putIfAbsent(n, () => _Attack(n)).add(m.from, count);
      }
      moved[m.from] += count;
      s.units[m.from] -= count;
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
      final rollA = rng.range(1 - Rules.combatSpread, 1 + Rules.combatSpread);
      final rollD = rng.range(1 - Rules.combatSpread, 1 + Rules.combatSpread);
      final attack = a.count * rollA;
      final defense = defenders * cover * rollD;
      final attackerWon = attack > defense;
      final int survivors;
      if (attackerWon) {
        survivors = ((attack - defense) / rollA).round().clamp(1, a.count);
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
      s.lastGain[pairKey(holder, original)] = turn;
      events.add(GameEvent(EventKind.captured, a: holder, b: original, province: p));
    }
  }

  // ---------------------------------------------------------- 5. eliminations
  final held = List.filled(nationCount, 0);
  for (final o in s.owner) {
    held[o]++;
  }
  for (var n = 0; n < nationCount; n++) {
    if (!s.alive[n]) continue;
    if (held[n] == 0) {
      final conqueror = events.lastWhere((e) => e.kind == EventKind.captured && e.b == n, orElse: () => const GameEvent(EventKind.captured)).a;
      s.alive[n] = false;
      s.gold[n] = 0;
      s.capital[n] = -1;
      bool involves(int key) => key >> 8 == n || key & 0xFF == n;
      s.wars.removeWhere(involves);
      s.warStart.removeWhere((k, _) => involves(k));
      s.lastGain.removeWhere((k, _) => involves(k));
      s.truceUntil.removeWhere((k, _) => involves(k));
      s.peaceOffers.removeWhere((k, _) => involves(k));
      events.add(GameEvent(EventKind.eliminated, a: n, b: conqueror));
    } else if (s.owner[s.capital[n]] != n) {
      var best = -1;
      for (var p = 0; p < provinceCount; p++) {
        if (s.owner[p] == n && (best < 0 || w.provinces[p].income > w.provinces[best].income)) best = p;
      }
      s.capital[n] = best;
      events.add(GameEvent(EventKind.capitalMoved, a: n, province: best));
    }
  }

  // ---------------------------------------------------------- 6. economy
  for (var n = 0; n < nationCount; n++) {
    if (!s.alive[n]) continue;
    s.gold[n] += g.incomeOf(n) - g.upkeepOf(n);
    if (s.gold[n] >= 0) continue;
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

  // ---------------------------------------------------------- 7. victory
  if (!s.ended && !s.sandbox) {
    var leader = -1;
    var standing = 0;
    for (var n = 0; n < nationCount; n++) {
      if (!s.alive[n]) continue;
      standing++;
      if (leader < 0 || held[n] > held[leader]) leader = n;
    }
    if (held[leader] >= g.winTarget || standing == 1) {
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
  for (final key in s.wars) {
    s.lastWar[key >> 8] = s.turn;
    s.lastWar[key & 0xFF] = s.turn;
  }
  return TurnReport(turn, events);
}
