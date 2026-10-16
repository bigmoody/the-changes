// Recorded instrument samples, loaded once when the app starts.
//
// Sources (see assets/sounds/CREDITS.md):
//  • Bass: Sneakybass by Karoryfer Samples (CC0), a 1958 upright bass.
//  • Piano: Salamander Grand Piano V3 by Alexander Holm (CC-BY 3.0).
//  • Drums: Virtuosity Drums by Versilian Studios & Karoryfer (CC0).
//  • Drums, brushes: Swirly Drums by Karoryfer Samples (CC0).
//
// The files were trimmed and converted to mono 16-bit WAV by
// tool/process_samples.py. Samples are kept as 16-bit integers (half the
// memory of floating point) and converted as they're mixed.

import 'dart:math' as math;
import 'dart:typed_data';

import '../music/tune.dart' show BassSound, Comping, DrumSound;
import 'drum_patterns.dart' show Drum;

/// One drum, recorded at two or three strengths of stroke ("layers"), each
/// with a few takes of the same stroke.
///
/// The layers are recorded at very different levels (the ride's hard stroke
/// is 12 dB above its soft one), so playing them raw makes a hit's loudness
/// depend on which recording it landed on rather than on the part. Instead
/// each layer is [levelled] to the same peak, and the part's own velocity
/// decides how loud the hit is. Picking a harder layer then changes the
/// *tone* (brighter, more attack), which is what a harder stroke really
/// sounds like.
class DrumSamples {
  DrumSamples(this.layers) : levelling = _levelling(layers);

  /// A kit's worth of plain recordings, for the band's own drums, which
  /// are all trimmed to the app's rate and never loop.
  DrumSamples.plain(List<List<Int16List>> layers)
    : this([
        for (final takes in layers)
          [for (final take in takes) SampledNote(take)],
      ]);

  /// Takes for each layer, softest layer first.
  ///
  /// [SampledNote] rather than plain samples because an imported kit's
  /// hits carry their own sample rate, and a kick recorded at 22 kHz
  /// played at ours is not a kick.
  final List<List<SampledNote>> layers;

  /// What to multiply each layer by to bring it up to the loudest layer's
  /// level, so only the tone changes from layer to layer.
  final List<double> levelling;

  int get length => layers.length;

  static List<double> _levelling(List<List<SampledNote>> layers) {
    final peaks = [
      for (final takes in layers)
        takes
            .map(
              (take) =>
                  take.samples.fold(0, (peak, s) => math.max(peak, s.abs())),
            )
            .reduce(math.max),
    ];
    final loudest = peaks.reduce(math.max);
    return [for (final peak in peaks) peak == 0 ? 1.0 : loudest / peak];
  }
}

/// One recording of one note.
///
/// The built-in instruments are trimmed WAVs at the app's own sample rate,
/// so for them this is the samples and nothing else. A note out of a
/// SoundFont carries two more facts that cannot be baked into the samples:
/// the rate it was recorded at, which is often not ours, and where it
/// loops, because a sustained sound is stored as a short piece of the note
/// plus a region to go round while the key is held. Without the loop an
/// organ stops dead a third of a second in.
class SampledNote {
  // Not const: [lead] is measured from the samples the first time it is
  // asked for, and a const object cannot hold a field worked out later.
  SampledNote(this.samples, {this.rate = 1, this.loop});

  final Int16List samples;

  /// How much faster than normal to read it, before any pitch shift: the
  /// ratio of its own sample rate to the app's, with any fine tuning the
  /// recording asks for folded in.
  final double rate;

  /// The region to repeat while the note is held, as sample offsets. Null
  /// for a one-shot, which is every built-in recording.
  final (int, int)? loop;

  int get length => samples.length;

  /// How many samples pass before the recording is heard.
  ///
  /// A file starts when the engineer pressed record; the note starts when
  /// the player's hand did, and the note is *heard* later still. Between
  /// the three sit a little silence and the climb of the attack, and how
  /// long that climb takes depends on the instrument: a kick or a ride is
  /// at full strength within a millisecond, while a plucked upright at
  /// the bottom of its range takes the best part of fifty to get there,
  /// because the ear needs several cycles of a low string before it can
  /// hear that there is a note at all.
  ///
  /// So a bass played from the front of its file lands behind the kit on
  /// every note, by twenty-six milliseconds on average here and by a
  /// different amount on each take, which is a bass that drags and
  /// wanders without anybody having asked it to. Starting it where the
  /// sound first appears is not enough either: that only lines up the
  /// moment the string is touched, and the kit is already loud by the
  /// time the bass is audible.
  ///
  /// What the band lines up instead is the half-way point of each
  /// attack, which is about where a listener puts a note. Measured
  /// against the recording's own peak, so a soft take is not judged by a
  /// loud one, and capped at [_mostLead]: a sound still climbing after
  /// that is one that swells rather than one that is late.
  late final int lead = _leadIn();

