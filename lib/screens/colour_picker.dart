// Choosing a colour by hand.
//
// Hue, depth and brightness, rather than a grid of swatches. Three sliders
// are not as nice as pointing at the colour you mean, but they reach every
// colour, which a grid does not, and the people this is for already know
// which colour they want.
//
// Whatever is being coloured is shown while the sliders move, drawn the
// way it will really appear, because that is the only question worth
// answering here: is this it.

import 'package:flutter/material.dart';

/// What the sheet gives back when somebody asks for no colour at all,
/// since a plain null already means they backed out. The two are different
/// answers and must not be confused.
const noColour = Color(0x00000001);

/// Asks for a colour, showing [preview] of it as it will appear.
///
/// Returns null if they backed out, [noColour] if they asked for none.
Future<Color?> pickColour(
  BuildContext context, {
  required String title,
  required Color? start,
  required Widget Function(Color) preview,
  String? clearLabel,
}) => showModalBottomSheet<Color>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) => _Picker(
    title: title,
    start: start,
    preview: preview,
    clearLabel: clearLabel,
  ),
);

class _Picker extends StatefulWidget {
  const _Picker({
    required this.title,
    required this.start,
    required this.preview,
    this.clearLabel,
  });

  final String title;
  final Color? start;
  final Widget Function(Color) preview;

  /// What to call going back to no colour. Left out when that is not an
  /// answer.
  final String? clearLabel;

  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> {
  late HSLColor _colour = HSLColor.fromColor(
    widget.start ?? const Color(0xFFC23B22),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chosen = _colour.toColor();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            widget.preview(chosen),
            const SizedBox(height: 8),
            _Slider(
              name: 'Hue',
              value: _colour.hue,
              max: 360,
              onChanged: (v) => setState(() => _colour = _colour.withHue(v)),
            ),
            _Slider(
              name: 'Depth',
              value: _colour.saturation,
              max: 1,
              onChanged: (v) =>
                  setState(() => _colour = _colour.withSaturation(v)),
            ),
            _Slider(
              name: 'Brightness',
              value: _colour.lightness,
              max: 1,
              onChanged: (v) =>
                  setState(() => _colour = _colour.withLightness(v)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (widget.clearLabel case final label?)
                  TextButton(
                    key: const ValueKey('no-colour'),
                    onPressed: () => Navigator.of(context).pop(noColour),
                    child: Text(label),
                  ),
                const Spacer(),
                FilledButton(
                  key: const ValueKey('keep-colour'),
                  onPressed: () => Navigator.of(context).pop(chosen),
                  child: const Text('Keep'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider({
    required this.name,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final String name;
  final double value;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(width: 86, child: Text(name)),
      Expanded(
        child: Slider(
          key: ValueKey('slider-$name'),
          value: value.clamp(0, max),
          max: max,
          onChanged: onChanged,
        ),
      ),
    ],
  );
}
