// Reading somebody else's WAV.
//
// The files are built here byte by byte rather than kept as fixtures, so
// what each test is actually about is on the page: a stray chunk, an
// unusual bit depth, a size that overruns the file.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/wav_file.dart';

/// A WAV holding [body] as its data chunk.
Uint8List wav({
  required Uint8List body,
  int format = 1,
  int channels = 1,
  int rate = 44100,
  int bits = 16,
  List<(String, Uint8List)> extra = const [],
  int? dataSize,
  Uint8List? fmt,
}) {
  final out = BytesBuilder();
  void u32(BytesBuilder b, int value) => b.add(
    Uint8List(4)..buffer.asByteData().setUint32(0, value, Endian.little),
  );
  void u16(BytesBuilder b, int value) => b.add(
    Uint8List(2)..buffer.asByteData().setUint16(0, value, Endian.little),
  );

  final header =
      fmt ??
      () {
        final f = BytesBuilder();
        u16(f, format);
        u16(f, channels);
        u32(f, rate);
        u32(f, rate * channels * bits ~/ 8); // byte rate
        u16(f, channels * bits ~/ 8); // block align
        u16(f, bits);
        return f.toBytes();
      }();

  final chunks = BytesBuilder();
  chunks.add('fmt '.codeUnits);
  u32(chunks, header.length);
  chunks.add(header);
  if (header.length.isOdd) chunks.add([0]);
  for (final (id, data) in extra) {
    chunks.add(id.codeUnits);
    u32(chunks, data.length);
    chunks.add(data);
    if (data.length.isOdd) chunks.add([0]);
  }
  chunks.add('data'.codeUnits);
  u32(chunks, dataSize ?? body.length);
  chunks.add(body);

  final payload = chunks.toBytes();
  out.add('RIFF'.codeUnits);
  u32(out, payload.length + 4);
  out.add('WAVE'.codeUnits);
  out.add(payload);
  return out.toBytes();
}

Uint8List bytesOf(List<int> values) => Uint8List.fromList(values);

/// Signed 16-bit samples, little endian.
Uint8List pcm16(List<int> samples) {
  final out = Uint8List(samples.length * 2);
  final view = ByteData.sublistView(out);
  for (final (i, sample) in samples.indexed) {
    view.setInt16(i * 2, sample, Endian.little);
  }
  return out;
}

