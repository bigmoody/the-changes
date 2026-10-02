// Pointing at the colour you mean.
//
// The square is saturation across and brightness up; the strip under it
// is the hue. These check that where you point is what you get, because
// a picker that is merely pretty is worse than the sliders it replaced.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/screens/colour_picker.dart';

/// Opens the picker and hands back whatever it is closed with.
Future<Color?> pick(
  WidgetTester tester, {
  Color? start,
  required Future<void> Function(WidgetTester tester) use,
}) async {
  Color? kept;
  var opened = false;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                opened = true;
                kept = await pickColour(
                  context,
                  title: 'A Colour',
                  start: start,
                  clearLabel: 'No Colour',
                  preview: (colour) => Container(
                    key: const ValueKey('preview'),
                    height: 40,
                    color: colour,
                  ),
                );
              },
              child: const Text('Pick'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Pick'));
  await tester.pumpAndSettle();
  expect(opened, isTrue);
  await use(tester);
  return kept;
}

/// The colour the preview is showing, which is what the picker is on.
Color previewColour(WidgetTester tester) =>
    (tester.widget<Container>(find.byKey(const ValueKey('preview'))).color)!;

/// A point a fraction of the way across and down a widget, kept just
/// inside it: a tap exactly on the edge lands outside and picks nothing.
Offset inside(WidgetTester tester, Key key, double across, double down) {
  final box = tester.getRect(find.byKey(key));
  return Offset(
    (box.left + box.width * across).clamp(box.left + 2, box.right - 2),
    (box.top + box.height * down).clamp(box.top + 2, box.bottom - 2),
  );
}

void main() {
  testWidgets('it opens on the colour it was given', (tester) async {
    await pick(
      tester,
      start: const Color(0xFF1A3FA0),
      use: (tester) async {
        expect(previewColour(tester), const Color(0xFF1A3FA0));
        await tester.tap(find.byKey(const ValueKey('keep-colour')));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('the top right of the square is the hue at full strength', (
    tester,
  ) async {
    final kept = await pick(
      tester,
      start: const Color(0xFF808080),
      use: (tester) async {
        // Hue first, so the square is showing that hue.
        await tester.tapAt(
          inside(tester, const ValueKey('colour-hues'), 0, 0.5),
        );
        await tester.pumpAndSettle();
        await tester.tapAt(
          inside(tester, const ValueKey('colour-field'), 1, 0),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('keep-colour')));
        await tester.pumpAndSettle();
      },
    );
    // Full saturation, full brightness, at the left-hand end of the hue
    // strip, which is red.
    final hsv = HSVColor.fromColor(kept!);
    expect(hsv.saturation, closeTo(1, 0.05));
    expect(hsv.value, closeTo(1, 0.05));
    expect(hsv.hue, closeTo(0, 4));
  });

  testWidgets('the bottom of the square is black whatever the hue', (
    tester,
  ) async {
    final kept = await pick(
      tester,
      use: (tester) async {
        await tester.tapAt(
          inside(tester, const ValueKey('colour-field'), 0.5, 1),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('keep-colour')));
        await tester.pumpAndSettle();
      },
    );
    expect(HSVColor.fromColor(kept!).value, closeTo(0, 0.05));
  });

  testWidgets('the left of the square is unsaturated', (tester) async {
    final kept = await pick(
      tester,
      use: (tester) async {
        await tester.tapAt(
          inside(tester, const ValueKey('colour-field'), 0, 0),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('keep-colour')));
        await tester.pumpAndSettle();
      },
    );
    expect(HSVColor.fromColor(kept!).saturation, closeTo(0, 0.05));
  });

  testWidgets('the strip runs through the hues, left to right', (tester) async {
    for (final (across, hue) in [(0.0, 0.0), (1 / 3, 120.0), (2 / 3, 240.0)]) {
      final kept = await pick(
        tester,
        use: (tester) async {
          await tester.tapAt(
            inside(tester, const ValueKey('colour-hues'), across, 0.5),
          );
          await tester.pumpAndSettle();
          await tester.tapAt(
            inside(tester, const ValueKey('colour-field'), 1, 0),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('keep-colour')));
          await tester.pumpAndSettle();
        },
      );
      expect(
        HSVColor.fromColor(kept!).hue,
        closeTo(hue, 8),
        reason: 'at $across across',
      );
    }
  });

  testWidgets('dragging across the square follows the finger', (tester) async {
    final kept = await pick(
      tester,
      start: const Color(0xFF1A3FA0),
      use: (tester) async {
        final from = inside(tester, const ValueKey('colour-field'), 0.1, 0.9);
        await tester.dragFrom(from, const Offset(60, -60));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('keep-colour')));
        await tester.pumpAndSettle();
      },
    );
    // Up and to the right is brighter and more saturated than where it
    // started, which is the point of dragging rather than tapping.
    final hsv = HSVColor.fromColor(kept!);
    expect(hsv.saturation, greaterThan(0.1));
    expect(hsv.value, greaterThan(0.1));
  });

  testWidgets('the preview keeps up while you move', (tester) async {
    await pick(
      tester,
      start: const Color(0xFF808080),
      use: (tester) async {
        final before = previewColour(tester);
        await tester.tapAt(
          inside(tester, const ValueKey('colour-field'), 1, 0),
        );
        await tester.pumpAndSettle();
        expect(previewColour(tester), isNot(before));
        await tester.tap(find.byKey(const ValueKey('keep-colour')));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('asking for no colour is still its own answer', (tester) async {
    final kept = await pick(
      tester,
      use: (tester) async {
        await tester.tap(find.byKey(const ValueKey('no-colour')));
        await tester.pumpAndSettle();
      },
    );
    expect(kept, noColour);
  });
}