  /// Where the sound is heard: half way up to the peak of its own
  /// attack.
  int _leadIn() {
    final look = math.min(samples.length, _attackWindow);
    var peak = 0;
    for (var i = 0; i < look; i++) {
      final level = samples[i].abs();
      if (level > peak) peak = level;
    }
    if (peak == 0) return 0;
    final threshold = peak ~/ 2;
    for (var i = 0; i < math.min(look, _mostLead); i++) {
      if (samples[i].abs() >= threshold) return i;
    }
    return 0;
  }
}

/// How far into a recording to look for its peak: a quarter of a second,
/// which is past the attack of anything struck or plucked.
const _attackWindow = 11025;

/// The furthest a recording is ever moved: sixty milliseconds, which is
/// past the slowest attack in the bank (a low upright string, at fifty
/// three) and well short of anything that would drag a swelling sound
/// out of its place.
const _mostLead = 2646;

/// How an instrument's recordings of one note differ from each other.
enum Takes {
  /// The same stroke played again: pick one at random, so a busy part does
  /// not play the same sound twice running.
  roundRobin,

  /// Softest first: pick by how hard the note is being played, so a quiet
  /// note is a gentler recording rather than the same one turned down.
  velocity,
}

/// A recorded melodic instrument: the notes somebody played into a
/// microphone, and how to reach the ones they did not.
///
/// Almost no instrument is recorded at every pitch. The piano here is
/// sampled every three semitones and the guitar likewise, so most notes the
/// band plays are a neighbouring recording pushed up or down a little. That
/// is a property of the recording, not of the piano, which is why it lives
/// with the samples and not in the synth.
///
/// It exists as a type rather than as three fields on [SampleBank] so that
/// something recorded elsewhere can stand where the piano stands.
class SampledInstrument {
  SampledInstrument({
    required this.name,
    required this.notes,
    required this.takesAre,
    this.velocityBands = const [],
  }) : pitches = notes.keys.toList()..sort() {
    assert(notes.isNotEmpty, '$name has no recordings');
  }

  /// What to call it on screen.
  final String name;

  /// The recordings, by the MIDI pitch they were played at.
  final Map<int, List<SampledNote>> notes;

  /// Those pitches in order, so [nearest] is a walk rather than a search.
  final List<int> pitches;

  final Takes takesAre;

  /// Where one velocity layer gives way to the next, when the instrument
  /// has an opinion about it.
  ///
  /// The built-in piano does: its three recordings change over at 0.72 and
  /// 0.86, which are not even thirds because they were found by playing it
  /// rather than by dividing one by three. Anything without an opinion,
  /// which is every imported instrument, gets even bands.
  final List<double> velocityBands;

  /// Which recording of a note to play at [velocity].
  ///
  /// Written here rather than at the call sites because the call sites used
  /// to assume the piano's three layers, which made a font with one take
  /// or four a crash rather than a sound.
  SampledNote forVelocity(List<SampledNote> takes, double velocity) {
    if (takes.length == 1) return takes.first;
    if (velocityBands.isNotEmpty) {
      var layer = 0;
      while (layer < velocityBands.length && velocity >= velocityBands[layer]) {
        layer++;
      }
      return takes[layer.clamp(0, takes.length - 1)];
    }
    final band = (velocity * takes.length).floor();
    return takes[band.clamp(0, takes.length - 1)];
  }

  int get lowest => pitches.first;
  int get highest => pitches.last;

  /// The recording nearest to [pitch], and how many semitones it must be
  /// shifted to get there. Past either end of the range that shift grows,
  /// which is right for a line that climbs deliberately out of the
  /// instrument's register.
  (int, List<SampledNote>) nearest(int pitch) {
    final nearest = pitches.reduce(
      (a, b) => (a - pitch).abs() <= (b - pitch).abs() ? a : b,
    );
    return (pitch - nearest, notes[nearest]!);
  }

  /// The recording at [pitch], unshifted, clamped to the range.
  ///
  /// For an instrument recorded at every semitone, which the bass is. A
  /// walking line that dips under the bottom of an upright should play the
  /// bottom note, the way a bass player would, rather than a pitched-down
  /// one; use [nearest] where the line is meant to leave the register.
  List<SampledNote> at(int pitch) {
    final wanted = pitch.clamp(lowest, highest);
    return notes[wanted] ?? nearest(wanted).$2;
  }
}

