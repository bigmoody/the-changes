// Listening to an instrument through the microphone for the tuner.
//
// Samples arrive in small chunks; they're kept in a rolling window, and a
// few times a second the window is checked for a pitch. Readings are
// smoothed over the last few so the needle settles rather than twitching.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
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
    // A guitar's low E on an iPad's own microphone is quiet: the little
    // microphone hardly hears 82 Hz. At 0.008 a recorded low E, rolled
    // off below 150 Hz as a small microphone does and at a tenth of full
    // level, was named in 3 to 5 windows of 22; at 0.0005, 16 to 22.
    // Noise alone named no note at either (see silence, above).
    this.silence = 0.0005,
    // Five periods of the lowest note, not three: a little steadier on a
    // low string (17 to 22 windows of 22, from 16 to 21), and 85 ms.
    int periods = 5,
    this.follows = true,
  }) : _detector = PitchDetector(
         sampleRate: sampleRate,
         lowestHz: lowestHz,
         silence: silence,
         periods: periods,
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
    // Short, for eighth notes.
    periods: 3,
    // A line of notes changes note every reading or two: each is taken
    // as it comes, not followed.
    follows: false,
  );

  /// Whether a note, once found, is followed while it rings (see
  /// [_follow]): what a tuner wants, a string held and dying away.
  final bool follows;

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
  var _lastLevel = 0.0;

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

  /// [samples] as if they had just come from the microphone, read as a
  /// reading would be: for a test to play a recording to.
  @visibleForTesting
  Heard playToIt(Float32List samples) {
    final bytes = ByteData(samples.length * 2);
    for (var i = 0; i < samples.length; i++) {
      bytes.setInt16(
        i * 2,
        (samples[i].clamp(-1.0, 1.0) * 32767).round(),
        Endian.little,
      );
    }
    _add(bytes.buffer.asUint8List());
    return _filled < _window.length ? null : _read();
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
    if (follows) return _follow();
    final heard = _detector.detect(_window);
    if (heard == null || heard.clarity < minClarity) {
      _recent.clear();
      _lastLevel = level;
      return null;
    }
    var hz = heard.hz;
    // A string dying away can leave its third or second harmonic louder
    // than the note: the recorded low E read as the B above its octave
    // for the last half second. Twice or three times the note just heard,
    // to a third of a semitone, getting no louder, is that note still. A
    // string plucked is louder at once: the B string after the low E is
    // three times it, and is the B.
    final dying = level <= _lastLevel * 1.2;
    _lastLevel = level;
    if (_recent.isNotEmpty && dying) {
      final note = _recent.last;
      for (final k in [2, 3]) {
        final cents = 1200 * math.log(hz / (note * k)) / math.ln2;
        if (cents.abs() < 33) {
          hz /= k;
          break;
        }
      }
    }
    // A new note (more than a semitone away): start averaging afresh.
    if (_recent.isNotEmpty && (hz / _recent.last - 1).abs() > 0.06) {
      _recent.clear();
    }
    _recent.add(hz);
    if (_recent.length > smoothing) _recent.removeAt(0);
    final sorted = [..._recent]..sort();
    return (hz: sorted[sorted.length ~/ 2], clarity: heard.clarity);
  }

  /// The note being followed, and how many readings in a row it has not
  /// been found.
  double? _note;
  var _misses = 0;

  /// A different note heard, waiting to be heard again, and how many
  /// times it has been since.
  double? _candidate;
  var _heardAgain = 0;

  /// Whether the candidate came in on a pluck.
  var _candidatePlucked = false;

  /// Every ratio of two whole numbers from one to seven but one itself.
  static final _overtoneRatios = {
    for (var n = 1; n <= 7; n++)
      for (var m = 1; m <= 7; m++)
        if (n != m) n / m,
  };

  /// The note last let go, and how many readings ago.
  ({double hz, int readings})? _faded;

  /// Readings a note is held through when it cannot be found, so a
  /// moment's dropout is not the display flashing back to listening:
  /// about a third of a second.
  static const _holdFor = 4;

  /// Following a note while it rings, the way a tuner has to. Played to
  /// a recording of a guitar on an iPad (the player's own, taken off the
  /// screen recording of this tuner and another), the tuner asked from
  /// scratch every reading lost a string as it died away, and named C2,
  /// E3 or A2 under an E4 and B3 under an E2 as it went: harmonics and
  /// undertones outlasting the note.
  ///
  /// So once a note is found it is looked for where it was, more loosely
  /// ([PitchDetector.detectNear]); a different note takes over at once
  /// when it is plucked (the sound gets louder at once), and otherwise
  /// only when the note being followed can no longer be found and the
  /// new one has been heard twice; and a note that cannot be found is
  /// held for a moment before the tuner says it has lost it.
  Heard _follow() {
    final strict = _detector.detect(_window);
    final clear = strict != null && strict.clarity >= minClarity
        ? strict
        : null;
    final plucked = level > _lastLevel * 1.3;
    _lastLevel = level;
    // The string let go a couple of seconds ago is forgotten, and so is
    // one a pluck has taken the place of.
    if (_faded case final faded?) {
      _faded = plucked || faded.readings > 25
          ? null
          : (hz: faded.hz, readings: faded.readings + 1);
    }

    double cents(double a, double b) => 1200 * math.log(a / b) / math.ln2;
    bool sameNote(double a, double b) => cents(a, b).abs() < 60;
    // What the same string throws up for a reading at the attack of a
    // fresh pluck, or as it dies: its harmonics, an undertone, and the
    // intervals between harmonics, every ratio of two whole numbers up to
    // seven (a B♭2 read off a low E is seven to five), to a third of a
    // semitone. A second is never one, so a string tuned up or down a
    // step is never taken for one.
    bool related(double hz, double note) =>
        _overtoneRatios.any((k) => cents(hz, note * k).abs() < 33);

    final note = _note;
    final near = note == null ? null : _detector.detectNear(_window, note);
    if (clear != null && (note == null || !sameNote(clear.hz, note))) {
      // The same string plucked again reads for an instant as one of its
      // overtones, some of them at no tidy ratio (a B♭2, seven fifths of
      // a low E): where the note being followed is still there at least
      // as plainly, it is that string, plucked again.
      final kin =
          note != null &&
          (related(clear.hz, note) ||
              (near != null && near.clarity >= clear.clarity));
      // Plucked: a new note at once. From nothing, only if it is clearly
      // a note; and not on one reading if it is a harmonic or undertone
      // of the note ringing, which is what the same string re-plucked
      // reads as for an instant (a B3 or an A2 off a low E).
      if (plucked && !kin && (note != null || clear.clarity >= 0.9)) {
        _candidate = null;
        _recent.clear();
        return _found(clear.hz, clear.clarity);
      }
      if (_candidate != null && sameNote(clear.hz, _candidate!)) {
        _heardAgain++;
      } else {
        _candidate = clear.hz;
        _heardAgain = 0;
        _candidatePlucked = plucked;
      }
      // Plucked and heard twice more, plainly: a new note an octave or a
      // fifth from the last is still a new note, even while the old one
      // can be found under it. A low E plucked again read as a B♭2 twice
      // running, faintly, and took over.
      if (_candidatePlucked && _heardAgain >= 2 && clear.clarity >= 0.9) {
        _candidate = null;
        _recent.clear();
        return _found(clear.hz, clear.clarity);
      }
    } else if (clear != null) {
      _candidate = null;
    }
    // Not plucked, a different note only takes over once the one being
    // followed is gone, and once it has been heard twice: what a dying
    // string throws up comes and goes while the string can still be heard.
    final candidate = _candidate;
    if (near != null) return _found(near.hz, near.clarity);
    // What is left when a low string has faded past following is mostly
    // its own overtones, and the strings ringing with it: an A2 or a B2
    // off a dying low E. Those are let go, not named.
    // The same once it has gone: for a couple of seconds the string that
    // was being followed is still the one a new note is judged against,
    // and nothing unplucked starts unless it is plainly a note.
    final faded = _faded;
    if (candidate != null &&
        note == null &&
        _heardAgain >= 1 &&
        (clear?.clarity ?? 0) >= 0.9 &&
        (faded == null || !related(candidate, faded.hz))) {
      _candidate = null;
      _recent.clear();
      return _found(candidate, minClarity);
    }
    if (note == null) return null;
    if (++_misses <= _holdFor) {
      return (hz: _smoothed(), clarity: 0.0);
    }
    _faded = (hz: note, readings: 0);
    _note = null;
    _recent.clear();
    return null;
  }

  Heard _found(double hz, double clarity) {
    _misses = 0;
    _recent.add(hz);
    if (_recent.length > smoothing) _recent.removeAt(0);
    _note = _smoothed();
    return (hz: _note!, clarity: clarity);
  }

  double _smoothed() {
    final sorted = [..._recent]..sort();
    return sorted[sorted.length ~/ 2];
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    if (_opened && await _recorder.isRecording()) await _recorder.stop();
    _filled = 0;
    level = 0;
    _recent.clear();
    _note = null;
    _candidate = null;
    _faded = null;
    _misses = 0;
  }

  Future<void> dispose() async {
    await stop();
    if (_opened) await _recorder.dispose();
  }
}
