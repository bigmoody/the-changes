// Generates the band's audio for a looped section.
//
// This is pure Dart maths, no audio plugin involved, so it's easy to test
// and runs in a background isolate.
//
//   [ count-in ][ batch 1: several passes ][ batch 2 ][ ... ]
//
// Each instrument is written in batches of about a minute. Every batch is
// played differently (see walking_bass.dart, piano_comping.dart and
// drum_patterns.dart), and batches join seamlessly: a batch carries the
// sound still ringing at its end into the start of the next one, and the
// players carry on from where they left off.

import 'dart:math' as math;
import 'dart:typed_data';

import '../music/arrangement.dart';
import '../music/loop_range.dart';
import '../music/swing.dart';
import '../music/tune.dart';
import '../music/imported_part.dart';
import 'arpeggios.dart';
import 'drum_patterns.dart';
import 'guitar_comping.dart';
import 'instruments.dart';
import 'piano_comping.dart';
import 'sample_bank.dart';
import 'walking_bass.dart';

/// What comes off the bottom of the bass before the shelf goes on.
///
/// One pass, gently. An upright's low roots pile up below this and turn
/// woolly, but the ear takes the pitch from the overtones above it, so a
/// light hand here costs nothing and a heavy one made it thin.
const bassCutBelow = 120.0;

/// The high shelf that puts the bass on a phone speaker: everything above
/// [bassLiftFrom] is lifted by [bassLift].
///
/// Chosen by listening to a ladder of them rather than by argument. Low
/// enough a corner that it brings up the body of the note rather than
/// finger noise, and gentle enough that it stays a bass.
const bassLiftFrom = 1500.0;
const bassLift = 4.0;

/// How much of the bass's harmonics to lift, and where.
///
/// A phone speaker plays almost nothing below 300 Hz, so what is heard of
/// an upright is its overtones, and without this the bass simply is not
/// there on a phone. It is a big lift, though, and it lands on the part of
/// the pluck that reads as attack, so it is easy to take too far.
const bassPresence = 2.6;

/// How much room to put around the guitar.
///
/// More than anything else in the band gets, because it starts with less
/// than anything else has: the recordings are mostly the magnetic pickup,
/// which hears the string and no room whatsoever. An archtop in a room is
/// what the ear expects, and a note with nothing behind it is the sound of
/// a sampler.
const guitarRoom = 0.26;

/// How far a strum strays from the beat, either way, in seconds.
///
/// A comper is never exactly on the grid. Without this the guitar lands on
/// the same sample of every bar for a whole chorus, which is most of what
/// makes it sound like a machine rather than a player. Small enough that
/// it reads as feel rather than as a mistake: twelve milliseconds is about
/// a fiftieth of a beat at a medium tempo.
const guitarTimingSpread = 0.012;

/// How much a strum's strength wanders from what was written, either way.
///
/// The rhythms are written with fixed velocities, so bar after bar was
/// struck at exactly the same strength. This is per stroke rather than per
/// string, because a hand is hard or soft for a whole chord; the strings
/// within one vary far less, and that is the small figure below.
const guitarVelocitySpread = 0.18;

/// How loud a guitar note is played, before velocity and the mixer.
///
/// Set by measurement rather than by taste: the whole guitar set is
/// normalised together, so a new library lands at its own level and this
/// is what puts it back where the band expects. The figure that decides it
/// is the bass, which has to stay audible above the chords on a phone
/// speaker, and there is a test that says so.
const guitarLevel = 0.28;

/// The instruments in the backing band, in mixer order.
enum Instrument {
  /// The chords: piano or guitar, whichever [Comping] says.
  chords('Chords'),
  bass('Bass'),
  drums('Drums'),

  /// Each chord as a broken chord, when [BackingRequest.arpeggios] asks
  /// for it. Only rendered then; the other parts are always there.
  arpeggio('Arpeggios'),

  /// A part read out of a MIDI file, when [BackingRequest.imported] has
  /// one. Like the arpeggios, only rendered when it is asked for.
  imported('Imported');

  const Instrument(this.label);
  final String label;
}

class BackingRequest {
  const BackingRequest({
    required this.tune,
    required this.loop,
    required this.tempo,
    this.countInBars = 1,
    this.sampleRate = 44100,
    this.seed = 0,
    this.samples,
    this.comping = Comping.piano,
    this.arpeggios = false,
    this.arpeggioSound = Comping.piano,
    this.arpeggioStart = ArpeggioStart.root,
    this.arrangement = Arrangement.keepGoing,
    this.imported,
  });

  final Tune tune;
  final LoopRange loop;

  /// Beats per minute.
  final int tempo;
  final int countInBars;
  final int sampleRate;

  /// Picks which variations the band plays. Same seed, same performance.
  final int seed;

  /// Recorded instruments. Without them the band falls back to synthesised
  /// sounds (used in tests, or if the samples fail to load).
  final SampleBank? samples;

  /// Who plays the chords.
  final Comping comping;

  /// Whether to add a part playing each chord as a broken chord.
  final bool arpeggios;

  /// What the arpeggios are played on.
  final Comping arpeggioSound;

  /// Which chord tone they start from.
  final ArpeggioStart arpeggioStart;

  /// How the band plays the form: how many choruses, and what happens on
  /// each of them.
  final Arrangement arrangement;

  /// A part from a MIDI file playing alongside the band, already in the
  /// key being played. Null when there isn't one, which is the usual case.
  final ImportedPart? imported;

  BackingRequest withSamples(SampleBank? samples) => BackingRequest(
    tune: tune,
    loop: loop,
    tempo: tempo,
    countInBars: countInBars,
    sampleRate: sampleRate,
    seed: seed,
    samples: samples,
    comping: comping,
    arpeggios: arpeggios,
    arpeggioSound: arpeggioSound,
    arpeggioStart: arpeggioStart,
    arrangement: arrangement,
    imported: imported,
  );
}

/// Where each player got to, so the next batch continues from there.
class BandState {
  const BandState({
    this.bassPitch,
    this.pianoVoicing,
    this.guitarVoicing,
    this.arpeggioRoot,
  });

  final int? bassPitch;

  /// The pianist's hand position, so the next batch carries on from the
  /// same voicing instead of jumping registers at the join.
  final List<int>? pianoVoicing;

  /// The guitarist's last shape, likewise.
  final List<int>? guitarVoicing;

  /// Where the arpeggios had got to: the note the last one started from.
  final int? arpeggioRoot;
}

/// A stretch of playing, as raw 16-bit PCM per instrument (no WAV header).
class BackingBatch {
  const BackingBatch({
    required this.pcm,
    required this.clicks,
    required this.tails,
    required this.state,
  });

  final Map<Instrument, Uint8List> pcm;

  /// The count-in clicks, then silence for as long as the batch lasts. It's
  /// streamed alongside the band and never loops, so its playing position is
  /// the clock the app keeps time by, which a tempo ramp would otherwise
  /// leave behind.
  final Uint8List clicks;

  /// What's still ringing at the end, to mix into the next batch.
  final Map<Instrument, Float32List> tails;
  final BandState state;
}

