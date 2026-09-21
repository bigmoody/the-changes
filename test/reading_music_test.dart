// The reading guide draws music symbols by their code points, and a wrong
// one doesn't fail; it draws nothing at all, or a box. So as well as
// checking the page holds together, this reads the font itself and makes
// sure every symbol the guide asks for is actually in it.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/clef.dart';
import 'package:play_along/screens/reading_music_screen.dart';
import 'package:play_along/screens/stave_figure.dart';
import 'package:play_along/screens/tunes_page.dart' show SectionHeader;
import 'package:play_along/theme.dart';

void main() {
  group('the clefs', () {
    test('each one names the note it fixes', () {
      expect(Clef.treble.fixes, (letter: 'G', octave: 4));
      expect(Clef.bass.fixes, (letter: 'F', octave: 3));
      expect(Clef.alto.fixes, (letter: 'C', octave: 4));
      expect(Clef.tenor.fixes, (letter: 'C', octave: 4));
    });

    test('the treble stave reads E G B D F, F A C E', () {
      final up = [for (var s = 0; s <= 8; s++) Clef.treble.noteAt(s).letter];
      expect(up, ['E', 'F', 'G', 'A', 'B', 'C', 'D', 'E', 'F']);
      // The lines are the even steps, the spaces the odd ones.
      expect(
        [for (var s = 0; s <= 8; s += 2) up[s]],
        ['E', 'G', 'B', 'D', 'F'],
      );
      expect([for (var s = 1; s <= 7; s += 2) up[s]], ['F', 'A', 'C', 'E']);
    });

    test('the bass stave reads G B D F A, A C E G', () {
      final up = [for (var s = 0; s <= 8; s++) Clef.bass.noteAt(s).letter];
      expect(
        [for (var s = 0; s <= 8; s += 2) up[s]],
        ['G', 'B', 'D', 'F', 'A'],
      );
      expect([for (var s = 1; s <= 7; s += 2) up[s]], ['A', 'C', 'E', 'G']);
    });

    test('the C clefs put middle C on the line they point at', () {
      expect(Clef.alto.noteAt(4), (letter: 'C', octave: 4));
      expect(Clef.tenor.noteAt(6), (letter: 'C', octave: 4));
    });

    test('middle C is a ledger line outside both staves', () {
      // Below the treble stave, above the bass one, by the same distance.
      expect(Clef.treble.stepOf('C', 4), -2);
      expect(Clef.bass.stepOf('C', 4), 10);
    });

    test('a step is its own inverse', () {
      for (final clef in Clef.values) {
        for (var step = -6; step <= 14; step++) {
          final note = clef.noteAt(step);
          expect(clef.stepOf(note.letter, note.octave), step);
        }
      }
    });
  });

  group('key signatures', () {
    test('the sharps climb the stave in the order they are written', () {
      // F on the top line, then C, G, D, A, E, B.
      final steps = keySignatureSteps(Clef.treble, count: 7, sharp: true);
      expect(steps, [8, 5, 9, 6, 3, 7, 4]);
      expect([
        for (final step in steps) Clef.treble.noteAt(step).letter,
      ], sharpOrder);
    });

    test('the flats fall in the reverse order', () {
      final steps = keySignatureSteps(Clef.treble, count: 7, sharp: false);
      expect([
        for (final step in steps) Clef.treble.noteAt(step).letter,
      ], flatOrder);
      expect(flatOrder, sharpOrder.reversed.toList());
    });

    test('bass is the same shape a line lower, on the same letters', () {
      for (final sharp in [true, false]) {
        final treble = keySignatureSteps(Clef.treble, count: 7, sharp: sharp);
        final bass = keySignatureSteps(Clef.bass, count: 7, sharp: sharp);
        expect(bass, [for (final step in treble) step - 2]);
        expect(
          [for (final step in bass) Clef.bass.noteAt(step).letter],
          [for (final step in treble) Clef.treble.noteAt(step).letter],
        );
      }
    });

    test('a key takes the first few, in order', () {
      expect(keySignatureSteps(Clef.treble, count: 0, sharp: true), isEmpty);
      expect(keySignatureSteps(Clef.treble, count: 3, sharp: false).length, 3);
    });
  });

  group('the font has every symbol the guide draws', () {
    late Set<int> inTheFont;

    setUpAll(() {
      inTheFont = _codePointsIn(File('assets/fonts/Petaluma.otf'));
    });

    test('the font was read', () {
      // Petaluma is a full notation font; if this is small, the reader is
      // wrong rather than the font.
      expect(inTheFont.length, greaterThan(1000));
    });

    test('every named symbol', () {
      final missing = <String>[];
      for (final entry in _named.entries) {
        for (final rune in entry.value.runes) {
          if (!inTheFont.contains(rune)) {
            missing.add('${entry.key} (U+${rune.toRadixString(16)})');
          }
        }
      }
      expect(missing, isEmpty, reason: 'not in Petaluma: $missing');
    });

    test('every clef', () {
      for (final clef in Clef.values) {
        expect(
          inTheFont.contains(clef.glyph.runes.first),
          isTrue,
          reason: '${clef.label} clef',
        );
      }
    });

    test('the digits a time signature and a tuplet are built from', () {
      for (var digit = 0; digit <= 9; digit++) {
        expect(
          inTheFont.contains(Smufl.timeSigDigit(digit).runes.first),
          isTrue,
          reason: 'time signature $digit',
        );
        // The tuplet numbers, which sit just after them in SMuFL.
        expect(
          inTheFont.contains(0xE880 + digit),
          isTrue,
          reason: 'tuplet $digit',
        );
      }
    });
  });

  group('the page', () {
    Future<void> open(WidgetTester tester, {required Size size}) async {
      tester.view
        ..physicalSize = size * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: const ReadingMusicScreen(),
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final (name, size) in [
      ('the narrowest phone', Size(320, 568)),
      ('a normal phone', Size(393, 852)),
      ('a tablet', Size(834, 1112)),
    ]) {
      testWidgets('lays out on $name without overflowing', (tester) async {
        await open(tester, size: size);
        expect(tester.takeException(), isNull);
        // Then all the way down it, in case a figure further on is wider.
        final list = find.byType(Scrollable).first;
        for (var i = 0; i < 40; i++) {
          await tester.drag(list, const Offset(0, -400));
          await tester.pump();
          expect(
            tester.takeException(),
            isNull,
            reason: 'after ${i + 1} drags',
          );
        }
      });
    }

    testWidgets('scrolls through every section, in order', (tester) async {
      await open(tester, size: const Size(393, 852));
      // The page is longer than the screen, so the headings have to be
      // collected on the way down.
      final seen = <String>[];
      final list = find.byType(Scrollable).first;
      for (var i = 0; i < 60; i++) {
        for (final heading in tester.widgetList<SectionHeader>(
          find.byType(SectionHeader),
        )) {
          if (!seen.contains(heading.text)) seen.add(heading.text);
        }
        await tester.drag(list, const Offset(0, -300));
        await tester.pump();
      }
      expect(seen, [
        'The Stave',
        'The Clefs',
        'Lines and Spaces',
        'Middle C and Ledger Lines',
        'Note Values',
        'Beams, Dots and Ties',
        'Accidentals',
        'Key Signatures',
        'Time Signatures',
        'Bars and Repeats',
        'Marks You’ll Meet',
        'And on a Chart',
      ]);
    });

    testWidgets('the contents jump straight to a section', (tester) async {
      await open(tester, size: const Size(393, 852));
      // A section most of the way down, so it can only be on screen if the
      // jump worked rather than because the page happened to start there.
      expect(_heading('Key Signatures'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('contents-Key Signatures')));
      await tester.pumpAndSettle();
      expect(_heading('Key Signatures'), findsOneWidget);
      expect(_heading('The Stave'), findsNothing);
      // And it lands at the top, not merely somewhere on screen.
      expect(tester.getTopLeft(_heading('Key Signatures')).dy, lessThan(200));
    });

    testWidgets('the contents are in the bar too, once past them', (
      tester,
    ) async {
      await open(tester, size: const Size(393, 852));
      await tester.tap(find.byKey(const ValueKey('contents')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Bars and Repeats'));
      await tester.pumpAndSettle();
      expect(_heading('Bars and Repeats'), findsOneWidget);
      expect(tester.getTopLeft(_heading('Bars and Repeats')).dy, lessThan(200));
    });

    testWidgets('each figure with a memory hook carries it underneath', (
      tester,
    ) async {
      await open(tester, size: const Size(393, 852));
      for (final (section, hooks) in [
        // As the note reads: the label, then the phrase.
        (
          'Lines and Spaces',
          [
            'Lines\u2003Every Good Boy Deserves Football',
            'Spaces\u2003F A C E',
            'Lines\u2003Good Boys Deserve Fine Apples',
            'Spaces\u2003All Cows Eat Grass',
          ],
        ),
        (
          'Key Signatures',
          [
            'Father Charles Goes Down And Ends Battle',
            'Battle Ends And Down Goes Charles\u2019 Father',
          ],
        ),
      ]) {
        // Through the bar, which works wherever the last jump left us.
        await tester.tap(find.byKey(const ValueKey('contents')));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ListTile, section));
        await tester.pumpAndSettle();
        for (final hook in hooks) {
          expect(
            find.text(hook, findRichText: true),
            findsOneWidget,
            reason: hook,
          );
        }
      }
    });

    testWidgets('names all four clefs', (tester) async {
      await open(tester, size: const Size(393, 852));
      final seen = <String>{};
      final list = find.byType(Scrollable).first;
      for (var i = 0; i < 20; i++) {
        for (final clef in Clef.values) {
          if (find.text('${clef.label} Clef').evaluate().isNotEmpty) {
            seen.add(clef.label);
          }
        }
        await tester.drag(list, const Offset(0, -300));
        await tester.pump();
      }
      expect(seen, {for (final clef in Clef.values) clef.label});
    });

    testWidgets('every heading is in Title Case', (tester) async {
      await open(tester, size: const Size(393, 852));
      // Short joining words stay lowercase; everything else is capitalised.
      const joins = {'and', 'a', 'on', 'the', 'of', 'in', 'to'};
      for (final heading in _headingsIn(
        File('lib/screens/reading_music_screen.dart'),
      )) {
        final words = heading.split(' ');
        for (final (i, word) in words.indexed) {
          if (i > 0 && joins.contains(word)) continue;
          expect(
            word[0],
            word[0].toUpperCase(),
            reason: '"$heading": "$word" is not capitalised',
          );
        }
      }
    });
  });
}

