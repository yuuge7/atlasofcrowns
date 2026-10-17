import 'package:flutter/material.dart';

import '../engine/rules.dart';
import '../game/game_controller.dart';
import '../theme.dart';
import 'flags.dart';
import 'widgets.dart';

/// How a nation feeling [value] about another puts it, in a word.
String feelingWord(int value) => switch (value) {
      <= -60 => 'hostile',
      <= -20 => 'unfriendly',
      < 20 => 'indifferent',
      < 60 => 'cordial',
      _ => 'friendly',
    };

/// [value] with its sign, as relations are written.
String signed(int value) => value > 0 ? '+$value' : '$value';

/// What the player and another nation say to each other about an offer
/// that needs both sides: peace, an alliance or a pact.
class OfferWords {
  const OfferWords({
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
(String?, Widget) offerAction(OfferWords words, {required bool theyOffer, required bool weOffer, required bool standing, required ValueChanged<bool> answer}) {
  if (weOffer) return (theyOffer ? words.signed : words.sent, OutlinedButton(onPressed: () => answer(false), child: Text(words.withdraw)));
  if (theyOffer) return (words.offered, FilledButton(onPressed: () => answer(true), child: Text(words.accept)));
  if (standing) return (words.waiting, OutlinedButton(onPressed: null, child: Text(words.pending)));
  return (null, OutlinedButton(onPressed: () => answer(true), child: Text(words.propose)));
}

/// The player's dealings with [nation] short of war: envoys, gifts and a
/// non-aggression pact.
Future<void> showDiplomacy(BuildContext context, GameController controller, int nation) {
  return showAtlasSheet<void>(
    context,
    (context) => ListenableBuilder(listenable: controller, builder: (context, _) => _DiplomacySheet(controller, nation)),
    heightFactor: 0.85,
  );
}

class _DiplomacySheet extends StatelessWidget {
  const _DiplomacySheet(this.controller, this.nation);

  final GameController controller;
  final int nation;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final n = c.world.nations[nation];
    final feeling = c.feeling(nation);
    final courting = c.game.canCourt(c.human, nation);
    final envoy = c.orders.envoys.contains(nation);
    final gift = c.orders.gifts[nation] ?? 0;
    final theirIncome = c.game.incomeOf(nation);
    final amounts = {
      for (final share in const [0.5, 1, 2, 3]) (theirIncome * share).round().clamp(1, 1 << 30)
    }.toList();
    final pactLeft = c.game.pactLeft(c.human, nation);
    final envoyCost = c.game.envoyCost(nation);

    final (pactSaid, pactButton) = offerAction(
      OfferWords(
        signed: 'The pact with ${n.shortName} will be signed at the end of the turn.',
        sent: 'Your pact offer goes to ${n.shortName} at the end of the turn.',
        offered: '${n.shortName} proposes a non-aggression pact.',
        waiting: '${n.shortName} has your pact offer and has not answered.',
        accept: pactLeft > 0 ? 'ACCEPT RENEWAL' : 'ACCEPT PACT',
        withdraw: 'WITHDRAW',
        pending: 'OFFERED',
        propose: pactLeft > 0 ? 'RENEW THE PACT' : 'PROPOSE A PACT',
      ),
      theyOffer: c.game.hasPactOffer(nation, c.human),
      weOffer: c.orders.offerPact.contains(nation),
      standing: c.game.hasPactOffer(c.human, nation),
      answer: (yes) => c.setPactOffered(nation, yes),
    );
    final String pactNote;
    if (pactLeft > 0) {
      pactNote = 'Pact for $pactLeft more turns: neither of you may declare war on the other, nor join a war against the other through an alliance.';
    } else if (!c.game.canOfferPact(c.human, nation)) {
      pactNote = c.game.atWar(c.human, nation) ? 'Not while you are at war.' : (c.game.allied(c.human, nation) ? 'Allies need no pact.' : 'Not while either of you is a vassal.');
    } else {
      pactNote = 'For ${Rules.pactTurns} turns neither of you may declare war on the other, nor join a war against the other through an alliance.';
    }

    return AtlasSheet(
      title: n.name,
      note: 'Relations ${signed(feeling)}, ${feelingWord(feeling)}',
      body: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Row(children: [
            NationFlag(n, height: 28),
            const SizedBox(width: 14),
            Expanded(child: RelationScale(feeling)),
          ]),
          const SizedBox(height: 10),
          const Text(
            'Relations sink in war and drift back towards indifference in peace. '
            'A friend (+${Rules.aiFriendRelation}) accepts an alliance even without a common enemy; the hostile are the first to be attacked.',
            style: AtlasText.note,
          ),
          _Section(
            title: 'Envoy',
            note: courting ? 'Relations ${signed(Rules.envoyGain)}, for $envoyCost gold. One a turn.' : 'Not while you are at war.',
            child: envoy
                ? OutlinedButton(onPressed: () => c.setEnvoy(nation, false), child: const Text('CALL THE ENVOY BACK'))
                : FilledButton(
                    onPressed: courting && envoyCost <= c.goldFree ? () => c.setEnvoy(nation, true) : null,
                    child: Text(courting && envoyCost > c.goldFree ? 'NEEDS $envoyCost GOLD' : 'SEND AN ENVOY FOR $envoyCost GOLD'),
                  ),
          ),
          _Section(
            title: 'Gift',
            note: courting
                ? 'Gold leaves your treasury at the end of the turn. A turn of their income, $theirIncome gold, is worth ${signed(Rules.giftGain)}; no gift more than ${signed(Rules.giftMaxGain)}.'
                : 'Not while you are at war.',
            child: Row(children: [
              for (final amount in amounts) ...[
                if (amount != amounts.first) const SizedBox(width: 8),
                Expanded(
                  child: ChoiceTile(
                    selected: gift == amount,
                    onTap: () {
                      if (gift == amount) {
                        c.setGift(nation, 0);
                      } else if (courting && amount <= c.goldFree + gift) {
                        c.setGift(nation, amount);
                      }
                    },
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(children: [
                      Text('$amount', style: AtlasText.figure.copyWith(fontSize: 18, color: courting && amount <= c.goldFree + gift ? AtlasColors.ivory : AtlasColors.ivoryDim)),
                      Text(signed(c.game.giftGain(nation, amount)), style: AtlasText.label),
                    ]),
                  ),
                ),
              ],
            ]),
          ),
          _Section(
            title: 'Non-aggression pact',
            note: pactSaid ?? pactNote,
            child: c.game.canOfferPact(c.human, nation) || c.orders.offerPact.contains(nation) ? pactButton : null,
          ),
          _Section(
            title: 'Guarantee of independence',
            note: _guaranteeNote(c, nation),
            child: c.game.guarantees(c.human, nation)
                ? (c.orders.revokeGuarantee.contains(nation)
                    ? OutlinedButton(onPressed: () => c.setGuaranteeRevoked(nation, false), child: const Text('KEEP THE GUARANTEE'))
                    : OutlinedButton(onPressed: () => c.setGuaranteeRevoked(nation, true), child: const Text('WITHDRAW THE GUARANTEE')))
                : c.orders.guarantee.contains(nation)
                    ? OutlinedButton(onPressed: () => c.setGuarantee(nation, false), child: const Text('CALL IT OFF'))
                    : c.game.canGuarantee(c.human, nation)
                        ? FilledButton(onPressed: () => c.setGuarantee(nation, true), child: Text('GUARANTEE ${n.shortName.toUpperCase()}'))
                        : null,
          ),
        ],
      ),
    );
  }
}

