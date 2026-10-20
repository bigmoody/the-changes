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
//
// So is hearing another app on an iPhone (see other_apps.dart): only the
// proof that a record playing in YouTube or Spotify reaches the app, with
// a meter and the format it arrives in.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/other_apps.dart';
import '../audio/room_listener.dart';
import '../practice/chart_follower.dart';
import '../practice/form_finder.dart';
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
    this.otherApps,
    this.hearOthers = false,
  });

  final PracticeController controller;

  /// Whether to start hearing other apps as soon as the stage opens: it
  /// was opened for that, from the tune's own page.
  final bool hearOthers;

  /// The scrolling stage: a few big rows that move on with the band,
  /// rather than the whole tune fitted to the screen.
  final bool follow;

  /// The ear, for a test to hand in one that hears a track rather than
  /// the microphone. Made here otherwise, when Listen is first pressed.
  final RoomListener? listener;

  /// The count, for a test to hand in one on its own clock.
  final TapFollower? taps;

  /// What another app is playing, for a test to hand in one that answers
  /// as the phone. Made here otherwise, when it is first asked for.
  final OtherAppsSound? otherApps;

  @override
  State<StageScreen> createState() => _StageScreenState();
}

class _StageScreenState extends State<StageScreen> {
  PracticeController get controller => widget.controller;

  RoomListener? _ear;

  /// Following by taps, once it has been turned on.
  TapFollower? _taps;
  var _tapping = false;

  /// Where in the tune the band is, by ear, while following another app.
  FormFinder? _form;

  /// Whether the ear has moved the count to the bar it heard.
  var _placedByEar = false;

  /// The ear says whether it is listening, so the screen and the
  /// microphone cannot disagree about it.
  bool get _listening => _ear?.listening ?? false;

  /// Hearing other apps, once it has been asked for.
  OtherAppsSound? _otherApps;
  var _hearingOthers = false;

  /// Only an iPhone or iPad can, and only a build being worked on has
  /// the extension that does it.
  bool get _canHearOthers =>
      widget.follow &&
      kDebugMode &&
      (widget.otherApps != null || defaultTargetPlatform == TargetPlatform.iOS);

  /// Below this the follower is guessing, and a guess marked on the chart
  /// looks exactly like knowing. Nothing is marked until it is surer.
  static const _sureEnough = 0.25;

