// Tuner and pitch practice.
//
// Tap one of the twelve notes to hear it; it becomes the target. Then play
// or sing it back, and the needle shows how close you are, in whatever
// octave you're in. With no target it's a chromatic tuner: it names the note
// you're playing and how far off it is.
//
// For transposing instruments the notes are named as the player reads them:
// a trumpeter's written C sounds, and is played, as a concert B♭.

import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/backing_synth.dart';
import '../audio/practice_player.dart';
import '../audio/tuner_listener.dart';
import '../music/tuning.dart';
import '../settings/app_settings.dart';
import '../theme.dart';
import 'chart_instrument_button.dart';
import 'note_ink.dart';

/// Within this many cents counts as in tune: closer than most ears can tell.
const inTuneCents = 5.0;

class TunerScreen extends StatefulWidget {
  const TunerScreen({
    super.key,
    required this.player,
    required this.settings,
    this.listener,
  });

  final PracticePlayer player;
  final AppSettings settings;

  /// The microphone; replaced in tests.
  final TunerListener? listener;

  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

enum _MicState { starting, listening, denied, failed }

class _TunerScreenState extends State<TunerScreen> {
  late final _listener = widget.listener ?? TunerListener();
  var _mic = _MicState.starting;
  Heard _heard;

  /// The note being aimed for, as written for the player's instrument
  /// (0 = C), or null for plain tuning.
  int? _target;

  /// Which octave the reference notes play in: 4 starts on middle C.
  var _octave = 4;

  Timer? _flash;
  int? _sounding;

  /// How far the player's written notes are above concert pitch.
  int get _transpose => widget.settings.instrument.semitones;

  @override
  void initState() {
    super.initState();
    // The band would drown out the player, and the mic would hear it.
    widget.player.stop();
    _startListening();
  }

  Future<void> _startListening() async {
    setState(() => _mic = _MicState.starting);
    try {
      if (!await _listener.hasPermission()) {
        if (mounted) setState(() => _mic = _MicState.denied);
        return;
      }
      await _listener.start((heard) {
        if (mounted) setState(() => _heard = heard);
      });
      if (mounted) setState(() => _mic = _MicState.listening);
    } catch (e) {
      debugPrint('Tuner could not start the microphone: $e');
      if (mounted) setState(() => _mic = _MicState.failed);
    }
  }

