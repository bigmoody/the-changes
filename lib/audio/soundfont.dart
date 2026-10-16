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
//    the note that sample was recorded at, its tuning, how far apart it
//    says its keys are, whether it sounds one fixed note whatever is
//    played, and its loop.
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
const _genKeynum = 46;
const _genScaleTuning = 56;
const _genRootKey = 58;
const _genSampleId = 53;

const _pbagSize = 4;
const _pgenSize = 4;
const _instSize = 22;
const _ibagSize = 4;
const _igenSize = 4;
const _shdrSize = 46;

/// One stretch of the keyboard and of the velocity range, and the recording
/// that answers for it.
///
/// A region is a preset zone and an instrument zone met together. Fonts
/// split their work between the two very differently: GeneralUser GS puts
/// the whole articulation map at the preset level, forty-eight zones of it,
/// all pointing at one instrument. Walking only the instrument gives that
/// instrument forty-eight times over.
class _Region {
  _Region({
    required this.generators,
    required this.keyLow,
    required this.keyHigh,
    required this.velLow,
    required this.velHigh,
    required this.tuneCents,
    required this.scaleCents,
  });

  final Map<int, int> generators;
  final int keyLow;
  final int keyHigh;
  final int velLow;
  final int velHigh;

  /// Tuning asked for at the preset level, which the spec adds to the
  /// instrument's rather than replacing it.
  final int tuneCents;

  /// The same for the scale: a preset's scale tuning is an offset to its
  /// instrument's, not a replacement.
  final int scaleCents;

  /// How far apart two keys are, in cents. A hundred is a semitone and
  /// the default; a font may say otherwise, and some do. Nought is a
  /// fixed-pitch sound, where every key plays the same note, which is
  /// how a font carries a sound effect or a gong.
  int get scaleTuning => (generators[_genScaleTuning] ?? 100) + scaleCents;

  /// The key this zone sounds as, whatever key was played. Fonts use it
  /// for a fixed-pitch zone, and a zone that has it is not transposed.
  int? get keynum {
    final key = generators[_genKeynum];
    return key != null && key >= 0 && key <= 127 ? key : null;
  }

  int? get sampleId => generators[_genSampleId];
  bool get loops => (generators[_genSampleModes] ?? 0) & 1 == 1;

  bool covers(int pitch) => pitch >= keyLow && pitch <= keyHigh;

  /// Signed, because a generator's amount is two bytes read either way
  /// depending on what it means.
  int signed(int generator) {
    final raw = generators[generator];
    if (raw == null) return 0;
    return raw >= 0x8000 ? raw - 0x10000 : raw;
  }
}

/// A recording with the facts about it that do not depend on which key is
/// being played.
typedef _Recording = ({
  Int16List samples,
  int root,
  double rate,
  (int, int)? loop,
});

extension SoundFontInstruments on SoundFont {
  /// Reads [preset] into something the band can play.
  ///
  /// Every key the preset answers for becomes a note, with the recording
  /// the font would use for it pitched to that key. Where the font gives a
  /// key several recordings at different velocities they become that
  /// note's takes, quietest first.
  ///
  /// Keeping the key ranges rather than filing everything under its root
  /// note matters more than it sounds. A font's zones are not centred on
  /// their roots: a piano zone may be recorded at C and stretched up a
  /// fifth, and the font knows where it wants the seams. Following them is
  /// the difference between a piano and a piano with a few strange notes.
  ///
  /// The recordings themselves are shared between the keys that use them,
  /// so a note is a few dozen bytes and not a copy of the sample.
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

