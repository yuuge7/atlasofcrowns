/// Static data of one scenario on one map. Nothing in here changes during play.
library;

class Province {
  Province({
    required this.id,
    required this.name,
    required this.modern,
    required this.area,
    required this.adj,
    required this.sea,
    required this.income,
    this.coast = const [],
  }) : links = List.unmodifiable([...adj, ...sea]);

  final int id;
  final String name;

  /// Modern country this land belongs to (ISO alpha-3 of the merge group).
  final String modern;
  final int area;

  /// Land neighbors.
  final List<int> adj;

  /// Neighbors across a strait.
  final List<int> sea;

  /// Everywhere an army can go overland, or across a strait, in one turn.
  final List<int> links;

  final int income;

  /// Ids of the sea zones its coast touches; empty inland.
  final List<int> coast;
}

/// A stretch of sea armies can be shipped across.
class SeaZone {
  const SeaZone(this.name, this.adj);

  final String name;

  /// Ids of the zones next to it.
  final List<int> adj;
}

class Nation {
  const Nation({
    required this.id,
    required this.tag,
    required this.name,
    required this.shortName,
    required this.color,
    required this.capital,
    this.readiness = 1,
    this.tech = const [0, 0],
    this.flag = '',
  });

  final int id;
  final String tag;
  final String name;
  final String shortName;

  /// 0xAARRGGBB.
  final int color;

  /// Starting capital. The live one is in the game state.
  final int capital;

  /// Scales the army the nation starts with: how far it had mobilised when
  /// the scenario opens.
  final double readiness;

  /// Starting level in each research field, by field index.
  final List<int> tech;

  /// How the flag is drawn, e.g. `h:#000000,#FFFFFF,#DD0000` for three
  /// stripes (the UI reads it).
  final String flag;
}

/// Something that happened in history on a given turn, replayed when the
/// game still looks enough like history for it to make sense.
class HistoryEvent {
  const HistoryEvent({required this.turn, required this.text, this.alliances = const [], this.wars = const []});

  factory HistoryEvent.fromJson(Map<String, dynamic> j) {
    List<(int, int)> pairs(String key) => [for (final p in j[key] as List? ?? const []) ((p as List)[0] as int, p[1] as int)];
    return HistoryEvent(turn: j['turn'] as int, text: j['text'] as String, alliances: pairs('alliances'), wars: pairs('wars'));
  }

  final int turn;

  /// What the dispatches say when it happens.
  final String text;

  /// Alliances signed, before any of the [wars] are declared.
  final List<(int, int)> alliances;

  /// Wars declared, (attacker, attacked).
  final List<(int, int)> wars;
}

class World {
  World({
    required this.mapBuild,
    required this.scenarioId,
    required this.scenarioName,
    required this.startYear,
    required this.startMonth,
    required this.provinces,
    required this.nations,
    required this.startOwners,
    required this.startWars,
    this.startAlliances = const [],
    this.aggression = 1,
    this.history = const [],
    this.seas = const [],
    List<int>? startForts,
  }) : startForts = startForts ?? List.filled(provinces.length, 0);

