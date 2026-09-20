// Icon buttons have to be visible.
//
// The app paints plain icon buttons in the same ink as the text, and a
// theme's icon button style applies to every kind of icon button — filled
// ones included. In this palette the primary colour and the text ink are
// the same near-black, so a filled icon button inherits dark-on-dark and
// vanishes. It happened once, on the stage screen's play button.
//
// These measure what actually gets painted: the colour of the glyph
// against the colour of the button under it.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/theme.dart';

/// How far apart two colours are to the eye, as the accessibility
/// guidelines count it: 1 is identical, 21 is black on white. Anything
/// under about 3 is unreadable at a glance.
double _contrast(Color a, Color b) {
  final light = a.computeLuminance();
  final dark = b.computeLuminance();
  final brighter = light > dark ? light : dark;
  final dimmer = light > dark ? dark : light;
  return (brighter + 0.05) / (dimmer + 0.05);
}

/// The colour the glyph is actually painted in.
Color _iconColour(WidgetTester tester, IconData icon) => tester
    .widget<RichText>(
      find.descendant(of: find.byIcon(icon), matching: find.byType(RichText)),
    )
    .text
    .style!
    .color!;

/// The colour of the button under the glyph, or null where it's see-through.
Color? _buttonColour(WidgetTester tester, IconData icon) {
  final material = tester.widgetList<Material>(
    find.ancestor(of: find.byIcon(icon), matching: find.byType(Material)),
  );
  for (final layer in material) {
    final colour = layer.color;
    if (colour != null && colour.a > 0) return colour;
  }
  return null;
}

Future<void> _pump(WidgetTester tester, Brightness brightness) async {
  await tester.pumpWidget(
    MaterialApp(
      key: ValueKey(brightness),
      theme: appTheme(brightness),
      home: Builder(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          return Scaffold(
            body: Column(
              children: [
                IconButton(icon: const Icon(Icons.abc), onPressed: () {}),
                IconButton.filled(
                  style: filledIconButton(scheme),
                  icon: const Icon(Icons.ac_unit),
                  onPressed: () {},
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.access_alarm),
                  onPressed: () {},
                ),
                IconButton.outlined(
                  icon: const Icon(Icons.accessible),
                  onPressed: () {},
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('every filled icon button in the app says its own colours', () {
    // The guard that makes the rest of this file worth having: a new
    // filled icon button written without [filledIconButton] would be dark
    // on dark, and no widget test would think to look at it.
    final missing = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      // Exactly the filled one: filledTonal sits on a pale background and
      // the text's ink reads fine on it, which the contrast tests below
      // check for themselves.
      var at = source.indexOf('IconButton.filled(');
      while (at >= 0) {
        // The style is given in the first few lines of the call.
        final call = source.substring(at, math.min(at + 400, source.length));
        if (!call.contains('filledIconButton(')) {
          final line = '\n'.allMatches(source.substring(0, at)).length + 1;
          missing.add('${file.path}:$line');
        }
        at = source.indexOf('IconButton.filled(', at + 1);
      }
    }
    expect(
      missing,
      isEmpty,
      reason: 'these would be invisible: ${missing.join(', ')}',
    );
  });

  for (final brightness in Brightness.values) {
    group('in ${brightness.name}', () {
      testWidgets('a plain one is drawn in the ink the text is in', (
        tester,
      ) async {
        await _pump(tester, brightness);
        final scheme = appTheme(brightness).colorScheme;
        expect(_iconColour(tester, Icons.abc), scheme.onSurface);
        expect(
          _buttonColour(tester, Icons.abc),
          isNot(scheme.primary),
          reason: 'nothing filled behind it',
        );
      });

      testWidgets('a filled one can be seen against its own background', (
        tester,
      ) async {
        await _pump(tester, brightness);
        final glyph = _iconColour(tester, Icons.ac_unit);
        final button = _buttonColour(tester, Icons.ac_unit);
        expect(button, isNotNull, reason: 'it is filled');
        expect(
          _contrast(glyph, button!),
          greaterThan(4.5),
          reason: 'dark on dark is how this went wrong before',
        );
      });

      testWidgets('a tonal one reads on its pale background as it is', (
        tester,
      ) async {
        await _pump(tester, brightness);
        final glyph = _iconColour(tester, Icons.access_alarm);
        final button = _buttonColour(tester, Icons.access_alarm);
        expect(button, isNotNull, reason: 'it is filled, palely');
        expect(_contrast(glyph, button!), greaterThan(4.5));
      });

      testWidgets('and without the app\'s style it would not be', (
        tester,
      ) async {
        // The failing case, kept so the reason for [filledIconButton] is
        // written down rather than remembered: the theme's ink on the
        // filled button's background is the same colour twice over.
        final scheme = appTheme(brightness).colorScheme;
        expect(_contrast(scheme.onSurface, scheme.primary), lessThan(1.2));
      });
    });
  }
}