    final read = <_Region, _Recording?>{};
    final notes = <int, List<SampledNote>>{};
    var widest = <_Region>[];
    for (var pitch = 0; pitch < 128; pitch++) {
      final covering = regions.where((r) => r.covers(pitch)).toList()
        ..sort((a, b) => a.velLow - b.velLow);
      if (covering.isEmpty) continue;
      final takes = <SampledNote>[];
      for (final region in covering) {
        final recording = read.putIfAbsent(region, () => _recordingOf(region));
        if (recording == null) continue;
        // What this key sounds as. Normally the key itself; a zone with
        // a keynum sounds that key whatever was played, which is how a
        // font writes a fixed-pitch sound.
        final sounding = region.keynum ?? pitch;
        takes.add(
          SampledNote(
            recording.samples,
            // The sample's own rate and tuning, and then however far
            // this key is from the note it was played at. How far that
            // is in cents is the font's business: a hundred to the
            // semitone unless it says otherwise, and nought where it
            // wants every key to sound the same note.
            rate:
                recording.rate *
                _centsToRatio((sounding - recording.root) * region.scaleTuning),
            loop: recording.loop,
          ),
        );
      }
      if (takes.isEmpty) continue;
      notes[pitch] = takes;
      if (covering.length > widest.length) widest = covering;
    }
    if (notes.isEmpty) {
      throw SoundFontException(
        '${preset.name} points at sample data that is not in the file.',
      );
    }

