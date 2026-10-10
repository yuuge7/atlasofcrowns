import 'package:flutter/material.dart';

import '../engine/rules.dart';
import '../game/game_controller.dart';
import '../theme.dart';
import 'widgets.dart';

/// The panel at the bottom of the game screen: what the selected province
/// is, and what the player can do with it.
class ProvinceSheet extends StatelessWidget {
  const ProvinceSheet(this.controller, {super.key});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final p = c.selected;
    if (p < 0) return const SizedBox.shrink();
    final province = c.world.provinces[p];
    final owner = c.state.owner[p];
    final nation = c.world.nations[owner];
    final mine = c.commanding && owner == c.human;

    return Panel(
      ruleOnTop: true,
      padding: EdgeInsets.fromLTRB(16, 12, 8, 12 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            NationSwatch(Color(nation.color)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(province.name, style: AtlasText.place, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(_ownerLine(c, owner, mine, c.game.isCapital(p)), style: AtlasText.note, maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            IconButton(onPressed: () => c.tapProvince(-1), icon: const Icon(Icons.close), tooltip: 'Close'),
          ]),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: switch (c.mode) {
              InputMode.pickTarget => _PickTarget(c),
              InputMode.moveAmount => _MoveAmount(c),
              InputMode.recruitAmount => _RecruitAmount(c),
              InputMode.browse => mine ? _OwnProvince(c) : _ForeignProvince(c),
            },
          ),
        ],
      ),
    );
  }

  static String _ownerLine(GameController c, int owner, bool mine, bool capital) {
    final seat = capital ? ', capital' : '';
    if (mine) return 'Yours$seat';
    final name = c.world.nations[owner].name;
    if (!c.commanding) return '$name$seat';
    if (c.game.atWar(c.human, owner)) return '$name$seat. At war with you';
    final truce = c.game.truceLeft(c.human, owner);
    return truce > 0 ? '$name$seat. Truce, $truce more turns' : '$name$seat. At peace with you';
  }
}

class _Stats extends StatelessWidget {
  const _Stats(this.controller);

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final p = c.selected;
    final mine = c.commanding && c.state.owner[p] == c.human;
    final ordered = c.recruitsAt(p);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 12),
      child: Row(children: [
        Expanded(child: Stat('Units', '${c.state.units[p]}', detail: mine && ordered > 0 ? '+$ordered' : null, detailColor: AtlasColors.brassBright)),
        Expanded(child: Stat('Militia', '${c.game.militia(p)}')),
        Expanded(child: Stat('Income', '${c.world.provinces[p].income}')),
        Expanded(child: Stat('Defends', '${c.game.defenseStrength(p)}')),
      ]),
    );
  }
}

class _OwnProvince extends StatelessWidget {
  const _OwnProvince(this.controller);

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final p = c.selected;
    final room = c.recruitRoom(p);
    final movable = c.movable(p);
    final moves = c.orders.moves.where((m) => m.from == p).toList();
    final recruits = c.orders.recruits.where((r) => r.province == p).toList();
    final String? hint;
    if (room == 0 && c.recruitsAt(p) >= c.game.recruitCap(p)) {
      hint = 'This province has raised all it can this turn.';
    } else if (room == 0) {
      hint = 'A unit costs ${Rules.unitCost} gold. The treasury has ${c.goldFree} left.';
    } else {
      hint = null;
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      _Stats(c),
      for (final r in recruits) _OrderRow('Raise ${r.count} units, ${r.count * Rules.unitCost} gold', () => c.cancelRecruit(r)),
      for (final m in moves)
        _OrderRow('${c.isHostile(m.to) ? 'Attack' : 'Send to'} ${c.world.provinces[m.to].name} with ${m.count}', () => c.cancelMove(m), hostile: c.isHostile(m.to)),
      if (hint != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(hint, style: AtlasText.note)),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: room > 0 ? c.beginRecruit : null, child: const Text('RECRUIT'))),
        const SizedBox(width: 12),
        Expanded(child: FilledButton(onPressed: movable > 0 ? c.beginMove : null, child: Text(movable > 0 ? 'MOVE $movable' : 'NO UNITS FREE'))),
      ]),
    ]);
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow(this.text, this.onCancel, {this.hostile = false});

  final String text;
  final VoidCallback onCancel;
  final bool hostile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Container(width: 14, height: 4, color: hostile ? AtlasColors.signal : AtlasColors.staffBlue),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: AtlasText.body, maxLines: 1, overflow: TextOverflow.ellipsis)),
        IconButton(onPressed: onCancel, icon: const Icon(Icons.undo, size: 20), tooltip: 'Cancel this order'),
      ]),
    );
  }
}

class _PickTarget extends StatelessWidget {
  const _PickTarget(this.controller);

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final atWar = c.targetsFrom(c.selected).any(c.isHostile);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          atWar ? 'Tap a highlighted province: one of yours to reinforce it, an enemy one to attack.' : 'Tap a highlighted province to send units there.',
          style: AtlasText.body,
        ),
      ),
      OutlinedButton(onPressed: c.cancelInput, child: const Text('CANCEL')),
    ]);
  }
}

