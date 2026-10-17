import 'package:flutter/material.dart';

import '../engine/orders.dart';
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
              InputMode.build => _BuildChoice(c),
              InputMode.browse => mine ? _OwnProvince(c) : _ForeignProvince(c),
            },
          ),
        ],
      ),
    );
  }

  static String _ownerLine(GameController c, int owner, bool mine, bool capital) {
    final fort = switch (c.state.forts[c.selected]) {
      0 => '',
      1 => ', fort',
      _ => ', fortress',
    };
    final seat = '${capital ? ', capital' : ''}$fort';
    if (mine) return 'Yours$seat';
    final name = c.world.nations[owner].name;
    if (!c.commanding) return '$name$seat';
    return switch (c.relationTo(owner)) {
      Relation.war => '$name$seat. At war with you',
      Relation.ally => '$name$seat. Your ally',
      Relation.truce => '$name$seat. Truce, ${c.game.truceLeft(c.human, owner)} more turns',
      Relation.peace || Relation.you => '$name$seat. At peace with you',
    };
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
    final income = c.game.provinceIncome(p);
    final full = c.game.fullIncome(p);
    final units = c.unitsSeen(p);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 12),
      child: Row(children: [
        Expanded(child: Stat('Units', '${units ?? '?'}', detail: mine && ordered > 0 ? '+$ordered' : null, detailColor: AtlasColors.brassBright)),
        Expanded(child: Stat('Militia', '${c.game.militia(p)}')),
        Expanded(child: Stat('Income', '$income', detail: income < full ? 'of $full' : null)),
        Expanded(child: Stat('Defends', units == null ? '?' : '${c.game.defenseStrength(p)}', detail: '×${c.game.defenseMultiplier(p)}')),
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
    final build = c.buildAt(p);
    final String? hint;
    if (room == 0 && c.recruitsAt(p) >= c.game.recruitCap(p)) {
      hint = 'This province has raised all it can this turn.';
    } else if (room == 0) {
      hint = 'A unit costs ${Rules.unitCost} gold. The treasury has ${c.goldFree} left.';
    } else if (c.game.revoltChance(p) > 0) {
      hint = 'Taken from ${c.world.nations[c.world.startOwners[p]].shortName} and restless: keep ${c.game.militia(p)} units here or it may revolt.';
    } else if (c.game.isOccupied(p)) {
      hint = 'Taken from ${c.world.nations[c.world.startOwners[p]].shortName}: it yields its full income once it has been yours for ${Rules.integrationTurns} turns.';
    } else {
      hint = null;
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      _Stats(c),
      for (final r in recruits) _OrderRow('Raise ${r.count} units, ${r.count * Rules.unitCost} gold', () => c.cancelRecruit(r)),
      if (build != null) _OrderRow('${build.project == Project.fortify ? 'Build a fort' : 'Develop'}, ${c.game.buildCost(p, build.project)} gold', () => c.cancelBuild(build)),
      for (final m in moves) _OrderRow(_moveText(c, m), () => c.cancelMove(m), hostile: c.isHostile(m.to)),
      if (hint != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(hint, style: AtlasText.note)),
      Row(children: [
        Expanded(flex: 4, child: OutlinedButton(onPressed: room > 0 ? c.beginRecruit : null, child: const Text('RECRUIT'))),
        const SizedBox(width: 10),
        Expanded(flex: 3, child: OutlinedButton(onPressed: build == null ? c.beginBuild : null, child: const Text('BUILD'))),
        const SizedBox(width: 10),
        Expanded(flex: 5, child: FilledButton(onPressed: movable > 0 ? c.beginMove : null, child: Text(movable > 0 ? 'MOVE $movable' : 'NO UNITS FREE'))),
      ]),
    ]);
  }
}