class RenderedBacking {
  const RenderedBacking({
    required this.stems,
    required this.countIn,
    required this.sampleRate,
    required this.samplesPerBeat,
    required this.samplesPerBeatByChorus,
    required this.countInBeats,
    required this.gain,
    required this.batch,
  });

  /// One looping WAV per instrument: the first batch with its ringing tail
  /// wrapped back to the start. Used when not streaming (and in tests).
  final Map<Instrument, Uint8List> stems;

  /// The count-in clicks, kept separate so muting drums doesn't silence
  /// them. This is the loop the rest of the app keeps time by.
  final Uint8List countIn;
  final int sampleRate;

  /// Beats are a whole number of samples long, so timing never drifts.
  /// This is the first pass's; a tempo ramp changes it as it goes.
  final int samplesPerBeat;

  /// How long a beat lasts on each pass through the form, for as many
  /// passes as the tempo keeps changing. The last entry holds from then on,
  /// so the list is short even for a performance that goes on all night.
  final List<int> samplesPerBeatByChorus;
  final int countInBeats;

  /// The volume scaling applied to everything; later batches reuse it.
  final double gain;

  /// The first batch, for streaming: count-in silence then the playing.
  final BackingBatch batch;

  Duration get loopStart => Duration(
    microseconds: (countInBeats * samplesPerBeat * 1000000 / sampleRate)
        .round(),
  );
}

/// How late the off-beat eighth lands for everybody in the band who plays
/// one, on the pass starting at [firstChorus].
///
/// Worked out once for the whole pass so the drummer, the bass and the
/// comper cannot land in different places. A tempo ramp moves it between
/// passes rather than inside one, which is what keeps the band together
/// while it speeds up. Each part still decides for itself whether it is
/// swinging at all: this is only how far.
double swingForPass(BackingRequest request, int firstChorus) =>
    swingAt(tempoForChorus(request, firstChorus));

/// The tempo on a given pass through the form: the tempo asked for, plus
/// whatever a tempo ramp has added to it by then.
int tempoForChorus(BackingRequest request, int chorus) =>
    request.arrangement.ramp.tempoAt(chorus, request.tempo);

/// How many samples a beat lasts on that pass. Beats are a whole number of
/// samples long, so timing never drifts.
int samplesPerBeatFor(BackingRequest request, int chorus) =>
    (60 / tempoForChorus(request, chorus) * request.sampleRate).round();

/// How long a beat lasts on each pass through the form, up to the point
/// where a ramp stops changing it (one entry when there's no ramp).
List<int> samplesPerBeatByChorus(BackingRequest request) {
  final ramp = request.arrangement.ramp;
  var passes = ramp.chorusesToTop(request.tempo) + 1;
  final total = request.arrangement.choruses;
  if (total != null) passes = math.min(passes, math.max(total, 1));
  return [
    for (var chorus = 0; chorus < passes; chorus++)
      samplesPerBeatFor(request, chorus),
  ];
}

/// How many passes through the loop each batch holds: about a minute's worth.
int chorusesPerBatch(BackingRequest request) {
  final samplesPerBeat = (60 / request.tempo * request.sampleRate).round();
  final loopSamples = request.loop.lengthBeats * samplesPerBeat;
  return (60 * request.sampleRate / loopSamples).ceil().clamp(1, 32);
}

/// How many passes batch [batch] actually holds: a batch's worth, or what's
/// left of an arrangement that ends. Zero once it has been played out.
int chorusesIn(BackingRequest request, int batch) {
  final perBatch = chorusesPerBatch(request);
  final total = request.arrangement.choruses;
  if (total == null) return perBatch;
  return (total - batch * perBatch).clamp(0, perBatch);
}

/// The sound still ringing at the end of a batch, as PCM to play out after
/// the last one: an arrangement that ends shouldn't be cut off mid-chord.
Uint8List ringOut(Float32List tail, double gain, int sampleRate) =>
    Uint8List.sublistView(_encodeWav(tail, sampleRate, gain), 44);

/// Renders the first batch, including the count-in, and works out the volume
/// scaling the whole performance uses.
RenderedBacking renderBacking(BackingRequest request) {
  final parts = _renderParts(request, batch: 0, withCountIn: true);
  final sampleRate = request.sampleRate;
  final loopStart = parts.offset;

  // Scale everything by the same amount, based on the loudest moment of the
  // whole band, so the balance between instruments is preserved.
  var peak = 0.0;
  for (var i = 0; i < parts.length; i++) {
    var sum = parts.clicks.buffer[i];
    for (final mix in parts.mixes.values) {
      sum += mix.buffer[i];
    }
    peak = math.max(peak, sum.abs());
  }
  // The level for the whole performance is set here, from the first batch.
  // When the choruses differ (a head in two before the solos walk), a later
  // one can be fuller than this, so leave it a little more room.
  final headroom = request.arrangement.isPlain ? 0.85 : 0.78;
  final gain = peak > 0 ? headroom / peak : 1.0;

  // As looping files the tails wrap round to the loop start; when streamed
  // they go into the next batch instead.
  Uint8List loopingStem(_Mix mix) {
    final wrapped = Float32List.fromList(
      Float32List.sublistView(mix.buffer, 0, parts.length),
    );
    for (
      var i = parts.length;
      i < mix.buffer.length && loopStart + i - parts.length < wrapped.length;
      i++
    ) {
      wrapped[loopStart + i - parts.length] += mix.buffer[i];
    }
    return _encodeWav(wrapped, sampleRate, gain);
  }

  return RenderedBacking(
    stems: {
      for (final entry in parts.mixes.entries)
        entry.key: loopingStem(entry.value),
    },
    countIn: _encodeWav(
      Float32List.sublistView(parts.clicks.buffer, 0, parts.length),
      sampleRate,
      gain,
    ),
    sampleRate: sampleRate,
    samplesPerBeat: parts.samplesPerBeat,
    samplesPerBeatByChorus: samplesPerBeatByChorus(request),
    countInBeats: request.countInBars * request.tune.beatsPerBar,
    gain: gain,
    batch: parts.toBatch(gain, sampleRate),
  );
}

/// The next stretch of playing, continuing seamlessly from the last batch.
BackingBatch renderBatch(
  BackingRequest request, {
  required int batch,
  required double gain,
  required BandState state,
  required Map<Instrument, Float32List> carryIn,
}) {
  final parts = _renderParts(
    request,
    batch: batch,
    withCountIn: false,
    state: state,
  );
  for (final entry in parts.mixes.entries) {
    final tail = carryIn[entry.key];
    if (tail == null) continue;
    final buffer = entry.value.buffer;
    for (var i = 0; i < tail.length && i < buffer.length; i++) {
      buffer[i] += tail[i];
    }
  }
  return parts.toBatch(gain, request.sampleRate);
}

/// Everything the band plays in one batch, before volume scaling.
class _Parts {
  _Parts({
    required this.mixes,
    required this.clicks,
    required this.length,
    required this.offset,
    required this.samplesPerBeat,
    required this.state,
  });

  final Map<Instrument, _Mix> mixes;
  final _Mix clicks;

  /// Samples of actual playing; anything past this is the ringing tail.
  final int length;

  /// Where the playing starts (after the count-in, if there is one).
  final int offset;
  final int samplesPerBeat;
  final BandState state;

