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
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../music/loop_range.dart';
import '../music/recorded_take.dart';
import 'backing_synth.dart';
import 'now_playing_centre.dart';
import 'sample_bank.dart';
import 'take_audio.dart';
import 'wav_file.dart';

/// Which of the mixer's channels a recorded stem plays on.
///
/// The stems go on the band's own channels rather than getting three of
/// their own, so every screen that already knows how to pull the piano
/// down keeps working without being told that this band is made of people.
Instrument instrumentFor(TakeStem stem) => switch (stem) {
  TakeStem.bass => Instrument.bass,
  TakeStem.drums => Instrument.drums,
  TakeStem.comp => Instrument.chords,
};

/// A recording, decoded and ready to be laid against the band's clock.
class PlayableRecording {
  const PlayableRecording({
    required this.take,
    required this.stems,
    required this.shift,
  });

  final RecordedTake take;

  /// The audio of each stem that was imported, already read.
  final Map<TakeStem, WavAudio> stems;

  /// What the engine has to do to it to land on the tempo and key being
  /// played. Worked out in recorded_take.dart, applied here and nowhere
  /// else.
  final TakeShift shift;

  bool get isEmpty => stems.isEmpty;
}

class PracticePlayer {
  SoLoud get _soloud => SoLoud.instance;
  AudioSession? _session;

  /// The Control Centre card, where the platform has one.
  ///
  /// It lives here because it mirrors the audio session, which lives
  /// here: the card is the app saying out loud the thing the session
  /// already asked for, which is to be the only sound playing.
  NowPlayingCentre? nowPlaying;

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

  /// The stems of an imported recording, playing as the band.
  final _recordingHandles = <TakeStem, SoundHandle>{};
  _RecordingStream? _recording;

  /// Whether real players are playing rather than the generated band.
  bool get isPlayingRecording => _recording != null;

