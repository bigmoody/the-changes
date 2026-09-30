// Reading a SoundFont (.sf2) file, so somebody can play the changes with
// their own piano rather than ours.
//
// An .sf2 is a RIFF file, the same container a WAV is, with three lists in
// it:
//
//   INFO  who made it, and which version of the spec it claims
//   sdta  every sample in the font, 16-bit, end to end in one chunk
//   pdta  the paperwork: which stretch of that chunk is which note of
//         which instrument of which preset
//
// The paperwork is nine tables that point at each other by index, and
// almost all of the work here is walking them: a preset points at a list
// of zones, each zone points at an instrument, an instrument points at its
// own list of zones, and those finally point at a sample. A zone says which
// keys and which velocities it answers for.
//
// What this reads, and what it does not:
//
//  • Read: the key and velocity range of each zone, the sample it plays,
//    the note that sample was recorded at, its tuning, and its loop.
//  • Not read: modulators, envelopes, filters, LFOs, chorus, reverb, and
//    the rest of the synthesis the format can describe. The app has its own
//    envelope and its own room, and a note is held and released by the band
//    rather than by the font.
//
// That is a sampler rather than a SoundFont player, and the difference is
// worth being honest about: a font built around a filter sweep will not
// sound here the way it does in a synth that reads one. A piano, an organ,
// a Rhodes, a horn, which is what anybody is importing this for, will.

import 'dart:math' as math;
import 'dart:typed_data';

import 'sample_bank.dart';

/// A font that could not be read. The message is shown to the person who
/// chose the file, so it says what is wrong with it and not where it threw.
class SoundFontException implements Exception {
  const SoundFontException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// One sound in the font, as the list of them shows it.
///
/// Bank 128 is where the spec keeps percussion. The app has its own drums
/// and they are a different shape entirely (levelled layers, no pitch), so
/// a percussion preset is listed and marked rather than hidden, and refused
/// with a reason if somebody picks it.
class SoundFontPreset {
  const SoundFontPreset({
    required this.name,
    required this.bank,
    required this.program,
    required this.index,
  });

  final String name;
  final int bank;
  final int program;

  /// Where it sits in the font's own table, which is how it is asked for.
  final int index;

  bool get isPercussion => bank == 128;

  @override
  String toString() => '$name (bank $bank, program $program)';
}

/// A file somebody picked, read far enough to list what is in it.
///
/// The samples are not decoded until a preset is chosen. A General MIDI
/// font is a hundred megabytes and holds a hundred and twenty-eight sounds;
/// somebody wants one of them.
class SoundFont {
  SoundFont._(
    this.name,
    this._bytes,
    this._sampleData,
    this._sampleDataLength,
    this._tables,
  ) {
    presets = _readPresets();
  }

  /// What the font calls itself, or the file name if it does not.
  final String name;

  /// Set as soon as the tables are in place, which is the only reason it
  /// is late rather than final.
  late final List<SoundFontPreset> presets;

  final Uint8List _bytes;

  /// Where the 16-bit samples start, and how many of them there are.
  final int _sampleData;
  final int _sampleDataLength;

  final Map<String, _Table> _tables;