/// Every recorded sound the band uses.
class SampleBank {
  SampleBank({
    required this.bass,
    required this.piano,
    required this.guitar,
    required this.ride,
    required this.hiHatPedal,
    required this.hiHatClosed,
    required this.hiHatOpen,
    required this.kick,
    required this.snare,
    required this.crossStick,
    required this.cowbell,
    required this.tomHigh,
    required this.tomLow,
    this.importedChords,
    this.importedArpeggio,
    this.importedBass,
    required this.snareTight,
    required this.kickClose,
    this.brushes = const {},
    this.importedDrums = const {},
  });

  /// Bass notes by MIDI pitch (E1–E3), two recorded takes each: every
  /// semitone of the range, so nothing in it is ever shifted.
  final SampledInstrument bass;

  /// Piano notes by MIDI pitch, sampled every 3 semitones from C3 to C5,
  /// each as [soft, medium, loud].
  final SampledInstrument piano;

  /// Guitar notes by MIDI pitch, sampled every 3 semitones from E2 to
  /// G♭5: three takes of one gentle stroke.
  ///
  /// One stroke on purpose. This is a guitar to comp under somebody for
  /// twenty minutes rather than to solo with, and with the tone rolled
  /// back as far as it is here a firmer stroke measured no brighter, only
  /// louder, which velocity already does. Three takes rather than two, so
  /// a busy comp repeats itself less.
  final SampledInstrument guitar;

  /// SoundFonts somebody imported, if they have. Null is the usual case,
  /// and each falls back to the band's own instrument.
  ///
  /// Two of them, because a piano and a bass are two files: importing a
  /// bass would otherwise throw away the piano somebody chose last week.
  final SampledInstrument? importedChords;
  final SampledInstrument? importedBass;

  /// A third, for the arpeggios, so they can be something other than
  /// whatever is comping. Null means they follow the chords, which is
  /// what they did when there was only one font to go round.
  final SampledInstrument? importedArpeggio;

  /// The brush kit, drum by drum. A whole second set of recordings rather
  /// than the stick kit played quietly, because a brush is not a softer
  /// stick: it answers with a wash where a stick answers with a crack.
  final Map<Drum, DrumSamples> brushes;

  /// An imported kit, drum by drum. Only the drums the kit actually had:
  /// anything missing keeps the band's own, so a font without a cowbell
  /// costs a cowbell and not a calypso.
  final Map<Drum, DrumSamples> importedDrums;

  /// The same bank with these as the imported sounds, or with none.
  ///
  /// A copy rather than a setter because the bank is sent to the render
  /// isolate, where a bank that can change underneath a render in progress
  /// would be a very hard bug to find.
  SampleBank withImported({
    SampledInstrument? chords,
    SampledInstrument? bass,
    SampledInstrument? arpeggio,
    Map<Drum, DrumSamples> drums = const {},
  }) => SampleBank(
    // this.bass, because the named argument above is the imported one.
    bass: this.bass,
    piano: piano,
    guitar: guitar,
    ride: ride,
    hiHatPedal: hiHatPedal,
    hiHatClosed: hiHatClosed,
    hiHatOpen: hiHatOpen,
    kick: kick,
    snare: snare,
    crossStick: crossStick,
    cowbell: cowbell,
    tomHigh: tomHigh,
    tomLow: tomLow,
    snareTight: snareTight,
    kickClose: kickClose,
    brushes: brushes,
    importedChords: chords,
    importedBass: bass,
    importedArpeggio: arpeggio,
    importedDrums: drums,
  );

  /// Who plays the chords, given what somebody chose.
  SampledInstrument playing(Comping comping) => switch (comping) {
    Comping.piano => piano,
    Comping.guitar => guitar,
    Comping.imported => importedChords ?? piano,
  };

  /// Who plays the arpeggios, given what somebody chose.
  ///
  /// Their own imported font if there is one, and otherwise the chords'
  /// font: before there was a font of their own, choosing the imported
  /// sound for the arpeggios meant the one the chords were using, and
  /// anybody who set it up that way should keep hearing it.
  SampledInstrument playingArpeggio(Comping comping) => switch (comping) {
    Comping.piano => piano,
    Comping.guitar => guitar,
    Comping.imported => importedArpeggio ?? importedChords ?? piano,
  };

