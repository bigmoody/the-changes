// Scratch: the count and finder at several leads, on device logs (HEARD lines) or Mac looks.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/other_apps.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/form_finder.dart';
import 'package:play_along/practice/tap_follower.dart';

void main() {
  final env = Platform.environment;
  for (final lead in [0.4, 0.5, 0.6, 0.8]) {
    test('lead $lead', () {
      final tune = standards.firstWhere((t) => t.title == env['TUNE']);
      var now = 0.0;
      Duration d(double s) => Duration(microseconds: (s * 1e6).round());
      final taps = TapFollower(tune: tune, clock: () => d(now));
      final form = FormFinder(tune: tune, lead: lead);
      double? started, placed;
      final shown = <String>[];
      var next = 3.0;
      void tick(double t) {
        while (next < t) {
          shown.add('$next:${taps.placeKnown ? (taps.barAt(d(next)) ?? -1) : -1}');
          next += 1;
        }
        now = t;
      }
      void bar(double start, double end, List<double> pitches) {
        form.heard(d((start + end) / 2), pitches);
        if (!taps.counting) return;
        final move = form.shift(taps.barAt);
        if (move == null) return;
        taps.moveBars(move);
        placed ??= now;
      }
      final path = env['IN']!;
      if (path.contains('looks')) {
        final filter = BarlineFilter();
        double? lastBar;
        for (final look in File(path).readAsStringSync().split('LOOK ').skip(1)) {
          final lines = look.split('\n');
          tick(double.parse(lines[0]));
          final downs = lines[1].split(' ').skip(1).where((x) => x.isNotEmpty).map(double.parse).toList();
          for (final b in filter.take(downs)) {
            taps.heardBarline(d(now - b));
            if (taps.counting) started ??= now;
          }
          final bars = lines.where((l) => l.startsWith('B ')).map((l) => l.split(' ').skip(1).map(double.parse).toList()).toList();
          for (var k = 0; k < bars.length; k++) {
            final start = bars[k][0];
            if (lastBar != null && start <= lastBar + 0.2) continue;
            final end = k + 1 < bars.length ? bars[k + 1][0] : (downs.isEmpty ? null : downs.last);
            if (end == null || end <= start) continue;
            lastBar = start;
            bar(start, end, bars[k].sublist(1));
          }
        }
      } else {
        final lines = File(path).readAsLinesSync().where((l) => l.contains('HEARD')).toList();
        for (var i = 0; i < lines.length; i++) {
          final p = lines[i].trim().split(RegExp(r'\s+'));
          tick(double.parse(p[0]));
          if (p[2] == 'BARLINE') {
            taps.heardBarline(d(now - double.parse(p[3])));
            if (taps.counting) started ??= now;
          } else {
            final start = double.parse(p[3]);
            double? end;
            for (var j = i + 1; j < lines.length; j++) {
              final q = lines[j].trim().split(RegExp(r'\s+'));
              if (q[2] == 'BAR') { end = double.parse(q[3]); break; }
            }
            if (end == null || end <= start) end = start + 1.15;
            bar(start, end, p.sublist(4).map(double.parse).toList());
          }
        }
      }
      // ignore: avoid_print
      print('RUN lead=$lead started=${started?.toStringAsFixed(1)} placed=${placed?.toStringAsFixed(1)} SHOWN ${shown.join(' ')}');
      taps.dispose();
    });
  }
}
