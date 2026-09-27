// Recorded instrument samples, loaded once when the app starts.
//
// Sources (see assets/sounds/CREDITS.md):
//  • Bass: Sneakybass by Karoryfer Samples (CC0), a 1958 upright bass.
//  • Piano: Salamander Grand Piano V3 by Alexander Holm (CC-BY 3.0).
//  • Drums: Virtuosity Drums by Versilian Studios & Karoryfer (CC0).
//
// The files were trimmed and converted to mono 16-bit WAV by
// tool/process_samples.py. Samples are kept as 16-bit integers (half the
// memory of floating point) and converted as they're mixed.

import 'dart:math' as math;
import 'dart:typed_data';

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

  /// Takes for each layer, softest layer first.
  final List<List<Int16List>> layers;

  /// What to multiply each layer by to bring it up to the loudest layer's
  /// level, so only the tone changes from layer to layer.
  final List<double> levelling;

  int get length => layers.length;

  static List<double> _levelling(List<List<Int16List>> layers) {
    final peaks = [
      for (final takes in layers)
        takes
            .map((take) => take.fold(0, (peak, s) => math.max(peak, s.abs())))
            .reduce(math.max),
    ];
    final loudest = peaks.reduce(math.max);
    return [for (final peak in peaks) peak == 0 ? 1.0 : loudest / peak];
  }
}

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
  }) : pitches = notes.keys.toList()..sort() {
    assert(notes.isNotEmpty, '$name has no recordings');
  }

  /// What to call it on screen.
  final String name;

  /// The recordings, by the MIDI pitch they were played at.
  final Map<int, List<Int16List>> notes;

  /// Those pitches in order, so [nearest] is a walk rather than a search.
  final List<int> pitches;

  final Takes takesAre;

  int get lowest => pitches.first;
  int get highest => pitches.last;

  /// The recording nearest to [pitch], and how many semitones it must be
  /// shifted to get there. Past either end of the range that shift grows,
  /// which is right for a line that climbs deliberately out of the
  /// instrument's register.
  (int, List<Int16List>) nearest(int pitch) {
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
  List<Int16List> at(int pitch) {
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

  /// Drum hits, softest layer first.
  final DrumSamples ride;
  final DrumSamples hiHatPedal;
  final DrumSamples hiHatClosed;
  final DrumSamples hiHatOpen;
  final DrumSamples kick;

  /// Snare hits: [quiet (jazz comping), loud (funk backbeat)].
  final DrumSamples snare;

  /// Cross-stick (rim click) hits. The library records this from a tick to
  /// a crack, 14 dB apart; the bossa clave wants the quiet end, so only two
  /// neighbouring layers are kept and played round-robin.
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

    Future<DrumSamples> kit(String name) async => DrumSamples([
      for (final layer in [1, 2])
        [
          for (final take in [1, 2, 3, 4])
            await wav('drums/${name}_${layer}_$take.wav'),
        ],
    ]);

    Future<DrumSamples> toms(String name) async => DrumSamples([
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
              await wav('bass/bass_${pitch}_rr1.wav'),
              await wav('bass/bass_${pitch}_rr2.wav'),
            ],
        },
      ),
      piano: SampledInstrument(
        name: 'Piano',
        takesAre: Takes.velocity,
        notes: {
          for (final pitch in pianoPitches)
            pitch: [
              for (final layer in [1, 2, 3])
                await wav('piano/piano_${pitch}_v$layer.wav'),
            ],
        },
      ),
      guitar: SampledInstrument(
        name: 'Guitar',
        takesAre: Takes.roundRobin,
        notes: {
          for (final pitch in guitarPitches)
            pitch: [
              for (final take in [1, 2, 3])
                await wav('guitar/guitar_${pitch}_rr$take.wav'),
            ],
        },
      ),
      ride: await kit('ride'),
      hiHatPedal: await kit('hihat_pedal'),
      hiHatClosed: await kit('hihat_closed'),
      hiHatOpen: DrumSamples([
        for (final layer in [2, 3])
          [
            for (final take in [1, 2, 3])
              await wav('drums/hihat_open_${layer}_$take.wav'),
          ],
      ]),
      kick: await kit('kick'),
      snare: DrumSamples([
        for (final layers in [
          [4, 6, 8],
          [24, 26, 28],
        ])
          [for (final level in layers) await wav('drums/snare_$level.wav')],
      ]),
      crossStick: DrumSamples([
        [
          for (final layer in [6, 7]) await wav('drums/cross_stick_$layer.wav'),
        ],
      ]),
      cowbell: await kit('cowbell'),
      tomHigh: await toms('tom_high'),
      tomLow: await toms('tom_low'),
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
Uint8List wavOf(Int16List samples, int sampleRate) {
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
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little); // PCM
  bytes.setUint16(22, 1, Endian.little); // mono
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  bytes.setUint32(40, dataSize, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    bytes.setInt16(headerSize + i * 2, samples[i], Endian.little);
  }
  return bytes.buffer.asUint8List();
}