  /// Who plays the bass, given what somebody chose.
  SampledInstrument playingBass(BassSound sound) => switch (sound) {
    BassSound.upright => bass,
    BassSound.imported => importedBass ?? bass,
  };

  /// Which recordings to hit for [drum], given what somebody chose.
  ///
  /// Both the brush kit and an imported one fall back to the band's own
  /// drum when they have not got that drum, so a kit missing a cowbell
  /// costs a cowbell and not a calypso.
  DrumSamples? playingDrum(Drum drum, DrumSound sound, DrumSamples? ours) =>
      switch (sound) {
        DrumSound.kit => ours,
        DrumSound.brushes => brushes[drum] ?? ours,
        DrumSound.imported => importedDrums[drum] ?? ours,
        // Nothing recorded: a chiptune kit is made rather than sampled,
        // and the band reaches for it before it gets this far.
        DrumSound.chiptune => null,
      };

  /// Whether an imported kit has anything in it at all.
  bool get hasImportedDrums => importedDrums.isNotEmpty;

  /// Drum hits, softest layer first.
  final DrumSamples ride;
  final DrumSamples hiHatPedal;
  final DrumSamples hiHatClosed;
  final DrumSamples hiHatOpen;
  final DrumSamples kick;

  /// Snare hits: [quiet (jazz comping), loud (funk backbeat)].
  final DrumSamples snare;

  /// The same kick through the microphone inside the drum: present
  /// rather than across the room. The overheads' kick is 22 dB under the
  /// snare, which is what a kick sounds like from out there and is the
  /// floor of a funk groove rather than a thing feathered under it.
  final DrumSamples kickClose;

  /// The same snare through the close microphone: shorter, drier, more
  /// crack and less room. What a funk backbeat is, and the overhead's
  /// snare is what a jazz one is, so the groove picks.
  final DrumSamples snareTight;

  /// Cross-stick hits: [click, crack].
  ///
  /// The library records this from a tick to a crack across sixteen
  /// layers, 14 dB apart end to end. Two of them are kept at each end of
  /// the useful range rather than one pair in the middle, because the
  /// same drum is the bossa clave, the calypso and the samba, and those
  /// are not the same stroke. A clave laid on the rim is a click; a samba
  /// asks for `hard` and now has something to be given.
  final DrumSamples crossStick;

  /// Calypso percussion: [soft, hard] layers each.
  final DrumSamples cowbell;
  final DrumSamples tomHigh;
  final DrumSamples tomLow;

  static final bassPitches = [for (var p = 28; p <= 52; p++) p];
  static const pianoPitches = [48, 51, 54, 57, 60, 63, 66, 69, 72];
  static const guitarPitches = [
    40, 42, 45, 48, 51, 54, 57, 60, 63, 66, 69, 72, 75, 78, //
  ];
  static const sampleRate = 44100;

