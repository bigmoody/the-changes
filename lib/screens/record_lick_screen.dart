// Catching a lick: play it over some changes and the app writes it down.
//
// The hard part is not the recording, it is turning it into notes, and
// that is done in transcribe.dart where it can be tested against playing
// whose answer is known. What happens here is the arranging: choosing
// what to play it over, getting the band going and the microphone
// running at the same time, and then showing what was heard so it can be
// corrected before it is kept.
//
// Showing it matters. A transcription is a reading, and a reading can be
// wrong; a lick saved with a note the app misheard is worse than no lick,
// because it will be practised that way in twelve keys. So nothing is
// saved until somebody has looked at it.

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../audio/practice_player.dart';
import '../audio/transcribe.dart';
import '../audio/wav_file.dart';
import '../music/lick.dart';
import '../music/lick_contexts.dart';
import '../music/midi_file.dart';
import '../music/user_progression.dart';
import '../practice/lick_store.dart';
import '../practice/lick_tape.dart';
import '../practice/practice_controller.dart';
import '../settings/app_settings.dart';
import '../audio/backing_synth.dart';
import '../theme.dart';
import 'click_bar.dart';
import 'stave.dart';
import 'stave_figure.dart';
import 'transport.dart';

class RecordLickScreen extends StatefulWidget {
  const RecordLickScreen({
    super.key,
    required this.licks,
    required this.player,
    required this.settings,
    this.tape,
  });

  final LickStore licks;
  final PracticePlayer player;
  final AppSettings settings;

  /// Stood in for by the tests, which have no microphone.
  @visibleForTesting
  final LickTape? tape;

  @override
  State<RecordLickScreen> createState() => _RecordLickScreenState();
}

/// The dropdown's stand-in for no changes at all.
const _noChanges = 'none';

class _RecordLickScreenState extends State<RecordLickScreen> {
  late final _tape = widget.tape ?? DeviceLickTape();

  /// What it is being played over, or null for just a line with a click.
  late UserProgression? _over = lickContexts.first;
  late PracticeController? _controller = _controllerFor(_over);
  var _tempo = 120;
  var _clicking = false;
  final _name = TextEditingController();

  var _recording = false;
  String? _problem;
  List<PlayedNote> _heard = const [];
  List<MidiNote> _notes = const [];
  NoteGrid _grid = NoteGrid.swungEighths;
  double _startSeconds = 0;
  double _nudge = 0;

  PracticeController? _controllerFor(UserProgression? over) => over == null
      ? null
      : PracticeController(
          tune: over.toTune(),
          player: widget.player,
          settings: widget.settings,
        );

  /// The tempo being played at, whether the band or the click is giving
  /// it. Everything that turns playing into notes needs this one number.
  int get _playingAt => _controller?.tempo ?? _tempo;

  int get _beatsPerBar => _over?.beatsPerBar ?? 4;

  /// Something for the builder to listen to when there is no band.
  static final _still = ValueNotifier<int>(0);

  @override
  void dispose() {
    _name.dispose();
    if (_clicking) widget.player.stopLoop();
    _controller?.dispose();
    super.dispose();
  }

  void _setContext(UserProgression? over) {
    final old = _controller;
    old?.stop();
    setState(() {
      _over = over;
      _controller = _controllerFor(over);
      _heard = const [];
      _notes = const [];
      _nudge = 0;
    });
    old?.dispose();
  }

  Future<void> _setTempo(int by) async {
    setState(() => _tempo = (_tempo + by).clamp(40, 320));
    if (_clicking) {
      await widget.player.playLoop(
        metronomeLoop(tempo: _tempo, beatsPerBar: _beatsPerBar),
      );
    }
  }

  Future<void> _toggleClick() async {
    if (_clicking) {
      await widget.player.stopLoop();
      if (mounted) setState(() => _clicking = false);
      return;
    }
    await widget.player.playLoop(
      metronomeLoop(tempo: _tempo, beatsPerBar: _beatsPerBar),
    );
    if (mounted) setState(() => _clicking = true);
  }

