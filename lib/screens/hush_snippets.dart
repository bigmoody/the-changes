// Leaving a screen stops whatever it was playing you.
//
// A couple of dozen screens have a "hear it" button, and every one of
// them plays a snippet: a chord, a scale, a shape, a palm key exercise.
// None of them stopped it. Press it, go back, and the sound carried on
// over whatever you opened next, finishing a scale you had already left
// behind, which reads as the app losing track of itself.
//
// Done here rather than in each screen's dispose for two reasons. It is
// one rule in one place rather than the same four lines twenty-odd
// times, and it applies to the screens nobody has written yet, which is
// where the next copy of the bug would have been.
//
// Only a page popping counts. A sheet or a dialog closing over a screen
// leaves the screen there, and the sound with it: shutting the key
// chooser on the phrases page should not stop the phrase.

import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/practice_player.dart';

/// Stops any snippet when a page is left.
class HushSnippets extends NavigatorObserver {
  HushSnippets(this.player);

  final PracticePlayer player;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _hush(route);
  }

  /// A page swapped out from under you is a page left, as much as one
  /// backed out of.
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (oldRoute != null) _hush(oldRoute);
  }

  /// The band is not touched. It is stopped by the screen that started
  /// it, which knows what it was in the middle of: a take being
  /// recorded, a run being scored.
  void _hush(Route<dynamic> route) {
    if (route is! PageRoute) return;
    unawaited(player.stopSnippet());
  }
}
