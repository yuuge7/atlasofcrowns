import 'dart:convert';

import 'package:atlasofcrowns/engine/events.dart';
import 'package:atlasofcrowns/engine/game.dart';
import 'package:atlasofcrowns/engine/orders.dart';
import 'package:atlasofcrowns/engine/rng.dart';
import 'package:atlasofcrowns/engine/resolve.dart';
import 'package:atlasofcrowns/engine/rules.dart';
import 'package:atlasofcrowns/engine/state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// Resolves one turn where only the listed nations give orders.
TurnReport turn(Game g, Map<int, Orders> orders) {
  final all = List<Orders?>.filled(g.world.nations.length, null);
  orders.forEach((n, o) => all[n] = o);
  final rng = Rng(g.state.rngState);
  final report = resolveTurn(g, all, rng);
  g.state.rngState = rng.state;
  checkInvariants(g);
  return report;
}

bool has(TurnReport r, EventKind kind) => r.events.any((e) => e.kind == kind);

void main() {
  // A line of four provinces: nation 0 holds 0 and 1, nation 1 holds 2 and 3.
  final line = tinyWorld(
    links: [
      [1],
      [0, 2],
      [1, 3],
      [2],
    ],
    owners: [0, 0, 1, 1],
    wars: [
      [0, 1],
    ],
  );

  group('recruiting', () {
    test('costs gold and is capped by the province', () {
      final g = gameWith(line, units: [0, 0, 0, 0], gold: [1000, 0]);
      turn(g, {0: Orders()..recruits.add(const RecruitOrder(0, 99))});
      expect(g.state.units[0], g.recruitCap(0));
      expect(g.state.gold[0], 1000 - g.recruitCap(0) * Rules.unitCost + g.incomeOf(0) - g.upkeepOf(0));
    });

    test('stops when the treasury is empty', () {
      final g = gameWith(line, units: [0, 0, 0, 0], gold: [Rules.unitCost * 2 + 1, 0]);
      turn(g, {0: Orders()..recruits.add(const RecruitOrder(0, 4))});
      expect(g.state.units[0], 2);
    });

    test('is refused in a province of someone else', () {
      final g = gameWith(line, units: [0, 0, 0, 0], gold: [1000, 0]);
      turn(g, {0: Orders()..recruits.add(const RecruitOrder(2, 3))});
      expect(g.state.units[2], 0);
    });

    test('new units cannot march the turn they are raised', () {
      final g = gameWith(line, units: [0, 0, 0, 0], gold: [1000, 0]);
      turn(g, {
        0: Orders()
          ..recruits.add(const RecruitOrder(0, 3))
          ..moves.add(const MoveOrder(0, 1, 3)),
      });
      expect(g.state.units[0], 3);
      expect(g.state.units[1], 0);
    });
  });

  group('movement', () {
    test('between own provinces just relocates', () {
      final g = gameWith(line, units: [7, 1, 0, 0]);
      turn(g, {0: Orders()..moves.add(const MoveOrder(0, 1, 5))});
      expect(g.state.units.sublist(0, 2), [2, 6]);
    });

    test('never sends more than the province holds', () {
      final g = gameWith(line, units: [4, 0, 0, 0]);
      turn(g, {
        0: Orders()
          ..moves.add(const MoveOrder(0, 1, 3))
          ..moves.add(const MoveOrder(0, 1, 3)),
      });
      expect(g.state.units.sublist(0, 2), [0, 4]);
    });

    test('needs a link', () {
      final g = gameWith(line, units: [4, 0, 0, 0]);
      turn(g, {0: Orders()..moves.add(const MoveOrder(0, 3, 4))});
      expect(g.state.units[0], 4);
      expect(g.state.owner[3], 1);
    });

    test('into a nation at peace is refused', () {
      final peaceful = tinyWorld(
        links: [
          [1],
          [0],
        ],
        owners: [0, 1],
      );
      final g = gameWith(peaceful, units: [50, 0]);
      turn(g, {0: Orders()..moves.add(const MoveOrder(0, 1, 50))});
      expect(g.state.owner[1], 1);
      expect(g.state.units[0], 50);
    });
  });

  group('battles', () {
    test('an overwhelming attack takes the province', () {
      final g = gameWith(line, units: [0, 100, 5, 0]);
      final r = turn(g, {0: Orders()..moves.add(const MoveOrder(1, 2, 100))});
      expect(g.state.owner[2], 0);
      expect(g.state.units[2], inInclusiveRange(1, 99));
      expect(g.state.units[1], 0);
      expect(has(r, EventKind.battle), isTrue);
      expect(has(r, EventKind.captured), isTrue);
    });

    test('a weak attack is wiped out and the defender bleeds', () {
      final g = gameWith(line, units: [0, 10, 40, 0]);
      final r = turn(g, {0: Orders()..moves.add(const MoveOrder(1, 2, 10))});
      expect(g.state.owner[2], 1);
      expect(g.state.units[1], 0);
      expect(g.state.units[2], inInclusiveRange(25, 39));
      expect(r.events.firstWhere((e) => e.kind == EventKind.battle).flag, isFalse);
    });

    test('militia alone can hold an empty province', () {
      final g = gameWith(line, units: [0, 1, 0, 0]);
      turn(g, {0: Orders()..moves.add(const MoveOrder(1, 2, 1))});
      expect(g.state.owner[2], 1);
      expect(g.state.units[2], 0);
    });

    test('reinforcements arriving the same turn count as defenders', () {
      final g = gameWith(line, units: [0, 30, 2, 60]);
      turn(g, {
        0: Orders()..moves.add(const MoveOrder(1, 2, 30)),
        1: Orders()..moves.add(const MoveOrder(3, 2, 60)),
      });
      expect(g.state.owner[2], 1);
    });

    test('units that left do not defend', () {
      final g = gameWith(line, units: [0, 30, 60, 0]);
      turn(g, {
        0: Orders()..moves.add(const MoveOrder(1, 2, 30)),
        1: Orders()..moves.add(const MoveOrder(2, 3, 60)),
      });
      expect(g.state.owner[2], 0);
      expect(g.state.units[3], 60);
    });

    test('losing the last province eliminates the nation and ends the game', () {
      final two = tinyWorld(
        links: [
          [1],
          [0],
        ],
        owners: [0, 1],
        wars: [
          [0, 1],
        ],
      );
      final g = gameWith(two, units: [200, 1]);
      final r = turn(g, {0: Orders()..moves.add(const MoveOrder(0, 1, 200))});
      expect(g.state.alive[1], isFalse);
      expect(g.state.wars, isEmpty);
      expect(r.events.firstWhere((e) => e.kind == EventKind.eliminated).b, 0);
      expect(g.state.ended, isTrue);
      expect(g.state.winner, 0);
    });

    test('a lost capital moves to the richest province left', () {
      final w = tinyWorld(
        links: [
          [1],
          [0, 2],
          [1, 3],
          [2],
        ],
        owners: [0, 1, 1, 1],
        income: [2, 1, 3, 9],
        wars: [
          [0, 1],
        ],
      );
      final g = gameWith(w, units: [500, 0, 0, 0]);
      expect(g.state.capital[1], 1);
      final r = turn(g, {0: Orders()..moves.add(const MoveOrder(0, 1, 500))});
      expect(g.state.owner[1], 0);
      expect(g.state.capital[1], 3);
      expect(has(r, EventKind.capitalMoved), isTrue);
    });
  });

  group('diplomacy', () {
    final neighbors = tinyWorld(
      links: [
        [1],
        [0],
      ],
      owners: [0, 1],
    );

    test('a declared war opens the border only next turn', () {
      final g = gameWith(neighbors, units: [500, 0]);
      final declare = Orders()
        ..declareWar.add(1)
        ..moves.add(const MoveOrder(0, 1, 500));
      final r = turn(g, {0: declare});
      expect(has(r, EventKind.warDeclared), isTrue);
      expect(g.atWar(0, 1), isTrue);
      expect(g.state.owner[1], 1);
      turn(g, {0: Orders()..moves.add(const MoveOrder(0, 1, 500))});
      expect(g.state.owner[1], 0);
    });

    test('peace needs both sides and starts a truce', () {
      final g = gameWith(line, units: [5, 5, 5, 5]);
      final r1 = turn(g, {0: Orders()..offerPeace.add(1)});
      expect(g.atWar(0, 1), isTrue);
      expect(has(r1, EventKind.peaceOffered), isTrue);
      expect(g.hasPeaceOffer(0, 1), isTrue);
      final r2 = turn(g, {1: Orders()..offerPeace.add(0)});
      expect(has(r2, EventKind.peaceSigned), isTrue);
      expect(g.atWar(0, 1), isFalse);
      expect(g.canDeclareWar(0, 1), isFalse);
      expect(g.truceLeft(0, 1), Rules.truceTurns);
      for (var i = 0; i < Rules.truceTurns; i++) {
        turn(g, {});
      }
      expect(g.canDeclareWar(0, 1), isTrue);
    });

    test('an unanswered offer lapses', () {
      final g = gameWith(line, units: [5, 5, 5, 5]);
      turn(g, {0: Orders()..offerPeace.add(1)});
      turn(g, {});
      expect(g.hasPeaceOffer(0, 1), isFalse);
      turn(g, {1: Orders()..offerPeace.add(0)});
      expect(g.atWar(0, 1), isTrue);
    });

    test('an attack is called off when peace is signed the same turn', () {
      final g = gameWith(line, units: [0, 500, 0, 0]);
      turn(g, {
        0: Orders()
          ..offerPeace.add(1)
          ..moves.add(const MoveOrder(1, 2, 500)),
        1: Orders()..offerPeace.add(0),
      });
      expect(g.state.owner[2], 1);
      expect(g.state.units[1], 500);
    });
  });

  group('economy', () {
    test('income minus upkeep lands in the treasury', () {
      final g = gameWith(line, units: [8, 8, 0, 0], gold: [10, 0]);
      turn(g, {});
      expect(g.state.gold[0], 10 + Rules.baseIncome + 2 + 2 - 16 ~/ Rules.unitsPerUpkeepGold);
    });

    test('an army nobody can pay shrinks', () {
      final g = gameWith(line, units: [400, 400, 0, 0], gold: [0, 0]);
      final r = turn(g, {});
      expect(g.state.gold[0], 0);
      expect(g.unitsOf(0), lessThan(800));
      expect(r.events.firstWhere((e) => e.kind == EventKind.desertion).n1, 800 - g.unitsOf(0));
    });
  });

  test('desertion removes exactly the units it reports, however thin the army', () {
    final thin = tinyWorld(
      links: [
        [1],
        [0, 2],
        [1, 3],
        [2, 4],
        [3],
      ],
      owners: [0, 0, 0, 0, 1],
      income: [0, 0, 0, 0, 1],
    );
    // Income 4, upkeep 44 ~/ 4 = 11: seven gold short.
    final g = gameWith(thin, units: [11, 11, 11, 11, 0], gold: [0, 0]);
    final r = turn(g, {});
    expect(r.events.firstWhere((e) => e.kind == EventKind.desertion).n1, 7);
    expect(g.unitsOf(0), 44 - 7);
  });

  test('holding the winning share of provinces ends the game', () {
    final g = gameWith(line, units: [0, 300, 0, 0], winFraction: 0.75);
    expect(g.winTarget, 3);
    turn(g, {0: Orders()..moves.add(const MoveOrder(1, 2, 300))});
    expect(g.state.ended, isTrue);
    expect(g.state.winner, 0);
  });

  test('a wiped out player ends the game without a winner', () {
    final w = tinyWorld(
      links: [
        [1],
        [0, 2],
        [1],
      ],
      owners: [0, 1, 2],
      wars: [
        [0, 1],
      ],
    );
    final g = gameWith(w, units: [0, 300, 5], human: 0);
    turn(g, {1: Orders()..moves.add(const MoveOrder(1, 0, 300))});
    expect(g.state.ended, isTrue);
    expect(g.state.winner, -1);
  });

  test('a save restores the exact game', () {
    final a = Game.start(loadEurope1914(), human: -1, seed: 9);
    for (var i = 0; i < 12; i++) {
      a.endTurn(null);
    }
    final b = Game.fromJson(a.world, jsonDecode(jsonEncode(a.toJson())) as Map<String, dynamic>);
    for (var i = 0; i < 12; i++) {
      a.endTurn(null);
      b.endTurn(null);
    }
    expect(jsonEncode(b.toJson()), jsonEncode(a.toJson()));
  });

  test('a save from another map is refused', () {
    final g = gameWith(line, units: [1, 1, 1, 1]);
    final json = g.toJson()..['mapBuild'] = 'older';
    expect(() => Game.fromJson(line, json), throwsFormatException);
  });

  test('orders survive a round trip through JSON', () {
    final o = Orders()
      ..moves.add(const MoveOrder(1, 2, 3))
      ..recruits.add(const RecruitOrder(4, 5))
      ..declareWar.add(6)
      ..offerPeace.add(7);
    final back = Orders.fromJson(jsonDecode(jsonEncode(o.toJson())) as Map<String, dynamic>);
    expect(jsonEncode(back.toJson()), jsonEncode(o.toJson()));
  });

  test('pair keys ignore order', () {
    expect(pairKey(3, 17), pairKey(17, 3));
    expect(directedKey(3, 17), isNot(directedKey(17, 3)));
  });
}