  /// Starts the microphone, then the band, and remembers how long the gap
  /// between them was.
  ///
  /// The band has to be written before it can play, which takes a moment,
  /// and the microphone is running all the while. That wait, plus the
  /// count-in, is where bar 1 actually falls in the recording, and
  /// getting it wrong puts every note over the wrong chord.
  Future<void> _record() async {
    setState(() => _problem = null);
    try {
      if (!await _tape.hasPermission()) {
        if (mounted) {
          setState(
            () => _problem =
                'The app needs the microphone to hear '
                'what you play.',
          );
        }
        return;
      }
      final waiting = Stopwatch()..start();
      await _tape.start();
      if (!mounted) return;
      setState(() => _recording = true);
      if (_controller case final controller?) {
        await controller.play();
        final countIn = controller.countIn
            ? _beatsPerBar * 60 / controller.tempo
            : 0.0;
        _startSeconds = waiting.elapsedMilliseconds / 1000 + countIn;
      } else {
        // Just a click. There is no bar 1 to come in on, so where the
        // line sits is decided afterwards, from where it actually began.
        if (!_clicking) await _toggleClick();
        _startSeconds = 0;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _recording = false;
          _problem = 'Could not start recording: $e';
        });
      }
    }
  }

  Future<void> _stop() async {
    await _controller?.stop();
    Uint8List? bytes;
    try {
      bytes = await _tape.stop();
    } catch (e) {
      if (mounted) setState(() => _problem = 'Could not stop recording: $e');
    }
    if (!mounted) return;
    setState(() => _recording = false);
    if (bytes == null) {
      setState(() => _problem = 'Nothing was recorded.');
      return;
    }
    _read(bytes);
  }

  void _read(Uint8List bytes) {
    try {
      final heard = hearNotes(readWav(bytes));
      // Without changes there is nothing to be late or early against, so
      // the line simply starts where it starts: its first note is beat
      // one and the rest is measured from there.
      if (_over == null && heard.isNotEmpty) _startSeconds = heard.first.at;
      final grid = bestGrid(
        heard,
        bpm: _playingAt.toDouble(),
        startSeconds: _startSeconds,
      );
      setState(() {
        _heard = heard;
        _grid = grid;
        _nudge = 0;
        _problem = heard.isEmpty
            ? 'Nothing was heard. Play a single line, near the microphone, '
                  'and try again.'
            : null;
      });
      _place();
    } on WavFormatException catch (e) {
      setState(() => _problem = e.message);
    } catch (e) {
      setState(() => _problem = 'That recording could not be read: $e');
    }
  }

  /// Puts what was heard on the grid, moved by however far the line has
  /// been nudged.
  ///
  /// Worked out again on every change rather than kept, so what is drawn
  /// is always what would be saved. The nudge moves the line, so nudging
  /// it later puts the notes later against the chords; taking the start
  /// of the recording earlier is the same thing said backwards and is
  /// not how anybody looking at a stave thinks about it.
  void _place() {
    setState(() {
      _notes = onTheGrid(
        _heard,
        bpm: _playingAt.toDouble(),
        grid: _grid,
        startSeconds: _startSeconds - _nudge * 60 / _playingAt,
      );
    });
  }

  Future<void> _save() async {
    if (_notes.isEmpty) return;
    final id = widget.licks.newId();
    await widget.licks.add(
      Lick(
        id: id,
        name: _name.text.trim().isEmpty
            ? (_over?.title ?? 'Just a line')
            : _name.text.trim(),
        // Its own copy, so editing the changes later does not change what
        // the lick is about.
        over: _over == null ? null : UserProgression.fromJson(_over!.toJson()),
        beatsPerBar: _beatsPerBar,
        tempo: _playingAt,
        notes: _notes,
        at: DateTime.now(),
        grid: _grid,
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller ?? _still,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Record a Lick')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                children: [
                  Text('Over', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('lick-context'),
                    initialValue: _over?.id ?? _noChanges,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final one in lickContexts)
                        DropdownMenuItem(
                          value: one.id,
                          child: Text(
                            '${one.title}  ·  ${one.bars.join(' | ')}',
                          ),
                        ),
                      const DropdownMenuItem(
                        value: _noChanges,
                        child: Text('Nothing, just a click'),
                      ),
                    ],
                    onChanged: (id) => _setContext(
                      id == _noChanges
                          ? null
                          : lickContexts.firstWhere((one) => one.id == id),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey('lick-record'),
                      icon: Icon(
                        _recording ? Icons.stop : Icons.fiber_manual_record,
                      ),
                      label: Text(
                        _recording ? 'Stop and Write It Down' : 'Record',
                      ),
                      onPressed: _recording ? _stop : _record,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _recording
                        ? 'Play your line. It is going round until you '
                              'stop it.'
                        : _over == null
                        ? 'A click, and nothing else. Play a line and the '
                              'app writes it down; without a band in the '
                              'room it hears you more clearly.'
                        : 'The band plays these changes and the app '
                              'listens. One line at a time: it hears a '
                              'melody, not chords.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (_problem case final problem?) ...[
                    const SizedBox(height: 12),
                    Text(
                      problem,
                      key: const ValueKey('lick-problem'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.error,
                      ),
                    ),
                  ],
                  if (_notes.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text('What it heard', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 6),
                    _Heard(notes: _notes, over: _over),
                    const SizedBox(height: 10),
                    _Fixes(
                      grid: _grid,
                      nudge: _nudge,
                      movable: _over != null,
                      onGrid: (grid) {
                        setState(() => _grid = grid);
                        _place();
                      },
                      onNudge: (by) {
                        setState(() => _nudge += by);
                        _place();
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      key: const ValueKey('lick-name'),
                      controller: _name,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        hintText: _over?.title ?? 'Just a line',
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const ValueKey('lick-save'),
                        onPressed: _save,
                        child: Text(
                          'Save These '
                          '${_notes.length} Notes',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_controller case final controller?)
              Transport(controller: controller)
            else
              ClickBar(
                tempo: _tempo,
                clicking: _clicking,
                onNudge: _setTempo,
                onToggle: _toggleClick,
              ),
          ],
        ),
      ),
    );
  }
}

