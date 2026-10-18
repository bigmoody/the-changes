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
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../music/tune.dart';
import '../practice/chart_follower.dart';
import '../practice/room_follower.dart';

/// Somewhere sound comes from, a few milliseconds at a time: mono, -1 to
/// 1, at [RoomListener.sampleRate]. The microphone, or a test's track.
typedef SoundSource = Future<Stream<Float32List>> Function();

class RoomListener extends ChangeNotifier {
  RoomListener({required this.tune, SoundSource? source, bool? keepWhatItHears})
    : keepWhatItHears = keepWhatItHears ?? kDebugMode,
      // ignore: prefer_initializing_formals
      _source = source;

  /// Whether to keep what it hears, to be saved and listened back to when
  /// it has not followed something it should have. Only while the app is
  /// being worked on (debug builds): nothing is kept in the app people
  /// use, which is what the microphone's purpose string promises.
  final bool keepWhatItHears;

  /// What it heard, as 16-bit samples, and what happened while it did:
  /// each beat it counted, and every tap.
  final _kept = <Int16List>[];
  var _keptSamples = 0;
  final _log = StringBuffer();

  /// Five minutes, which is a tune and then some.
  static const _keepAtMost = sampleRate * 300;

  bool get hasKept => _keptSamples > 0;

  /// The tune at concert pitch, which is what the room plays.
  final Tune tune;

  final SoundSource? _source;

  static const sampleRate = 44100;

  // Told nothing about the tempo: it hears it (see room_follower.dart).
  // The tempo on the chart is whatever it was last practised at, and on
  // a stand there is no time to look up what the band counted off.
  late RoomFollower _follower = _fresh();
  RoomFollower _fresh() => RoomFollower(tune: tune, sampleRate: sampleRate);

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
  RoomFollower get follower => _follower;

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
    _kept.clear();
    _keptSamples = 0;
    _log
      ..clear()
      ..writeln(
        '# ${tune.title}, ${tune.key}, tempo heard not told, '
        '${tune.meter.label}, ${tune.barCount} bars',
      )
      ..writeln('# seconds  event');
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

  double get _now => _keptSamples / sampleRate;

  void _keep(Float32List samples) {
    if (!keepWhatItHears || _keptSamples >= _keepAtMost) return;
    final chunk = Int16List(samples.length);
    for (var i = 0; i < samples.length; i++) {
      chunk[i] = (samples[i].clamp(-1.0, 1.0) * 32767).round().toInt();
    }
    _kept.add(chunk);
    _keptSamples += chunk.length;
  }

  void _hear(Float32List samples) {
    _keep(samples);
    final before = _follower.heardBeats.length;
    _follower.hear(samples);
    if (keepWhatItHears) {
      for (final beat in _follower.heardBeats.skip(before)) {
        _log.writeln(
          '${beat.at.toStringAsFixed(3)}  beat ${beat.beat} bar '
          '${beat.bar + 1} sure ${beat.confidence.toStringAsFixed(2)} '
          'music ${beat.hearsMusic} tempo ${beat.tempo.toStringAsFixed(1)} '
          'level ${_follower.level.toStringAsFixed(4)}',
        );
      }
    }
    // Told once a beat, not every few milliseconds: nothing on screen
    // changes in between.
    final beat = _follower.position?.beat;
    if (beat != _lastBeat) {
      _lastBeat = beat;
      notifyListeners();
    }
  }

  /// The tempo of a groove heard that the count is not on, if there is
  /// one: a sign the chart's tempo is some way from the record's.
  double? get roomTempo => _follower.roomTempo;

  /// A tap on the beat, along with the music.
  void tap() {
    _log.writeln('${_now.toStringAsFixed(3)}  TAP THE BEAT');
    _follower.tap();
    notifyListeners();
  }

  /// "We are here": the bar a finger landed on, now beginning.
  void placeAt(int bar) {
    _log.writeln('${_now.toStringAsFixed(3)}  TAPPED BAR ${bar + 1}');
    _follower.placeAt(bar * tune.beatsPerBar);
    _lastBeat = _follower.position?.beat;
    notifyListeners();
  }

  /// Whether listening has been asked for and not since stopped, which
  /// is true from the moment Listen is pressed, before the microphone has
  /// come on.
  var _wanted = false;

  /// What it heard (a WAV) and what it made of it (a log), with a name
  /// for them. Null if nothing was kept.
  ({String name, Uint8List wav, String log})? whatItHeard() {
    if (!hasKept) return null;
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-')
        .substring(0, 19);
    return (
      name:
          'heard-${tune.title.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')}-$stamp',
      wav: _wavOf(_kept, _keptSamples),
      log: _log.toString(),
    );
  }

  static Uint8List _wavOf(List<Int16List> chunks, int samples) {
    final bytes = ByteData(44 + samples * 2);
    void text(int at, String s) {
      for (var i = 0; i < s.length; i++) {
        bytes.setUint8(at + i, s.codeUnitAt(i));
      }
    }

    text(0, 'RIFF');
    bytes.setUint32(4, 36 + samples * 2, Endian.little);
    text(8, 'WAVE');
    text(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, 1, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    text(36, 'data');
    bytes.setUint32(40, samples * 2, Endian.little);
    var at = 44;
    for (final chunk in chunks) {
      for (final sample in chunk) {
        bytes.setInt16(at, sample, Endian.little);
        at += 2;
      }
    }
    return bytes.buffer.asUint8List();
  }

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