  /// Reads enough of [bytes] to list the presets.
  static SoundFont read(Uint8List bytes, {String? fileName}) {
    final data = ByteData.sublistView(bytes);
    if (bytes.length < 12 || _ascii(bytes, 0, 4) != 'RIFF') {
      throw const SoundFontException('That is not a SoundFont file.');
    }
    if (_ascii(bytes, 8, 4) != 'sfbk') {
      throw const SoundFontException(
        'That is a RIFF file, but not a SoundFont.',
      );
    }

    String? inam;
    var sampleData = 0;
    var sampleDataLength = 0;
    final tables = <String, _Table>{};

    // Walk the three lists, and the chunks inside them.
    var at = 12;
    while (at + 8 <= bytes.length) {
      final id = _ascii(bytes, at, 4);
      final size = data.getUint32(at + 4, Endian.little);
      if (id != 'LIST') {
        at += 8 + size + (size.isOdd ? 1 : 0);
        continue;
      }
      final list = _ascii(bytes, at + 8, 4);
      var inner = at + 12;
      final end = _min(at + 8 + size, bytes.length);
      while (inner + 8 <= end) {
        final chunk = _ascii(bytes, inner, 4);
        final length = data.getUint32(inner + 4, Endian.little);
        final start = inner + 8;
        final kept = _min(length, bytes.length - start);
        switch ((list, chunk)) {
          case ('INFO', 'INAM'):
            inam = _string(bytes, start, kept);
          case ('sdta', 'smpl'):
            sampleData = start;
            sampleDataLength = kept ~/ 2;
          case ('pdta', _):
            tables[chunk] = _Table(start, kept);
        }
        inner = start + length + (length.isOdd ? 1 : 0);
      }
      at += 8 + size + (size.isOdd ? 1 : 0);
    }

    if (sampleDataLength == 0) {
      throw const SoundFontException(
        'That SoundFont holds no sound. It may be one of the files that '
        'keeps its samples in a separate .sf2pack or .sfz.',
      );
    }
    for (final needed in [
      'phdr',
      'pbag',
      'pgen',
      'inst',
      'ibag',
      'igen',
      'shdr',
    ]) {
      if (!tables.containsKey(needed)) {
        throw SoundFontException(
          'That SoundFont is missing its $needed table and cannot be read.',
        );
      }
    }

    final font = SoundFont._(
      // What the font calls itself, and only then what the file is
      // called: the file is often "GeneralUser GS v1.471.sf2".
      inam?.isNotEmpty == true ? inam! : (fileName ?? 'SoundFont'),
      bytes,
      sampleData,
      sampleDataLength,
      tables,
    );
    if (font.presets.isEmpty) {
      throw const SoundFontException('That SoundFont holds no instruments.');
    }
    return font;
  }

  /// The preset table, minus the terminal record every table ends with.
  List<SoundFontPreset> _readPresets() {
    final table = _tables['phdr']!;
    final count = table.length ~/ _phdrSize - 1;
    final data = ByteData.sublistView(_bytes);
    return [
      for (var i = 0; i < count; i++)
        SoundFontPreset(
          name: _string(_bytes, table.start + i * _phdrSize, 20),
          program: data.getUint16(
            table.start + i * _phdrSize + 20,
            Endian.little,
          ),
          bank: data.getUint16(table.start + i * _phdrSize + 22, Endian.little),
          index: i,
        ),
    ];
  }

  static int _min(int a, int b) => a < b ? a : b;
}

const _phdrSize = 38;

/// Where one of the pdta tables sits in the file.
class _Table {
  const _Table(this.start, this.length);
  final int start;
  final int length;
}

String _ascii(Uint8List bytes, int at, int length) =>
    String.fromCharCodes(bytes.sublist(at, _atMost(at + length, bytes.length)));

/// A fixed-width name, cut at the first zero and trimmed.
String _string(Uint8List bytes, int at, int length) {
  final end = _atMost(at + length, bytes.length);
  var stop = at;
  while (stop < end && bytes[stop] != 0) {
    stop++;
  }
  return String.fromCharCodes(bytes.sublist(at, stop)).trim();
}

int _atMost(int a, int b) => a < b ? a : b;

// ── The zone walk ────────────────────────────────────────────────────────

/// The generators this reads. The spec defines sixty; the rest describe
/// synthesis the app does its own way (see the note at the top).
const _genStartOffset = 0;
const _genEndOffset = 1;
const _genStartLoopOffset = 2;
const _genEndLoopOffset = 3;
const _genStartOffsetCoarse = 4;
const _genEndOffsetCoarse = 12;
const _genStartLoopOffsetCoarse = 45;
const _genEndLoopOffsetCoarse = 50;
const _genKeyRange = 43;
const _genVelRange = 44;
const _genInstrument = 41;
const _genSampleModes = 54;
const _genCoarseTune = 51;
const _genFineTune = 52;
const _genRootKey = 58;
const _genSampleId = 53;

const _pbagSize = 4;
const _pgenSize = 4;
const _instSize = 22;
const _ibagSize = 4;
const _igenSize = 4;
const _shdrSize = 46;

/// One stretch of the keyboard, and the recording that answers for it.
class _Region {
  _Region(this.generators);
  final Map<int, int> generators;

