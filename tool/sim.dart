// Headless AI-against-AI run, for balancing.
//
//   dart run tool/sim.dart [turns=300] [seed=1] [winFraction=0.4]
//
// Prints a standings line every 25 turns and a summary at the end.
import 'dart:convert';
import 'dart:io';

import 'package:atlasofcrowns/engine/events.dart';
import 'package:atlasofcrowns/engine/game.dart';
import 'package:atlasofcrowns/engine/world.dart';

void main(List<String> args) {
  final turns = args.isNotEmpty ? int.parse(args[0]) : 300;
  final seed = args.length > 1 ? int.parse(args[1]) : 1;
  final winFraction = args.length > 2 ? double.parse(args[2]) : 0.4;

  final world = World.fromJson(
    jsonDecode(File('assets/map/europe.json').readAsStringSync()) as Map<String, dynamic>,
    jsonDecode(File('assets/scenarios/1914.json').readAsStringSync()) as Map<String, dynamic>,
  );
  final game = Game.start(world, human: -1, seed: seed, winFraction: winFraction);
  final tally = <EventKind, int>{};
  var lastCapture = 0;
  var longestQuiet = 0;
  final clock = Stopwatch()..start();

  void standings() {
    final ranked = [
      for (final n in world.nations)
        if (game.state.alive[n.id]) n,
    ]..sort((a, b) => game.provinceCount(b.id) - game.provinceCount(a.id));
    final top = ranked.take(8).map((n) => '${n.tag} ${game.provinceCount(n.id)}p/${game.unitsOf(n.id)}u/${game.state.gold[n.id]}g').join('  ');
    stdout.writeln('${world.dateLabel(game.state.turn).padRight(9)} alive ${ranked.length.toString().padLeft(2)} wars ${game.state.wars.length.toString().padLeft(2)} | $top');
  }

  standings();
  while (game.state.turn < turns && !game.state.ended) {
    final report = game.endTurn(null);
    for (final e in report.events) {
      tally[e.kind] = (tally[e.kind] ?? 0) + 1;
      if (e.kind == EventKind.captured) lastCapture = game.state.turn;
      if (e.kind == EventKind.eliminated) {
        stdout.writeln('  ${world.dateLabel(report.turn)}: ${world.nations[e.a].name} falls to ${e.b >= 0 ? world.nations[e.b].name : '?'}');
      }
    }
    if (game.state.turn - lastCapture > longestQuiet) longestQuiet = game.state.turn - lastCapture;
    if (game.state.turn % 25 == 0) standings();
  }
  standings();
  stdout.writeln('ended: ${game.state.ended}, winner: ${game.state.winner >= 0 ? world.nations[game.state.winner].name : '-'}, '
      'turns: ${game.state.turn}, longest spell without a capture: $longestQuiet turns, ${clock.elapsedMilliseconds} ms');
  stdout.writeln(tally.entries.map((e) => '${e.key.name} ${e.value}').join(', '));
}
