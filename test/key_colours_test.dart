// The colour of the key a tune is in.
//
// A separate map from the chord colours, and the tests say so in the one
// place it matters: setting a key colour must not move a chord colour, and
// the other way round. People who have both of these rarely have them
// agree, and an app that quietly used one for the other would be inventing
// half of somebody's perception.
//
// The rest is the bargain the switch makes. Turning the minors on must not
// blank anything, and turning them off must not lose anything.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/screens/key_colours_screen.dart';
import 'package:play_along/screens/note_ink.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/settings/key_colours.dart';

const cMajor = (pitchClass: 0, minor: false);
const cMinor = (pitchClass: 0, minor: true);
const gMinor = (pitchClass: 7, minor: true);

double hueOf(Color colour) => HSLColor.fromColor(colour).hue;

Widget under(AppSettings settings, Widget child) => MaterialApp(
  home: NoteInk(
    settings: settings,
    child: Scaffold(body: Center(child: child)),
  ),
);

Color? colourOf(WidgetTester tester, Finder of) {
  final text = tester.widget<Text>(
    find.descendant(of: of, matching: find.byType(Text)),
  );
  return text.style?.color;
}

void main() {
  group('reading what key a label is in', () {
    test('a plain key, a minor one and a mode', () {
      expect(readKeyLabel('B♭'), (pitchClass: 10, minor: false));
      expect(readKeyLabel('G minor'), (pitchClass: 7, minor: true));
      // A mode counts as minor because that is what it sounds like.
      expect(readKeyLabel('D Dorian'), (pitchClass: 2, minor: true));
    });

    test('a tune that moves key is in the first one named', () {
      expect(readKeyLabel('C minor, F minor'), (pitchClass: 0, minor: true));
      expect(readKeyLabel('C, B♭, A♭'), (pitchClass: 0, minor: false));
    });
  });

  group('keeping the key colours', () {
    test('a minor key follows the major until it is answered', () {
      final colours = const KeyColours().set(0, const Color(0xFF3366CC));
      expect(colours.of(cMajor), const Color(0xFF3366CC));
      expect(colours.of(cMinor), const Color(0xFF3366CC));
    });

    test('and wins over it once it has one', () {
      final colours = const KeyColours()
          .set(0, const Color(0xFF3366CC))
          .set(0, const Color(0xFFCC6633), minor: true);
      expect(colours.of(cMajor), const Color(0xFF3366CC));
      expect(colours.of(cMinor), const Color(0xFFCC6633));
    });

    test('with the split off the minors are ignored, not lost', () {
      final colours = const KeyColours()
          .set(0, const Color(0xFF3366CC))
          .set(0, const Color(0xFFCC6633), minor: true);
      expect(colours.of(cMinor, split: false), const Color(0xFF3366CC));
      expect(colours.byMinorKey[0], const Color(0xFFCC6633));
    });

    test('a minor with no major under it is simply its own colour', () {
      final colours = const KeyColours().set(
        7,
        const Color(0xFF11AA22),
        minor: true,
      );
      expect(colours.of(gMinor), const Color(0xFF11AA22));
      // And the major on the same note stays plain: the fallback only
      // runs one way, from the minor to the major.
      expect(colours.of((pitchClass: 7, minor: false)), isNull);
    });

    test('they survive being written down and read back', () {
      final colours = const KeyColours()
          .set(10, const Color(0xFFAA1122))
          .set(7, const Color(0xFF11AA22), minor: true);
      final read = KeyColours.fromJson(colours.toJson());
      expect(read.of((pitchClass: 10, minor: false)), const Color(0xFFAA1122));
      expect(read.of(gMinor), const Color(0xFF11AA22));
      expect(read.byKey, hasLength(1));
      expect(read.byMinorKey, hasLength(1));
    });

    test('rubbish in the saved map is skipped rather than thrown', () {
      final read = KeyColours.fromJson({
        '0': 0xFFAA1122,
        '99': 0xFF000000,
        'wat': 0xFF000000,
        '3m': 0xFF11AA22,
      });
      expect(read.byKey, hasLength(1));
      expect(read.byMinorKey, hasLength(1));
      expect(read.of((pitchClass: 3, minor: true)), const Color(0xFF11AA22));
    });
  });

  group('separate from the chord colours', () {
    test('setting one leaves the other alone', () async {
      final settings = AppSettings.inMemory();
      await settings.setChordColour(0, const Color(0xFF3366CC));
      await settings.setKeyColour(0, const Color(0xFFCC6633));
      // Somebody's C major and their C are different things to see, and
      // the app must not answer one question with the other.
      expect(settings.chordColourFor(0), const Color(0xFF3366CC));
      expect(settings.keyColourFor(cMajor), const Color(0xFFCC6633));
    });

    test('clearing one leaves the other alone', () async {
      final settings = AppSettings.inMemory();
      await settings.setChordColour(0, const Color(0xFF3366CC));
      await settings.setKeyColour(0, const Color(0xFFCC6633));
      await settings.clearKeyColours();
      expect(settings.chordColourFor(0), const Color(0xFF3366CC));
      expect(settings.keyColourFor(cMajor), isNull);
    });

    test('turning one off leaves the other on', () async {
      final settings = AppSettings.inMemory();
      await settings.setChordColour(0, const Color(0xFF3366CC));
      await settings.setKeyColour(0, const Color(0xFFCC6633));
      await settings.setColourKeys(false);
      expect(settings.chordColourFor(0), const Color(0xFF3366CC));
      expect(settings.keyColourFor(cMajor), isNull);
    });
  });

  group('a key written anywhere', () {
    testWidgets('is left alone when nobody has said anything', (tester) async {
      await tester.pumpWidget(
        under(AppSettings.inMemory(), const KeyText('Key of G minor')),
      );
      expect(colourOf(tester, find.byType(KeyText)), isNull);
    });

    testWidgets('takes the colour of its key once they have', (tester) async {
      final settings = AppSettings.inMemory();
      await settings.setKeyColour(7, const Color(0xFF11AA22));
      await tester.pumpWidget(
        under(settings, const KeyText('Key of G minor', name: 'G minor')),
      );
      final drawn = colourOf(tester, find.byType(KeyText))!;
      expect(hueOf(drawn), closeTo(hueOf(const Color(0xFF11AA22)), 1));
    });

    testWidgets('only the key in a line of details is coloured', (
      tester,
    ) async {
      final settings = AppSettings.inMemory();
      await settings.setKeyColour(7, const Color(0xFF11AA22));
      await tester.pumpWidget(
        under(
          settings,
          const DetailLine(['Thelonious Monk', 'Key of G', '200 bpm']),
        ),
      );
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byType(DetailLine),
          matching: find.byType(Text),
        ),
      );
      final coloured = <String, Color?>{};
      text.textSpan!.visitChildren((visited) {
        if (visited is TextSpan && (visited.text ?? '').trim().isNotEmpty) {
          coloured[visited.text!] = visited.style?.color;
        }
        return true;
      });
      expect(coloured['Key of G'], isNotNull);
      expect(coloured['Thelonious Monk'], isNull);
      expect(coloured['200 bpm'], isNull);
    });
  });

  group('saying which key is which', () {
    Future<void> open(WidgetTester tester, AppSettings settings) async {
      tester.view.physicalSize = const Size(1200, 5000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: KeyColoursScreen(settings: settings)),
      );
      await tester.pumpAndSettle();
    }

    Finder rows(String prefix) => find.byWidgetPredicate(
      (widget) =>
          widget is ListTile &&
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(prefix),
    );

    testWidgets('twelve keys until somebody asks for more', (tester) async {
      await open(tester, AppSettings.inMemory());
      expect(rows('key-'), findsNWidgets(12));
      expect(rows('minor-key-'), findsNothing);
    });

    testWidgets('and twenty-four once they do', (tester) async {
      final settings = AppSettings.inMemory();
      await open(tester, settings);
      await tester.tap(find.byKey(const ValueKey('split-minor-keys')));
      await tester.pumpAndSettle();
      expect(rows('key-'), findsNWidgets(12));
      expect(rows('minor-key-'), findsNWidgets(12));
    });

    testWidgets('a minor follows the major until it is answered', (
      tester,
    ) async {
      final settings = AppSettings.inMemory();
      await settings.setKeyColour(0, const Color(0xFF3366CC));
      await settings.setSplitMinorKeys(true);
      await open(tester, settings);

      final borrowed = tester.widget<ListTile>(
        find.byKey(const ValueKey('minor-key-0')),
      );
      expect((borrowed.subtitle! as Text).data, 'Follows the major');

      await settings.setKeyColour(0, const Color(0xFFCC6633), minor: true);
      await tester.pumpAndSettle();
      final own = tester.widget<ListTile>(
        find.byKey(const ValueKey('minor-key-0')),
      );
      expect((own.subtitle! as Text).data, 'Yours');
    });

    testWidgets('turning the split off keeps the answers', (tester) async {
      final settings = AppSettings.inMemory();
      await settings.setKeyColour(0, const Color(0xFFCC6633), minor: true);
      await settings.setSplitMinorKeys(true);
      await open(tester, settings);
      await tester.tap(find.byKey(const ValueKey('split-minor-keys')));
      await tester.pumpAndSettle();
      expect(rows('minor-key-'), findsNothing);
      expect(settings.keyColours.byMinorKey[0], const Color(0xFFCC6633));
    });
  });
}
