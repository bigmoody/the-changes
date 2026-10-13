// The phone's own transport: the Control Centre card and the lock screen.
//
// With "Keep Other Apps Playing" on, the app is a second source of sound
// alongside whatever you are playing along to, and the Now Playing card
// belongs to that other app. Taking it would mean the pause button on
// the lock screen stopped pausing Spotify, which is somebody else's
// control taken away without being asked.
//
// With it off, the app is the only thing making a sound and there is no
// card at all: the band plays from a pocket with no way to stop it short
// of taking the phone out, unlocking it and finding the screen. So when
// the app has the audio to itself it says so, and takes the buttons.
//
// Only what the app can actually do appears. There is no next or
// previous here, because there is no next: a practice session is one
// tune until you choose another, and a skip button that did nothing
// would be the card lying about the app.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The channel the native side answers on.
const nowPlayingChannel = MethodChannel('the_changes/now_playing');

/// What the system transport can ask for.
///
/// Stop as well as pause, because they are different things here as they
/// are everywhere else in this app: pausing holds the band mid-bar and
/// stopping is being finished with the run.
typedef NowPlayingCommand = void Function();

/// The card, and the buttons on it.
class NowPlayingCentre {
  NowPlayingCentre({this.channel = nowPlayingChannel}) {
    channel.setMethodCallHandler(_fromTheSystem);
  }

  /// Taken rather than reached for, so a test can answer as the phone.
  final MethodChannel channel;

  NowPlayingCommand? onPlay;
  NowPlayingCommand? onPause;

  /// The one big button on the card, and the button on a pair of
  /// headphones, which send a toggle rather than one or the other.
  NowPlayingCommand? onToggle;
  NowPlayingCommand? onStop;

  /// Whether a card is up, so putting one away twice is not two calls
  /// into the platform for nothing.
  var _showing = false;

  bool get showing => _showing;

  Future<dynamic> _fromTheSystem(MethodCall call) async {
    switch (call.method) {
      case 'play':
        onPlay?.call();
      case 'pause':
        onPause?.call();
      case 'toggle':
        onToggle?.call();
      case 'stop':
        onStop?.call();
      // A button the app does not answer is better ignored than crashed
      // on: the system may send one this version has never heard of.
      default:
        debugPrint('The system asked for ${call.method}, which we do not do.');
    }
    return null;
  }

  /// Puts the card up, or changes what it says.
  ///
  /// [line] is the second line, under the title: what a record sleeve
  /// would call the artist and what this app has instead, which is the
  /// key and the tempo you are playing in.
  Future<void> show({
    required String title,
    required String line,
    required bool playing,
  }) async {
    await _ask('show', {'title': title, 'line': line, 'playing': playing});
    _showing = true;
  }

  /// Takes the card away.
  Future<void> hide() async {
    if (!_showing) return;
    _showing = false;
    await _ask('hide', const {});
  }

  /// Nothing here is worth an error in front of somebody.
  ///
  /// A platform with no card at all, which is every platform but iOS so
  /// far, answers with a missing plugin, and the band plays on exactly as
  /// it did before any of this existed.
  Future<void> _ask(String method, Map<String, Object?> arguments) async {
    try {
      await channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // No card on this platform. Nothing is wrong.
    } catch (e) {
      debugPrint('The Now Playing card would not $method: $e');
    }
  }

  void dispose() {
    channel.setMethodCallHandler(null);
    onPlay = null;
    onPause = null;
    onToggle = null;
    onStop = null;
  }
}
