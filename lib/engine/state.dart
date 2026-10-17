/// Everything that changes during play, and nothing else. A save file is this
/// object as JSON.
library;

import 'rules.dart';

/// Order-free key for a pair of nations (wars, truces).
int pairKey(int a, int b) => a < b ? (a << 8) | b : (b << 8) | a;

/// Key for something [from] did towards [to] (peace and alliance offers).
int directedKey(int from, int to) => (from << 8) | to;

/// The two nations in a [pairKey] (lower id first) or a [directedKey]
/// (from, to).
(int, int) pairOf(int key) => (key >> 8, key & 0xFF);

class GameState {
  GameState({
    required this.seed,
    required this.human,
    required this.winFraction,
    required this.owner,
    required this.units,
    required this.gold,
    required this.alive,
    required this.capital,
    required this.rngState,
    this.difficulty = Rules.normalDifficulty,
    this.fog = false,
    this.randomEvents = false,
    List<int>? lastWar,
    List<int>? forts,
    List<int>? development,
    List<int>? heldSince,
    List<List<int>>? tech,
    List<List<int>>? research,
    List<int>? researchFocus,
    List<int>? researchShare,
    List<int>? overlord,
    List<List<int>>? chronicle,
    this.chronicleEvery = 1,
    this.chronicleFrom = 0,
  })  : lastWar = lastWar ?? List.filled(gold.length, 0),
        chronicle = chronicle ?? [],
        overlord = overlord ?? List.filled(gold.length, -1),
        tech = tech ?? List.generate(gold.length, (_) => [0, 0]),
        research = research ?? List.generate(gold.length, (_) => [0, 0]),
        researchFocus = researchFocus ?? List.filled(gold.length, 0),
        researchShare = researchShare ?? List.filled(gold.length, 0),
        forts = forts ?? List.filled(owner.length, 0),
        development = development ?? List.filled(owner.length, 0),
        heldSince = heldSince ?? List.filled(owner.length, 0);

  factory GameState.fromJson(Map<String, dynamic> j) {
    // Fields added after the first release may be missing from older saves:
    // these read them as null or empty.
    Map<int, int> intMap(String key) => {for (final e in (j[key] as Map<String, dynamic>? ?? const {}).entries) int.parse(e.key): e.value as int};
    List<int>? intList(String key) => (j[key] as List?)?.cast<int>().toList();
    List<List<int>>? intGrid(String key) => (j[key] as List?)?.map((row) => (row as List).cast<int>().toList()).toList();
    return GameState(
      seed: j['seed'] as int,
      human: j['human'] as int,
      winFraction: (j['winFraction'] as num).toDouble(),
      owner: (j['owner'] as List).cast<int>().toList(),
      units: (j['units'] as List).cast<int>().toList(),
      gold: (j['gold'] as List).cast<int>().toList(),
      alive: (j['alive'] as List).cast<bool>().toList(),
      capital: (j['capital'] as List).cast<int>().toList(),
      rngState: j['rngState'] as int,
      difficulty: j['difficulty'] as int? ?? Rules.normalDifficulty,
      fog: j['fog'] as bool? ?? false,
      randomEvents: j['randomEvents'] as bool? ?? true,
      // Saves from before this field existed count everyone as just out of a war.
      lastWar: intList('lastWar') ?? List.filled((j['gold'] as List).length, j['turn'] as int),
      // Saves from before buildings have none, and count every province as
      // held since the start; from before technology, none of it.
      forts: intList('forts'),
      development: intList('development'),
      heldSince: intList('heldSince'),
      tech: intGrid('tech'),
      research: intGrid('research'),
      researchFocus: intList('researchFocus'),
      researchShare: intList('researchShare'),
      overlord: intList('overlord'),
      chronicle: intGrid('chronicle'),
      chronicleEvery: j['chronicleEvery'] as int? ?? 1,
      chronicleFrom: j['chronicleFrom'] as int? ?? 0,
    )
      ..turn = j['turn'] as int
      ..ended = j['ended'] as bool
      ..winner = j['winner'] as int
      ..sandbox = j['sandbox'] as bool
      ..wars.addAll((j['wars'] as List).cast<int>())
      ..warStart.addAll(intMap('warStart'))
      ..lastGain.addAll(intMap('lastGain'))
      ..truceUntil.addAll(intMap('truceUntil'))
      ..peaceOffers.addAll(intMap('peaceOffers'))
      // Saves from before alliances have none.
      ..alliances.addAll(intList('alliances') ?? const [])
      ..allianceOffers.addAll(intMap('allianceOffers'))
      ..allianceAsked.addAll(intMap('allianceAsked'))
      ..peaceTerms.addAll(intMap('peaceTerms'))
      ..gains.addAll(intMap('gains'))
      ..tribute.addAll(intMap('tribute'))
      ..relations.addAll(intMap('relations'))
      ..pacts.addAll(intMap('pacts'))
      ..pactOffers.addAll(intMap('pactOffers'))
      ..pactAsked.addAll(intMap('pactAsked'))
      ..pending.addAll(intMap('pending'));
  }

