// Renders every groove in three, five and seven to WAV files, so the
// grooves in odd meters can be listened to and judged by ear: two
// choruses of an eight-bar ii-V, drums, bass and piano, with brushes as
// well for the grooves that are played with them.
//
// Usage: dart run tool/render_meter_demos.dart [out directory]

import 'dart:io';
import 'dart:typed_data';

import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/sample_bank.dart';
import 'package:play_along/music/loop_range.dart';
import 'package:play_along/music/meter.dart';
import 'package:play_along/music/tune.dart';

Future<void> main(List<String> args) async {
  final out = Directory(args.isEmpty ? 'meter-demos' : args.first)
    ..createSync(recursive: true);
  final bank = await SampleBank.load(
    (path) async => File('assets/sounds/$path').readAsBytes(),
  );
  const tempos = {
    Feel.swing: 160,
    Feel.jazzWaltz: 160,
    Feel.ballad: 72,
    Feel.shuffle: 120,
    Feel.funk: 100,
    Feel.bossa: 140,
    Feel.samba: 112,
    Feel.calypso: 150,
    Feel.secondLine: 110,
    Feel.gypsy: 180,
  };
  const brushed = {
    Feel.swing,
    Feel.jazzWaltz,
    Feel.ballad,
    Feel.bossa,
    Feel.calypso,
  };
  for (final beats in [3, 5, 7]) {
    for (final MapEntry(key: feel, value: tempo) in tempos.entries) {
      // Swing in three is the jazz waltz, and in five and seven the
      // waltz is the swing drummer's cells: one file each, not two the
      // same.
      if (feel == (beats == 3 ? Feel.swing : Feel.jazzWaltz)) continue;
      final tune = Tune.fromChart(
        title: '${feel.label} in $beats',
        key: 'C',
        feel: feel,
        meter: Meter(beats, 4),
        defaultTempo: tempo,
        chart: '| Dm7 | G7 | CΔ7 | A7 | Dm7 | G7 | CΔ7 | CΔ7 |',
      );
      for (final sound in [
        DrumSound.kit,
        if (brushed.contains(feel)) DrumSound.brushes,
      ]) {
        final rendered = renderBacking(
          BackingRequest(
            tune: tune,
            loop: LoopRange.wholeTune(tune),
            tempo: tempo,
            countInBars: 1,
            seed: 11,
            samples: bank,
            drumSound: sound,
          ),
        );
        // Two passes of the eight bars, and a breath after: the band
        // renders more choruses than that, and the phrase's fill is in
        // the eighth bar of each.
        final wanted = ((16 * beats * 60 / tempo) * 44100).round() + 44100;
        final stems = [
          for (final i in [
            Instrument.chords,
            Instrument.bass,
            Instrument.drums,
          ])
            decodeWav(rendered.stems[i]!),
        ];
        final mix = Int16List(wanted);
        for (final stem in stems) {
          for (var at = 0; at < wanted; at++) {
            mix[at] = (mix[at] + stem[at % stem.length]).clamp(-32768, 32767);
          }
        }
        final name =
            '$beats-4 ${feel.label}${sound == DrumSound.brushes ? ' (brushes)' : ''}'
                .replaceAll('/', '-');
        File('${out.path}/$name.wav').writeAsBytesSync(_wav(mix, 44100));
        stdout.writeln('wrote $name');
      }
    }
  }
}

Uint8List _wav(Int16List samples, int rate) {
  final data = ByteData(44 + samples.length * 2);
  void text(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  text(0, 'RIFF');
  data.setUint32(4, 36 + samples.length * 2, Endian.little);
  text(8, 'WAVE');
  text(12, 'fmt ');
  data
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, rate, Endian.little)
    ..setUint32(28, rate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little);
  text(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(44 + i * 2, samples[i], Endian.little);
  }
  return data.buffer.asUint8List();
}
