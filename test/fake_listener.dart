// A microphone that hears whatever the test says, for the tuner and for
// checking what you played.

import 'dart:typed_data';

import 'package:play_along/audio/tuner_listener.dart';

class FakeListener implements TunerListener {
  FakeListener({this.allowed = true});

  final bool allowed;
  void Function(Heard)? _onHeard;
  var stopped = false;

  /// Whether it was told to keep the band playing while it listened.
  bool? alongside;

  bool get listening => _onHeard != null && !stopped;

  /// Hears [hz], or nothing. The level is separate from the pitch: a
  /// microphone can be picking up plenty and still make no sense of it.
  void hear(double? hz, {double clarity = 0.95, double? at}) {
    if (at != null) {
      level = at;
    } else if (hz != null) {
      level = 0.05;
    }
    _onHeard?.call(hz == null ? null : (hz: hz, clarity: clarity));
  }

  @override
  double level = 0;

  /// Not for a fake: it hears what [hear] says.
  @override
  Heard playToIt(Float32List samples) => throw UnimplementedError();

  @override
  double get silence => 0.0002;

  @override
  double get lowestHz => 110;

  @override
  int get sampleRate => 44100;

  @override
  double get minClarity => 0.8;

  @override
  int get everyMs => 80;

  @override
  int get smoothing => 5;

  @override
  Future<bool> hasPermission() async => allowed;

  @override
  Future<void> start(
    void Function(Heard) onHeard, {
    bool alongsideMusic = false,
  }) async {
    _onHeard = onHeard;
    alongside = alongsideMusic;
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
