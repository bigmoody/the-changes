// Choosing what the app is printed on.
//
// The derivation is the part worth testing hardest. A paper that leaves
// the ink unreadable, or that flattens every box into the background, is
// worse than no choice at all, and neither shows up in a test that only
// asks whether the setting was saved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return x > y ? (x + 0.05) / (y + 0.05) : (y + 0.05) / (x + 0.05);
}

/// Papers worth trying: the two the app ships with, and then the awkward
/// ones somebody will actually pick.
const papers = {
  'the usual warm paper': Color(0xFFF7F4EE),
  'near black': Color(0xFF151413),
  'white': Color(0xFFFFFFFF),
  'a deep green': Color(0xFF14321E),
  'a pale mint': Color(0xFFD9F2E3),
  'a strong blue': Color(0xFF1B3B8F),
  'mid grey': Color(0xFF808080),
  'a hot pink': Color(0xFFFF4FC3),
};

void main() {
  group('working a scheme out from a paper', () {
    test('the paper is the paper, exactly as chosen', () {
      for (final entry in papers.entries) {
        expect(
          schemeForPaper(entry.value).surface,
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('the ink can always be read on it', () {
      // The one promise worth making. 4.5 is the usual bar for body text;
      // the chart's lettering is large, so this asks for more than that.
      for (final entry in papers.entries) {
        final scheme = schemeForPaper(entry.value);
        expect(
          contrast(scheme.onSurface, scheme.surface),
          greaterThanOrEqualTo(4.5),
          reason: '${entry.key}: ink is hard to read',
        );
      }
    });

    test('the quieter ink can be read too', () {
      for (final entry in papers.entries) {
        final scheme = schemeForPaper(entry.value);
        expect(
          contrast(scheme.onSurfaceVariant, scheme.surface),
          greaterThanOrEqualTo(2.5),
          reason: '${entry.key}: the small print is hard to read',
        );
      }
    });

    test('a dark paper gets a dark scheme, and a light one a light', () {
      expect(
        schemeForPaper(const Color(0xFF14321E)).brightness,
        Brightness.dark,
      );
      expect(
        schemeForPaper(const Color(0xFFD9F2E3)).brightness,
        Brightness.light,
      );
    });

    test('the boxes stay visible against it rather than flattening', () {
      // What a naive "just change the surface" would lose: the cards and
      // rules would end up the same colour as the paper.
      for (final entry in papers.entries) {
        final scheme = schemeForPaper(entry.value);
        expect(
          scheme.surfaceContainerLowest,
          isNot(scheme.surface),
          reason: '${entry.key}: cards vanish into the paper',
        );
        expect(
          contrast(scheme.outlineVariant, scheme.surface),
          greaterThan(1.05),
          reason: '${entry.key}: the rules vanish',
        );
      }
    });

    test('the pencil is left alone, because it is not paper', () {
      // The accent means something; retinting it with the paper's hue
      // would make a green chart have a green "this bar is playing".
      // Two papers of the same lightness and opposite hues, so the only
      // thing that could differ is the retinting.
      final onMint = schemeForPaper(const Color(0xFFD9F2E3));
      final onBlush = schemeForPaper(const Color(0xFFF2D9E3));
      expect(onMint.brightness, onBlush.brightness);
      expect(onMint.tertiary, onBlush.tertiary);
      expect(onMint.error, onBlush.error);
    });

    test('a paper dark enough to need light ink gets the dark pencil', () {
      // Not a contradiction of the above: which of the two schemes a
      // paper belongs to is its lightness, and the pencil comes from
      // whichever that is.
      expect(
        schemeForPaper(const Color(0xFF14321E)).tertiary,
        isNot(schemeForPaper(const Color(0xFFD9F2E3)).tertiary),
      );
    });

    test('the surfaces take the paper\'s hue', () {
      // So the whole thing reads as one paper rather than grey boxes on a
      // coloured background.
      const green = Color(0xFFD9F2E3);
      final scheme = schemeForPaper(green);
      expect(
        HSLColor.fromColor(scheme.surfaceContainer).hue,
        closeTo(HSLColor.fromColor(green).hue, 1),
      );
    });

    test('the whole theme builds on any of them', () {
      for (final entry in papers.entries) {
        final theme = appTheme(Brightness.light, paper: entry.value);
        expect(theme.colorScheme.surface, entry.value, reason: entry.key);
        expect(theme.scaffoldBackgroundColor, entry.value, reason: entry.key);
      }
    });
  });

  group('the setting', () {
    test('follows the system until somebody says otherwise', () {
      expect(AppSettings.inMemory().paper, isNull);
    });

    test('keeps a chosen paper, and gives it back', () async {
      final settings = AppSettings.inMemory();
      await settings.setPaper(const Color(0xFF14321E));
      expect(settings.paper, const Color(0xFF14321E));
    });

    test('and goes back to the system when cleared', () async {
      final settings = AppSettings.inMemory();
      await settings.setPaper(const Color(0xFF14321E));
      await settings.setPaper(null);
      expect(settings.paper, isNull);
    });
  });
}
