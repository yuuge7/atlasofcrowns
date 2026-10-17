import 'package:flutter/material.dart';

import '../engine/events.dart';
import '../engine/happenings.dart';
import '../engine/orders.dart';
import '../engine/rules.dart';
import '../engine/world.dart';
import '../game/game_controller.dart';
import '../theme.dart';
import 'diplomacy_sheet.dart';
import 'happening_dialog.dart';
import 'research_sheet.dart';
import 'widgets.dart';

enum Tone { good, bad, plain }

/// An offer the player can answer from the dispatches, or a happening
/// waiting for their answer.
enum Offer { peace, alliance, pact, happening }

class Dispatch {
  const Dispatch(this.text, [this.tone = Tone.plain, this.offer]);

  final String text;
  final Tone tone;

  /// The offer this line reports and the nation making it, if any.
  final (Offer, int)? offer;
}

/// A turn's events as sentences, split into what touched the player and
/// what happened elsewhere.
class Dispatches {
  Dispatches(TurnReport report, World world, int human) {
    String nation(int n) => n < 0 ? 'someone' : world.nations[n].shortName;
    String place(int p) => world.provinces[p].name;
    final taken = <(int, int), List<int>>{};

    for (final e in report.events) {
      final mine = e.involves(human);
      switch (e.kind) {
        case EventKind.warDeclared:
          if (e.a == human) {
            yours.add(Dispatch('You declared war on ${nation(e.b)}. The border opens next turn.'));
          } else if (e.b == human) {
            yours.add(Dispatch('${nation(e.a)} declared war on you.', Tone.bad));
          } else {
            elsewhere.add(Dispatch('${nation(e.a)} declared war on ${nation(e.b)}.'));
          }
        case EventKind.peaceSigned:
          final terms = Terms.values[e.n1];
          final winner = e.n2;
          final loser = winner == e.a ? e.b : e.a;
          final outcome = switch (terms) {
            Terms.reparations => winner == human
                ? ': ${nation(loser)} pays you reparations for ${Rules.reparationTurns} turns'
                : (loser == human ? ': you pay ${nation(winner)} reparations for ${Rules.reparationTurns} turns' : ', ${nation(loser)} paying reparations'),
            Terms.vassal => winner == human
                ? ': ${nation(loser)} is now your vassal'
                : (loser == human ? ': you are now the vassal of ${nation(winner)}' : ', ${nation(loser)} becoming a vassal of ${nation(winner)}'),
            Terms.white || Terms.accept => '',
          };
          if (mine) {
            yours.add(Dispatch('Peace with ${nation(e.a == human ? e.b : e.a)}$outcome.', loser == human && winner >= 0 ? Tone.bad : Tone.good));
          } else {
            elsewhere.add(Dispatch('${nation(e.a)} and ${nation(e.b)} made peace$outcome.'));
          }
        case EventKind.peaceOffered:
          final terms = Terms.values[e.n1];
          if (e.b == human) {
            final ask = switch (terms) {
              Terms.reparations => ' if you pay reparations: ${(Rules.reparationShare * 100).round()}% of your income for ${Rules.reparationTurns} turns',
              Terms.vassal => ' if you become its vassal: ${(Rules.vassalTribute * 100).round()}% of your income as tribute, and its wars your wars',
              Terms.white || Terms.accept => '',
            };
            yours.add(Dispatch('${nation(e.a)} offers peace$ask.', terms == Terms.white || terms == Terms.accept ? Tone.plain : Tone.bad, (Offer.peace, e.a)));
          } else if (e.a == human) {
            yours.add(Dispatch('Your peace offer reached ${nation(e.b)}. No answer yet.'));
          }
        case EventKind.independence:
          if (e.a == human) {
            yours.add(Dispatch('You threw off ${nation(e.b)}. Its armies will come.', Tone.bad));
          } else if (e.b == human) {
            yours.add(Dispatch('Your vassal ${nation(e.a)} declared its independence and is at war with you.', Tone.bad));
          } else {
            elsewhere.add(Dispatch('${nation(e.a)} threw off ${nation(e.b)}.'));
          }
        case EventKind.calledToArms:
          if (e.a == human) {
            yours.add(Dispatch('${nation(e.b)} attacked your ally ${nation(e.n1)}. You are at war with ${nation(e.b)}; the border opens next turn.', Tone.bad));
          } else if (e.b == human) {
            yours.add(Dispatch('${nation(e.a)} stands by ${nation(e.n1)} and declares war on you.', Tone.bad));
          } else if (e.n1 == human) {
            yours.add(Dispatch('${nation(e.a)} honours the alliance and joins your war against ${nation(e.b)}.', Tone.good));
          } else {
            elsewhere.add(Dispatch('${nation(e.a)} joins ${nation(e.n1)} against ${nation(e.b)}.'));
          }
        case EventKind.allianceSigned:
          if (mine) {
            yours.add(Dispatch('Alliance signed with ${nation(e.a == human ? e.b : e.a)}.', Tone.good));
          } else {
            elsewhere.add(Dispatch('${nation(e.a)} and ${nation(e.b)} signed an alliance.'));
          }
        case EventKind.allianceOffered:
          if (e.b == human) {
            yours.add(Dispatch('${nation(e.a)} proposes an alliance.', Tone.plain, (Offer.alliance, e.a)));
          } else if (e.a == human) {
            yours.add(Dispatch('Your alliance offer reached ${nation(e.b)}. No answer yet.'));
          }
        case EventKind.allianceBroken:
          if (e.a == human) {
            yours.add(Dispatch('You left the alliance with ${nation(e.b)}.'));
          } else if (e.b == human) {
            yours.add(Dispatch('${nation(e.a)} left its alliance with you.', Tone.bad));
          } else {
            elsewhere.add(Dispatch('${nation(e.a)} left its alliance with ${nation(e.b)}.'));
          }
        case EventKind.pactSigned:
          if (mine) {
            yours.add(Dispatch('Non-aggression pact signed with ${nation(e.a == human ? e.b : e.a)} for ${Rules.pactTurns} turns.', Tone.good));
          } else {
            elsewhere.add(Dispatch('${nation(e.a)} and ${nation(e.b)} signed a non-aggression pact.'));
          }
        case EventKind.pactOffered:
          if (e.b == human) {
            yours.add(Dispatch('${nation(e.a)} proposes a non-aggression pact for ${Rules.pactTurns} turns.', Tone.plain, (Offer.pact, e.a)));
          } else if (e.a == human) {
            yours.add(Dispatch('Your pact offer reached ${nation(e.b)}. No answer yet.'));
          }
        case EventKind.gift:
          if (e.a == human) {
            yours.add(Dispatch('You gave ${nation(e.b)} ${e.n1} gold. Relations ${signed(e.n2)}.'));
          } else if (e.b == human) {
            yours.add(Dispatch('${nation(e.a)} sent you ${e.n1} gold. Relations ${signed(e.n2)}.', Tone.good));
          }
        case EventKind.envoy:
          if (e.a == human) {
            yours.add(Dispatch('Your envoy was received in ${nation(e.b)}. Relations ${signed(e.n2)}.'));
          } else if (e.b == human) {
            yours.add(Dispatch('An envoy from ${nation(e.a)} was received at court. Relations ${signed(e.n2)}.', Tone.good));
          }
        case EventKind.happening:
          if (e.a == human) yours.add(_happening(e, world, nation, place));
        case EventKind.battle:
          if (e.a == human) {
            yours.add(e.flag
                ? Dispatch('Took ${place(e.province)} from ${nation(e.b)}: ${e.n1} attacked ${e.n2}, ${e.n3} hold it.', Tone.good)
                : Dispatch('The attack on ${place(e.province)} failed. All ${e.n1} were lost against ${e.n2} of ${nation(e.b)}.', Tone.bad));
          } else if (e.b == human) {
            yours.add(e.flag
                ? Dispatch('${place(e.province)} fell to ${nation(e.a)}: ${e.n1} overran your ${e.n2}.', Tone.bad)
                : Dispatch('${place(e.province)} held against ${e.n1} of ${nation(e.a)}.', Tone.good));
          }
        case EventKind.captured:
          if (!mine) taken.putIfAbsent((e.a, e.b), () => []).add(e.province);
        case EventKind.eliminated:
          if (e.a == human) {
            yours.add(const Dispatch('Your last province has fallen.', Tone.bad));
          } else if (e.b == human) {
            yours.add(Dispatch('${world.nations[e.a].name} is no more. You took its last province.', Tone.good));
          } else {
            elsewhere.add(Dispatch('${world.nations[e.a].name} is no more, conquered by ${nation(e.b)}.'));
          }
        case EventKind.revolt:
          final how = e.flag ? '${world.nations[e.a].name} rises again' : 'it goes back to ${nation(e.a)}';
          if (e.b == human) {
            yours.add(Dispatch('${place(e.province)} revolted against you: $how, with ${e.n1} rebels.${e.flag ? ' It is at war with you.' : ''}', Tone.bad));
          } else if (e.a == human) {
            yours.add(Dispatch('${place(e.province)} rose against ${nation(e.b)} and is yours again, with ${e.n1} rebels under arms.', Tone.good));
          } else {
            elsewhere.add(Dispatch('${place(e.province)} revolted against ${nation(e.b)}: $how.'));
          }
        case EventKind.capitalMoved:
          if (e.a == human) yours.add(Dispatch('Your court moved to ${place(e.province)}.', Tone.bad));
        case EventKind.desertion:
          if (e.a == human) yours.add(Dispatch('${e.n1} units went home unpaid. The treasury is empty.', Tone.bad));
        case EventKind.techAdvanced:
          if (e.a == human) {
            final field = Field.values[e.n1];
            yours.add(Dispatch('${field == Field.army ? 'Army technology' : 'Industry'} reaches level ${e.n2}: ${techEffect(field, e.n2)}.', Tone.good));
          }
        case EventKind.history:
          final h = world.history[e.n1];
          final touched = h.alliances.any((p) => p.$1 == human || p.$2 == human) || h.wars.any((p) => p.$1 == human || p.$2 == human);
          (touched ? yours : elsewhere).add(Dispatch(h.text, Tone.plain));
        case EventKind.gameOver:
          break;
      }
    }
    for (final entry in taken.entries) {
      final (winner, loser) = entry.key;
      final provinces = entry.value;
      elsewhere.add(
          Dispatch(provinces.length == 1 ? '${nation(winner)} took ${place(provinces.first)} from ${nation(loser)}.' : '${nation(winner)} took ${provinces.length} provinces from ${nation(loser)}.'));
    }
  }

