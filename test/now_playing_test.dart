import 'dart:math' as math;

// The chord readout and the controls have to fit on the narrowest phone we
// support, without cutting anything off.
//
// Widget tests normally draw every character as a square box, which is far
// wider than a real letter, so this test loads the Roboto that Flutter ships
// with and measures against that instead.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/theme.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/screens/practice_screen.dart';
import 'package:play_along/settings/app_settings.dart';

/// The material fonts in the Flutter SDK's cache, next to the Dart VM that's
/// running this test.
Directory get _materialFonts {
  var directory = File(Platform.resolvedExecutable).parent;
  while (directory.path != directory.parent.path) {
    final fonts = Directory('${directory.path}/artifacts/material_fonts');
    if (fonts.existsSync()) return fonts;
    directory = directory.parent;
  }
  throw StateError('No material fonts found in the Flutter SDK cache');
}

Future<void> _loadRoboto() async {
  for (final (family, path) in [
    ('Roboto', '${_materialFonts.path}/Roboto-Regular.ttf'),
    ('Roboto', '${_materialFonts.path}/Roboto-Medium.ttf'),
    // The chart's hand lettering, which the chords are measured in.
    (handFont, 'assets/fonts/PetalumaScript.otf'),
  ]) {
    final bytes = await File(path).readAsBytes();
    await (FontLoader(
      family,
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
  // For the Δ, which the lettering borrows from the system on a phone.
  handFontFallback = ['Roboto'];
}

void main() {
  setUpAll(_loadRoboto);

  for (final (name, size) in [
    ('iPhone SE', Size(375, 667)),
    ('iPhone 15', Size(393, 852)),
    ('iPad mini', Size(744, 1133)),
  ]) {
    for (final diagram in ChordDiagram.values) {
      testWidgets('the practice screen fits on a $name (${diagram.label})', (
        tester,
      ) async {
        tester.view
          ..physicalSize = size * 3
          ..devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        // "Take the 'A' Train": D7♯11 has a long quality name *and*
        // extensions, so its readout is the tightest fit in the library.
        final tune = standards.firstWhere((t) => t.title.contains('A" Train'));
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme(Brightness.light, fontFamily: 'Roboto'),
            home: PracticeScreen(
              tune: tune,
              player: PracticePlayer(),
              settings: AppSettings.inMemory(ChartInstrument.concert, diagram),
            ),
          ),
        );

        void expectNothingCutOff(String where) {
          for (final paragraph in tester.renderObjectList<RenderParagraph>(
            find.byType(RichText),
          )) {
            expect(
              paragraph.didExceedMaxLines,
              isFalse,
              reason:
                  'cut off on a $name $where: '
                  '"${paragraph.text.toPlainText()}"',
            );
          }
        }

        // No ellipsis anywhere: every label is readable in full.
        expectNothingCutOff('at rest');

        // Loop the D7♯11 bar so the readout shows that chord, which is the
        // widest: a long quality name, four tones and two extensions.
        await tester.tap(find.text('D7♯11').first);
        await tester.pumpAndSettle();
        expect(find.textContaining('ext '), findsOneWidget);
        expectNothingCutOff('with D7♯11 showing');
      });
    }
  }

  for (final (name, size) in [
    ('iPhone SE', Size(375, 667)),
    ('iPhone 15', Size(393, 852)),
  ]) {
    testWidgets(
      'the part buttons, Arpeggios included, are readable on a $name',
      (tester) async {
        tester.view
          ..physicalSize = size * 3
          ..devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme(Brightness.light, fontFamily: 'Roboto'),
            home: PracticeScreen(
              tune: standards.firstWhere((t) => t.title == 'Autumn Leaves'),
              player: PracticePlayer(),
              settings: AppSettings.inMemory(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final part in ['Piano', 'Bass', 'Drums', 'Arpeggios']) {
          final drawn = tester.getRect(find.text(part)).height;
          final natural = tester.renderObject<RenderBox>(find.text(part)).size;
          final scale = drawn / natural.height;
          debugPrint('$name: $part drawn at ${(scale * 100).round()}%');
          expect(scale, greaterThan(0.85), reason: part);
        }
      },
    );
  }

  group('chord size', () {
    // How wide the first chord on the chart is drawn, in points.
    Future<double> chordWidth(
      WidgetTester tester, {
      required String title,
      required String chord,
      double textScale = 1,
    }) async {
      tester.view
        ..physicalSize = const Size(393, 852) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final tune = standards.firstWhere((t) => t.title.contains(title));
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: const Size(393, 852),
            textScaler: TextScaler.linear(textScale),
          ),
          child: MaterialApp(
            theme: appTheme(Brightness.light, fontFamily: 'Roboto'),
            home: PracticeScreen(
              tune: tune,
              player: PracticePlayer(),
              settings: AppSettings.inMemory(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle(); // lets the guitar shapes be worked out
      // The width of the chord as drawn grows in step with its size, whatever
      // the line spacing, so it's the fairest measure of what the eye sees.
      final width = tester.getRect(find.text(chord).first).width;
      debugPrint(
        '$title $chord at ×$textScale: ${width.toStringAsFixed(1)} wide',
      );
      return width;
    }

    testWidgets('a long tune is readable on a phone', (tester) async {
      // Cherokee is 64 bars: the most there is to fit on one screen.
      final width = await chordWidth(tester, title: 'Cherokee', chord: 'Cm7');
      expect(width, greaterThanOrEqualTo(38));
    });

    /// Every chord's size on the chart (not the big readout below it), and
    /// how many chords share its bar.
    List<({double size, int inBar})> chartSizes(WidgetTester tester) {
      bool isChord(Widget widget) =>
          widget is Text &&
          widget.textScaler == TextScaler.noScaling &&
          widget.style?.fontFamily == handFont;
      final chords = find.byWidgetPredicate(isChord);
      return [
        for (final element in chords.evaluate())
          (
            size: (element.widget as Text).style!.fontSize!,
            inBar: find
                .descendant(
                  of: find
                      .ancestor(
                        of: find.byWidget(element.widget),
                        matching: find.byType(Row),
                      )
                      .first,
                  matching: chords,
                )
                .evaluate()
                .length,
          ),
      ];
    }

    for (final (title, chord) in [
      ('Mercy', 'E♭/B♭'),
      ('Anthropology', 'E♭Δ7'),
      ('Green Dolphin', 'F7/E♭'),
      ('Moanin', 'G7♭9'),
      // Long pairs like F♯13 F♯7alt: drawn smaller side by side, rather
      // than shrinking the whole chart to fit them.
      ('Wave', 'F♯13'),
      ('Cherokee', 'Cm7'),
      ('Autumn Leaves', 'Cm7'),
    ]) {
      testWidgets('$title: every bar of one chord is one size', (tester) async {
        final width = await chordWidth(tester, title: title, chord: chord);
        final all = chartSizes(tester);
        expect(all.length, greaterThan(20));
        final sizes = [
          for (final chord in all)
            if (chord.inBar == 1) chord.size,
        ];
        // All the same, bar the odd extreme chord left to shrink alone.
        final common = sizes.reduce(math.max);
        debugPrint('$title: chords drawn at ${common.toStringAsFixed(1)}');
        final same = sizes.where((size) => size == common).length;
        expect(same / sizes.length, greaterThan(0.9), reason: '$sizes');
        // Two in a bar are never drawn bigger than one.
        for (final chord in all) {
          expect(chord.size, lessThanOrEqualTo(common));
        }
        // And big enough to read on a phone.
        expect(common, greaterThanOrEqualTo(18));
        // A chord sharing its bar is drawn smaller, but not much.
        expect(width, greaterThan(20));
      });
    }

    testWidgets('a busy bar reads left to right, as on a page', (tester) async {
      await chordWidth(tester, title: 'Mercy', chord: 'E♭/B♭');
      final first = tester.getRect(find.text('B♭').first);
      final second = tester.getRect(find.text('E♭/B♭').first);
      expect(second.left, greaterThan(first.right - 1));
      expect(second.center.dy, closeTo(first.center.dy, 1));
    });

    testWidgets('Larger Text makes the chart bigger, and it scrolls', (
      tester,
    ) async {
      // The chart is the only thing on the screen that may scroll up and
      // down, and only when Larger Text has pushed it past the glass. The
      // loop bar has a sideways scroller of its own for its chips, which
      // isn't the chart giving up on one screen, so it isn't counted here.
      final chartScrolls = find.byWidgetPredicate(
        (w) => w is SingleChildScrollView && w.scrollDirection == Axis.vertical,
      );
      // The height of the first bar's box: what Larger Text grows.
      final firstBar = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            (w.properties.label?.startsWith('Bars 1 and') ?? false),
      );
      final normal = await chordWidth(tester, title: 'Cherokee', chord: 'Cm7');
      final normalRow = tester.getRect(firstBar).height;
      expect(chartScrolls, findsNothing);

      final large = await chordWidth(
        tester,
        title: 'Cherokee',
        chord: 'Cm7',
        textScale: 2.0,
      );
      expect(tester.getRect(firstBar).height, greaterThan(normalRow * 1.3));
      // Chords never get smaller (here they already fill the box's width).
      expect(large, greaterThanOrEqualTo(normal - 0.01));
      // It no longer fits, so the chart scrolls instead of shrinking it.
      expect(
        find.descendant(of: find.byType(Stack), matching: chartScrolls),
        findsOneWidget,
      );
    });
  });

  group('bar numbers never sit on a chord', () {
    for (final title in ['Blue Bossa', 'Cherokee', 'Mercy']) {
      for (final textScale in [1.0, 1.6, 2.0]) {
        testWidgets('$title at text size ×$textScale', (tester) async {
          tester.view
            ..physicalSize = const Size(393, 852) * 3
            ..devicePixelRatio = 3;
          addTearDown(tester.view.reset);
          final tune = standards.firstWhere((t) => t.title.contains(title));
          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: const Size(393, 852),
                textScaler: TextScaler.linear(textScale),
              ),
              child: MaterialApp(
                theme: appTheme(Brightness.light, fontFamily: 'Roboto'),
                home: PracticeScreen(
                  tune: tune,
                  player: PracticePlayer(),
                  settings: AppSettings.inMemory(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final numbers = find.byWidgetPredicate(
            (w) => w is Text && RegExp(r'^\d+$').hasMatch(w.data ?? ''),
          );
          var checked = 0;
          for (final number in numbers.evaluate()) {
            final cell = find
                .ancestor(
                  of: find.byWidget(number.widget),
                  matching: find.byType(Stack),
                )
                .first;
            final numberRect = tester.getRect(find.byWidget(number.widget));
            for (final text
                in find
                    .descendant(of: cell, matching: find.byType(Text))
                    .evaluate()) {
              if (identical(text.widget, number.widget)) continue;
              final chordRect = tester.getRect(find.byWidget(text.widget));
              expect(
                numberRect.overlaps(chordRect),
                isFalse,
                reason:
                    'bar ${(number.widget as Text).data} covers '
                    '"${(text.widget as Text).data}"',
              );
              checked++;
            }
          }
          debugPrint('$title ×$textScale: $checked number/chord pairs clear');
        });
      }
    }
  });
}
