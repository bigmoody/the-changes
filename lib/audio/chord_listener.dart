// Listening for chords through the microphone.
//
// Where the tuner needs a fiftieth of a second to find one note, a chord
// needs a third of a second: telling a B from a C two octaves down means
// telling frequencies a couple of hertz apart, and that resolution can only
// come from listening for longer.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:record/record.dart';

import 'chord_ear.dart';

class ChordListener {
  ChordListener({
    this.sampleRate = 44100,
    this.size = 16384,
    // Every 60 ms: a note fretted on the G string, heard through an
    // iPad, is gone in a fifth of a second, and read every 120 ms it was
    // often gone before the chord could be named (chord_reader.dart).
    this.everyMs = 60,
  });

  final int sampleRate;

  /// How many samples each listen looks at. A power of two, and about a
  /// third of a second at 44.1 kHz.
  final int size;

  /// How often to make something of what's been heard.
  final int everyMs;

  /// Opened the first time it's wanted: making one reaches for the
  /// platform.
  late final _recorder = AudioRecorder();
  var _opened = false;
  StreamSubscription<Uint8List>? _subscription;

  late final _window = Float32List(size);
  var _filled = 0;
  final _clock = Stopwatch();

  /// How loud the input is (RMS, 0–1).
  double level = 0;

  /// Asks for the microphone if need be. False if the player said no.
  Future<bool> hasPermission() {
    _opened = true;
    return _recorder.hasPermission();
  }

  /// Starts listening; [onHeard] is called several times a second with
  /// whatever notes are sounding.
  Future<void> start(void Function(HeardNotes) onHeard) async {
    _opened = true;
    final stream = await _recorder.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
        // Processing meant for voices would flatten a chord's quieter
        // strings into the loud ones.
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
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
      final heard = listenForNotes(_window, sampleRate: sampleRate, size: size);
      level = heard.level;
      onHeard(heard);
    });
  }

  void _add(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    final count = bytes.length ~/ 2;
    if (count >= _window.length) {
      for (var i = 0; i < _window.length; i++) {
        final from = count - _window.length + i;
        _window[i] = data.getInt16(from * 2, Endian.little) / 32768;
      }
      _filled = _window.length;
      return;
    }
    // Slide the window along and put the new samples at the end.
    _window.setRange(0, _window.length - count, _window, count);
    for (var i = 0; i < count; i++) {
      _window[_window.length - count + i] =
          data.getInt16(i * 2, Endian.little) / 32768;
    }
    _filled = math.min(_filled + count, _window.length);
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    if (_opened && await _recorder.isRecording()) await _recorder.stop();
    _filled = 0;
    level = 0;
  }

  Future<void> dispose() async {
    await stop();
    if (_opened) await _recorder.dispose();
  }
}