void main() {
  group('what comes out', () {
    test('the samples, the rate and the channels', () {
      final read = readWav(
        wav(body: pcm16([0, 16384, -16384, 32767]), rate: 48000),
      );
      expect(read.sampleRate, 48000);
      expect(read.channels, 1);
      expect(read.frames, 4);
      expect(read.samples[0], 0);
      expect(read.samples[1], closeTo(0.5, 0.0001));
      expect(read.samples[2], closeTo(-0.5, 0.0001));
      expect(read.samples[3], closeTo(1, 0.001));
    });

    test('stereo counts frames, not samples', () {
      final read = readWav(wav(body: pcm16([1, 2, 3, 4, 5, 6]), channels: 2));
      expect(read.channels, 2);
      expect(read.frames, 3, reason: 'three instants, six numbers');
      expect(read.samples.length, 6);
    });

    test('how long it is', () {
      final read = readWav(
        wav(body: pcm16(List.filled(88200, 0)), channels: 2, rate: 44100),
      );
      expect(read.seconds, closeTo(1, 0.0001));
    });
  });

  group('the bit depths', () {
    // The template asks for 24-bit, which is the one that needs assembling
    // by hand: there is no 24-bit integer to read it into.
    test('24-bit, both signs', () {
      // 0x400000 is half of full scale; 0xC00000 is minus that.
      final body = bytesOf([0x00, 0x00, 0x40, 0x00, 0x00, 0xC0]);
      final read = readWav(wav(body: body, bits: 24));
      expect(read.frames, 2);
      expect(read.samples[0], closeTo(0.5, 0.0001));
      expect(read.samples[1], closeTo(-0.5, 0.0001));
    });

    test('8-bit is the unsigned one', () {
      final read = readWav(wav(body: bytesOf([128, 255, 0]), bits: 8));
      expect(read.samples[0], 0, reason: '128 is the middle, not full scale');
      expect(read.samples[1], closeTo(0.99, 0.01));
      expect(read.samples[2], -1);
    });

    test('32-bit float comes through as it is', () {
      final body = Uint8List(8);
      ByteData.sublistView(body)
        ..setFloat32(0, 0.25, Endian.little)
        ..setFloat32(4, -0.75, Endian.little);
      final read = readWav(wav(body: body, format: 3, bits: 32));
      expect(read.samples[0], closeTo(0.25, 0.0001));
      expect(read.samples[1], closeTo(-0.75, 0.0001));
    });

    test('32-bit integer', () {
      final body = Uint8List(4);
      ByteData.sublistView(body).setInt32(0, 1073741824, Endian.little);
      final read = readWav(wav(body: body, bits: 32));
      expect(read.samples[0], closeTo(0.5, 0.0001));
    });
  });

  group('files as a DAW actually writes them', () {
    test('chunks the app has no use for are stepped over', () {
      final read = readWav(
        wav(
          body: pcm16([16384]),
          extra: [
            ('LIST', bytesOf(List.filled(20, 65))),
            ('bext', bytesOf(List.filled(64, 0))),
          ],
        ),
      );
      expect(read.frames, 1);
      expect(read.samples[0], closeTo(0.5, 0.0001));
    });

    test('an odd length chunk is padded, and the pad is not in the size', () {
      final read = readWav(
        wav(
          body: pcm16([16384]),
          extra: [
            ('junk', bytesOf([1, 2, 3])),
          ],
        ),
      );
      expect(read.samples[0], closeTo(0.5, 0.0001));
    });

    test('extensible says the real format in its subformat', () {
      // WAVE_FORMAT_EXTENSIBLE, with PCM as the subformat.
      final header = Uint8List(40);
      ByteData.sublistView(header)
        ..setUint16(0, 0xFFFE, Endian.little)
        ..setUint16(2, 1, Endian.little)
        ..setUint32(4, 44100, Endian.little)
        ..setUint32(8, 88200, Endian.little)
        ..setUint16(12, 2, Endian.little)
        ..setUint16(14, 16, Endian.little)
        ..setUint16(16, 22, Endian.little) // cbSize
        ..setUint16(24, 1, Endian.little); // the subformat GUID starts with PCM
      final read = readWav(wav(body: pcm16([16384]), fmt: header));
      expect(read.samples[0], closeTo(0.5, 0.0001));
    });

    test('a half copied file gives back what is there', () {
      // The size says far more audio than the file holds. Throwing would
      // lose a recording that is almost entirely fine.
      final read = readWav(wav(body: pcm16([16384, 0]), dataSize: 999999));
      expect(read.frames, 2);
    });
  });

  group('what it refuses, and what it says', () {
    test('not a WAV at all', () {
      expect(
        () => readWav(bytesOf([...'ID3'.codeUnits, ...List.filled(64, 0)])),
        throwsA(
          isA<WavFormatException>().having(
            (e) => e.message,
            'message',
            contains('not a WAV'),
          ),
        ),
      );
    });

    test('too short to be anything', () {
      expect(
        () => readWav(bytesOf([1, 2, 3])),
        throwsA(isA<WavFormatException>()),
      );
    });

    test('compressed, and says so in those words', () {
      expect(
        () => readWav(wav(body: pcm16([0]), format: 0x11)),
        throwsA(
          isA<WavFormatException>().having(
            (e) => e.message,
            'message',
            contains('compressed'),
          ),
        ),
      );
    });

    test('a bit depth the app does not read names the depth', () {
      expect(
        () => readWav(wav(body: pcm16([0]), bits: 12)),
        throwsA(
          isA<WavFormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('12-bit'), contains('24-bit')),
          ),
        ),
      );
    });

    test('no audio in it', () {
      final headerOnly = BytesBuilder()
        ..add('RIFF'.codeUnits)
        ..add(bytesOf([4, 0, 0, 0]))
        ..add('WAVE'.codeUnits);
      expect(
        () => readWav(headerOnly.toBytes()),
        throwsA(isA<WavFormatException>()),
      );
    });
  });
}