  BackingBatch toBatch(double gain, int sampleRate) => BackingBatch(
    clicks: Uint8List.sublistView(
      _encodeWav(
        Float32List.sublistView(clicks.buffer, 0, length),
        sampleRate,
        gain,
      ),
      44,
    ),
    pcm: {
      for (final entry in mixes.entries)
        entry.key: Uint8List.sublistView(
          _encodeWav(
            Float32List.sublistView(entry.value.buffer, 0, length),
            sampleRate,
            gain,
          ),
          44,
        ),
    },
    tails: {
      for (final entry in mixes.entries)
        entry.key: Float32List.fromList(
          Float32List.sublistView(entry.value.buffer, length),
        ),
    },
    state: state,
  );
}

_Parts _renderParts(
  BackingRequest request, {
  required int batch,
  required bool withCountIn,
  BandState state = const BandState(),
}) {
  final tune = request.tune;
  final loop = request.loop;
  final bank = request.samples;
  final sampleRate = request.sampleRate;
  final beatsPerBar = tune.beatsPerBar;
  final choruses = chorusesIn(request, batch);
  // Which pass through the form this batch starts on, so the arrangement
  // knows where it has got to.
  final arrangement = request.arrangement;
  final firstChorus = batch * chorusesPerBatch(request);

  // A tempo ramp gives every pass through the form its own tempo, so a beat
  // is a different number of samples in each. These are the lengths of each
  // pass in this batch, and where each one starts.
  final samplesPerBeatOf = [
    for (var chorus = 0; chorus < math.max(choruses, 1); chorus++)
      samplesPerBeatFor(request, firstChorus + chorus),
  ];
  final chorusStart = <int>[];
  var playing = 0;
  for (final perBeat in samplesPerBeatOf) {
    chorusStart.add(playing);
    playing += loop.lengthBeats * perBeat;
  }
  final samplesPerBeat = samplesPerBeatOf.first;
  final offset = withCountIn
      ? request.countInBars * beatsPerBar * samplesPerBeat
      : 0;
  final length = offset + (choruses == 0 ? 0 : playing);
  // Room at the end for sounds that ring past the batch.
  final pad = sampleRate;

  _Mix newMix() =>
      _Mix(sampleRate: sampleRate, loopStart: offset, length: length + pad);
  final clicks = newMix();
  final mixes = {
    for (final part in Instrument.values)
      if (switch (part) {
        Instrument.arpeggio => request.arpeggios,
        Instrument.imported => request.imported?.isEmpty == false,
        _ => true,
      })
        part: newMix(),
  };
  final piano = mixes[Instrument.chords]!;
  final bass = mixes[Instrument.bass]!;
  final drums = mixes[Instrument.drums]!;

  // Each batch gets its own random choices, so nothing ever repeats.
  final seed = request.seed * 31 + batch * 7919;
  final human = math.Random(seed + 1);
  final takesRandom = math.Random(seed + 2);
  final kit = bank == null ? DrumKit(sampleRate, math.Random(seed + 3)) : null;
  final pianoCache = <(int, int), Float32List>{};

  // Which pass through the form a beat belongs to, within this batch.
  int chorusOf(double beat) =>
      (beat ~/ loop.lengthBeats).clamp(0, samplesPerBeatOf.length - 1);

  // Beat (from the start of this batch's playing) to sample index.
  int at(double beat) {
    final chorus = chorusOf(beat);
    final within = beat - chorus * loop.lengthBeats;
    return offset +
        chorusStart[chorus] +
        (within * samplesPerBeatOf[chorus]).round();
  }

  // How long a beat lasts where this one falls: a ramp makes it shorter as
  // the performance goes on.
  double secondsPerBeatAt(double beat) =>
      samplesPerBeatOf[chorusOf(beat)] / sampleRate;

  // ── Count-in ───────────────────────────────────────────────────────────
  if (withCountIn) {
    for (var beat = 0; beat < request.countInBars * beatsPerBar; beat++) {
      clicks.tone(
        beat * samplesPerBeat,
        beat % beatsPerBar == 0 ? 1760 : 1320,
        0.06,
        0.35,
        decay: 0.02,
      );
    }
  }

  final swing = swingForPass(request, firstChorus);

  // ── Bass ───────────────────────────────────────────────────────────────
  final chords = [
    for (final slot in loop.slotsIn(tune))
      (
        slot.chord,
        (math.min(slot.endBeat, loop.endBeat) -
                math.max(slot.startBeat, loop.startBeat))
            .toInt(),
      ),
  ];
  // Which pass through the form a beat falls in, and which bar of it; the
  // arrangement is written in those terms.
  bool sounds(LayOut part, double beat) {
    if (arrangement.isPlain) return true;
    final within = beat < 0 ? 0.0 : beat;
    final chorus = within ~/ loop.lengthBeats;
    final bar = (within - chorus * loop.lengthBeats) ~/ beatsPerBar;
    return arrangement.plays(part, firstChorus + chorus, bar);
  }

  final walk = switch (tune.style.bass) {
    BassStyle.walking => walkingBassLine,
    BassStyle.twoFeel => twoFeelBassLine,
    BassStyle.bossa => bossaBassLine,
    BassStyle.funk => funkBassLine,
    BassStyle.calypso => calypsoBassLine,
  };
  // In two on the head, walking for the solos, but only where the bassist
  // would be walking to begin with.
  bool inTwo(int chorus) =>
      tune.style.bass == BassStyle.walking &&
      arrangement.planFor(firstChorus + chorus).twoFeel;

  final List<BassNote> bassLine;
  if (choruses == 0) {
    bassLine = const [];
  } else if (!List.generate(choruses, inTwo).contains(true)) {
    bassLine = walk(
      chords,
      choruses: choruses,
      random: math.Random(seed),
      swing: swing,
      beatsPerBar: beatsPerBar,
      startPitch: state.bassPitch,
    );
  } else {
    // The feel changes part-way through the batch, so the line is written a
    // chorus at a time, each carrying on from where the last one ended.
    final line = <BassNote>[];
    var from = state.bassPitch;
    for (var chorus = 0; chorus < choruses; chorus++) {
      final pass = (inTwo(chorus) ? twoFeelBassLine : walk)(
        chords,
        choruses: 1,
        random: math.Random(seed + chorus * 101),
        swing: swing,
        beatsPerBar: beatsPerBar,
        startPitch: from,
      );
      final shift = chorus * loop.lengthBeats;
      for (final note in pass) {
        line.add((
          pitch: note.pitch,
          beat: note.beat + shift,
          length: note.length,
          velocity: note.velocity,
        ));
      }
      if (pass.isNotEmpty) from = pass.last.pitch;
    }
    bassLine = line;
  }

  for (final note in bassLine) {
    if (!sounds(LayOut.bass, note.beat)) continue;
    if (bank != null) {
      final recordings = bank.bass.at(note.pitch);
      bass.addRecording(
        at(note.beat),
        recordings[takesRandom.nextInt(recordings.length)],
        1.25 * note.velocity,
        holdSamples: (secondsPerBeatAt(note.beat) * note.length * sampleRate)
            .round(),
        releaseSamples: (0.06 * sampleRate).round(),
      );
    } else {
      bass.addSamples(
        at(note.beat),
        pluckedBass(
          midiToFrequency(note.pitch),
          secondsPerBeatAt(note.beat) * note.length,
          sampleRate,
          takesRandom,
          velocity: note.velocity,
        ),
        0.5,
      );
    }
  }

  // ── Piano ──────────────────────────────────────────────────────────────
  /// The keyboard part: the piano, or an imported SoundFont standing in
  /// its place. It keeps the piano's envelope either way, because the band
  /// decides how long a chord is held and the font has no say in it.
  void playPianoNote(
    int pitch,
    int start,
    double lengthBeats,
    double velocity, {
    _Mix? into,
    double level = 1,
    SampledInstrument? instrument,
    required double beatSeconds,
  }) {
    final target = into ?? piano;
    if (bank != null) {
      final sound = instrument ?? bank.piano;
      final (shift, layers) = sound.nearest(pitch);
      // Softer hits use the softer recording, not just a quieter one.
      target.addRecording(
        start,
        sound.forVelocity(layers, velocity),
        0.52 * velocity * level,
        rate: math.pow(2, shift / 12).toDouble(),
        holdSamples: (beatSeconds * lengthBeats * sampleRate).round(),
        releaseSamples: (0.18 * sampleRate).round(),
      );
    } else {
      final duration = (beatSeconds * lengthBeats * 100).round();
      final note = pianoCache.putIfAbsent(
        (pitch, duration),
        () => electricPiano(midiToFrequency(pitch), duration / 100, sampleRate),
      );
      target.addSamples(start, note, 0.16 * velocity * level);
    }
  }

  final comper = Comper(math.Random(seed + 4))
    ..previousVoicing = state.pianoVoicing;
  final compSlots = loop.slotsIn(tune);
  final guitarist = GuitarComper(math.Random(seed + 6))
    ..previousVoicing = state.guitarVoicing;

  // ── Guitar ─────────────────────────────────────────────────────────────
  void playGuitarNote(
    int pitch,
    int start,
    double lengthBeats,
    double velocity, {
    _Mix? into,
    double level = 1,
    required double beatSeconds,
  }) {
    if (bank != null) {
      final (shift, takes) = bank.guitar.nearest(pitch);
      // A couple of cents either way. Six strings are never exactly in
      // tune with each other, and without it two notes from the same
      // recording are bit for bit the same sound, which is what makes a
      // busy comp rattle like a machine gun.
      final detune = 1 + (takesRandom.nextDouble() - 0.5) * 0.003;
      (into ?? piano).addRecording(
        start,
        takes[takesRandom.nextInt(takes.length)],
        guitarLevel * velocity * level,
        rate: math.pow(2, shift / 12).toDouble() * detune,
        holdSamples: (beatSeconds * lengthBeats * sampleRate).round(),
        // A guitarist lets go quickly (the string is damped, not left to
        // ring like a piano's sustain), but not so fast it clicks.
        releaseSamples: (0.1 * sampleRate).round(),
      );
    } else {
      playPianoNote(
        pitch,
        start,
        lengthBeats,
        velocity,
        into: into,
        level: level,
        beatSeconds: beatSeconds,
      );
    }
  }

  // Who is actually playing the chords, and the arpeggios. An imported
  // SoundFont plays through the pianist: the guitarist's voicings are
  // shapes a hand makes on a neck, and putting an organ through them
  // would be a strange thing to hear.
  final chordSound = bank?.playing(request.comping);
  final arpeggioSound = bank?.playing(request.arpeggioSound);

  final loopBars =
      (loop.endBeat - 1) ~/ beatsPerBar - loop.startBeat ~/ beatsPerBar + 1;
  if (request.comping == Comping.guitar) {
    for (var chorus = 0; chorus < choruses; chorus++) {
      final chorusBeat = chorus * loop.lengthBeats;
      for (var index = 0; index < compSlots.length; index++) {
        final slot = compSlots[index];
        final slotStart =
            math.max(slot.startBeat, loop.startBeat) - loop.startBeat;
        final beats =
            (math.min(slot.endBeat, loop.endBeat) -
                    math.max(slot.startBeat, loop.startBeat))
                .toInt();
        final tuneBeat = math.max(slot.startBeat, loop.startBeat);
        for (final hit in guitarist.comp(
          slot.chord,
          beats,
          style: tune.style.piano,
          groove: tune.style.drums,
          next: compSlots[(index + 1) % compSlots.length].chord,
          tempo: tempoForChorus(request, firstChorus + chorus),
          figure: tune.style.figure,
          beatsPerBar: beatsPerBar,
          swing: swing,
          beatInBar: (tuneBeat % beatsPerBar).toDouble(),
          // Counted from the start of the loop, as the drums count, so the
          // guitar's clave lines up with the drummer's.
          bar:
              tuneBeat ~/ beatsPerBar -
              loop.startBeat ~/ beatsPerBar +
              chorus * loopBars,
        )) {
          if (!sounds(LayOut.chords, chorusBeat + slotStart + hit.beat)) {
            continue;
          }
          // A strum: the pick crosses the strings one after another, low to
          // high going down, high to low (and quicker) coming up.
          final order = hit.strum == Strum.up
              ? hit.notes.reversed.toList()
              : hit.notes;
          final gap = switch (hit.strum) {
            Strum.down => 0.007,
            Strum.up => 0.007,
            Strum.together => 0.002,
          };
          // One stroke's worth of humanising, shared by every string in
          // it: the hand is early or late, and hard or soft, for the whole
          // chord rather than string by string.
          final push =
              ((human.nextDouble() + human.nextDouble()) / 2 * 2 - 1) *
              guitarTimingSpread;
          final strength =
              1 +
              ((human.nextDouble() + human.nextDouble()) / 2 * 2 - 1) *
                  guitarVelocitySpread;
          final nudge = (push * sampleRate).round();
          for (var v = 0; v < order.length; v++) {
            final offset =
                (v * (gap + human.nextDouble() * gap * 0.4) * sampleRate)
                    .round();
            playGuitarNote(
              order[v],
              math.max(
                0,
                at(chorusBeat + slotStart + hit.beat) + nudge + offset,
              ),
              hit.length,
              hit.velocity *
                  (hit.strum == Strum.up ? 0.75 : 1) *
                  strength *
                  // The pick does not cross every string alike.
                  (0.95 + human.nextDouble() * 0.1),
              beatSeconds: secondsPerBeatAt(chorusBeat + slotStart + hit.beat),
            );
          }
        }
      }
    }
  } else {
    for (var chorus = 0; chorus < choruses; chorus++) {
      final chorusBeat = chorus * loop.lengthBeats;
      for (var index = 0; index < compSlots.length; index++) {
        final slot = compSlots[index];
        final slotStart =
            math.max(slot.startBeat, loop.startBeat) - loop.startBeat;
        final beats =
            (math.min(slot.endBeat, loop.endBeat) -
                    math.max(slot.startBeat, loop.startBeat))
                .toInt();
        // The loop comes round again, so the chord after the last one is the
        // first one.
        final next = compSlots[(index + 1) % compSlots.length].chord;
        for (final hit in comper.comp(
          slot.chord,
          beats,
          tune.style.piano.feel,
          next: next,
          held: tune.style.piano == PianoStyle.held,
          calypso: tune.style.piano == PianoStyle.calypso,
          figure: tune.style.figure,
          beatsPerBar: beatsPerBar,
          swing: swing,
          beatInBar: (math.max(slot.startBeat, loop.startBeat) % beatsPerBar)
              .toDouble(),
        )) {
          if (!sounds(LayOut.chords, chorusBeat + slotStart + hit.beat)) {
            continue;
          }
          for (var v = 0; v < hit.notes.length; v++) {
            // Notes of a chord land a few milliseconds apart, as fingers do.
            final spread =
                (v * (0.003 + human.nextDouble() * 0.004) * sampleRate).round();
            playPianoNote(
              hit.notes[v],
              at(chorusBeat + slotStart + hit.beat) + spread,
              hit.length,
              hit.velocity * (0.9 + human.nextDouble() * 0.1),
              instrument: chordSound,
              beatSeconds: secondsPerBeatAt(chorusBeat + slotStart + hit.beat),
            );
          }
        }
      }
    }
  }

  // ── Arpeggios ──────────────────────────────────────────────────────────
  final arpeggio = mixes[Instrument.arpeggio];
  var arpeggioRoot = state.arpeggioRoot;
  if (arpeggio != null) {
    final line = arpeggioLine(
      chords,
      choruses: choruses,
      swing: tune.style.piano.feel == Feel.swing ? swing : straight,
      from: request.arpeggioStart,
      startNote: state.arpeggioRoot,
    );
    arpeggioRoot = line.lastStart;
    for (final note in line.notes) {
      if (request.arpeggioSound == Comping.guitar) {
        playGuitarNote(
          note.pitch,
          at(note.beat),
          note.length,
          note.velocity,
          into: arpeggio,
          // Its own level, not the comping's. The comper has to stay
          // under the bass; an arpeggio is a practice aid and is meant to
          // be followed, so it sits where the piano's does.
          level: 1.4,
          beatSeconds: secondsPerBeatAt(note.beat),
        );
      } else {
        playPianoNote(
          note.pitch,
          at(note.beat),
          note.length,
          note.velocity,
          into: arpeggio,
          // Gently played, for a mellow tone, but as present as the chords:
          // they're what you're listening for.
          level: 1.6,
          instrument: arpeggioSound,
          beatSeconds: secondsPerBeatAt(note.beat),
        );
      }
    }
  }

  // ── An imported part ───────────────────────────────────────────────────
  // Nothing is decided here. Somebody else wrote these notes and all this
  // does is put them where the form says and play them on whichever of the
  // three instruments was chosen.
  //
  // It keeps playing when the band lays out. Laying out drops the parts
  // the app writes so a player can cover them; a part somebody imported is
  // not one of those, and silencing it would be answering a question
  // nobody asked.
  final importedMix = mixes[Instrument.imported];
  final importedPart = request.imported;
  if (importedMix != null && importedPart != null) {
    final laid = importedPart.laidOver(
      choruses: choruses,
      formBeats: loop.lengthBeats.toDouble(),
      // The part is measured along the tune, so a loop takes the window of
      // it the band is playing rather than starting it again.
      fromBeat: loop.startBeat.toDouble(),
    );
    for (final note in laid) {
      // Off the ends of a keyboard there is nothing recorded to play, and
      // a file transposed a long way can ask for it.
      final pitch = note.pitch.clamp(21, 108);
      final start = at(note.beat);
      final beatSeconds = secondsPerBeatAt(note.beat);
      switch (importedPart.voice) {
        case PartVoice.piano:
          playPianoNote(
            pitch,
            start,
            note.beats,
            note.velocity,
            into: importedMix,
            level: 1.6,
            beatSeconds: beatSeconds,
          );
        case PartVoice.guitar:
          playGuitarNote(
            pitch,
            start,
            note.beats,
            note.velocity,
            into: importedMix,
            level: 1.3,
            beatSeconds: beatSeconds,
          );
        case PartVoice.bass:
          if (bank != null) {
            final recordings = bank.bass.at(pitch);
            importedMix.addRecording(
              start,
              recordings[takesRandom.nextInt(recordings.length)],
              1.1 * note.velocity,
              holdSamples: (beatSeconds * note.beats * sampleRate).round(),
              releaseSamples: (0.06 * sampleRate).round(),
            );
          } else {
            importedMix.addSamples(
              start,
              pluckedBass(
                midiToFrequency(pitch),
                beatSeconds * note.beats,
                sampleRate,
                takesRandom,
                velocity: note.velocity,
              ),
              0.5,
            );
          }
      }
    }
  }

  // ── Drums ──────────────────────────────────────────────────────────────
  // Avoid the same recorded take twice in a row (the "machine-gun" effect).
  final lastTake = <Object, int>{};
  Int16List pickTake(List<Int16List> takes) {
    var take = takesRandom.nextInt(takes.length);
    if (takes.length > 1 && take == lastTake[takes]) {
      take = (take + 1) % takes.length;
    }
    lastTake[takes] = take;
    return takes[take];
  }

  DrumSamples? recordedDrum(Drum drum) => switch (drum) {
    Drum.ride => bank?.ride,
    Drum.hiHatPedal => bank?.hiHatPedal,
    Drum.hiHatClosed => bank?.hiHatClosed,
    Drum.hiHatOpen => bank?.hiHatOpen,
    Drum.kick => bank?.kick,
    Drum.snare => bank?.snare,
    Drum.crossStick => bank?.crossStick,
    Drum.cowbell => bank?.cowbell,
    Drum.tomHigh => bank?.tomHigh,
    Drum.tomLow => bank?.tomLow,
  };

  Float32List? synthesisedDrum(Drum drum) => switch (drum) {
    Drum.ride => kit?.ride[takesRandom.nextInt(kit.ride.length)],
    Drum.hiHatPedal => kit?.hiHatPedal,
    Drum.hiHatClosed || Drum.hiHatOpen => kit?.closedHat,
    Drum.kick => kit?.kick,
    // The synthesised kit has no snare; its cross-stick stands in.
    Drum.snare || Drum.crossStick || Drum.cowbell => kit?.crossStick,
    Drum.tomHigh || Drum.tomLow => kit?.kick,
  };

  // The tune bars the loop covers (a loop can start mid-bar).
  final bars = <int>[];
  for (var beat = loop.startBeat; beat < loop.endBeat;) {
    final bar = beat ~/ beatsPerBar;
    bars.add(bar);
    beat = (bar + 1) * beatsPerBar;
  }

  final drumRandom = math.Random(seed + 5);
  for (var chorus = 0; chorus < choruses; chorus++) {
    for (var i = 0; i < bars.length; i++) {
      final trading = arrangement.planFor(firstChorus + chorus).trading;
      final theirs = arrangement.drummerHas(firstChorus + chorus, i);
      final hits = theirs
          ? drumSoloBar(
              feel: tune.style.drums,
              bar: i % trading.bars,
              of: trading.bars,
              beatsPerBar: beatsPerBar,
              random: drumRandom,
              swing: swing,
            )
          : drumBar(
              feel: tune.style.drums,
              bar: chorus * bars.length + i,
              beatsPerBar: beatsPerBar,
              random: drumRandom,
              swing: swing,
            );
      for (final hit in hits) {
        final beatInTune = bars[i] * beatsPerBar + hit.beat;
        if (beatInTune < loop.startBeat || beatInTune >= loop.endBeat) continue;
        final beat = chorus * loop.lengthBeats + beatInTune - loop.startBeat;
        final samples = recordedDrum(hit.drum);
        if (samples != null) {
          // How hard the stroke is decides which recording is used, which
          // changes its tone; how loud it comes out is the part's velocity.
          // Deciding the level by which layer was picked is what made the
          // odd beat jump 12 dB out of the groove.
          final layer = (hit.hard ? samples.length - 1 : 0);
          drums.addRecording(
            at(beat),
            // A drum hit has no rate and no loop: it is struck and it
            // decays, so it goes in as plain samples.
            SampledNote(pickTake(samples.layers[layer])),
            _drumLevel * hit.velocity * samples.levelling[layer],
          );
        } else {
          final sound = synthesisedDrum(hit.drum);
          if (sound != null) {
            drums.addSamples(at(beat), sound, hit.velocity * 0.35);
          }
        }
      }
    }
  }

  // Give the bass some presence. An upright's fundamental is 40–160 Hz,
  // which a phone speaker or a pair of earbuds barely reproduce at all, so
  // a bass that measures *louder* than the piano can still be inaudible.
  // What you actually hear on a small speaker is the note's harmonics, so
  // that's the range this lifts. It leaves the bottom alone, so it doesn't
  // turn boomy on a real speaker.
  addPresence(bass.buffer, sampleRate, hertz: 220, gain: bassPresence);

  // Put the band in a room. The recordings already have natural room sound,
  // so they need much less added. The reverb runs straight through the batch,
  // so its tail carries into the next one.
  //
  // The guitar is the exception, and it is why it sounded like a sampler
  // playing in a cupboard. The piano was recorded with a microphone in a
  // hall, so it arrives with a room already around it; the guitar is
  // mostly its magnetic pickup, which hears the string and nothing else at
  // all. Giving them the same small amount left the guitar bone dry, and
  // nothing sounds more synthetic than a note with no space behind it.
  addRoomReverb(
    piano.buffer,
    0,
    sampleRate,
    wet: bank == null
        ? 0.35
        : request.comping == Comping.guitar
        ? guitarRoom
        : 0.12,
  );
  if (mixes[Instrument.arpeggio] case final arpeggioMix?) {
    addRoomReverb(
      arpeggioMix.buffer,
      0,
      sampleRate,
      wet: request.arpeggioSound == Comping.guitar ? guitarRoom : 0.12,
    );
  }
  if (mixes[Instrument.imported] case final importedMix?) {
    addRoomReverb(
      importedMix.buffer,
      0,
      sampleRate,
      wet: request.imported?.voice == PartVoice.guitar ? guitarRoom : 0.12,
    );
  }
  if (bank == null) {
    addRoomReverb(drums.buffer, 0, sampleRate, wet: 0.25);
    addRoomReverb(bass.buffer, 0, sampleRate, wet: 0.08);
  }

  return _Parts(
    mixes: mixes,
    clicks: clicks,
    length: length,
    offset: offset,
    samplesPerBeat: samplesPerBeat,
    state: BandState(
      bassPitch: bassLine.isEmpty ? state.bassPitch : bassLine.last.pitch,
      pianoVoicing: comper.previousVoicing,
      guitarVoicing: guitarist.previousVoicing,
      arpeggioRoot: arpeggioRoot,
    ),
  );
}

