/// What happened while a turn resolved. The UI turns these into the turn
/// report; the engine itself never reads them back.
library;

enum EventKind {
  /// [GameEvent.a] declared war on [GameEvent.b].
  warDeclared,

  /// [GameEvent.a] and [GameEvent.b] made peace.
  peaceSigned,

  /// [GameEvent.a] offers peace to [GameEvent.b], who has not answered yet.
  peaceOffered,

  /// [GameEvent.a] went to war with [GameEvent.b] because [GameEvent.b]
  /// declared war on [GameEvent.n1], an ally of [GameEvent.a].
  calledToArms,

  /// [GameEvent.a] and [GameEvent.b] signed an alliance.
  allianceSigned,

  /// [GameEvent.a] offers an alliance to [GameEvent.b], who has not answered yet.
  allianceOffered,

  /// [GameEvent.a] left its alliance with [GameEvent.b].
  allianceBroken,

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

class TurnReport {
  const TurnReport(this.turn, this.events);

  /// The turn that just ended.
  final int turn;
  final List<GameEvent> events;
}
