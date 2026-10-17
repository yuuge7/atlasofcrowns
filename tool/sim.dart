// Headless AI-against-AI run, for balancing.
//
//   dart run tool/sim.dart [turns=300] [seed=1] [winFraction=0.4] [every=25] [scenario=1914]
//
// Prints a standings line every 25 turns (every [every] turns when given as a
// fourth argument) and a summary at the end.
import 'dart:convert';
import 'dart:io';

import 'package:atlasofcrowns/engine/events.dart';
import 'package:atlasofcrowns/engine/game.dart';
import 'package:atlasofcrowns/engine/world.dart';

void main(List<String> args) {
  final turns = args.isNotEmpty ? int.parse(args[0]) : 300;
  final seed = args.length > 1 ? int.parse(args[1]) : 1;
  final winFraction = args.length > 2 ? double.parse(args[2]) : 0.4;
  final every = args.length > 3 ? int.parse(args[3]) : 25;
  final scenario = args.length > 4 ? args[4] : '1914';

  final scenarioJson = jsonDecode(File('assets/scenarios/$scenario.json').readAsStringSync()) as Map<String, dynamic>;
  final world = World.fromJson(
    jsonDecode(File('assets/map/${scenarioJson['map'] ?? 'europe'}.json').readAsStringSync()) as Map<String, dynamic>,
    scenarioJson,
  );
  final game = Game.start(world, human: -1, seed: seed, winFraction: winFraction, randomEvents: args.length > 5 ? args[5] == 'events' : true);
  final tally = <EventKind, int>{};
  var lastCapture = 0;
  var longestQuiet = 0;
  final clock = Stopwatch()..start();

  void standings() {
    final ranked = [
      for (final n in world.nations)
        if (game.state.alive[n.id]) n,
    ]..sort((a, b) => game.provinceCount(b.id) - game.provinceCount(a.id));
    String lord(int n) => game.state.overlord[n] >= 0 ? '<${world.nations[game.state.overlord[n]].tag}' : '';
    final top = ranked.take(8).map((n) => '${n.tag}${lord(n.id)} ${game.provinceCount(n.id)}p/${game.unitsOf(n.id)}u/${game.state.gold[n.id]}g').join('  ');
    final s = game.state;
    final forts = s.forts.fold(0, (a, b) => a + b);
    final developed = s.development.fold(0, (a, b) => a + b);
    stdout.writeln('${game.dateLabel(s.turn).padRight(9)} alive ${ranked.length.toString().padLeft(2)} wars ${s.wars.length.toString().padLeft(2)} '
        'allies ${s.alliances.length.toString().padLeft(2)} pacts ${s.pacts.length.toString().padLeft(2)} forts ${forts.toString().padLeft(3)} dev ${developed.toString().padLeft(4)} | $top');
  }

  standings();
  while (game.state.turn < turns && !game.state.ended) {
    final report = game.endTurn(null);
    for (final e in report.events) {
      tally[e.kind] = (tally[e.kind] ?? 0) + 1;
      if (e.kind == EventKind.captured) lastCapture = game.state.turn;
      if (e.kind == EventKind.eliminated) {
        stdout.writeln('  ${game.dateLabel(report.turn)}: ${world.nations[e.a].name} falls to ${e.b >= 0 ? world.nations[e.b].name : '?'}');
      }
    }
    if (game.state.turn - lastCapture > longestQuiet) longestQuiet = game.state.turn - lastCapture;
    if (game.state.turn % every == 0) standings();
  }
  standings();
  stdout.writeln('ended: ${game.state.ended}, winner: ${game.state.winner >= 0 ? world.nations[game.state.winner].name : '-'}, '
      'turns: ${game.state.turn}, longest spell without a capture: $longestQuiet turns, ${clock.elapsedMilliseconds} ms');
  stdout.writeln(tally.entries.map((e) => '${e.key.name} ${e.value}').join(', '));
}
