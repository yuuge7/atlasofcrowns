import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'map_camera.dart';
import 'map_scene.dart';

/// An order drawn on the map in staff pencil: blue for a march through your
/// own land, red for an attack.
class MapArrow {
  const MapArrow(this.from, this.to, this.count, {required this.hostile});

  final int from;
  final int to;
  final int count;
  final bool hostile;
}

/// The changing things drawn over the land: selection, orders, armies.
class MapOverlay extends ChangeNotifier {
  int selected = -1;

  /// Provinces offered as destinations while picking where to move.
  Set<int> targets = const {};
  List<MapArrow> arrows = const [];

  /// The road still ahead of each march, after this turn's step: provinces
  /// from the step's end to the destination.
  List<List<int>> marches = const [];

  /// Units per province, or null to hide the counters (menus). A negative
  /// count is an army the player cannot see.
  List<int>? units;

  /// Units ordered but not yet raised, shown as "+n".
  Map<int, int> recruits = const {};
  Set<int> capitals = const {};

  /// Fort level of each province, or empty for none anywhere.
  List<int> forts = const [];

  /// Provinces that just changed hands, and how far their flash has faded (1 to 0).
  Set<int> flashing = const {};
  double flash = 0;

  void changed() => notifyListeners();
}

/// Sea, land, borders and lettering. All of it comes ready-made from the
/// [MapScene]; this only places it under the camera.
class MapBasePainter extends CustomPainter {
  MapBasePainter(this.scene, this.camera) : super(repaint: Listenable.merge([scene, camera]));

  final MapScene scene;
  final MapCamera camera;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = camera.scale;
    canvas.drawRect(Offset.zero & size, Paint()..color = AtlasColors.sea);
    canvas.save();
    canvas.translate(camera.offset.dx, camera.offset.dy);
    canvas.scale(scale);

    final line = Paint()..style = PaintingStyle.stroke;
    canvas.drawPath(
        scene.geometry.graticule,
        line
          ..color = AtlasColors.seaLine
          ..strokeWidth = 1 / scale);
    // Straits armies can cross: a dotted line from shore to shore.
    final dot = Paint()..color = AtlasColors.baizeDeep;
    final gap = 4.5 / scale;
    for (final (from, to) in scene.geometry.crossings) {
      final steps = math.max(2, ((to - from).distance / gap).round());
      for (var i = 0; i <= steps; i++) {
        canvas.drawCircle(Offset.lerp(from, to, i / steps)!, 1.1 / scale, dot);
      }
    }
    final land = scene.land;
    if (land != null) canvas.drawPicture(land);
    // Province borders thin out as the map is pulled back.
    final innerAlpha = ((scale - 0.3) / 1.2).clamp(0.12, 0.42);
    canvas.drawPath(
        scene.innerBorders,
        line
          ..color = AtlasColors.ink.withValues(alpha: innerAlpha)
          ..strokeWidth = 0.8 / scale);
    canvas.drawPath(
        scene.geometry.coast,
        line
          ..color = AtlasColors.coast
          ..strokeWidth = 1.1 / scale);
    canvas.drawPath(
        scene.nationBorders,
        line
          ..color = AtlasColors.ink
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 1.9 / scale);