String _moveText(GameController c, MoveOrder m) {
  final march = c.marchOf(m);
  if (march != null) {
    final turns = march.ahead.length;
    return 'March to ${c.world.provinces[march.to].name} with ${m.count}, $turns ${turns == 1 ? 'turn' : 'turns'}';
  }
  return '${c.isHostile(m.to) ? 'Attack' : 'Send to'} ${c.world.provinces[m.to].name} with ${m.count}';
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
          atWar
              ? 'Tap a highlighted province: one of yours to reinforce it, an enemy one to attack. Or tap any province of yours further off to march there.'
              : 'Tap a highlighted province to send units there, or any province of yours further off to march there.',
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
    final turns = c.marchTurns(c.selected, to);
    final march = turns > 0;
    final String line;
    if (march) {
      line = 'A march of $turns turns through your own land, one province a turn. They go on by themselves; cancel the order to stop them.';
    } else if (hostile) {
      final cover = c.game.defenseMultiplier(to);
      final army = c.game.techLevel(c.state.owner[to], Field.army);
      line = '$target defends with strength ${c.game.defenseStrength(to)}: ${c.state.units[to]} units and ${c.game.militia(to)} militia, '
          'dug in ×$cover${army > 0 ? ', army level $army' : ''}. Each side then rolls ±${(Rules.combatSpread * 100).round()}%.';
    } else {
      line = 'They arrive at the end of the turn, before any attack on $target.';
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(hostile ? 'Attack $target' : (march ? 'March to $target' : 'Send units to $target'), style: AtlasText.body.copyWith(color: hostile ? AtlasColors.signalText : AtlasColors.ivory)),
      ),
      Text(line, style: AtlasText.note),
      AmountPicker(
        key: ValueKey('move-${c.selected}-$to'),
        max: c.movable(c.selected),
        confirmLabel: (n) => hostile ? 'Attack with $n' : (march ? 'March $n' : 'Send $n'),
        verdict: hostile ? (n) => _odds(n + c.headingTo(to), c.game.armyFactor(c.human), c.game.defenseStrength(to), c.headingTo(to)) : null,
        onConfirm: c.confirmMove,
        onCancel: c.cancelInput,
      ),
    ]);
  }
}

/// How [attackers], each worth [factor] by the army's technology, stand
/// against [defence] as things are now. The rolls swing each side by
/// [Rules.combatSpread], so only clear margins are sure.
String _odds(int attackers, double factor, int defence, int alreadySent) {
  const low = (1 - Rules.combatSpread) / (1 + Rules.combatSpread);
  final strength = (attackers * factor).floor();
  final ratio = strength / defence;
  final worth = factor > 1 ? ' (strength $strength)' : '';
  final force = alreadySent > 0 ? '$attackers in all$worth against $defence' : '$attackers$worth against $defence';
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

class _BuildChoice extends StatelessWidget {
  const _BuildChoice(this.controller);

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final p = c.selected;
    final fort = c.state.forts[p];
    final cover = c.game.defenseMultiplier(p);
    final income = c.game.fullIncome(p);
    Widget option(Project project, String title, String note, String done, String Function(int cost) label) {
      final cost = c.game.buildCost(p, project);
      final String text;
      if (cost < 0) {
        text = done;
      } else if (cost > c.goldFree) {
        text = 'Needs $cost gold';
      } else {
        text = label(cost);
      }
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: AtlasText.body),
          Text(note, style: AtlasText.note),
          const SizedBox(height: 8),
          FilledButton(onPressed: c.canBuild(p, project) ? () => c.orderBuild(project) : null, child: Text(text.toUpperCase())),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      option(
        Project.fortify,
        fort == 0 ? 'Fort' : 'Fortress',
        fort >= Rules.maxFort
            ? 'Defenders here fight at ×$cover. The walls cannot go higher.'
            : 'Defenders fight at ×${cover + Rules.fortBonus} instead of ×$cover. Every fort level costs ${Rules.fortUpkeep} gold a turn, and loses a level when the province falls.',
        'Fortress complete',
        (cost) => fort == 0 ? 'Build a fort for $cost gold' : 'Make it a fortress for $cost gold',
      ),
      option(
        Project.develop,
        'Development',
        c.state.development[p] >= Rules.maxDevelop
            ? 'Developed as far as it will go: income $income.'
            : 'Income $income becomes ${income + 1}, and with it the recruits and militia the province gives.',
        'Fully developed',
        (cost) => 'Develop for $cost gold',
      ),
      const SizedBox(height: 12),
      OutlinedButton(onPressed: c.cancelInput, child: const Text('CANCEL')),
    ]);
  }
}

/// What the player and another nation say to each other about an offer
/// that needs both sides: peace, or an alliance.
class _OfferWords {
  const _OfferWords({
    required this.signed,
    required this.sent,
    required this.offered,
    required this.waiting,
    required this.accept,
    required this.withdraw,
    required this.pending,
    required this.propose,
  });

  /// Notes: both sides agree; the player's offer goes out; theirs is in;
  /// the player's is unanswered.
  final String signed;
  final String sent;
  final String offered;
  final String waiting;

  /// Buttons.
  final String accept;
  final String withdraw;
  final String pending;
  final String propose;
}