  /// How [a] and [b] feel about each other.
  int relation(int a, int b) => relations[pairKey(a, b)] ?? 0;

  /// Moves the relations of [a] and [b] by [by], within the limits.
  void changeRelation(int a, int b, int by) => setRelation(a, b, relation(a, b) + by);

  void setRelation(int a, int b, int value) {
    final key = pairKey(a, b);
    final clamped = value.clamp(-Rules.maxRelation, Rules.maxRelation);
    if (clamped == 0) {
      relations.remove(key);
    } else {
      relations[key] = clamped;
    }
  }

  /// Puts [a] and [b] at war from [turn] on, and drops the offers between
  /// them that the war makes moot.
  void openWar(int a, int b, int turn) {
    final key = pairKey(a, b);
    wars.add(key);
    warStart[key] = turn;
    lastGain[key] = turn;
    pacts.remove(key);
    setRelation(a, b, relation(a, b) < Rules.declaredRelation ? relation(a, b) : Rules.declaredRelation);
    for (final offer in [directedKey(a, b), directedKey(b, a)]) {
      peaceOffers.remove(offer);
      peaceTerms.remove(offer);
      allianceOffers.remove(offer);
      pactOffers.remove(offer);
      gains.remove(offer);
    }
  }

  /// Ends the war between [a] and [b] on [turn]: a truce follows.
  void closeWar(int a, int b, int turn, int truceTurns) {
    final key = pairKey(a, b);
    wars.remove(key);
    warStart.remove(key);
    lastGain.remove(key);
    truceUntil[key] = turn + 1 + truceTurns;
    for (final offer in [directedKey(a, b), directedKey(b, a)]) {
      peaceOffers.remove(offer);
      peaceTerms.remove(offer);
      gains.remove(offer);
    }
  }

  /// Drops every war, truce, alliance and offer [n] is part of, once it has
  /// fallen. Every pair-keyed collection above belongs in here.
  void forgetNation(int n) {
    bool involves(int key) {
      final (a, b) = pairOf(key);
      return a == n || b == n;
    }

    wars.removeWhere(involves);
    alliances.removeWhere(involves);
    for (final map in [warStart, lastGain, truceUntil, peaceOffers, peaceTerms, allianceOffers, allianceAsked, gains, tribute, relations, pacts, pactOffers, pactAsked]) {
      map.removeWhere((key, _) => involves(key));
    }
    pending.remove(n);
    // A fallen overlord sets its vassals free.
    overlord[n] = -1;
    for (var v = 0; v < overlord.length; v++) {
      if (overlord[v] == n) overlord[v] = -1;
    }
  }

  final int seed;

  /// Nation the player controls, or -1 when every nation is run by the AI.
  final int human;

  /// Share of all provinces a nation must hold to win.
  final double winFraction;

  /// Index into [Rules.aiIncome].
  final int difficulty;

  /// Whether the player sees armies only near their own and allied land.
  final bool fog;

  /// Whether harvests, strikes, fires and the like happen by chance.
  final bool randomEvents;

  /// Turns fully resolved so far.
  int turn = 0;

  /// Nation holding each province.
  final List<int> owner;

  /// Units in each province. They always belong to the province's owner.
  final List<int> units;

  /// Fort level of each province, 0 to [Rules.maxFort].
  final List<int> forts;

  /// Income each province has gained by development.
  final List<int> development;

  /// Turn on which each province passed to its current owner.
  final List<int> heldSince;

  final List<int> gold;
  final List<bool> alive;

  /// Capital province of each nation, -1 once it is gone.
  final List<int> capital;

  /// [pairKey]s of nations at war.
  final Set<int> wars = {};

  /// [pairKey] -> turn the war began.
  final Map<int, int> warStart = {};

