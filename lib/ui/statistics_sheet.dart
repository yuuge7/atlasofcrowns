import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../theme.dart';
import 'flags.dart';
import 'widgets.dart';

/// What the chart follows: the order matches the numbers a nation has in
/// each chronicle sample.
enum _Measure {
  provinces('Provinces'),
  army('Army'),
  income('Income');

  const _Measure(this.label);

  final String label;
}

/// How the powers have stood over the game, one measure at a time.
Future<void> showStatistics(BuildContext context, GameController controller) {
  return showAtlasSheet<void>(context, (context) => _StatisticsSheet(controller), heightFactor: 0.88);
}

class _StatisticsSheet extends StatefulWidget {
  const _StatisticsSheet(this.controller);

  final GameController controller;

  @override
  State<_StatisticsSheet> createState() => _StatisticsSheetState();
}

class _StatisticsSheetState extends State<_StatisticsSheet> {
  _Measure _measure = _Measure.provinces;

  /// Sample the player is reading, or null for the latest.
  int? _cursor;

  /// At most this many nations are drawn: the leaders, and the player.
  static const _shown = 7;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final s = c.state;
    final samples = s.chronicle;
    final from = c.world.dateLabel(s.chronicleFrom);
    if (samples.isEmpty) {
      return const AtlasSheet(title: 'Statistics', body: Padding(padding: EdgeInsets.all(20), child: Text('Nothing recorded yet.', style: AtlasText.note)));
    }
    final last = samples.length - 1;
    final at = (_cursor ?? last).clamp(0, last);
    int value(int nation, int sample) => samples[sample][nation * 3 + _measure.index];
    int turnOf(int sample) => s.chronicleFrom + sample * s.chronicleEvery;

    // The leaders now, and the player wherever they stand.
    final ranked = [for (var n = 0; n < c.world.nations.length; n++) n]..sort((a, b) => value(b, last) != value(a, last) ? value(b, last) - value(a, last) : a - b);
    final series = ranked.take(_shown).toList();
    if (c.human >= 0 && !series.contains(c.human)) series[_shown - 1] = c.human;
    final byValueAt = List.of(series)..sort((a, b) => value(b, at) != value(a, at) ? value(b, at) - value(a, at) : a - b);

    void point(double dx, double width) {
      final x = ((dx - _ChartPainter.left) / (width - _ChartPainter.left - _ChartPainter.right)).clamp(0.0, 1.0);
      setState(() => _cursor = (x * last).round());
    }

