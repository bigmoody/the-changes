// A chart handed to the app from somewhere else.
//
// Import reads the clipboard, which assumes you can get a link onto the
// clipboard, and on a phone you often cannot: an iReal Pro link is not a
// web address, so a long press offers to open it rather than to copy it.
// These cover the way in that does not need copying.
//
// The one worth guarding is the handover happening once. A share that
// starts the app is held by the native side until Dart asks, and sent
// live once Dart is listening; doing both would import it twice.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/library/shared_links.dart';
import 'package:play_along/screens/import_screen.dart';
import 'package:play_along/settings/progression_store.dart';

/// One song, as iReal Pro writes it.
const aChart =
    'irealb://Blue%20Bossa%3DKenny%20Dorham%3D%3DMedium%20Bossa%3D'
    'C-%3D%3D1r34LbKcu7%20CM7ZL%7CQyXZL%7CQyX%3D%3D0%3D0%3D%3D';

class _Phone {
  _Phone(this.channel);

  final MethodChannel channel;

  /// What the app was opened with, which the native side holds until
  /// Dart asks for it.
  String? startedWith;
  var askedForInitial = false;

  void listen() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'initial') {
            askedForInitial = true;
            final was = startedWith;
            startedWith = null;
            return was;
          }
          return null;
        });
  }

  void goSilent() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  }

  /// A share arriving at an app that is already running.
  Future<void> share(String text) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(MethodCall('shared', text)),
          (_) {},
        );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('the_changes/test_shared');
  late _Phone phone;
  late SharedLinks links;

  setUp(() {
    phone = _Phone(channel)..listen();
    links = SharedLinks(channel: channel);
  });

  tearDown(() {
    links.dispose();
    phone.goSilent();
  });

  group('a chart arriving from another app', () {
    test('it reaches whatever is waiting for one', () async {
      final arrived = <String>[];
      links.onText = arrived.add;
      await phone.share(aChart);
      expect(arrived, [aChart]);
    });

    test('nothing at all is not something to open', () async {
      // An empty share, or one with only whitespace in it, is somebody
      // having shared the wrong thing, not a chart.
      final arrived = <String>[];
      links.onText = arrived.add;
      await phone.share('');
      await phone.share('   \n ');
      expect(arrived, isEmpty);
    });

    test('what opened the app is asked for, and only given once', () async {
      // The native side holds a share that starts the app, since it
      // lands before any of this is listening. Asked twice, a second
      // import would open over the first.
      phone.startedWith = aChart;
      expect(await links.whatStartedUs(), aChart);
      expect(phone.askedForInitial, isTrue);
      expect(await links.whatStartedUs(), isNull);
    });

    test('an app opened by hand was opened with nothing', () async {
      expect(await links.whatStartedUs(), isNull);
    });

    test('a platform that hands nothing over is not an error', () async {
      phone.goSilent();
      expect(await links.whatStartedUs(), isNull);
    });

    test('nothing arrives after it is disposed of', () async {
      final arrived = <String>[];
      links.onText = arrived.add;
      links.dispose();
      await phone.share(aChart);
      expect(arrived, isEmpty);
    });
  });

  group('the import screen', () {
    testWidgets('a handed chart is read without pasting anything', (
      tester,
    ) async {
      // The whole point: the songs are there to choose from on the way
      // in, rather than behind a Paste button that had nothing to paste.
      final store = ProgressionStore.inMemory();
      await tester.pumpWidget(
        MaterialApp(
          home: ImportScreen(store: store, handed: aChart),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Blue Bossa'), findsOneWidget);
    });

    testWidgets('and one opened by hand still asks for a paste', (
      tester,
    ) async {
      final store = ProgressionStore.inMemory();
      await tester.pumpWidget(MaterialApp(home: ImportScreen(store: store)));
      await tester.pumpAndSettle();
      expect(find.text('Blue Bossa'), findsNothing);
    });
  });
}
