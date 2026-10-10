import 'package:flutter/material.dart';

import '../engine/events.dart';
import '../engine/world.dart';
import '../game/game_controller.dart';
import '../theme.dart';

enum Tone { good, bad, plain }

class Dispatch {
  const Dispatch(this.text, [this.tone = Tone.plain, this.peaceFrom = -1]);

  final String text;
  final Tone tone;

  /// Nation whose peace offer this line reports, or -1.
  final int peaceFrom;
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
          if (mine) {
            yours.add(Dispatch('Peace with ${nation(e.a == human ? e.b : e.a)}.', Tone.good));
          } else {
            elsewhere.add(Dispatch('${nation(e.a)} and ${nation(e.b)} made peace.'));
          }
        case EventKind.peaceOffered:
          if (e.b == human) {
            yours.add(Dispatch('${nation(e.a)} offers peace.', Tone.plain, e.a));
          } else if (e.a == human) {
            yours.add(Dispatch('Your peace offer reached ${nation(e.b)}. No answer yet.'));
          }
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
        case EventKind.capitalMoved:
          if (e.a == human) yours.add(Dispatch('Your court moved to ${place(e.province)}.', Tone.bad));
        case EventKind.desertion:
          if (e.a == human) yours.add(Dispatch('${e.n1} units went home unpaid. The treasury is empty.', Tone.bad));
        case EventKind.gameOver:
          break;
      }
    }
    for (final entry in taken.entries) {
      final (winner, loser) = entry.key;
      final provinces = entry.value;
      elsewhere.add(Dispatch(provinces.length == 1
          ? '${nation(winner)} took ${place(provinces.first)} from ${nation(loser)}.'
          : '${nation(winner)} took ${provinces.length} provinces from ${nation(loser)}.'));
    }
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
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.72),
    builder: (context) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 8, 6),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Dispatches', style: AtlasText.title),
                Text('What happened in ${controller.world.dateLabel(report.turn)}', style: AtlasText.note),
              ]),
            ),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close), tooltip: 'Close'),
          ]),
        ),
        const Divider(color: AtlasColors.brass),
        Flexible(
          child: ListenableBuilder(
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
      ]),
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
    final from = dispatch.peaceFrom;
    final canAnswer = from >= 0 && controller.peaceOffers.contains(from);
    final accepted = controller.orders.offerPeace.contains(from);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 4, height: 20, margin: const EdgeInsets.only(top: 1), color: color),
        const SizedBox(width: 12),
        Expanded(child: Text(dispatch.text, style: AtlasText.body)),
        if (canAnswer)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: accepted
                ? OutlinedButton(onPressed: () => controller.setPeaceOffered(from, false), child: const Text('ACCEPTED'))
                : FilledButton(onPressed: () => controller.setPeaceOffered(from, true), child: const Text('ACCEPT')),
          ),
      ]),
    );
  }
}
