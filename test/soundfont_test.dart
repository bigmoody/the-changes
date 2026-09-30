// Reading a SoundFont, checked against fonts built here byte by byte.
//
// Built rather than bundled, because the app ships no SoundFonts and a test
// fixture would be the one exception to that. A font written here also lets
// a test say exactly what it is testing: this one has two velocity layers
// on one note, that one loops, this one points at a sample that is not in
// the file.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/sample_bank.dart';
import 'package:play_along/audio/soundfont.dart';

/// One zone of a font being built: which keys, which velocities, and the
/// sample it plays.
typedef Zone = ({int sample, int keyLow, int keyHigh, int velLow, int velHigh});

Zone zone(
  int sample, {
  int keyLow = 0,
  int keyHigh = 127,
  int velLow = 0,
  int velHigh = 127,
}) => (
  sample: sample,
  keyLow: keyLow,
  keyHigh: keyHigh,
  velLow: velLow,
  velHigh: velHigh,
);

/// One recording in a font being built.
typedef Sample = ({
  String name,
  int length,
  int rate,
  int root,
  int correction,
  bool loops,
});

Sample sample({
  String name = 'note',
  int length = 64,
  int rate = 44100,
  int root = 60,
  int correction = 0,
  bool loops = false,
}) => (
  name: name,
  length: length,
  rate: rate,
  root: root,
  correction: correction,
  loops: loops,
);

/// Writes a real .sf2: RIFF, three lists, nine tables, terminal records and
/// all. Anything the parser is meant to read has to be spelled here, which
/// is the point.
Uint8List buildFont({
  String name = 'Test Font',
  int bank = 0,
  List<Sample> samples = const [],
  List<Zone> zones = const [],
  List<Zone> presetZones = const [],
  bool withSampleData = true,
}) {
  final out = BytesBuilder();

  Uint8List chunk(String id, List<int> body) {
    final head = BytesBuilder();
    head.add(id.codeUnits);
    final size = ByteData(4)..setUint32(0, body.length, Endian.little);
    head.add(size.buffer.asUint8List());
    head.add(body);
    if (body.length.isOdd) head.addByte(0);
    return head.toBytes();
  }

  List<int> fixed(String text, int width) {
    final bytes = List.filled(width, 0);
    for (var i = 0; i < text.length && i < width - 1; i++) {
      bytes[i] = text.codeUnitAt(i);
    }
    return bytes;
  }

  List<int> u16(int value) =>
      (ByteData(2)..setUint16(0, value, Endian.little)).buffer.asUint8List();
  List<int> u32(int value) =>
      (ByteData(4)..setUint32(0, value, Endian.little)).buffer.asUint8List();

  // ── sdta: every sample end to end, with the spec's 46 zero frames after
  // each one so nothing bleeds into the next.
  final pcm = BytesBuilder();
  final starts = <int>[];
  for (final s in samples) {
    starts.add(pcm.length ~/ 2);
    for (var i = 0; i < s.length; i++) {
      // A ramp, so a test can tell which part of the sample it is holding.
      pcm.add(u16(i * 100 & 0x7FFF));
    }
    pcm.add(Uint8List(46 * 2));
  }

  // ── pdta
  final phdr = BytesBuilder()
    ..add(fixed('Preset', 20))
    ..add(u16(0)) // program
    ..add(u16(bank))
    ..add(u16(0)) // first preset bag
    ..add(u32(0))
    ..add(u32(0))
    ..add(u32(0))
    // The terminal record every table ends with.
    ..add(fixed('EOP', 20))
    ..add(u16(0))
    ..add(u16(0))
    ..add(u16(1))
    ..add(u32(0))
    ..add(u32(0))
    ..add(u32(0));

  // The preset zones. One plain zone pointing at instrument 0 unless the
  // caller asks for its own, which is how a real font narrows by key and
  // velocity at the preset level before ever reaching the instrument.
  final pbag = BytesBuilder();
  final pgen = BytesBuilder();
  var pgenAt = 0;
  for (final split in presetZones.isEmpty ? [null] : presetZones) {
    pbag
      ..add(u16(pgenAt))
      ..add(u16(0));
    if (split != null) {
      pgen
        ..add(u16(43))
        ..add(u16(split.keyLow | (split.keyHigh << 8)))
        ..add(u16(44))
        ..add(u16(split.velLow | (split.velHigh << 8)));
      pgenAt += 2;
    }
    pgen
      ..add(u16(41))
      ..add(u16(0)); // instrument 0
    pgenAt += 1;
  }
  pbag
    ..add(u16(pgenAt))
    ..add(u16(0));
  pgen
    ..add(u16(0))
    ..add(u16(0)); // terminal

  final inst = BytesBuilder()
    ..add(fixed('Instrument', 20))
    ..add(u16(0))
    ..add(fixed('EOI', 20))
    ..add(u16(zones.length));

  final ibag = BytesBuilder();
  final igen = BytesBuilder();
  var gen = 0;
  for (final z in zones) {
    ibag
      ..add(u16(gen))
      ..add(u16(0));
    igen
      ..add(u16(43))
      ..add(u16(z.keyLow | (z.keyHigh << 8)))
      ..add(u16(44))
      ..add(u16(z.velLow | (z.velHigh << 8)))
      ..add(u16(54))
      ..add(u16(samples[z.sample].loops ? 1 : 0))
      // sampleID last, as the spec requires.
      ..add(u16(53))
      ..add(u16(z.sample));
    gen += 4;
  }
  ibag
    ..add(u16(gen))
    ..add(u16(0));
  igen
    ..add(u16(0))
    ..add(u16(0));

  final shdr = BytesBuilder();
  for (final (i, s) in samples.indexed) {
    shdr
      ..add(fixed(s.name, 20))
      ..add(u32(starts[i]))
      ..add(u32(starts[i] + s.length))
      ..add(u32(starts[i] + 8)) // loop start
      ..add(u32(starts[i] + s.length - 8)) // loop end
      ..add(u32(s.rate))
      ..addByte(s.root)
      ..addByte(s.correction < 0 ? 256 + s.correction : s.correction)
      ..add(u16(0))
      ..add(u16(1)); // mono
  }
  shdr
    ..add(fixed('EOS', 20))
    ..add(u32(0))
    ..add(u32(0))
    ..add(u32(0))
    ..add(u32(0))
    ..add(u32(0))
    ..addByte(0)
    ..addByte(0)
    ..add(u16(0))
    ..add(u16(0));

  List<int> list(String kind, List<Uint8List> chunks) {
    final body = BytesBuilder()..add(kind.codeUnits);
    for (final c in chunks) {
      body.add(c);
    }
    return chunk('LIST', body.toBytes());
  }

  final inner = BytesBuilder()
    ..add('sfbk'.codeUnits)
    ..add(
      list('INFO', [
        chunk('ifil', [2, 0, 1, 0]),
        chunk('INAM', fixed(name, name.length + 1)),
      ]),
    )
    ..add(list('sdta', [if (withSampleData) chunk('smpl', pcm.toBytes())]))
    ..add(
      list('pdta', [
        chunk('phdr', phdr.toBytes()),
        chunk('pbag', pbag.toBytes()),
        chunk('pmod', List.filled(10, 0)),
        chunk('pgen', pgen.toBytes()),
        chunk('inst', inst.toBytes()),
        chunk('ibag', ibag.toBytes()),
        chunk('imod', List.filled(10, 0)),
        chunk('igen', igen.toBytes()),
        chunk('shdr', shdr.toBytes()),
      ]),
    );

  out.add(chunk('RIFF', inner.toBytes()));
  return out.toBytes();
}