  /// Loads every sample using [load], which returns a file's bytes by its
  /// path inside `assets/sounds/` (e.g. from Flutter's asset bundle).
  static Future<SampleBank> load(
    Future<Uint8List> Function(String path) load,
  ) async {
    Future<Int16List> wav(String path) async => decodeWav(await load(path));
    Future<SampledNote> note(String path) async => SampledNote(await wav(path));

    Future<DrumSamples> kit(String name) async => DrumSamples.plain([
      for (final layer in [1, 2])
        [
          for (final take in [1, 2, 3, 4])
            await wav('drums/${name}_${layer}_$take.wav'),
        ],
    ]);

    // The brush kit: three velocity layers a drum rather than two, and
    // three takes rather than four. The layer is chosen by how hard the
    // stroke is, and this library records up to 22 of them, so a third
    // layer buys more than a fourth take of the same one does.
    Future<DrumSamples> brush(String name, {int layers = 3}) async =>
        DrumSamples.plain([
          for (var layer = 1; layer <= layers; layer++)
            [
              for (final take in [1, 2, 3])
                await wav('drums_brushes/${name}_${layer}_$take.wav'),
            ],
        ]);

    Future<DrumSamples> toms(String name) async => DrumSamples.plain([
      for (final layer in [1, 2])
        [
          for (final take in [1, 2])
            await wav('drums/${name}_${layer}_$take.wav'),
        ],
    ]);

    return SampleBank(
      bass: SampledInstrument(
        name: 'Upright bass',
        takesAre: Takes.roundRobin,
        notes: {
          for (final pitch in bassPitches)
            pitch: [
              await note('bass/bass_${pitch}_rr1.wav'),
              await note('bass/bass_${pitch}_rr2.wav'),
            ],
        },
      ),
      piano: SampledInstrument(
        name: 'Piano',
        takesAre: Takes.velocity,
        velocityBands: const [0.72, 0.86],
        notes: {
          for (final pitch in pianoPitches)
            pitch: [
              for (final layer in [1, 2, 3])
                await note('piano/piano_${pitch}_v$layer.wav'),
            ],
        },
      ),
      guitar: SampledInstrument(
        name: 'Guitar',
        takesAre: Takes.roundRobin,
        notes: {
          for (final pitch in guitarPitches)
            pitch: [
              for (final round in [1, 2, 3])
                await note('guitar/guitar_${pitch}_rr$round.wav'),
            ],
        },
      ),
      ride: await kit('ride'),
      hiHatPedal: await kit('hihat_pedal'),
      hiHatClosed: await kit('hihat_closed'),
      hiHatOpen: DrumSamples.plain([
        for (final layer in [2, 3])
          [
            for (final take in [1, 2, 3])
              await wav('drums/hihat_open_${layer}_$take.wav'),
          ],
      ]),
      kick: await kit('kick'),
      snare: DrumSamples.plain([
        for (final layers in [
          [4, 6, 8],
          [24, 26, 28],
        ])
          [for (final level in layers) await wav('drums/snare_$level.wav')],
      ]),
      kickClose: await kit('kick_close'),
      snareTight: DrumSamples.plain([
        for (final layers in [
          [6, 8, 10],
          [24, 26, 28],
        ])
          [
            for (final level in layers)
              await wav('drums/snare_tight_$level.wav'),
          ],
      ]),
      // Two layers, because the clave is a click and a samba's is a
      // crack, and with one of them there was nothing to choose between.
      crossStick: DrumSamples.plain([
        for (final layers in [
          [1, 2],
          [6, 7],
        ])
          [
            for (final level in layers)
              await wav('drums/cross_stick_$level.wav'),
          ],
      ]),
      cowbell: await kit('cowbell'),
      tomHigh: await toms('tom_high'),
      tomLow: await toms('tom_low'),
      brushes: {
        Drum.ride: await brush('ride'),
        Drum.hiHatPedal: await brush('hihat_pedal'),
        Drum.hiHatClosed: await brush('hihat_closed'),
        Drum.hiHatOpen: await brush('hihat_open'),
        Drum.kick: await brush('kick'),
        Drum.snare: await brush('snare'),
        // Brushes have no cross-stick: the handle would be turned round to
        // play one, and a drummer with brushes in their hands plays the
        // clave on the edge of the snare instead. Two layers, because the
        // library's edge hits run from a tick to a slap and the top of
        // that range is a different gesture.
        Drum.crossStick: await brush('cross_stick', layers: 2),
        Drum.cowbell: await brush('cowbell'),
        Drum.tomHigh: await brush('tom_high'),
        Drum.tomLow: await brush('tom_low'),
        // Two circle lengths rather than two velocities: the band stretches
        // whichever is nearer to fit the beat, and having two keeps that
        // stretch close to 1 from a ballad up to a burner.
        Drum.swirl: await brush('swirl', layers: 2),
      },
    );
  }
}

/// Reads 16-bit PCM from a WAV file (mono assumed).
Int16List decodeWav(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  var offset = 12; // after "RIFF", size, "WAVE"
  while (offset + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    final size = data.getUint32(offset + 4, Endian.little);
    if (id == 'data') {
      final count = math.min(size, bytes.length - offset - 8) ~/ 2;
      final samples = Int16List(count);
      for (var i = 0; i < count; i++) {
        samples[i] = data.getInt16(offset + 8 + i * 2, Endian.little);
      }
      return samples;
    }
    offset += 8 + size + (size.isOdd ? 1 : 0);
  }
  throw const FormatException('No audio data found in WAV file');
}

/// Wraps 16-bit mono [samples] in a WAV header, for writing out as a file.
/// A WAV file of [samples] at [sampleRate].
///
/// With [channels] above one the samples are already interleaved, a frame
/// at a time: left, right, left, right.
Uint8List wavOf(Int16List samples, int sampleRate, {int channels = 1}) {
  const headerSize = 44;
  final dataSize = samples.length * 2;
  final bytesPerFrame = channels * 2;
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
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little); // PCM
  bytes.setUint16(22, channels, Endian.little);
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * bytesPerFrame, Endian.little);
  bytes.setUint16(32, bytesPerFrame, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  bytes.setUint32(40, dataSize, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    bytes.setInt16(headerSize + i * 2, samples[i], Endian.little);
  }
  return bytes.buffer.asUint8List();
}