/// How loud the recorded drums sit against the bass and piano (cymbals
/// measure quiet on average but cut through, so this was set by level
/// matching the stems to a typical trio balance).
const _drumLevel = 1.7;

/// A drum in a short example: [at] seconds in, how loud, and whether it
/// is a hard stroke, which changes the tone rather than the level, as it
/// does for the band.
///
/// Off the recorded kit rather than a synthesised tone. Where the thing
/// being taught is placement, a pitched metronome under a pitched
/// exercise is one more note to listen to: the time has to be the one
/// sound in the mix that is plainly not part of the music.
typedef SnippetDrum = ({double at, Drum drum, double velocity, bool hard});

/// The recordings of [drum] in [bank].
DrumSamples drumIn(SampleBank bank, Drum drum) => switch (drum) {
  Drum.ride => bank.ride,
  Drum.hiHatPedal => bank.hiHatPedal,
  Drum.hiHatClosed => bank.hiHatClosed,
  Drum.hiHatOpen => bank.hiHatOpen,
  Drum.kick => bank.kick,
  Drum.snare => bank.snare,
  Drum.crossStick => bank.crossStick,
  Drum.cowbell => bank.cowbell,
  Drum.tomHigh => bank.tomHigh,
  Drum.tomLow => bank.tomLow,
};

