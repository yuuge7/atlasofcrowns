/// What one nation asks for in one turn. Orders are requests: the resolver
/// checks every one of them against the rules and drops what is not allowed.
library;

class MoveOrder {
  const MoveOrder(this.from, this.to, this.count);

  final int from;
  final int to;
  final int count;

  List<int> toJson() => [from, to, count];

  static MoveOrder fromJson(List<dynamic> j) => MoveOrder(j[0] as int, j[1] as int, j[2] as int);
}

class RecruitOrder {
  const RecruitOrder(this.province, this.count);

  final int province;
  final int count;

  List<int> toJson() => [province, count];

  static RecruitOrder fromJson(List<dynamic> j) => RecruitOrder(j[0] as int, j[1] as int);
}

class Orders {
  Orders();

  factory Orders.fromJson(Map<String, dynamic> j) {
    return Orders()
      ..moves.addAll([for (final m in j['moves'] as List) MoveOrder.fromJson(m as List)])
      ..recruits.addAll([for (final r in j['recruits'] as List) RecruitOrder.fromJson(r as List)])
      ..declareWar.addAll((j['declareWar'] as List).cast<int>())
      ..offerPeace.addAll((j['offerPeace'] as List).cast<int>());
  }

  final List<MoveOrder> moves = [];
  final List<RecruitOrder> recruits = [];

  /// Nations to declare war on. Takes effect at the end of this turn; armies
  /// may cross the border from the next one.
  final Set<int> declareWar = {};

  /// Nations to offer peace to, or whose standing offer is accepted.
  final Set<int> offerPeace = {};

  bool get isEmpty => moves.isEmpty && recruits.isEmpty && declareWar.isEmpty && offerPeace.isEmpty;

  Map<String, dynamic> toJson() => {
        'moves': [for (final m in moves) m.toJson()],
        'recruits': [for (final r in recruits) r.toJson()],
        'declareWar': declareWar.toList(),
        'offerPeace': offerPeace.toList(),
      };
}
