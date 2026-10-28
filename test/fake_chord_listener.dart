// A microphone that hears whatever the test says it hears.

import 'package:play_along/audio/chord_ear.dart';
import 'package:play_along/audio/chord_listener.dart';

class FakeChordListener implements ChordListener {
  FakeChordListener({this.allowed = true});

  final bool allowed;
  void Function(HeardNotes)? _onHeard;
  var stopped = false;

  bool get listening => _onHeard != null && !stopped;

  /// Hears these notes (MIDI), evenly weighted, for three readings in a
  /// row as a chord strummed and ringing is: the first, louder than what
  /// came before, is the strum; then it has to read the same twice before
  /// it is named (see chord_reader.dart).
  void hear(List<int> pitches, {double level = 0.05}) {
    final chroma = List.filled(12, 0.0);
    for (final pitch in pitches) {
      chroma[pitch % 12] += 1;
    }
    final total = chroma.fold(0.0, (a, b) => a + b);
    if (total > 0) {
      for (var i = 0; i < 12; i++) {
        chroma[i] /= total;
      }
    }
    this.level = level;
    final heard = HeardNotes(pitches: pitches, chroma: chroma, level: level);
    for (var reading = 0; reading < 3; reading++) {
      _onHeard?.call(heard);
    }
  }

  @override
  double level = 0;

  @override
  int get sampleRate => 44100;

  @override
  int get size => 16384;

  @override
  int get everyMs => 120;

  @override
  Future<bool> hasPermission() async => allowed;

  @override
  Future<void> start(void Function(HeardNotes) onHeard) async {
    _onHeard = onHeard;
    stopped = false;
  }

  @override
  Future<void> stop() async {
    stopped = true;
    _onHeard = null;
  }

  @override
  Future<void> dispose() async => stop();
}
