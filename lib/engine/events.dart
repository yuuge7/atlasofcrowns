/// What happened while a turn resolved. The UI turns these into the turn
/// report; the engine itself never reads them back.
library;

enum EventKind {
  /// [GameEvent.a] declared war on [GameEvent.b].
  warDeclared,

  /// [GameEvent.a] and [GameEvent.b] made peace, on the terms with index
  /// [GameEvent.n1] that nation [GameEvent.n2] asked for (-1 for white).
  peaceSigned,

  /// [GameEvent.a] offers peace to [GameEvent.b], who has not answered yet,
  /// on the terms with index [GameEvent.n1].
  peaceOffered,

  /// [GameEvent.a] threw off its overlord [GameEvent.b] and is at war with it.
  independence,

  /// [GameEvent.a] went to war with [GameEvent.b] because [GameEvent.b]
  /// declared war on [GameEvent.n1], an ally of [GameEvent.a].
  calledToArms,

  /// [GameEvent.a] and [GameEvent.b] signed an alliance.
  allianceSigned,

  /// [GameEvent.a] offers an alliance to [GameEvent.b], who has not answered yet.
  allianceOffered,

  /// [GameEvent.a] left its alliance with [GameEvent.b].
  allianceBroken,

  /// [GameEvent.a] and [GameEvent.b] signed a non-aggression pact.
  pactSigned,

  /// [GameEvent.a] offers [GameEvent.b] a non-aggression pact, not yet
  /// answered.
  pactOffered,

  /// [GameEvent.a] gave [GameEvent.b] [GameEvent.n1] gold; relations rose
  /// by [GameEvent.n2].
  gift,

  /// [GameEvent.a] sent an envoy to [GameEvent.b]; relations rose by
  /// [GameEvent.n2].
  envoy,

  /// Something happened by chance to [GameEvent.a], in
  /// [GameEvent.province]: the happening with index [GameEvent.n1],
  /// answered with choice [GameEvent.n2] (-1 while the answer is awaited).
  /// [GameEvent.n3] is the gold, units or research it came to, and
  /// [GameEvent.b] the other nation involved, if any.
  happening,

  /// [GameEvent.a] attacked [GameEvent.b] in [GameEvent.province] with
  /// [GameEvent.n1] units against [GameEvent.n2]; the winner kept
  /// [GameEvent.n3]. [GameEvent.flag] is true when the attacker won.
  battle,

  /// [GameEvent.a] took [GameEvent.province] from [GameEvent.b].
  captured,

  /// [GameEvent.a] lost its last province, to [GameEvent.b].
  eliminated,

  /// [GameEvent.a] moved its capital to [GameEvent.province].
  capitalMoved,

  /// [GameEvent.province] rose against [GameEvent.b] and went back to
  /// [GameEvent.a], with [GameEvent.n1] rebels. [GameEvent.flag] is true
  /// when [GameEvent.a] had fallen and rises again from it.
  revolt,

  /// [GameEvent.a] could not pay its army; [GameEvent.n1] units left.
  desertion,

  /// [GameEvent.a] reached level [GameEvent.n2] in the research field with
  /// index [GameEvent.n1].
  techAdvanced,

  /// The scripted event [World.history] at index [GameEvent.n1] took place.
  history,

  /// [GameEvent.a] won, or -1 when the human player was wiped out.
  gameOver,
}

class GameEvent {
  const GameEvent(this.kind, {this.a = -1, this.b = -1, this.province = -1, this.n1 = 0, this.n2 = 0, this.n3 = 0, this.flag = false});

  final EventKind kind;
  final int a;
  final int b;
  final int province;
  final int n1;
  final int n2;
  final int n3;
  final bool flag;

  /// True when nation [n] is one of the two parties.
  bool involves(int n) => n >= 0 && (a == n || b == n);
}

/// Units [nation] actually sent from [from] to [to] in a turn: a march
/// through its own land, or an attack when [hostile].
class Movement {
  const Movement(this.nation, this.from, this.to, this.count, {required this.hostile, this.bySea = false});

  final int nation;
  final int from;
  final int to;
  final int count;
  final bool hostile;

  /// Shipped across a sea zone rather than marched overland.
  final bool bySea;
}

class TurnReport {
  const TurnReport(this.turn, this.events, [this.movements = const []]);

  /// The turn that just ended.
  final int turn;
  final List<GameEvent> events;

  /// Every move the rules let through, in the order it was carried out.
  final List<Movement> movements;
}
