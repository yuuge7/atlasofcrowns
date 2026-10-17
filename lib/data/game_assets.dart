import 'dart:convert';

import 'package:flutter/services.dart';

import '../engine/world.dart';
import '../map/map_geometry.dart';

/// The maps and scenario files, decoded once at startup.
class GameAssets {
  GameAssets(this.scenarios, this.maps) : assert(scenarios.isNotEmpty);

  /// Every scenario, the first one the default.
  final List<World> scenarios;

  /// The geometry of every map a scenario is played on, by map name.
  final Map<String, MapGeometry> maps;

  /// The default scenario, shown behind the title screen.
  World get world => scenarios.first;

  /// The map of the default scenario.
  MapGeometry get geometry => geometryOf(world);

  /// The map [world] is played on.
  MapGeometry geometryOf(World world) => maps[world.mapName]!;

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

  static const _index = 'assets/scenarios/index.json';
  static String _scenarioPath(String id) => 'assets/scenarios/$id.json';
  static String _mapPath(String name) => 'assets/map/$name.json';
  static String _mapOf(Map<String, dynamic> scenario) => scenario['map'] as String? ?? 'europe';

  /// Builds the assets from the decoded JSON files, by path: the scenarios
  /// listed in `assets/scenarios/index.json`, and the maps they name.
  factory GameAssets.read(Object? Function(String path) json) {
    final scenarios = [for (final id in (json(_index) as List).cast<String>()) json(_scenarioPath(id)) as Map<String, dynamic>];
    final maps = {for (final s in scenarios) _mapOf(s): json(_mapPath(_mapOf(s))) as Map<String, dynamic>};
    return GameAssets(
      [for (final s in scenarios) World.fromJson(maps[_mapOf(s)]!, s)],
      {for (final e in maps.entries) e.key: MapGeometry.fromJson(e.value)},
    );
  }

  static Future<GameAssets> load() async {
    Future<Object?> decode(String path) async => jsonDecode(await rootBundle.loadString(path));
    final files = <String, Object?>{_index: await decode(_index)};
    for (final id in (files[_index] as List).cast<String>()) {
      final scenario = await decode(_scenarioPath(id)) as Map<String, dynamic>;
      files[_scenarioPath(id)] = scenario;
      files[_mapPath(_mapOf(scenario))] ??= await decode(_mapPath(_mapOf(scenario)));
    }
    return GameAssets.read((path) => files[path]);
  }
}
