// The stage: the chart and nothing else.
//
// A phone on a stand, read from a metre away, with an instrument in your
// hands. Everything you'd tap while working on a tune (the mixer, the
// arrangement, the loop, the transposition) is settled before you get
// here, so none of it is on screen. What's left is the chart, as big as
// the screen can draw it, and a way to start and stop.
//
// It plays the same band as the screen you came from: the same controller,
// so walking in and out of the stage doesn't interrupt anything.
//
// A tap anywhere on the chart starts or stops it, because reaching for a
// small button with a horn in your mouth is the thing this view is for.
// That's also why a tap here doesn't set a loop the way it does while
// you're practising: nobody wants to change what the band is playing by
// touching the screen to get it going.
//
// There are two of it. Stage View is the whole tune fitted to the screen.
// Scrolling Stage View is a few rows at a time, big, moving on as the band
// moves down the tune, so the line being played is near the top and what
// comes next is under it: a long chart fitted to a phone is too small to
// read from a stand, and nobody can scroll it with a horn in their hands.
//
// The scrolling one can follow a band that is not the app's: a record, or
// the band on the stand. It is told where they are rather than hearing
// it (see tap_follower.dart): the beat tapped along, the top of each
// chorus, a bar on the chart, by finger or by a page-turner pedal.
//
// Listening for itself is here too, in builds being worked on only
// (see chart_follower.dart). It follows iReal Pro's backing and not a
// real record, so nobody else is shown it until it does.

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/room_listener.dart';
import '../practice/chart_follower.dart';
import '../practice/practice_controller.dart';
import '../practice/tap_follower.dart';
import '../theme.dart';
import 'chord_chart.dart' show ChordChart, CountInBubble;
import 'play_shortcuts.dart';

class StageScreen extends StatefulWidget {
  const StageScreen({
    super.key,
    required this.controller,
    this.follow = false,
    this.listener,
    this.taps,
  });

  final PracticeController controller;

  /// The scrolling stage: a few big rows that move on with the band,
  /// rather than the whole tune fitted to the screen.
  final bool follow;

  /// The ear, for a test to hand in one that hears a track rather than
  /// the microphone. Made here otherwise, when Listen is first pressed.
  final RoomListener? listener;

  /// The count, for a test to hand in one on its own clock.
  final TapFollower? taps;

  @override
  State<StageScreen> createState() => _StageScreenState();
}

class _StageScreenState extends State<StageScreen> {
  PracticeController get controller => widget.controller;

  RoomListener? _ear;

  /// Following by taps, once it has been turned on.
  TapFollower? _taps;
  var _tapping = false;

  /// The ear says whether it is listening, so the screen and the
  /// microphone cannot disagree about it.
  bool get _listening => _ear?.listening ?? false;

  /// Below this the follower is guessing, and a guess marked on the chart
  /// looks exactly like knowing. Nothing is marked until it is surer.
  static const _sureEnough = 0.25;

  @override
  void dispose() {
    _ear?.dispose();
    if (widget.taps == null) _taps?.dispose();
    super.dispose();
  }

