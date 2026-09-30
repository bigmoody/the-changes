// Keeping an imported instrument on the phone.
//
// The .sf2 it came out of is not kept. A General MIDI font is a hundred
// megabytes holding a hundred and twenty-eight sounds, and somebody wanted
// one of them; carrying the other hundred and twenty-seven around for the
// life of the app, and walking the tables again on every launch, is a
// great deal of phone for no benefit.
//
// So the chosen preset is written out on its own, in the plainest format
// that will hold it: a short piece of JSON saying where each note is, and
// then every sample end to end. Reading it back is one allocation and a
// walk, which matters because it happens while somebody waits for the app
// to open.

import 'dart:convert';
import 'dart:typed_data';

import 'sample_bank.dart';

/// A file that is not one of ours, or is from a version that is not.
class InstrumentFileException implements Exception {
  const InstrumentFileException(this.message);
  final String message;
  @override
  String toString() => message;
}

const _magic = 'TCSI';

/// Bumped when the layout changes. An older file is thrown away and the
/// person is asked to import again, which is a second of their time; the
/// alternative is reading a file that means something else now.
const _version = 1;

/// [instrument] as bytes, to write somewhere.
Uint8List writeInstrument(SampledInstrument instrument) {
  final samples = BytesBuilder();
  // A recording is shared by every key it plays for: a font's lowest zone
  // may answer for two octaves, and an instrument that wrote the same
  // samples out once per key came to 115 MB where 23 would do.
  final written = <Int16List, int>{};
  final notes = <Map<String, Object?>>[];
  for (final pitch in instrument.pitches) {
    final takes = <Map<String, Object?>>[];
    for (final take in instrument.notes[pitch]!) {
      final at = written.putIfAbsent(take.samples, () {
        final offset = samples.length ~/ 2;
        samples.add(Uint8List.sublistView(take.samples));
        return offset;
      });
      takes.add({
        'at': at,
        'length': take.samples.length,
        'rate': take.rate,
        if (take.loop case final loop?) 'loop': [loop.$1, loop.$2],
      });
    }
    notes.add({'pitch': pitch, 'takes': takes});
  }

  final header = utf8.encode(
    jsonEncode({
      'name': instrument.name,
      'takesAre': instrument.takesAre.name,
      'velocityBands': instrument.velocityBands,
      'notes': notes,
    }),
  );

  final out = BytesBuilder()
    ..add(ascii.encode(_magic))
    ..add(_uint32(_version))
    ..add(_uint32(header.length))
    ..add(header)
    ..add(samples.toBytes());
  return out.toBytes();
}

/// Reads back what [writeInstrument] wrote.
SampledInstrument readInstrument(Uint8List bytes) {
  if (bytes.length < 12 || ascii.decode(bytes.sublist(0, 4)) != _magic) {
    throw const InstrumentFileException('That is not a saved instrument.');
  }
  final data = ByteData.sublistView(bytes);
  if (data.getUint32(4, Endian.little) != _version) {
    throw const InstrumentFileException(
      'That instrument was saved by an older version of the app. Import '
      'the SoundFont again.',
    );
  }
  final headerLength = data.getUint32(8, Endian.little);
  if (12 + headerLength > bytes.length) {
    throw const InstrumentFileException('That saved instrument is cut short.');
  }
  final header = jsonDecode(
    utf8.decode(bytes.sublist(12, 12 + headerLength)),
  ) as Map<String, Object?>;
  final samplesAt = 12 + headerLength;

  final notes = <int, List<SampledNote>>{};
  // Read once and shared again, the same way they were written.
  final read = <int, Int16List>{};
  for (final note in (header['notes'] as List).cast<Map<String, Object?>>()) {
    final takes = <SampledNote>[];
    for (final take in (note['takes'] as List).cast<Map<String, Object?>>()) {
      final at = take['at'] as int;
      final length = take['length'] as int;
      final from = samplesAt + at * 2;
      if (from + length * 2 > bytes.length) {
        throw const InstrumentFileException(
          'That saved instrument is cut short.',
        );
      }
      final samples = read.putIfAbsent(at, () {
        final out = Int16List(length);
        for (var i = 0; i < length; i++) {
          out[i] = data.getInt16(from + i * 2, Endian.little);
        }
        return out;
      });
      final loop = take['loop'] as List?;
      takes.add(
        SampledNote(
          samples,
          rate: (take['rate'] as num).toDouble(),
          loop: loop == null ? null : (loop[0] as int, loop[1] as int),
        ),
      );
    }
    notes[note['pitch'] as int] = takes;
  }
  if (notes.isEmpty) {
    throw const InstrumentFileException('That saved instrument has no notes.');
  }

  return SampledInstrument(
    name: header['name'] as String? ?? 'Imported',
    takesAre: Takes.values.firstWhere(
      (t) => t.name == header['takesAre'],
      orElse: () => Takes.velocity,
    ),
    velocityBands: [
      for (final band in (header['velocityBands'] as List? ?? const []))
        (band as num).toDouble(),
    ],
    notes: notes,
  );
}

Uint8List _uint32(int value) =>
    (ByteData(4)..setUint32(0, value, Endian.little)).buffer.asUint8List();
