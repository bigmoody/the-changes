// Renders a tune to a WAV file so the band can be listened to outside the
// app. Usage: dart run tool/render_demo.dart "Take the" [--no-drums] [tempo]

import 'dart:io';
import 'dart:typed_data';

import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/sample_bank.dart';
import 'package:play_along/music/loop_range.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';

Future<void> main(List<String> args) async {
  final title = args.isEmpty ? 'Autumn Leaves' : args.first;
  final only = args
      .where((a) => a.startsWith('--only='))
      .map((a) => a.substring(7))
      .toSet();
  final withDrums = !args.contains('--no-drums');
  final tempo = int.tryParse(
    args.lastWhere((a) => int.tryParse(a) != null, orElse: () => ''),
  );

  final bank = await SampleBank.load(
    (path) async => File('assets/sounds/$path').readAsBytes(),
  );
  final tune = standards.firstWhere((t) => t.title.contains(title));
  final rendered = renderBacking(
    BackingRequest(
      tune: tune,
      loop: LoopRange.wholeTune(tune),
      tempo: tempo ?? tune.defaultTempo,
      seed: 11,
      samples: bank,
      comping: args.contains('--guitar') ? Comping.guitar : Comping.piano,
    ),
  );

  final wanted = only.isNotEmpty
      ? [
          for (final i in Instrument.values)
            if (only.contains(i.name)) i,
        ]
      : [Instrument.chords, Instrument.bass, if (withDrums) Instrument.drums];
  final stems = [
    for (final instrument in wanted) decodeWav(rendered.stems[instrument]!),
    if (only.isEmpty) decodeWav(rendered.countIn),
  ];
  final length = stems.map((s) => s.length).reduce((a, b) => a > b ? a : b);
  final mix = Int16List(length);
  for (final stem in stems) {
    for (var i = 0; i < stem.length; i++) {
      mix[i] = (mix[i] + stem[i]).clamp(-32768, 32767);
    }
  }

  final name = tune.title.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
  final out = File(
    '${Platform.environment['DEMO_DIR'] ?? '.'}/The_Changes_$name'
    '${args.contains('--guitar') ? '_guitar' : ''}'
    '${only.isNotEmpty ? '_${only.join('_')}' : (withDrums ? '_band' : '_piano_and_bass')}.wav',
  );
  await out.writeAsBytes(_wav(mix, rendered.sampleRate));
  stdout.writeln('${out.path}  ${(length / rendered.sampleRate).round()} s');
}

Uint8List _wav(Int16List samples, int rate) {
  final bytes = BytesBuilder();
  final header = ByteData(44);
  void ascii(int at, String s) {
    for (var i = 0; i < 4; i++) {
      header.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  header.setUint32(4, 36 + samples.length * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 1, Endian.little);
  header.setUint32(24, rate, Endian.little);
  header.setUint32(28, rate * 2, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  header.setUint32(40, samples.length * 2, Endian.little);
  bytes
    ..add(header.buffer.asUint8List())
    ..add(Uint8List.sublistView(samples));
  return bytes.toBytes();
}
