/// Everything that changes during play, and nothing else. A save file is this
/// object as JSON.
library;

/// Order-free key for a pair of nations (wars, truces).
int pairKey(int a, int b) => a < b ? (a << 8) | b : (b << 8) | a;

/// Key for something [from] did towards [to] (peace offers).
int directedKey(int from, int to) => (from << 8) | to;

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
    List<int>? lastWar,
  }) : lastWar = lastWar ?? List.filled(gold.length, 0);

  factory GameState.fromJson(Map<String, dynamic> j) {
    Map<int, int> intMap(String key) => {for (final e in (j[key] as Map<String, dynamic>).entries) int.parse(e.key): e.value as int};
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
      // Saves from before this field existed count everyone as just out of a war.
      lastWar: (j['lastWar'] as List?)?.cast<int>().toList() ?? List.filled((j['gold'] as List).length, j['turn'] as int),
    )
      ..turn = j['turn'] as int
      ..ended = j['ended'] as bool
      ..winner = j['winner'] as int
      ..sandbox = j['sandbox'] as bool
      ..wars.addAll((j['wars'] as List).cast<int>())
      ..warStart.addAll(intMap('warStart'))
      ..lastGain.addAll(intMap('lastGain'))
      ..truceUntil.addAll(intMap('truceUntil'))
      ..peaceOffers.addAll(intMap('peaceOffers'));
  }

  final int seed;

  /// Nation the player controls, or -1 when every nation is run by the AI.
  final int human;

  /// Share of all provinces a nation must hold to win.
  final double winFraction;

  /// Turns fully resolved so far.
  int turn = 0;

  /// Nation holding each province.
  final List<int> owner;

  /// Units in each province. They always belong to the province's owner.
  final List<int> units;

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

  /// Last turn each nation was at war with anyone.
  final List<int> lastWar;

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
      'turn': turn,
      'owner': owner,
      'units': units,
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
      'lastWar': lastWar,
    };
  }
}
