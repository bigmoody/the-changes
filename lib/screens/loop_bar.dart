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
            final compact = constraints.maxWidth < 600;
            // On a phone, "Whole tune", where the band comes in and how many
            // times round are more than the row holds. The chorus count
            // already says it is the whole tune, so the name gives way.
            final named =
                !(compact && wholeTune && controller.startBar != null);
            return Row(
              children: [
                if (named) ...[
                  Icon(
                    Icons.repeat,
                    size: 20,
                    color: theme.colorScheme.tertiary,
                  ),
                  const SizedBox(width: 6),
                  // A long loop's name ("Bars 1–16") may shrink to an
                  // ellipsis if it has to, but it takes no share of the free
                  // space: with a flex of 1 it split the row with the chips
                  // beside it and squeezed them off the edge.
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: most),
                    child: Text(
                      loop.describe(tune),
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ],
                // Where the band comes in, when that isn't the top. It sits
                // outside the scrolling strip: it is a thing you have
                // switched on, and it has to be as easy to switch off.
                if (controller.startBar case final bar?) ...[
                  const SizedBox(width: 6),
                  InputChip(
                    key: const ValueKey('starts-at'),
                    visualDensity: VisualDensity.compact,
                    avatar: Icon(
                      Icons.keyboard_tab,
                      size: 16,
                      color: theme.colorScheme.tertiary,
                    ),
                    label: Text('From ${bar + 1}'),
                    deleteIcon: const Icon(
                      Icons.close,
                      key: ValueKey('starts-at-clear'),
                      size: 16,
                    ),
                    onDeleted: controller.startFromTheTop,
                    tooltip:
                        'The first time through starts at bar ${bar + 1}, '
                        'then it comes round to the top',
                  ),
                ],
                const SizedBox(width: 8),
                // Everything between the loop's name and the way out of it
                // goes in one strip that scrolls. Nothing in here is a fixed
                // width, so however many chips a bar wants (looping one bar
                // of two chords asks for three) the row can't be pushed over
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
                          // The meter, when it is not the one the tune
                          // was written in. Counting a standard another
                          // way is a practice exercise and not a claim
                          // about the tune, so the chart has to say so
                          // where the chart is, not only in the sheet
                          // where it was chosen.
                          if (controller.meterIsChosen) ...[
                            Tooltip(
                              message:
                                  '${controller.originalTune.title} is '
                                  'written in '
                                  '${controller.originalTune.meter.label}; '
                                  'you are counting it in '
                                  '${controller.meter.label}. Tap to '
                                  'change it.',
                              child: ActionChip(
                                key: const ValueKey('chart-meter'),
                                visualDensity: VisualDensity.compact,
                                onPressed: () =>
                                    showViewOptions(context, controller),
                                label: Text(
                                  controller.meter.label,
                                  semanticsLabel:
                                      'Counted in ${controller.meter.label}, '
                                      'written in '
                                      '${controller.originalTune.meter.label}',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          // What the small red line under each chord is.
                          // It is set in a sheet and then forgotten, and
                          // an unexplained row of letters under a chord is
                          // worse than no help at all.
                          if (controller.settings.chordAid != ChordAid.off) ...[
                            Tooltip(
                              message: controller.settings.chordAid.legend,
                              child: ActionChip(
                                key: const ValueKey('chord-aid'),
                                visualDensity: VisualDensity.compact,
                                avatar: Icon(
                                  Icons.school_outlined,
                                  size: 15,
                                  color: theme.colorScheme.tertiary,
                                ),
                                onPressed: () =>
                                    showViewOptions(context, controller),
                                label: Text(
                                  controller.settings.chordAid.short,
                                  semanticsLabel:
                                      controller.settings.chordAid.legend,
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
                              'Tap or drag to loop · hold to start there',
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
                // How many times round before the band ends it, where the
                // whole tune is playing: a tune has to know when to stop,
                // and that was three taps deep in the Arrangement sheet.
                if (wholeTune)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: most),
                    // On a phone the row is shared with the start chip and
                    // the chart's chips, so it says the number and no more;
                    // the menu and the tooltip say what it is a number of.
                    child: _ChorusCount(
                      controller: controller,
                      compact: compact,
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
  final total = controller.choruses;
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

/// How many choruses the band plays, as a button that offers the others.
class _ChorusCount extends StatelessWidget {
  const _ChorusCount({required this.controller, required this.compact});

  final PracticeController controller;
  final bool compact;

  /// The counts on offer. Nought stands for keep going.
  static const counts = [1, 2, 3, 4, 5, 6, 8, 12, 0];

  @override
  Widget build(BuildContext context) {
    final count = controller.arrangement.choruses;
    return PopupMenuButton<int>(
      key: const ValueKey('chorus-count'),
      tooltip: 'How many times round the tune before the band ends it',
      initialValue: count ?? 0,
      onSelected: (chosen) => controller.setArrangement(
        chosen == 0
            ? controller.arrangement.copyWith(keepGoing: true)
            : controller.arrangement.copyWith(choruses: chosen),
      ),
      itemBuilder: (context) => [
        for (final option in counts)
          PopupMenuItem(
            key: ValueKey('chorus-count-$option'),
            value: option,
            child: Text(chorusCountLabel(option == 0 ? null : option)),
          ),
      ],
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 10,
          vertical: 8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              count == null ? Icons.all_inclusive : Icons.flag_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            if (!compact || count != null) ...[
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  compact ? '$count' : chorusCountLabel(count),
                  semanticsLabel: chorusCountLabel(count),
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "3 Choruses", "1 Chorus" or "Keep Going".
String chorusCountLabel(int? count) => switch (count) {
  null => 'Keep Going',
  1 => '1 Chorus',
  _ => '$count Choruses',
};
