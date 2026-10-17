// How weak nations fare in the player's seat, played by the AI: a floor for
// what a player can do with them.
//
//   dart run tool/underdog.dart <scenario> <tag,tag,...> [seeds=20] [turns=400] [winFraction=0.4] [difficulty=0]
//
// For each nation: how often it survives, how often it wins, and its median
// and best size at the end. Difficulty 0 is Easy (the AI earns 80%), 1
// Normal, 2 Hard.
import 'dart:convert';
import 'dart:io';

import 'package:atlasofcrowns/engine/game.dart';
import 'package:atlasofcrowns/engine/world.dart';

void main(List<String> args) {
  final scenario = args[0];
  final tags = args[1].split(',');
  final seeds = args.length > 2 ? int.parse(args[2]) : 20;
  final turns = args.length > 3 ? int.parse(args[3]) : 400;
  final winFraction = args.length > 4 ? double.parse(args[4]) : 0.4;
  final difficulty = args.length > 5 ? int.parse(args[5]) : 0;

  final scenarioJson = jsonDecode(File('assets/scenarios/$scenario.json').readAsStringSync()) as Map<String, dynamic>;
  final world = World.fromJson(jsonDecode(File('assets/map/${scenarioJson['map'] ?? 'europe'}.json').readAsStringSync()) as Map<String, dynamic>, scenarioJson);

  for (final tag in tags) {
    final n = world.nations.indexWhere((x) => x.tag == tag);
    if (n < 0) throw ArgumentError('no nation $tag in $scenario');
    final start = world.startOwners.where((o) => o == n).length;
    var survived = 0;
    var won = 0;
    final sizes = <int>[];
    for (var seed = 1; seed <= seeds; seed++) {
      final g = Game.start(world, human: n, seed: seed, winFraction: winFraction, difficulty: difficulty, randomEvents: true);
      while (g.state.turn < turns && g.state.alive[n] && !(g.state.ended && g.state.winner >= 0)) {
        g.endTurn(null, autoPlayHuman: true);
      }
      if (g.state.alive[n]) survived++;
      if (g.state.ended && g.state.winner == n) won++;
      sizes.add(g.state.alive[n] ? g.realmCount(n) : 0);
    }
    sizes.sort();
    stdout.writeln('${world.nations[n].shortName.padRight(16)} starts ${start.toString().padLeft(2)}p: '
        'survives ${(100 * survived / seeds).round().toString().padLeft(3)}%, wins ${(100 * won / seeds).round().toString().padLeft(3)}%, '
        'median end ${sizes[seeds ~/ 2]}p, best ${sizes.last}p');
  }
}