  /// How a happening to the player reads.
  static Dispatch _happening(GameEvent e, World world, String Function(int) nation, String Function(int) place) {
    final h = Happening.values[e.n1];
    final at = place(e.province);
    final amount = e.n3;
    if (e.n2 < 0) {
      final ask = switch (h) {
        Happening.strike => 'Workers strike in $at.',
        Happening.refugees => 'Refugees from the war reach $at.',
        Happening.inventor => 'An inventor asks for an audience.',
        _ => '',
      };
      return Dispatch(ask, Tone.plain, (Offer.happening, e.province));
    }
    final modern = world.startYear >= 1950;
    return switch ((h, e.n2)) {
      (Happening.harvest, _) => Dispatch('A bumper harvest in $at: $amount gold.', Tone.good),
      (Happening.windfall, _) => Dispatch('Customs and taxes came in above the estimate: $amount gold.', Tone.good),
      (Happening.epidemic, _) => amount > 0 ? Dispatch('Sickness in $at: $amount units died.', Tone.bad) : Dispatch('Sickness in $at. No soldiers were there to fall ill.'),
      (Happening.volunteers, _) => Dispatch('Volunteers flock to the colours in $at: $amount units.', Tone.good),
      (Happening.breakthrough, _) => Dispatch('A breakthrough in the laboratories: $amount gold of research done at once.', Tone.good),
      (Happening.scandal, _) => Dispatch('A scandal at court cost the treasury $amount gold.', Tone.bad),
      (Happening.fire, _) => Dispatch(amount > 0 ? 'Fire in $at. Rebuilding cost $amount gold.' : 'Fire in $at: a level of development lost.', Tone.bad),
      (Happening.railway, _) => Dispatch('${modern ? 'A new motorway' : 'A new railway'} reaches $at: a level of development.', Tone.good),
      (Happening.mutiny, _) => Dispatch('Unpaid troops mutinied in $at: $amount units deserted.', Tone.bad),
      (Happening.incident, _) => Dispatch('A border incident with ${nation(e.b)} near $at. Relations ${signed(incidentRelation)}.', Tone.bad),
      (Happening.visit, _) => Dispatch('A state visit from ${nation(e.b)}. Relations ${signed(visitRelation)}.', Tone.good),
      (Happening.strike, 0) => Dispatch('The strikers in $at were paid $amount gold and went back to work.'),
      (Happening.strike, _) => Dispatch(amount > 0 ? 'Troops broke the strike in $at: $amount units fell.' : 'Troops broke the strike in $at: a level of development lost.', Tone.bad),
      (Happening.refugees, 0) => Dispatch('Refugees found shelter in $at for $amount gold: a level of development.', Tone.good),
      (Happening.refugees, _) => Dispatch('Refugees were turned away from $at.'),
      (Happening.inventor, 0) => Dispatch('The inventor got to work: $amount gold of research done at once.', Tone.good),
      (Happening.inventor, _) => Dispatch('The inventor took the design elsewhere.'),
    };
  }