  Future<void> _toggleTapping() async {
    if (_tapping) {
      _taps?.stop();
      setState(() => _tapping = false);
      return;
    }
    // Following somebody else's band: the app's own would only be in the
    // way, and so would the ear.
    if (controller.isPlaying) await controller.stop();
    await _ear?.stop();
    _taps ??= widget.taps ?? TapFollower(tune: controller.tune);
    setState(() => _tapping = true);
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _ear?.stop();
      return;
    }
    // The band and the room at once would be the ear hearing the band.
    if (controller.isPlaying) await controller.stop();
    if (_tapping) await _toggleTapping();
    final ear = _ear ??= widget.listener ?? RoomListener(tune: controller.tune);
    // Rebuilt to listen to the ear, which did not exist until now.
    setState(() {});
    final started = await ear.start();
    if (!mounted) return;
    if (!started && ear.problem != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(ear.problem!)));
    }
  }

  /// Saves what the ear heard and what it made of it, for working out
  /// why it did not follow something. Debug builds only.
  Future<void> _saveWhatItHeard() async {
    final heard = _ear?.whatItHeard();
    if (heard == null) return;
    try {
      final wav = await FilePicker.platform.saveFile(
        dialogTitle: 'Save What the Ear Heard',
        fileName: '${heard.name}.wav',
        bytes: heard.wav,
      );
      if (wav == null) return;
      await FilePicker.platform.saveFile(
        dialogTitle: 'Save What It Made of It',
        fileName: '${heard.name}.txt',
        bytes: Uint8List.fromList(utf8.encode(heard.log)),
      );
    } catch (e) {
      debugPrint('Could not save what the ear heard: $e');
    }
  }

  Future<void> _togglePlay() async {
    // Starting the band stops the ear, for the same reason, even one
    // still coming on, and the count.
    await _ear?.stop();
    if (_tapping) await _toggleTapping();
    await controller.togglePlay();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, ?_ear, ?_taps]),
    // The spacebar as well as the whole chart. On a stand a metre away a
    // keyboard may be the only thing within reach.
    builder: (context, _) {
      final heard = _listening ? _ear?.position : null;
      final sure =
          heard != null && heard.hearsMusic && heard.confidence >= _sureEnough;
      final taps = _tapping ? _taps : null;
      final tapped = taps?.beat;
      // The beat marked: the count's, the ear's, or (with neither) the
      // band's own, which the chart reads for itself.
      final followed = taps != null
          ? tapped
          : sure
          ? heard.beat
          : null;
      final following = taps != null || _listening;
      final tempo = taps != null
          ? taps.tempo?.round()
          : _listening
          // A tempo it has not heard is a guess, like a bar it has not
          // heard: shown only once it is following.
          ? (sure ? heard.tempo.round() : null)
          : controller.currentTempo;
      return _Pedals(
        // Tapping, the spacebar and a page-turner's right pedal tap the
        // beat and its left pedal is the top of the chorus; otherwise the
        // spacebar starts and stops the band.
        onBeat: taps?.tapBeat,
        onTop: taps?.topOfChorus,
        child: PlayPauseShortcut(
          onPlayPause: taps != null ? taps.tapBeat : _togglePlay,
          child: Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: GestureDetector(
                      key: const ValueKey('stage-chart'),
                      behavior: HitTestBehavior.opaque,
                      onTap: following ? null : _togglePlay,
                      child: Stack(
                        children: [
                          ChordChart(
                            controller: controller,
                            stage: true,
                            follow: widget.follow,
                            heardBeat: followed,
                            onBarTapped: taps != null
                                ? taps.placeAtBar
                                : _listening
                                ? _ear!.placeAt
                                : null,
                          ),
                          if (controller.countInBeat != null)
                            CountInBubble(beat: controller.countInBeat!),
                        ],
                      ),
                    ),
                  ),
                  if (taps != null) _Tapping(taps: taps),
                  if (_listening)
                    _Hearing(
                      level: _ear!.level,
                      heard: heard,
                      sure: sure,
                      roomTempo: _ear!.roomTempo,
                      onTap: _ear!.tap,
                    ),
                  const Divider(height: 1),
                  _StageBar(
                    controller: controller,
                    onPlay: _togglePlay,
                    tapping: _tapping,
                    onTapping: widget.follow ? _toggleTapping : null,
                    listening: _listening,
                    // Listening for itself follows iReal Pro and not a real
                    // record, so it is only offered while it is worked on.
                    onListen: widget.follow && kDebugMode
                        ? _toggleListening
                        : null,
                    onSave:
                        kDebugMode && !_listening && (_ear?.hasKept ?? false)
                        ? _saveWhatItHeard
                        : null,
                    chord: following
                        ? (followed == null
                              ? null
                              : controller.chart
                                    .slotAtBeat(followed)
                                    .chord
                                    .display)
                        : controller.shownSlot.chord.display,
                    tempo: tempo,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// A page-turner pedal is a keyboard with two keys: which two depends on
/// the pedal (arrows, page up and down), so all of them are taken.
class _Pedals extends StatelessWidget {
  const _Pedals({
    required this.onBeat,
    required this.onTop,
    required this.child,
  });

  final VoidCallback? onBeat;
  final VoidCallback? onTop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final beat = onBeat;
    final top = onTop;
    if (beat == null || top == null) return child;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): beat,
        const SingleActivator(LogicalKeyboardKey.arrowDown): beat,
        const SingleActivator(LogicalKeyboardKey.pageDown): beat,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): top,
        const SingleActivator(LogicalKeyboardKey.arrowUp): top,
        const SingleActivator(LogicalKeyboardKey.pageUp): top,
      },
      child: child,
    );
  }
}

/// Following by taps: what to do next, and the two things it can be told.
class _Tapping extends StatelessWidget {
  const _Tapping({required this.taps});

