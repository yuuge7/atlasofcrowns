import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/world.dart';
import '../theme.dart';

/// A nation's flag, simplified the way a small atlas plate would print it.
class NationFlag extends StatelessWidget {
  const NationFlag(this.nation, {super.key, this.height = 20});

  final Nation nation;

  /// Width follows at 3:2.
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Flag of ${nation.shortName}',
      child: SizedBox(
        width: height * 1.5,
        height: height,
        child: CustomPaint(painter: _FlagPainter(nation.flag, Color(nation.color))),
      ),
    );
  }
}

class _FlagPainter extends CustomPainter {
  _FlagPainter(this.spec, this.fallback);

  final String spec;
  final Color fallback;

  @override
  void paint(Canvas canvas, Size size) {
    final box = Offset.zero & size;
    canvas.save();
    canvas.clipRect(box);
    paintFlag(canvas, box, spec, fallback);
    canvas.restore();
    canvas.drawRect(
      box.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AtlasColors.ink,
    );
  }

  @override
  bool shouldRepaint(_FlagPainter old) => old.spec != spec || old.fallback != fallback;
}

Color _hex(String hex) => Color(0xFF000000 | int.parse(hex.replaceFirst('#', ''), radix: 16));

/// Paints flag [spec] into [box]. A spec is a kind and its colours:
///
/// - `h:c1,c2,...` and `v:c1,c2,...`: equal horizontal or vertical stripes
///   (repeat a colour to make a stripe wider);
/// - `nordic:field,cross` or `nordic:field,border,cross`: a Nordic cross;
/// - `cross:field,cross`: a centred cross that runs to the edges;
/// - `swiss:field,cross`: a short centred cross;
/// - `union`: the Union Jack;
/// - `greece`: nine stripes and a cross in the canton;
/// - `crescent:field,emblem`: a crescent and star;
/// - `emblem:field,emblem` and `sun:field,emblem`: a lozenge or a disc in
///   the middle;
/// - `border:field,border`: a plain field in a border;
/// - `triangle:c1,...,cn,hoist`: horizontal stripes with a triangle at the
///   hoist;
/// - `canton:canton,stars,c1,...,cn`: horizontal stripes with a canton
///   strewn with stars, like the Stars and Stripes;
/// - `hoist:band,star,c1,...,cn`: horizontal stripes with a band at the
///   hoist bearing a star, like Texas;
/// - `pale:side,middle,emblem`: a wide middle stripe between two narrow
///   ones, with a lozenge in the middle, like Canada;
/// - `saltire:field,cross`: a diagonal cross;
/// - `quarters:c1,c2,c3,c4`: four quarters, left to right and top down;
/// - `crossq:cross,c1,c2,c3,c4`: four quarters parted by a centred cross;
/// - `bend:field,band,edge`: a diagonal band with edges, hoist top to fly
///   bottom.
///
/// Anything else is a plain field of [fallback].
void paintFlag(Canvas canvas, Rect box, String spec, Color fallback) {
  final colon = spec.indexOf(':');
  final kind = colon < 0 ? spec : spec.substring(0, colon);
  final colors = colon < 0 ? <Color>[] : [for (final c in spec.substring(colon + 1).split(',')) _hex(c.trim())];
  final paint = Paint();
  void fill(Rect r, Color c) => canvas.drawRect(r, paint..color = c);

  switch (kind) {
    case 'h' when colors.isNotEmpty:
      final band = box.height / colors.length;
      for (var i = 0; i < colors.length; i++) {
        fill(Rect.fromLTWH(box.left, box.top + band * i, box.width, band + 0.5), colors[i]);
      }
    case 'v' when colors.isNotEmpty:
      final band = box.width / colors.length;
      for (var i = 0; i < colors.length; i++) {
        fill(Rect.fromLTWH(box.left + band * i, box.top, band + 0.5, box.height), colors[i]);
      }
    case 'nordic' when colors.length >= 2:
      fill(box, colors.first);
      final x = box.left + box.width * 0.36;
      final y = box.center.dy;
      if (colors.length == 3) {
        final wide = box.height * 0.32;
        fill(Rect.fromCenter(center: Offset(x, y), width: wide, height: box.height * 2), colors[1]);
        fill(Rect.fromCenter(center: Offset(box.center.dx, y), width: box.width * 2, height: wide), colors[1]);
      }
      final arm = box.height * (colors.length == 3 ? 0.16 : 0.22);
      fill(Rect.fromCenter(center: Offset(x, y), width: arm, height: box.height * 2), colors.last);
      fill(Rect.fromCenter(center: Offset(box.center.dx, y), width: box.width * 2, height: arm), colors.last);
    case 'cross' when colors.length == 2:
      fill(box, colors[0]);
      final arm = box.height * 0.2;
      fill(Rect.fromCenter(center: box.center, width: arm, height: box.height), colors[1]);
      fill(Rect.fromCenter(center: box.center, width: box.width, height: arm), colors[1]);
    case 'swiss' when colors.length == 2:
      fill(box, colors[0]);
      final arm = box.height * 0.18;
      final reach = box.height * 0.6;
      fill(Rect.fromCenter(center: box.center, width: arm, height: reach), colors[1]);
      fill(Rect.fromCenter(center: box.center, width: reach, height: arm), colors[1]);
    case 'union':
      _unionJack(canvas, box);
    case 'greece':
      const blue = Color(0xFF0D5EAF);
      for (var i = 0; i < 9; i++) {
        fill(Rect.fromLTWH(box.left, box.top + box.height / 9 * i, box.width, box.height / 9 + 0.5), i.isEven ? blue : Colors.white);
      }
      final canton = Rect.fromLTWH(box.left, box.top, box.height * 5 / 9, box.height * 5 / 9);
      fill(canton, blue);
      fill(Rect.fromCenter(center: canton.center, width: canton.width / 5, height: canton.height), Colors.white);
      fill(Rect.fromCenter(center: canton.center, width: canton.width, height: canton.height / 5), Colors.white);
    case 'crescent' when colors.length == 2:
      fill(box, colors[0]);
      final r = box.height * 0.25;
      final c = Offset(box.left + box.width * 0.42, box.center.dy);
      final moon = Path.combine(
        PathOperation.difference,
        Path()..addOval(Rect.fromCircle(center: c, radius: r)),
        Path()..addOval(Rect.fromCircle(center: c + Offset(r * 0.32, 0), radius: r * 0.8)),
      );
      canvas.drawPath(moon, paint..color = colors[1]);
      canvas.drawPath(_star(c + Offset(r * 1.05, 0), r * 0.42), paint..color = colors[1]);
    case 'emblem' when colors.length == 2:
      fill(box, colors[0]);
      final c = box.center;
      final w = box.height * 0.32;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - w)
          ..lineTo(c.dx + w * 0.8, c.dy)
          ..lineTo(c.dx, c.dy + w)
          ..lineTo(c.dx - w * 0.8, c.dy)
          ..close(),
        paint..color = colors[1],
      );
    case 'sun' when colors.length == 2:
      fill(box, colors[0]);
      canvas.drawCircle(box.center, box.height * 0.26, paint..color = colors[1]);
    case 'border' when colors.length == 2:
      fill(box, colors[1]);
      fill(box.deflate(box.height * 0.1), colors[0]);
    case 'triangle' when colors.length >= 2:
      final stripes = colors.sublist(0, colors.length - 1);
      final band = box.height / stripes.length;
      for (var i = 0; i < stripes.length; i++) {
        fill(Rect.fromLTWH(box.left, box.top + band * i, box.width, band + 0.5), stripes[i]);
      }
      canvas.drawPath(
        Path()
          ..moveTo(box.left, box.top)
          ..lineTo(box.left + box.width * 0.42, box.center.dy)
          ..lineTo(box.left, box.bottom)
          ..close(),
        paint..color = colors.last,
      );
    case 'canton' when colors.length >= 3:
      final stripes = colors.sublist(2);
      final band = box.height / stripes.length;
      for (var i = 0; i < stripes.length; i++) {
        fill(Rect.fromLTWH(box.left, box.top + band * i, box.width, band + 0.5), stripes[i]);
      }
      // Down to the middle stripe of a striped flag, over the top two of a
      // barred one.
      final depth = stripes.length > 4 ? band * ((stripes.length + 1) ~/ 2) : band * math.min(2, stripes.length);
      final canton = Rect.fromLTWH(box.left, box.top, box.width * 0.4, depth);
      fill(canton, colors[0]);
      final star = Paint()..color = colors[1];
      for (var row = 0; row < 3; row++) {
        for (var col = 0; col < 4; col++) {
          final c = Offset(canton.left + canton.width * (col + 0.5 + (row.isOdd ? 0.25 : 0) - 0.125) / 4, canton.top + canton.height * (row + 0.5) / 3);
          canvas.drawCircle(c, canton.height * 0.07, star);
        }
      }
    case 'hoist' when colors.length >= 3:
      final stripes = colors.sublist(2);
      final band = box.height / stripes.length;
      for (var i = 0; i < stripes.length; i++) {
        fill(Rect.fromLTWH(box.left, box.top + band * i, box.width, band + 0.5), stripes[i]);
      }
      final hoist = Rect.fromLTWH(box.left, box.top, box.width / 3, box.height);
      fill(hoist, colors[0]);
      canvas.drawPath(_star(hoist.center, hoist.width * 0.32), paint..color = colors[1]);
    case 'pale' when colors.length == 3:
      fill(box, colors[1]);
      fill(Rect.fromLTWH(box.left, box.top, box.width / 4, box.height), colors[0]);
      fill(Rect.fromLTWH(box.right - box.width / 4, box.top, box.width / 4, box.height), colors[0]);
      final c = box.center;
      final w = box.height * 0.28;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - w)
          ..lineTo(c.dx + w * 0.8, c.dy)
          ..lineTo(c.dx, c.dy + w)
          ..lineTo(c.dx - w * 0.8, c.dy)
          ..close(),
        paint..color = colors[2],
      );
    case 'saltire' when colors.length == 2:
      fill(box, colors[0]);
      final arm = Paint()
        ..strokeWidth = box.height * 0.2
        ..color = colors[1];
      canvas.drawLine(box.topLeft, box.bottomRight, arm);
      canvas.drawLine(box.bottomLeft, box.topRight, arm);
    case 'quarters' when colors.length == 4:
      final w = box.width / 2;
      final h = box.height / 2;
      for (var i = 0; i < 4; i++) {
        fill(Rect.fromLTWH(box.left + w * (i % 2), box.top + h * (i ~/ 2), w + 0.5, h + 0.5), colors[i]);
      }
    case 'crossq' when colors.length == 5:
      final w = box.width / 2;
      final h = box.height / 2;
      for (var i = 0; i < 4; i++) {
        fill(Rect.fromLTWH(box.left + w * (i % 2), box.top + h * (i ~/ 2), w + 0.5, h + 0.5), colors[i + 1]);
      }
      final arm = box.height * 0.18;
      fill(Rect.fromCenter(center: box.center, width: arm, height: box.height), colors[0]);
      fill(Rect.fromCenter(center: box.center, width: box.width, height: arm), colors[0]);
    case 'bend' when colors.length == 3:
      fill(box, colors[0]);
      canvas.drawLine(
          box.topLeft,
          box.bottomRight,
          Paint()
            ..strokeWidth = box.height * 0.42
            ..color = colors[2]);
      canvas.drawLine(
          box.topLeft,
          box.bottomRight,
          Paint()
            ..strokeWidth = box.height * 0.3
            ..color = colors[1]);
    default:
      fill(box, colors.isEmpty ? fallback : colors.first);
  }
}