/// A drum with one silent hit, for a bank that is only here to carry one
/// melodic instrument into the renderer.
final emptyDrum = DrumSamples([
  [Int16List(1)],
]);

void main() {
  group('reading the file', () {
    test('lists what is in it', () {
      final font = SoundFont.read(
        buildFont(name: 'Nice Piano', samples: [sample()], zones: [zone(0)]),
      );
      expect(font.name, 'Nice Piano');
      expect(font.presets, hasLength(1));
      expect(font.presets.single.name, 'Preset');
      expect(font.presets.single.bank, 0);
      expect(font.presets.single.isPercussion, isFalse);
    });

    test('says so when the file is not a SoundFont at all', () {
      expect(
        () => SoundFont.read(Uint8List.fromList('not a font'.codeUnits)),
        throwsA(isA<SoundFontException>()),
      );
    });

    test('says so when the samples are somewhere else', () {
      // The .sf2pack and two-file fonts, which are a real thing somebody
      // will try, and which would otherwise read as an empty instrument.
      expect(
        () => SoundFont.read(
          buildFont(
            samples: [sample()],
            zones: [zone(0)],
            withSampleData: false,
          ),
        ),
        throwsA(
          isA<SoundFontException>().having(
            (e) => e.message,
            'message',
            contains('no sound'),
          ),
        ),
      );
    });
  });

  group('building an instrument', () {
    test('answers for every key the font says it does', () {
      final font = SoundFont.read(
        buildFont(
          samples: [
            sample(name: 'low', root: 48),
            sample(name: 'middle', root: 60),
            sample(name: 'high', root: 72),
          ],
          zones: [
            zone(0, keyLow: 36, keyHigh: 53),
            zone(1, keyLow: 54, keyHigh: 65),
            zone(2, keyLow: 66, keyHigh: 96),
          ],
        ),
      );
      final instrument = font.instrumentFor(font.presets.single);
      // Not three notes filed under their roots: every key in the ranges,
      // because the font put the seams where it wanted them and they are
      // not halfway between the roots.
      expect(instrument.lowest, 36);
      expect(instrument.highest, 96);
      expect(instrument.pitches, hasLength(61));
    });

    test('a key is played at its own pitch, not its recording\'s', () {
      final font = SoundFont.read(
        buildFont(
          samples: [sample(root: 60)],
          zones: [zone(0, keyLow: 48, keyHigh: 72)],
        ),
      );
      final instrument = font.instrumentFor(font.presets.single);
      // On the root, untouched. A tone up, a tone's worth faster.
      expect(instrument.notes[60]!.single.rate, closeTo(1, 0.0001));
      expect(instrument.notes[62]!.single.rate, closeTo(1.1225, 0.0005));
      expect(instrument.notes[48]!.single.rate, closeTo(0.5, 0.0005));
    });

    test('one recording is shared by every key that plays it', () {
      // Sixty keys off one zone must not be sixty copies of the samples:
      // a real piano preset came to 115 MB that way and 23 shared.
      final font = SoundFont.read(
        buildFont(
          samples: [sample(length: 200)],
          zones: [zone(0, keyLow: 36, keyHigh: 96)],
        ),
      );
      final instrument = font.instrumentFor(font.presets.single);
      final distinct = <Object>{
        for (final takes in instrument.notes.values)
          for (final take in takes) take.samples,
      };
      expect(instrument.pitches, hasLength(61));
      expect(distinct, hasLength(1));
    });

    test('several takes of one note come out softest first', () {
      final font = SoundFont.read(
        buildFont(
          samples: [
            sample(name: 'loud', length: 40),
            sample(name: 'soft', length: 80),
          ],
          zones: [
            zone(0, velLow: 64, velHigh: 127),
            zone(1, velLow: 0, velHigh: 63),
          ],
        ),
      );
      final instrument = font.instrumentFor(font.presets.single);
      // A SoundFont has no round robins, so this is always by velocity.
      expect(instrument.takesAre, Takes.velocity);
      final takes = instrument.notes[60]!;
      expect(takes, hasLength(2));
      // The quiet one is the longer recording, so length says which is which.
      expect(takes.first.samples.length, 80);
      expect(takes.last.samples.length, 40);
    });

    test('a preset zone does not multiply the instrument behind it', () {
      // How a real font is laid out, and the bug it found: the preset
      // carries the articulation map and points every zone of it at one
      // instrument. Walking the instrument once per preset zone gave a
      // piano forty-eight takes of every note and a hundred megabytes.
      final font = SoundFont.read(
        buildFont(
          samples: [
            sample(name: 'low', root: 48),
            sample(name: 'high', root: 72),
          ],
          zones: [
            zone(0, keyLow: 36, keyHigh: 59),
            zone(1, keyLow: 60, keyHigh: 84),
          ],
          presetZones: [
            zone(0, keyLow: 36, keyHigh: 59),
            zone(0, keyLow: 60, keyHigh: 84),
          ],
        ),
      );
      final instrument = font.instrumentFor(font.presets.single);
      // One take a key, not two: each preset zone reaches only the
      // instrument zone it overlaps.
      for (final takes in instrument.notes.values) {
        expect(takes, hasLength(1));
      }
    });

    test('a preset zone narrows what the instrument offers', () {
      final font = SoundFont.read(
        buildFont(
          samples: [sample(root: 60)],
          zones: [zone(0, keyLow: 0, keyHigh: 127)],
          presetZones: [zone(0, keyLow: 60, keyHigh: 72)],
        ),
      );
      final instrument = font.instrumentFor(font.presets.single);
      // The overlap, not either one on its own.
      expect(instrument.lowest, 60);
      expect(instrument.highest, 72);
    });

    test('the velocity layers change over where the font says', () {
      final font = SoundFont.read(
        buildFont(
          samples: [
            sample(name: 'soft'),
            sample(name: 'loud'),
          ],
          zones: [
            zone(0, velLow: 0, velHigh: 99),
            zone(1, velLow: 100, velHigh: 127),
          ],
        ),
      );
      final instrument = font.instrumentFor(font.presets.single);
      // Not halfway: a font's layers are rarely even, and guessing at
      // thirds would play the loud recording for a medium note.
      expect(instrument.velocityBands, hasLength(1));
      expect(instrument.velocityBands.single, closeTo(100 / 127, 0.001));
      final takes = instrument.notes[60]!;
      expect(
        instrument.forVelocity(takes, 0.5).samples.length,
        takes.first.samples.length,
      );
    });

    test('a sample recorded at another rate is played at its own pitch', () {
      final font = SoundFont.read(
        buildFont(samples: [sample(rate: 22050)], zones: [zone(0)]),
      );
      final instrument = font.instrumentFor(font.presets.single);
      // Half our rate, so it is read at half speed and comes out where it
      // was played rather than an octave up.
      expect(instrument.notes[60]!.single.rate, closeTo(0.5, 0.0001));
    });

    test('the tuning the font asks for is folded into that rate', () {
      final font = SoundFont.read(
        buildFont(samples: [sample(correction: 50)], zones: [zone(0)]),
      );
      final instrument = font.instrumentFor(font.presets.single);
      // Fifty cents sharp: a quarter tone, so a ratio of about 1.0293.
      expect(instrument.notes[60]!.single.rate, closeTo(1.0293, 0.0005));
    });

    test('a looping sample brings its loop with it', () {
      final font = SoundFont.read(
        buildFont(samples: [sample(length: 64, loops: true)], zones: [zone(0)]),
      );
      final note = font.instrumentFor(font.presets.single).notes[60]!.single;
      // Written 8 in from each end, and relative to the note rather than to
      // the file, because the file is not what gets played.
      expect(note.loop, (8, 56));
    });

    test('a one-shot has no loop, so nothing goes round for ever', () {
      final font = SoundFont.read(
        buildFont(samples: [sample()], zones: [zone(0)]),
      );
      final note = font.instrumentFor(font.presets.single).notes[60]!.single;
      expect(note.loop, isNull);
    });

    test('a drum kit is refused, with a reason', () {
      // Bank 128 is where the spec keeps percussion. The app plays its own
      // drums and they are a different shape entirely.
      final font = SoundFont.read(
        buildFont(bank: 128, samples: [sample()], zones: [zone(0)]),
      );
      expect(font.presets.single.isPercussion, isTrue);
      expect(
        () => font.instrumentFor(font.presets.single),
        throwsA(
          isA<SoundFontException>().having(
            (e) => e.message,
            'message',
            contains('drum kit'),
          ),
        ),
      );
    });

    test('a preset with nothing playable in it is refused', () {
      // Sound in the file, but the preset reaches none of it.
      final font = SoundFont.read(buildFont(samples: [sample()], zones: []));
      expect(
        () => font.instrumentFor(font.presets.single),
        throwsA(isA<SoundFontException>()),
      );
    });
  });

  group('and playing one', () {
    /// One note of [instrument] held for [seconds], as samples.
    List<int> hold(SampledInstrument instrument, double seconds) {
      final wav = renderSnippet(
        SampleBank(
          bass: instrument,
          piano: instrument,
          guitar: instrument,
          ride: emptyDrum,
          hiHatPedal: emptyDrum,
          hiHatClosed: emptyDrum,
          hiHatOpen: emptyDrum,
          kick: emptyDrum,
          snare: emptyDrum,
          crossStick: emptyDrum,
          cowbell: emptyDrum,
          tomHigh: emptyDrum,
          tomLow: emptyDrum,
        ),
        [(pitch: 60, start: 0, length: seconds, velocity: 0.8, bass: false)],
      );
      return decodeWav(wav).toList();
    }

    test('a looping note is still sounding long after the sample ran out', () {
      // The whole reason the mixer learned about loops. The recording is
      // 64 samples, a thousandth of a second; the note is held for one.
      final font = SoundFont.read(
        buildFont(samples: [sample(length: 64, loops: true)], zones: [zone(0)]),
      );
      final played = hold(font.instrumentFor(font.presets.single), 1);
      expect(played.length, greaterThan(40000));
      // Still moving three quarters of the way through, rather than
      // silence with an eighth of a second of organ at the front.
      final late = played.sublist((played.length * 0.75).round());
      expect(late.any((s) => s.abs() > 0), isTrue);
    });

    test('a one-shot does not, which is the difference', () {
      // Not silence: the snippet renderer puts a room around everything, so
      // a one-shot has a tail. It is the tail of a sound that stopped,
      // though, and the looping one is still being played.
      SampledInstrument of({required bool loops}) {
        final font = SoundFont.read(
          buildFont(
            samples: [sample(length: 64, loops: loops)],
            zones: [zone(0)],
          ),
        );
        return font.instrumentFor(font.presets.single);
      }

      double lateEnergy(List<int> played) {
        final late = played.sublist((played.length * 0.75).round());
        return late.fold<double>(0, (sum, s) => sum + s.abs()) / late.length;
      }

      final looping = lateEnergy(hold(of(loops: true), 1));
      final oneShot = lateEnergy(hold(of(loops: false), 1));
      expect(looping, greaterThan(oneShot * 20));
    });
  });
}