    // Nation names show while they are a readable size, then make way for
    // the provinces as the player closes in.
    final visible = camera.visibleMap;
    for (final label in scene.lettered ? scene.lettering : const <NationLettering>[]) {
      final onScreen = label.fontSize * scale;
      final alpha = math.min(((onScreen - 8) / 4).clamp(0.0, 1.0), ((70 - onScreen) / 18).clamp(0.0, 1.0)) * 0.5;
      if (alpha <= 0) continue;
      final topLeft = label.center - Offset(label.painter.width / 2, label.painter.height / 2);
      final box = topLeft & label.painter.size;
      if (!box.overlaps(visible)) continue;
      canvas.saveLayer(box, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
      label.painter.paint(canvas, topLeft);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(MapBasePainter oldDelegate) => oldDelegate.scene != scene || oldDelegate.camera != camera;
}

/// Selection, order arrows, army counters and province names, at a constant
/// size on screen whatever the zoom.
class MapOverlayPainter extends CustomPainter {
  MapOverlayPainter(this.scene, this.camera, this.overlay) : super(repaint: Listenable.merge([scene, camera, overlay]));

  final MapScene scene;
  final MapCamera camera;
  final MapOverlay overlay;

  /// Laid-out text is reused between frames; the set of strings is small.
  static final Map<String, TextPainter> _text = {};

  static TextPainter _layout(String text, TextStyle style, String key) {
    if (_text.length > 1500) _text.clear();
    return _text.putIfAbsent('$key|$text', () => TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout());
  }

  static const _counterStyle = TextStyle(fontFamily: AtlasFonts.data, fontWeight: FontWeight.w600, fontSize: 13, height: 1);
  static const _nameStyle = TextStyle(fontFamily: AtlasFonts.display, fontStyle: FontStyle.italic, fontSize: 12, height: 1);

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = scene.geometry;
    final scale = camera.scale;
    final visible = camera.visibleMap;

    // ---- shapes that follow the land
    canvas.save();
    canvas.translate(camera.offset.dx, camera.offset.dy);
    canvas.scale(scale);
    if (overlay.flash > 0) {
      final paint = Paint()..color = AtlasColors.ivory.withValues(alpha: 0.75 * overlay.flash);
      for (final p in overlay.flashing) {
        canvas.drawPath(geometry.provinces[p].path, paint);
      }
    }
    if (overlay.targets.isNotEmpty) {
      final wash = Paint()..color = AtlasColors.ivory.withValues(alpha: 0.3);
      final edge = Paint()
        ..style = PaintingStyle.stroke
        ..color = AtlasColors.ivory
        ..strokeWidth = 2 / scale;
      for (final p in overlay.targets) {
        canvas.drawPath(geometry.provinces[p].path, wash);
        canvas.drawPath(geometry.provinces[p].path, edge);
      }
    }
    if (overlay.selected >= 0) {
      final path = geometry.provinces[overlay.selected].path;
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(
          path,
          stroke
            ..color = AtlasColors.ink
            ..strokeWidth = 5.5 / scale);
      canvas.drawPath(
          path,
          stroke
            ..color = AtlasColors.brassBright
            ..strokeWidth = 3 / scale);
    }
    canvas.restore();

    // ---- orders
    for (final road in overlay.marches) {
      _drawRoad(canvas, [for (final p in road) camera.toScreen(geometry.provinces[p].label)], Offset.zero & size);
    }
    for (final arrow in overlay.arrows) {
      _drawArrow(canvas, camera.toScreen(geometry.provinces[arrow.from].label), camera.toScreen(geometry.provinces[arrow.to].label), arrow);
    }

    // ---- armies and names
    final units = overlay.units;
    final owners = scene.owners;
    for (final p in geometry.provinces) {
      final onScreen = p.radius * scale;
      final picked = p.id == overlay.selected || overlay.targets.contains(p.id);
      if (onScreen < 9 && !picked) continue;
      if (!visible.inflate(p.radius).contains(p.label)) continue;
      final at = camera.toScreen(p.label);
      var nameTop = at.dy - 6;
      if (units != null) {
        final fort = overlay.forts.isEmpty ? 0 : overlay.forts[p.id];
        _drawCounter(canvas, at, units[p.id], scene.colorOf(owners[p.id]), overlay.recruits[p.id] ?? 0, overlay.capitals.contains(p.id), fort);
        nameTop = at.dy + 11;
      }
      if (onScreen >= 30 || picked) {
        final ink = inkOn(scene.fillOf(p.id));
        final name = _layout(scene.world.provinces[p.id].name, _nameStyle.copyWith(color: ink.withValues(alpha: 0.85)), ink == AtlasColors.ink ? 'n0' : 'n1');
        if (name.width < onScreen * 3.2 || picked) name.paint(canvas, Offset(at.dx - name.width / 2, nameTop));
      }
    }
  }

  void _drawCounter(Canvas canvas, Offset at, int count, Color color, int recruits, bool capital, int fort) {
    final ink = inkOn(color);
    final number = _layout(count < 0 ? '?' : '$count', _counterStyle.copyWith(color: ink), ink == AtlasColors.ink ? 'c0' : 'c1');
    final width = math.max(number.width + 9, 20.0);
    final plate = RRect.fromRectAndRadius(Rect.fromCenter(center: at, width: width, height: 17), const Radius.circular(3));
    canvas.drawRRect(plate.shift(const Offset(0, 1.2)), Paint()..color = const Color(0x55000000));
    canvas.drawRRect(plate, Paint()..color = color);
    canvas.drawRRect(
        plate,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = AtlasColors.ink);
    number.paint(canvas, Offset(at.dx - number.width / 2, at.dy - number.height / 2));
    if (capital) _drawCrown(canvas, Offset(at.dx, plate.top - 1.5));
    if (fort > 0) _drawFort(canvas, Offset(plate.left - 1, plate.bottom + 1), fort);
    if (recruits > 0) {
      final plus = _layout('+$recruits', _counterStyle.copyWith(color: AtlasColors.ink, fontSize: 11), 'r');
      final tag = RRect.fromRectAndRadius(Rect.fromLTWH(plate.right - 3, plate.top - 8, plus.width + 6, 13), const Radius.circular(3));
      canvas.drawRRect(tag, Paint()..color = AtlasColors.brassBright);
      plus.paint(canvas, Offset(tag.left + 3, tag.top + 1));
    }
  }

  /// A crenellated tower standing on the origin's line, its right foot at
  /// [right].
  static Path _tower(double right, double width, double height) {
    final left = right - width;
    final merlon = width / 5;
    return Path()
      ..moveTo(left, 0)
      ..lineTo(left, -height)
      ..lineTo(left + merlon, -height)
      ..lineTo(left + merlon, 2.2 - height)
      ..lineTo(left + merlon * 2, 2.2 - height)
      ..lineTo(left + merlon * 2, -height)
      ..lineTo(left + merlon * 3, -height)
      ..lineTo(left + merlon * 3, 2.2 - height)
      ..lineTo(left + merlon * 4, 2.2 - height)
      ..lineTo(left + merlon * 4, -height)
      ..lineTo(right, -height)
      ..lineTo(right, 0)
      ..close();
  }

  /// The towers of a fort and of a fortress, back to front, right foot at
  /// the origin.
  static final List<List<Path>> _forts = [
    [_tower(0, 9, 10)],
    [_tower(-6, 8, 13), _tower(0, 9, 10)],
  ];
  static final Paint _towerFill = Paint()..color = AtlasColors.ivory;
  static final Paint _towerEdge = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..strokeJoin = StrokeJoin.miter
    ..color = AtlasColors.ink;

  /// A crenellated tower at the lower left of the counter, its right foot
  /// at [foot]; a fortress gets a second, taller one.
  void _drawFort(Canvas canvas, Offset foot, int level) {
    canvas.save();
    canvas.translate(foot.dx, foot.dy);
    for (final tower in _forts[math.min(level, _forts.length) - 1]) {
      canvas.drawPath(tower, _towerFill);
      canvas.drawPath(tower, _towerEdge);
    }
    canvas.restore();
  }

  /// A three-pointed crown sitting on the counter of a capital.
  void _drawCrown(Canvas canvas, Offset base) {
    final crown = Path()
      ..moveTo(base.dx - 6, base.dy)
      ..lineTo(base.dx - 6.5, base.dy - 6)
      ..lineTo(base.dx - 3, base.dy - 3)
      ..lineTo(base.dx, base.dy - 7.5)
      ..lineTo(base.dx + 3, base.dy - 3)
      ..lineTo(base.dx + 6.5, base.dy - 6)
      ..lineTo(base.dx + 6, base.dy)
      ..close();
    canvas.drawPath(crown, Paint()..color = AtlasColors.brassBright);
    canvas.drawPath(
        crown,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..strokeJoin = StrokeJoin.round
          ..color = AtlasColors.ink);
  }

  static final Paint _roadPencil = Paint()
    ..style = PaintingStyle.stroke
    ..color = AtlasColors.staffBlue
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round;
  static final Paint _ringUnder = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5
    ..color = AtlasColors.ivory;
  static final Paint _ringOver = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..color = AtlasColors.staffBlue;

  /// A march's road ahead: blue pencil dashes from province to province and
  /// a ring at the destination. Stretches off [screen] are left out.
  void _drawRoad(Canvas canvas, List<Offset> points, Rect screen) {
    if (points.length < 2) return;
    final dashes = Path();
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      final length = (b - a).distance;
      if (length < 1 || !Rect.fromPoints(a, b).inflate(2).overlaps(screen)) continue;
      final unit = (b - a) / length;
      for (var d = 0.0; d < length; d += 11) {
        final from = a + unit * d;
        final to = a + unit * math.min(d + 6, length);
        dashes
          ..moveTo(from.dx, from.dy)
          ..lineTo(to.dx, to.dy);
      }
    }
    canvas.drawPath(dashes, _roadPencil);
    canvas.drawCircle(points.last, 9, _ringUnder);
    canvas.drawCircle(points.last, 9, _ringOver);
  }