/// Every symbol the guide names, so the font check can find them all.
const _named = {
  'noteWhole': Smufl.noteWhole,
  'noteHalfUp': Smufl.noteHalfUp,
  'noteQuarterUp': Smufl.noteQuarterUp,
  'note8thUp': Smufl.note8thUp,
  'note16thUp': Smufl.note16thUp,
  'note32ndUp': Smufl.note32ndUp,
  'noteheadWhole': Smufl.noteheadWhole,
  'noteheadBlack': Smufl.noteheadBlack,
  'augmentationDot': Smufl.augmentationDot,
  'restWhole': Smufl.restWhole,
  'restHalf': Smufl.restHalf,
  'restQuarter': Smufl.restQuarter,
  'rest8th': Smufl.rest8th,
  'rest16th': Smufl.rest16th,
  'rest32nd': Smufl.rest32nd,
  'flat': Smufl.flat,
  'natural': Smufl.natural,
  'sharp': Smufl.sharp,
  'doubleSharp': Smufl.doubleSharp,
  'doubleFlat': Smufl.doubleFlat,
  'timeSigCommon': Smufl.timeSigCommon,
  'timeSigCutCommon': Smufl.timeSigCutCommon,
  'barlineSingle': Smufl.barlineSingle,
  'barlineDouble': Smufl.barlineDouble,
  'barlineFinal': Smufl.barlineFinal,
  'barlineReverseFinal': Smufl.barlineReverseFinal,
  'repeatDots': Smufl.repeatDots,
  'repeatRightLeft': Smufl.repeatRightLeft,
  'repeatStart': Smufl.repeatStart,
  'repeatEnd': Smufl.repeatEnd,
  'segno': Smufl.segno,
  'coda': Smufl.coda,
  'staccato': Smufl.staccato,
  'accent': Smufl.accent,
  'tenuto': Smufl.tenuto,
  'fermata': Smufl.fermata,
  'trill': Smufl.trill,
  'piano': Smufl.piano,
  'mezzo': Smufl.mezzo,
  'forte': Smufl.forte,
  'ottavaAlta': Smufl.ottavaAlta,
};