  int? get sampleId => generators[_genSampleId];
  int get keyLow => (generators[_genKeyRange] ?? 0x7F00) & 0xFF;
  int get keyHigh => ((generators[_genKeyRange] ?? 0x7F00) >> 8) & 0xFF;
  int get velLow => (generators[_genVelRange] ?? 0x7F00) & 0xFF;
  int get velHigh => ((generators[_genVelRange] ?? 0x7F00) >> 8) & 0xFF;
  bool get loops => (generators[_genSampleModes] ?? 0) & 1 == 1;

  /// Signed, because a generator's amount is two bytes read either way
  /// depending on what it means.
  int signed(int generator) {
    final raw = generators[generator];
    if (raw == null) return 0;
    return raw >= 0x8000 ? raw - 0x10000 : raw;
  }
}

extension SoundFontInstruments on SoundFont {
  /// Reads [preset] into something the band can play.
  ///
  /// Every zone of the preset becomes one recorded note, filed under the
  /// key it was recorded at. Where a font gives several zones the same
  /// root, which is how it writes a soft and a loud take of one note, they
  /// become that note's takes, quietest first.
  ///
  /// The zones' key ranges are not kept. [SampledInstrument] is keyed by
  /// the pitch somebody played, and finds anything else by shifting the
  /// nearest one, which is how the built-in piano works too. For a font
  /// whose zones sit around their root note, which is nearly all of them,
  /// that comes out the same. For one that stretches a sample a long way
  /// upwards on purpose, it does not, and a few notes will be brighter
  /// than the font intended.
  SampledInstrument instrumentFor(SoundFontPreset preset) {
    if (preset.isPercussion) {
      throw const SoundFontException(
        'That is a drum kit. The Changes plays its own drums, so import a '
        'pitched instrument instead.',
      );
    }
    final regions = _regionsOf(preset);
    if (regions.isEmpty) {
      throw SoundFontException('${preset.name} has no playable notes in it.');
    }

    final byRoot = <int, List<(int, SampledNote)>>{};
    for (final region in regions) {
      final note = _noteFrom(region);
      if (note == null) continue;
      byRoot.putIfAbsent(note.$1, () => []).add((region.velLow, note.$2));
    }
    if (byRoot.isEmpty) {
      throw SoundFontException(
        '${preset.name} points at sample data that is not in the file.',
      );
    }
    return SampledInstrument(
      name: preset.name,
      // A SoundFont has velocity layers and no concept of a round robin, so
      // the takes of a note are always softest first.
      takesAre: Takes.velocity,
      notes: {
        for (final entry in byRoot.entries)
          entry.key: [
            for (final take in entry.value..sort((a, b) => a.$1 - b.$1))
              take.$2,
          ],
      },
    );
  }

  /// The pitch it was recorded at, and the recording, or null when the
  /// sample it names is missing or empty.
  (int, SampledNote)? _noteFrom(_Region region) {
    final shdr = _tables['shdr']!;
    final id = region.sampleId;
    if (id == null) return null;
    final at = shdr.start + id * _shdrSize;
    if (id < 0 || at + _shdrSize > shdr.start + shdr.length) return null;
    final data = ByteData.sublistView(_bytes);

    final type = data.getUint16(at + 44, Endian.little);
    // A sample living in ROM on some 1990s sound card is not in this file,
    // and the right half of a stereo pair would only double what the left
    // one already says.
    if (type & 0x8000 != 0 || type == 2) return null;

    // Past the twenty bytes of sample name: start, end, the loop, the rate
    // it was recorded at, the note it was played at, and how far out of
    // tune that note was.
    var start = data.getUint32(at + 20, Endian.little);
    var end = data.getUint32(at + 24, Endian.little);
    var loopStart = data.getUint32(at + 28, Endian.little);
    var loopEnd = data.getUint32(at + 32, Endian.little);
    final rate = data.getUint32(at + 36, Endian.little);
    final original = data.getUint8(at + 40);
    final correction = data.getInt8(at + 41);

    start +=
        region.signed(_genStartOffset) +
        region.signed(_genStartOffsetCoarse) * 32768;
    end +=
        region.signed(_genEndOffset) +
        region.signed(_genEndOffsetCoarse) * 32768;
    loopStart +=
        region.signed(_genStartLoopOffset) +
        region.signed(_genStartLoopOffsetCoarse) * 32768;
    loopEnd +=
        region.signed(_genEndLoopOffset) +
        region.signed(_genEndLoopOffsetCoarse) * 32768;

    if (rate <= 0) return null;
    if (end <= start) return null;
    if (end > _sampleDataLength) return null;

    final samples = Int16List(end - start);
    for (var i = 0; i < samples.length; i++) {
      samples[i] = data.getInt16(_sampleData + (start + i) * 2, Endian.little);
    }

    final root = region.generators[_genRootKey] ?? original;
    // The recording's own rate against ours, and whatever tuning the font
    // asks for on top. The pitch it is played at is the band's business,
    // not the font's, so the root key is not folded in here.
    final cents =
        correction +
        region.signed(_genFineTune) +
        region.signed(_genCoarseTune) * 100;
    final speed = rate / SampleBank.sampleRate * _centsToRatio(cents);

    (int, int)? loop;
    if (region.loops &&
        loopEnd > loopStart &&
        loopStart >= start &&
        loopEnd <= end) {
      loop = (loopStart - start, loopEnd - start);
    }
    // A root key of 255 is the spec's way of saying "whatever the sample
    // said", which we have already taken.
    return (
      root > 127 ? original : root,
      SampledNote(samples, rate: speed, loop: loop),
    );
  }

