import 'package:flutter/material.dart';

import '../engine/rules.dart';
import '../engine/world.dart';
import '../theme.dart';
import 'widgets.dart';

/// How a new game is set up, besides the scenario and the nation.
class GameSettings {
  const GameSettings({
    this.winFraction = Rules.defaultWinFraction,
    this.endless = false,
    this.difficulty = Rules.normalDifficulty,
    this.monthsPerTurn = 1,
    this.fog = false,
    this.randomEvents = true,
  });

  /// Share of all provinces that wins, unless [endless].
  final double winFraction;

  /// Nobody wins: the game goes on as long as the player likes.
  final bool endless;
  final int difficulty;
  final int monthsPerTurn;
  final bool fog;
  final bool randomEvents;

  GameSettings copyWith({double? winFraction, bool? endless, int? difficulty, int? monthsPerTurn, bool? fog, bool? randomEvents}) => GameSettings(
        winFraction: winFraction ?? this.winFraction,
        endless: endless ?? this.endless,
        difficulty: difficulty ?? this.difficulty,
        monthsPerTurn: monthsPerTurn ?? this.monthsPerTurn,
        fog: fog ?? this.fog,
        randomEvents: randomEvents ?? this.randomEvents,
      );

  static const difficulties = ['Easy', 'Normal', 'Hard'];

  /// Share of the map the largest nation of [world] holds when it opens.
  static double largestShare(World world) {
    final held = List.filled(world.nations.length, 0);
    for (final o in world.startOwners) {
      if (!world.isWild(o)) held[o]++;
    }
    return held.reduce((a, b) => a > b ? a : b) / world.provinces.length;
  }

  /// Whether a game of [world] can still be won with [fraction]: it must be
  /// well beyond what any nation holds at the start.
  static bool canWin(World world, double fraction) => fraction >= largestShare(world) + 0.05;

  /// These settings, with the victory raised to the first share [world]
  /// allows when the chosen one is too low for it.
  GameSettings fitFor(World world) => endless || canWin(world, winFraction) ? this : copyWith(winFraction: Rules.winFractions.firstWhere((f) => canWin(world, f), orElse: () => 1.0));

  /// The victory condition in a few words.
  String victoryLabel(int provinces) {
    if (endless) return 'No victory';
    if (winFraction >= 1) return 'The whole map';
    return '${(winFraction * 100).round()}%, ${(winFraction * provinces).ceil()} provinces';
  }

  static String turnLabel(int months) => switch (months) {
        1 => 'A month',
        3 => 'A season',
        12 => 'A year',
        _ => '$months months',
      };
}

/// The settings of a new game in two lines, opening [showGameSettings].
class SettingsSummary extends StatelessWidget {
  const SettingsSummary({super.key, required this.settings, required this.world, required this.onTap});

  final GameSettings settings;
  final World world;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = settings;
    final top = '${s.victoryLabel(world.provinces.length)} · ${GameSettings.difficulties[s.difficulty]}';
    final bottom = '${GameSettings.turnLabel(s.monthsPerTurn)} a turn · fog ${s.fog ? 'on' : 'off'} · events ${s.randomEvents ? 'on' : 'off'}';
    return Semantics(
      button: true,
      label: 'Game settings: $top, $bottom. Tap to change.',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(5), border: Border.all(color: AtlasColors.brass)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('GAME SETTINGS', style: AtlasText.label),
                const SizedBox(height: 3),
                Text(top, style: AtlasText.figure.copyWith(fontSize: 17), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(bottom, style: AtlasText.note.copyWith(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            const Icon(Icons.tune, color: AtlasColors.brassBright),
          ]),
        ),
      ),
    );
  }
}

