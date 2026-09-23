// Reading a WAV file into samples.
//
// The band is generated, so until now the app only ever wrote audio files
// and never read one. A recording made to the template is the other way
// round: somebody else's file, chosen in a file picker, and the app has to
// say what is wrong with it when it cannot be used.
//
// Read here rather than handed to the audio engine's own loader for three
// reasons. The template asks for 24-bit, which is the format engines are
// most likely to be fussy about. The recording has to have silence put on
// the front of it so it starts on the count-in's last beat rather than on
// Play. And it has to be cut at bar lines for looping. All three are
// easier on samples than on a file.
//
// Only uncompressed WAV is read. That is what the template asks for, and a
// file that is not one is told so plainly rather than half playing.

import 'dart:typed_data';

class WavFormatException implements Exception {
  const WavFormatException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// The contents of a WAV file, as the audio engine wants them.
class WavAudio {
  const WavAudio({
    required this.sampleRate,
    required this.channels,
    required this.samples,
  });

  final int sampleRate;
  final int channels;

  /// Interleaved, -1 to 1: left, right, left, right for a stereo file.
  final Float32List samples;

  /// How many sampling instants there are, whatever the channel count.
  int get frames => channels == 0 ? 0 : samples.length ~/ channels;

  double get seconds => sampleRate == 0 ? 0 : frames / sampleRate;
}

/// Reads [bytes] as an uncompressed WAV file.
///
/// Throws [WavFormatException] with something a person can act on. Every
/// one of these is a file somebody chose by hand and is entitled to be
/// told about, and "nothing happened" is the one answer that helps nobody.
WavAudio readWav(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  if (bytes.length < 12) {
    throw const WavFormatException('That file is too short to be audio.');
  }
  if (_tag(bytes, 0) != 'RIFF' || _tag(bytes, 8) != 'WAVE') {
    throw const WavFormatException(
      'That is not a WAV file. The template asks for WAV, 44.1 kHz, '
      '24-bit; an MP3 or an AIFF will need converting first.',
    );
  }

  int? format;
  var channels = 0;
  var sampleRate = 0;
  var bits = 0;
  Uint8List? audio;

  // Walk the chunks. A file out of a DAW carries several the app has no
  // use for (LIST, bext, cue points), so anything unrecognised is stepped
  // over rather than treated as a problem.
  var at = 12;
  while (at + 8 <= bytes.length) {
    final id = _tag(bytes, at);
    final size = data.getUint32(at + 4, Endian.little);
    final body = at + 8;
    if (id == 'fmt ') {
      if (size < 16 || body + 16 > bytes.length) {
        throw const WavFormatException('The header of that WAV is damaged.');
      }
      format = data.getUint16(body, Endian.little);
      channels = data.getUint16(body + 2, Endian.little);
      sampleRate = data.getUint32(body + 4, Endian.little);
      bits = data.getUint16(body + 14, Endian.little);
      // Extensible: the real format is the front of the subformat GUID.
      if (format == 0xFFFE && size >= 40 && body + 26 <= bytes.length) {
        format = data.getUint16(body + 24, Endian.little);
      }
    } else if (id == 'data') {
      // A size that overruns the file is what a half-copied recording
      // looks like. Take what is actually there rather than throwing.
      final end = size == 0xFFFFFFFF
          ? bytes.length
          : (body + size).clamp(body, bytes.length);
      audio = Uint8List.sublistView(bytes, body, end);
    }
    // Chunks are padded to an even length, and the pad is not in the size.
    at = body + size + (size.isOdd ? 1 : 0);
    if (size < 0) break;
  }

  if (format == null) {
    throw const WavFormatException('That WAV has no format header.');
  }
  if (audio == null) {
    throw const WavFormatException('That WAV has no audio in it.');
  }
  if (channels < 1) {
    throw const WavFormatException('That WAV says it has no channels.');
  }
  if (sampleRate < 1) {
    throw const WavFormatException('That WAV does not say how fast it runs.');
  }
  if (format != 1 && format != 3) {
    throw const WavFormatException(
      'That WAV is compressed. The app reads plain uncompressed WAV, which '
      'is what the template asks for.',
    );
  }
  if (format == 3 && bits != 32 && bits != 64) {
    throw WavFormatException('The app cannot read $bits-bit floating point.');
  }
  if (format == 1 && bits != 8 && bits != 16 && bits != 24 && bits != 32) {
    throw WavFormatException(
      'The app cannot read $bits-bit audio. The template asks for 24-bit.',
    );
  }

  return WavAudio(
    sampleRate: sampleRate,
    channels: channels,
    samples: _toFloat(audio, format: format, bits: bits),
  );
}

/// Whatever the file held, as -1 to 1.
Float32List _toFloat(
  Uint8List audio, {
  required int format,
  required int bits,
}) {
  final bytesPer = bits ~/ 8;
  final count = audio.length ~/ bytesPer;
  final out = Float32List(count);
  final data = ByteData.sublistView(audio);
  for (var i = 0; i < count; i++) {
    final at = i * bytesPer;
    out[i] = switch ((format, bits)) {
      (3, 32) => data.getFloat32(at, Endian.little),
      (3, _) => data.getFloat64(at, Endian.little),
      // 8-bit WAV is the one integer size that is unsigned.
      (_, 8) => (audio[at] - 128) / 128,
      (_, 16) => data.getInt16(at, Endian.little) / 32768,
      (_, 24) => _int24(audio, at) / 8388608,
      _ => data.getInt32(at, Endian.little) / 2147483648,
    };
  }
  return out;
}

/// A 24-bit little-endian sample, sign extended.
int _int24(Uint8List audio, int at) {
  final value = audio[at] | (audio[at + 1] << 8) | (audio[at + 2] << 16);
  return value >= 0x800000 ? value - 0x1000000 : value;
}

String _tag(Uint8List bytes, int at) =>
    at + 4 > bytes.length ? '' : String.fromCharCodes(bytes, at, at + 4);