  final List<Dispatch> yours = [];
  final List<Dispatch> elsewhere = [];

  bool get isEmpty => yours.isEmpty && elsewhere.isEmpty;
}

/// Shows the report of the last turn. Peace offers can be accepted in place.
Future<void> showDispatches(BuildContext context, GameController controller) {
  final report = controller.lastReport;
  if (report == null) return Future.value();
  final dispatches = Dispatches(report, controller.world, controller.human);
  return showAtlasSheet<void>(
    context,
    (context) => AtlasSheet(
      title: 'Dispatches',
      note: 'What happened in ${controller.world.dateLabel(report.turn)}',
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          children: [
            if (dispatches.isEmpty) const Text('A quiet month. Nothing to report.', style: AtlasText.note),
            if (dispatches.yours.isNotEmpty) const _Heading('Your realm'),
            for (final d in dispatches.yours) _Line(d, controller),
            if (dispatches.elsewhere.isNotEmpty) const _Heading('Elsewhere'),
            for (final d in dispatches.elsewhere) _Line(d, controller),
          ],
        ),
      ),
    ),
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(top: 12, bottom: 6), child: Text(text.toUpperCase(), style: AtlasText.label));
  }
}

class _Line extends StatelessWidget {
  const _Line(this.dispatch, this.controller);