/// Lets the player change every setting of a new game; [onChanged] gets
/// each change as it is made.
Future<void> showGameSettings(BuildContext context, {required GameSettings settings, required World world, required ValueChanged<GameSettings> onChanged}) {
  var current = settings;
  return showAtlasSheet<void>(
    context,
    (context) => StatefulBuilder(builder: (context, setState) {
      void set(GameSettings next) {
        setState(() => current = next);
        onChanged(next);
      }

      final provinces = world.provinces.length;
      final s = current;
      final years = (1000 * s.monthsPerTurn / 12).round();
      return AtlasSheet(
        title: 'Game settings',
        note: world.scenarioName,
        body: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            _Group(
              title: 'Victory',
              note: s.endless
                  ? 'Nobody wins. Play as long as you like; the game ends only if you lose your last province.'
                  : 'Hold ${(s.winFraction * provinces).ceil()} of the $provinces provinces, your vassals\' included.'
                      '${GameSettings.canWin(world, Rules.winFractions.first) ? '' : ' One nation already holds ${(GameSettings.largestShare(world) * 100).round()}% of this map, so smaller shares are out.'}',
              choices: [
                for (final f in Rules.winFractions)
                  (
                    f >= 1 ? 'All' : '${(f * 100).round()}%',
                    !s.endless && s.winFraction == f,
                    GameSettings.canWin(world, f) ? () => set(s.copyWith(winFraction: f, endless: false)) : null,
                  ),
                ('Never', s.endless, () => set(s.copyWith(endless: true))),
              ],
            ),
            _Group(
              title: 'Turn',
              note: 'Each turn moves the calendar on by ${GameSettings.turnLabel(s.monthsPerTurn).toLowerCase()}: a thousand turns are $years years. '
                  'Every rule counts in turns, so only the dates change.',
              choices: [
                for (final m in Rules.turnLengths) (GameSettings.turnLabel(m), s.monthsPerTurn == m, () => set(s.copyWith(monthsPerTurn: m))),
              ],
            ),
            _Group(
              title: 'Difficulty',
              note: switch (s.difficulty) {
                0 =>
                  'The AI nations earn ${(Rules.aiIncome[0] * 100).round()}% of a normal income, leave you alone for your first ${Rules.aiSparePlayerTurns[0]} turns and look for other prey before you.',
                1 => 'The AI nations earn a normal income, leave you alone for your first ${Rules.aiSparePlayerTurns[1]} turns and are a little slower to pick on you.',
                _ => 'The AI nations earn ${(Rules.aiIncome[s.difficulty] * 100).round()}% of a normal income and come for you as for anyone.',
              },
              choices: [
                for (var d = 0; d < GameSettings.difficulties.length; d++) (GameSettings.difficulties[d], s.difficulty == d, () => set(s.copyWith(difficulty: d))),
              ],
            ),
            _Group(
              title: 'Fog of war',
              note: s.fog ? 'You see armies only in your own and allied land and next to it.' : 'Every army on the map is in sight.',
              choices: [
                ('Off', !s.fog, () => set(s.copyWith(fog: false))),
                ('On', s.fog, () => set(s.copyWith(fog: true))),
              ],
            ),
            _Group(
              title: 'Random events',
              note: s.randomEvents ? 'Harvests, strikes, fires, inventors and more come by chance.' : 'Nothing happens by chance beyond the battles.',
              choices: [
                ('On', s.randomEvents, () => set(s.copyWith(randomEvents: true))),
                ('Off', !s.randomEvents, () => set(s.copyWith(randomEvents: false))),
              ],
            ),
          ],
        ),
      );
    }),
    heightFactor: 0.9,
  );
}

/// One setting: its name, a row of choices and what the chosen one means.
class _Group extends StatelessWidget {
  const _Group({required this.title, required this.note, required this.choices});

  final String title;
  final String note;

  /// Label, whether chosen, and what a tap does: null for a choice that is
  /// not open.
  final List<(String, bool, VoidCallback?)> choices;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text(title.toUpperCase(), style: AtlasText.label.copyWith(color: AtlasColors.brassBright)),
        const SizedBox(height: 8),
        Row(children: [
          for (final (label, selected, onTap) in choices) ...[
            if (label != choices.first.$1) const SizedBox(width: 6),
            Expanded(
              child: ChoiceTile(
                selected: selected,
                onTap: onTap ?? () {},
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  label.toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: AtlasText.button.copyWith(
                    fontSize: 15,
                    color: onTap == null ? AtlasColors.baizeLight : (selected ? AtlasColors.ivory : AtlasColors.ivoryDim),
                    decoration: onTap == null ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 6),
        Text(note, style: AtlasText.note),
      ]),
    );
  }
}