/// The line as it was heard, over the changes it was played on.
class _Heard extends StatelessWidget {
  const _Heard({required this.notes, required this.over});

  final List<MidiNote> notes;

  /// The changes under it, if there are any.
  final UserProgression? over;

  @override
  Widget build(BuildContext context) {
    final tune = over?.toTune();
    // With no changes there is no key to spell by, so the line is
    // spelled by the note it starts on, which is what it is known by.
    final key =
        tune?.keyPitchClass ?? (notes.isEmpty ? 0 : notes.first.pitch % 12);
    final placed = lineOnStave([
      for (final note in notes)
        (pitch: note.pitch, name: nameInKey(note.pitch, key: key)),
    ]);
    const accidentals = {
      -2: Smufl.doubleFlat,
      -1: Smufl.flat,
      1: Smufl.sharp,
      2: Smufl.doubleSharp,
    };
    String? chordAt(double beat) {
      if (tune == null) return null;
      String? found;
      for (final slot in tune.slots) {
        if (slot.startBeat <= beat) found = slot.chord.display;
      }
      return found;
    }

    final columns = <StaveColumn>[];
    String? last;
    for (final (i, head) in placed.indexed) {
      if (accidentals[head.accidental] case final glyph?) {
        columns.add(
          StaveColumn.one(glyph, step: head.step.toDouble(), gap: 0.2),
        );
      }
      final chord = chordAt(notes[i].beat);
      columns.add(
        StaveColumn.one(
          Smufl.noteheadBlack,
          step: head.step.toDouble(),
          ledgers: true,
          over: chord != null && chord != last ? handSymbol(chord) : null,
          gap: 1.5,
        ),
      );
      if (chord != null) last = chord;
    }
    return SizedBox(
      height: 120,
      child: StaveFigure(
        key: const ValueKey('heard-line'),
        columns: columns,
        space: 9,
        semanticsLabel: 'The line the app heard',
      ),
    );
  }
}

/// The two things a reading gets wrong: the rhythm it was read on, and
/// where the line was taken to start.
class _Fixes extends StatelessWidget {
  const _Fixes({
    required this.grid,
    required this.nudge,
    required this.movable,
    required this.onGrid,
    required this.onNudge,
  });

  final NoteGrid grid;
  final double nudge;

  /// Whether moving the line means anything. Without changes under it
  /// there is nothing for it to sit wrongly against, so it starts where
  /// it starts and there is nothing to decide.
  final bool movable;
  final ValueChanged<NoteGrid> onGrid;
  final ValueChanged<double> onNudge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: DropdownButtonFormField<NoteGrid>(
            key: const ValueKey('lick-grid'),
            initialValue: grid,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Written as',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              for (final one in NoteGrid.values)
                DropdownMenuItem(value: one, child: Text(one.label)),
            ],
            onChanged: (value) => onGrid(value ?? grid),
          ),
        ),
        if (!movable) const SizedBox.shrink() else const SizedBox(height: 8),
        if (movable)
          Row(
            children: [
              SizedBox(
                width: 96,
                child: Text('The line', style: theme.textTheme.titleSmall),
              ),
              Expanded(
                child: Text(
                  nudge == 0
                      ? 'Where it was played'
                      : '${nudge.abs() == 1 ? '1 beat' : '${_plain(nudge.abs())} beats'} '
                            '${nudge < 0 ? 'earlier' : 'later'}',
                  key: const ValueKey('lick-nudge'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              IconButton.outlined(
                key: const ValueKey('lick-earlier'),
                icon: const Icon(Icons.chevron_left, size: 18),
                tooltip: 'A beat earlier',
                visualDensity: VisualDensity.compact,
                onPressed: () => onNudge(-1),
              ),
              const SizedBox(width: 4),
              IconButton.outlined(
                key: const ValueKey('lick-later'),
                icon: const Icon(Icons.chevron_right, size: 18),
                tooltip: 'A beat later',
                visualDensity: VisualDensity.compact,
                onPressed: () => onNudge(1),
              ),
            ],
          ),
        if (movable) const SizedBox(height: 4),
        if (movable)
          Text(
            'Move the line if the notes are sitting over the wrong chords. '
            'The app times the gap between starting the microphone and the '
            'band, but it can be a fraction out.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  static String _plain(double value) =>
      value == value.roundToDouble() ? '${value.round()}' : '$value';
}