/// A heading on the page itself, as opposed to the same words in the
/// contents at the top or in the sheet.
Finder _heading(String title) =>
    find.descendant(of: find.byType(SectionHeader), matching: find.text(title));

/// The headings written into the guide, straight out of its source, so a
/// new section can't skip the check by never being scrolled to.
List<String> _headingsIn(File source) {
  final text = source.readAsStringSync();
  return [
    for (final match in RegExp(r"SectionHeader\('([^']*)'\)").allMatches(text))
      match.group(1)!.replaceAll('\\u2019', '’'),
  ];
}

/// The Unicode code points an OpenType font covers, read out of its `cmap`
/// table. Only the two subtable formats a modern font uses are handled,
/// enough to answer "is this symbol in here".
Set<int> _codePointsIn(File font) {
  final bytes = ByteData.sublistView(font.readAsBytesSync());
  final tables = bytes.getUint16(4);
  var cmap = -1;
  for (var i = 0; i < tables; i++) {
    final record = 12 + i * 16;
    final tag = String.fromCharCodes([
      for (var b = 0; b < 4; b++) bytes.getUint8(record + b),
    ]);
    if (tag == 'cmap') cmap = bytes.getUint32(record + 8);
  }
  if (cmap < 0) throw StateError('No cmap table in ${font.path}');

  final covered = <int>{};
  final subtables = bytes.getUint16(cmap + 2);
  for (var i = 0; i < subtables; i++) {
    final at = cmap + bytes.getUint32(cmap + 4 + i * 8 + 4);
    switch (bytes.getUint16(at)) {
      case 4:
        final segments = bytes.getUint16(at + 6) ~/ 2;
        final ends = at + 14;
        final starts = ends + segments * 2 + 2;
        for (var s = 0; s < segments; s++) {
          final start = bytes.getUint16(starts + s * 2);
          final end = bytes.getUint16(ends + s * 2);
          if (start == 0xFFFF) continue;
          for (var code = start; code <= end; code++) {
            covered.add(code);
          }
        }
      case 12:
        final groups = bytes.getUint32(at + 12);
        for (var g = 0; g < groups; g++) {
          final group = at + 16 + g * 12;
          final start = bytes.getUint32(group);
          final end = bytes.getUint32(group + 4);
          for (var code = start; code <= end; code++) {
            covered.add(code);
          }
        }
    }
  }
  return covered;
}
