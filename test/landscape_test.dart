// The practice screen on a phone held sideways.
//
// Turned sideways a phone has width to spare and hardly any height. Stacked
// the way it is upright, the chart was squeezed to a couple of centimetres
// and the layout overflowed the screen; the controls move beside it
// instead.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/screens/practice_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

Tune _standard(String title) =>
    standards.firstWhere((tune) => tune.title == title);

/// Every screen the app runs on, upright and sideways.
const _screens = {
  'iPhone upright': Size(393, 852),
  'iPhone sideways': Size(852, 393),
  'a small iPhone sideways': Size(667, 375),
  'a big iPhone sideways': Size(932, 430),
  'iPad upright': Size(834, 1194),
  'iPad sideways': Size(1194, 834),
};

Future<void> _open(
  WidgetTester tester,
  Size size, {
  String title = 'Cherokee',
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.light),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: PracticeScreen(
            tune: _standard(title),
            player: PracticePlayer(),
            settings: AppSettings.inMemory(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// How tall the chart itself is on screen.
double _chartHeight(WidgetTester tester) =>
    tester.getRect(find.byKey(const ValueKey('chart'))).height;

void main() {
  group('it fits, whichever way up and whatever the tune', () {
    for (final MapEntry(key: what, value: size) in _screens.entries) {
      testWidgets('on $what', (tester) async {
        for (final title in ['Cherokee', 'So What', 'Autumn Leaves']) {
          await _open(tester, size, title: title);
          expect(tester.takeException(), isNull, reason: '$what, $title');
        }
      });
    }

    testWidgets('sideways with Larger Text turned up', (tester) async {
      await _open(tester, const Size(852, 393), textScale: 1.6);
      expect(tester.takeException(), isNull);
    });
  });

  group('sideways the chart gets the height', () {
    testWidgets('it is most of the screen, not a sliver', (tester) async {
      await _open(tester, const Size(852, 393));
      // Stacked, the chart was left about a fifth of the screen. Beside the
      // controls it keeps nearly all of it.
      expect(_chartHeight(tester), greaterThan(280));
    });

    testWidgets('and the controls are beside it, not under it', (tester) async {
      await _open(tester, const Size(852, 393));
      final chart = tester.getRect(find.byKey(const ValueKey('chart')));
      final play = tester.getRect(find.text('Play'));
      expect(play.left, greaterThan(chart.right - 1));
    });

    testWidgets('upright they stay under it, as a page reads', (tester) async {
      await _open(tester, const Size(393, 852));
      final chart = tester.getRect(find.byKey(const ValueKey('chart')));
      final play = tester.getRect(find.text('Play'));
      expect(play.top, greaterThan(chart.bottom - 1));
    });

    testWidgets('a tablet stays stacked, sideways as well', (tester) async {
      await _open(tester, const Size(1194, 834));
      final chart = tester.getRect(find.byKey(const ValueKey('chart')));
      final play = tester.getRect(find.text('Play'));
      expect(play.top, greaterThan(chart.bottom - 1));
    });
  });
}
