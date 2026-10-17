import 'dart:convert';
import 'dart:io';

import 'package:atlasofcrowns/engine/game.dart';
import 'package:atlasofcrowns/engine/state.dart';
import 'package:atlasofcrowns/engine/world.dart';

/// The real map and scenario, straight from the asset files.
World loadEurope1914() => loadScenario('1914');

World loadScenario(String id) {
  final scenario = jsonDecode(File('assets/scenarios/$id.json').readAsStringSync()) as Map<String, dynamic>;
  return World.fromJson(jsonDecode(File('assets/map/${scenario['map'] ?? 'europe'}.json').readAsStringSync()) as Map<String, dynamic>, scenario);
}

/// A hand-made world. [links] lists each province's neighbors, [owners] who
/// starts where. Nation n's capital is its first province.
World tinyWorld({
  required List<List<int>> links,
  required List<int> owners,
  List<int>? income,
  List<List<int>> wars = const [],
  List<List<int>> alliances = const [],
  List<HistoryEvent> history = const [],
  List<List<int>>? coast,
  List<SeaZone> seas = const [],
  int wild = -1,
  List<double>? aggression,
  List<List<int>> guarantees = const [],
  List<List<int>> pacts = const [],
}) {
  final nationCount = owners.reduce((a, b) => a > b ? a : b) + 1;
  return World(
    mapBuild: 'test',
    scenarioId: 'test',
    scenarioName: 'Test',
    startYear: 1914,
    startMonth: 8,
    provinces: [
      for (var p = 0; p < links.length; p++) Province(id: p, name: 'P$p', modern: 'TST', area: 1000, adj: links[p], sea: const [], income: income?[p] ?? 2, coast: coast?[p] ?? const []),
    ],
    nations: [
      for (var n = 0; n < nationCount; n++)
        Nation(id: n, tag: 'N$n', name: 'Nation $n', shortName: 'N$n', color: 0xFF000000, capital: owners.indexOf(n), wild: n == wild, aggression: aggression?[n] ?? 1),
    ],
    startOwners: owners,
    startWars: wars,
    startAlliances: alliances,
    startGuarantees: guarantees,
    startPacts: pacts,
    history: history,
    seas: seas,
  );
}

/// A game on [world] with every army set by hand. Treasuries are full unless
/// [gold] says otherwise, so upkeep never interferes with a test by accident.
Game gameWith(World world, {required List<int> units, List<int>? gold, int human = -1, double winFraction = 2}) {
  final game = Game.start(world, human: human, seed: 42, winFraction: winFraction);
  for (var p = 0; p < units.length; p++) {
    game.state.units[p] = units[p];
  }
  for (var n = 0; n < world.nations.length; n++) {
    game.state.gold[n] = gold?[n] ?? 100000;
  }
  return game;
}

/// Everything that must hold after any turn of any game.
void checkInvariants(Game g) {
  final s = g.state;
  final held = List.filled(g.world.nations.length, 0);
  for (var p = 0; p < s.owner.length; p++) {
    if (s.owner[p] < 0 || s.owner[p] >= held.length) throw StateError('province $p has owner ${s.owner[p]}');
    if (s.units[p] < 0) throw StateError('province $p has ${s.units[p]} units');
    held[s.owner[p]]++;
  }
  for (var n = 0; n < held.length; n++) {
    if (s.alive[n] != held[n] > 0) throw StateError('nation $n alive=${s.alive[n]} with ${held[n]} provinces');
    if (s.gold[n] < 0) throw StateError('nation $n has ${s.gold[n]} gold');
    if (s.alive[n] && s.owner[s.capital[n]] != n) throw StateError('nation $n does not hold its capital');
    if (!s.alive[n] && s.capital[n] != -1) throw StateError('dead nation $n still has a capital');
  }
  for (final key in s.wars) {
    final a = key >> 8;
    final b = key & 0xFF;
    if (!s.alive[a] || !s.alive[b]) throw StateError('war $a-$b involves a dead nation');
    if (pairKey(a, b) != key) throw StateError('war key $key is not normalised');
  }
}