/// One note of a short example: [pitch] (MIDI) from [start] for [length],
/// both in seconds, on the piano, or the bass if [bass] is set.
typedef SnippetNote = ({
  int pitch,
  double start,
  double length,
  double velocity,
  bool bass,
});

/// A few notes on the recorded piano and bass, as a WAV file: what the
/// chord-tone drills play when you ask to hear a chord. With [guitar], the
/// piano's notes are played on the guitar instead. With [brightBass], the
/// bass is given some top end (the string's brightness and bite) for a
/// bass line heard on its own, which would otherwise be mostly lows a phone
/// speaker can't play.
/// How the bass in a snippet is treated.
enum BassTone {
  /// As recorded: an upright, body and all. Right when it is one note
  /// among several and nothing needs to cut through.
  natural,

  /// The boom taken out and nothing else. For a root sitting under other
  /// notes, where the low end muddies them but the bass is not the point.
  tight,

  /// Tightened and then driven, for a bass line heard on its own, which
  /// would otherwise be mostly lows a phone can't play. It is loud, so it
  /// is only right when the bass is the exercise.
  bright,
}

Uint8List renderSnippet(
  SampleBank bank,
  List<SnippetNote> notes, {
  int sampleRate = 44100,
  bool guitar = false,
  bool room = true,
  BassTone bassTone = BassTone.natural,
  List<SnippetDrum> drums = const [],
}) {
  final brightBass = bassTone != BassTone.natural;
  final end = [
    for (final note in notes) note.start + note.length,
    // A cymbal at the end still needs room to ring.
    for (final hit in drums) hit.at + 0.6,
  ].fold(0.0, (a, b) => math.max(a, b));
  final release = 0.35;
  final mix = _Mix(
    sampleRate: sampleRate,
    loopStart: 0,
    length: ((end + release + 0.1) * sampleRate).ceil(),
  );
  final bassMix = brightBass
      ? _Mix(sampleRate: sampleRate, loopStart: 0, length: mix.buffer.length)
      : mix;
  for (final note in notes) {
    final start = (note.start * sampleRate).round();
    final hold = (note.length * sampleRate).round();
    if (note.bass) {
      // Past the recorded range (a bass arpeggio climbs higher than a bass
      // line), the nearest recording pitched to it.
      final (shift, takes) = bank.bass.nearest(note.pitch);
      bassMix.addRecording(
        start,
        takes.first,
        1.1 * note.velocity,
        rate: math.pow(2, shift / 12).toDouble(),
        holdSamples: hold,
        releaseSamples: (0.08 * sampleRate).round(),
      );
    } else if (guitar) {
      final (shift, takes) = bank.guitar.nearest(note.pitch);
      mix.addRecording(
        start,
        takes.first,
        guitarLevel * note.velocity,
        rate: math.pow(2, shift / 12).toDouble(),
        holdSamples: hold,
        releaseSamples: (0.1 * sampleRate).round(),
      );
    } else {
      final (shift, layers) = bank.piano.nearest(note.pitch);
      mix.addRecording(
        start,
        bank.piano.forVelocity(layers, note.velocity),
        0.63 * note.velocity,
        rate: math.pow(2, shift / 12).toDouble(),
        holdSamples: hold,
        releaseSamples: (release * sampleRate).round(),
      );
    }
  }
  // The drums last, so they sit on top of whatever else is going on.
  for (final hit in drums) {
    final samples = drumIn(bank, hit.drum);
    final layer = hit.hard ? samples.length - 1 : 0;
    mix.addRecording(
      (hit.at * sampleRate).round(),
      SampledNote(samples.layers[layer].first),
      hit.velocity * samples.levelling[layer],
    );
  }
  if (brightBass) {
    final bass = bassMix.buffer;
    if (bassTone == BassTone.tight) {
      // Under a line rather than out in front of one: the boom goes, and
      // nothing is added.
      for (var pass = 0; pass < 3; pass++) {
        cutLows(bass, sampleRate, hertz: 180);
      }
    } else {
      // Out in front: a light hand on the bottom so the low roots do not
      // wallow, and the top lifted so it carries on a phone speaker.
      //
      // It used to be driven instead: the lows cut three times over, then
      // saturated, then a fivefold lift at 600 Hz, then saturated again.
      // That was two stages of distortion and a shout in the midrange, and
      // it sounded like the bass was being hit rather than plucked. All of
      // that is gone. One gentle cut and one shelf, both chosen by ear.
      cutLows(bass, sampleRate, hertz: bassCutBelow);
      addPresence(bass, sampleRate, hertz: bassLiftFrom, gain: bassLift);
    }
    for (var i = 0; i < mix.buffer.length; i++) {
      mix.buffer[i] += bassMix.buffer[i];
    }
  }
  // A snippet had no room at all, which is most of why chords played on
  // the Learn screens sounded like a cheap sampler: a handful of dry
  // samples struck together and stopping dead. A single chord with nothing
  // around it needs more of a room than a whole band does, not less.
  //
  // [room] turns it off for a snippet that is going to be measured rather
  // than listened to: a tail fills the silence a click test looks into,
  // and smears the signal the chord detector is meant to read as an
  // instrument played straight into a microphone.
  if (room) {
    addRoomReverb(mix.buffer, 0, sampleRate, wet: guitar ? guitarRoom : 0.16);
  }
  final peak = mix.buffer.fold(0.0, (a, b) => math.max(a, b.abs()));
  return _encodeWav(mix.buffer, sampleRate, peak > 0 ? 0.8 / peak : 1);
}

