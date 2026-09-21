// Listening to an instrument through the microphone for the tuner.
//
// Samples arrive in small chunks; they're kept in a rolling window, and a
// few times a second the window is checked for a pitch. Readings are
// smoothed over the last few so the needle settles rather than twitching.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:record/record.dart';

import 'pitch_detector.dart';

/// What the tuner hears: a pitch, or nothing (silence or noise).
typedef Heard = ({double hz, double clarity})?;

class TunerListener {
  TunerListener({
    this.sampleRate = 44100,
    this.minClarity = 0.8,
    this.everyMs = 80,
    this.smoothing = 5,
    this.lowestHz = 60,
    this.silence = 0.008,
  }) : _detector = PitchDetector(
         sampleRate: sampleRate,
         lowestHz: lowestHz,
         silence: silence,
       );

  /// Listening to one player while a band plays underneath them.
  ///
  /// The settings are measured rather than guessed. YIN doesn't care how
  /// loud a note is (it looks for the sound repeating, which is a shape,
  /// not a size), so the quiet limit is set by the room, not by the level:
  /// noise alone never names a note (nought out of fifteen hundred windows
  /// of it), while a note at a hundredth of speaking level is named
  /// perfectly. So the loudness gate is left barely above nothing, and it's
  /// the clarity of the repeat that decides.
  factory TunerListener.forChecking() => TunerListener(
    // Quicker than the tuner's: a line of eighth notes has to get through,
    // not a string being turned.
    everyMs: 40,
    smoothing: 3,
    minClarity: 0.85,
    // From A below the stave up. Lower than that is the bass player's, and
    // through a speaker the microphone would report their walking line as
    // yours: confidently, and wrongly.
    lowestHz: 110,
    // Only a guard against a dead input: quiet playing must get through.
    silence: 0.0002,
  );

  /// The lowest note it will look for.
  final double lowestHz;

  /// Quieter than this (RMS) and there is nothing to work with at all.
  final double silence;

  final int sampleRate;

  /// How plainly a single note has to be ringing to be reported. The tuner
  /// can be generous; listening while a band plays cannot.
  final double minClarity;

  /// How often to read the window. A needle only needs a dozen readings a
  /// second; a line of eighth notes needs more.
  final int everyMs;

  /// How many readings are averaged. More settles the needle; fewer keeps
  /// up with fast playing.
  final int smoothing;
  final PitchDetector _detector;

  /// Opened the first time it's actually wanted. Making one reaches for the
  /// platform, so simply describing a listener shouldn't.
  late final _recorder = AudioRecorder();
  var _opened = false;

  /// How loud the input is (RMS, 0–1), whatever the detector makes of it.
  /// Without this there's no telling a wrong note from a microphone that
  /// isn't hearing you at all.
  double level = 0;
  StreamSubscription<Uint8List>? _subscription;

  late final _window = Float32List(_detector.windowSize);
  var _filled = 0;
  final _clock = Stopwatch();
  final _recent = <double>[];

  /// Asks for the microphone if need be. False if the player said no.
  Future<bool> hasPermission() {
    _opened = true;
    return _recorder.hasPermission();
  }

  /// Starts listening; [onHeard] is called several times a second.
  ///
  /// With [alongsideMusic] the app keeps playing while it listens, which iOS
  /// only allows when the session is set up for both at once; otherwise
  /// starting the microphone silences the band.
  Future<void> start(
    void Function(Heard) onHeard, {
    bool alongsideMusic = false,
  }) async {
    _opened = true;
    final stream = await _recorder.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
        // Processing meant for voices would smear the pitch.
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
        iosConfig: IosRecordConfig(
          categoryOptions: [
            IosAudioCategoryOption.defaultToSpeaker,
            IosAudioCategoryOption.allowBluetooth,
            IosAudioCategoryOption.allowBluetoothA2DP,
            if (alongsideMusic) IosAudioCategoryOption.mixWithOthers,
          ],
        ),
      ),
    );
    _clock
      ..reset()
      ..start();
    _subscription = stream.listen((bytes) {
      _add(bytes);
      if (_filled < _window.length || _clock.elapsedMilliseconds < everyMs) {
        return;
      }
      _clock.reset();
      onHeard(_read());
    });
  }

  void _add(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    final count = bytes.length ~/ 2;
    final incoming = Float32List(count);
    for (var i = 0; i < count; i++) {
      incoming[i] = data.getInt16(i * 2, Endian.little) / 32768;
    }
    if (count >= _window.length) {
      _window.setAll(0, incoming.sublist(count - _window.length));
      _filled = _window.length;
      return;
    }
    // Slide the window along and put the new samples at the end.
    _window.setRange(0, _window.length - count, _window, count);
    _window.setRange(_window.length - count, _window.length, incoming);
    _filled = (_filled + count).clamp(0, _window.length);
  }

  Heard _read() {
    var energy = 0.0;
    for (final sample in _window) {
      energy += sample * sample;
    }
    level = math.sqrt(energy / _window.length);
    final heard = _detector.detect(_window);
    if (heard == null || heard.clarity < minClarity) {
      _recent.clear();
      return null;
    }
    // A new note (more than a semitone away): start averaging afresh.
    if (_recent.isNotEmpty && (heard.hz / _recent.last - 1).abs() > 0.06) {
      _recent.clear();
    }
    _recent.add(heard.hz);
    if (_recent.length > smoothing) _recent.removeAt(0);
    final sorted = [..._recent]..sort();
    return (hz: sorted[sorted.length ~/ 2], clarity: heard.clarity);
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    if (_opened && await _recorder.isRecording()) await _recorder.stop();
    _filled = 0;
    level = 0;
    _recent.clear();
  }

  Future<void> dispose() async {
    await stop();
    if (_opened) await _recorder.dispose();
  }
}
