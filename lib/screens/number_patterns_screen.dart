// Number patterns: one shape, run through the changes.
//
// The screen is built so the numbers stay still and the notes move, which
// is the whole idea. Pick 1-2-3-5 and it is written out over every chord
// of the progression (D E F A, then G A B D, then C D E G) with the
// numbers underneath each one so you can see your hand doing the same
// thing while the music does something different.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/backing_synth.dart';
import '../audio/practice_player.dart';
import '../music/chord.dart';
import '../music/loop_range.dart';
import '../music/number_patterns.dart';
import '../music/tune.dart';
import '../settings/app_settings.dart';
import '../theme.dart';
import 'stave_figure.dart';

const _keys = ['C', 'F', 'B♭', 'E♭', 'G', 'D', 'A'];

/// Note names for each step above a key's root, spelled for flat keys,
/// which is most of them.
const _steps = [
  'C',
  'D♭',
  'D',
  'E♭',
  'E',
  'F',
  'G♭',
  'G',
  'A♭',
  'A',
  'B♭',
  'B',
];

class NumberPatternsScreen extends StatefulWidget {
  const NumberPatternsScreen({
    super.key,
    required this.player,
    required this.settings,
  });

  final PracticePlayer player;
  final AppSettings settings;

  @override
  State<NumberPatternsScreen> createState() => _NumberPatternsScreenState();
}

class _NumberPatternsScreenState extends State<NumberPatternsScreen> {
  var _pattern = numberPatterns.first;
  var _changes = patternChanges.first;
  var _key = 'C';