  /// Every instrument zone reachable from [preset], with the defaults its
  /// global zones set already folded in.
  List<_Region> _regionsOf(SoundFontPreset preset) {
    final data = ByteData.sublistView(_bytes);
    final phdr = _tables['phdr']!;
    final pbag = _tables['pbag']!;
    final pgen = _tables['pgen']!;
    final inst = _tables['inst']!;
    final ibag = _tables['ibag']!;
    final igen = _tables['igen']!;

    final firstBag = data.getUint16(
      phdr.start + preset.index * _phdrSize + 24,
      Endian.little,
    );
    final lastBag = data.getUint16(
      phdr.start + (preset.index + 1) * _phdrSize + 24,
      Endian.little,
    );

    final out = <_Region>[];
    for (var bag = firstBag; bag < lastBag; bag++) {
      final gens = _generators(data, pbag, pgen, bag, _pbagSize, _pgenSize, 0);
      final which = gens[_genInstrument];
      // A preset zone with no instrument generator is the global one: it
      // sets defaults for the zones after it, none of which this reads.
      if (which == null) continue;
      final firstInstBag = data.getUint16(
        inst.start + which * _instSize + 20,
        Endian.little,
      );
      final lastInstBag = data.getUint16(
        inst.start + (which + 1) * _instSize + 20,
        Endian.little,
      );

      var globals = <int, int>{};
      for (var zone = firstInstBag; zone < lastInstBag; zone++) {
        final zoneGens = _generators(
          data,
          ibag,
          igen,
          zone,
          _ibagSize,
          _igenSize,
          0,
        );
        if (!zoneGens.containsKey(_genSampleId)) {
          // The instrument's own global zone, same rule as above.
          globals = zoneGens;
          continue;
        }
        out.add(_Region({...globals, ...zoneGens}));
      }
    }
    return out;
  }

  /// The generators of one zone, as a map from generator to its amount.
  ///
  /// A zone's generators are the run between its own index in the bag
  /// table and the next zone's, which is why the tables all carry one
  /// record more than they have zones.
  Map<int, int> _generators(
    ByteData data,
    _Table bagTable,
    _Table genTable,
    int zone,
    int bagSize,
    int genSize,
    int bagOffset,
  ) {
    final bagAt = bagTable.start + zone * bagSize;
    if (bagAt + bagSize * 2 > bagTable.start + bagTable.length) return const {};
    final from = data.getUint16(bagAt + bagOffset, Endian.little);
    final to = data.getUint16(bagAt + bagSize + bagOffset, Endian.little);
    final out = <int, int>{};
    for (var i = from; i < to; i++) {
      final at = genTable.start + i * genSize;
      if (at + genSize > genTable.start + genTable.length) break;
      out[data.getUint16(at, Endian.little)] = data.getUint16(
        at + 2,
        Endian.little,
      );
    }
    return out;
  }
}

double _centsToRatio(int cents) =>
    cents == 0 ? 1 : math.pow(2, cents / 1200).toDouble();