  final Dispatch dispatch;
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final color = switch (dispatch.tone) {
      Tone.good => AtlasColors.brassBright,
      Tone.bad => AtlasColors.signal,
      Tone.plain => AtlasColors.baizeLight,
    };
    Widget? reply;
    if (dispatch.offer case (Offer.happening, final province)) {
      if (controller.pendingHappening?.$2 == province) {
        reply = controller.orders.answer == null
            ? FilledButton(onPressed: () => showHappening(context, controller), child: const Text('ANSWER'))
            : OutlinedButton(onPressed: () => showHappening(context, controller), child: const Text('CHANGE'));
      }
    } else if (dispatch.offer case (final kind, final from)) {
      final (open, answered, answer) = switch (kind) {
        Offer.peace => (controller.peaceOffers, controller.orders.offerPeace, controller.setPeaceOffered),
        Offer.alliance => (controller.allianceOffers, controller.orders.offerAlliance, controller.setAllianceOffered),
        Offer.pact || Offer.happening => (controller.pactOffers, controller.orders.offerPact, controller.setPactOffered),
      };
      if (open.contains(from)) {
        reply = answered.contains(from)
            ? OutlinedButton(onPressed: () => answer(from, false), child: const Text('ACCEPTED'))
            : FilledButton(onPressed: () => answer(from, true), child: const Text('ACCEPT'));
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 4, height: 20, margin: const EdgeInsets.only(top: 1), color: color),
        const SizedBox(width: 12),
        Expanded(child: Text(dispatch.text, style: AtlasText.body)),
        if (reply != null) Padding(padding: const EdgeInsets.only(left: 8), child: reply),
      ]),
    );
  }
}