/// How a metronome divides the beat.
enum Subdivision {
  quarters('Beats'),
  eighths('Eighths'),
  triplets('Triplets'),
  swing('Swing');

  const Subdivision(this.label);
  final String label;

  /// Where the clicks fall inside one beat.
  List<double> get offsets => switch (this) {
    quarters => const [0],
    eighths => const [0, 0.5],
    triplets => const [0, 1 / 3, 2 / 3],
    swing => const [0, 2 / 3],
  };
}

/// Which beats of the bar the metronome clicks on.
enum ClickOn {
  everyBeat('Every Beat'),
  backbeat('2 And 4');

  const ClickOn(this.label);
  final String label;

  /// Whether a click falls on [beat] of the bar, counted from nought.
  bool sounds(int beat) => switch (this) {
    everyBeat => true,
    // 2 and 4 of a bar of four; the even-numbered beats of any bar.
    backbeat => beat.isOdd,
  };

  /// Whether this makes sense in a bar of [beatsPerBar] beats. There is no
  /// 4 in a bar of three, so the backbeat is only offered in even time.
  bool suits(int beatsPerBar) => this == everyBeat || beatsPerBar.isEven;
}

/// How much of the click is taken away, as bars on and bars off.
///
/// The click returns exactly where it would have been, so the gap marks
/// itself: if it comes back where you expected, your time held. Easiest
/// first: one bar missing in four is a stumble you can recover from; four
/// bars off and nothing is holding you up but you.
enum Dropout {
  none('Off', on: 1, off: 0),
  oneInFour('3 On, 1 Off', on: 3, off: 1),
  everyOther('1 On, 1 Off', on: 1, off: 1),
  twoInFour('2 On, 2 Off', on: 2, off: 2),
  fourInEight('4 On, 4 Off', on: 4, off: 4);

