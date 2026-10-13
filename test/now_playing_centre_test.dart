// The Control Centre card and the buttons on it.
//
// The rule worth guarding is the one about whose buttons they are. With
// "Keep Other Apps Playing" on, the card belongs to whatever you are
// playing along to, and taking it would mean the pause button on the
// lock screen stopped pausing them: somebody else's control taken away
// without being asked. So the card appears only when this app has the
// sound to itself.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/now_playing_centre.dart';

/// Stands in for the phone, remembering what it was told and able to
/// press the buttons back.
class FakePhone {
  FakePhone(this.channel) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          asked.add(call.method);
          if (call.method == 'show') {
            shown = Map<String, Object?>.from(call.arguments as Map);
          }
          if (call.method == 'hide') shown = null;
          return null;
        });
  }

  final MethodChannel channel;
  final asked = <String>[];
  Map<String, Object?>? shown;

  /// Nothing at all answers, as on a platform with no card built.
  void goSilent() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  }

  /// A button pressed on the lock screen.
  Future<void> press(String button) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(MethodCall(button)),
          (_) {},
        );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('the_changes/test_now_playing');
  late FakePhone phone;
  late NowPlayingCentre card;

  setUp(() {
    phone = FakePhone(channel);
    card = NowPlayingCentre(channel: channel);
  });

  tearDown(() {
    card.dispose();
    phone.goSilent();
  });

  group('putting the card up', () {
    test('it carries the tune, the key and the tempo', () async {
      await card.show(title: 'Blues for Alice', line: 'F · 180', playing: true);
      expect(phone.shown, {
        'title': 'Blues for Alice',
        'line': 'F · 180',
        'playing': true,
      });
      expect(card.showing, isTrue);
    });

    test('a paused band says so, rather than disappearing', () async {
      // Paused is still the card's to hold: it is the one thing on the
      // lock screen that can start the band again.
      await card.show(title: 'Oleo', line: 'B♭ · 220', playing: false);
      expect(phone.shown!['playing'], isFalse);
      expect(card.showing, isTrue);
    });

    test('taking it down leaves nothing up', () async {
      await card.show(title: 'Oleo', line: 'B♭ · 220', playing: true);
      await card.hide();
      expect(phone.shown, isNull);
      expect(card.showing, isFalse);
    });

    test('taking down a card that is not up asks the phone for nothing', () {
      expect(card.showing, isFalse);
      card.hide();
      expect(phone.asked, isEmpty);
    });
  });

  group('the buttons coming back', () {
    test('each one reaches what it is wired to', () async {
      final pressed = <String>[];
      card.onPlay = () {
        pressed.add('play');
      };
      card.onPause = () {
        pressed.add('pause');
      };
      card.onToggle = () {
        pressed.add('toggle');
      };
      card.onStop = () {
        pressed.add('stop');
      };
      for (final button in ['play', 'pause', 'toggle', 'stop']) {
        await phone.press(button);
      }
      expect(pressed, ['play', 'pause', 'toggle', 'stop']);
    });

    test('a button nothing is wired to is let go of quietly', () async {
      // The system may send one this version has never heard of, and a
      // crash in front of somebody is the wrong answer to that.
      await phone.press('skipToNextTrack');
      await phone.press('play');
      expect(card.showing, isFalse);
    });

    test('nothing is pressed after it is disposed of', () async {
      var pressed = 0;
      card.onPlay = () {
        pressed++;
      };
      card.dispose();
      await phone.press('play');
      expect(pressed, 0);
    });
  });

  group('a platform with no card', () {
    test('asking for one is not an error, and the band plays on', () async {
      phone.goSilent();
      await card.show(title: 'Oleo', line: 'B♭ · 220', playing: true);
      await card.hide();
    });
  });
}
