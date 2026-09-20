// Plays the generated backing track on a seamless loop, and decides whether
// the app shares the speaker with other apps (Spotify, forScore, YouTube …).
//
// How "play alongside other apps" works:
//  • iOS: every app has an audio session. The `playback` category with the
//    `mixWithOthers` option tells iOS "don't stop other apps' audio when I
//    play". Without that option, pressing play interrupts Spotify.
//  • Android: apps pause when another app requests "audio focus". In mixing
//    mode we simply never request it, so nothing else gets paused.

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:isolate';
import 'dart:math' as math;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../music/loop_range.dart';
import 'backing_synth.dart';
import 'sample_bank.dart';

class PracticePlayer {
  SoLoud get _soloud => SoLoud.instance;
  AudioSession? _session;

  /// Recorded instruments; null until loaded (the band then uses synthesis).
  SampleBank? samples;

  bool _mixWithOthers = true;
  bool get mixWithOthers => _mixWithOthers;

  /// Everything currently loaded and playing: one source and handle per stem.
  final _sources = <AudioSource>[];
  final _handles = <Instrument, SoundHandle>{};
  SoundHandle? _countInHandle;

  /// A recording of you, playing over the band.
  SoundHandle? _takeHandle;
  double _takeVolume = 1;

  /// How loud the take plays against the band.
  void setTakeVolume(double volume) {
    _takeVolume = volume.clamp(0.0, 1.0);
    final handle = _takeHandle;
    if (handle != null) _soloud.setVolume(handle, _takeVolume);
  }

  /// The clicks stem. Its position — how much of it the engine has taken —
  /// is what the app keeps time by: it runs straight through, counts the
  /// count-in and the playing alike, and can't be got wrong by a tempo that
  /// changes.
  AudioSource? _clickSource;
  AudioSource? _loop;
  PlaybackClock? _clock;

  /// The volume (0–1) each instrument should play at; changed by the mixer.
  final _volumes = {
    for (final instrument in Instrument.values) instrument: 1.0,
  };

  /// Bumped on every start/stop so a slow render can't override a newer request.
  int _generation = 0;

  Future<void> init({bool mixWithOthers = true}) async {
    _session = await AudioSession.instance;
    await setMixWithOthers(mixWithOthers);
    if (Platform.isIOS) await _session!.setActive(true);
    await _soloud.init();
  }

  /// Puts the audio back as the band needs it, after something else (the
  /// tuner's microphone) has changed how the phone's audio is set up.
  Future<void> restoreAudioSession() async {
    await setMixWithOthers(_mixWithOthers);
    if (Platform.isIOS) await _session?.setActive(true);
  }