  /// [pairKey] -> last turn a province changed hands in that war.
  final Map<int, int> lastGain = {};

  /// [pairKey] -> first turn on which the two may declare war again.
  final Map<int, int> truceUntil = {};

  /// [directedKey] -> turn on which the offer lapses.
  final Map<int, int> peaceOffers = {};

  /// [directedKey] -> [Terms] index of that peace offer, when not white.
  final Map<int, int> peaceTerms = {};

  /// [directedKey] (a, b) -> provinces a has taken from b in their war.
  final Map<int, int> gains = {};

  /// [directedKey] (payer, payee) -> turn the reparations end.
  final Map<int, int> tribute = {};

  /// The overlord of each nation, or -1 for a free one.
  final List<int> overlord;

  /// [pairKey] -> how the two feel about each other, see [relation]. Pairs
  /// at 0 are left out.
  final Map<int, int> relations = {};

  /// [pairKey] -> first turn after the non-aggression pact between the two.
  final Map<int, int> pacts = {};

  /// [directedKey] -> turn on which the pact offer lapses.
  final Map<int, int> pactOffers = {};

  /// [directedKey] -> turn of the last pact offer, kept for a while after it
  /// lapsed so the AI does not keep asking.
  final Map<int, int> pactAsked = {};

  /// Nation -> the happening waiting for its answer, as
  /// `happening index * 1000 + province`.
  final Map<int, int> pending = {};

  /// How the powers stood every [chronicleEvery] turns, from the start: one
  /// sample per row, holding each nation's provinces, units and income in
  /// turn (three numbers a nation).
  final List<List<int>> chronicle;

  /// Turns between two samples of the [chronicle].
  int chronicleEvery;

  /// Turn of the first sample: 0, or later for a game saved before there
  /// was a chronicle.
  int chronicleFrom;

  /// [pairKey]s of allied nations. An ally joins any war declared on the
  /// other.
  final Set<int> alliances = {};

  /// [directedKey] -> turn on which the alliance offer lapses.
  final Map<int, int> allianceOffers = {};

  /// [directedKey] -> turn of the last alliance offer, kept for a while
  /// after it lapsed so the AI does not keep asking.
  final Map<int, int> allianceAsked = {};

  /// Last turn each nation was at war with anyone.
  final List<int> lastWar;

  /// Level of each nation in each research field, by field index.
  final List<List<int>> tech;

  /// Gold put towards the next level, by nation and field index.
  final List<List<int>> research;

  /// Field index each nation is researching.
  final List<int> researchFocus;

  /// Percent of income each nation puts into research.
  final List<int> researchShare;

  int rngState;

  bool ended = false;

  /// Winner once [ended], or -1 when the player was wiped out first.
  int winner = -1;

  /// Play on after the game is decided; no further victory checks.
  bool sandbox = false;

  Map<String, dynamic> toJson() {
    Map<String, int> strMap(Map<int, int> m) => {for (final e in m.entries) '${e.key}': e.value};
    return {
      'seed': seed,
      'human': human,
      'winFraction': winFraction,
      'difficulty': difficulty,
      'fog': fog,
      'randomEvents': randomEvents,
      'turn': turn,
      'owner': owner,
      'units': units,
      'forts': forts,
      'development': development,
      'heldSince': heldSince,
      'gold': gold,
      'alive': alive,
      'capital': capital,
      'rngState': rngState,
      'ended': ended,
      'winner': winner,
      'sandbox': sandbox,
      'wars': wars.toList()..sort(),
      'warStart': strMap(warStart),
      'lastGain': strMap(lastGain),
      'truceUntil': strMap(truceUntil),
      'peaceOffers': strMap(peaceOffers),
      'alliances': alliances.toList()..sort(),
      'allianceOffers': strMap(allianceOffers),
      'allianceAsked': strMap(allianceAsked),
      'peaceTerms': strMap(peaceTerms),
      'gains': strMap(gains),
      'tribute': strMap(tribute),
      'relations': strMap(relations),
      'pacts': strMap(pacts),
      'pactOffers': strMap(pactOffers),
      'pactAsked': strMap(pactAsked),
      'pending': strMap(pending),
      'overlord': overlord,
      'chronicle': chronicle,
      'chronicleEvery': chronicleEvery,
      'chronicleFrom': chronicleFrom,
      'lastWar': lastWar,
      'tech': tech,
      'research': research,
      'researchFocus': researchFocus,
      'researchShare': researchShare,
    };
  }
}
