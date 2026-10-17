import 'package:flutter/material.dart';

import '../engine/happenings.dart';
import '../engine/orders.dart';
import '../game/game_controller.dart';
import '../theme.dart';
import 'widgets.dart';

/// What the player is asked about a happening: a title, the situation, and
/// each answer with what it leads to.
(String, String, List<(String, String)>) happeningPrompt(GameController c, Happening h, int province) {
  final place = c.world.provinces[province].name;
  final field = Field.values[c.state.researchFocus[c.human]] == Field.army ? 'army technology' : 'industry';
  final cost = c.happeningCostOf(0);
  return switch (h) {
    Happening.strike => (
        'Strike in $place',
        'Workers in $place have downed tools and want better pay.',
        [
          ('Pay them, $cost gold', 'The works start again.'),
          ('Send in the troops', c.state.development[province] > 0 ? '$place loses a level of development.' : 'Some of the garrison falls in the fighting.'),
        ],
      ),
    Happening.refugees => (
        'Refugees in $place',
        'Families fleeing the war have reached $place and ask for shelter.',
        [
          ('Shelter them, $cost gold', 'They settle and work: a level of development in $place.'),
          ('Turn them away', 'It costs nothing.'),
        ],
      ),
    Happening.inventor => (
        'An inventor at court',
        'An inventor offers a design that would speed up the research of $field.',
        [
          ('Fund it, $cost gold', '${(inventorShare * 100).round()}% of the next level of $field at once.'),
          ('Show the inventor out', 'It costs nothing.'),
        ],
      ),
    _ => (h.name, '', const []),
  };
}

/// Asks the player how to answer the happening waiting for them. The
/// answer goes out with the turn's orders.
Future<void> showHappening(BuildContext context, GameController c) async {
  final pending = c.pendingHappening;
  if (pending == null) return;
  final (h, province) = pending;
  final (title, body, choices) = happeningPrompt(c, h, province);
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(body, style: AtlasText.body),
        const SizedBox(height: 14),
        for (var i = 0; i < choices.length; i++)
          Builder(builder: (context) {
            final cost = c.happeningCostOf(i);
            // The gold already set aside for this answer is free for it.
            final affordable = cost <= c.goldFree + c.answerCost;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ChoiceTile(
                selected: c.orders.answer == i,
                onTap: () {
                  if (!affordable) return;
                  c.answerHappening(i);
                  Navigator.pop(context);
                },
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(choices[i].$1, style: AtlasText.body.copyWith(color: affordable ? AtlasColors.ivory : AtlasColors.ivoryDim)),
                  Text(affordable ? choices[i].$2 : 'The treasury has only ${c.goldFree + c.answerCost} gold.', style: AtlasText.note),
                ]),
              ),
            );
          }),
        Text('Your answer takes effect at the end of the turn.', style: AtlasText.note),
      ]),
    ),
  );
}