/// What the guarantee section says: who already guarantees [nation], and
/// what the player's own guarantee does or would do.
String _guaranteeNote(GameController c, int nation) {
  final name = c.world.nations[nation].shortName;
  final others = [
    for (final g in c.game.guarantorsOf(nation))
      if (g != c.human) c.world.nations[g].shortName,
  ];
  final already = others.isEmpty ? '' : ' Already guaranteed by ${others.length == 1 ? others.single : '${others.sublist(0, others.length - 1).join(', ')} and ${others.last}'}.';
  if (c.game.guarantees(c.human, nation)) {
    return c.orders.revokeGuarantee.contains(nation)
        ? 'Your guarantee of $name ends at the end of the turn. Relations ${signed(Rules.brokenRelation)}.$already'
        : 'You guarantee $name: whoever declares war on it is at war with you.$already';
  }
  if (c.orders.guarantee.contains(nation)) return 'Your guarantee of $name begins at the end of the turn.$already';
  if (!c.game.canGuarantee(c.human, nation)) {
    final why = c.game.atWar(c.human, nation)
        ? 'Not while you are at war.'
        : c.game.allied(c.human, nation)
            ? 'Allies defend each other anyway.'
            : 'Not while either of you is a vassal.';
    return '$why$already';
  }
  return 'Promise to go to war with anyone who attacks $name. It does not bind $name to your wars. Relations ${signed(Rules.guaranteeRelation)}.$already';
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.note, this.child});

  final String title;
  final String note;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text(title.toUpperCase(), style: AtlasText.label.copyWith(color: AtlasColors.brassBright)),
        const SizedBox(height: 4),
        Text(note, style: AtlasText.note),
        if (child != null) ...[const SizedBox(height: 8), child!],
      ]),
    );
  }
}

/// Relations on their scale, hostile on the left and friendly on the right,
/// with a mark where [value] stands.
class RelationScale extends StatelessWidget {
  const RelationScale(this.value, {super.key});

  final int value;

  @override
  Widget build(BuildContext context) {
    final at = (value + Rules.maxRelation) / (2 * Rules.maxRelation);
    return Semantics(
      label: 'Relations ${signed(value)}, ${feelingWord(value)}',
      excludeSemantics: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          height: 18,
          child: LayoutBuilder(
            builder: (context, box) => Stack(clipBehavior: Clip.none, children: [
              Positioned(
                left: 0,
                right: 0,
                top: 4,
                height: 10,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AtlasColors.ink),
                    gradient: const LinearGradient(colors: [AtlasColors.mapEnemy, AtlasColors.mapNeutral, AtlasColors.mapFriend]),
                  ),
                ),
              ),
              Positioned(
                left: (box.maxWidth * at - 2).clamp(0, box.maxWidth - 4),
                top: 0,
                width: 4,
                height: 18,
                child: Container(decoration: BoxDecoration(color: AtlasColors.brassBright, border: Border.all(color: AtlasColors.ink))),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 3),
        Row(children: [
          Text('HOSTILE', style: AtlasText.label.copyWith(fontSize: 11)),
          const Spacer(),
          Text('INDIFFERENT', style: AtlasText.label.copyWith(fontSize: 11)),
          const Spacer(),
          Text('FRIENDLY', style: AtlasText.label.copyWith(fontSize: 11)),
        ]),
      ]),
    );
  }
}
