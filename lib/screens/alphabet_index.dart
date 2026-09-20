// The A–Z strip down the side of a long list, to get from one end of the
// book to the other with a thumb.
//
// Two hundred standards is a lot of scrolling. Running a finger down the
// letters jumps the list as you go, with the letter you're on shown beside
// your thumb, the way a phone's contacts do it.
//
// Where the list actually goes is the caller's business: this only says
// which letter the finger is on. [LetterIndex] does the scrolling, by
// keeping a key on the first tune under each letter.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'anchors.dart';

/// Anything that isn't a letter — "52nd Street Theme", "'Round Midnight" —
/// goes under this, which sorts before A as those titles do.
const otherLetters = '#';

/// The letter [title] is filed under.
String letterOf(String title) {
  final first = title.trim().toUpperCase();
  if (first.isEmpty) return otherLetters;
  final code = first.codeUnitAt(0);
  final isLetter = code >= 0x41 && code <= 0x5A;
  return isLetter ? first[0] : otherLetters;
}

/// The letters a list uses, in the order it uses them.
///
/// [filedAs] is what each row is filed under — its title, or whoever wrote
/// it — in the order the list shows them. The strip is built from that
/// rather than from the alphabet, for two reasons. A letter that goes
/// nowhere is a strip lying about what's in the book. And the odd ones
/// don't always fall in the same place: a title starting with a number or
/// a quote sorts before A, while a tune with nobody credited sorts after Z,
/// and the strip has to agree with the list either way.
List<String> lettersIn(Iterable<String> filedAs) {
  final letters = <String>[];
  for (final one in filedAs) {
    final letter = letterOf(one);
    if (!letters.contains(letter)) letters.add(letter);
  }
  return letters;
}

/// Scrolls a list to the first row under a letter.
class LetterIndex extends Anchors {
  LetterIndex(super.scroll);

  /// Tells the index where each letter falls: [titles] in the order they're
  /// listed, so a guess can be made before anything has been built.
  void follow(List<String> titles) {
    final guesses = <String, double>{};
    for (final (index, title) in titles.indexed) {
      guesses.putIfAbsent(letterOf(title), () => index / titles.length);
    }
    expect(guesses);
  }
}

/// The strip itself: a column of letters to tap or run a finger down.
class AlphabetIndex extends StatefulWidget {
  const AlphabetIndex({
    super.key,
    required this.letters,
    required this.onLetter,
  });

  final List<String> letters;

  /// Called as the finger passes each letter, not only when it lifts, so
  /// the list moves under the thumb.
  final ValueChanged<String> onLetter;

  /// How much room to leave for it at the side of a list, so the strip
  /// never sits on top of what it's indexing.
  static const width = 24.0;

  @override
  State<AlphabetIndex> createState() => _AlphabetIndexState();
}

class _AlphabetIndexState extends State<AlphabetIndex> {
  /// The letter under the finger, or null when nothing is touching it.
  String? _under;

  /// How far down the strip the finger is, so the letter can be shown
  /// beside it rather than somewhere else.
  double _at = 0;

  void _touch(Offset global) {
    final box = context.findRenderObject();
    if (box is! RenderBox || widget.letters.isEmpty) return;
    final local = box.globalToLocal(global);
    final count = widget.letters.length;
    final index = (local.dy / box.size.height * count).floor().clamp(
      0,
      count - 1,
    );
    final letter = widget.letters[index];
    setState(() => _at = local.dy);
    if (letter == _under) return;
    setState(() => _under = letter);
    // A small tick as each letter passes, as a phone's contacts do.
    HapticFeedback.selectionClick();
    widget.onLetter(letter);
  }

  void _lift() => setState(() => _under = null);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (widget.letters.length < 2) return const SizedBox.shrink();
    return Semantics(
      // The letters stay readable one by one; this says what the column of
      // them is for.
      label: 'Jump to a letter',
      explicitChildNodes: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) => _touch(details.globalPosition),
        onTapUp: (_) => _lift(),
        onTapCancel: _lift,
        onVerticalDragStart: (details) => _touch(details.globalPosition),
        onVerticalDragUpdate: (details) => _touch(details.globalPosition),
        onVerticalDragEnd: (_) => _lift(),
        onVerticalDragCancel: _lift,
        child: SizedBox(
          width: AlphabetIndex.width,
          // The letter beside the thumb hangs outside the strip. The letters
          // themselves have to fill it, or where a finger lands wouldn't be
          // where the letter it picked is drawn.
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              Column(
                children: [
                  for (final letter in widget.letters)
                    // An equal share of the strip each, and the letter
                    // shrunk to fit it. Turn the text size right up and
                    // twenty-seven letters at their asking size are taller
                    // than the screen; the strip has to stay the height of
                    // the list whatever they ask for, because where a
                    // finger lands is worked out from that height.
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          letter,
                          textAlign: TextAlign.center,
                          style: handLettered(
                            TextStyle(
                              fontSize: 12,
                              height: 1,
                              color: letter == _under
                                  ? scheme.tertiary
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (_under case final letter?) _Showing(letter: letter, at: _at),
            ],
          ),
        ),
      ),
    );
  }
}

/// The letter under the thumb, written large enough to read around it.
class _Showing extends StatelessWidget {
  const _Showing({required this.letter, required this.at});

  final String letter;
  final double at;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const size = 56.0;
    return Positioned(
      right: AlphabetIndex.width + 4,
      top: at - size / 2,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cardColour(scheme),
            shape: BoxShape.circle,
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Text(
            letter,
            style: handLettered(
              TextStyle(fontSize: 30, color: scheme.tertiary),
            ),
          ),
        ),
      ),
    );
  }
}
