// Finding a page in Learn.
//
// Thirty-one pages, three sections and A to Z get you there when you know
// the name. Search is for when you know the idea and not what this app
// decided to call it, which is why it reads the subtitles too.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/practice/phrase_store.dart';
import 'package:play_along/screens/learn_page.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

Future<void> openLearn(WidgetTester tester) async {
  tester.view
    // Tall enough that the whole list is built: a lazy ListView does
    // not make the headings further down, and these are about what is
    // in the list rather than about scrolling.
    ..physicalSize = const Size(393, 6000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.light),
      home: LearnPage(
        player: PracticePlayer(),
        settings: AppSettings.inMemory(),
        phrases: PhraseStore.inMemory(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> search(WidgetTester tester, String query) async {
  await tester.enterText(find.byKey(const ValueKey('search-learn')), query);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('with nothing typed, everything is there', (tester) async {
    await openLearn(tester);
    expect(find.text('Practise'), findsOneWidget);
    expect(find.text('Concepts'), findsOneWidget);
    expect(find.text('Look It Up'), findsOneWidget);
    expect(find.text('Walking Bass'), findsOneWidget);
  });

  testWidgets('typing a title narrows it to that page', (tester) async {
    await openLearn(tester);
    await search(tester, 'walking');
    expect(find.text('Walking Bass'), findsOneWidget);
    expect(find.text('Metronome'), findsNothing);
    // And the heading it sits under comes with it, so you can still see
    // what kind of page you have found.
    expect(find.text('Practise'), findsOneWidget);
    expect(find.text('Look It Up'), findsNothing);
  });

  testWidgets('it finds a page by what the page is about', (tester) async {
    // The case search exists for. Voicings never says "drop 2" in its
    // name, and somebody looking for drop 2 does not know to look under
    // Voicings.
    await openLearn(tester);
    await search(tester, 'drop 2');
    expect(find.text('Voicings'), findsOneWidget);
  });

  testWidgets('and by an idea spread across two words', (tester) async {
    await openLearn(tester);
    await search(tester, 'twelve keys');
    expect(find.text('Changes in Twelve Keys'), findsOneWidget);
  });

  testWidgets(
    'every word has to match, so two words narrow rather than widen',
    (tester) async {
      await openLearn(tester);
      await search(tester, 'chord');
      final onChord = tester.widgetList(find.byType(Card)).length;
      await search(tester, 'chord quiz');
      expect(tester.widgetList(find.byType(Card)).length, lessThan(onChord));
    },
  );

  testWidgets('case does not matter', (tester) async {
    await openLearn(tester);
    await search(tester, 'SWING');
    expect(find.text('Swing'), findsOneWidget);
  });

  testWidgets('nothing matching says so, rather than showing an empty page', (
    tester,
  ) async {
    await openLearn(tester);
    await search(tester, 'bagpipes');
    expect(find.byKey(const ValueKey('nothing-matches')), findsOneWidget);
    expect(find.textContaining('bagpipes'), findsWidgets);
  });

  testWidgets('clearing it brings everything back', (tester) async {
    await openLearn(tester);
    await search(tester, 'walking');
    expect(find.text('Metronome'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('clear-search')));
    await tester.pumpAndSettle();
    expect(find.text('Metronome'), findsOneWidget);
    expect(find.text('Walking Bass'), findsOneWidget);
  });

  testWidgets('the box stays put while the list scrolls under it', (
    tester,
  ) async {
    // It is for getting somewhere, and thirty-one pages is a long way to
    // scroll back to change what you typed.
    await openLearn(tester);
    final box = tester.getTopLeft(find.byKey(const ValueKey('search-learn')));
    await tester.drag(find.text('Walking Bass'), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const ValueKey('search-learn'))), box);
  });
}