/// The note, if any, and the button for an offer between the player and
/// another nation.
(String?, Widget) _offerAction(_OfferWords words, {required bool theyOffer, required bool weOffer, required bool standing, required ValueChanged<bool> answer}) {
  if (weOffer) return (theyOffer ? words.signed : words.sent, OutlinedButton(onPressed: () => answer(false), child: Text(words.withdraw)));
  if (theyOffer) return (words.offered, FilledButton(onPressed: () => answer(true), child: Text(words.accept)));
  if (standing) return (words.waiting, OutlinedButton(onPressed: null, child: Text(words.pending)));
  return (null, OutlinedButton(onPressed: () => answer(true), child: Text(words.propose)));
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

    final actions = <Widget>[];
    String? note;
    switch (c.relationTo(owner)) {
      case Relation.war:
        final (said, button) = _offerAction(
          _OfferWords(
            signed: 'Peace with $name will be signed at the end of the turn.',
            sent: 'Your peace offer goes to $name at the end of the turn.',
            offered: '$name offers peace.',
            waiting: '$name has your peace offer and has not answered.',
            accept: 'ACCEPT PEACE',
            withdraw: 'WITHDRAW THE OFFER',
            pending: 'PEACE OFFERED',
            propose: 'OFFER PEACE',
          ),
          theyOffer: c.game.hasPeaceOffer(owner, c.human),
          weOffer: c.orders.offerPeace.contains(owner),
          standing: c.game.hasPeaceOffer(c.human, owner),
          answer: (yes) => c.setPeaceOffered(owner, yes),
        );
        note = said ?? 'To attack, select one of your provinces next to this one and choose Move.';
        actions.add(button);
      case Relation.ally:
        if (c.orders.breakAlliance.contains(owner)) {
          note = 'You leave the alliance with $name at the end of the turn.';
          actions.add(OutlinedButton(onPressed: () => c.setAllianceBroken(owner, false), child: const Text('STAY ALLIED')));
        } else {
          note = 'Allies: if either of you is attacked, the other joins the war.';
          actions.add(OutlinedButton(onPressed: () => _confirmLeave(context, owner), child: const Text('LEAVE THE ALLIANCE')));
        }
      case Relation.truce || Relation.peace || Relation.you:
        if (c.orders.declareWar.contains(owner)) {
          note = 'War on $name begins at the end of the turn. Your armies may cross the border from next turn.';
          actions.add(OutlinedButton(onPressed: () => c.setWarDeclared(owner, false), child: const Text('CALL IT OFF')));
          break;
        }
        final (said, button) = _offerAction(
          _OfferWords(
            signed: 'The alliance with $name will be signed at the end of the turn.',
            sent: 'Your alliance offer goes to $name at the end of the turn.',
            offered: '$name proposes an alliance.',
            waiting: '$name has your alliance offer and has not answered.',
            accept: 'ACCEPT ALLIANCE',
            withdraw: 'WITHDRAW',
            pending: 'OFFERED',
            propose: 'PROPOSE ALLIANCE',
          ),
          theyOffer: c.game.hasAllianceOffer(owner, c.human),
          weOffer: c.orders.offerAlliance.contains(owner),
          standing: c.game.hasAllianceOffer(c.human, owner),
          answer: (yes) => c.setAllianceOffered(owner, yes),
        );
        note = said;
        actions.add(button);
        final truce = c.game.truceLeft(c.human, owner);
        if (truce > 0) {
          note ??= 'Truce with $name for $truce more turns.';
          actions.add(const OutlinedButton(onPressed: null, child: Text('TRUCE')));
        } else {
          actions.add(FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AtlasColors.signal, foregroundColor: AtlasColors.ivory),
            onPressed: () => _confirmWar(context, owner),
            child: const Text('DECLARE WAR'),
          ));
        }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      _Stats(c),
      if (note != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(note, style: AtlasText.note)),
      Row(children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: actions[i]),
        ],
      ]),
    ]);
  }

  Future<void> _confirmWar(BuildContext context, int owner) async {
    final c = controller;
    final nation = c.world.nations[owner];
    final names = [for (final d in c.game.wouldDefend(c.human, owner)) c.world.nations[d].shortName];
    final allies = switch (names.length) {
      0 => '',
      1 => ' Its ally ${names.single} will join the war against you.',
      _ => ' Its allies ${names.sublist(0, names.length - 1).join(', ')} and ${names.last} will join the war against you.',
    };
    final army = c.armyOf(owner);
    final sure = await confirm(
      context,
      title: 'Declare war on ${nation.shortName}?',
      body: '${nation.name} ${army != null ? 'fields $army units across' : 'holds'} ${c.game.provinceCount(owner)} provinces.$allies '
          'Your own allies stay out of a war you start. Once peace is signed, a truce of ${Rules.truceTurns} turns follows.',
      no: 'STAY AT PEACE',
      yes: 'DECLARE WAR',
      danger: true,
    );
    if (sure) c.setWarDeclared(owner, true);
  }

  Future<void> _confirmLeave(BuildContext context, int owner) async {
    final c = controller;
    final name = c.world.nations[owner].shortName;
    final sure = await confirm(
      context,
      title: 'Leave the alliance with $name?',
      body: "Neither of you will be bound to join the other's wars any more. You cannot declare war on $name this turn.",
      no: 'STAY ALLIED',
      yes: 'LEAVE',
    );
    if (sure) c.setAllianceBroken(owner, true);
  }
}
