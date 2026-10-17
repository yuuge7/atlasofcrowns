import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// A value under a small spaced-capitals label.
class Stat extends StatelessWidget {
  const Stat(this.label, this.value, {super.key, this.detail, this.detailColor});

  final String label;
  final String value;

  /// Smaller text right after the value, e.g. "+41".
  final String? detail;
  final Color? detailColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(), style: AtlasText.label),
        const SizedBox(height: 2),
        Text.rich(
          TextSpan(text: value, children: [
            if (detail != null) TextSpan(text: '  $detail', style: AtlasText.figure.copyWith(fontSize: 14, color: detailColor ?? AtlasColors.ivoryDim)),
          ]),
          style: AtlasText.figure,
          maxLines: 1,
        ),
      ],
    );
  }
}

/// The colour a nation has on the map, as a small enamel plate.
class NationSwatch extends StatelessWidget {
  const NationSwatch(this.color, {super.key, this.width = 10, this.height = 34});

  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2), border: Border.all(color: AtlasColors.ink)),
    );
  }
}

/// A HUD surface: baize with a brass rule along one edge.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.ruleOnTop = false, this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 12)});

  final Widget child;
  final bool ruleOnTop;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    const rule = BorderSide(color: AtlasColors.brass, width: 1.5);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AtlasColors.baize,
        border: Border(top: ruleOnTop ? rule : BorderSide.none, bottom: ruleOnTop ? BorderSide.none : rule),
        boxShadow: const [BoxShadow(color: AtlasColors.shadow, blurRadius: 10)],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Picks a number of units between 1 and [max].
class AmountPicker extends StatefulWidget {
  const AmountPicker({super.key, required this.max, required this.confirmLabel, required this.onConfirm, required this.onCancel, this.initial, this.verdict});

  final int max;
  final int? initial;

  /// A line about the amount picked, e.g. the odds of an attack.
  final String Function(int amount)? verdict;

  /// Text of the confirm button for a given amount, e.g. "Send 12".
  final String Function(int amount) confirmLabel;
  final ValueChanged<int> onConfirm;
  final VoidCallback onCancel;

  @override
  State<AmountPicker> createState() => _AmountPickerState();
}

class _AmountPickerState extends State<AmountPicker> {
  late int _amount = (widget.initial ?? widget.max).clamp(1, widget.max);

  @override
  void didUpdateWidget(AmountPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    _amount = _amount.clamp(1, widget.max);
  }

  void _set(int value) => setState(() => _amount = value.clamp(1, widget.max));

  @override
  Widget build(BuildContext context) {
    final max = widget.max;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          IconButton(onPressed: _amount > 1 ? () => _set(_amount - 1) : null, icon: const Icon(Icons.remove), tooltip: 'One fewer'),
          Expanded(
            child: Slider(
              value: _amount.toDouble(),
              min: 1,
              max: max > 1 ? max.toDouble() : 2,
              divisions: max > 1 ? max - 1 : 1,
              onChanged: max > 1 ? (v) => _set(v.round()) : null,
            ),
          ),
          IconButton(onPressed: _amount < max ? () => _set(_amount + 1) : null, icon: const Icon(Icons.add), tooltip: 'One more'),
        ]),
        Row(children: [
          for (final (label, value) in [('1', 1), ('Half', (max + 1) ~/ 2), ('All', max)])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: () => _set(value),
                style: TextButton.styleFrom(
                  minimumSize: const Size(52, 40),
                  backgroundColor: _amount == value ? AtlasColors.baizeLight : null,
                ),
                child: Text(label.toUpperCase()),
              ),
            ),
        ]),
        if (widget.verdict != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6),
            child: Text(widget.verdict!(_amount), style: AtlasText.body),
          ),
        const SizedBox(height: 10),
        Row(children: [
          OutlinedButton(onPressed: widget.onCancel, child: const Text('CANCEL')),
          const SizedBox(width: 12),
          Expanded(child: FilledButton(onPressed: () => widget.onConfirm(_amount), child: Text(widget.confirmLabel(_amount).toUpperCase()))),
        ]),
      ],
    );
  }
}

/// Opens a sheet from the bottom of the screen, at most [heightFactor] of
/// its height.
Future<T?> showAtlasSheet<T>(BuildContext context, WidgetBuilder builder, {double heightFactor = 0.72}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * heightFactor),
    builder: builder,
  );
}

/// What a bottom sheet holds: its title and a note under it, a close
/// button, a brass rule, then [body], which takes the room that is left.
class AtlasSheet extends StatelessWidget {
  const AtlasSheet({super.key, required this.title, this.note, this.banner, required this.body});

  final String title;
  final String? note;

  /// Shown between the rule and the body, e.g. an error.
  final Widget? banner;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 8, 6),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: AtlasText.title),
                if (note != null) Text(note!, style: AtlasText.note),
              ]),
            ),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close), tooltip: 'Close'),
          ]),
        ),
        const Divider(color: AtlasColors.brass),
        ?banner,
        Flexible(child: body),
      ]),
    );
  }
}

/// Asks a question with two answers; true when the player picks [yes].
/// [danger] paints [yes] in red pencil, for war.
Future<bool> confirm(BuildContext context, {required String title, required String body, required String no, required String yes, bool danger = false}) async {
  final answer = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(no)),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: AtlasColors.signal, foregroundColor: AtlasColors.ivory) : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(yes),
        ),
      ],
    ),
  );
  return answer ?? false;
}

/// One choice among several, brass-ringed when [selected]. [idle] fills it
/// while it is not.
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
    this.idle,
    this.padding = const EdgeInsets.fromLTRB(12, 6, 8, 7),
    this.label,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final Color? idle;
  final EdgeInsets padding;

  /// What a screen reader says for it, in place of [child].
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: label != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: selected ? AtlasColors.baizeLight : idle,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: selected ? AtlasColors.brassBright : AtlasColors.baizeLight, width: selected ? 1.5 : 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// The first of [texts] that fits on one line, or the last one cut short.
/// The choice is worked out again only when the width or the texts change.
class FirstThatFits extends StatefulWidget {
  const FirstThatFits(this.texts, {super.key, required this.style}) : assert(texts.length > 0);

  final List<String> texts;
  final TextStyle style;

  @override
  State<FirstThatFits> createState() => _FirstThatFitsState();
}

class _FirstThatFitsState extends State<FirstThatFits> {
  double _width = -1;
  TextScaler? _scaler;
  List<String> _texts = const [];
  int _chosen = 0;

  int _choose(double width, TextScaler scaler) {
    for (var i = 0; i < widget.texts.length - 1; i++) {
      final painter = TextPainter(text: TextSpan(text: widget.texts[i], style: widget.style), maxLines: 1, textDirection: TextDirection.ltr, textScaler: scaler)..layout();
      final fits = painter.width <= width;
      painter.dispose();
      if (fits) return i;
    }
    return widget.texts.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth != _width || scaler != _scaler || !listEquals(widget.texts, _texts)) {
        _width = box.maxWidth;
        _scaler = scaler;
        _texts = widget.texts;
        _chosen = _choose(box.maxWidth, scaler);
      }
      return Text(widget.texts[_chosen], style: widget.style, maxLines: 1, overflow: TextOverflow.ellipsis);
    });
  }
}