  Future<void> setMixWithOthers(bool value) async {
    _mixWithOthers = value;
    await _session?.configure(
      AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: value
            ? AVAudioSessionCategoryOptions.mixWithOthers
            : AVAudioSessionCategoryOptions.none,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
      ),
    );
    if (_countInHandle != null && Platform.isAndroid) {
      await _session?.setActive(!value); // take or release audio focus now
    }
  }

  /// Renders the backing for [request] and starts playing it.
  ///
  /// With [alongside], a recording of you is played over the top, starting
  /// on the same sample as the band's first beat — so a take lines up with
  /// the band without either having to be recorded against the other.
  Future<void> start(
    BackingRequest request, {
    String? alongside,
    Duration leadIn = Duration.zero,
  }) async {
    final generation = ++_generation;
    final backing = await _renderInBackground(request.withSamples(samples));
    if (generation != _generation) return;

    final sources = <AudioSource>[];
    // Everything is streamed rather than looped: fresh playing is added
    // before the current batch runs out, so nothing ever repeats. The clicks
    // are streamed with the band — silence after the count-in — so their
    // playing position is a clock that runs straight through, whatever the
    // tempo is doing.
    final streams = {
      // Every part the band is playing (the arpeggios only when asked for).
      for (final instrument in backing.batch.pcm.keys)
        instrument: _soloud.setBufferStream(
          maxBufferSizeBytes: 0x7fffffff, // a limit on total data, not memory
          bufferingType: BufferingType.released, // free audio once played
          bufferingTimeNeeds: 0.5,
          sampleRate: backing.sampleRate,
          channels: Channels.mono,
          format: BufferType.s16le,
          onBuffering: (isBuffering, handle, time) {
            if (isBuffering) {
              debugPrint(
                '${instrument.label} stream ran dry at '
                '${time.toStringAsFixed(1)} s',
              );
            }
          },
        ),
    };
    for (final entry in streams.entries) {
      sources.add(entry.value);
      _soloud.addAudioDataStream(entry.value, backing.batch.pcm[entry.key]!);
    }
    final clickStream = _soloud.setBufferStream(
      maxBufferSizeBytes: 0x7fffffff,
      bufferingType: BufferingType.released,
      bufferingTimeNeeds: 0.5,
      sampleRate: backing.sampleRate,
      channels: Channels.mono,
      format: BufferType.s16le,
    );
    sources.add(clickStream);
    _soloud.addAudioDataStream(clickStream, backing.batch.clicks);

    AudioSource? take;
    if (alongside != null) {
      // If this fails there's nothing to say over the band, and playing the
      // band on its own would look exactly like the take being played. So
      // it's reported rather than swallowed.
      take = await _soloud.loadFile(alongside);
      sources.add(take);
    }
    if (generation != _generation) {
      for (final source in sources) {
        await _soloud.disposeSource(source);
      }
      return;
    }

    await _stopCurrent();
    if (Platform.isAndroid && !_mixWithOthers) await _session?.setActive(true);

    // Start every stem paused, then unpause them as one voice group so they
    // begin on exactly the same sample and stay in sync.
    _countInHandle = _soloud.play(clickStream, paused: true, volume: 1);
    _clickSource = clickStream;
    for (final entry in streams.entries) {
      _handles[entry.key] = _soloud.play(
        entry.value,
        paused: true,
        volume: _volumes[entry.key]!,
      );
    }
    if (take != null) {
      _takeHandle = _soloud.play(take, paused: true, volume: _takeVolume);
      // The recording began before the band did — the band has to be
      // written first — so wind past that much of it.
      if (leadIn > Duration.zero) _soloud.seek(_takeHandle!, leadIn);
    }
    final group = _soloud.createVoiceGroup();
    _soloud.addVoicesToGroup(group, [
      _countInHandle!,
      ?_takeHandle,
      ..._handles.values,
    ]);
    _soloud.setPause(group, false);
    _soloud.destroyVoiceGroup(group);

    _sources.addAll(sources);
    _clock = PlaybackClock(backing: backing, loop: request.loop);

    final stream = _BandStream(
      request: request.withSamples(samples),
      sources: streams,
      clicks: clickStream,
      gain: backing.gain,
      secondsAdded:
          backing.batch.pcm[Instrument.bass]!.length / 2 / backing.sampleRate,
      tails: backing.batch.tails,
      state: backing.batch.state,
    );
    _stream = stream;
    _streamTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _topUp(stream, generation),
    );
  }

  _BandStream? _stream;
  Timer? _streamTimer;

  /// Keeps at least ~45 seconds of playing queued ahead of what's heard.
  Future<void> _topUp(_BandStream stream, int generation) async {
    if (stream.rendering || generation != _generation) return;
    // An arrangement that ends has nothing more to write. What's left is
    // the sound still ringing from the last chord, so it isn't cut off.
    if (chorusesIn(stream.request, stream.nextBatch) == 0) {
      if (stream.ended) return;
      stream.ended = true;
      for (final entry in stream.sources.entries) {
        _soloud.addAudioDataStream(
          entry.value,
          ringOut(
            stream.tails[entry.key]!,
            stream.gain,
            stream.request.sampleRate,
          ),
        );
      }
      // Silence of the same length, so the clock runs on to the end.
      _soloud.addAudioDataStream(
        stream.clicks,
        Uint8List(stream.tails.values.first.length * 2),
      );
      return;
    }
    final played =
        _soloud
            .getStreamTimeConsumed(stream.sources[Instrument.bass]!)
            .inMilliseconds /
        1000;
    if (stream.secondsAdded - played > 45) return;

    stream.rendering = true;
    final batch = await _renderBatchInBackground(
      stream.request,
      batch: stream.nextBatch,
      gain: stream.gain,
      state: stream.state,
      carryIn: stream.tails,
    );
    stream.rendering = false;
    if (generation != _generation || _stream != stream) return;

    for (final entry in stream.sources.entries) {
      _soloud.addAudioDataStream(entry.value, batch.pcm[entry.key]!);
    }
    _soloud.addAudioDataStream(stream.clicks, batch.clicks);
    debugPrint(
      'Batch ${stream.nextBatch} added: ${played.toStringAsFixed(2)} s played, '
      '${stream.sinceStart.elapsedMilliseconds / 1000} s since Play',
    );
    stream
      ..secondsAdded +=
          batch.pcm[Instrument.bass]!.length / 2 / stream.request.sampleRate
      ..tails = batch.tails
      ..state = batch.state
      ..nextBatch += 1;
  }

  /// Rendering is heavy maths, so it runs on a background isolate.
  ///
  /// These are `static` on purpose: a closure created inside an instance
  /// method can capture `this`, and the player (with its audio session)
  /// can't be copied to another isolate.
  static Future<RenderedBacking> _renderInBackground(BackingRequest request) =>
      Isolate.run(() => renderBacking(request));

  static Future<BackingBatch> _renderBatchInBackground(
    BackingRequest request, {
    required int batch,
    required double gain,
    required BandState state,
    required Map<Instrument, Float32List> carryIn,
  }) => Isolate.run(
    () => renderBatch(
      request,
      batch: batch,
      gain: gain,
      state: state,
      carryIn: carryIn,
    ),
  );

  AudioSource? _snippet;

  /// Plays a short WAV once, over anything else — the drills' "hear it".
  /// Each new one replaces the last, so tapping twice doesn't pile them up.
  Future<void> playSnippet(Uint8List wav) async {
    final previous = _snippet;
    _snippet = null;
    if (previous != null) await _soloud.disposeSource(previous);
    final source = await _soloud.loadMem('snippet.wav', wav);
    _snippet = source;
    _soloud.play(source);
  }

  /// Plays [wav] over and over until [stopLoop] — the metronome's bar of
  /// clicks. It plays on its own, apart from the band.
  /// How many times a looping sound has been started: the metronome's
  /// tests watch this to see that changing the tempo doesn't restart it
  /// over and over.
  @visibleForTesting
  int loopsStarted = 0;

  Future<void> playLoop(Uint8List wav) async {
    await stopLoop();
    loopsStarted++;
    // Without working audio there's simply no click.
    try {
      final source = await _soloud.loadMem('loop.wav', wav);
      _loop = source;
      _soloud.play(source, looping: true);
    } catch (e) {
      debugPrint('Could not play the loop: $e');
    }
  }

  Future<void> stopLoop() async {
    final source = _loop;
    _loop = null;
    if (source == null) return;
    try {
      await _soloud.disposeSource(source);
    } catch (e) {
      debugPrint('Could not stop the loop: $e');
    }
  }

  /// Whether the looping sound is playing.
  bool get isLooping => _loop != null;

  /// Whether playback is paused (as opposed to stopped: a paused band keeps
  /// its place and carries on from it).
  bool get isPaused => _paused;
  bool _paused = false;

  /// Pauses every instrument at once. They're paused as one voice group — the
  /// same way they're started — so they stop on the same sample and resume
  /// in step, and the clock (the count-in stem) stops with them.
  void pause() => _setPaused(true);

  /// Carries on from exactly where [pause] left off.
  void resume() => _setPaused(false);

  void _setPaused(bool paused) {
    final handles = [?_countInHandle, ?_takeHandle, ..._handles.values];
    if (handles.isEmpty || paused == _paused) return;
    final group = _soloud.createVoiceGroup();
    _soloud.addVoicesToGroup(group, handles);
    _soloud.setPause(group, paused);
    _soloud.destroyVoiceGroup(group);
    _paused = paused;
  }

  /// Sets one instrument's volume (0 = silent, 1 = full) immediately.
  void setVolume(Instrument instrument, double volume) {
    _volumes[instrument] = volume;
    final handle = _handles[instrument];
    if (handle != null) _soloud.setVolume(handle, volume);
  }

  Future<void> stop() async {
    _generation++;
    await _stopCurrent();
    if (Platform.isAndroid && !_mixWithOthers) await _session?.setActive(false);
  }

  Future<void> _stopCurrent() async {
    _streamTimer?.cancel();
    _streamTimer = null;
    _stream = null;
    final handles = [?_countInHandle, ?_takeHandle, ..._handles.values];
    final sources = [..._sources];
    _countInHandle = null;
    _takeHandle = null;
    _clickSource = null;
    _handles.clear();
    _sources.clear();
    _clock = null;
    _paused = false;
    for (final handle in handles) {
      await _soloud.stop(handle);
    }
    for (final source in sources) {
      await _soloud.disposeSource(source);
    }
  }

  /// Where playback is right now, or null when stopped.
  PlaybackPosition? position() {
    // A streamed stem has no "position" to read; what it has is how much of
    // it the engine has taken, which is the same thing and keeps counting
    // past the end of a batch.
    final source = _clickSource;
    final clock = _clock;
    if (source == null || clock == null) return null;
    return clock.positionAt(_soloud.getStreamTimeConsumed(source));
  }
}

