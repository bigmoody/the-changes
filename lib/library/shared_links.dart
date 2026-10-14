// A chart handed to the app from somewhere else.
//
// Import reads the clipboard, which assumes you can get a link onto the
// clipboard, and on a phone you often cannot: an iReal Pro link is not a
// web address, so a long press on the forum offers to open it rather
// than to copy it, and there the trail ends. The feature was reachable
// only from a desktop browser.
//
// So the app takes one from outside instead. Share a link to The Changes
// and it arrives here; tap one and, where the system lets us have it, it
// arrives here too.
//
// Nothing is fetched. What arrives is text somebody chose to send, read
// on the phone, exactly as a paste is: the import has always been the
// player handing over something they already had, and this is the same
// thing without the copying.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The channel the native side hands links over on.
const sharedLinksChannel = MethodChannel('the_changes/shared');

/// Links arriving from outside the app.
class SharedLinks {
  SharedLinks({this.channel = sharedLinksChannel}) {
    channel.setMethodCallHandler(_fromOutside);
  }

  /// Taken rather than reached for, so a test can hand one over.
  final MethodChannel channel;

  /// What to do with one. Null until the app is up enough to show it.
  ValueChanged<String>? onText;

  Future<dynamic> _fromOutside(MethodCall call) async {
    if (call.method == 'shared') {
      final text = call.arguments as String?;
      if (text != null && text.trim().isNotEmpty) onText?.call(text);
    }
    return null;
  }

  /// Whatever the app was opened with, where it was opened with one.
  ///
  /// A share that starts the app arrives before any of this is listening,
  /// so the native side holds it and hands it over when asked. Asked once
  /// and then forgotten, or every trip through the library would open the
  /// same import again.
  Future<String?> whatStartedUs() async {
    try {
      final text = await channel.invokeMethod<String>('initial');
      return text != null && text.trim().isNotEmpty ? text : null;
    } on MissingPluginException {
      // A platform that hands nothing over. Import still reads a paste.
      return null;
    } catch (e) {
      debugPrint('Could not read what opened the app: $e');
      return null;
    }
  }

  void dispose() {
    channel.setMethodCallHandler(null);
    onText = null;
  }
}