  final TapFollower taps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tempo = taps.tempo;
    final text = taps.counting && tempo != null
        ? 'Counting at ${tempo.round()} BPM. Top of the Chorus at each '
              'chorus, or tap the bar the band is on.'
        : taps.taps > 0
        ? 'Keep tapping the beat.'
        : 'Count the band in on Tap the Beat, and bar 1 comes on the next '
              'beat. Already playing? Tap the beat, then the bar it is on. '
              'A page-turner pedal works too.';
    return Padding(
      key: const ValueKey('stage-tapping'),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              // Big, because they are hit with a thumb between phrases.
              Expanded(
                child: FilledButton(
                  key: const ValueKey('stage-tap-beat'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  onPressed: taps.tapBeat,
                  child: const Text('Tap the Beat'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('stage-top'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  onPressed: taps.topOfChorus,
                  child: const Text('Top of the Chorus'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// What the ear makes of the room, in a line: whether it can hear
/// anything, and whether it knows where it is.
class _Hearing extends StatelessWidget {
  const _Hearing({
    required this.level,
    required this.heard,
    required this.sure,
    required this.roomTempo,
    required this.onTap,
  });

  final double level;
  final FollowedPosition? heard;
  final bool sure;

  /// The tempo of a groove heard off the count, which says the chart's
  /// tempo is some way from the record's.
  final double? roomTempo;

  /// A tap on the beat, along with the music. Shown whenever it is
  /// listening: it is the quickest way to give it the tempo, and the one
  /// thing that settles a groove heard in two from one in four.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Each says what to do next, because the person reading it has an
    // instrument in their hands and no time to work it out.
    final text = sure
        ? 'Following the room. Tap a bar to put it right.'
        : roomTempo != null
        ? 'The beat in the room is not at the chart\'s tempo. Tap the '
              'beat along with it a few times.'
        : heard == null
        ? (level < 0.001
              ? 'Listening, but it is very quiet. Turn the music up, or '
                    'bring the device closer.'
              : 'Listening for the beat and the chords. Tap the bar it is '
                    'on if you know it, or tap the beat to hurry it.')
        : !heard!.hearsMusic
        ? 'Hearing sound, but no beat it can count. Tap the beat along '
              'with the music a few times.'
        : 'Not sure where in the tune we are. Tap the bar you are on.';
    return Padding(
      key: const ValueKey('stage-hearing'),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        children: [
          Icon(
            Icons.hearing,
            size: 18,
            color: sure
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            key: const ValueKey('stage-tap-tempo'),
            onPressed: onTap,
            child: const Text('Tap the Beat'),
          ),
        ],
      ),
    );
  }
}

/// The one strip of controls: what's playing, whether it's playing, and the
/// way out.
class _StageBar extends StatelessWidget {
  const _StageBar({
    required this.controller,
    required this.onPlay,
    required this.tapping,
    required this.onTapping,
    required this.listening,
    required this.onListen,
    required this.chord,
    required this.tempo,
    this.onSave,
  });

  /// Saving what the ear heard, in a build being worked on.
  final VoidCallback? onSave;

  final PracticeController controller;
  final VoidCallback onPlay;

  /// Following by taps, and the way to turn it on and off: null on the
  /// stage that does not scroll.
  final bool tapping;
  final VoidCallback? onTapping;
  final bool listening;

  /// Null on the stage that does not scroll, which has nothing to follow
  /// a room with.
  final VoidCallback? onListen;

  /// The chord being played, or null when the ear is not sure.
  final String? chord;
  final int? tempo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playing = controller.isPlaying && !controller.isPaused;
    final chord = this.chord;
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            IconButton.filled(
              key: const ValueKey('stage-play'),
              iconSize: 32,
              style: filledIconButton(theme.colorScheme),
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
              tooltip: playing ? 'Stop' : 'Play',
              onPressed: onPlay,
            ),
            if (onTapping != null) ...[
              const SizedBox(width: 4),
              IconButton(
                key: const ValueKey('stage-follow-taps'),
                iconSize: 28,
                isSelected: tapping,
                icon: const Icon(Icons.touch_app_outlined),
                selectedIcon: const Icon(Icons.touch_app),
                tooltip: tapping
                    ? 'Stop Following by Taps'
                    : 'Follow a Band by Taps',
                onPressed: onTapping,
              ),
            ],
            if (onListen != null) ...[
              const SizedBox(width: 4),
              IconButton(
                key: const ValueKey('stage-listen'),
                iconSize: 28,
                isSelected: listening,
                icon: const Icon(Icons.hearing_outlined),
                selectedIcon: const Icon(Icons.hearing),
                tooltip: listening ? 'Stop Listening' : 'Listen to the Room',
                onPressed: onListen,
              ),
            ],
            if (onSave != null)
              IconButton(
                key: const ValueKey('stage-save-heard'),
                icon: const Icon(Icons.save_alt),
                tooltip: 'Save What It Heard',
                onPressed: onSave,
              ),
            const SizedBox(width: 12),
            // The chart says where you are; this says what you're on, big
            // enough to catch out of the corner of an eye.
            Expanded(
              child: chord == null
                  ? const SizedBox()
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        handSymbol(chord),
                        semanticsLabel: chord,
                        style: handLettered(
                          TextStyle(
                            fontSize: 34,
                            height: 1,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
            ),
            if (tempo != null)
              Text(
                '$tempo BPM',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            IconButton(
              key: const ValueKey('stage-done'),
              icon: const Icon(Icons.close_fullscreen),
              tooltip: 'Leave the Stage',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
