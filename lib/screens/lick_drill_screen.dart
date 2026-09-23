// Playing one lick in all twelve keys.
//
// A phrase you can only play in one key is a phrase you have memorised.
// The way anybody turns one into something they own is to take it round
// the keys with the changes underneath it, which is dull to set up by
// hand and takes about four seconds here.
//
// The stave fills in as you play. That is better feedback than a mark at
// the end, because the useful information is not how many you got but
// exactly where you stopped: everyone can play the first four notes.
//
// The band plays the changes the lick was written over, moved to the same
// key as the line, and both are worked out from one number so they cannot
// come apart.
//
// Headphones are worth a word on screen. The microphone hears the band as
// well as you, and while spotting one known note in that is a far smaller
// job than writing the whole phrase down, it is still easier without a
// speaker playing chords into it.

import 'package:flutter/material.dart';

import '../audio/lick_sound.dart';
import '../audio/practice_player.dart';
import '../audio/tuner_listener.dart';
import '../music/lick.dart';
import '../music/midi_file.dart';
import '../music/tune.dart';
import '../audio/backing_synth.dart';
import '../music/tuning.dart';
import '../practice/practice_controller.dart';
import '../settings/app_settings.dart';
import '../theme.dart';
import 'click_bar.dart';
import 'key_round.dart';
import 'stave.dart';
import 'stave_figure.dart';
import 'transport.dart';

class LickDrillScreen extends StatefulWidget {
  const LickDrillScreen({
    super.key,
    required this.lick,
    required this.player,
    required this.settings,
    this.listener,
  });

  final Lick lick;
  final PracticePlayer player;
  final AppSettings settings;

  /// Stood in for by the tests, which have no microphone.
  @visibleForTesting
  final TunerListener? listener;

  @override
  State<LickDrillScreen> createState() => _LickDrillScreenState();
}

class _LickDrillScreenState extends State<LickDrillScreen> {
  /// The band, when there are changes for it to play. A lick saved as
  /// just a line has none, and gets a click instead.
  late final PracticeController? _controller = widget.lick.over == null
      ? null
      : PracticeController(
          tune: widget.lick.over!.toTune(),
          player: widget.player,
          settings: widget.settings,
        );
  late final _listener = widget.listener ?? TunerListener();

  var _order = KeyOrder.fourths;
  late List<int> _moves = _order.moves();
  var _at = 0;
  late LickFollower _follower = _followerFor(0);

  /// Which keys have been played all the way through.
  final _done = <int>{};
  var _listening = false;
  String? _problem;

  Lick get lick => widget.lick;

  /// How far the line is from where it was played, for this key.
  int get move => _moves[_at];

  /// The line as the player reads it: moved to this key, and then again
  /// for whatever instrument they are on, exactly as the chart is.
  List<MidiNote> get _written =>
      lick.notesUp(move + widget.settings.instrument.semitones);

  /// The key the line is written in, which for a B flat instrument is
  /// not the key the band is playing in.
  int get _writtenKey =>
      (lick.key + move + widget.settings.instrument.semitones) % 12;

  /// What this time round is called.
  ///
  /// With changes, the key, spelled as the changes are spelled. Without
  /// them there is no key to name, so it is the note the line starts on,
  /// which is what anybody would call it: not "in E flat" but "starting
  /// on E flat".
  String _keyName(int by) {
    final moved = by + widget.settings.instrument.semitones;
    final over = lick.over;
    if (over != null) return over.toTune().keyLabelBy(moved);
    final pitch = lick.key + moved;
    return nameInKey(pitch, key: pitch);
  }

  LickFollower _followerFor(int index) =>
      LickFollower(lick.notesUp(_moves[index]));