/// Turns the audio engine's playback time into "count-in beat 3" or
/// "tune beat 17".
///
/// When a loop jumps back to its start, the engine can briefly report a time
/// a fraction of a sample *before* the loop point (rounding when it converts
/// the loop point to samples, which depends on the device's sample rate).
/// Read naively, that looks like the last beat of the count-in, so a "4"
/// flashed up at every loop on some devices. Once the count-in has finished,
/// this clock never goes back to it.
class PlaybackClock {
  PlaybackClock({required this.backing, required this.loop});

  final RenderedBacking backing;
  final LoopRange loop;
  bool _countInFinished = false;

  /// How long a beat lasts on [chorus]. A tempo ramp shortens it every time
  /// round until it tops out, and holds it there.
  int _samplesPerBeat(int chorus) {
    final table = backing.samplesPerBeatByChorus;
    return table[math.min(chorus, table.length - 1)];
  }

  PlaybackPosition positionAt(Duration time) {
    final samples = time.inMicroseconds * backing.sampleRate / 1000000;
    final countInSamples = backing.countInBeats * backing.samplesPerBeat;

    // Tiny tolerance for rounding right at the end of the count-in.
    if (!_countInFinished &&
        samples < countInSamples - backing.samplesPerBeat * 0.001) {
      return PlaybackPosition(
        countInBeat: (samples / backing.samplesPerBeat).floor() + 1,
      );
    }
    _countInFinished = true;

    // Walk the passes off one at a time: they aren't all the same length
    // when the tempo is climbing.
    var left = samples - countInSamples;
    if (left < 0) left = 0;
    var chorus = 0;
    while (true) {
      final chorusSamples = loop.lengthBeats * _samplesPerBeat(chorus);
      if (left < chorusSamples) break;
      left -= chorusSamples;
      chorus++;
    }
    return PlaybackPosition(
      tuneBeat: loop.startBeat + (left / _samplesPerBeat(chorus)).floor(),
      chorus: chorus,
    );
  }
}

class PlaybackPosition {
  const PlaybackPosition({this.countInBeat, this.tuneBeat, this.chorus});

  /// 1, 2, 3, 4 during the count-in; otherwise null.
  final int? countInBeat;

  /// The beat of the tune being played (0-based); null during the count-in.
  final int? tuneBeat;

  /// Which time round the form this is (0-based); null during the count-in.
  final int? chorus;
}

/// Bookkeeping for the streamed instruments.
class _BandStream {
  _BandStream({
    required this.request,
    required this.sources,
    required this.clicks,
    required this.gain,
    required this.secondsAdded,
    required this.tails,
    required this.state,
  });

  final BackingRequest request;
  final Map<Instrument, AudioSource> sources;

  /// The clock stem, fed in step with the band.
  final AudioSource clicks;
  final double gain;
  double secondsAdded;
  Map<Instrument, Float32List> tails;
  BandState state;
  int nextBatch = 1;
  bool rendering = false;

  /// Whether the arrangement has been played out and rung off.
  bool ended = false;

  /// For the debug log: played time should track this closely.
  final sinceStart = Stopwatch()..start();
}
