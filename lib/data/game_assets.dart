import 'dart:convert';

import 'package:flutter/services.dart';

import '../engine/world.dart';
import '../map/map_geometry.dart';

/// The map and scenario files, decoded once at startup.
class GameAssets {
  GameAssets(this.world, this.geometry);

  final World world;
  final MapGeometry geometry;

  static Future<GameAssets> load() async {
    final map = jsonDecode(await rootBundle.loadString('assets/map/europe.json')) as Map<String, dynamic>;
    final scenario = jsonDecode(await rootBundle.loadString('assets/scenarios/1914.json')) as Map<String, dynamic>;
    return GameAssets(World.fromJson(map, scenario), MapGeometry.fromJson(map));
  }
}
