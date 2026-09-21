// Comping: one ii–V, and the only thing changing is where the chord goes.
//
// The picture of the bar is the feature. Where a chord lands is the sort
// of thing that takes a year to hear and a second to see, and the moment
// it is drawn (two blocks and a lot of white) the point about leaving
// space makes itself without a paragraph.
//
// It is drawn from the last beat of the bar before, rather than from
// beat 1, because a push starts there. Left off, the one figure that
// explains most about comping would have nowhere to be.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/backing_synth.dart';
import '../audio/piano_comping.dart';
import '../audio/practice_player.dart';
import '../music/chord.dart';
import '../music/comping.dart';
import '../music/swing.dart';
import '../settings/app_settings.dart';
import 'swing_screen.dart' show ridePattern;

/// Medium, where most of the repertoire sits and where the placement is
/// plainest to a listener.
const _tempo = 150;

class CompingScreen extends StatefulWidget {
  const CompingScreen({
    super.key,
    required this.player,
    required this.settings,
  });

  final PracticePlayer player;
  final AppSettings settings;

  @override
  State<CompingScreen> createState() => _CompingScreenState();
}

class _CompingScreenState extends State<CompingScreen> {
  var _figure = CompFigure.charleston;

  /// How late the "and" is at this tempo, the same answer the band gets.
  static final _and = swingAt(_tempo);

  /// A ii–V, because a figure only means anything across a change.
  static final _changes = [Chord.parse('Dm7'), Chord.parse('G7')];

  Future<void> _play() async {
    final bank = widget.player.samples;
    if (bank == null) return;
    final beat = 60 / _tempo;
    // A bar of time first, so a push has a bar to be early against and
    // so there is something to hear the placement in.
    const leadIn = 1;
    final bars = leadIn + _changes.length;
    final notes = <SnippetNote>[];
    final comper = Comper(math.Random(1));

    for (final (i, chord) in _changes.indexed) {
      final barStart = (leadIn + i) * 4 * beat;
      final next = i + 1 < _changes.length ? _changes[i + 1] : null;
      final voicing = comper.voice(chord, next);
      notes.add((
        pitch: 38 + (chord.bass - 38) % 12,
        start: barStart,
        length: 4 * beat * 0.95,
        velocity: 0.34,
        bass: true,
      ));
      for (final (at, length, weight) in _figure.strikes(_and)) {
        for (final pitch in voicing) {
          notes.add((
            pitch: pitch,
            start: barStart + at * beat,
            length: length * beat,
            velocity: 0.52 * weight,
            bass: false,
          ));
        }
      }
    }
    await widget.player.playSnippet(
      renderSnippet(
        bank,
        notes,
        drums: ridePattern(tempo: _tempo, at: _and, bars: bars),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Comping')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                key: const ValueKey('comping-list'),
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      'The chart gives you the chords. What it never tells '
                      'you is when to put them down, and for a piano or a '
                      'guitar that is most of the job. A good bar is two '
                      'chords and a lot of nothing.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  _BarPicture(figure: _figure, and: _and),
                  _Chips(
                    values: [
                      for (final figure in CompFigure.values)
                        (figure.name, figure.label),
                    ],
                    selected: _figure.name,
                    onPick: (name) => setState(
                      () => _figure = CompFigure.values.firstWhere(
                        (f) => f.name == name,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(
                      _figure.about,
                      key: const ValueKey('about-figure'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (!_figure.playedByTheBand)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Text(
                        'The band never plays this one.',
                        key: const ValueKey('never-played'),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.tertiary,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Text(
                      'Dm7 to G7, with the band. The figure is the only '
                      'thing changing: same chords, same voicings, same '
                      'tempo.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('play-comping'),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Hear It'),
                  onPressed: _play,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One bar, with a block wherever the chord is sounding.
///
/// The last beat of the bar before is drawn too, faintly, because a push
/// lands in it, and seeing the chord arrive on the wrong side of the bar
/// line is the quickest way to understand what a push is.
class _BarPicture extends StatelessWidget {
  const _BarPicture({required this.figure, required this.and});

  final CompFigure figure;
  final double and;

  /// The drawing runs from the last beat of the bar before to the end of
  /// the bar: five beats in all.
  static const _from = -1.0;
  static const _to = 4.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${strikeCount(figure)} '
            '${strikeCount(figure) == 1 ? 'chord' : 'chords'} · '
            '${whereItLands(figure, and)}',
            key: const ValueKey('where-it-lands'),
            style: theme.textTheme.titleSmall?.copyWith(color: scheme.tertiary),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, size) {
              double x(double beat) =>
                  (beat - _from) / (_to - _from) * size.maxWidth;
              return SizedBox(
                height: 52,
                child: Stack(
                  children: [
                    // The bar before, greyed: it belongs to the chord
                    // that came earlier.
                    Positioned(
                      left: 0,
                      width: x(0),
                      top: 0,
                      bottom: 16,
                      child: ColoredBox(color: scheme.surfaceContainerHighest),
                    ),
                    for (var beat = -1; beat <= 4; beat++)
                      Positioned(
                        left: x(beat.toDouble()) - (beat == 0 ? 1 : 0.5),
                        width: beat == 0 ? 2 : 1,
                        top: 0,
                        bottom: 16,
                        child: ColoredBox(
                          color: beat == 0 ? scheme.onSurface : scheme.outline,
                        ),
                      ),
                    for (final (at, length, weight) in figure.strikes(and))
                      Positioned(
                        left: x(at),
                        width: math.max(6, x(at + length) - x(at)),
                        top: 6,
                        bottom: 22,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.tertiary.withValues(
                              alpha: 0.35 + weight * 0.4,
                            ),
                            borderRadius: BorderRadius.circular(3),
                            border: Border(
                              left: BorderSide(
                                color: scheme.tertiary,
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    for (final (beat, written) in const [
                      (-1.0, '4'),
                      (0.0, '1'),
                      (1.0, '2'),
                      (2.0, '3'),
                      (3.0, '4'),
                    ])
                      Positioned(
                        left: x(beat) + 3,
                        bottom: 0,
                        child: Text(
                          written,
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontSize: 11,
                            color: beat < 0
                                ? scheme.outline
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            'One bar, with the last beat of the one before it on the left '
            'of the bar line.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A labelled row of chips that scrolls sideways.
class _Chips extends StatelessWidget {
  const _Chips({
    required this.values,
    required this.selected,
    required this.onPick,
  });

  final List<(String, String)> values;
  final String selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final (value, written) in values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                key: ValueKey('pick-$value'),
                visualDensity: VisualDensity.compact,
                showCheckmark: false,
                label: Text(written),
                selected: value == selected,
                onSelected: (_) => onPick(value),
              ),
            ),
        ],
      ),
    ),
  );
}
