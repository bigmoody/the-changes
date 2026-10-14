// Leaving a screen stops whatever it was playing you.
//
// Two dozen screens have a "hear it" button and none of them stopped the
// sound on the way out, so a scale you had already left behind went on
// playing over whatever you opened next. The rule is one line in one
// place, and these say where it applies and where it must not.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/screens/hush_snippets.dart';

import 'support/fake_player.dart';

class _FakePlayer extends FakePlayer {
  var hushed = 0;

  @override
  Future<void> stopSnippet() async => hushed++;

  @override
  Future<void> stop() async {}

  @override
  void setVolume(Instrument instrument, double volume) {}
}

void main() {
  late _FakePlayer player;

  /// A first screen with a button that opens a second one.
  Widget app({required WidgetBuilder second, bool asDialog = false}) =>
      MaterialApp(
        navigatorObservers: [HushSnippets(player)],
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const ValueKey('go'),
              onPressed: () {
                if (asDialog) {
                  showDialog<void>(context: context, builder: second);
                } else {
                  Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: second));
                }
              },
              child: const Text('Go'),
            ),
          ),
        ),
      );

  setUp(() => player = _FakePlayer());

  testWidgets('backing out of a screen stops the sound', (tester) async {
    await tester.pumpWidget(
      app(second: (_) => const Scaffold(body: Text('A drill'))),
    );
    await tester.tap(find.byKey(const ValueKey('go')));
    await tester.pumpAndSettle();
    expect(player.hushed, 0, reason: 'nothing left yet');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(player.hushed, 1);
  });

  testWidgets('a dialog closing leaves the sound alone', (tester) async {
    // The screen is still there and so is what it was playing: shutting
    // the key chooser on the phrases page should not stop the phrase.
    await tester.pumpWidget(
      app(
        asDialog: true,
        second: (_) => const AlertDialog(content: Text('Which key?')),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('go')));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Which key?'), findsNothing, reason: 'it did close');
    expect(player.hushed, 0);
  });

  testWidgets('a page swapped out from under you counts as leaving', (
    tester,
  ) async {
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        navigatorObservers: [HushSnippets(player)],
        home: const Scaffold(body: Text('First')),
      ),
    );
    key.currentState!.pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('2'))),
    );
    await tester.pumpAndSettle();
    expect(player.hushed, 1);
  });
}
