// Play a chord; the app names it and shows it on the keys and the guitar.
//
// What's on screen holds still between strums rather than flickering back
// to nothing: once it has named something it keeps it there until you play
// the next one, which is what you want when you're reaching for the guitar
// with one hand.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/chord_ear.dart';
import '../audio/chord_listener.dart';
import '../audio/chord_reader.dart';
import '../audio/practice_player.dart';
import '../music/chord.dart';
import '../music/chord_match.dart';
import '../music/guitar_chord_shapes.dart';
import '../music/tuning.dart';
import '../settings/app_settings.dart';
import '../theme.dart';
import 'chord_diagram.dart';

/// How the microphone is doing.
enum _Mic { starting, listening, denied, failed }

class ChordIdentifierScreen extends StatefulWidget {
  const ChordIdentifierScreen({
    super.key,
    required this.player,
    required this.settings,
    this.listener,
  });

  final PracticePlayer player;
  final AppSettings settings;

  /// Only passed by tests; the screen makes its own.
  @visibleForTesting
  final ChordListener? listener;

  @override
  State<ChordIdentifierScreen> createState() => _ChordIdentifierScreenState();
}

class _ChordIdentifierScreenState extends State<ChordIdentifierScreen> {
  late final _listener = widget.listener ?? ChordListener();
  var _mic = _Mic.starting;

  /// What was last named, kept on screen between strums.
  List<ChordGuess> _guesses = const [];
  List<int> _pitches = const [];
  var _chosen = 0;
  double _level = 0;

  /// Sounds that were too vague to name, so "nothing heard" can be told
  /// apart from "nothing played".
  var _hearingSomething = false;

  @override
  void initState() {
    super.initState();
    // Nothing should be coming out of the speaker while it listens.
    widget.player.stop();
    unawaited(_listen());
  }

  Future<void> _listen() async {
    try {
      if (!await _listener.hasPermission()) {
        if (mounted) setState(() => _mic = _Mic.denied);
        return;
      }
      await _listener.start(_heard);
      if (mounted) setState(() => _mic = _Mic.listening);
    } catch (e) {
      debugPrint('The chord identifier could not start the microphone: $e');
      if (mounted) setState(() => _mic = _Mic.failed);
    }
  }

  /// Which moments to name a chord from (see chord_reader.dart).
  final _reader = ChordReader();

  void _heard(HeardNotes heard) {
    if (!mounted) return;
    setState(() {
      _level = heard.level;
      _hearingSomething = heard.pitches.isNotEmpty;
      // The chord strummed, once it has settled, kept on screen while the
      // strings die away.
      if (_reader.hear(heard)) {
        _guesses = _reader.guesses;
        _pitches = _reader.pitches;
        _chosen = 0;
      }
    });
  }

  @override
  void dispose() {
    _listener.dispose().then((_) => widget.player.restoreAudioSession());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final guess = _guesses.isEmpty ? null : _guesses[_chosen];
    return Scaffold(
      appBar: AppBar(title: const Text('Chord Identifier')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _Ear(mic: _mic, level: _level, hearing: _hearingSomething),
            const SizedBox(height: 8),
            if (guess == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Text(
                  _mic == _Mic.denied
                      ? "The microphone is blocked: allow it in the phone's "
                            'settings and come back.'
                      : 'Play a chord.',
                  key: const ValueKey('prompt'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else ...[
              Center(
                child: Text(
                  handSymbol(guess.display),
                  key: const ValueKey('chord-name'),
                  style: handLettered(theme.textTheme.displayMedium)
                      .copyWith(height: 1.1),
                ),
              ),
              Center(
                child: Text(
                  guess.chord.quality.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _Notes(pitches: _pitches),
              if (_guesses.length > 1) ...[
                const SizedBox(height: 12),
                Text('Or', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final (i, other) in _guesses.indexed)
                      ChoiceChip(
                        key: ValueKey('guess-$i'),
                        label: Text(handSymbol(other.display)),
                        showCheckmark: false,
                        selected: i == _chosen,
                        onSelected: (_) => setState(() => _chosen = i),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Text('On the Keys', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              AspectRatio(
                aspectRatio: 3.4,
                child: KeyboardDiagram(chord: guess.chord),
              ),
              const SizedBox(height: 20),
              Text('On the Guitar', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              _Shape(chord: guess.chord, pitches: _pitches),
            ],
          ],
        ),
      ),
    );
  }
}

/// The notes it heard, low to high, as note names.
class _Notes extends StatelessWidget {
  const _Notes({required this.pitches});

  final List<int> pitches;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = [...pitches]..sort();
    return Center(
      child: Text(
        'Heard ${[for (final pitch in sorted) pitchClassName(pitch % 12, separator: '/')].join('  ')}',
        key: const ValueKey('heard-notes'),
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The fingering closest to what was actually played.
class _Shape extends StatelessWidget {
  const _Shape({required this.chord, required this.pitches});

  final Chord chord;
  final List<int> pitches;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = shapeLike(chord, pitches);
    if (shape == null) {
      return Text(
        'No shape a hand can reach',
        style: theme.textTheme.bodySmall,
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: AspectRatio(
            aspectRatio: GuitarDiagram.aspect,
            child: GuitarDiagram(chord: chord, voicing: shape),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                shape.frets.map((f) => f?.toString() ?? 'x').join(' '),
                key: const ValueKey('shape-frets'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                shape.position <= 1 ? 'Open' : 'Fret ${shape.position}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'The nearest shape to what it heard',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Whether it's hearing you, so silence can be told from a blocked
/// microphone.
class _Ear extends StatelessWidget {
  const _Ear({required this.mic, required this.level, required this.hearing});

  final _Mic mic;
  final double level;
  final bool hearing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A rough decibel scale, so quiet playing still moves the bar.
    final bar = (1 + math.log(level.clamp(0.0002, 1)) / 9).clamp(0.0, 1.0);
    final says = switch (mic) {
      _Mic.denied => 'The microphone is blocked',
      _Mic.failed => "The microphone wouldn't start",
      _Mic.starting => 'Starting the microphone…',
      _Mic.listening => hearing ? 'Hearing you' : 'Listening',
    };
    return Row(
      children: [
        Icon(
          mic == _Mic.listening ? Icons.mic : Icons.mic_off,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: LinearProgressIndicator(
            key: const ValueKey('ear-level'),
            value: bar,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
            color: hearing
                ? successColour(theme.colorScheme)
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            says,
            key: const ValueKey('ear-says'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
