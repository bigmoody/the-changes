// The strip over the chart saying what's looping, and the shortcuts for
// changing it.

import 'package:flutter/material.dart';

import '../music/arrangement.dart';
import '../practice/practice_controller.dart';
import '../settings/app_settings.dart';
import 'practice_sheets.dart';

/// One line saying what's looping, with shortcuts to change it.
class LoopBar extends StatelessWidget {
  const LoopBar({super.key, required this.controller});

  final PracticeController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tune = controller.chart;
    final loop = controller.loop;
    final wholeTune = loop.isWholeTune(tune);

    // Offer "just this chord" when a single bar holding several chords is
    // looped, and "whole bar" when a single chord is looped.
    final singleBar = loop.firstBar(tune) == loop.lastBar(tune);
    final barSlots = tune.bars[loop.firstBar(tune)];
    final chips = <Widget>[
      if (singleBar && loop.isBarAligned(tune) && barSlots.length > 1)
        for (final slot in barSlots)
          ActionChip(
            visualDensity: VisualDensity.compact,
            label: Text('${slot.chord.display} only'),
            onPressed: () => controller.loopChord(slot),
          ),
      if (!loop.isBarAligned(tune))
        ActionChip(
          visualDensity: VisualDensity.compact,
          label: Text('Whole bar ${loop.firstBar(tune) + 1}'),
          onPressed: () => controller.loopBar(loop.firstBar(tune)),
        ),
    ];
    final instrument = controller.settings.instrument;

    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Neither the loop's name nor the way out of it may take more
            // than this much of the row. At the ordinary text size both are
            // well inside it and nothing is cut; at three times the size
            // either one on its own is wider than the phone, and without a
            // ceiling it pushes the rest over the edge.
            final most = constraints.maxWidth * 0.4;
            return Row(
              children: [
                Icon(Icons.repeat, size: 20, color: theme.colorScheme.tertiary),
                const SizedBox(width: 6),
                // A long loop's name ("Bars 1–16") may shrink to an ellipsis
                // if it has to, but it takes no share of the free space: with
                // a flex of 1 it split the row with the chips beside it and
                // squeezed them off the edge.
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: most),
                  child: Text(
                    loop.describe(tune),
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                const SizedBox(width: 8),
                // Everything between the loop's name and the way out of it
                // goes in one strip that scrolls. Nothing in here is a fixed
                // width, so however many chips a bar wants — looping one bar
                // of two chords asks for three — the row can't be pushed over
                // the edge of the screen.
                Expanded(
                  child: ShaderMask(
                    // What runs past the end fades rather than being chopped
                    // off square against the button beside it, which read as
                    // two controls sitting on top of each other.
                    shaderCallback: (bounds) => const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Colors.black, Colors.black, Colors.transparent],
                      stops: [0, 0.88, 1],
                    ).createShader(bounds),
                    blendMode: BlendMode.dstIn,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // First, so it's the one thing here always in view:
                          // it says what key the chart is written in, which is
                          // worth knowing before anything else in the row.
                          if (instrument != ChartInstrument.concert) ...[
                            Tooltip(
                              message:
                                  'Chart for ${instrument.name}; the band plays '
                                  'at concert pitch. Tap to change it.',
                              // It sits among chips you can tap, so it has to
                              // be one: it used to be a label that looked like
                              // a button and did nothing. It opens the place
                              // the chart's instrument is actually chosen.
                              child: ActionChip(
                                key: const ValueKey('chart-instrument'),
                                visualDensity: VisualDensity.compact,
                                onPressed: () =>
                                    showViewOptions(context, controller),
                                // Just the letter: spelling out "E♭ chart" took
                                // a third of a phone's width, and the tooltip
                                // says the rest.
                                label: Text(
                                  instrument.symbol,
                                  semanticsLabel:
                                      'Chart for ${instrument.name}',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (controller.chorus != null ||
                              controller.isFinishing)
                            Text(
                              _chorusLine(controller),
                              key: const ValueKey('chorus-line'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.tertiary,
                              ),
                            )
                          else if (wholeTune)
                            Text(
                              'Tap or drag across bars to loop',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            )
                          else
                            for (final chip in chips)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: chip,
                              ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!wholeTune)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: most),
                    child: TextButton(
                      // The app's buttons are roomy, which is right where
                      // there is room; here it shares a row with a chip per
                      // chord.
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      onPressed: controller.loopWholeTune,
                      child: const Text(
                        'Whole tune',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Where the performance has got to: which time round the form, and what
/// the band is doing with it.
String _chorusLine(PracticeController controller) {
  if (controller.isFinishing) return "That's it";
  final chorus = controller.chorus;
  if (chorus == null) return '';
  final total = controller.arrangement.choruses;
  final plan = controller.chorusPlan;
  return [
    total == null ? 'Chorus $chorus' : 'Chorus $chorus of $total',
    if (controller.arrangement.ramp.isOn) '${controller.currentTempo} BPM',
    if (controller.check case final marking?) marking.describe(),
    if (plan != null) ...[
      if (plan.head) 'head',
      if (plan.trading != Trading.off)
        'trading ${plan.trading.label.toLowerCase()}',
      for (final part in LayOut.values)
        if (plan.layOut.contains(part))
          'no ${part == LayOut.chords ? controller.settings.comping.label.toLowerCase() : part.label.toLowerCase()}',
    ],
  ].join(' · ');
}
