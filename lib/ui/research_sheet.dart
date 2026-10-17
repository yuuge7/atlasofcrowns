import 'package:flutter/material.dart';

import '../engine/orders.dart';
import '../engine/rules.dart';
import '../game/game_controller.dart';
import '../theme.dart';
import 'widgets.dart';

/// What [level] in [field] does, in a few words: "+10% strength in every
/// battle".
String techEffect(Field field, int level) => switch (field) {
      Field.army => '+${(Rules.armyTechBonus * 100 * level).round()}% strength in every battle',
      Field.industry => '+${(Rules.industryTechBonus * 100 * level).round()}% income',
    };

/// Where the player's research goes and how much of the income it takes.
Future<void> showResearch(BuildContext context, GameController controller) {
  return showAtlasSheet<void>(
    context,
    (context) => ListenableBuilder(listenable: controller, builder: (context, _) => _ResearchSheet(controller)),
    heightFactor: 0.8,
  );
}

class _ResearchSheet extends StatelessWidget {
  const _ResearchSheet(this.controller);

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final spend = c.researchSpend;
    return AtlasSheet(
      title: 'Research',
      note: spend > 0 ? '$spend gold a turn goes into ${c.researchField.name} research' : 'Nothing is being spent on research',
      body: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        children: [
          for (final field in Field.values) _FieldCard(c, field),
          Padding(
            padding: const EdgeInsets.only(top: 18, bottom: 8),
            child: Text('SHARE OF INCOME', style: AtlasText.label.copyWith(color: AtlasColors.brassBright)),
          ),
          Row(children: [
            for (final share in Rules.researchShares)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: share == Rules.researchShares.last ? 0 : 8),
                  child: ChoiceTile(
                    selected: c.researchShare == share,
                    onTap: () => c.setResearch(c.researchField, share),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Text(
                      '$share%',
                      textAlign: TextAlign.center,
                      style: AtlasText.button.copyWith(color: c.researchShare == share ? AtlasColors.ivory : AtlasColors.ivoryDim),
                    ),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 8),
          Text(
            'Research is paid from what is left after upkeep, so it never leaves an army unpaid. '
            'A level costs ${Rules.techCost} turns of income for every level reached, so the share, not the size of the realm, sets the pace.',
            style: AtlasText.note,
          ),
        ],
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard(this.controller, this.field);

  final GameController controller;
  final Field field;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final level = c.game.techLevel(c.human, field);
    final focus = c.researchField == field;
    final cost = c.game.researchCost(c.human, field, income: c.income);
    final progress = c.state.research[c.human][field.index];
    final (title, scope) = switch (field) {
      Field.army => ('Army', ', attack and defence'),
      Field.industry => ('Industry', ' from all your land'),
    };
    final String next;
    if (cost < 0) {
      next = 'Fully researched.';
    } else {
      final spend = c.researchSpend;
      final turns = spend > 0 ? ((cost - progress) / spend).ceil() : -1;
      final pace = !focus ? 'Not being researched.' : (turns < 0 ? 'Set a share of income to research it.' : 'About $turns ${turns == 1 ? 'turn' : 'turns'} at this pace.');
      next = 'Level ${level + 1}: $progress of $cost gold. $pace';
    }
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: ChoiceTile(
        selected: focus,
        idle: AtlasColors.baizeDeep,
        onTap: () => c.setResearch(field, c.researchShare),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(title, style: AtlasText.place),
            const SizedBox(width: 10),
            Text('LEVEL $level', style: AtlasText.label.copyWith(color: AtlasColors.ivory)),
            const Spacer(),
            Text(focus ? 'RESEARCHING' : 'TAP TO RESEARCH', style: AtlasText.label.copyWith(color: focus ? AtlasColors.brassBright : AtlasColors.ivoryDim)),
          ]),
          const SizedBox(height: 4),
          Text('${techEffect(field, level)}$scope', style: AtlasText.body),
          const SizedBox(height: 12),
          _ScaleBar(levels: Rules.maxTech, reached: level, progress: cost > 0 ? (progress / cost).clamp(0.0, 1.0) : 0),
          const SizedBox(height: 8),
          Text(next, style: AtlasText.note),
        ]),
      ),
    );
  }
}

/// Levels drawn like the scale bar of a map: one segment per level,
/// alternately ink and ivory once reached, the next one filling in brass.
class _ScaleBar extends StatelessWidget {
  const _ScaleBar({required this.levels, required this.reached, required this.progress});

  final int levels;
  final int reached;

  /// How far into the level after [reached], 0 to 1.
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Level $reached of $levels',
      child: SizedBox(height: 22, width: double.infinity, child: CustomPaint(painter: _ScaleBarPainter(levels, reached, progress))),
    );
  }
}

class _ScaleBarPainter extends CustomPainter {
  _ScaleBarPainter(this.levels, this.reached, this.progress);

  final int levels;
  final int reached;
  final double progress;

  static const _barHeight = 9.0;

  @override
  void paint(Canvas canvas, Size size) {
    final step = size.width / levels;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AtlasColors.ivoryDim;
    for (var i = 0; i < levels; i++) {
      final cell = Rect.fromLTWH(i * step, 0, step, _barHeight);
      if (i < reached) {
        canvas.drawRect(cell, Paint()..color = i.isEven ? AtlasColors.ink : AtlasColors.ivory);
      } else if (i == reached && progress > 0) {
        canvas.drawRect(Rect.fromLTWH(cell.left, cell.top, step * progress, _barHeight), Paint()..color = AtlasColors.brass);
      }
    }
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, _barHeight), edge);
    // Ticks and figures under every other division, like a surveyor's rule.
    for (var i = 0; i <= levels; i++) {
      final x = (i * step).clamp(0.5, size.width - 0.5);
      canvas.drawLine(Offset(x, 0), Offset(x, _barHeight + (i.isEven ? 4 : 2)), edge);
      if (i.isOdd) continue;
      final figure = TextPainter(
        text: TextSpan(text: '$i', style: AtlasText.label.copyWith(fontSize: 9, letterSpacing: 0, color: i == reached ? AtlasColors.brassBright : AtlasColors.ivoryDim)),
        textDirection: TextDirection.ltr,
      )..layout();
      final left = (x - figure.width / 2).clamp(0.0, size.width - figure.width);
      figure
        ..paint(canvas, Offset(left, size.height - figure.height))
        ..dispose();
    }
  }

  @override
  bool shouldRepaint(_ScaleBarPainter old) => old.levels != levels || old.reached != reached || old.progress != progress;
}
