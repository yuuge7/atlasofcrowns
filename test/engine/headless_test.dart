import 'dart:convert';
import 'dart:io';

import 'package:atlasofcrowns/engine/events.dart';
import 'package:atlasofcrowns/engine/game.dart';
import 'package:atlasofcrowns/engine/rng.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  final world = loadEurope1914();

  test('the engine imports nothing from Flutter', () {
    for (final file in Directory('lib/engine').listSync(recursive: true).whereType<File>()) {
      for (final line in file.readAsLinesSync()) {
        if (!line.startsWith('import ')) continue;
        expect(line, isNot(contains('package:flutter')), reason: file.path);
        expect(line, isNot(contains('dart:ui')), reason: file.path);
      }
    }
  });

  test('the map is one connected graph with symmetric links', () {
    final seen = {0};
    final queue = [0];
    while (queue.isNotEmpty) {
      final p = world.provinces[queue.removeLast()];
      for (final q in p.links) {
        expect(world.provinces[q].links, contains(p.id), reason: '${p.name} -> ${world.provinces[q].name}');
        if (seen.add(q)) queue.add(q);
      }
    }
    expect(seen.length, world.provinces.length);
  });

  test('every nation starts alive, armed and holding its capital', () {
    final g = Game.start(world, human: -1, seed: 1);
    checkInvariants(g);
    for (final n in world.nations) {
      expect(g.state.alive[n.id], isTrue, reason: n.name);
      expect(g.unitsOf(n.id), greaterThan(0), reason: n.name);
      expect(g.state.owner[n.capital], n.id, reason: n.name);
    }
    expect(g.state.wars.length, world.startWars.length);
  });

  test('the generator repeats itself for a seed', () {
    final a = Rng(123);
    final b = Rng(123);
    final c = Rng(124);
    final rollsA = [for (var i = 0; i < 50; i++) a.nextU32()];
    expect([for (var i = 0; i < 50; i++) b.nextU32()], rollsA);
    expect([for (var i = 0; i < 50; i++) c.nextU32()], isNot(rollsA));
    for (var i = 0; i < 1000; i++) {
      expect(a.nextDouble(), inInclusiveRange(0, 0.9999999999));
      expect(a.nextInt(7), inInclusiveRange(0, 6));
    }
  });

  test('the same seed plays the same game', () {
    String play(int seed) {
      final g = Game.start(world, human: -1, seed: seed);
      for (var i = 0; i < 40; i++) {
        g.endTurn(null);
      }
      return jsonEncode(g.toJson());
    }

    expect(play(5), play(5));
    expect(play(5), isNot(play(6)));
  });

  // AI against AI, with victory out of reach so the game has to keep moving
  // for the full 300 turns unless one empire swallows the map.
  for (final seed in [1, 2, 3, 4, 5, 6, 7, 8]) {
    test('300 turns of AI against AI, seed $seed: no crash, no stall', () {
      final g = Game.start(world, human: -1, seed: seed, winFraction: 0.95);
      var lastCapture = 0;
      var captures = 0;
      while (g.state.turn < 300 && !g.state.ended) {
        final report = g.endTurn(null);
        checkInvariants(g);
        for (final e in report.events) {
          if (e.kind != EventKind.captured) continue;
          captures++;
          lastCapture = g.state.turn;
        }
        expect(g.state.turn - lastCapture, lessThan(60), reason: 'nothing changed hands since turn $lastCapture');
      }
      expect(captures, greaterThan(100));
      if (g.state.ended) expect(g.provinceCount(g.state.winner), greaterThanOrEqualTo(g.winTarget));
    });
  }

  test('a game with the default victory target finishes', () {
    final g = Game.start(world, human: -1, seed: 11);
    while (g.state.turn < 400 && !g.state.ended) {
      g.endTurn(null);
    }
    expect(g.state.ended, isTrue);
    expect(g.provinceCount(g.state.winner), greaterThanOrEqualTo(g.winTarget));
  });

  test('the AI can play the human seat', () {
    final g = Game.start(world, human: 0, seed: 3);
    for (var i = 0; i < 30 && !g.state.ended; i++) {
      g.endTurn(null, autoPlayHuman: true);
      checkInvariants(g);
    }
    expect(g.state.turn, greaterThan(0));
  });
}