class _MoveAmount extends StatelessWidget {
  const _MoveAmount(this.controller);

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final to = c.moveTarget;
    final target = c.world.provinces[to].name;
    final hostile = c.isHostile(to);
    final String line;
    if (hostile) {
      final cover = c.game.defenseMultiplier(to);
      line = '$target defends with strength ${c.game.defenseStrength(to)}: ${c.state.units[to]} units and ${c.game.militia(to)} militia, '
          'dug in ×$cover. Each side then rolls ±${(Rules.combatSpread * 100).round()}%.';
    } else {
      line = 'They arrive at the end of the turn, before any attack on $target.';
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(hostile ? 'Attack $target' : 'Send units to $target', style: AtlasText.body.copyWith(color: hostile ? const Color(0xFFF08A75) : AtlasColors.ivory)),
      ),
      Text(line, style: AtlasText.note),
      AmountPicker(
        key: ValueKey('move-${c.selected}-$to'),
        max: c.movable(c.selected),
        confirmLabel: (n) => hostile ? 'Attack with $n' : 'Send $n',
        verdict: hostile ? (n) => _odds(n + c.headingTo(to), c.game.defenseStrength(to), c.headingTo(to)) : null,
        onConfirm: c.confirmMove,
        onCancel: c.cancelInput,
      ),
    ]);
  }
}

/// How [attackers] stand against [defence] as things are now. The rolls
/// swing each side by [Rules.combatSpread], so only clear margins are sure.
String _odds(int attackers, int defence, int alreadySent) {
  const low = (1 - Rules.combatSpread) / (1 + Rules.combatSpread);
  final ratio = attackers / defence;
  final force = alreadySent > 0 ? '$attackers in all against $defence' : '$attackers against $defence';
  if (ratio < low) return '$force: no chance.';
  if (ratio < 0.95) return '$force: poor odds.';
  if (ratio < 1.08) return '$force: even odds.';
  if (ratio < 1 / low) return '$force: good odds.';
  return '$force: certain, unless they reinforce.';
}

class _RecruitAmount extends StatelessWidget {
  const _RecruitAmount(this.controller);

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text('Raise units here', style: AtlasText.body),
      ),
      Text('${Rules.unitCost} gold each. They can defend at once and march from next turn.', style: AtlasText.note),
      AmountPicker(
        key: ValueKey('recruit-${c.selected}'),
        max: c.recruitRoom(c.selected),
        confirmLabel: (n) => 'Raise $n for ${n * Rules.unitCost} gold',
        onConfirm: c.confirmRecruit,
        onCancel: c.cancelInput,
      ),
    ]);
  }
}

class _ForeignProvince extends StatelessWidget {
  const _ForeignProvince(this.controller);

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final owner = c.state.owner[c.selected];
    final name = c.world.nations[owner].shortName;
    if (!c.commanding) return _Stats(c);

    final Widget action;
    String? note;
    if (c.game.atWar(c.human, owner)) {
      final theyOffer = c.game.hasPeaceOffer(owner, c.human);
      final weOffer = c.orders.offerPeace.contains(owner);
      final standing = c.game.hasPeaceOffer(c.human, owner);
      if (weOffer) {
        note = theyOffer ? 'Peace with $name will be signed at the end of the turn.' : 'Your peace offer goes to $name at the end of the turn.';
        action = OutlinedButton(onPressed: () => c.setPeaceOffered(owner, false), child: const Text('WITHDRAW THE OFFER'));
      } else if (theyOffer) {
        note = '$name offers peace.';
        action = FilledButton(onPressed: () => c.setPeaceOffered(owner, true), child: const Text('ACCEPT PEACE'));
      } else if (standing) {
        note = '$name has your peace offer and has not answered.';
        action = const OutlinedButton(onPressed: null, child: Text('PEACE OFFERED'));
      } else {
        note = 'To attack, select one of your provinces next to this one and choose Move.';
        action = OutlinedButton(onPressed: () => c.setPeaceOffered(owner, true), child: const Text('OFFER PEACE'));
      }
    } else if (c.orders.declareWar.contains(owner)) {
      note = 'War on $name begins at the end of the turn. Your armies may cross the border from next turn.';
      action = OutlinedButton(onPressed: () => c.setWarDeclared(owner, false), child: const Text('CALL IT OFF'));
    } else if (c.game.truceLeft(c.human, owner) > 0) {
      action = const OutlinedButton(onPressed: null, child: Text('TRUCE IN FORCE'));
    } else {
      action = FilledButton(
        style: FilledButton.styleFrom(backgroundColor: AtlasColors.signal, foregroundColor: AtlasColors.ivory),
        onPressed: () async {
          final sure = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Declare war on $name?'),
              content: Text('${c.world.nations[owner].name} fields ${c.game.unitsOf(owner)} units across ${c.game.provinceCount(owner)} provinces. '
                  'Once peace is signed, a truce of ${Rules.truceTurns} turns follows.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('STAY AT PEACE')),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AtlasColors.signal, foregroundColor: AtlasColors.ivory),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('DECLARE WAR'),
                ),
              ],
            ),
          );
          if (sure ?? false) c.setWarDeclared(owner, true);
        },
        child: const Text('DECLARE WAR'),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      _Stats(c),
      if (note != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(note, style: AtlasText.note)),
      action,
    ]);
  }
}
