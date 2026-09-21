// The readout that goes with the chart: the chord sounding now, what it's
// called, and the note to aim for; under the chart on a phone held
// upright, beside it when it's turned.

import 'package:flutter/material.dart';

import '../audio/arpeggios.dart';
import '../music/chord.dart';
import '../music/chord_drill.dart';
import '../music/tuning.dart';
import '../practice/practice_controller.dart';
import '../settings/app_settings.dart';
import '../theme.dart';
import 'chord_diagram.dart';
import 'chord_reference_screen.dart';

/// A large readout of the chord being played (or the loop's first chord),
/// with its name and notes beside it. Tap for the full explanation.
class NowPlaying extends StatelessWidget {
  const NowPlaying({super.key, required this.controller});

  final PracticeController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chord = controller.shownSlot.chord;
    final aimFor = controller.settings.aimFor;
    // With arpeggios on, where this chord's one starts, so "from the 7th"
    // on C6 is plainly the 6th, A.
    final arpeggioStart = controller.arpeggios
        ? arpeggioStartOf(chord, controller.settings.arpeggioStart)
        : null;
    final arpeggioLine = arpeggioStart == null
        ? null
        : 'Arpeggio from ${arpeggioStart.note} (${arpeggioStart.degree})';
    // Scales with the screen: about 75 pt tall on a phone, more on a tablet.
    // A fingering diagram needs more room than the text alone.
    final diagram = controller.settings.diagram;
    final screen = MediaQuery.sizeOf(context);
    // Larger Text in the phone's settings makes the three lines of notes
    // taller, so the strip grows with it rather than squashing them.
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final baseHeight =
        (diagram == ChordDiagram.none
            ? (screen.height * 0.09).clamp(66.0, 120.0)
            : (screen.height * 0.15).clamp(104.0, 200.0)) *
        textScale;
    // One more line for the arpeggios, when they're on.
    final height = baseHeight + (arpeggioLine != null ? 20 * textScale : 0);
    final detailStyle = theme.textTheme.bodyMedium?.copyWith(
      height: 1.3,
      color: theme.colorScheme.onSurfaceVariant,
    );

    // With the chart down to its bars this strip would simply say the
    // chord in letters a foot high, which is the whole thing the exercise
    // is taking away. It says what is happening instead, and offers the
    // way back.
    final shows = controller.chartShows;
    if (!shows.hasChords) {
      return _HiddenInstead(controller: controller, height: height);
    }

