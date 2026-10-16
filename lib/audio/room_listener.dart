// The microphone, listening to the room for the scrolling stage.
//
// Whatever is playing (a record, a band on the bandstand) comes in as
// sound, goes to a ChartFollower, and what the follower makes of it comes
// out as a place on the chart. This is the plumbing between the two: the
// microphone opened plainly, with none of the processing a phone puts on
// a voice, and its samples handed over as they arrive.
//
// The follower is fast enough to run where the screen runs: it gets
// through a chorus of a tune about fifty times quicker than the band
// plays it.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../music/tune.dart';
import '../practice/chart_follower.dart';

/// Somewhere sound comes from, a few milliseconds at a time: mono, -1 to
/// 1, at [RoomListener.sampleRate]. The microphone, or a test's track.
typedef SoundSource = Future<Stream<Float32List>> Function();

class RoomListener extends ChangeNotifier {
  RoomListener({
    required this.tune,
    required this.tempo,
    this.fromTheTop = true,
    SoundSource? source,
  })
    // ignore: prefer_initializing_formals
    : _source = source;

  /// The tune at concert pitch, which is what the room plays.
  final Tune tune;

  /// The tempo to start counting at, before anything has been heard.
  final double tempo;
  final bool fromTheTop;
  final SoundSource? _source;

  static const sampleRate = 44100;

  late ChartFollower _follower = _fresh();
  ChartFollower _fresh() => ChartFollower(
    tune: tune,
    tempo: tempo,
    sampleRate: sampleRate,
    fromTheTop: fromTheTop,
  );

  AudioRecorder? _recorder;
  StreamSubscription<Float32List>? _subscription;
  var _listening = false;
  String? _problem;
  int? _lastBeat;

  bool get listening => _listening;

  /// Why it is not listening, where there is something to say.
  String? get problem => _problem;

  /// What is listening, for a test to look into.
  @visibleForTesting
  ChartFollower get follower => _follower;

  /// Where the music is, once a beat has been heard.
  FollowedPosition? get position => _follower.position;

  /// How loud the room is, 0 to 1.
  double get level => _follower.level;

  /// Starts listening. False if there is no microphone to listen with,
  /// with [problem] saying why.
  Future<bool> start() async {
    if (_listening) return true;
    _wanted = true;
    _problem = null;
    _follower = _fresh();
    _lastBeat = null;
    try {
      final stream = await (_source ?? _microphone)();
      // Stopped while the microphone was still coming on: the band was
      // started, say, and the ear is no longer wanted.
      if (!_wanted) {
        await _closeMicrophone();
        return false;
      }
      _subscription = stream.listen(_hear);
      _listening = true;
    } on _NoMicrophone {
      _problem =
          'The microphone is off for The Changes. It can be turned on in '
          'the Settings app, under Privacy, Microphone.';
    } catch (e) {
      debugPrint('Could not start listening: $e');
      _problem = 'The microphone would not start.';
    }
    notifyListeners();
    return _listening;
  }

  Future<Stream<Float32List>> _microphone() async {
    final recorder = _recorder ??= AudioRecorder();
    if (!await recorder.hasPermission()) throw _NoMicrophone();
    final bytes = await recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
        // Processing meant for voices squashes the attacks the beat is
        // counted from and thins the notes the chords are heard in.
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
      ),
    );
    return bytes.map(_toSamples);
  }

  static Float32List _toSamples(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    final samples = Float32List(bytes.length ~/ 2);
    for (var i = 0; i < samples.length; i++) {
      samples[i] = data.getInt16(i * 2, Endian.little) / 32768;
    }
    return samples;
  }

  void _hear(Float32List samples) {
    _follower.hear(samples);
    // Told once a beat, not every few milliseconds: nothing on screen
    // changes in between.
    final beat = _follower.position?.beat;
    if (beat != _lastBeat) {
      _lastBeat = beat;
      notifyListeners();
    }
  }

  /// "We are here": the bar a finger landed on, now beginning.
  void placeAt(int bar) {
    _follower.placeAt(bar * tune.beatsPerBar);
    _lastBeat = _follower.position?.beat;
    notifyListeners();
  }

  /// Whether listening has been asked for and not since stopped, which
  /// is true from the moment Listen is pressed, before the microphone has
  /// come on.
  var _wanted = false;

  Future<void> stop() async {
    _wanted = false;
    if (!_listening) return;
    _listening = false;
    notifyListeners();
    await _subscription?.cancel();
    _subscription = null;
    await _closeMicrophone();
  }

  Future<void> _closeMicrophone() async {
    final recorder = _recorder;
    if (recorder != null && await recorder.isRecording()) {
      await recorder.stop();
    }
  }

  @override
  void dispose() {
    unawaited(_closeDown());
    super.dispose();
  }

  Future<void> _closeDown() async {
    await _subscription?.cancel();
    final recorder = _recorder;
    if (recorder == null) return;
    if (await recorder.isRecording()) await recorder.stop();
    await recorder.dispose();
  }
}

class _NoMicrophone implements Exception {}
