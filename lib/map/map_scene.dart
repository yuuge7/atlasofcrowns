import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../engine/world.dart';
import '../theme.dart';
import 'map_geometry.dart';

/// A nation's name set across its land, the way an atlas plate letters a country.
class NationLettering {
  NationLettering(this.nation, this.center, this.fontSize, this.painter);

  final int nation;
  final Offset center;

  /// In map units.
  final double fontSize;
  final TextPainter painter;
}

/// Everything about the map that only changes when a province changes hands:
/// the coloured land, the borders between nations and the lettering.
///
/// Rebuilt by [setOwners]; panning, zooming and selecting never touch it.
class MapScene extends ChangeNotifier {
  MapScene(this.geometry, this.world);

  final MapGeometry geometry;
  final World world;

  List<int> _owners = const [];
  List<Color>? _fills;

  /// Land fills, recorded once per ownership change.
  ui.Picture? land;
  Path innerBorders = Path();
  Path nationBorders = Path();
  List<NationLettering> lettering = const [];

  /// Size of the sea names, in map units.
  static const double seaFont = 17;

  /// The sea names, laid out once: where each goes and its text.
  late final List<(Offset, TextPainter)> seaLettering = [
    for (final (name, at) in geometry.seaNames)
      (
        at,
        TextPainter(
          text: TextSpan(
            text: name.toUpperCase(),
            style: const TextStyle(
              fontFamily: AtlasFonts.display,
              fontStyle: FontStyle.italic,
              fontSize: seaFont,
              letterSpacing: seaFont * 0.3,
              color: AtlasColors.coast,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
      ),
  ];

  List<int> get owners => _owners;

  Color colorOf(int nation) => Color(world.nations[nation].color);

  /// The colour province [p] is filled with.
  Color fillOf(int p) => _fills?[p] ?? colorOf(_owners[p]);

  /// Nation names are lettered only over the nations' own colours.
  bool get lettered => _fills == null;

  /// Colours the land by owner, or by [fills] (one colour per province)
  /// for the other map modes. Borders always follow the owners.
  void setOwners(List<int> owners, {List<Color>? fills}) {
    final ownersChanged = !listEquals(owners, _owners);
    if (!ownersChanged && listEquals(fills, _fills)) return;
    _owners = List.of(owners);
    _fills = fills == null ? null : List.of(fills);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    // An ink underlay, so the hairline seams between neighbouring fills show
    // as border and not as sea.
    final ink = Paint()
      ..color = AtlasColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    final fill = Paint();
    for (final p in geometry.provinces) {
      canvas.drawPath(p.path, ink);
    }
    for (final p in geometry.provinces) {
      canvas.drawPath(p.path, fill..color = fillOf(p.id));
    }
    land?.dispose();
    land = recorder.endRecording();

    // A new map mode only recolours the land.
    if (ownersChanged) {
      innerBorders = geometry.bordersWhere((arc) => _owners[arc.a] == _owners[arc.b]);
      nationBorders = geometry.bordersWhere((arc) => _owners[arc.a] != _owners[arc.b]);
      lettering = _letter();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    land?.dispose();
    super.dispose();
  }

  /// One label per nation, over its largest contiguous stretch of land.
  List<NationLettering> _letter() {
    final result = <NationLettering>[];
    final seen = List.filled(_owners.length, false);
    final best = <int, List<int>>{};
    final bestWeight = <int, double>{};
    for (var start = 0; start < _owners.length; start++) {
      if (seen[start]) continue;
      final nation = _owners[start];
      final block = <int>[];
      final stack = [start];
      seen[start] = true;
      var weight = 0.0;
      while (stack.isNotEmpty) {
        final p = stack.removeLast();
        block.add(p);
        weight += geometry.provinces[p].radius * geometry.provinces[p].radius;
        for (final q in world.provinces[p].adj) {
          if (!seen[q] && _owners[q] == nation) {
            seen[q] = true;
            stack.add(q);
          }
        }
      }
      if (weight > (bestWeight[nation] ?? 0)) {
        bestWeight[nation] = weight;
        best[nation] = block;
      }
    }
    for (final entry in best.entries) {
      var cx = 0.0, cy = 0.0, total = 0.0;
      var box = Rect.fromCircle(center: geometry.provinces[entry.value.first].label, radius: 1);
      for (final p in entry.value) {
        final shape = geometry.provinces[p];
        final weight = shape.radius * shape.radius;
        cx += shape.label.dx * weight;
        cy += shape.label.dy * weight;
        total += weight;
        box = box.expandToInclude(Rect.fromCircle(center: shape.label, radius: shape.radius));
      }
      final text = world.nations[entry.key].shortName.toUpperCase();
      // Sized so the spaced word spans most of the block.
      final fontSize = math.min(box.width * 0.95 / (text.length * 0.95), box.height * 0.42).clamp(5.0, 80.0);
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: AtlasFonts.display,
            fontSize: fontSize,
            letterSpacing: fontSize * 0.28,
            color: inkOn(colorOf(entry.key)),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      result.add(NationLettering(entry.key, Offset(cx / total, cy / total), fontSize, painter));
    }
    return result;
  }
}