  const Dropout(this.label, {required this.on, required this.off});

  final String label;

  /// Bars of clicking, then bars of silence.
  final int on;
  final int off;

  /// How long the whole pattern is, in bars.
  int get bars => on + off;

  /// Whether [bar] of the loop clicks at all.
  bool sounds(int bar) => bar % bars < on;
}

/// Metronome clicks to play on a loop: [beatsPerBar] beats at [tempo], the
/// first of each bar accented, each beat divided by [subdivision], clicking
/// on the beats [clickOn] asks for and only in the bars [dropout] leaves in.
///
/// It is a whole number of samples long, so looping it keeps time exactly
/// however long it runs, which is what makes the silent bars worth
/// anything: the click comes back in the right place or not at all.
Uint8List metronomeLoop({
  required int tempo,
  required int beatsPerBar,
  Subdivision subdivision = Subdivision.quarters,
  ClickOn clickOn = ClickOn.everyBeat,
  Dropout dropout = Dropout.none,
  bool accentFirst = true,
  int sampleRate = 44100,
}) {
  final samplesPerBeat = (60 / tempo * sampleRate).round();
  final mix = _Mix(
    sampleRate: sampleRate,
    loopStart: 0,
    length: samplesPerBeat * beatsPerBar * dropout.bars,
  );
  for (var bar = 0; bar < dropout.bars; bar++) {
    if (!dropout.sounds(bar)) continue;
    for (var beat = 0; beat < beatsPerBar; beat++) {
      if (!clickOn.sounds(beat)) continue;
      for (final offset in subdivision.offsets) {
        final accent = beat == 0 && offset == 0 && accentFirst;
        final onBeat = offset == 0;
        mix.tone(
          ((bar * beatsPerBar + beat + offset) * samplesPerBeat).round(),
          accent
              ? 2093 // C7: the bar's own click
              : onBeat
              ? 1568 // G6
              : 1175, // D6, for the notes in between
          0.05,
          accent
              ? 0.5
              : onBeat
              ? 0.34
              : 0.16,
          decay: 0.03,
        );
      }
    }
  }
  return _encodeWav(mix.buffer, sampleRate, 1);
}

