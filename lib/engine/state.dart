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
    List<int>? lastWar,
    List<int>? forts,
    List<int>? development,
    List<int>? heldSince,
    List<List<int>>? tech,
    List<List<int>>? research,
    List<int>? researchFocus,
    List<int>? researchShare,
  })  : lastWar = lastWar ?? List.filled(gold.length, 0),
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
      ..allianceAsked.addAll(intMap('allianceAsked'));
  }

  /// Puts [a] and [b] at war from [turn] on, and drops the offers between
  /// them that the war makes moot.
  void openWar(int a, int b, int turn) {
    final key = pairKey(a, b);
    wars.add(key);
    warStart[key] = turn;
    lastGain[key] = turn;
    for (final offer in [directedKey(a, b), directedKey(b, a)]) {
      peaceOffers.remove(offer);
      allianceOffers.remove(offer);
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
    for (final map in [warStart, lastGain, truceUntil, peaceOffers, allianceOffers, allianceAsked]) {
      map.removeWhere((key, _) => involves(key));
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
      'lastWar': lastWar,
      'tech': tech,
      'research': research,
      'researchFocus': researchFocus,
      'researchShare': researchShare,
    };
  }
}