    return InkWell(
      onTap: () => showChordDetails(context, chord),
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth:
                      screen.width *
                      (diagram == ChordDiagram.none ? 0.5 : 0.26),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    handSymbol(chord.display),
                    semanticsLabel: chord.display,
                    style: handLettered(
                      TextStyle(
                        // With a diagram beside it the name doesn't need to
                        // be the whole strip: the notes and the shape do the
                        // work.
                        fontSize:
                            baseHeight *
                            (diagram == ChordDiagram.none ? 0.78 : 0.42),
                        height: 1,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // The notes and the extensions get a line each: on a narrow
              // phone they don't fit side by side, and the end of the line
              // was being cut off.
              Expanded(
                // Each line already shrinks to fit across; this shrinks
                // them together when there are more lines than the strip
                // is tall, which happens when the strip is narrow enough
                // for a line to wrap, beside the chart on a phone held
                // sideways, say.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Long names ("Dominant 7th sharp 11") shrink rather
                      // than trail off in an ellipsis.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          chord.quality.name,
                          maxLines: 1,
                          style: theme.textTheme.titleSmall?.copyWith(
                            height: 1.25,
                          ),
                        ),
                      ),
                      // Aiming for a chord tone: the note to land on now, and
                      // the one after: at tempo you need to see it coming.
                      if (aimFor != null) ...[
                        _line(
                          _aimText('Aim', chord, aimFor) + _marking(controller),
                          detailStyle?.copyWith(
                            color: controller.check?.current?.hit == true
                                ? successColour(theme.colorScheme)
                                : theme.colorScheme.tertiary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        _line(
                          _aimText(
                            'Then ${controller.nextSlot.chord.display}',
                            controller.nextSlot.chord,
                            aimFor,
                          ),
                          detailStyle,
                        ),
                      ] else ...[
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            chord.noteNames.join(' '),
                            maxLines: 1,
                            style: detailStyle,
                          ),
                        ),
                        if (chord.extensionNotes.isNotEmpty)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'ext '
                              '${chord.extensionNotes.map((e) => '${e.note}(${e.degree})').join(' ')}',
                              maxLines: 1,
                              style: detailStyle,
                            ),
                          ),
                      ],
                      // With arpeggios on, a line of its own for where they
                      // start (the strip grows to make room).
                      if (arpeggioLine != null)
                        _line(
                          arpeggioLine,
                          detailStyle?.copyWith(
                            color: theme.colorScheme.tertiary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (diagram != ChordDiagram.none) ...[
                const SizedBox(width: 12),
                _Fingering(chord: chord, diagram: diagram, height: height),
              ],
              Icon(
                Icons.info_outline,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One line of the readout, shrinking rather than being cut off.
Widget _line(String text, TextStyle? style) => FittedBox(
  fit: BoxFit.scaleDown,
  alignment: Alignment.centerLeft,
  child: Text(text, maxLines: 1, style: style),
);

/// What the microphone makes of this chord so far: a tick once you have
/// landed on the note, or what it is hearing instead, so you can tell the
/// difference between playing the wrong note and not being heard at all.
String _marking(PracticeController controller) {
  final marking = controller.check;
  if (marking == null) return '';
  if (marking.current?.hit == true) return '  ✓';
  // Say when nothing is getting through, rather than marking silence as a
  // wrong note and leaving you to wonder which it was.
  if (controller.hearingNothing) return '  not hearing you';
  final heard = controller.heard;
  return heard == null ? '' : '  heard ${pitchClassName(heard.midi % 12)}';
}

/// "Aim: D♭ (♭3)", or both guide tones: "Aim: D♭ (♭3) · A♭ (♭7)".
String _aimText(String lead, Chord chord, DrillTarget target) {
  final notes = [
    for (final number in target.numbers)
      if (degreeFor(chord, number) case final degree?)
        '${chord.noteFor(degree)} (${prettyDegree(degree)})',
  ];
  return '$lead: ${notes.isEmpty ? '–' : notes.join(' · ')}';
}

/// The fingering diagram beside the chord, sized to the strip. A keyboard
/// is wide and short; grids are tall.
class _Fingering extends StatelessWidget {
  const _Fingering({
    required this.chord,
    required this.diagram,
    required this.height,
  });

  final Chord chord;
  final ChordDiagram diagram;
  final double height;

  @override
  Widget build(BuildContext context) => FingeringDiagram(
    // Without the extensions, a shape is quicker to read and grab at tempo:
    // D7♯11 is shown as a D7 grip, C13 as C7 in root position on the keys.
    // The extensions are listed beside it. (Bass diagrams show only roots.)
    chord: diagram == ChordDiagram.bass ? chord : chord.withoutExtensions,
    diagram: diagram,
    height: height * (diagram == ChordDiagram.keyboard ? 0.45 : 0.8),
  );
}

/// What sits where the chord readout was, once the chart has gone: what
/// has been taken away, and the way back to it.
class _HiddenInstead extends StatelessWidget {
  const _HiddenInstead({required this.controller, required this.height});

  final PracticeController controller;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shows = controller.chartShows;
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shows.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Flexible(
                    child: Text(
                      shows.line,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              key: const ValueKey('show-the-chart'),
              onPressed: controller.showTheChart,
              child: const Text('Show It'),
            ),
          ],
        ),
      ),
    );
  }
}