  void _drawArrow(Canvas canvas, Offset from, Offset to, MapArrow arrow) {
    final delta = to - from;
    final length = delta.distance;
    if (length < 12) return;
    final unit = delta / length;
    final normal = Offset(-unit.dy, unit.dx);
    // Start and stop short of the two counters, and bow a little so that
    // opposite orders between the same provinces do not overlap.
    final start = from + unit * math.min(14, length * 0.2);
    final end = to - unit * math.min(16, length * 0.25);
    final bend = (start + end) / 2 + normal * length * 0.14;
    final shaft = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(bend.dx, bend.dy, end.dx, end.dy);
    final color = arrow.hostile ? AtlasColors.signal : AtlasColors.staffBlue;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
        shaft,
        stroke
          ..color = AtlasColors.ivory
          ..strokeWidth = 6.5);
    canvas.drawPath(
        shaft,
        stroke
          ..color = color
          ..strokeWidth = 4);
    final heading = (end - bend) / (end - bend).distance;
    final side = Offset(-heading.dy, heading.dx);
    final head = Path()
      ..moveTo(end.dx + heading.dx * 9, end.dy + heading.dy * 9)
      ..lineTo(end.dx + side.dx * 7 - heading.dx * 2, end.dy + side.dy * 7 - heading.dy * 2)
      ..lineTo(end.dx - side.dx * 7 - heading.dx * 2, end.dy - side.dy * 7 - heading.dy * 2)
      ..close();
    canvas.drawPath(
        head,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 2.5
          ..color = AtlasColors.ivory);
    canvas.drawPath(head, Paint()..color = color);

    final middle = (start + end) / 2 * 0.5 + bend * 0.5;
    final count = _layout('${arrow.count}', _counterStyle.copyWith(color: AtlasColors.ivory, fontSize: 12), 'a');
    final disc = RRect.fromRectAndRadius(Rect.fromCenter(center: middle, width: math.max(count.width + 8, 18), height: 16), const Radius.circular(8));
    canvas.drawRRect(disc, Paint()..color = color);
    canvas.drawRRect(
        disc,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = AtlasColors.ivory);
    count.paint(canvas, Offset(middle.dx - count.width / 2, middle.dy - count.height / 2));
  }

  @override
  bool shouldRepaint(MapOverlayPainter oldDelegate) => oldDelegate.scene != scene || oldDelegate.camera != camera || oldDelegate.overlay != overlay;
}