    return SampledInstrument(
      name: preset.name,
      // A SoundFont has velocity layers and no concept of a round robin, so
      // the takes of a note are always softest first.
      takesAre: Takes.velocity,
      // Where the layers change over, taken from the font rather than
      // guessed at: they are rarely even, and the piano above has eight of
      // them with the first covering well over a third of the range.
      velocityBands: [for (final region in widest.skip(1)) region.velLow / 127],
      notes: notes,
    );
  }

  /// A drum kit out of a percussion preset, by the note each drum sits on.
  ///
  /// The General MIDI percussion map is a convention, not a fact about the
  /// file: note 36 is the kick because everybody agrees it is, and a font
  /// that disagrees will come out wrong. Almost none do, because a kit
  /// that did would play back wrong in every other program too.
  ///
  /// Unpitched, unlike everything else here. A drum is played at the speed
  /// it was recorded and no other: shifting a snare to the key of the tune
  /// is not a thing anybody wants. So the only rate is the sample's own.
  Map<int, List<SampledNote>> drumKitFor(SoundFontPreset preset) {
    if (!preset.isPercussion) {
      throw SoundFontException(
        '${preset.name} is an instrument rather than a drum kit.',
      );
    }
    final regions = _regionsOf(preset);
    final out = <int, List<({int velLow, SampledNote note})>>{};
    final read = <_Region, _Recording?>{};
    for (final region in regions) {
      final recording = read.putIfAbsent(region, () => _recordingOf(region));
      if (recording == null) continue;
      // A zone spanning several notes is one drum offered at several keys,
      // which is how some kits write their toms. Each key gets it.
      for (var note = region.keyLow; note <= region.keyHigh; note++) {
        out.putIfAbsent(note, () => []).add((
          velLow: region.velLow,
          // No key transposition, on purpose: see above.
          note: SampledNote(
            recording.samples,
            rate: recording.rate,
            loop: recording.loop,
          ),
        ));
      }
    }
    if (out.isEmpty) {
      throw SoundFontException('${preset.name} has no drums in it.');
    }
    return {
      for (final entry in out.entries)
        entry.key: [
          for (final hit in entry.value..sort((a, b) => a.velLow - b.velLow))
            hit.note,
        ],
    };
  }

  /// The samples [region] plays, and what it takes to play them, or null
  /// when the sample it names is missing or empty.
  _Recording? _recordingOf(_Region region) {
    final shdr = _tables['shdr']!;
    final id = region.sampleId;
    if (id == null || id < 0) return null;
    final at = shdr.start + id * _shdrSize;
    if (at + _shdrSize > shdr.start + shdr.length) return null;
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

    if (rate <= 0 || end <= start || end > _sampleDataLength) return null;

    final samples = Int16List(end - start);
    for (var i = 0; i < samples.length; i++) {
      samples[i] = data.getInt16(_sampleData + (start + i) * 2, Endian.little);
    }

    // A root key of 255 is the spec's way of saying "whatever the sample
    // said", which we have already taken.
    final override = region.generators[_genRootKey];
    final root = override == null || override > 127 ? original : override;

    final cents =
        correction +
        region.signed(_genFineTune) +
        region.signed(_genCoarseTune) * 100 +
        region.tuneCents;

    (int, int)? loop;
    if (region.loops &&
        loopEnd > loopStart &&
        loopStart >= start &&
        loopEnd <= end) {
      loop = (loopStart - start, loopEnd - start);
    }
    return (
      samples: samples,
      root: root,
      // The recording's own rate against ours, and whatever tuning the font
      // asks for on top.
      rate: rate / SampleBank.sampleRate * _centsToRatio(cents),
      loop: loop,
    );
  }

  /// Every preset zone met with every instrument zone it overlaps.
  ///
  /// Where they disagree about which keys or velocities they answer for,
  /// the answer is the overlap, and a pair with no overlap is not a region
  /// at all. That is what keeps a preset from being its instrument over and
  /// over: the font narrows at the preset level and the instrument is
  /// walked once per narrowing.
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
    var presetGlobals = <int, int>{};
    for (var bag = firstBag; bag < lastBag; bag++) {
      final zone = {
        ...presetGlobals,
        ..._generators(data, pbag, pgen, bag, _pbagSize, _pgenSize),
      };
      final which = zone[_genInstrument];
      // A preset zone with no instrument generator is the global one: it
      // sets defaults for the zones after it.
      if (which == null) {
        presetGlobals = zone;
        continue;
      }
      if (inst.start + (which + 2) * _instSize > inst.start + inst.length) {
        continue;
      }
      final firstInstBag = data.getUint16(
        inst.start + which * _instSize + 20,
        Endian.little,
      );
      final lastInstBag = data.getUint16(
        inst.start + (which + 1) * _instSize + 20,
        Endian.little,
      );

      final presetKeys = _range(zone[_genKeyRange]);
      final presetVels = _range(zone[_genVelRange]);
      // The spec adds the preset's tuning to the instrument's rather than
      // replacing it. Everything else it could say here is attenuation,
      // filters and envelopes, which the band decides.
      final tune =
          _signedOf(zone[_genFineTune]) + _signedOf(zone[_genCoarseTune]) * 100;
      final scale = _signedOf(zone[_genScaleTuning]);

      var instGlobals = <int, int>{};
      for (var z = firstInstBag; z < lastInstBag; z++) {
        final zoneGens = {
          ...instGlobals,
          ..._generators(data, ibag, igen, z, _ibagSize, _igenSize),
        };
        if (!zoneGens.containsKey(_genSampleId)) {
          instGlobals = zoneGens;
          continue;
        }
        final keys = _range(zoneGens[_genKeyRange]);
        final vels = _range(zoneGens[_genVelRange]);
        final keyLow = math.max(presetKeys.$1, keys.$1);
        final keyHigh = math.min(presetKeys.$2, keys.$2);
        final velLow = math.max(presetVels.$1, vels.$1);
        final velHigh = math.min(presetVels.$2, vels.$2);
        if (keyLow > keyHigh || velLow > velHigh) continue;
        out.add(
          _Region(
            generators: zoneGens,
            keyLow: keyLow,
            keyHigh: keyHigh,
            velLow: velLow,
            velHigh: velHigh,
            tuneCents: tune,
            scaleCents: scale,
          ),
        );
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
  ) {
    final bagAt = bagTable.start + zone * bagSize;
    if (bagAt + bagSize * 2 > bagTable.start + bagTable.length) return const {};
    final from = data.getUint16(bagAt, Endian.little);
    final to = data.getUint16(bagAt + bagSize, Endian.little);
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

/// A key or velocity range generator, as low and high. Absent means the
/// whole range, which is what the spec's default of 0 to 127 comes to.
(int, int) _range(int? raw) =>
    raw == null ? (0, 127) : (raw & 0xFF, (raw >> 8) & 0xFF);

int _signedOf(int? raw) =>
    raw == null ? 0 : (raw >= 0x8000 ? raw - 0x10000 : raw);

double _centsToRatio(int cents) =>
    cents == 0 ? 1 : math.pow(2, cents / 1200).toDouble();