  /// The clicks stem. Its position (how much of it the engine has taken)
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
    // Both phones have a card built. Anywhere else this stays null and
    // nothing asks for one.
    if (Platform.isIOS || Platform.isAndroid) nowPlaying = NowPlayingCentre();
    await setMixWithOthers(mixWithOthers);
    if (Platform.isIOS) await _session!.setActive(true);
    // On a Mac, twice the buffer an iPad gets. The iPad app running there
    // popped and crackled the way a DAW does with too many plugins: the
    // Mac's audio missing its deadline with 2048 frames to fill, not the
    // app running short of the band, which is queued 45 seconds ahead.
    // The extra 46 ms of latency is nothing to a backing track, and an
    // iPad or a phone keeps the smaller buffer and its tighter timing.
    final onMac = await _onMac();
    await _soloud.init(bufferSize: onMac ? 4096 : 2048, lowLatency: !onMac);
  }

  /// Whether this is the iPad app running on a Mac.
  static Future<bool> _onMac() async {
    if (!Platform.isIOS) return false;
    try {
      return await const MethodChannel(
            'the_changes/device',
          ).invokeMethod<bool>('onMac') ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
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
  /// on the same sample as the band's first beat, so a take lines up with
  /// the band without either having to be recorded against the other.
  Future<void> start(
    BackingRequest request, {
    String? alongside,
    Duration leadIn = Duration.zero,
    int pickUpBeats = 0,
    PlayableRecording? recording,
  }) async {
    final generation = ++_generation;
    final rendered = await _renderInBackground(request.withSamples(samples));
    if (generation != _generation) return;
    // Coming in part-way through the form: the band is written whole and
    // the beats before the pick-up are cut off the front of the first
    // batch. Everything after it (the top-ups, the ring-out, the clock)
    // then works out as it always did, because only the first time round
    // is short.
    final backing = fromPickUp(rendered, pickUpBeats);

    final sources = <AudioSource>[];
    // Everything is streamed rather than looped: fresh playing is added
    // before the current batch runs out, so nothing ever repeats. The clicks
    // are streamed with the band (silence after the count-in), so their
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

    // A recording plays as the band rather than beside it. Its stems go on
    // the band's own mixer channels and the generated instruments are
    // turned down to nothing. They are still written and still streamed,
    // because the clicks stem that everything is timed by is written with
    // them, and unpicking that to save the work would put the clock at
    // risk to save a little processing.
    final playing = recording != null && !recording.isEmpty ? recording : null;
    final recordingStreams = <TakeStem, AudioSource>{};
    _RecordingStream? recordingStream;
    if (playing != null) {
      final countInBeats = request.countInBars * request.tune.beatsPerBar;
      final perBatch = _chorusesPerBatch(request);
      final laid = _layRecording(
        playing,
        loop: request.loop,
        countInBeats: countInBeats,
        fromChorus: 0,
        choruses: perBatch,
      );
      for (final entry in playing.stems.entries) {
        final source = _soloud.setBufferStream(
          maxBufferSizeBytes: 0x7fffffff,
          bufferingType: BufferingType.released,
          bufferingTimeNeeds: 0.5,
          sampleRate: entry.value.sampleRate,
          channels: entry.value.channels >= 2 ? Channels.stereo : Channels.mono,
          format: BufferType.s16le,
        );
        // The filter has to be switched on before the voice is played: a
        // voice started without it goes on without it for good.
        source.filters.pitchShiftFilter.activate();
        sources.add(source);
        recordingStreams[entry.key] = source;
        _soloud.addAudioDataStream(source, laid[entry.key]!);
      }
      recordingStream = _RecordingStream(
        recording: playing,
        sources: recordingStreams,
        loop: request.loop,
        countInBeats: countInBeats,
        perBatch: perBatch,
        nextChorus: perBatch,
        secondsAdded: _recordingSeconds(
          playing,
          request.loop,
          perBatch,
          countInBeats,
        ),
      );
    }

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
        // Silent, not skipped: see where the streams are built.
        volume: playing == null ? _volumes[entry.key]! : 0,
        // Each part in its own place. The stems are already separate
        // voices, so this is the whole of the stereo: nothing in the
        // renderer has to know, and the mono buffers stay mono.
        pan: entry.key.pan,
      );
    }
    for (final entry in recordingStreams.entries) {
      final handle = _soloud.play(
        entry.value,
        paused: true,
        volume: _volumes[instrumentFor(entry.key)]!,
        // The same place the live band's part sits, so playing a take
        // back does not rearrange the room.
        pan: instrumentFor(entry.key).pan,
      );
      _recordingHandles[entry.key] = handle;
      _applyShift(entry.value, handle, playing!.shift);
    }
    if (take != null) {
      _takeHandle = _soloud.play(take, paused: true, volume: _takeVolume);
      // The recording began before the band did (the band has to be
      // written first), so wind past that much of it.
      if (leadIn > Duration.zero) _soloud.seek(_takeHandle!, leadIn);
    }
    final group = _soloud.createVoiceGroup();
    _soloud.addVoicesToGroup(group, [
      _countInHandle!,
      ?_takeHandle,
      ..._handles.values,
      ..._recordingHandles.values,
    ]);
    _soloud.setPause(group, false);
    _soloud.destroyVoiceGroup(group);

    _sources.addAll(sources);
    _recording = recordingStream;
    _clock = PlaybackClock(
      backing: backing,
      loop: request.loop,
      pickUpBeats: pickUpBeats,
    );

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
    _streamTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _topUp(stream, generation);
      if (recordingStream != null) {
        _topUpRecording(recordingStream, generation);
      }
    });
  }

  /// [backing] with [pickUpBeats] of its first time through the form taken
  /// off the front, leaving the count-in where it is: you still get
  /// counted in, you just come in at the bridge.
  @visibleForTesting
  static RenderedBacking fromPickUp(RenderedBacking backing, int beats) {
    if (beats <= 0) return backing;
    final countIn = backing.countInBeats * backing.samplesPerBeat * 2;
    final cut = beats * backing.samplesPerBeatByChorus.first * 2;
    Uint8List trim(Uint8List pcm) {
      if (countIn + cut >= pcm.length) return pcm;
      return Uint8List.fromList([
        ...pcm.sublist(0, countIn),
        ...pcm.sublist(countIn + cut),
      ]);
    }

    return RenderedBacking(
      stems: backing.stems,
      countIn: backing.countIn,
      sampleRate: backing.sampleRate,
      samplesPerBeat: backing.samplesPerBeat,
      samplesPerBeatByChorus: backing.samplesPerBeatByChorus,
      countInBeats: backing.countInBeats,
      introBeats: backing.introBeats,
      gain: backing.gain,
      batch: BackingBatch(
        pcm: {
          for (final entry in backing.batch.pcm.entries)
            entry.key: trim(entry.value),
        },
        clicks: trim(backing.batch.clicks),
        tails: backing.batch.tails,
        state: backing.batch.state,
      ),
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

  /// How many choruses of a recording to lay out at a time: about a
  /// minute's worth, and never fewer than two.
  ///
  /// A recording is tens of megabytes, so a run has to be fed to the
  /// engine in pieces rather than written out whole before the first note.
  static int _chorusesPerBatch(BackingRequest request) {
    final beats = request.loop.lengthBeats;
    if (beats <= 0 || request.tempo <= 0) return 2;
    final seconds = beats * 60 / request.tempo;
    return math.max(2, (60 / seconds).ceil());
  }

  /// How long [choruses] of the recording run to, in the recording's own
  /// time, which is what its stream's clock counts in.
  static double _recordingSeconds(
    PlayableRecording recording,
    LoopRange loop,
    int choruses,
    int countInBeats,
  ) {
    final bpm = recording.take.bpm;
    if (bpm <= 0) return 0;
    return (loop.lengthBeats * choruses + countInBeats) * 60 / bpm;
  }

  /// Each stem cut to [choruses] of the run, ready for the engine.
  static Map<TakeStem, Uint8List> _layRecording(
    PlayableRecording recording, {
    required LoopRange loop,
    required int countInBeats,
    required int fromChorus,
    required int choruses,
  }) => {
    for (final entry in recording.stems.entries)
      entry.key: pcm16(
        layStem(
          entry.value,
          take: recording.take,
          loopStartBeat: loop.startBeat,
          loopBeats: loop.lengthBeats,
          choruses: choruses,
          countInBeats: countInBeats,
          fromChorus: fromChorus,
        ),
      ),
  };

  /// Puts the tempo and the key on a stem.
  ///
  /// The speed resamples, which is exact; the filter puts back whatever
  /// pitch that dragged along with it. The clamp is the filter's own
  /// limit, and a shift outside it is far past anything worth listening
  /// to anyway.
  void _applyShift(AudioSource source, SoundHandle handle, TakeShift shift) {
    _soloud.setRelativePlaySpeed(handle, shift.speed.clamp(0.05, 8.0));
    source.filters.pitchShiftFilter.shift(soundHandle: handle).value = shift
        .shift
        .clamp(0.05, 3.0);
  }

  /// Keeps the recording queued as far ahead as the band is.
  ///
  /// The comparison is in the recording's own time, because that is what
  /// the stream's own clock counts in: the play speed is the engine's
  /// business and cancels on both sides of it.
  void _topUpRecording(_RecordingStream stream, int generation) {
    if (stream.laying || generation != _generation) return;
    final first = stream.sources.values.firstOrNull;
    if (first == null) return;
    final played = _soloud.getStreamTimeConsumed(first).inMilliseconds / 1000;
    if (stream.secondsAdded - played > 45) return;

    stream.laying = true;
    try {
      final laid = _layRecording(
        stream.recording,
        loop: stream.loop,
        countInBeats: stream.countInBeats,
        fromChorus: stream.nextChorus,
        choruses: stream.perBatch,
      );
      for (final entry in stream.sources.entries) {
        if (laid[entry.key] case final pcm?) {
          _soloud.addAudioDataStream(entry.value, pcm);
        }
      }
      stream
        ..nextChorus += stream.perBatch
        ..secondsAdded += _recordingSeconds(
          stream.recording,
          stream.loop,
          stream.perBatch,
          0,
        );
    } catch (e) {
      debugPrint('Could not lay out more of the recording: $e');
    }
    stream.laying = false;
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

  /// The voice the snippet is playing on, kept rather than dropped.
  ///
  /// It used to be thrown away the moment it started, which made a
  /// snippet a thing you could only fire: no position, no seeking, no
  /// stopping it short. Holding it is the whole of what lets a phrase be
  /// scrubbed.
  SoundHandle? _snippetHandle;

  /// Whether a snippet is sounding, held, or done: what the Pause and Stop
  /// bar shows on every screen that plays one.
  ///
  /// It lives here, not on the screens, because thirty-odd screens play
  /// snippets and every one of them needed the same two buttons. One
  /// place knowing means one bar does for all of them.
  final snippetState = ValueNotifier(SnippetState.idle);

  /// Watches for the snippet coming to its end on its own.
  Timer? _snippetWatch;

  void _snippetEnded() {
    _snippetWatch?.cancel();
    _snippetWatch = null;
    snippetState.value = SnippetState.idle;
  }

  /// Plays a short WAV once: the drills' "hear it".
  /// Each new one replaces the last, so tapping twice doesn't pile them up,
  /// and the band stops: a drill played over the changes was two things
  /// sounding at once, usually in two different keys.
  ///
  /// With a [shift] it is moved in pitch, in tempo, or both, by the same
  /// two knobs the recorded band is moved with: the speed resamples,
  /// which is exact, and the filter puts back whatever pitch that dragged
  /// along with it.
  ///
  /// [from] starts it part way in, which is what a phrase being scrubbed
  /// asks for. It is a point in the recording rather than in what you
  /// hear: played at half speed the same point arrives twice as late, and
  /// it is still the same note of the line.
  Future<void> playSnippet(
    Uint8List wav, {
    TakeShift? shift,
    Duration from = Duration.zero,
  }) async {
    // The band stops first. Two things playing at once is two things
    // nobody asked for: pressing Hear It on a drill while the changes
    // were going left them both sounding, over each other, in different
    // keys as often as not. The generation moves so a batch already on
    // its way does not arrive after this.
    _generation++;
    await _stopCurrent();
    final source = await _soloud.loadMem('snippet.wav', wav);
    _snippet = source;
    // Paused first in every case now, not only for a shift: a seek has
    // to land before the first sample is heard, or the start of the file
    // comes out before the point that was asked for.
    final moved = shift != null && (shift.speed != 1 || shift.shift != 1);
    if (moved) source.filters.pitchShiftFilter.activate();
    final handle = _soloud.play(source, paused: true);
    _snippetHandle = handle;
    if (moved) _applyShift(source, handle, shift);
    if (from > Duration.zero) _soloud.seek(handle, from);
    _soloud.setPause(handle, false);
    snippetState.value = SnippetState.playing;
    _snippetWatch?.cancel();
    _snippetWatch = Timer.periodic(const Duration(milliseconds: 250), (_) {
      try {
        if (_snippetHandle != handle ||
            !_soloud.getIsValidVoiceHandle(handle)) {
          if (_snippetHandle == handle) _snippetHandle = null;
          _snippetEnded();
        }
      } catch (_) {
        _snippetEnded();
      }
    });
  }

  /// How far into the recording the snippet has got, or null when there
  /// is nothing playing.
  ///
  /// In the recording's own time, not the listener's: see [playSnippet].
  Duration? snippetPosition() {
    final handle = _snippetHandle;
    if (handle == null) return null;
    try {
      if (!_soloud.getIsValidVoiceHandle(handle)) return null;
      return _soloud.getPosition(handle);
    } catch (e) {
      debugPrint('Could not read the snippet position: $e');
      return null;
    }
  }

  /// Moves the playing snippet to [to]. Does nothing if none is playing,
  /// which is the case a scrub bar hits every time somebody drags it
  /// before pressing play.
  Future<void> seekSnippet(Duration to) async {
    final handle = _snippetHandle;
    if (handle == null) return;
    try {
      if (_soloud.getIsValidVoiceHandle(handle)) _soloud.seek(handle, to);
    } catch (e) {
      debugPrint('Could not move the snippet: $e');
    }
  }

  /// Holds the snippet where it is, and lets it go again.
  ///
  /// Paused rather than stopped, so carrying on means carrying on from
  /// the note it was on rather than from wherever the bar was set.
  Future<void> pauseSnippet() async => _setSnippetPaused(true);

  Future<void> resumeSnippet() async => _setSnippetPaused(false);

  Future<void> _setSnippetPaused(bool paused) async {
    final handle = _snippetHandle;
    if (handle == null) return;
    try {
      if (_soloud.getIsValidVoiceHandle(handle)) {
        _soloud.setPause(handle, paused);
        snippetState.value = paused
            ? SnippetState.paused
            : SnippetState.playing;
      }
    } catch (e) {
      debugPrint('Could not hold the snippet: $e');
    }
  }

  /// Stops the snippet where it is.
  Future<void> stopSnippet() async {
    final handle = _snippetHandle;
    _snippetHandle = null;
    _snippetEnded();
    if (handle == null) return;
    try {
      await _soloud.stop(handle);
    } catch (e) {
      debugPrint('Could not stop the snippet: $e');
    }
  }

  /// Plays [wav] over and over until [stopLoop]: the metronome's bar of
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

  /// Pauses every instrument at once. They're paused as one voice group, the
  /// same way they're started, so they stop on the same sample and resume
  /// in step, and the clock (the count-in stem) stops with them.
  void pause() => _setPaused(true);

  /// Carries on from exactly where [pause] left off.
  void resume() => _setPaused(false);

  void _setPaused(bool paused) {
    final handles = [
      ?_countInHandle,
      ?_takeHandle,
      ..._handles.values,
      ..._recordingHandles.values,
    ];
    if (handles.isEmpty || paused == _paused) return;
    final group = _soloud.createVoiceGroup();
    _soloud.addVoicesToGroup(group, handles);
    _soloud.setPause(group, paused);
    _soloud.destroyVoiceGroup(group);
    _paused = paused;
  }

  /// Sets one instrument's volume (0 = silent, 1 = full) immediately.
  ///
  /// When real players are playing, the channel is theirs: the generated
  /// instrument behind it stays silent whatever the mixer says. That is
  /// what lets somebody drop the comp and sit in the chair while the real
  /// bass and drums keep going.
  void setVolume(Instrument instrument, double volume) {
    _volumes[instrument] = volume;
    final playingRecording = _recording != null;
    final handle = _handles[instrument];
    if (handle != null) {
      _soloud.setVolume(handle, playingRecording ? 0 : volume);
    }
    for (final entry in _recordingHandles.entries) {
      if (instrumentFor(entry.key) == instrument) {
        _soloud.setVolume(entry.value, volume);
      }
    }
  }

  Future<void> stop() async {
    _generation++;
    await _stopCurrent();
    if (Platform.isAndroid && !_mixWithOthers) await _session?.setActive(false);
  }

  /// Stops everything this player is sounding: the band, a take, and the
  /// snippet the drills play.
  ///
  /// The snippet is in here rather than left to the screens because the
  /// band starting and a snippet starting both come through here, so one
  /// place covers every direction: pressing Hear It stops the band,
  /// pressing play on the band stops a snippet, and stopping stops both.
  /// It used to stop only the band, which left the two overlapping either
  /// way round and left a snippet running after stop() had been called.
  Future<void> _stopCurrent() async {
    _streamTimer?.cancel();
    _streamTimer = null;
    _stream = null;
    final snippet = _snippet;
    final snippetHandle = _snippetHandle;
    _snippet = null;
    _snippetHandle = null;
    if (snippetHandle != null) _snippetEnded();
    final handles = [
      ?_countInHandle,
      ?_takeHandle,
      ..._handles.values,
      ..._recordingHandles.values,
    ];
    final sources = [..._sources];
    _countInHandle = null;
    _takeHandle = null;
    _clickSource = null;
    _recording = null;
    _recordingHandles.clear();
    _handles.clear();
    _sources.clear();
    _clock = null;
    _paused = false;
    if (snippetHandle != null) {
      try {
        await _soloud.stop(snippetHandle);
      } catch (e) {
        debugPrint('Could not stop the snippet: $e');
      }
    }
    if (snippet != null) {
      try {
        await _soloud.disposeSource(snippet);
      } catch (e) {
        debugPrint('Could not let the snippet go: $e');
      }
    }
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
  PlaybackClock({
    required this.backing,
    required this.loop,
    this.pickUpBeats = 0,
  });

  final RenderedBacking backing;
  final LoopRange loop;

  /// How far into the first time through the form the band came in. The
  /// beats before it were never played, so the clock counts them as
  /// already gone: the first chorus is short, the rest are whole.
  final int pickUpBeats;
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

    var left = samples - countInSamples;
    if (left < 0) left = 0;
    // An intro, once, before the loop: its own bars, just ahead of the
    // loop's first, and the first time round.
    final introSamples = backing.introBeats * _samplesPerBeat(0);
    if (left < introSamples) {
      return PlaybackPosition(
        tuneBeat:
            loop.startBeat -
            backing.introBeats +
            (left / _samplesPerBeat(0)).floor(),
        chorus: 0,
      );
    }
    left -= introSamples;
    // Walk the passes off one at a time: they aren't all the same length
    // when the tempo is climbing.
    left += pickUpBeats * _samplesPerBeat(0);
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

/// Bookkeeping for an imported recording as it is fed to the engine.
class _RecordingStream {
  _RecordingStream({
    required this.recording,
    required this.sources,
    required this.loop,
    required this.countInBeats,
    required this.perBatch,
    required this.nextChorus,
    required this.secondsAdded,
  });

  final PlayableRecording recording;
  final Map<TakeStem, AudioSource> sources;
  final LoopRange loop;
  final int countInBeats;

  /// How many choruses go in at a time.
  final int perBatch;

  /// The chorus of the run the next piece starts at.
  int nextChorus;

  /// How much has been handed over, in the recording's own time.
  double secondsAdded;
  bool laying = false;
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

/// Where the snippet is: what the Pause and Stop bar needs to know.
enum SnippetState { idle, playing, paused }