  /// The chord over each note, as the player reads it.
  ///
  /// Taken from the transposed tune rather than spelled here, so the
  /// symbols over the line are the ones the app would print anywhere
  /// else: a B flat player in the key of D sees D, not C. Empty when the
  /// lick is just a line.
  List<String?> get _chordNames {
    final slots = lick
        .tuneUp(move + widget.settings.instrument.semitones)
        ?.slots;
    if (slots == null) return [for (final _ in lick.notes) null];
    return [
      for (final note in lick.notes)
        () {
          String? found;
          for (final slot in slots) {
            if (slot.startBeat <= note.beat) found = slot.chord.display;
          }
          return found;
        }(),
    ];
  }

  /// Something for the builder to listen to when there is no band.
  static final _still = ValueNotifier<int>(0);

  /// The click, for a lick with no changes under it.
  var _clicking = false;

  late int _tempo = widget.lick.tempo;

  @override
  void initState() {
    super.initState();
    _controller?.transpose(move);
  }

  @override
  void dispose() {
    _listener.stop();
    if (widget.listener == null) _listener.dispose();
    if (_clicking) widget.player.stopLoop();
    _controller?.dispose();
    super.dispose();
  }

  /// Plays the lick as it stands in this key.
  ///
  /// At concert pitch, like everything the app sounds: the stave is
  /// moved for whatever instrument you read, the speaker is not.
  Future<void> _hearIt() async {
    final wav = lickSnippet(
      lick,
      widget.player.samples,
      semitones: move,
      tempo: _controller?.tempo ?? _tempo,
      guitar: widget.settings.arpeggioSound == Comping.guitar,
    );
    if (wav == null) {
      setState(
        () => _problem =
            'The instruments are still loading. Try again in '
            'a moment.',
      );
      return;
    }
    setState(() => _problem = null);
    await widget.player.playSnippet(wav);
  }

  Future<void> _toggleClick() async {
    if (_clicking) {
      await widget.player.stopLoop();
      if (mounted) setState(() => _clicking = false);
      return;
    }
    await widget.player.playLoop(
      metronomeLoop(tempo: _tempo, beatsPerBar: lick.beatsPerBar),
    );
    if (mounted) setState(() => _clicking = true);
  }

  Future<void> _setTempo(int by) async {
    setState(() => _tempo = (_tempo + by).clamp(40, 320));
    if (_clicking) {
      await widget.player.playLoop(
        metronomeLoop(tempo: _tempo, beatsPerBar: lick.beatsPerBar),
      );
    }
  }

  Future<void> _listen() async {
    if (_listening) return;
    try {
      if (!await _listener.hasPermission()) {
        if (mounted) {
          setState(
            () => _problem =
                'The app needs the microphone to follow '
                'you through the lick. Playing works without it.',
          );
        }
        return;
      }
      await _listener.start(_onHeard, alongsideMusic: true);
      if (mounted) setState(() => _listening = true);
    } catch (e) {
      if (mounted) setState(() => _problem = 'Could not listen: $e');
    }
  }

  void _onHeard(Heard heard) {
    // The microphone hears concert pitch, and the lick is held at concert
    // pitch too, so nothing is transposed here. The transposing happens
    // where the line is written, and nowhere else.
    final moved = _follower.heard(heard == null ? null : hzToMidi(heard.hz));
    if (!moved) return;
    setState(() {});
    if (_follower.done) _done.add(move);
  }

  Future<void> _goTo(int index) async {
    setState(() {
      _at = index % _moves.length;
      _follower = _followerFor(_at);
      _problem = null;
    });
    _controller?.transpose(move);
  }

