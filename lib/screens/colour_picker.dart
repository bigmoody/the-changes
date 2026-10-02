// Choosing a colour by hand.
//
// A square of one hue with saturation across and brightness up, and a
// strip of hues under it: the arrangement every colour picker uses, which
// is the reason to use it. Nobody has to be taught it.
//
// It was three sliders for a while. They reached every colour, which a
// grid of swatches does not, but naming one of the axes "depth" and
// asking somebody to imagine the result is a strange thing to do when the
// colours can simply be shown. Pointing at the colour you mean is the
// whole idea, and for the people this is for, who already see the colour
// they are looking for, it is the only thing that matters.
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
  late HSVColor _colour = HSVColor.fromColor(
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
            const SizedBox(height: 12),
            // The square is every colour of one hue: saturation across,
            // brightness up. The strip underneath picks the hue. It is
            // the arrangement every colour picker uses, which is the
            // reason to use it: nobody has to be taught it.
            SizedBox(
              height: 170,
              child: _Field(
                key: const ValueKey('colour-field'),
                colour: _colour,
                onPick: (saturation, value) => setState(
                  () => _colour = _colour
                      .withSaturation(saturation)
                      .withValue(value),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 32,
              child: _Hues(
                key: const ValueKey('colour-hues'),
                hue: _colour.hue,
                onPick: (hue) => setState(() => _colour = _colour.withHue(hue)),
              ),
            ),
            const SizedBox(height: 12),
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

/// Every colour of one hue: saturation left to right, brightness bottom
/// to top. Drag anywhere in it.
class _Field extends StatelessWidget {
  const _Field({super.key, required this.colour, required this.onPick});

  final HSVColor colour;
  final void Function(double saturation, double value) onPick;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      void pick(Offset at) => onPick(
        (at.dx / size.maxWidth).clamp(0.0, 1.0),
        (1 - at.dy / size.maxHeight).clamp(0.0, 1.0),
      );
      // Pointer events rather than a pan gesture: the sheet this sits in
      // drags to dismiss, and a vertical pan here was being taken by the
      // sheet. Brightness is the vertical axis, so that is most of the
      // square not working.
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) => pick(event.localPosition),
        onPointerMove: (event) => pick(event.localPosition),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              // The hue at full strength, then white washed in from the
              // left and black from the bottom: saturation and
              // brightness, drawn rather than computed.
              Positioned.fill(
                child: ColoredBox(
                  color: HSVColor.fromAHSV(1, colour.hue, 1, 1).toColor(),
                ),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.white, Color(0x00FFFFFF)],
                    ),
                  ),
                ),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black, Color(0x00000000)],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: colour.saturation * size.maxWidth - 11,
                top: (1 - colour.value) * size.maxHeight - 11,
                child: const _Spot(),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// The hues, in a strip.
class _Hues extends StatelessWidget {
  const _Hues({super.key, required this.hue, required this.onPick});

  final double hue;
  final void Function(double hue) onPick;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      void pick(Offset at) =>
          onPick((at.dx / size.maxWidth).clamp(0.0, 1.0) * 360);
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) => pick(event.localPosition),
        onPointerMove: (event) => pick(event.localPosition),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        for (var stop = 0; stop <= 6; stop++)
                          HSVColor.fromAHSV(
                            1,
                            stop * 60.0 % 360,
                            1,
                            1,
                          ).toColor(),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: hue / 360 * size.maxWidth - 11,
                top: 5,
                child: const _Spot(),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Where you are: a ring rather than a dot, so the colour under it is
/// still the colour you are looking at.
class _Spot extends StatelessWidget {
  const _Spot();

  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: 22,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 3)],
    ),
  );
}
