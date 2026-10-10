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

  /// [GameEvent.a] could not pay its army; [GameEvent.n1] units left.
  desertion,

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
