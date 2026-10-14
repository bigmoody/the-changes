// One band that makes no sound, for every test that needs one.
//
// There were forty-two of these, one per test file, each a slightly
// different subset of the same handful of no-op overrides. The cost was
// not the duplication: it was that changing anything on PracticePlayer
// broke an arbitrary few of them, and which few was unknowable until the
// whole suite had run. Adding one optional parameter to playSnippet
// broke two; adding pause and resume to it broke more.
//
// So: one fake, which answers every call the real player answers and
// remembers what it was asked. A test that needs something particular
// subclasses it and overrides that one thing, rather than starting again
// from nothing.
//
// It deliberately records more than any single test needs. The whole
// point is that the next test does not have to write a new one.

import 'dart:typed_data';

import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/recorded_take.dart' show TakeShift;

class FakePlayer extends PracticePlayer {
  /// What the band was last asked to play, and everything it was asked
  /// to play, in order.
  BackingRequest? request;
  final requests = <BackingRequest>[];

  /// The take or imported recording it was asked to play alongside.
  String? alongside;
  Duration leadIn = Duration.zero;
  int pickUpBeats = 0;
  PlayableRecording? recording;

  /// Every call by name, in order, for tests about what happened when.
  final calls = <String>[];

  var stopped = false;
  var restored = false;

  final volumes = <Instrument, double>{};
  double? takeVolume;

  var _playing = false;
  var _paused = false;

  bool get playing => _playing;

  /// What [position] gives back. Null is a band that has not started, or
  /// one whose clock a test does not care about.
  PlaybackPosition? at;

  @override
  Future<void> init({bool mixWithOthers = true}) async {
    calls.add('init');
  }

  @override
  Future<void> start(
    BackingRequest request, {
    String? alongside,
    Duration leadIn = Duration.zero,
    int pickUpBeats = 0,
    PlayableRecording? recording,
  }) async {
    calls.add('start');
    this.request = request;
    requests.add(request);
    this.alongside = alongside;
    this.leadIn = leadIn;
    this.pickUpBeats = pickUpBeats;
    this.recording = recording;
    _playing = true;
    _paused = false;
  }

  @override
  void pause() {
    calls.add('pause');
    _paused = true;
  }

  @override
  void resume() {
    calls.add('resume');
    _paused = false;
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    stopped = true;
    _playing = false;
    _paused = false;
  }

  @override
  bool get isPaused => _paused;

  @override
  PlaybackPosition? position() => at;

  @override
  Future<void> restoreAudioSession() async {
    calls.add('restore');
    restored = true;
  }

  @override
  Future<void> setMixWithOthers(bool value) async {
    calls.add('mix');
  }

  @override
  void setVolume(Instrument instrument, double volume) =>
      volumes[instrument] = volume;

  @override
  void setTakeVolume(double volume) => takeVolume = volume;

  // The short sounds: a drill's "hear it", a phrase being scrubbed.

  Uint8List? played;

  /// Every snippet, in order, for tests about how many were played
  /// rather than which was last.
  final playedSnippets = <Uint8List>[];
  TakeShift? withShift;
  Duration? playedFrom;

  /// Every place a playing snippet was asked to move to, in order.
  final movedTo = <Duration>[];

  /// What [snippetPosition] gives back: null is nothing playing, which
  /// is also how a snippet says it has run out.
  Duration? snippetAt;

  var snippetStopped = false;
  var snippetPaused = false;
  var snippetResumed = false;

  @override
  Future<void> playSnippet(
    Uint8List wav, {
    TakeShift? shift,
    Duration from = Duration.zero,
  }) async {
    calls.add('snippet');
    played = wav;
    playedSnippets.add(wav);
    withShift = shift;
    playedFrom = from;
  }

  @override
  Duration? snippetPosition() => snippetAt;

  @override
  Future<void> seekSnippet(Duration to) async => movedTo.add(to);

  @override
  Future<void> pauseSnippet() async => snippetPaused = true;

  @override
  Future<void> resumeSnippet() async => snippetResumed = true;

  @override
  Future<void> stopSnippet() async => snippetStopped = true;

  @override
  Future<void> playLoop(Uint8List wav) async => calls.add('loop');

  @override
  Future<void> stopLoop() async => calls.add('stopLoop');
}
