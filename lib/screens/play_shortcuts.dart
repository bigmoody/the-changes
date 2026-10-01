// The spacebar starts and stops the band.
//
// Wherever there is a hardware keyboard: an iPad with one clipped to it
// today, and a desktop build if there is ever one. On a phone it costs
// nothing and does nothing.
//
// Space because that is what every other thing that plays audio uses, and
// because the one tap you make most while practising should not need you
// to find a button. On the stage screen, where the phone is on a stand a
// metre away, a keyboard is the only thing within reach anyway.
//
// It deliberately does nothing while you are typing. A space in the search
// box, or in a chord being edited, is a space: Flutter gives the text
// field the key first, but a field that has focus without swallowing the
// key (an empty one, say) would otherwise start the band from under
// somebody mid-word, so the check is explicit rather than left to luck.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps [child] so the spacebar runs [onPlayPause].
///
/// Autofocus, so it works the moment the screen opens rather than after
/// something has been tapped.
class PlayPauseShortcut extends StatelessWidget {
  const PlayPauseShortcut({
    super.key,
    required this.onPlayPause,
    required this.child,
  });

  final VoidCallback onPlayPause;
  final Widget child;

  /// Whether something is being typed into, in which case the spacebar
  /// belongs to whoever is typing.
  static bool _typing() {
    final focus = FocusManager.instance.primaryFocus;
    final context = focus?.context;
    if (context == null) return false;
    return context.widget is EditableText ||
        context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.space): () {
        if (_typing()) return;
        onPlayPause();
      },
    },
    child: Focus(autofocus: true, child: child),
  );
}
