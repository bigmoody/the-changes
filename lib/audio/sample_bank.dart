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

  /// Bass notes by MIDI pitch (E1–E3), two recorded takes each.
  final Map<int, List<Int16List>> bass;

  /// Piano notes by MIDI pitch, sampled every 3 semitones from C3 to C5,
  /// each as [soft, medium, loud].
  final Map<int, List<Int16List>> piano;

  /// Guitar notes by MIDI pitch, sampled every 3 semitones from E2 to
  /// G♭5: three takes of one gentle stroke.
  ///
  /// One stroke on purpose. This is a guitar to comp under somebody for
  /// twenty minutes rather than to solo with, and with the tone rolled
  /// back as far as it is here a firmer stroke measured no brighter, only
  /// louder, which velocity already does. Three takes rather than two, so
  /// a busy comp repeats itself less.
  final Map<int, List<Int16List>> guitar;

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
      bass: {
        for (final pitch in bassPitches)
          pitch: [
            await wav('bass/bass_${pitch}_rr1.wav'),
            await wav('bass/bass_${pitch}_rr2.wav'),
          ],
      },
      piano: {
        for (final pitch in pianoPitches)
          pitch: [
            for (final layer in [1, 2, 3])
              await wav('piano/piano_${pitch}_v$layer.wav'),
          ],
      },
      guitar: {
        for (final pitch in guitarPitches)
          pitch: [
            for (final take in [1, 2, 3])
              await wav('guitar/guitar_${pitch}_rr$take.wav'),
          ],
      },
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

  /// The recorded piano note nearest to [pitch], and how many semitones it
  /// must be shifted to reach it (at most 1, since they're 3 apart).
  (int, List<Int16List>) nearestPiano(int pitch) {
    final nearest = pianoPitches.reduce(
      (a, b) => (a - pitch).abs() <= (b - pitch).abs() ? a : b,
    );
    return (pitch - nearest, piano[nearest]!);
  }

  /// The recorded guitar note nearest to [pitch], and how many semitones it
  /// must be shifted to reach it (at most 1, but for the very top and
  /// bottom of the range).
  (int, List<Int16List>) nearestGuitar(int pitch) {
    final nearest = guitarPitches.reduce(
      (a, b) => (a - pitch).abs() <= (b - pitch).abs() ? a : b,
    );
    return (pitch - nearest, guitar[nearest]!);
  }

  /// A bass note, clamped to the recorded range.
  List<Int16List> bassNote(int pitch) =>
      bass[pitch.clamp(bassPitches.first, bassPitches.last)]!;
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