/// A reference note at exactly [hz], as a WAV file: what the tuner plays to
/// match. Built from harmonics rather than samples so the pitch is exact,
/// which is the whole point of a reference note.
///
/// It is shaped to be sung or played against rather than listened to: it
/// comes in over a moment instead of starting with a click, holds nearly
/// steady so there is something there to match, and fades out at the end
/// rather than stopping. The harmonics roll off steeply, which leaves the
/// fundamental plainly the loudest thing in it. A tone with strong upper
/// harmonics is easier to hear across a room and harder to tune to,
/// because the ear starts comparing the wrong part of it.
Uint8List referenceTone(
  double hz, {
  double seconds = 2.5,
  int sampleRate = 44100,
}) {
  final mix = _Mix(
    sampleRate: sampleRate,
    loopStart: 0,
    length: (seconds * sampleRate).round() + 1,
  );
  mix.tone(
    0,
    hz,
    seconds,
    1,
    // Enough of the 2nd and 3rd to sound like something rather than a
    // test tone, and little enough that the fundamental is never in
    // question.
    harmonics: const [1, 0.22, 0.09, 0.035],
    // Slow enough that there is no click at the front.
    attack: 0.04,
    // A long time constant, so it holds rather than plinking: you are
    // meant to play along with it, not listen to it.
    decay: 6,
    releaseSeconds: 0.3,
  );
  final peak = mix.buffer.fold(0.0, (a, b) => math.max(a, b.abs()));
  return _encodeWav(mix.buffer, sampleRate, peak > 0 ? 0.7 / peak : 1);
}

class _Mix {
  _Mix({required this.sampleRate, required this.loopStart, required int length})
    : buffer = Float32List(length);

  final int sampleRate;
  final int loopStart;
  final Float32List buffer;

  /// Mixes in a recorded note at [start].
  ///
  /// [rate] above 1 plays it faster and higher (for small pitch shifts); the
  /// take's own rate is multiplied in, so a sample recorded at 22 kHz comes
  /// out at the pitch it was played. If [holdSamples] is given, the sound is
  /// faded out over [releaseSamples] after that point, like a key being
  /// released or a string being damped.
  ///
  /// A recording with a loop goes round it for as long as the note is held,
  /// rather than running off its own end. That is how an organ or a Rhodes
  /// out of a SoundFont is stored: a moment of the attack, then a region
  /// to repeat. A one-shot, which is every built-in recording, simply runs
  /// out, and the loop costs it nothing.
  void addRecording(
    int start,
    SampledNote note,
    double gain, {
    double rate = 1,
    int? holdSamples,
    int releaseSamples = 0,
  }) {
    final sample = note.samples;
    final speed = rate * note.rate;
    final scale = gain / 32768;
    final loop = note.loop;
    // Where the readhead may not go: one short of the end, because reading
    // a fraction of the way between two samples needs the one after it.
    final last = (loop == null ? sample.length : loop.$2) - 1;
    var length = (last / speed).floor();
    if (holdSamples != null) {
      length = math.min(length, holdSamples + releaseSamples);
    } else if (loop != null) {
      // Nothing says when to stop, so the loop would go round for ever.
      length = math.min(length, sample.length);
    }
    if (loop != null && holdSamples != null) {
      length = holdSamples + releaseSamples;
    }
    final loopLength = loop == null ? 0 : loop.$2 - loop.$1;
    for (var i = 0; i < length; i++) {
      var position = i * speed;
      if (loop != null && loopLength > 0 && position > loop.$1) {
        position = loop.$1 + (position - loop.$1) % loopLength;
      }
      double value;
      if (speed == 1 && loop == null) {
        value = sample[i].toDouble();
      } else {
        final index = position.floor();
        if (index + 1 >= sample.length) break;
        final fraction = position - index;
        value = sample[index] + (sample[index + 1] - sample[index]) * fraction;
      }
      if (holdSamples != null && i > holdSamples) {
        if (releaseSamples == 0) break;
        value *= 1 - (i - holdSamples) / releaseSamples;
      }
      add(start + i, value * scale);
    }
  }

  /// Mixes a pre-rendered sound in at [start], scaled by [gain].
  void addSamples(int start, Float32List samples, double gain) {
    for (var i = 0; i < samples.length; i++) {
      add(start + i, samples[i] * gain);
    }
  }

  void add(int index, double value) {
    if (index < 0) return;
    if (index < buffer.length) {
      buffer[index] += value;
    } else {
      // Past the end: wrap into the loop so ringing notes cross the loop point.
      final loopLength = buffer.length - loopStart;
      buffer[loopStart + (index - buffer.length) % loopLength] += value;
    }
  }

  /// A plucked or struck tone built from a few harmonics.
  void tone(
    int start,
    double frequency,
    double seconds,
    double amplitude, {
    List<double> harmonics = const [1],
    double attack = 0.005,
    double decay = 0.5,
    double releaseSeconds = 0.03,
  }) {
    final count = (seconds * sampleRate).round();
    final release = math.min(count, (releaseSeconds * sampleRate).round());
    final nyquist = sampleRate / 2;
    for (var k = 0; k < count; k++) {
      final t = k / sampleRate;
      var envelope = math.min(1.0, t / attack) * math.exp(-t / decay);
      if (k > count - release) envelope *= (count - k) / release;
      var sample = 0.0;
      for (var h = 0; h < harmonics.length; h++) {
        final f = frequency * (h + 1);
        if (f >= nyquist) break;
        sample += harmonics[h] * math.sin(2 * math.pi * f * t);
      }
      add(start + k, amplitude * envelope * sample);
    }
  }

  /// A burst of bright noise, used for cymbals and hi-hats.
  void noise(
    int start,
    double seconds,
    double amplitude,
    double decay,
    math.Random random,
  ) {
    final count = (seconds * sampleRate).round();
    var previous = 0.0;
    for (var k = 0; k < count; k++) {
      final white = random.nextDouble() * 2 - 1;
      final bright = white - previous; // crude high-pass filter
      previous = white;
      add(start + k, amplitude * math.exp(-k / sampleRate / decay) * bright);
    }
  }
}

/// Packs samples into a 16-bit mono WAV file, multiplying each by [gain].
Uint8List _encodeWav(Float32List samples, int sampleRate, double gain) {
  const headerSize = 44;
  final dataSize = samples.length * 2;
  final bytes = ByteData(headerSize + dataSize);
  void ascii(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      bytes.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  bytes.setUint32(4, 36 + dataSize, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little); // format chunk size
  bytes.setUint16(20, 1, Endian.little); // PCM
  bytes.setUint16(22, 1, Endian.little); // mono
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * 2, Endian.little); // bytes per second
  bytes.setUint16(32, 2, Endian.little); // bytes per frame
  bytes.setUint16(34, 16, Endian.little); // bits per sample
  ascii(36, 'data');
  bytes.setUint32(40, dataSize, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    final value = ((samples[i] * gain).clamp(-1.0, 1.0) * 32767).round();
    bytes.setInt16(headerSize + i * 2, value, Endian.little);
  }
  return bytes.buffer.asUint8List();
}
