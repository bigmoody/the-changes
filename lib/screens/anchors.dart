// Jumping a scrolling page to a named place in it.
//
// A long page is built as it's scrolled, so the thing being jumped to
// usually doesn't exist yet and there's nothing to measure. So it's done in
// two moves: a jump to roughly where it should be, which builds what's
// around it, and then an exact one now that it's really there. Two or three
// goes is normally enough; the guess gets better each time, because a
// list's estimated length does.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// Named places in a scrolling page, and how to get to them.
class Anchors {
  Anchors(this.scroll);

  final ScrollController scroll;

  /// The widget at each anchor, so it can be scrolled to exactly once it
  /// has been built.
  final _keys = <String, GlobalKey>{};

  /// Roughly how far down the page each anchor falls, 0 to 1.
  var _guesses = <String, double>{};

  /// Stops two jumps running at once, when a finger is sweeping an index
  /// or a second one is asked for before the first has landed.
  var _turn = 0;

  /// The key to hang on whatever is at [name].
  GlobalKey keyFor(String name) =>
      _keys.putIfAbsent(name, () => GlobalKey(debugLabel: 'anchor-$name'));

  /// Says roughly how far down the page each anchor is, so a guess can be
  /// made before anything has been built.
  void expect(Map<String, double> guesses) => _guesses = {...guesses};

  /// Puts [name] at the top of the page.
  Future<void> goTo(String name) async {
    final turn = ++_turn;
    for (var tries = 0; tries < 5; tries++) {
      if (!scroll.hasClients || turn != _turn) return;
      final position = scroll.position;
      final target = _exactly(name);
      if (target != null) {
        scroll.jumpTo(target.clamp(0, position.maxScrollExtent));
        return;
      }
      // Not built yet: land near it, which builds it, and look again.
      final guess = _guesses[name] ?? 0;
      final to = (guess * position.maxScrollExtent).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if ((to - position.pixels).abs() < 1) return;
      scroll.jumpTo(to);
      await SchedulerBinding.instance.endOfFrame;
    }
  }

  /// Where [name] is, if it has been built.
  double? _exactly(String name) {
    final context = _keys[name]?.currentContext;
    if (context == null) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return RenderAbstractViewport.of(box).getOffsetToReveal(box, 0).offset;
  }
}
