import 'dart:convert';

import 'package:atlasofcrowns/engine/events.dart';
import 'package:atlasofcrowns/engine/game.dart';
import 'package:atlasofcrowns/engine/happenings.dart';
import 'package:atlasofcrowns/engine/orders.dart';
import 'package:atlasofcrowns/engine/rng.dart';
import 'package:atlasofcrowns/engine/resolve.dart';
import 'package:atlasofcrowns/engine/rules.dart';
import 'package:atlasofcrowns/engine/state.dart';
import 'package:atlasofcrowns/engine/world.dart';
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
      final r = turn(g, {0: Orders()..moves.add(const MoveOrder(0, 1, 5))});
      expect(g.state.units.sublist(0, 2), [2, 6]);
      final move = r.movements.single;
      expect((move.nation, move.from, move.to, move.count, move.hostile), (0, 0, 1, 5, false));
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

  group('alliances', () {
    // Three in a row: 0 | 1 | 2, with 1 and 2 allied.
    final row = tinyWorld(
      links: [
        [1],
        [0, 2],
        [1],
      ],
      owners: [0, 1, 2],
      alliances: [
        [1, 2],
      ],
    );

    test('an ally joins a war declared on its partner', () {
      final g = gameWith(row, units: [5, 5, 5]);
      expect(g.wouldDefend(0, 1), [2]);
      final r = turn(g, {0: Orders()..declareWar.add(1)});
      expect(g.atWar(0, 1), isTrue);
      expect(g.atWar(0, 2), isTrue);
      final call = r.events.singleWhere((e) => e.kind == EventKind.calledToArms);
      expect((call.a, call.b, call.n1), (2, 0, 1));
    });

    test('a war the allies start themselves stays theirs', () {
      final g = gameWith(row, units: [5, 5, 5]);
      turn(g, {1: Orders()..declareWar.add(0)});
      expect(g.atWar(0, 1), isTrue);
      expect(g.atWar(0, 2), isFalse);
    });

    test('a nation allied to both sides stays out', () {
      final both = tinyWorld(
        links: [
          [1],
          [0, 2],
          [1],
        ],
        owners: [0, 1, 2],
        alliances: [
          [1, 2],
          [0, 2],
        ],
      );
      final g = gameWith(both, units: [5, 5, 5]);
      expect(g.canDeclareWar(0, 2), isFalse);
      turn(g, {0: Orders()..declareWar.add(1)});
      expect(g.atWar(0, 1), isTrue);
      expect(g.atWar(0, 2), isFalse);
      expect(g.allied(0, 2), isTrue);
    });

    test('nobody allies with the enemy of an ally', () {
      final g = gameWith(row, units: [5, 5, 5]);
      g.state.wars.add(pairKey(0, 2));
      expect(g.canOfferAlliance(0, 1), isFalse, reason: '1 is allied to 2, at war with 0');
      expect(g.canOfferAlliance(1, 0), isFalse);
      turn(g, {
        0: Orders()..offerAlliance.add(1),
        1: Orders()..offerAlliance.add(0),
      });
      expect(g.allied(0, 1), isFalse);
    });

    test('an alliance needs both sides', () {
      final g = gameWith(row, units: [5, 5, 5]);
      final r1 = turn(g, {0: Orders()..offerAlliance.add(1)});
      expect(g.allied(0, 1), isFalse);
      expect(has(r1, EventKind.allianceOffered), isTrue);
      expect(g.hasAllianceOffer(0, 1), isTrue);
      final r2 = turn(g, {1: Orders()..offerAlliance.add(0)});
      expect(has(r2, EventKind.allianceSigned), isTrue);
      expect(g.allied(0, 1), isTrue);
      expect(g.hasAllianceOffer(0, 1), isFalse);
      expect(g.canDeclareWar(1, 0), isFalse);
    });

    test('an alliance offer is remembered for a while after it lapses', () {
      final g = gameWith(row, units: [5, 5, 5]);
      turn(g, {0: Orders()..offerAlliance.add(1)});
      for (var i = 0; i < Rules.peaceOfferTurns; i++) {
        turn(g, {});
      }
      expect(g.hasAllianceOffer(0, 1), isFalse);
      expect(g.askedRecently(0, 1), isTrue);
      expect(g.askedRecently(1, 0), isFalse);
      for (var i = 0; i < Rules.aiAllianceRetryTurns; i++) {
        turn(g, {});
      }
      expect(g.askedRecently(0, 1), isFalse);
      expect(g.state.allianceAsked, isEmpty);
    });

    test('an ally cannot be attacked in the turn the alliance is left', () {
      final g = gameWith(row, units: [5, 5, 5]);
      final r = turn(g, {
        1: Orders()
          ..breakAlliance.add(2)
          ..declareWar.add(2),
      });
      expect(has(r, EventKind.allianceBroken), isTrue);
      expect(g.allied(1, 2), isFalse);
      expect(g.atWar(1, 2), isFalse);
      turn(g, {1: Orders()..declareWar.add(2)});
      expect(g.atWar(1, 2), isTrue);
    });

    test('a war cancels the offers between the two', () {
      final g = gameWith(row, units: [5, 5, 5]);
      turn(g, {1: Orders()..offerAlliance.add(0)});
      turn(g, {0: Orders()..declareWar.add(1)});
      expect(g.hasAllianceOffer(1, 0), isFalse);
      turn(g, {0: Orders()..offerAlliance.add(1)});
      expect(g.allied(0, 1), isFalse);
    });

    test('alliances go with a fallen nation', () {
      final g = gameWith(row, units: [300, 0, 0]);
      g.state.wars.add(pairKey(0, 1));
      g.state.alliances.add(pairKey(0, 2));
      turn(g, {0: Orders()..moves.add(const MoveOrder(0, 1, 300))});
      expect(g.state.alive[1], isFalse);
      expect(g.state.alliances, {pairKey(0, 2)});
    });
  });

  group('building', () {
    test('a fort raises the cover, costs gold and upkeep', () {
      final g = gameWith(line, units: [0, 0, 0, 0], gold: [100, 0]);
      final before = g.defenseMultiplier(1);
      turn(g, {0: Orders()..builds.add(const BuildOrder(1, Project.fortify))});
      expect(g.state.forts[1], 1);
      expect(g.defenseMultiplier(1), before + Rules.fortBonus);
      expect(g.upkeepOf(0), Rules.fortUpkeep);
      expect(g.state.gold[0], 100 - Rules.fortCost + g.incomeOf(0) - Rules.fortUpkeep);
    });

    test('one project per province, none past the top level or the treasury', () {
      final g = gameWith(line, units: [0, 0, 0, 0], gold: [1000, 0]);
      turn(g, {
        0: Orders()
          ..builds.add(const BuildOrder(1, Project.fortify))
          ..builds.add(const BuildOrder(1, Project.develop))
          ..builds.add(const BuildOrder(2, Project.fortify)),
      });
      expect(g.state.forts[1], 1);
      expect(g.state.development[1], 0);
      expect(g.state.forts[2], 0);
      for (var i = 0; i < 4; i++) {
        turn(g, {0: Orders()..builds.add(const BuildOrder(1, Project.fortify))});
      }
      expect(g.state.forts[1], Rules.maxFort);
      expect(g.buildCost(1, Project.fortify), -1);
      g.state.gold[0] = Rules.developCost - 1;
      turn(g, {0: Orders()..builds.add(const BuildOrder(0, Project.develop))});
      expect(g.state.development[0], 0);
    });

    test('development adds income, at a rising price', () {
      final g = gameWith(line, units: [0, 0, 0, 0], gold: [1000, 0]);
      final income = g.incomeOf(0);
      final first = g.buildCost(0, Project.develop);
      turn(g, {0: Orders()..builds.add(const BuildOrder(0, Project.develop))});
      expect(g.incomeOf(0), income + 1);
      expect(g.recruitCap(0), Rules.recruitBase + 3);
      expect(g.buildCost(0, Project.develop), first + Rules.developStep);
    });

    test('a conquered province yields less at first and loses a fort level', () {
      final g = gameWith(line, units: [0, 300, 0, 0], gold: [1000, 1000]);
      g.state.forts[2] = 2;
      g.state.development[2] = 6;
      final full = g.fullIncome(2);
      turn(g, {0: Orders()..moves.add(const MoveOrder(1, 2, 300))});
      expect(g.state.owner[2], 0);
      expect(g.state.forts[2], 1);
      expect(g.isOccupied(2), isTrue);
      expect(g.provinceIncome(2), lessThan(full));
      expect(g.provinceIncome(2), greaterThanOrEqualTo((full * Rules.occupiedShare).floor()));
      for (var i = 0; i < Rules.integrationTurns; i++) {
        turn(g, {});
      }
      expect(g.isOccupied(2), isFalse);
      expect(g.provinceIncome(2), full);
    });

    test('a province won back by its first owner yields all at once', () {
      final g = gameWith(line, units: [0, 0, 0, 300], gold: [1000, 1000]);
      g.state.owner[2] = 0;
      g.state.heldSince[2] = 0;
      expect(g.isOccupied(2), isTrue);
      turn(g, {1: Orders()..moves.add(const MoveOrder(3, 2, 300))});
      expect(g.state.owner[2], 1);
      expect(g.isOccupied(2), isFalse);
      expect(g.provinceIncome(2), g.fullIncome(2));
    });
  });

  group('technology', () {
    test('research is paid from the surplus and buys levels', () {
      final g = gameWith(line, units: [0, 0, 0, 0], gold: [0, 0]);
      final r1 = turn(g, {0: Orders()..research = const ResearchPlan(Field.industry, 50)});
      expect(g.state.researchFocus[0], Field.industry.index);
      expect(g.state.researchShare[0], 50);
      final income = g.incomeOf(0);
      expect(g.state.research[0][Field.industry.index], income ~/ 2);
      expect(g.state.gold[0], income - income ~/ 2);
      expect(has(r1, EventKind.techAdvanced), isFalse);
      var advanced = false;
      for (var i = 0; i < 20 && !advanced; i++) {
        advanced = has(turn(g, {}), EventKind.techAdvanced);
      }
      expect(advanced, isTrue);
      expect(g.techLevel(0, Field.industry), 1);
      expect(g.state.researchShare[0], 50, reason: 'the plan stands until changed');
    });

    test('research never leaves an army unpaid', () {
      final g = gameWith(line, units: [40, 40, 0, 0], gold: [0, 0]);
      g.state.researchShare[0] = 50;
      turn(g, {});
      expect(g.state.research[0], [0, 0]);
    });

    test('a share that is not on offer is ignored', () {
      final g = gameWith(line, units: [0, 0, 0, 0]);
      turn(g, {0: Orders()..research = const ResearchPlan(Field.army, 99)});
      expect(g.state.researchShare[0], isNot(99));
    });

    test('army technology makes every unit count for more', () {
      final g = gameWith(line, units: [0, 100, 49, 0]);
      final before = g.defenseStrength(2);
      g.state.tech[1][Field.army.index] = 4;
      expect(g.defenseStrength(2), (before * (1 + 4 * Rules.armyTechBonus)).round());
      g.state.tech[1][Field.army.index] = 0;
      // Even with the worst roll against the best, 100 units at level 10 beat
      // 49 units and 3 militia dug in at x2.0 in a capital.
      g.state.tech[0][Field.army.index] = Rules.maxTech;
      turn(g, {0: Orders()..moves.add(const MoveOrder(1, 2, 100))});
      expect(g.state.owner[2], 0);
    });

    test('industry raises the income', () {
      final g = gameWith(line, units: [0, 0, 0, 0]);
      final before = g.incomeOf(0);
      g.state.tech[0][Field.industry.index] = 5;
      expect(g.incomeOf(0), (before * (1 + 5 * Rules.industryTechBonus)).floor());
    });
  });

  group('setup', () {
    test('difficulty scales what the AI earns, never the player', () {
      int incomes(int difficulty, int nation) => Game.start(line, human: 0, seed: 1, difficulty: difficulty).incomeOf(nation);
      expect(incomes(0, 0), incomes(2, 0));
      expect(incomes(0, 1), lessThan(incomes(1, 1)));
      expect(incomes(2, 1), greaterThan(incomes(1, 1)));
      final watching = Game.start(line, human: -1, seed: 1, difficulty: 2);
      expect(watching.incomeOf(1), incomes(1, 1));
    });

    test('difficulty leaves the opening position alone', () {
      final easy = Game.start(line, human: 0, seed: 1, difficulty: 0);
      final hard = Game.start(line, human: 0, seed: 1, difficulty: 2);
      expect(hard.state.gold, easy.state.gold);
      expect(hard.state.units, easy.state.units);
    });

    test('a nation sees its own land, its allies and one province beyond', () {
      final row = tinyWorld(
        links: [
          [1],
          [0, 2],
          [1, 3],
          [2, 4],
          [3],
        ],
        owners: [0, 1, 1, 2, 2],
        alliances: [
          [0, 2],
        ],
      );
      final g = Game.start(row, human: 0, seed: 1, fog: true);
      expect(g.sightOf(0), [true, true, true, true, true]);
      g.state.alliances.clear();
      expect(g.sightOf(0), [true, true, false, false, false]);
    });
  });

  group('peace terms', () {
    // 0 | 1 | 2, with 0 and 1 at war.
    final row = tinyWorld(
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

    Orders peace(int to, [Terms terms = Terms.white]) => Orders()
      ..offerPeace.add(to)
      ..peaceTerms.addAll({if (terms != Terms.white) to: terms});

    test("a vassal's land counts for its overlord's victory", () {
      final g = gameWith(row, units: [5, 5, 5], winFraction: 0.6);
      g.state.closeWar(0, 1, 0, 0);
      g.state.overlord[1] = 0;
      expect(g.realmCount(0), 2);
      final r = turn(g, {});
      expect(g.state.ended, isTrue);
      expect(g.state.winner, 0);
      expect(r.events.last.kind, EventKind.gameOver);
    });

    test('a demand is met only when the other side accepts it', () {
      final g = gameWith(row, units: [5, 5, 5]);
      turn(g, {0: peace(1, Terms.reparations), 1: peace(0)});
      expect(g.atWar(0, 1), isTrue, reason: 'white peace does not accept a demand');
      final r = turn(g, {1: peace(0, Terms.accept)});
      expect(g.atWar(0, 1), isFalse);
      final signed = r.events.singleWhere((e) => e.kind == EventKind.peaceSigned);
      expect((Terms.values[signed.n1], signed.n2), (Terms.reparations, 0));
      expect(g.state.tribute.keys, [directedKey(1, 0)]);
    });

    test('reparations move gold from the loser to the winner for a while', () {
      final g = gameWith(row, units: [0, 0, 0], gold: [0, 0, 0]);
      g.state.wars.clear();
      g.state.tribute[directedKey(1, 0)] = 2;
      final owed = (g.incomeOf(1) * Rules.reparationShare).floor();
      expect(g.tributeOwed(1), owed);
      expect(g.tributeOwed(0), -owed);
      turn(g, {});
      expect(g.state.gold[0], g.incomeOf(0) + owed);
      expect(g.state.gold[1], g.incomeOf(1) - owed);
      turn(g, {});
      turn(g, {});
      expect(g.state.tribute, isEmpty);
    });

    test('a vassal pays tribute, follows its overlord to war and may break free', () {
      final g = gameWith(row, units: [5, 5, 5]);
      turn(g, {0: peace(1, Terms.vassal), 1: peace(0, Terms.accept)});
      expect(g.overlordOf(1), 0);
      expect(g.vassalsOf(0), [1]);
      expect(g.tributeOwed(1), (g.incomeOf(1) * Rules.vassalTribute).floor());
      expect(g.canDeclareWar(1, 2), isFalse);
      expect(g.canDeclareWar(0, 1), isFalse);
      g.state.truceUntil.clear();
      final r = turn(g, {0: Orders()..declareWar.add(2)});
      expect(g.atWar(1, 2), isTrue);
      expect(r.events.any((e) => e.kind == EventKind.calledToArms && e.a == 1 && e.n1 == 0), isTrue);
      final free = turn(g, {1: Orders()..declareIndependence = true});
      expect(g.overlordOf(1), -1);
      expect(g.atWar(0, 1), isTrue);
      expect(free.events.any((e) => e.kind == EventKind.independence), isTrue);
    });

    test('a vassal makes no war of its own', () {
      final g = gameWith(row, units: [5, 5, 5]);
      g.state.wars.clear();
      g.state.overlord[1] = 0;
      g.state.wars.add(pairKey(1, 2));
      turn(g, {});
      expect(g.atWar(1, 2), isFalse);
    });

    test('captured provinces count in the war score', () {
      final w = tinyWorld(
        links: [
          [1],
          [0, 2],
          [1],
        ],
        owners: [0, 1, 1],
        wars: [
          [0, 1],
        ],
      );
      final h = gameWith(w, units: [300, 0, 5]);
      turn(h, {0: Orders()..moves.add(const MoveOrder(0, 1, 300))});
      expect(h.warScore(0, 1), 1);
      expect(h.warScore(1, 0), -1);
    });
  });

  group('chronicle', () {
    test('records every turn from the start, then thins itself out', () {
      final g = gameWith(line, units: [3, 4, 5, 6]);
      expect(g.state.chronicle, hasLength(1));
      for (var i = 0; i < Rules.chronicleSamples; i++) {
        turn(g, {});
      }
      expect(g.state.chronicle.length, lessThanOrEqualTo(Rules.chronicleSamples));
      expect(g.state.chronicleEvery, 2);
      expect(g.state.chronicleFrom, 0);
      final latest = g.state.chronicle.last;
      expect(g.state.chronicleFrom + (g.state.chronicle.length - 1) * g.state.chronicleEvery, g.state.turn);
      expect([latest[0], latest[1], latest[2]], [g.provinceCount(0), g.unitsOf(0), g.incomeOf(0)]);
    });

    test('a game saved before the chronicle starts one where it stands', () {
      final g = gameWith(line, units: [1, 1, 1, 1]);
      turn(g, {});
      turn(g, {});
      g.state.chronicle.clear();
      turn(g, {});
      expect(g.state.chronicleFrom, 3);
      expect(g.state.chronicle, hasLength(1));
    });
  });

  group('relations and pacts', () {
    // Three at peace in a row: 0 | 1 | 2, with 1 and 2 allied.
    final row = tinyWorld(
      links: [
        [1],
        [0, 2],
        [1],
      ],
      owners: [0, 1, 2],
      alliances: [
        [1, 2],
      ],
    );

    test('start warm between allies and cold between enemies', () {
      final g = gameWith(row, units: [5, 5, 5]);
      expect(g.state.relation(1, 2), Rules.alliedRelation);
      expect(g.state.relation(0, 1), 0);
      expect(gameWith(line, units: [1, 1, 1, 1]).state.relation(0, 1), Rules.warRelation);
    });

    test('sink when war is declared, and further every turn of it', () {
      final g = gameWith(row, units: [5, 5, 5]);
      turn(g, {0: Orders()..declareWar.add(1)});
      expect(g.state.relation(0, 1), Rules.declaredRelation);
      expect(g.state.relation(0, 2), Rules.declaredRelation, reason: 'the ally was called to arms');
      turn(g, {});
      expect(g.state.relation(0, 1), Rules.declaredRelation - 1);
    });

    test('an envoy costs gold and warms relations', () {
      final g = gameWith(row, units: [0, 0, 0], gold: [100, 100, 100]);
      final cost = g.envoyCost(1);
      final income = g.incomeOf(0);
      final r = turn(g, {0: Orders()..envoys.add(1)});
      expect(g.state.relation(0, 1), Rules.envoyGain);
      expect(g.state.gold[0], 100 - cost + income);
      expect(r.events.singleWhere((e) => e.kind == EventKind.envoy).b, 1);
    });

    test('a gift moves gold across and warms relations by what it is worth to the receiver', () {
      final g = gameWith(row, units: [0, 0, 0], gold: [100, 0, 0]);
      final gift = g.incomeOf(1);
      turn(g, {0: Orders()..gifts[1] = gift});
      expect(g.state.relation(0, 1), Rules.giftGain);
      expect(g.state.gold[1], gift + g.incomeOf(1));
      expect(g.giftGain(1, 1000), Rules.giftMaxGain);
    });

    test('no envoys or gifts to an enemy', () {
      final g = gameWith(line, units: [1, 1, 1, 1], gold: [100, 100]);
      final before = g.state.relation(0, 1);
      turn(g, {
        0: Orders()
          ..envoys.add(1)
          ..gifts[1] = 50,
      });
      expect(g.state.relation(0, 1), before - 1);
      expect(g.state.gold[1], 100 + g.incomeOf(1) - g.upkeepOf(1));
    });

    test('drift back towards indifference in peace', () {
      final g = gameWith(row, units: [0, 0, 0]);
      g.state.setRelation(0, 1, 10);
      for (var i = 0; i < Rules.relationDriftTurns * 3; i++) {
        turn(g, {});
      }
      expect(g.state.relation(0, 1), 7);
    });

    test('a pact needs both sides, forbids war while it lasts, then lapses', () {
      final g = gameWith(row, units: [5, 5, 5]);
      final r1 = turn(g, {0: Orders()..offerPact.add(1)});
      expect(has(r1, EventKind.pactOffered), isTrue);
      final r2 = turn(g, {1: Orders()..offerPact.add(0)});
      expect(has(r2, EventKind.pactSigned), isTrue);
      expect(g.pactLeft(0, 1), Rules.pactTurns);
      expect(g.canDeclareWar(0, 1), isFalse);
      expect(g.canDeclareWar(1, 0), isFalse);
      turn(g, {0: Orders()..declareWar.add(1)});
      expect(g.atWar(0, 1), isFalse);
      while (g.pactLeft(0, 1) > 0) {
        turn(g, {});
      }
      expect(g.state.pacts, isEmpty);
      expect(g.canDeclareWar(0, 1), isTrue);
    });

    test('a pact with the attacker keeps an ally out of the war', () {
      final g = gameWith(row, units: [5, 5, 5]);
      g.state.pacts[pairKey(0, 2)] = g.state.turn + 10;
      expect(g.wouldDefend(0, 1), isEmpty);
      turn(g, {0: Orders()..declareWar.add(1)});
      expect(g.atWar(0, 1), isTrue);
      expect(g.atWar(0, 2), isFalse);
    });

    test('leaving an alliance costs relations', () {
      final g = gameWith(row, units: [5, 5, 5]);
      turn(g, {1: Orders()..breakAlliance.add(2)});
      expect(g.state.relation(1, 2), Rules.alliedRelation + Rules.brokenRelation);
    });
  });

  group('happenings', () {
    test('never happen with random events off', () {
      final g = gameWith(line, units: [5, 5, 5, 5]);
      for (var i = 0; i < 200; i++) {
        expect(has(turn(g, {}), EventKind.happening), isFalse);
      }
    });

    test('happen now and then with them on, the same way for the same seed', () {
      String play() {
        final g = Game.start(line, human: -1, seed: 9, randomEvents: true);
        final kinds = <int>[];
        for (var i = 0; i < 300; i++) {
          kinds.addAll([
            for (final e in turn(g, {}).events)
              if (e.kind == EventKind.happening) e.n1,
          ]);
        }
        expect(kinds, isNotEmpty);
        return kinds.join(',');
      }

      expect(play(), play());
    });

    test("the player's answer waits for their orders and is paid first", () {
      final g = gameWith(line, units: [1, 1, 1, 1], gold: [100, 100], human: 0);
      g.state.development[1] = 2;
      g.state.pending[0] = encodePending(Happening.strike, 1);
      final cost = happeningCost(g, 0, Happening.strike, 1, 0);
      final r = turn(g, {0: Orders()..answer = 0});
      final e = r.events.firstWhere((e) => e.kind == EventKind.happening);
      expect((e.n1, e.n2, e.n3), (Happening.strike.index, 0, cost));
      expect(g.state.pending, isEmpty);
      expect(g.state.development[1], 2);
    });

    test('no answer, or one the treasury cannot pay, takes the course that costs nothing', () {
      final g = gameWith(line, units: [1, 1, 1, 1], gold: [0, 100], human: 0);
      g.state.development[1] = 2;
      g.state.pending[0] = encodePending(Happening.strike, 1);
      turn(g, {0: Orders()..answer = 0});
      expect(g.state.development[1], 1, reason: 'the strike was put down');
      g.state.pending[0] = encodePending(Happening.refugees, 1);
      final r = turn(g, {});
      expect(r.events.firstWhere((e) => e.kind == EventKind.happening).n2, 1);
      expect(g.state.development[1], 1);
    });

    test('an inventor funded is research done', () {
      final g = gameWith(line, units: [1, 1, 1, 1], human: 0);
      g.state.pending[0] = encodePending(Happening.inventor, 0);
      final next = g.researchCost(0, Field.values[g.state.researchFocus[0]]);
      turn(g, {0: Orders()..answer = 0});
      expect(g.state.research[0][g.state.researchFocus[0]], greaterThanOrEqualTo((next * inventorShare).floor()));
    });
  });

  group('the sea', () {
    // Two islands on one sea, a third on the next, a fourth on a sea of its
    // own, and an inland province behind the first.
    final islands = tinyWorld(
      links: [
        [4],
        [],
        [],
        [],
        [0],
      ],
      owners: [0, 1, 1, 1, 0],
      wars: [
        [0, 1],
      ],
      coast: [
        [0],
        [0],
        [1],
        [2],
        [],
      ],
      seas: const [
        SeaZone('Near', [1]),
        SeaZone('Next', [0]),
        SeaZone('Far', []),
      ],
    );

    test('a coast reaches every coast on its sea and the next', () {
      expect(islands.landings[0], {1, 2});
      expect(islands.landings[2], {0, 1});
      expect(islands.landings[3], isEmpty);
      expect(islands.landings[4], isEmpty);
      expect(islands.reaches(0, 3), isFalse);
    });

    test('troops land at less than full strength, and only within reach', () {
      final g = gameWith(islands, units: [100, 0, 0, 0, 0]);
      final r = turn(g, {
        0: Orders()
          ..moves.add(const MoveOrder(0, 1, 60))
          ..moves.add(const MoveOrder(0, 3, 40)),
      });
      expect(g.state.owner[1], 0);
      expect(g.state.owner[3], 1, reason: 'too far by sea');
      expect(g.state.units[0], 40);
      final landing = r.movements.single;
      expect((landing.to, landing.bySea, landing.hostile), (1, true, true));
      final battle = r.events.firstWhere((e) => e.kind == EventKind.battle);
      // A landing of 60 fights like 45: it keeps less than a march would.
      expect(g.state.units[1], lessThan(60 - battle.n2));
    });
  });

  group('history', () {
    World scripted() => tinyWorld(
          links: [
            [1],
            [0, 2],
            [1],
          ],
          owners: [0, 1, 2],
          history: const [
            HistoryEvent(turn: 1, text: 'Two joins Nought and attacks One.', alliances: [(2, 0)], wars: [(2, 1)]),
          ],
        );

    test('replays on its turn', () {
      final g = gameWith(scripted(), units: [5, 5, 5]);
      expect(has(turn(g, {}), EventKind.history), isFalse);
      final r = turn(g, {});
      expect(r.events.firstWhere((e) => e.kind == EventKind.history).n1, 0);
      expect(g.allied(0, 2), isTrue);
      expect(g.atWar(1, 2), isTrue);
    });

    test('is skipped once it no longer makes sense', () {
      final g = gameWith(scripted(), units: [5, 5, 5]);
      g.state.wars.add(pairKey(0, 2));
      g.state.alliances.add(pairKey(1, 2));
      turn(g, {});
      final r = turn(g, {});
      expect(has(r, EventKind.history), isFalse);
      expect(g.allied(0, 2), isFalse);
      expect(g.atWar(1, 2), isFalse);
    });

    test('never sends the player to war, only offers the alliance', () {
      final g = gameWith(scripted(), units: [5, 5, 5], human: 2);
      turn(g, {});
      turn(g, {});
      expect(g.atWar(1, 2), isFalse);
      expect(g.allied(0, 2), isFalse);
      expect(g.hasAllianceOffer(0, 2), isTrue);
    });
  });

  group('unrest', () {
    // 0 | 1 | 2: nation 2 starts with province 2 but has lost it to 1.
    final three = tinyWorld(
      links: [
        [1],
        [0, 2],
        [1],
      ],
      owners: [0, 1, 2],
    );

    Game occupied({required bool fallen, required bool atWar}) {
      final g = gameWith(three, units: [5, 5, 0]);
      g.state.owner[2] = 1;
      g.state.heldSince[2] = 0;
      if (fallen) {
        g.state.alive[2] = false;
        g.state.capital[2] = -1;
      } else {
        // Nation 2 keeps a foothold in province 0 for this test.
        g.state.owner[0] = 2;
        g.state.capital[2] = 0;
        g.state.alive[0] = false;
        g.state.capital[0] = -1;
      }
      if (atWar) g.state.wars.add(pairKey(1, 2));
      return g;
    }

    test('a garrison as strong as the militia keeps the peace', () {
      final g = occupied(fallen: true, atWar: false);
      expect(g.revoltChance(2), greaterThan(0));
      g.state.units[2] = g.militia(2);
      expect(g.revoltChance(2), 0);
    });

    test('land of a nation at peace with the holder stays quiet', () {
      expect(occupied(fallen: false, atWar: false).revoltChance(2), 0);
      expect(occupied(fallen: false, atWar: true).revoltChance(2), greaterThan(0));
    });

    test('a fallen nation rises again, at war with its conqueror', () {
      final g = occupied(fallen: true, atWar: false);
      TurnReport? report;
      for (var i = 0; i < 2000 && g.state.owner[2] == 1; i++) {
        g.state.heldSince[2] = g.state.turn - 1;
        report = turn(g, {});
      }
      expect(g.state.owner[2], 2);
      expect(g.state.alive[2], isTrue);
      expect(g.state.capital[2], 2);
      expect(g.atWar(1, 2), isTrue);
      final revolt = report!.events.singleWhere((e) => e.kind == EventKind.revolt);
      expect(revolt.flag, isTrue);
      expect(g.state.units[2], revolt.n1);
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

  test('a save from before alliances, buildings and research still opens', () {
    final g = gameWith(line, units: [1, 1, 1, 1]);
    final json = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
    final state = json['state'] as Map<String, dynamic>;
    for (final key in [
      'alliances',
      'allianceOffers',
      'allianceAsked',
      'peaceTerms',
      'gains',
      'tribute',
      'overlord',
      'chronicle',
      'chronicleEvery',
      'chronicleFrom',
      'forts',
      'development',
      'heldSince',
      'tech',
      'research',
      'researchFocus',
      'researchShare',
      'difficulty',
      'fog',
      'randomEvents',
      'relations',
      'pacts',
      'pactOffers',
      'pactAsked',
      'pending',
    ]) {
      expect(state.remove(key), isNotNull, reason: key);
    }
    final back = Game.fromJson(line, json);
    expect(back.state.alliances, isEmpty);
    expect(back.state.forts, [0, 0, 0, 0]);
    expect(back.provinceIncome(0), back.fullIncome(0));
    expect(back.techLevel(0, Field.army), 0);
    expect(back.state.difficulty, Rules.normalDifficulty);
    expect(back.state.fog, isFalse);
    expect(back.state.randomEvents, isTrue);
    expect(back.state.relation(0, 1), 0);
    expect(Orders.fromJson({'moves': [], 'recruits': [], 'declareWar': [], 'offerPeace': []}).isEmpty, isTrue);
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
      ..offerPeace.add(7)
      ..offerAlliance.add(8)
      ..breakAlliance.add(9)
      ..builds.add(const BuildOrder(10, Project.develop))
      ..research = const ResearchPlan(Field.industry, 30)
      ..peaceTerms[7] = Terms.vassal
      ..declareIndependence = true
      ..offerPact.add(11)
      ..envoys.add(12)
      ..gifts[13] = 40
      ..answer = 1;
    final back = Orders.fromJson(jsonDecode(jsonEncode(o.toJson())) as Map<String, dynamic>);
    expect(jsonEncode(back.toJson()), jsonEncode(o.toJson()));
  });

  test('pair keys ignore order', () {
    expect(pairKey(3, 17), pairKey(17, 3));
    expect(directedKey(3, 17), isNot(directedKey(17, 3)));
  });
}
