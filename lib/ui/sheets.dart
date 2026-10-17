import 'package:flutter/material.dart';

import '../data/game_assets.dart';
import '../data/save_store.dart';
import '../engine/rules.dart';
import '../theme.dart';
import 'widgets.dart';

/// Lists the saved games. Returns the save the player picked, opened and
/// ready, or null.
Future<LoadedSave?> showLoadSheet(BuildContext context, GameAssets assets, SaveStore saves) => showAtlasSheet<LoadedSave>(context, (context) => _LoadSheet(assets, saves));

class _LoadSheet extends StatefulWidget {
  const _LoadSheet(this.assets, this.saves);

  final GameAssets assets;
  final SaveStore saves;

  @override
  State<_LoadSheet> createState() => _LoadSheetState();
}

class _LoadSheetState extends State<_LoadSheet> {
  late Future<List<SaveInfo>> _list = widget.saves.list();
  String? _error;

  Future<void> _open(SaveInfo save) async {
    try {
      final loaded = await widget.saves.load(save.id, widget.assets);
      if (mounted) Navigator.pop(context, loaded);
    } on FormatException catch (e) {
      setState(() => _error = 'This save cannot be opened: ${e.message}. It was probably made with an older version of the map.');
    }
  }

  Future<void> _delete(SaveInfo save) async {
    await widget.saves.delete(save.id);
    setState(() => _list = widget.saves.list());
  }

  static String _when(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return AtlasSheet(
      title: 'Load game',
      banner: _error == null ? null : Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 0), child: Text(_error!, style: AtlasText.body.copyWith(color: AtlasColors.signalText))),
      body: FutureBuilder<List<SaveInfo>>(
            future: _list,
            builder: (context, snapshot) {
              final saves = snapshot.data;
              if (saves == null) return const SizedBox(height: 120);
              if (saves.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No saved games yet. The game saves itself at the end of every turn.', style: AtlasText.note),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: saves.length,
                itemBuilder: (context, i) {
                  final save = saves[i];
                  final nation = widget.assets.nationOf(save.scenario, save.nation);
                  return InkWell(
                    onTap: () => _open(save),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
                      child: Row(children: [
                        NationSwatch(Color(nation?.color ?? 0xFF888888)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${nation?.shortName ?? 'Watching'}, ${save.date}', style: AtlasText.body),
                            Text('${save.isAutosave ? 'Autosave' : 'Saved'} ${_when(save.savedAt)}', style: AtlasText.note),
                          ]),
                        ),
                        IconButton(onPressed: () => _delete(save), icon: const Icon(Icons.delete_outline), tooltip: 'Delete this save'),
                      ]),
                    ),
                  );
                },
              );
            },
          ),
    );
  }
}

/// The rules, as short as they can be said.
Future<void> showHowToPlay(BuildContext context) {
  final cover = Rules.defenseBonus;
  final capital = Rules.defenseBonus + Rules.capitalBonus;
  final spread = (Rules.combatSpread * 100).round();
  final rules = [
    ('The turn', 'One turn is one month. Give your orders, then end the turn. Every nation moves at the same moment.'),
    (
      'Recruiting',
      'A unit costs ${Rules.unitCost} gold. A province raises up to ${Rules.recruitBase} plus its income each turn. '
          'New units defend at once and can march from the next turn.'
    ),
    ('Upkeep', 'Every ${Rules.unitsPerUpkeepGold} units cost 1 gold a turn. When the treasury runs dry, units go home.'),
    (
      'Building',
      'One project per province a turn. A fort multiplies the defence by ${Rules.fortBonus} more, up to ${Rules.maxFort} levels, '
          'and costs ${Rules.fortUpkeep} gold a turn per level. Development adds 1 income, up to ${Rules.maxDevelop} times.'
    ),
    (
      'Research',
      'Put a share of the income into army or industry. Each army level adds ${(Rules.armyTechBonus * 100).round()}% to the strength of every unit; '
          'each industry level adds ${(Rules.industryTechBonus * 100).round()}% to the income. Research is paid only from what is left after upkeep.'
    ),
    (
      'Conquest',
      'A province taken from its owner at the start yields ${(Rules.occupiedShare * 100).round()}% of its income at first, and all of it after ${Rules.integrationTurns} turns. '
          'Its old owner gets it back whole. A captured fort loses a level. '
          'Until then, land held with fewer units than its militia may revolt: back to its old owner if that owner is at war with you, '
          'or as the old nation itself, risen from defeat.'
    ),
    ('Moving', 'Units move one province a turn: across a border, or across a strait marked with a dotted line. Blue arrows are marches, red arrows are attacks.'),
    (
      'Battle',
      'An attack must beat the defence: the units in the province plus its militia, multiplied by $cover for being dug in '
          '($capital in a capital). Each side then rolls $spread% up or down. The loser is destroyed. The winner loses about as much strength as the loser brought.'
    ),
    ('War and peace', 'Select a foreign province to declare war on its owner. The border opens the turn after. Peace needs both sides to agree, and a truce of ${Rules.truceTurns} turns follows.'),
    (
      'Alliances',
      'An alliance needs both sides to agree. When someone declares war on one of you, the other joins the war at once. '
          'A war you start yourself stays yours: allies are not dragged into it. You can leave an alliance at any time, but not attack the ally in the same turn.'
    ),
    ('Winning', 'Hold the share of provinces chosen at the start and the war is yours. Lose your last province and it is over.'),
  ];
  return showAtlasSheet<void>(
    context,
    (context) => AtlasSheet(
      title: 'How to play',
      body: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
        children: [
          for (final (heading, text) in rules) ...[
            Padding(padding: const EdgeInsets.only(top: 14, bottom: 4), child: Text(heading.toUpperCase(), style: AtlasText.label.copyWith(color: AtlasColors.brassBright))),
            Text(text, style: AtlasText.body),
          ],
        ],
      ),
    ),
    heightFactor: 0.8,
  );
}
