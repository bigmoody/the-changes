// Tuner and pitch practice.
//
// Tap one of the twelve notes to hear it; it becomes the target. Then play
// or sing it back, and the trace shows how close you are, in whatever
// octave you're in. With no target it's a chromatic tuner: it names the note
// you're playing and how far off it is.
//
// Laid out the way a player's strobe-style tuner is: the hertz, the note
// and the cents across the top, and under them a trace of the last few
// seconds scrolling down the page, so a note that wobbles, drifts or
// settles can be seen doing it, not only where it is now. The page goes
// green while you are in tune. The notes to play are a keyboard.
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

  /// The last few seconds of readings, newest last: cents from the target
  /// (or the nearest note), or null where nothing was heard.
  final _trace = <double?>[];

  /// How many readings the trace shows: two seconds, a reading every
  /// 80 ms. Four seconds crawled down the page; a tuner's trace runs.
  static const _traceLength = 25;

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
        if (!mounted) return;
        setState(() {
          _heard = heard;
          _trace.add(
            heard == null ? null : _centsOff(hzToMidi(heard.hz) + _transpose),
          );
          if (_trace.length > _traceLength) _trace.removeAt(0);
        });
      });
      if (mounted) setState(() => _mic = _MicState.listening);
    } catch (e) {
      debugPrint('Tuner could not start the microphone: $e');
      if (mounted) setState(() => _mic = _MicState.failed);
    }
  }

  /// How far [writtenMidi] is from the target, in whichever octave, or
  /// from the nearest note when there is no target.
  double _centsOff(double writtenMidi) => _target == null
      ? noteNear(writtenMidi).cents
      : centsFromPitchClass(writtenMidi, _target!);

  /// Plays [pitchClass] (as written) and makes it the target.
  Future<void> _play(int pitchClass) async {
    setState(() {
      _target = pitchClass;
      _sounding = pitchClass;
      // Measured against another note now: the old trace is a different
      // question.
      _trace.clear();
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
                    trace: _trace,
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
                      onPressed: () => setState(() {
                        _target = null;
                        _trace.clear();
                      }),
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
              _OctaveButtons(
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

/// The note heard, how far off it is (from the target if there is one,
/// otherwise from the nearest note), and the trace of the last few
/// seconds.
class _Reading extends StatelessWidget {
  const _Reading({
    required this.writtenMidi,
    required this.hz,
    required this.target,
    required this.trace,
  });

  final double? writtenMidi;
  final double? hz;
  final int? target;
  final List<double?> trace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final midi = writtenMidi;
    final target = this.target;
    final nearest = midi == null ? null : noteNear(midi);
    final cents = midi == null
        ? null
        : target == null
        ? nearest!.cents
        : centsFromPitchClass(midi, target);
    final inTune = cents != null && cents.abs() <= inTuneCents;
    final colour = inTune ? successColour(scheme) : scheme.error;
    final wrongNote = target != null && cents != null && cents.abs() > 50;
    final playedName = nearest == null
        ? null
        : pitchClassName(nearest.midi % 12);
    final figures = theme.textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final caption = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      letterSpacing: 1.2,
    );

    return Column(
      children: [
        Text(
          midi == null
              ? (target == null ? 'Play a note' : 'Play or sing it')
              : target == null
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
        // Hertz, the note, cents: the three things a tuner says, across.
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _Figure(
                  value: hz == null ? '–' : hz!.toStringAsFixed(1),
                  label: 'HERTZ',
                  style: figures,
                  caption: caption,
                ),
              ),
              Expanded(
                flex: 2,
                child: target == null && nearest == null
                    ? Icon(Icons.mic, size: 48, color: scheme.primary)
                    : _BigNote(
                        pitchClass: target ?? nearest!.midi % 12,
                        // The octave of what is being played, as written.
                        octave: nearest == null ? null : nearest.midi ~/ 12 - 1,
                        colour: inTune ? colour : scheme.onSurface,
                      ),
              ),
              Expanded(
                child: _Figure(
                  value: cents == null
                      ? '–'
                      : '${cents >= 0 ? '+' : '−'}'
                            '${cents.abs().toStringAsFixed(1)}',
                  label: 'CENTS',
                  style: figures?.copyWith(
                    color: cents == null ? null : colour,
                  ),
                  caption: caption,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _Trace(trace: trace, inTune: inTune),
        ),
        const SizedBox(height: 8),
        Text(
          cents == null
              ? 'Listening…'
              : inTune
              ? (target == null ? 'In tune' : 'Spot on')
              : cents < 0
              ? 'Flat, go up'
              : 'Sharp, go down',
          key: const ValueKey('tuner-advice'),
          style: theme.textTheme.titleLarge?.copyWith(
            color: cents == null ? scheme.onSurfaceVariant : colour,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// A number and what it is, small capitals under it.
class _Figure extends StatelessWidget {
  const _Figure({
    required this.value,
    required this.label,
    required this.style,
    required this.caption,
  });

  final String value;
  final String label;
  final TextStyle? style;
  final TextStyle? caption;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(value, style: style),
      ),
      Text(label, style: caption),
    ],
  );
}

/// The last few seconds, scrolling down the page: the newest reading at
/// the top, each older one a step further down, drawn across a scale from
/// 50 cents flat to 50 sharp with the in-tune band down the middle. The
/// whole panel goes green while the note is in tune. A gap is a moment
/// nothing was heard.
class _Trace extends StatelessWidget {
  const _Trace({required this.trace, required this.inTune});

  final List<double?> trace;
  final bool inTune;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final green = successColour(scheme);
    return Semantics(
      label: 'Pitch over the last few seconds',
      child: AnimatedContainer(
        key: const ValueKey('tuner-trace'),
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: inTune
              ? green.withValues(alpha: 0.32)
              : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CustomPaint(
            painter: _TracePainter(
              trace: List.of(trace),
              line: scheme.onSurface,
              band: green.withValues(alpha: inTune ? 0.45 : 0.22),
              marks: scheme.outline.withValues(alpha: 0.5),
              centre: scheme.onSurface.withValues(alpha: 0.55),
              length: _TunerScreenState._traceLength,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _TracePainter extends CustomPainter {
  _TracePainter({
    required this.trace,
    required this.line,
    required this.band,
    required this.marks,
    required this.centre,
    required this.length,
  });

  final List<double?> trace;
  final Color line;
  final Color band;
  final Color marks;
  final Color centre;
  final int length;

  @override
  void paint(Canvas canvas, Size size) {
    double x(double cents) =>
        size.width / 2 + (cents.clamp(-50.0, 50.0) / 50) * size.width / 2;
    // The in-tune band, and the quarter marks either side of it.
    canvas.drawRect(
      Rect.fromLTRB(x(-inTuneCents), 0, x(inTuneCents), size.height),
      Paint()..color = band,
    );
    final tick = Paint()
      ..color = marks
      ..strokeWidth = 1;
    for (final mark in [-25.0, 25.0]) {
      canvas.drawLine(Offset(x(mark), 0), Offset(x(mark), size.height), tick);
    }
    // Dead centre, the note exactly: the line the trace is aiming at.
    canvas.drawLine(
      Offset(x(0), 0),
      Offset(x(0), size.height),
      Paint()
        ..color = centre
        ..strokeWidth = 1.5,
    );
    // Newest at the top.
    final step = size.height / (length - 1);
    final pen = Paint()
      ..color = line
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    var path = Path();
    var drawing = false;
    for (var i = 0; i < trace.length; i++) {
      final cents = trace[trace.length - 1 - i];
      final y = i * step;
      if (cents == null) {
        drawing = false;
        continue;
      }
      if (drawing) {
        path.lineTo(x(cents), y);
      } else {
        path.moveTo(x(cents), y);
        drawing = true;
      }
    }
    canvas.drawPath(path, pen);
    // Where it is now: a dot at the head of the line.
    if (trace.isNotEmpty && trace.last != null) {
      canvas.drawCircle(Offset(x(trace.last!), 0), 5, Paint()..color = line);
    }
  }

  @override
  bool shouldRepaint(_TracePainter old) =>
      old.trace.length != trace.length ||
      !_sameReadings(old.trace, trace) ||
      old.band != band;

  static bool _sameReadings(List<double?> a, List<double?> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
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
  const _BigNote({required this.pitchClass, required this.colour, this.octave});

  final int pitchClass;
  final Color colour;

  /// The octave played in, as written, set small beside the letter.
  final int? octave;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.displayLarge?.copyWith(
      fontSize: 96,
      fontWeight: FontWeight.w800,
      color: colour,
      height: 1.1,
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          NoteText.pitchClass(
            pitchClass,
            key: const ValueKey('tuner-note'),
            on: Theme.of(context).colorScheme.surface,
            style: style,
          ),
          if (octave != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14, left: 2),
              child: Text(
                '$octave',
                key: const ValueKey('tuner-octave'),
                style: style?.copyWith(
                  fontSize: 36,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The twelve notes as a keyboard: the naturals along the bottom, the
/// sharps and flats raised above, each between the two it sits between.
/// The target is filled in; the note being heard is outlined.
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

  static const _naturals = [0, 2, 4, 5, 7, 9, 11];

  /// The raised keys, by the natural each one follows.
  static const _raised = {0: 1, 2: 3, 5: 6, 7: 8, 9: 10};

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 6.0;
      final width = (constraints.maxWidth - gap * 6) / 7;
      return Column(
        children: [
          SizedBox(
            height: 52,
            child: Stack(
              children: [
                for (final (i, natural) in _naturals.indexed)
                  if (_raised[natural] case final note?)
                    Positioned(
                      // Centred on the line between the two naturals.
                      left: (i + 0.5) * (width + gap),
                      width: width,
                      top: 0,
                      bottom: 0,
                      child: _key(context, note),
                    ),
              ],
            ),
          ),
          const SizedBox(height: gap),
          SizedBox(
            height: 56,
            child: Row(
              children: [
                for (final (i, note) in _naturals.indexed) ...[
                  if (i > 0) const SizedBox(width: gap),
                  Expanded(child: _key(context, note)),
                ],
              ],
            ),
          ),
        ],
      );
    },
  );

  Widget _key(BuildContext context, int note) {
    final scheme = Theme.of(context).colorScheme;
    final chosen = target == note;
    final background = chosen ? scheme.primary : scheme.surfaceContainerHigh;
    return Semantics(
      key: ValueKey('note-$note'),
      button: true,
      selected: chosen,
      label: 'Play ${pitchClassName(note, separator: ' or ')}',
      excludeSemantics: true,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: heard != null && heard! % 12 == note
              ? BorderSide(color: scheme.tertiary, width: 3)
              : sounding == note && !chosen
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
                  on: background,
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    color: chosen ? scheme.onPrimary : scheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Which octave the reference notes are played in: an octave down, back
/// to where they start, an octave up. The middle says which octave it is.
class _OctaveButtons extends StatelessWidget {
  const _OctaveButtons({required this.octave, required this.onChanged});

  final int octave;
  final ValueChanged<int> onChanged;

  static const lowest = 2;
  static const highest = 5;
  static const usual = 4;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Tooltip(
          message: 'Lower octave',
          child: OutlinedButton(
            onPressed: octave > lowest ? () => onChanged(octave - 1) : null,
            child: const FittedBox(child: Text('−1 Octave')),
          ),
        ),
      ),
      const SizedBox(width: 6),
      Expanded(
        // Never greyed out: it says where the notes are, and takes them
        // back to the usual octave (middle C's) from anywhere else.
        child: FilledButton.tonal(
          key: const ValueKey('octave-default'),
          onPressed: () => onChanged(usual),
          child: FittedBox(
            child: Text(octave == usual ? 'Default' : 'Octave $octave'),
          ),
        ),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Tooltip(
          message: 'Higher octave',
          child: OutlinedButton(
            onPressed: octave < highest ? () => onChanged(octave + 1) : null,
            child: const FittedBox(child: Text('+1 Octave')),
          ),
        ),
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
