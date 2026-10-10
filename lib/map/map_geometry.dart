import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

class ProvinceShape {
  ProvinceShape({required this.id, required this.path, required this.bounds, required this.label, required this.radius});

  final int id;
  final Path path;
  final Rect bounds;

  /// The point furthest from every edge: where the counter and the name go.
  final Offset label;

  /// Distance from [label] to the nearest edge, in map units.
  final double radius;
}

/// A stretch of border between exactly two provinces.
class BorderArc {
  BorderArc(this.a, this.b, this.points);

  final int a;
  final int b;

  /// x0, y0, x1, y1, ...
  final Float32List points;
}

/// Province outlines decoded from `assets/map/*.json`, in map units.
///
/// The file stores every border once, as an arc shared by the provinces on
/// both sides, so the same data gives filled shapes, the coastline and the
/// borders between any two owners.
class MapGeometry {
  MapGeometry._(this.size, this.provinces, this.borders, this.coast, this.graticule, this.crossings);

  factory MapGeometry.fromJson(Map<String, dynamic> json) {
    final scale = (json['scale'] as num).toDouble();
    final size = Size((json['width'] as num).toDouble(), (json['height'] as num).toDouble());
    final arcs = [
      for (final arc in json['arcs'] as List)
        Float32List.fromList([for (final v in arc as List) (v as num) / scale]),
    ];

    final users = List<List<int>>.generate(arcs.length, (_) => []);
    final provinces = <ProvinceShape>[];
    final arcsOf = <int, List<int>>{};
    final crossings = <(Offset, Offset)>[];
    for (final p in (json['provinces'] as List).cast<Map<String, dynamic>>()) {
      final id = p['id'] as int;
      final path = Path()..fillType = PathFillType.evenOdd;
      for (final ring in p['rings'] as List) {
        var started = false;
        for (final ref in (ring as List).cast<int>()) {
          final reversed = ref < 0;
          final index = reversed ? ~ref : ref;
          final points = arcs[index];
          if (!users[index].contains(id)) users[index].add(id);
          arcsOf.putIfAbsent(id, () => []).add(index);
          final count = points.length ~/ 2;
          for (var i = 0; i < count; i++) {
            final k = (reversed ? count - 1 - i : i) * 2;
            if (!started) {
              path.moveTo(points[k], points[k + 1]);
              started = true;
            } else if (i > 0) {
              // Point 0 repeats the end of the previous arc.
              path.lineTo(points[k], points[k + 1]);
            }
          }
        }
        path.close();
      }
      final label = (p['label'] as List).cast<num>();
      provinces.add(ProvinceShape(
        id: id,
        path: path,
        bounds: path.getBounds(),
        label: Offset(label[0] / scale, label[1] / scale),
        radius: (p['radius'] as num) / scale,
      ));
    }

    final borders = <BorderArc>[];
    final coast = Path();
    for (var i = 0; i < arcs.length; i++) {
      final points = arcs[i];
      if (users[i].length == 2) {
        borders.add(BorderArc(users[i][0], users[i][1], points));
      } else if (users[i].length == 1) {
        // Shoreline, except where the map window itself cuts the land off.
        var penDown = false;
        for (var k = 0; k + 3 < points.length; k += 2) {
          if (_onSameEdge(points[k], points[k + 1], points[k + 2], points[k + 3], size)) {
            penDown = false;
            continue;
          }
          if (!penDown) coast.moveTo(points[k], points[k + 1]);
          coast.lineTo(points[k + 2], points[k + 3]);
          penDown = true;
        }
      }
    }

    // A strait is drawn where the two shores come closest.
    for (final p in (json['provinces'] as List).cast<Map<String, dynamic>>()) {
      final a = p['id'] as int;
      for (final b in (p['sea'] as List).cast<int>()) {
        if (b < a) continue;
        var best = double.infinity;
        var from = Offset.zero;
        var to = Offset.zero;
        for (final i in arcsOf[a]!) {
          final pa = arcs[i];
          for (final j in arcsOf[b]!) {
            final pb = arcs[j];
            for (var m = 0; m < pa.length; m += 2) {
              for (var n = 0; n < pb.length; n += 2) {
                final dx = pa[m] - pb[n];
                final dy = pa[m + 1] - pb[n + 1];
                final d = dx * dx + dy * dy;
                if (d < best) {
                  best = d;
                  from = Offset(pa[m], pa[m + 1]);
                  to = Offset(pb[n], pb[n + 1]);
                }
              }
            }
          }
        }
        crossings.add((from, to));
      }
    }

    return MapGeometry._(size, provinces, borders, coast, _graticule(json['bbox'] as List?, size), crossings);
  }

  final Size size;
  final List<ProvinceShape> provinces;
  final List<BorderArc> borders;
  final Path coast;

  /// Meridians and parallels every five degrees.
  final Path graticule;

  /// Shore-to-shore ends of every sea link.
  final List<(Offset, Offset)> crossings;

  /// Province under [point] (map units), or -1 for open sea.
  int provinceAt(Offset point) {
    for (final p in provinces) {
      if (p.bounds.contains(point) && p.path.contains(point)) return p.id;
    }
    return -1;
  }

  /// One path with every border arc for which [include] holds.
  Path bordersWhere(bool Function(BorderArc arc) include) {
    final path = Path();
    for (final arc in borders) {
      if (!include(arc)) continue;
      final points = arc.points;
      path.moveTo(points[0], points[1]);
      for (var k = 2; k < points.length; k += 2) {
        path.lineTo(points[k], points[k + 1]);
      }
    }
    return path;
  }

  static bool _onSameEdge(double x0, double y0, double x1, double y1, Size size) {
    const eps = 0.3;
    bool both(double a, double b, double edge) => (a - edge).abs() < eps && (b - edge).abs() < eps;
    return both(x0, x1, 0) || both(x0, x1, size.width) || both(y0, y1, 0) || both(y0, y1, size.height);
  }

  static Path _graticule(List<dynamic>? bbox, Size size) {
    final path = Path();
    if (bbox == null) return path;
    final w = (bbox[0] as num).toDouble();
    final s = (bbox[1] as num).toDouble();
    final e = (bbox[2] as num).toDouble();
    final n = (bbox[3] as num).toDouble();
    double mercator(double lat) => math.log(math.tan(math.pi / 4 + lat * math.pi / 360));
    final top = mercator(n);
    final unitsPerRadian = size.width / ((e - w) * math.pi / 180);
    for (var lon = (w / 5).ceil() * 5; lon < e; lon += 5) {
      final x = (lon - w) / (e - w) * size.width;
      path
        ..moveTo(x, 0)
        ..lineTo(x, size.height);
    }
    for (var lat = (s / 5).ceil() * 5; lat < n; lat += 5) {
      final y = (top - mercator(lat.toDouble())) * unitsPerRadian;
      path
        ..moveTo(0, y)
        ..lineTo(size.width, y);
    }
    return path;
  }
}
