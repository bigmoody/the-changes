// When to name a chord, as well as what it is.
//
// The chord ear says what it hears in each moment; this says which of
// those moments to believe, the way a player's ear does: the chord is
// what was strummed, not what is left of it.
//
// Two things in a strum are not the chord. The attack, while the sound is
// still getting louder: the pick across the strings throws up notes that
// are not there a moment later. And the tail: strings die at different
// rates, and on the player's own C9 (x32330, off a screen recording) the
// B flat on the G string was gone within half a second, leaving C, D and
// E, which were named C69 for as long as they rang.

import '../music/chord_match.dart';
import 'chord_ear.dart';

class ChordReader {
  /// What is named, the likeliest first; empty until a chord is heard.
  List<ChordGuess> guesses = const [];

  /// The notes the chord was named from.
  List<int> pitches = const [];

  double _lastLevel = 0;

  /// A reading heard once, waiting to be heard again before it is named:
  /// what is left of the attack never says the same thing twice running.
  String? _pending;

  /// Whether a strum has begun since the chord was last named or heard
  /// again: then fewer notes is another chord, not this one dying.
  var _struck = false;

  /// Takes one moment's hearing; true if the chord named changed.
  bool hear(HeardNotes heard) {
    // Getting louder: a strum under way, not yet a chord to name.
    final rising = heard.level > _lastLevel * 1.15;
    _lastLevel = heard.level;
    if (rising) _struck = true;
    if (rising || heard.pitches.length < 3) {
      _pending = null;
      return false;
    }
    final named = namesFor(
      heard.chroma,
      bass: heard.bass == null ? null : heard.bass! % 12,
    );
    if (named.isEmpty) return false;
    // Fewer of the notes the chord was named from: it dying away, not
    // another chord.
    final played = {for (final pitch in heard.pitches) pitch % 12};
    final namedFrom = {for (final pitch in pitches) pitch % 12};
    if (!_struck && guesses.isNotEmpty && namedFrom.containsAll(played)) {
      _pending = null;
      return false;
    }
    final name = named.first.display;
    if (guesses.isNotEmpty && name == guesses.first.display) {
      pitches = heard.pitches;
      _struck = false;
      return false;
    }
    if (_pending != name) {
      _pending = name;
      return false;
    }
    _pending = null;
    _struck = false;
    guesses = named;
    pitches = heard.pitches;
    return true;
  }
}