    return AtlasSheet(
      title: 'Statistics',
      note: 'The powers since $from',
      body: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        children: [
          Row(children: [
            for (final measure in _Measure.values) ...[
              if (measure != _Measure.values.first) const SizedBox(width: 8),
              Expanded(
                child: ChoiceTile(
                  selected: measure == _measure,
                  onTap: () => setState(() => _measure = measure),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Text(
                    measure.label.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: AtlasText.button.copyWith(color: measure == _measure ? AtlasColors.ivory : AtlasColors.ivoryDim),
                  ),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, box) => GestureDetector(
              onTapDown: (d) => point(d.localPosition.dx, box.maxWidth),
              onHorizontalDragUpdate: (d) => point(d.localPosition.dx, box.maxWidth),
              child: Semantics(
                label: '${_measure.label} of the leading powers from $from to ${c.world.dateLabel(s.turn)}. The values are listed below.',
                child: SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _ChartPainter(
                      series: [
                        for (final n in series)
                          _Series(
                            [for (var i = 0; i <= last; i++) value(n, i)],
                            Color(c.world.nations[n].color),
                            c.world.nations[n].shortName,
                            mine: n == c.human,
                            label: n == c.human || n == ranked.first,
                          ),
                      ],
                      cursor: at,
                      firstDate: from,
                      lastDate: c.world.dateLabel(turnOf(last)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: Text(
              _cursor == null ? '${c.world.dateLabel(turnOf(at))}. Touch the chart to read another month.' : c.world.dateLabel(turnOf(at)),
              style: AtlasText.note,
            ),
          ),
          for (final n in byValueAt)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Container(width: 14, height: 3, color: Color(c.world.nations[n].color)),
                const SizedBox(width: 8),
                NationFlag(c.world.nations[n], height: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    c.world.nations[n].shortName,
                    style: AtlasText.body.copyWith(color: n == c.human ? AtlasColors.brassBright : AtlasColors.ivory),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text('${value(n, at)}', style: AtlasText.figure.copyWith(fontSize: 17)),
              ]),
            ),
        ],
      ),
    );
  }
}

class _Series {
  _Series(this.values, this.color, this.name, {required this.mine, required this.label});

  final List<int> values;
  final Color color;
  final String name;

  /// The player's: drawn heavier and on top.
  final bool mine;

  /// Named at the end of its line.
  final bool label;
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({required this.series, required this.cursor, required this.firstDate, required this.lastDate});

  final List<_Series> series;
  final int cursor;
  final String firstDate;
  final String lastDate;

  /// Room for the value axis, the end labels and the dates.
  static const left = 34.0;
  static const right = 58.0;
  static const bottom = 20.0;

  static const _axis = TextStyle(fontFamily: AtlasFonts.data, fontSize: 11, color: AtlasColors.ivoryDim);

  @override
  void paint(Canvas canvas, Size size) {
    final count = series.first.values.length;
    var top = 1;
    for (final line in series) {
      top = math.max(top, line.values.reduce(math.max));
    }
    // Gridlines at a round step, three or four of them.
    final rawStep = top / 3;
    final magnitude = math.pow(10, (math.log(rawStep) / math.ln10).floor()).toDouble();
    final step = [1, 2, 5, 10].map((m) => m * magnitude).firstWhere((v) => v >= rawStep);
    final ceiling = (top / step).ceil() * step;
    final plot = Rect.fromLTRB(left, 6, size.width - right, size.height - bottom);
    Offset at(int sample, int value) => Offset(
          plot.left + (count == 1 ? plot.width : plot.width * sample / (count - 1)),
          plot.bottom - plot.height * value / ceiling,
        );

    final grid = Paint()
      ..color = AtlasColors.baizeLight
      ..strokeWidth = 1;
    for (var v = 0.0; v <= ceiling + 0.5; v += step) {
      final y = plot.bottom - plot.height * v / ceiling;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      _text(canvas, v.round().toString(), _axis, Offset(plot.left - 6, y), alignRight: true);
    }
    _text(canvas, firstDate, _axis, Offset(plot.left, size.height - 8), alignLeft: true);
    _text(canvas, lastDate, _axis, Offset(plot.right, size.height - 8), alignRight: true);

    // Lines on a halo of baize, so that crossing lines stay apart; the
    // player's last, on top.
    final halo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = AtlasColors.baize;
    final ordered = [...series.where((l) => !l.mine), ...series.where((l) => l.mine)];
    for (final line in ordered) {
      final path = Path();
      for (var i = 0; i < count; i++) {
        final p = at(i, line.values[i]);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(path, halo..strokeWidth = line.mine ? 6 : 5);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = line.mine ? 3 : 2
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..color = line.color,
      );
    }

    // The leader and the player named at the end of their lines, kept apart.
    final labels = [
      for (final line in series)
        if (line.label) (line, at(count - 1, line.values.last).dy),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    var lastY = -100.0;
    for (final (line, y) in labels) {
      final placed = math.max(y, lastY + 13);
      _text(canvas, line.name, _axis.copyWith(color: line.mine ? AtlasColors.brassBright : AtlasColors.ivory), Offset(plot.right + 6, placed), alignLeft: true);
      lastY = placed;
    }

    // The month being read.
    final x = at(cursor, 0).dx;
    canvas.drawLine(
        Offset(x, plot.top),
        Offset(x, plot.bottom),
        Paint()
          ..color = AtlasColors.brassBright
          ..strokeWidth = 1);
    for (final line in series) {
      final p = at(cursor, line.values[cursor]);
      canvas.drawCircle(p, 4.5, Paint()..color = AtlasColors.baize);
      canvas.drawCircle(p, 3, Paint()..color = line.color);
    }
  }

  void _text(Canvas canvas, String text, TextStyle style, Offset anchor, {bool alignRight = false, bool alignLeft = false}) {
    final painter = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();
    final dx = alignRight ? anchor.dx - painter.width : (alignLeft ? anchor.dx : anchor.dx - painter.width / 2);
    painter
      ..paint(canvas, Offset(dx, anchor.dy - painter.height / 2))
      ..dispose();
  }

  @override
  bool shouldRepaint(_ChartPainter old) => true;
}