  /// Plays [pitchClass] (as written) and makes it the target.
  Future<void> _play(int pitchClass) async {
    setState(() {
      _target = pitchClass;
      _sounding = pitchClass;
    });
    _flash?.cancel();
    _flash = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _sounding = null);
    });
    final written = 12 * (_octave + 1) + pitchClass;
    await widget.player.playSnippet(
      referenceTone(midiToHz(written - _transpose)),
    );
  }

  @override
  void dispose() {
    _flash?.cancel();
    // Stop listening, then give the band its audio set-up back.
    _listener.dispose().then((_) => widget.player.restoreAudioSession());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.settings,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final theme = Theme.of(context);
    final heard = _heard;
    // What the player is playing, as they'd read it.
    final writtenMidi = heard == null ? null : hzToMidi(heard.hz) + _transpose;
    final instrument = widget.settings.instrument;
    return Scaffold(
      appBar: AppBar(title: const Text('Tuner')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            children: [
              InstrumentKeyPicker(
                instrument: instrument,
                onChanged: (value) {
                  // A target is a written note; in a new key it'd sound
                  // different, so start afresh.
                  setState(() => _target = null);
                  widget.settings.setInstrument(value);
                },
                showExamples: true,
              ),
              Expanded(
                child: switch (_mic) {
                  _MicState.listening => _Reading(
                    writtenMidi: writtenMidi,
                    hz: heard?.hz,
                    target: _target,
                  ),
                  _MicState.starting => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  _MicState.denied => _Message(
                    icon: Icons.mic_off,
                    text:
                        'The tuner needs the microphone to hear you. Allow it '
                        'in Settings → The Changes → Microphone. You can '
                        'still play the notes below to practise by ear.',
                    onRetry: _startListening,
                  ),
                  _MicState.failed => _Message(
                    icon: Icons.error_outline,
                    text:
                        "The microphone couldn't be started. You can still "
                        'play the notes below to practise by ear.',
                    onRetry: _startListening,
                  ),
                },
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _target == null
                          ? 'Tap a note to hear it, then match it'
                          : 'Play or sing ${pitchClassName(_target!)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (_target != null)
                    TextButton(
                      onPressed: () => setState(() => _target = null),
                      child: const Text('Any note'),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              _NotePad(
                target: _target,
                sounding: _sounding,
                heard: writtenMidi?.round(),
                onTap: _play,
              ),
              const SizedBox(height: 8),
              _OctaveStepper(
                octave: _octave,
                onChanged: (octave) => setState(() => _octave = octave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The note heard, and a needle showing how far off it is: from the target
/// if there is one, otherwise from the nearest note.
class _Reading extends StatelessWidget {
  const _Reading({
    required this.writtenMidi,
    required this.hz,
    required this.target,
  });

  final double? writtenMidi;
  final double? hz;
  final int? target;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final midi = writtenMidi;
    final target = this.target;
    if (midi == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (target != null) ...[
              Text('Aim For', style: theme.textTheme.titleMedium),
              Flexible(
                child: _BigNote(pitchClass: target, colour: scheme.primary),
              ),
              const SizedBox(height: 8),
            ] else
              Icon(Icons.mic, size: 48, color: scheme.primary),
            const SizedBox(height: 8),
            Text(
              target == null ? 'Play a note' : 'Play or sing it',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Listening…',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final nearest = noteNear(midi);
    final playedName = pitchClassName(nearest.midi % 12);
    // Against the target: how far from it, in whichever octave.
    final cents = target == null
        ? nearest.cents
        : centsFromPitchClass(midi, target);
    final inTune = cents.abs() <= inTuneCents;
    final colour = inTune
        ? successColour(Theme.of(context).colorScheme)
        : scheme.error;
    final wrongNote = target != null && cents.abs() > 50;
    final advice = inTune
        ? (target == null ? 'In tune' : 'Spot on')
        : cents < 0
        ? 'Flat, go up'
        : 'Sharp, go down';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          target == null
              ? 'You\'re playing'
              : wrongNote
              ? 'You\'re on $playedName, aim for ${pitchClassName(target)}'
              : 'Aiming for ${pitchClassName(target)}',
          key: const ValueKey('tuner-heading'),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        // The letter gives way first when the screen is short.
        Flexible(
          child: _BigNote(
            pitchClass: target ?? nearest.midi % 12,
            colour: inTune ? colour : scheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        _Needle(cents: cents, colour: colour),
        const SizedBox(height: 12),
        Text(
          advice,
          key: const ValueKey('tuner-advice'),
          style: theme.textTheme.headlineSmall?.copyWith(
            color: colour,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${cents >= 0 ? '+' : '−'}${cents.abs().round()} cents'
          '  ·  ${hz!.toStringAsFixed(1)} Hz',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// The note, as big as the screen will take it.
///
/// [colour] is what the tuner wants to say: green for in tune, plain
/// otherwise. Somebody who sees the pitch as a colour gets that instead,
/// because it is the stronger fact about the note and the tuning is
/// already being said by the needle, the advice and the cents. Both
/// spellings are shown, and if they are being kept apart the two halves
/// are coloured apart, since a heard pitch could honestly be either.
class _BigNote extends StatelessWidget {
  const _BigNote({required this.pitchClass, required this.colour});

  final int pitchClass;
  final Color colour;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: NoteText.pitchClass(
      pitchClass,
      key: const ValueKey('tuner-note'),
      on: Theme.of(context).colorScheme.surface,
      style: Theme.of(context).textTheme.displayLarge?.copyWith(
        fontSize: 110,
        fontWeight: FontWeight.w800,
        color: colour,
        height: 1.1,
      ),
    ),
  );
}

/// A dial from 50 cents flat to 50 cents sharp, with the in-tune zone
/// marked in the middle.
class _Needle extends StatelessWidget {
  const _Needle({required this.cents, required this.colour});

  final double cents;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 56,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          double x(double c) =>
              width / 2 + (c.clamp(-50.0, 50.0) / 50) * width / 2;
          return Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 26,
                child: Container(height: 4, color: scheme.outlineVariant),
              ),
              Positioned(
                left: x(-inTuneCents),
                width: x(inTuneCents) - x(-inTuneCents),
                top: 18,
                child: Container(
                  height: 20,
                  decoration: BoxDecoration(
                    color: successColour(Theme.of(context).colorScheme)
                        .withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              for (final mark in [-50.0, -25.0, 0.0, 25.0, 50.0])
                Positioned(
                  left: x(mark) - 1,
                  top: 14,
                  child: Container(width: 2, height: 28, color: scheme.outline),
                ),
              // The needle glides rather than jumping between readings.
              TweenAnimationBuilder<double>(
                tween: Tween(end: cents.clamp(-50, 50)),
                duration: const Duration(milliseconds: 150),
                builder: (context, value, _) => Positioned(
                  left: x(value) - 3,
                  top: 0,
                  child: Container(
                    width: 6,
                    height: 56,
                    decoration: BoxDecoration(
                      color: colour,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The twelve notes, C to B. The target is filled in; the note being heard
/// is outlined.
class _NotePad extends StatelessWidget {
  const _NotePad({
    required this.target,
    required this.sounding,
    required this.heard,
    required this.onTap,
  });

  final int? target;
  final int? sounding;

  /// The (written) MIDI note being heard, if any.
  final int? heard;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 6;
        const gap = 6.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var note = 0; note < 12; note++)
              SizedBox(
                key: ValueKey('note-$note'),
                width: width,
                height: 56,
                child: Semantics(
                  button: true,
                  selected: target == note,
                  label: 'Play ${pitchClassName(note, separator: ' or ')}',
                  excludeSemantics: true,
                  child: Material(
                    color: target == note
                        ? scheme.primary
                        : scheme.surfaceContainerHigh,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: heard != null && heard! % 12 == note
                          ? BorderSide(color: scheme.tertiary, width: 3)
                          : sounding == note && target != note
                          ? BorderSide(color: scheme.primary, width: 2)
                          : BorderSide.none,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onTap(note),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: NoteText.pitchClass(
                              note,
                              separator: '\n',
                              textAlign: TextAlign.center,
                              on: target == note
                                  ? scheme.primary
                                  : scheme.surfaceContainerHigh,
                              style: TextStyle(
                                fontSize: 18,
                                height: 1.1,
                                fontWeight: FontWeight.w700,
                                color: target == note
                                    ? scheme.onPrimary
                                    : scheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Which octave the reference notes are played in.
class _OctaveStepper extends StatelessWidget {
  const _OctaveStepper({required this.octave, required this.onChanged});

  final int octave;
  final ValueChanged<int> onChanged;

  static const lowest = 2;
  static const highest = 5;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(
        icon: const Icon(Icons.remove),
        tooltip: 'Lower octave',
        onPressed: octave > lowest ? () => onChanged(octave - 1) : null,
      ),
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            octave == 4 ? 'Octave 4 (middle C)' : 'Octave $octave',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
      ),
      IconButton(
        icon: const Icon(Icons.add),
        tooltip: 'Higher octave',
        onPressed: octave < highest ? () => onChanged(octave + 1) : null,
      ),
    ],
  );
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    required this.onRetry,
  });

  final IconData icon;
  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 48, color: Theme.of(context).colorScheme.error),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}
