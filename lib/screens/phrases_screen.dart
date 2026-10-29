// Phrases: play something, keep the sound of it, hear it in every key.
//
// It records audio and plays audio back. It does not write the line down.
// The app can hear pitches well enough to transcribe a phrase, and doing
// that throws away the reason anybody wanted to keep it: the time feel,
// the articulation, the way the note was got to. What came back was a
// correct transcription of something that was not the point.
//
// So the phrase stays the recording, and taking it round the keys is a
// question about sound: the engine moves the pitch, and what you hear is
// still you playing.

import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../audio/practice_player.dart';
import '../audio/take_recorder.dart';
import '../audio/waveform.dart';
import '../music/key_order.dart';
import '../music/phrase.dart';
import '../music/recorded_take.dart' show TakeShift;
import '../practice/phrase_store.dart';
import '../settings/app_settings.dart';
import 'key_round.dart';
import 'scrub_bar.dart';
import 'tunes_page.dart' show SectionHeader;

class PhrasesScreen extends StatefulWidget {
  const PhrasesScreen({
    super.key,
    required this.phrases,
    required this.player,
    required this.settings,
    this.recorder,
  });

  final PhraseStore phrases;
  final PracticePlayer player;
  final AppSettings settings;

  /// Tests hand in their own: there is no microphone in a widget test,
  /// and none on the simulator either.
  final TakeRecorder? recorder;

  @override
  State<PhrasesScreen> createState() => _PhrasesScreenState();
}

class _PhrasesScreenState extends State<PhrasesScreen> {
  late final _recorder = widget.recorder ?? TakeRecorder();
  var _recording = false;
  String? _problem;

