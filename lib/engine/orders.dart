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

/// What can be built in a province.
enum Project {
  /// One more level of fort.
  fortify,

  /// One more level of development: +1 income.
  develop,
}

/// What a peace offer asks of the enemy.
enum Terms {
  /// Each keeps what it holds.
  white,

  /// The enemy pays reparations.
  reparations,

  /// The enemy becomes a vassal.
  vassal,

  /// Agrees to whatever the enemy's own offer asks.
  accept,
}

/// What can be researched.
enum Field {
  /// Every unit fights harder.
  army,

  /// Every province yields more.
  industry,
}

/// Where research goes from this turn on, and how much of the income.
class ResearchPlan {
  const ResearchPlan(this.field, this.share);

  final Field field;

  /// Percent of income, one of [Rules.researchShares].
  final int share;

  List<int> toJson() => [field.index, share];

  static ResearchPlan fromJson(List<dynamic> j) => ResearchPlan(Field.values[j[0] as int], j[1] as int);
}

class BuildOrder {
  const BuildOrder(this.province, this.project);

  final int province;
  final Project project;

  List<int> toJson() => [province, project.index];

  static BuildOrder fromJson(List<dynamic> j) => BuildOrder(j[0] as int, Project.values[j[1] as int]);
}

class Orders {
  Orders();

  factory Orders.fromJson(Map<String, dynamic> j) {
    return Orders()
      ..moves.addAll([for (final m in j['moves'] as List) MoveOrder.fromJson(m as List)])
      ..recruits.addAll([for (final r in j['recruits'] as List) RecruitOrder.fromJson(r as List)])
      ..builds.addAll([for (final b in j['builds'] as List? ?? const []) BuildOrder.fromJson(b as List)])
      ..declareWar.addAll((j['declareWar'] as List).cast<int>())
      ..offerPeace.addAll((j['offerPeace'] as List).cast<int>())
      ..offerAlliance.addAll((j['offerAlliance'] as List? ?? const []).cast<int>())
      ..breakAlliance.addAll((j['breakAlliance'] as List? ?? const []).cast<int>())
      ..peaceTerms.addAll({for (final e in (j['peaceTerms'] as Map<String, dynamic>? ?? const {}).entries) int.parse(e.key): Terms.values[e.value as int]})
      ..declareIndependence = j['independence'] as bool? ?? false
      ..offerPact.addAll((j['offerPact'] as List? ?? const []).cast<int>())
      ..envoys.addAll((j['envoys'] as List? ?? const []).cast<int>())
      ..gifts.addAll({for (final e in (j['gifts'] as Map<String, dynamic>? ?? const {}).entries) int.parse(e.key): e.value as int})
      ..answer = j['answer'] as int?
      ..research = j['research'] == null ? null : ResearchPlan.fromJson(j['research'] as List);
  }

  final List<MoveOrder> moves = [];
  final List<RecruitOrder> recruits = [];

  /// At most one per province counts.
  final List<BuildOrder> builds = [];

  /// Nations to declare war on. Takes effect at the end of this turn; armies
  /// may cross the border from the next one.
  final Set<int> declareWar = {};

  /// Nations to offer peace to, or whose standing offer is accepted.
  final Set<int> offerPeace = {};

  /// What each of those offers asks; white peace when not listed.
  final Map<int, Terms> peaceTerms = {};

  /// Throw off the overlord this turn, at the price of a war with it.
  bool declareIndependence = false;

  /// Nations to offer an alliance to, or whose standing offer is accepted.
  final Set<int> offerAlliance = {};

  /// Allies to part ways with.
  final Set<int> breakAlliance = {};

  /// Nations to offer a non-aggression pact to, or whose offer is accepted.
  final Set<int> offerPact = {};

  /// Nations to send an envoy to, each at [Game.envoyCost].
  final Set<int> envoys = {};

  /// Gold to give each nation listed.
  final Map<int, int> gifts = {};

  /// The answer, by index, to the happening waiting for this nation; null
  /// lets it take its course.
  int? answer;

  /// A new research plan, or null to keep the current one.
  ResearchPlan? research;

  bool get isEmpty =>
      moves.isEmpty &&
      recruits.isEmpty &&
      builds.isEmpty &&
      declareWar.isEmpty &&
      offerPeace.isEmpty &&
      offerAlliance.isEmpty &&
      breakAlliance.isEmpty &&
      offerPact.isEmpty &&
      envoys.isEmpty &&
      gifts.isEmpty &&
      answer == null &&
      research == null &&
      !declareIndependence;

  Map<String, dynamic> toJson() => {
        'moves': [for (final m in moves) m.toJson()],
        'recruits': [for (final r in recruits) r.toJson()],
        'builds': [for (final b in builds) b.toJson()],
        'declareWar': declareWar.toList(),
        'offerPeace': offerPeace.toList(),
        'peaceTerms': {for (final e in peaceTerms.entries) '${e.key}': e.value.index},
        'independence': declareIndependence,
        'offerAlliance': offerAlliance.toList(),
        'breakAlliance': breakAlliance.toList(),
        'offerPact': offerPact.toList(),
        'envoys': envoys.toList(),
        'gifts': {for (final e in gifts.entries) '${e.key}': e.value},
        'answer': answer,
        'research': research?.toJson(),
      };
}