  /// The band going round, so the thing can be played along with rather
  /// than listened to. Listening tells you what a shape sounds like;
  /// playing it over and over is what puts it in your hands.
  var _tempo = 100;
  var _looping = false;
  int? _atChord;
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    unawaited(widget.player.stop());
    super.dispose();
  }

  /// The progression as a tune of one bar per chord, for the band.
  Tune get _asTune => Tune.fromChart(
    title: 'Number Patterns',
    key: _key,
    defaultTempo: _tempo,
    // Built from the same text the chords were parsed from, so whatever
    // parses one parses the other.
    chart: '| ${_chordText.join(' | ')} |',
  );

  List<String> get _chordText {
    final root = _steps.indexOf(_key);
    return [
      for (final (step, quality) in _changes.chords)
        '${_steps[(root + step) % 12]}$quality',
    ];
  }

  Future<void> _stopLoop() async {
    _ticker?.cancel();
    _ticker = null;
    if (mounted) {
      setState(() {
        _looping = false;
        _atChord = null;
      });
    }
    await widget.player.stop();
  }

  Future<void> _loop() async {
    if (_looping) {
      await _stopLoop();
      return;
    }
    final tune = _asTune;
    setState(() {
      _looping = true;
      _atChord = null;
    });
    try {
      await widget.player.start(
        BackingRequest(
          tune: tune,
          loop: LoopRange.wholeTune(tune),
          tempo: _tempo,
          comping: widget.settings.comping,
          seed: math.Random().nextInt(1 << 31),
        ),
      );
    } catch (e) {
      debugPrint('Could not start the band: $e');
      await _stopLoop();
      return;
    }
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!mounted || !_looping) return;
      final beat = widget.player.position()?.tuneBeat;
      final at = beat == null ? null : beat ~/ tune.beatsPerBar;
      if (at != _atChord) setState(() => _atChord = at);
    });
  }

  void _setTempo(int to) {
    final clamped = to.clamp(40, 240);
    if (clamped == _tempo) return;
    setState(() => _tempo = clamped);
    // A new tempo is a new performance: stop and start rather than
    // leaving the band where it was.
    if (_looping) unawaited(_stopLoop().then((_) => _loop()));
  }

  /// The progression's chords in the chosen key.
  List<Chord> get _chords {
    final root = _steps.indexOf(_key);
    return [
      for (final (step, quality) in _changes.chords)
        Chord.parse('${_steps[(root + step) % 12]}$quality'),
    ];
  }

  /// Plays the pattern through the changes, each chord under its own four
  /// notes so the shape is heard against what it is being played over.
  /// Plays the pattern through the changes, or over one chord when [only]
  /// names it, for the bar you keep fumbling.
  Future<void> _play({int? only}) async {
    final bank = widget.player.samples;
    if (bank == null) return;
    const quaver = 0.26;
    final notes = <SnippetNote>[];
    var at = 0.0;
    final chords = only == null
        ? _chords
        : [_chords[only.clamp(0, _chords.length - 1)]];
    for (final chord in chords) {
      final run = patternOn(_pattern.degrees, chord);
      if (run.isEmpty) continue;
      const bar = quaver * 4;
      notes.add((
        pitch: 36 + (chord.root - 36) % 12,
        start: at,
        length: bar,
        velocity: 0.34,
        bass: true,
      ));
      for (final interval in chord.quality.intervals) {
        notes.add((
          pitch: 48 + (chord.root + interval - 48) % 12,
          start: at,
          length: bar,
          velocity: 0.2,
          bass: false,
        ));
      }
      for (final (i, note) in run.indexed) {
        notes.add((
          pitch: note.pitch,
          start: at + i * quaver,
          length: quaver * 0.92,
          velocity: i == 0 ? 0.9 : 0.72,
          bass: false,
        ));
      }
      at += bar;
    }
    if (notes.isEmpty) return;
    await widget.player.playSnippet(renderSnippet(bank, notes));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chords = _chords;
    return Scaffold(
      appBar: AppBar(title: const Text('Number Patterns')),
      // The reading scrolls; hearing it does not. Putting the controls
      // under the staves left them below the fold on a phone, which is
      // the very thing that made the old app-bar icon useless.
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                key: const ValueKey('patterns-list'),
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      '"1235" is not a lick, it is a shape: the 1st, 2nd, 3rd and '
                      '5th of whatever scale the chord wants. Your hand does the '
                      'same thing over every chord and different notes come out. '
                      'Practise the numbers and the changes do the rest. The books '
                      'call these digital patterns, "digital" meaning the digits '
                      'you count on, not anything electronic.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  _Chips(
                    values: [
                      for (final p in numberPatterns) (p.written, p.written),
                    ],
                    selected: _pattern.written,
                    onPick: (written) => setState(
                      () => _pattern = numberPatterns.firstWhere(
                        (p) => p.written == written,
                      ),
                    ),
                  ),
                  _Chips(
                    values: [for (final c in patternChanges) (c.name, c.name)],
                    selected: _changes.name,
                    onPick: (name) => setState(
                      () => _changes = patternChanges.firstWhere(
                        (c) => c.name == name,
                      ),
                    ),
                  ),
                  _Chips(
                    values: [for (final k in _keys) (k, k)],
                    selected: _key,
                    onPick: (key) => setState(() => _key = key),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(
                      '${_pattern.name}. ${_pattern.about}',
                      key: const ValueKey('about-pattern'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                    child: Text(
                      _changes.about,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final (i, chord) in chords.indexed)
                          _OverChord(
                            chord: chord,
                            degrees: _pattern.degrees,
                            // The clef once, at the front, as it is written.
                            first: i == 0,
                            sounding: _atChord == i,
                            onPlay: () => _play(only: i),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Text(
                      'The numbers under the stave are the same in every '
                      'bar. The notes are not. Once a shape is in your '
                      'hands, move the key on and do it again; that is '
                      'the whole exercise, and it is meant to take weeks '
                      'rather than minutes.',
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
              child: _Controls(
                tempo: _tempo,
                looping: _looping,
                onPlay: _play,
                onLoop: _loop,
                onTempo: _setTempo,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The pattern over one chord: the symbol, the notes, and the numbers.
class _OverChord extends StatelessWidget {
  const _OverChord({
    required this.chord,
    required this.degrees,
    required this.first,
    required this.sounding,
    required this.onPlay,
  });

  final Chord chord;
  final List<int> degrees;
  final bool first;

  /// Whether the band is on this chord right now.
  final bool sounding;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final run = patternOn(degrees, chord);
    return Padding(
      padding: const EdgeInsets.only(right: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                handSymbol(chord.display),
                key: ValueKey('over-${chord.display}'),
                style: handLettered(
                  TextStyle(
                    fontSize: 22,
                    // In pencil red while the band is on it, so you can
                    // see where you are without counting.
                    color: sounding
                        ? theme.colorScheme.tertiary
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              // One bar on its own, for the one you keep fumbling.
              IconButton(
                key: ValueKey('play-${chord.display}'),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                iconSize: 18,
                icon: const Icon(Icons.play_circle_outline),
                tooltip: 'Play it over ${chord.display}',
                onPressed: onPlay,
              ),
            ],
          ),
          const SizedBox(height: 2),
          if (run.isEmpty)
            SizedBox(
              height: 90,
              child: Center(
                child: Text(
                  'no scale',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            StaveFigure(
              columns: [
                for (final (i, note) in run.indexed)
                  StaveColumn(
                    [
                      if (note.name.length > 1)
                        sym(
                          note.name.substring(1) == '♭'
                              ? Smufl.flat
                              : Smufl.sharp,
                          step: _stepOf(note),
                          dx: -1.15,
                        ),
                      sym(
                        Smufl.noteheadBlack,
                        step: _stepOf(note),
                        // The first of each group is the one to hear
                        // landing, and the one to put on the beat.
                        marked: i == 0,
                        ledgers: true,
                      ),
                    ],
                    stem: true,
                    gap: 1.5,
                    label: '${note.degree}',
                  ),
              ],
              clef: first ? Clef.treble : null,
              beams: [(from: 0, to: run.length - 1, count: 1)],
              space: 7,
              above: 6,
              below: 6,
              semanticsLabel:
                  'Over ${chord.display}: '
                  '${[for (final n in run) n.name].join(', ')}',
            ),
        ],
      ),
    );
  }

  /// Where the note sits on a treble stave.
  static double _stepOf(PatternNote note) =>
      Clef.treble.stepOf(note.name[0], note.octave).toDouble();
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
    padding: const EdgeInsets.only(top: 10),
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

/// Hearing it: once through, or round and round with the band.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.tempo,
    required this.looping,
    required this.onPlay,
    required this.onLoop,
    required this.onTempo,
  });

  final int tempo;
  final bool looping;
  final VoidCallback onPlay;
  final VoidCallback onLoop;
  final ValueChanged<int> onTempo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('play-through'),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Play It Through'),
                onPressed: onPlay,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey('loop-band'),
                icon: Icon(looping ? Icons.stop : Icons.loop),
                label: Text(looping ? 'Stop' : 'Play Along'),
                onPressed: onLoop,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton.outlined(
              key: const ValueKey('slower'),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.remove),
              tooltip: 'Slower',
              onPressed: tempo > 40 ? () => onTempo(tempo - 5) : null,
            ),
            Expanded(
              child: Text(
                '$tempo BPM',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall,
              ),
            ),
            IconButton.outlined(
              key: const ValueKey('faster'),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.add),
              tooltip: 'Faster',
              onPressed: tempo < 240 ? () => onTempo(tempo + 5) : null,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          looping
              ? 'The band is going round. Play the numbers over it: that '
                    'is the exercise; the rest of this screen is only the '
                    'instructions.'
              : 'Play Along puts the band on a loop so you can practise '
                    'over it instead of listening to it.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
