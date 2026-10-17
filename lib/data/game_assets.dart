import 'dart:convert';

import 'package:flutter/services.dart';

import '../engine/world.dart';
import '../map/map_geometry.dart';

/// The map and scenario files, decoded once at startup.
class GameAssets {
  GameAssets(this.scenarios, this.geometry) : assert(scenarios.isNotEmpty);

  /// Every scenario on the map, the first one the default.
  final List<World> scenarios;
  final MapGeometry geometry;

  /// The default scenario, shown behind the title screen.
  World get world => scenarios.first;

  /// The scenario a save was made in. Throws [FormatException] for one this
  /// version of the game does not have.
  World scenario(String id) => scenarioOrNull(id) ?? (throw FormatException('No scenario "$id" in this version'));

  World? scenarioOrNull(String id) => scenarios.where((w) => w.scenarioId == id).firstOrNull;

  /// Nation [nation] of scenario [scenario], or null for a player who was
  /// only watching or a scenario this version does not have.
  Nation? nationOf(String scenario, int nation) {
    final world = scenarioOrNull(scenario);
    return world == null || nation < 0 || nation >= world.nations.length ? null : world.nations[nation];
  }

  static const _map = 'assets/map/europe.json';
  static const _index = 'assets/scenarios/index.json';

  /// Builds the assets from the decoded JSON files, by path: the map, the
  /// list of scenarios in `assets/scenarios/index.json`, and each of those.
  factory GameAssets.read(Object? Function(String path) json) {
    final map = json(_map) as Map<String, dynamic>;
    return GameAssets([
      for (final id in (json(_index) as List).cast<String>()) World.fromJson(map, json('assets/scenarios/$id.json') as Map<String, dynamic>),
    ], MapGeometry.fromJson(map));
  }

  static Future<GameAssets> load() async {
    Future<Object?> decode(String path) async => jsonDecode(await rootBundle.loadString(path));
    final files = <String, Object?>{_map: await decode(_map), _index: await decode(_index)};
    for (final id in (files[_index] as List).cast<String>()) {
      files['assets/scenarios/$id.json'] = await decode('assets/scenarios/$id.json');
    }
    return GameAssets.read((path) => files[path]);
  }
}