  /// Builds the world from the decoded `assets/map/*.json` and
  /// `assets/scenarios/*.json`. Only the fields the rules need are read; the
  /// geometry stays with the renderer.
  factory World.fromJson(Map<String, dynamic> map, Map<String, dynamic> scenario) {
    if (scenario['mapBuild'] != map['build']) {
      throw FormatException('Scenario ${scenario['id']} was built for map ${scenario['mapBuild']}, not ${map['build']}');
    }
    final income = (scenario['income'] as List).cast<int>();
    // A scenario may name the provinces for its own time.
    final names = (scenario['names'] as List?)?.cast<String>();
    final coast = (map['coast'] as List?)?.map((c) => (c as List).cast<int>()).toList();
    final provinces = [
      for (final p in (map['provinces'] as List).cast<Map<String, dynamic>>())
        Province(
          id: p['id'] as int,
          name: names?[p['id'] as int] ?? p['name'] as String,
          modern: p['modern'] as String,
          area: p['area'] as int,
          adj: List.unmodifiable((p['adj'] as List).cast<int>()),
          sea: List.unmodifiable((p['sea'] as List).cast<int>()),
          income: income[p['id'] as int],
          coast: coast?[p['id'] as int] ?? const [],
        ),
    ];
    final rawNations = (scenario['nations'] as List).cast<Map<String, dynamic>>();
    final nations = [
      for (var i = 0; i < rawNations.length; i++)
        Nation(
          id: i,
          tag: rawNations[i]['tag'] as String,
          name: rawNations[i]['name'] as String,
          shortName: rawNations[i]['short'] as String,
          color: 0xFF000000 | int.parse((rawNations[i]['color'] as String).substring(1), radix: 16),
          capital: rawNations[i]['capital'] as int,
          readiness: (rawNations[i]['readiness'] as num? ?? 1).toDouble(),
          tech: (rawNations[i]['tech'] as List?)?.cast<int>() ?? const [0, 0],
          flag: rawNations[i]['flag'] as String? ?? '',
        ),
    ];
    return World(
      mapBuild: map['build'] as String,
      scenarioId: scenario['id'] as String,
      scenarioName: scenario['name'] as String,
      startYear: scenario['startYear'] as int,
      startMonth: scenario['startMonth'] as int,
      aggression: (scenario['aggression'] as num? ?? 1).toDouble(),
      history: [for (final e in scenario['history'] as List? ?? const []) HistoryEvent.fromJson(e as Map<String, dynamic>)],
      seas: [
        for (final z in (map['seas'] as List? ?? const []).cast<Map<String, dynamic>>()) SeaZone(z['name'] as String, (z['adj'] as List).cast<int>()),
      ],
      provinces: provinces,
      nations: nations,
      startOwners: (scenario['owners'] as List).cast<int>(),
      startWars: [for (final w in scenario['wars'] as List) (w as List).cast<int>()],
      startAlliances: [for (final a in scenario['alliances'] as List? ?? const []) (a as List).cast<int>()],
      startForts: (scenario['forts'] as List?)?.cast<int>(),
    );
  }

  final String mapBuild;
  final String scenarioId;
  final String scenarioName;
  final int startYear;
  final int startMonth;

  /// Scales how readily the AI starts a war: 1 for an age of empires, less
  /// for a time when wars are rare.
  final double aggression;

  /// Scripted events, by turn.
  final List<HistoryEvent> history;

  final List<SeaZone> seas;

  /// For every province, the coastal provinces an army can sail to from
  /// it: those on the same sea zone or a neighbouring one, less the ones it
  /// can reach overland anyway.
  late final List<Set<int>> landings = () {
    final onZone = List.generate(seas.length, (_) => <int>[]);
    for (final p in provinces) {
      for (final z in p.coast) {
        onZone[z].add(p.id);
      }
    }
    return [
      for (final p in provinces)
        {
          for (final z in {...p.coast, for (final z in p.coast) ...seas[z].adj})
            for (final q in onZone[z])
              if (q != p.id && !p.links.contains(q)) q,
        },
    ];
  }();

  /// Whether an army in [from] can reach [to] in one turn, overland, across
  /// a strait or by sea.
  bool reaches(int from, int to) => provinces[from].links.contains(to) || landings[from].contains(to);
  final List<Province> provinces;
  final List<Nation> nations;
  final List<int> startOwners;
  final List<List<int>> startWars;
  final List<List<int>> startAlliances;

  /// Fort level of each province when the scenario opens.
  final List<int> startForts;

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  /// One turn is one month.
  String dateLabel(int turn) {
    final months = startMonth - 1 + turn;
    return '${_months[months % 12]} ${startYear + months ~/ 12}';
  }
}