/// A five-pointed star of outer radius [r] around [c].
Path _star(Offset c, double r) {
  final path = Path();
  for (var i = 0; i < 10; i++) {
    final radius = i.isEven ? r : r * 0.42;
    final angle = -math.pi / 2 + i * math.pi / 5;
    final point = c + Offset(math.cos(angle), math.sin(angle)) * radius;
    if (i == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  return path..close();
}

/// The Union Jack, drawn plainly: blue field, white and red saltires, white
/// and red cross.
void _unionJack(Canvas canvas, Rect box) {
  const blue = Color(0xFF012169);
  const red = Color(0xFFC8102E);
  canvas.drawRect(box, Paint()..color = blue);
  final diagonal = Paint()
    ..strokeWidth = box.height * 0.2
    ..color = Colors.white;
  canvas.drawLine(box.topLeft, box.bottomRight, diagonal);
  canvas.drawLine(box.bottomLeft, box.topRight, diagonal);
  diagonal
    ..strokeWidth = box.height * 0.07
    ..color = red;
  canvas.drawLine(box.topLeft, box.bottomRight, diagonal);
  canvas.drawLine(box.bottomLeft, box.topRight, diagonal);
  final paint = Paint()..color = Colors.white;
  canvas.drawRect(Rect.fromCenter(center: box.center, width: box.height * 0.34, height: box.height), paint);
  canvas.drawRect(Rect.fromCenter(center: box.center, width: box.width, height: box.height * 0.34), paint);
  paint.color = red;
  canvas.drawRect(Rect.fromCenter(center: box.center, width: box.height * 0.2, height: box.height), paint);
  canvas.drawRect(Rect.fromCenter(center: box.center, width: box.width, height: box.height * 0.2), paint);
}