  /// The file being recorded to, since stopping only gives the length.
  String? _recordingTo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Phrases')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.phrases,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'Play something worth keeping and the app keeps the sound '
                  'of it, not a transcription. Then hear it in any key.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: FilledButton.icon(
                  key: const ValueKey('record-phrase'),
                  onPressed: _recording ? _stop : _start,
                  icon: Icon(_recording ? Icons.stop : Icons.mic),
                  label: Text(_recording ? 'Stop' : 'Record a Phrase'),
                  style: _recording
                      ? FilledButton.styleFrom(
                          backgroundColor: scheme.tertiary,
                          foregroundColor: scheme.onTertiary,
                        )
                      : null,
                ),
              ),
              if (_problem case final problem?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    problem,
                    key: const ValueKey('phrase-problem'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.error,
                    ),
                  ),
                ),
              if (widget.phrases.isEmpty && !_recording)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    'Nothing saved yet. Anything you play goes in here: four '
                    'bars that came out right, a lick off a record, a shape '
                    'you want in all twelve keys.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (widget.phrases.all.isNotEmpty) const SectionHeader('Yours'),
              for (final phrase in widget.phrases.all)
                ListTile(
                  key: ValueKey('phrase-${phrase.id}'),
                  leading: const Icon(Icons.graphic_eq),
                  title: Text(phrase.name),
                  subtitle: Text(
                    '${nameInKey(phrase.key, key: phrase.key)} · '
                    '${phrase.seconds.toStringAsFixed(1)} s',
                  ),
                  trailing: PopupMenuButton<void>(
                    key: ValueKey('more-${phrase.id}'),
                    icon: const Icon(Icons.more_horiz),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        key: ValueKey('rename-${phrase.id}'),
                        onTap: () => _rename(phrase),
                        child: const Text('Rename'),
                      ),
                      PopupMenuItem(
                        key: ValueKey('delete-${phrase.id}'),
                        onTap: () => _delete(phrase),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PhraseKeysScreen(
                        phrase: phrase,
                        phrases: widget.phrases,
                        player: widget.player,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Gives a phrase a name worth finding it by.
  ///
  /// They arrive called Phrase 1, which is the only name the app can give
  /// something it has not heard. A book of eleven of those is a book
  /// nobody opens.
  Future<void> _rename(Phrase phrase) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _RenameDialog(was: phrase.name),
    );
    // An empty name is not a name, and would leave a row with nothing in
    // it; backing out is a null and means the same thing here.
    if (name == null || name.trim().isEmpty) return;
    await widget.phrases.rename(phrase, name.trim());
  }

  /// Throws one away, asked first.
  ///
  /// It is a recording of somebody playing and there is no other copy of
  /// it, which is reason enough to ask even though the row is small.
  Future<void> _delete(Phrase phrase) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${phrase.name}?'),
        content: const Text(
          'The recording goes with it, and there is no other copy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep It'),
          ),
          TextButton(
            key: const ValueKey('really-delete'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (sure == true) await widget.phrases.remove(phrase);
  }

  Future<void> _start() async {
    setState(() => _problem = null);
    if (!await _recorder.hasPermission()) {
      if (!mounted) return;
      setState(
        () => _problem =
            'The app needs the microphone to record a phrase. It is in '
            'Settings on the phone, under The Changes.',
      );
      return;
    }
    final name = 'phrase-${DateTime.now().millisecondsSinceEpoch}.wav';
    final path = await widget.phrases.pathFor(name);
    if (path == null) {
      if (!mounted) return;
      setState(() => _problem = 'There is nowhere to record to.');
      return;
    }
    await _recorder.start(path);
    _recordingTo = name;
    if (!mounted) return;
    setState(() => _recording = true);
  }

  Future<void> _stop() async {
    final length = await _recorder.stop();
    final name = _recordingTo;
    _recordingTo = null;
    if (!mounted) return;
    setState(() => _recording = false);
    if (name == null) return;
    final key = await _askTheKey();
    if (key == null || !mounted) return;
    await widget.phrases.add(
      Phrase(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        name: 'Phrase ${widget.phrases.all.length + 1}',
        fileName: name,
        key: key,
        seconds: length.inMilliseconds / 1000,
      ),
    );
  }

  /// What key it was played in, which is the one thing the app cannot
  /// hear for itself well enough to be worth guessing.
  Future<int?> _askTheKey() => showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(
              'What key was that in?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'So the keys it is taken to are named from somewhere.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          for (var pitch = 0; pitch < 12; pitch++)
            ListTile(
              key: ValueKey('played-in-$pitch'),
              title: Text(nameInKey(pitch, key: pitch)),
              onTap: () => Navigator.of(context).pop(pitch),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// One phrase, round the twelve keys.
/// What the sound is doing.
///
/// Three states rather than a playing flag, because pausing and stopping
/// are different things to want: one keeps your place in the line and
/// the other gives it back to the point you chose.
enum _Doing { stopped, playing, paused }

/// Reading a recording down to the shape of it.
typedef DrawPhrase = Future<List<double>> Function(Uint8List wav);

/// Off the main thread: it walks every sample in the file, which is a
/// few hundred thousand of them, and doing that between frames is how a
/// screen arrives already stuttering.
Future<List<double>> _inItsOwnIsolate(Uint8List wav) =>
    Isolate.run(() => peaksOfWav(wav));

class PhraseKeysScreen extends StatefulWidget {
  const PhraseKeysScreen({
    super.key,
    required this.phrase,
    required this.phrases,
    required this.player,
    this.draw = _inItsOwnIsolate,
  });

  final Phrase phrase;
  final PhraseStore phrases;
  final PracticePlayer player;

  /// Taken rather than called directly so a test can hold it still: an
  /// isolate cannot be spawned from inside a widget test.
  final DrawPhrase draw;

  @override
  State<PhraseKeysScreen> createState() => _PhraseKeysScreenState();
}

class _PhraseKeysScreenState extends State<PhraseKeysScreen> {
  var _order = KeyOrder.fourths;
  late List<int> _moves = _order.moves();
  var _at = 0;
  final _done = <int>{};
  var _move = PhraseMove.inTime;

  /// Where in the recording the next play starts, which is also where a
  /// finished play comes back to. See [ScrubBar].
  var _from = Duration.zero;

  /// Where it has got to, while something is playing.
  Duration? _playingAt;

  /// What the sound is doing, which is what the three buttons are for.
  var _doing = _Doing.stopped;

  /// True between the finger going down on the bar and coming off it, so
  /// the ticker does not drag the thumb out from under the finger.
  var _dragging = false;

  Timer? _ticker;

  /// The recording drawn down to one level per column, once, when the
  /// screen opens. Empty until it is read, and empty for good if the
  /// file will not decode.
  var _peaks = const <double>[];

  @override
  void initState() {
    super.initState();
    unawaited(_draw());
    widget.player.snippetState.addListener(_heldElsewhere);
  }

  /// The Pause and Stop bar over every screen can hold or end this too,
  /// and this page's own buttons have to say so.
  void _heldElsewhere() {
    if (!mounted) return;
    final state = widget.player.snippetState.value;
    if (state == SnippetState.paused && _doing == _Doing.playing) {
      _ticker?.cancel();
      setState(() => _doing = _Doing.paused);
    } else if (state == SnippetState.playing && _doing == _Doing.paused) {
      setState(() => _doing = _Doing.playing);
      _follow(from: widget.player.snippetPosition());
    }
  }

  /// Reads the phrase and works out its shape.
  Future<void> _draw() async {
    final audio = await widget.phrases.audioOf(widget.phrase);
    if (audio == null || !mounted) return;
    final peaks = await widget.draw(audio);
    if (!mounted) return;
    setState(() => _peaks = peaks);
  }

  /// The recording's own length, which the phrase knows without anything
  /// having been played.
  Duration get _length =>
      Duration(milliseconds: (widget.phrase.seconds * 1000).round());

  @override
  void dispose() {
    _ticker?.cancel();
    widget.player.snippetState.removeListener(_heldElsewhere);
    unawaited(widget.player.stopSnippet());
    super.dispose();
  }

  int get move => _moves[_at];

  String _keyName(int by) =>
      nameInKey(widget.phrase.key + by, key: widget.phrase.key + by);

  Future<void> _hear() async {
    // Held, not stopped: carrying on means carrying on from the note it
    // was on rather than from wherever the bar was set.
    if (_doing == _Doing.paused) {
      await widget.player.resumeSnippet();
      if (!mounted) return;
      setState(() => _doing = _Doing.playing);
      _follow(from: _playingAt ?? _from);
      return;
    }
    final audio = await widget.phrases.audioOf(widget.phrase);
    if (audio == null) return;
    await widget.player.playSnippet(
      audio,
      shift: widget.phrase.shiftBy(_shiftOf(move), _move),
      from: _from,
    );
    if (!mounted) return;
    setState(() => _doing = _Doing.playing);
    _follow();
  }

  Future<void> _pause() async {
    _ticker?.cancel();
    await widget.player.pauseSnippet();
    if (!mounted) return;
    setState(() => _doing = _Doing.paused);
  }

  /// Stops, and puts the bar back to the point the play started from.
  ///
  /// Which is the difference between this and pausing: stopping is being
  /// finished with that hearing of it, and the next one begins where you
  /// chose rather than where you broke off.
  Future<void> _stop() async {
    _ticker?.cancel();
    await widget.player.stopSnippet();
    if (!mounted) return;
    setState(() {
      _doing = _Doing.stopped;
      _playingAt = null;
    });
  }

  /// Walks the thumb along while it plays, and puts it back to the point
  /// the play started from when the sound runs out.
  void _follow({Duration? from}) {
    _ticker?.cancel();
    if (!mounted) return;
    setState(() => _playingAt = from ?? _from);
    _ticker = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final at = widget.player.snippetPosition();
      if (at == null) {
        // Over. Back to where it started, so hearing the same four bars
        // again is one tap rather than a drag and a tap.
        timer.cancel();
        setState(() {
          _playingAt = null;
          _doing = _Doing.stopped;
        });
        return;
      }
      if (!_dragging) setState(() => _playingAt = at);
    });
  }

  /// Moving the thumb. The sound follows it where there is sound to
  /// follow, and where there is not this is simply choosing where the
  /// next play begins.
  void _scrubTo(Duration to) {
    setState(() {
      _dragging = true;
      _from = to;
      if (_playingAt != null) _playingAt = to;
    });
    unawaited(widget.player.seekSnippet(to));
  }

  void _scrubbed(Duration to) {
    setState(() {
      _dragging = false;
      _from = to;
    });
  }

  /// The shortest way to the key, so a phrase is never dragged up most of
  /// an octave to reach a key that was three semitones down.
  int _shiftOf(int by) => by > 6 ? by - 12 : by;

  void _goTo(int index) {
    setState(() {
      _done.add(move);
      _at = index % _moves.length;
    });
    _hear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shift = widget.phrase.shiftBy(_shiftOf(move), _move);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.phrase.name),
        actions: [
          KeyOrderButton(
            order: _order,
            onPick: (order) => setState(() {
              _order = order;
              _moves = order.moves(seed: DateTime.now().millisecond);
              _at = 0;
              _done.clear();
            }),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          _keyName(move),
                          key: const ValueKey('phrase-key'),
                          style: theme.textTheme.displaySmall,
                        ),
                      ),
                      Text(
                        '${_at + 1} of ${_moves.length}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ScrubBar(
                    at: _playingAt ?? _from,
                    length: _length,
                    peaks: _peaks,
                    onMoved: _scrubTo,
                    onSettled: _scrubbed,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          key: const ValueKey('hear-phrase'),
                          // Nothing to start while it is already going:
                          // the button for that is the one beside it.
                          onPressed: _doing == _Doing.playing ? null : _hear,
                          icon: const Icon(Icons.play_arrow),
                          label: Text(switch (_doing) {
                            _Doing.paused => 'Carry On',
                            _ when _from == Duration.zero => 'Hear It',
                            _ => 'Play From',
                          }),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        key: const ValueKey('pause-phrase'),
                        tooltip: 'Hold it there',
                        onPressed: _doing == _Doing.playing ? _pause : null,
                        icon: const Icon(Icons.pause),
                      ),
                      IconButton(
                        key: const ValueKey('stop-phrase'),
                        tooltip: 'Stop, and back to the point',
                        onPressed: _doing == _Doing.stopped ? null : _stop,
                        icon: const Icon(Icons.stop),
                      ),
                      if (_from > Duration.zero)
                        IconButton(
                          key: const ValueKey('scrub-to-start'),
                          tooltip: 'Back to the start',
                          onPressed: () => setState(() {
                            _from = Duration.zero;
                            if (_doing == _Doing.stopped) _playingAt = null;
                          }),
                          icon: const Icon(Icons.first_page),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<PhraseMove>(
                    key: const ValueKey('phrase-move'),
                    showSelectedIcon: false,
                    segments: [
                      for (final move in PhraseMove.values)
                        ButtonSegment(value: move, label: Text(move.label)),
                    ],
                    selected: {_move},
                    onSelectionChanged: (value) =>
                        setState(() => _move = value.first),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _about(shift),
                    key: const ValueKey('phrase-about'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: shift.worthSaying && _move == PhraseMove.inTime
                          ? scheme.error
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  KeyChips(
                    moves: _moves,
                    label: _keyName,
                    at: _at,
                    done: _done,
                    onPick: _goTo,
                  ),
                ],
              ),
            ),
            KeyStep(onBack: () => _goTo(_at - 1), onNext: () => _goTo(_at + 1)),
          ],
        ),
      ),
    );
  }

  /// What moving it this far is doing to the sound, said plainly.
  ///
  /// Worth saying because it is a real limit rather than a setting: a
  /// filter moving a recording half an octave is inventing a good deal of
  /// what you hear, and somebody deciding their playing sounds wrong
  /// should know it is the shifting.
  String _about(TakeShift shift) {
    if (_move == PhraseMove.likeTape) {
      final percent = shift.stretchPercent;
      if (percent.abs() < 1) return 'As you played it.';
      return percent > 0
          ? 'Up, and ${percent.round()}% faster, the way a tape speeds up.'
          : 'Down, and ${-percent.round()}% slower, the way a tape slows down.';
    }
    return switch (shift.strain) {
      _ when shift.cents.abs() < 50 => 'As you played it.',
      _ when shift.cents.abs() < 200 => 'Your playing, moved a little.',
      _ when shift.cents.abs() < 400 =>
        'A long way for a filter: it will start to sound processed.',
      _ => 'Very far. Like Tape will sound cleaner at this distance.',
    };
  }
}

/// Asking for a new name.
///
/// Its own widget so the field's controller lives exactly as long as the
/// dialog does. Disposing it as soon as the dialog returned was a use
/// after dispose: the dialog is still on screen while it animates away.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.was});

  final String was;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _field = TextEditingController(text: widget.was);

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Rename'),
    content: TextField(
      key: const ValueKey('phrase-name'),
      controller: _field,
      autofocus: true,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        labelText: 'Name',
        hintText: 'The one over the bridge',
      ),
      onSubmitted: (value) => Navigator.of(context).pop(value),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      TextButton(
        key: const ValueKey('keep-name'),
        onPressed: () => Navigator.of(context).pop(_field.text),
        child: const Text('Rename'),
      ),
    ],
  );
}