  @override
  void initState() {
    super.initState();
    if (widget.hearOthers && _canHearOthers) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hearingOthers) _toggleHearingOthers();
      });
    }
  }

  @override
  void dispose() {
    _ear?.dispose();
    if (widget.taps == null) _taps?.dispose();
    if (widget.otherApps == null) {
      _otherApps?.dispose();
    } else {
      _otherApps?.stopReading();
    }
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
    _keepTapsWithOthers();
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

  /// Hearing another app follows it too: the count, started by its
  /// barlines or by taps, and nudged by Beat This! from then on.
  Future<void> _toggleHearingOthers() async {
    final others = _otherApps ??= widget.otherApps ?? OtherAppsSound();
    if (_hearingOthers) {
      others
        ..stopReading()
        ..onBarline = null
        ..onBeats = null
        ..onChords = null
        ..onBar = null;
      _taps
        ?..onRecounted = null
        ..onHalved = null
        ..onChords = null;
      unawaited(others.stopFollowing());
      _form?.clear();
      setState(() {
        _hearingOthers = false;
        _placedByEar = false;
      });
      _keepTapsWithOthers();
      // The count goes with it: where other apps can be heard there is
      // nothing else to turn it off with (see the stage bar).
      if (_tapping) await _toggleTapping();
      return;
    }
    others
      ..startReading()
      // Only while following by taps: turned off, the count stays off.
      ..onBarline = (ago) {
        final taps = _tapping ? _taps : null;
        if (taps == null) return;
        final was = taps.counting;
        taps.heardBarline(ago);
        if (!was && taps.counting) {
          others.noted('COUNT STARTED AT ${taps.tempo!.round()} BPM');
        }
      }
      ..onBeats = (beats) {
        if (_tapping) _taps?.heardBeats(beats);
      }
      ..onChords = (ago, bar, tempo) {
        if (_tapping) _taps?.heardChords(ago, bar, tempo);
      }
      ..tune = controller.tune
      ..onBar = _heardBar;
    setState(() => _hearingOthers = true);
    if (!_tapping) await _toggleTapping();
    _taps
      ?..onRecounted = _recounted
      ..onHalved = (() => others.noted('COUNT HALVED ITSELF'))
      ..onChords = () {
        final taps = _taps!;
        others.noted(
          'CHORDS: ${taps.tempo!.round()} BPM, '
          'BAR ${taps.barAt(taps.now)! + 1}',
        );
        _form?.clear();
        setState(() => _placedByEar = true);
      };
    _keepTapsWithOthers();
    await others.follow();
  }

  /// A bar heard whole: put with the others, and the count moved to the
  /// bar of the tune they say the band is in, unless a bar was tapped.
  void _heardBar(Duration ago, List<double> pitches) {
    final taps = _taps;
    if (!_tapping || taps == null) return;
    final form = _form ??= FormFinder(tune: controller.tune);
    form.heard(taps.now - ago, pitches);
    _noteShown(taps);
    if (taps.placedByHand ||
        !taps.counting ||
        taps.losesTheBars ||
        taps.byChords) {
      return;
    }
    final move = form.shift(taps.barAt);
    if (move == null) return;
    if (move == 0) {
      taps.placeHeard();
    } else {
      taps.moveBars(move);
    }
    _otherApps?.noted(
      move == 0 ? 'EAR SURE OF THE BAR' : 'EAR MOVED THE COUNT $move BARS',
    );
    setState(() => _placedByEar = true);
  }

  /// For the log, what the count shows now, once a bar heard: the tempo,
  /// and the bar of the tune, or that it does not know it.
  void _noteShown(TapFollower taps) {
    if (!taps.counting) return;
    final bar = taps.barAt(taps.now);
    _otherApps?.noted(
      'SHOWING ${taps.tempo!.round()} BPM, '
      '${taps.losesTheBars
          ? 'NOT HEARING THE BARS'
          : taps.placeKnown && bar != null
          ? 'BAR ${bar + 1}'
          : 'NO BAR'}',
    );
  }

  /// The count's bars moved (Half Time, a new tempo tapped, or beat 1
  /// heard elsewhere): the bars heard so far were put in the old ones, and
  /// are put in the new.
  void _recounted() {
    _otherApps?.noted('COUNT MOVED ITS BARS, NOW ${_taps?.tempo?.round()} BPM');
    _form?.recount();
    setState(() => _placedByEar = false);
  }

  /// Taps made while hearing another app are kept with what it heard,
  /// whichever is being tapped: the count or the ear.
  void _keepTapsWithOthers() {
    _taps?.onTapped = _hearingOthers ? _otherApps?.tapped : null;
  }

  void _tapTheEar() {
    if (_hearingOthers) _otherApps?.tapped(null);
    _ear?.tap();
  }

  void _placeTheEar(int bar) {
    if (_hearingOthers) _otherApps?.tapped(bar);
    _ear?.placeAt(bar);
  }

  /// Saves the last minute the broadcast heard, and the taps made
  /// along with it, for running through a beat tracker on a computer.
  /// Debug builds only.
  Future<void> _saveWhatOthersPlayed() async {
    final tune = controller.tune;
    final kept = await _otherApps?.keep(
      header:
          '# ${tune.title}, ${tune.key}, tempo heard not told, '
          '${tune.meter.label}, ${tune.barCount} bars',
    );
    if (kept == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing has been heard to save yet.')),
      );
      return;
    }
    try {
      final name =
          'broadcast-${tune.title.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')}';
      final wav = await FilePicker.platform.saveFile(
        dialogTitle: 'Save What the Broadcast Heard',
        fileName: '$name.wav',
        bytes: kept.wav,
      );
      if (wav == null) return;
      await FilePicker.platform.saveFile(
        dialogTitle: 'Save the Taps Made Along With It',
        fileName: '$name.txt',
        bytes: Uint8List.fromList(utf8.encode(kept.log)),
      );
    } catch (e) {
      debugPrint('Could not save what the broadcast heard: $e');
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
    listenable: Listenable.merge([controller, ?_ear, ?_taps, ?_otherApps]),
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
      // A count that does not yet know the bar of the tune marks none:
      // a bar 1 it guessed looks exactly like knowing.
      // Nor one while the barlines heard do not agree with the count:
      // without drums Beat This! cannot hear them, and every bar shown
      // would be wrong.
      final followed = taps != null
          ? (taps.placeKnown && (!_hearingOthers || !taps.losesTheBars)
                ? tapped
                : null)
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
                  // The way back, where it is looked for first: above the
                  // chart, not over its first bar. A phone on its side has
                  // no height to spare for it, so it stays in the bar
                  // below there.
                  if (MediaQuery.sizeOf(context).height >= 500)
                    const Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: _Leave(),
                    ),
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
                                ? _placeTheEar
                                : null,
                          ),
                          if (controller.countInBeat != null)
                            CountInBubble(beat: controller.countInBeat!),
                        ],
                      ),
                    ),
                  ),
                  if (taps != null) _Tapping(taps: taps, byEar: _hearingOthers),
                  if (_listening)
                    _Hearing(
                      level: _ear!.level,
                      heard: heard,
                      sure: sure,
                      roomTempo: _ear!.roomTempo,
                      onTap: _tapTheEar,
                    ),
                  if (_hearingOthers)
                    _OtherApps(
                      sound: _otherApps!,
                      placedByEar:
                          _placedByEar && !(_taps?.placedByHand ?? false),
                      onStart: _otherApps!.pick,
                      onSave: _saveWhatOthersPlayed,
                      onHalfTime: (_taps?.counting ?? false)
                          ? () {
                              _otherApps?.noted('HALF TIME PRESSED');
                              _taps!.halfTime();
                            }
                          : null,
                      onDoubleTime: (_taps?.counting ?? false)
                          ? () {
                              _otherApps?.noted('DOUBLE TIME PRESSED');
                              _taps!.doubleTime();
                            }
                          : null,
                    ),
                  const Divider(height: 1),
                  _StageBar(
                    leave: MediaQuery.sizeOf(context).height < 500,
                    controller: controller,
                    onPlay: _togglePlay,
                    tapping: _tapping,
                    // Where other apps can be heard, following them (by
                    // broadcast or microphone) does what the taps and the
                    // ear were for, so neither is offered on its own. A
                    // release build still follows by taps.
                    onTapping: widget.follow && !_canHearOthers
                        ? _toggleTapping
                        : null,
                    listening: _listening,
                    // Listening for itself follows iReal Pro and not a real
                    // record, so it is only offered while it is worked on.
                    onListen: widget.follow && kDebugMode && !_canHearOthers
                        ? _toggleListening
                        : null,
                    onSave:
                        // Not beside the broadcast's own save, which looks
                        // the same and keeps something else.
                        kDebugMode &&
                            !_listening &&
                            !_hearingOthers &&
                            (_ear?.hasKept ?? false)
                        ? _saveWhatItHeard
                        : null,
                    hearingOthers: _hearingOthers,
                    onHearOthers: _canHearOthers ? _toggleHearingOthers : null,
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
  const _Tapping({required this.taps, this.byEar = false});

  final TapFollower taps;

  /// Whether Beat This! is following too, by broadcast or microphone.
  final bool byEar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tempo = taps.tempo;
    final text = byEar && taps.counting && taps.losesTheBars
        ? "Can't hear a steady beat. Tap the beat, or the bar the band is "
              'on.'
        : taps.counting && tempo != null && !taps.placeKnown
        ? 'Counting at ${tempo.round()} BPM, and listening for which bar '
              'of the tune it is. Tap the bar the band is on if you know it.'
        : taps.counting && tempo != null
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

/// Hearing another app: how loud it is arriving, in what format, and how
/// steadily. Only the proof that it arrives; nothing follows it yet.
class _OtherApps extends StatelessWidget {
  const _OtherApps({
    required this.sound,
    required this.onStart,
    required this.onSave,
    this.onHalfTime,
    this.onDoubleTime,
    this.placedByEar = false,
  });

  final OtherAppsSound sound;

  /// The count at half its tempo, for when Beat This! has taken half bars
  /// for bars. Null while nothing is counted.
  final VoidCallback? onHalfTime;

  /// The count at twice its tempo, for when everything heard the band at
  /// half its tempo. Null while nothing is counted.
  final VoidCallback? onDoubleTime;

  /// Whether the bar of the tune was found by ear, not tapped.
  final bool placedByEar;
  final VoidCallback onStart;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final microphone = sound.microphone;
    final report = microphone ? null : sound.report;
    final arriving = sound.arriving;
    final text = microphone
        ? 'Listening to the room through the microphone. Play the record '
              'out loud, or play along with a band.'
        : report == null
        ? 'Start Broadcast, choose The Changes and start it, then play '
              'something in another app.'
        : !arriving
        ? 'Nothing is arriving. Start Broadcast again if it has stopped.'
        : report.buffers == 0
        ? 'Broadcasting. Play something in another app.'
        : report.peak == 0
        ? 'Sound is arriving, but it is silent. Protected music, like '
              'Apple Music, is silenced in a broadcast.'
        : 'Hearing the other app.';
    final took = sound.took;
    final following = !sound.following
        ? null
        : sound.problem ??
              sound.waiting ??
              (sound.barlinesHeard == 0
                  ? 'Beat This! is listening for the bars'
                        '${took == null ? '' : ', ${(took * 1000).round()} ms a look'}. '
                        'The count starts once it hears them steadily, or tap '
                        'the bar it is on.'
                  : 'Beat This! has heard ${sound.barlinesHeard} barlines'
                        '${took == null ? '' : ', ${(took * 1000).round()} ms a look'}'
                        '${placedByEar ? ', and found the bar by ear' : ''}.');
    // Loudness on a decibel scale, 60 dB below full scale to full scale,
    // so a quiet record still moves it.
    final level = arriving && report != null && report.level > 0
        ? ((20 * log(report.level) / ln10 + 60) / 60).clamp(0.0, 1.0)
        : 0.0;
    final small = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final rate = report?.arrivingRate;
    return Padding(
      key: const ValueKey('stage-other-apps'),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              SegmentedButton<bool>(
                key: const ValueKey('stage-other-apps-source'),
                segments: const [
                  ButtonSegment(value: false, label: Text('Broadcast')),
                  ButtonSegment(value: true, label: Text('Microphone')),
                ],
                selected: {microphone},
                onSelectionChanged: (chosen) =>
                    sound.useMicrophone(chosen.first),
              ),
              OutlinedButton(
                key: const ValueKey('stage-half-time'),
                onPressed: onHalfTime,
                child: const Text('Half Time'),
              ),
              OutlinedButton(
                key: const ValueKey('stage-double-time'),
                onPressed: onDoubleTime,
                child: const Text('Double Time'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(text, style: small),
          Row(
            children: [
              Expanded(
                child: microphone
                    ? const SizedBox()
                    : LinearProgressIndicator(
                        key: const ValueKey('stage-other-apps-level'),
                        value: level,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
              ),
              const SizedBox(width: 8),
              if (!microphone)
                OutlinedButton(
                  key: const ValueKey('stage-start-broadcast'),
                  onPressed: onStart,
                  child: const Text('Start Broadcast'),
                ),
              IconButton(
                key: const ValueKey('stage-save-broadcast'),
                icon: const Icon(Icons.save_alt),
                tooltip: 'Save the Last Minute and the Taps',
                onPressed: onSave,
              ),
            ],
          ),
          if (following != null)
            Text(
              following,
              key: const ValueKey('stage-other-apps-following'),
              style: small,
            ),
          if (report != null && report.buffers > 0) ...[
            Text(report.format, style: small),
            Text(
              '${report.framesPerBuffer} frames a buffer. '
              '${report.buffers} buffers in '
              '${report.seconds.toStringAsFixed(1)} s, '
              '${report.silentBuffers} silent. '
              '${rate == null ? '' : '${rate.round()} frames a second. '}'
              'Longest gap ${(report.longestGap * 1000).round()} ms, '
              '${report.jumps} jumps.',
              style: small,
            ),
          ],
        ],
      ),
    );
  }
}

/// The one strip of controls: what's playing, whether it's playing, and the
/// way out.
/// The way off the stage.
class _Leave extends StatelessWidget {
  const _Leave();

  @override
  Widget build(BuildContext context) => IconButton(
    key: const ValueKey('stage-done'),
    icon: const Icon(Icons.close),
    tooltip: 'Leave the Stage',
    onPressed: () => Navigator.of(context).pop(),
  );
}

class _StageBar extends StatelessWidget {
  const _StageBar({
    this.leave = false,
    required this.controller,
    required this.onPlay,
    required this.tapping,
    required this.onTapping,
    required this.listening,
    required this.onListen,
    required this.chord,
    required this.tempo,
    this.onSave,
    this.hearingOthers = false,
    this.onHearOthers,
  });

  /// Hearing another app, in a build being worked on on an iPhone.
  /// Whether the way off the stage is here, at the end of the bar: where
  /// there is no height for it at the top.
  final bool leave;

  final bool hearingOthers;
  final VoidCallback? onHearOthers;

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
            if (onHearOthers != null)
              IconButton(
                key: const ValueKey('stage-hear-others'),
                iconSize: 28,
                isSelected: hearingOthers,
                icon: const Icon(Icons.hearing_outlined),
                selectedIcon: const Icon(Icons.hearing),
                tooltip: hearingOthers
                    ? 'Stop Hearing Other Apps'
                    : 'Hear Other Apps',
                onPressed: onHearOthers,
              ),
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
            if (leave) const _Leave(),
          ],
        ),
      ),
    );
  }
}