  void _setOrder(KeyOrder order) {
    setState(() {
      _order = order;
      _moves = order.moves(seed: DateTime.now().millisecond);
      _at = 0;
      _done.clear();
      _follower = _followerFor(0);
    });
    _controller?.transpose(move);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    // A lick with no changes has no band to listen to, so the screen
    // rebuilds on its own account instead.
    listenable: _controller ?? _still,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(lick.name),
        actions: [KeyOrderButton(order: _order, onPick: _setOrder)],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                children: [
                  _Heading(
                    keyName: _keyName(move),
                    at: _at,
                    of: _moves.length,
                    done: _done.length,
                  ),
                  const SizedBox(height: 12),
                  _TheLine(
                    notes: _written,
                    got: _follower.got,
                    chords: _chordNames,
                    writtenKey: _writtenKey,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const ValueKey('hear-it'),
                      icon: const Icon(Icons.volume_up_outlined),
                      label: const Text('Hear It in This Key'),
                      onPressed: _hearIt,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Progress(
                    follower: _follower,
                    listening: _listening,
                    onListen: _listen,
                  ),
                  if (_problem case final problem?) ...[
                    const SizedBox(height: 8),
                    Text(
                      problem,
                      key: const ValueKey('drill-problem'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
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

/// Which key this is, and how far round the twelve.
class _Heading extends StatelessWidget {
  const _Heading({
    required this.keyName,
    required this.at,
    required this.of,
    required this.done,
  });

  final String keyName;
  final int at;
  final int of;
  final int done;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            'Key of $keyName',
            key: const ValueKey('drill-key'),
            style: theme.textTheme.titleLarge,
          ),
        ),
        Text(
          '${at + 1} of $of · $done played',
          key: const ValueKey('drill-progress'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// The line, with the changes over it, filling in as it is played.
class _TheLine extends StatelessWidget {
  const _TheLine({
    required this.notes,
    required this.got,
    required this.chords,
    required this.writtenKey,
  });

  final List<MidiNote> notes;
  final List<bool> got;
  final List<String?> chords;
  final int writtenKey;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return const Text('This lick has no notes in it.');
    }
    final placed = lineOnStave([
      for (final note in notes)
        (pitch: note.pitch, name: nameInKey(note.pitch, key: writtenKey)),
    ]);
    const accidentals = {
      -2: Smufl.doubleFlat,
      -1: Smufl.flat,
      1: Smufl.sharp,
      2: Smufl.doubleSharp,
    };
    final columns = <StaveColumn>[];
    String? lastChord;
    for (final (i, head) in placed.indexed) {
      if (accidentals[head.accidental] case final glyph?) {
        columns.add(
          StaveColumn.one(glyph, step: head.step.toDouble(), gap: 0.2),
        );
      }
      final chord = i < chords.length ? chords[i] : null;
      columns.add(
        StaveColumn.one(
          Smufl.noteheadBlack,
          step: head.step.toDouble(),
          ledgers: true,
          // Filled in as you play it: the point is to see where you
          // stopped, not to be told a number afterwards.
          marked: i < got.length && got[i],
          over: chord != null && chord != lastChord ? handSymbol(chord) : null,
          gap: 1.6,
        ),
      );
      if (chord != null) lastChord = chord;
    }
    return SizedBox(
      height: 120,
      child: StaveFigure(
        key: const ValueKey('drill-line'),
        columns: columns,
        clef: Clef.treble,
        space: 9,
        semanticsLabel: 'The lick in this key',
      ),
    );
  }
}

/// How far through the lick this run has got.
class _Progress extends StatelessWidget {
  const _Progress({
    required this.follower,
    required this.listening,
    required this.onListen,
  });

  final LickFollower follower;
  final bool listening;
  final VoidCallback onListen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (!listening) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('follow-me'),
              icon: const Icon(Icons.hearing),
              label: const Text('Follow Me Through It'),
              onPressed: onListen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'The app listens and fills the line in as you play it. '
            'Headphones help: the microphone hears the band too.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(
            key: const ValueKey('drill-bar'),
            value: follower.length == 0 ? 0 : follower.at / follower.length,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          follower.done ? 'All of it' : '${follower.at} of ${follower.length}',
          key: const ValueKey('drill-got'),
          style: theme.textTheme.titleSmall?.copyWith(
            color: follower.done ? scheme.tertiary : null,
          ),
        ),
      ],
    );
  }
}
