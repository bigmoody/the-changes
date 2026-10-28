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

  /// How many readings after the pending one have agreed with it.
  var _agreed = 0;

  /// Readings since the sound last got louder.
  var _sinceStrum = 0;

  /// How many readings after a strum the name may still change, as the
  /// strum settles: half a second, a reading every 60 ms.
  static const settling = 8;

  /// How loud it was when the chord was named.
  double _namedLevel = 0;

  /// A reading heard once, waiting to be heard again before it is named:
  /// what is left of the attack never says the same thing twice running.
  ({List<ChordGuess> named, List<int> pitches})? _pending;

  /// Whether a strum has begun since the chord was last named or heard
  /// again: then fewer notes is another chord, not this one dying.
  var _struck = false;

  /// Takes one moment's hearing; true if the chord named changed.
  bool hear(HeardNotes heard) {
    // Getting louder: a strum under way, not yet a chord to name.
    final rising = heard.level > _lastLevel * 1.15;
    _lastLevel = heard.level;
    if (rising) {
      _struck = true;
      _sinceStrum = 0;
    } else {
      _sinceStrum++;
    }
    // Settled, named, and nothing struck since: the chord is what it was.
    // What a dying chord throws up late in its ring, read twice running,
    // renamed an A♭6 A♭69 and an Fm7 the same.
    if (!rising && guesses.isNotEmpty && _sinceStrum > settling) return false;
    if (rising || heard.pitches.length < 3) {
      _pending = null;
      _agreed = 0;
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
    // And only once the sound has dropped since the name was given: at the
    // same level it is the same strum, heard better.
    final dying = heard.level < _namedLevel * 0.9;
    if (!_struck &&
        dying &&
        guesses.isNotEmpty &&
        namedFrom.containsAll(played)) {
      _pending = null;
      return false;
    }
    final name = named.first.display;
    if (guesses.isNotEmpty && name == guesses.first.display) {
      pitches = heard.pitches;
      _struck = false;
      return false;
    }
    final pending = _pending;
    final reading = (named: named, pitches: heard.pitches);
    if (pending == null) {
      _pending = reading;
      return false;
    }
    final chosen = pending.named.first.display == name
        ? reading
        : _richer(pending, reading);
    if (chosen == null) {
      _pending = reading;
      _agreed = 0;
      return false;
    }
    // Three readings in a row, a fifth of a second: what is left of the
    // attack lasts long enough to be read twice.
    if (++_agreed < 2) {
      _pending = chosen;
      return false;
    }
    _pending = null;
    _agreed = 0;
    _struck = false;
    _namedLevel = heard.level;
    final changed =
        guesses.isEmpty || chosen.named.first.display != guesses.first.display;
    guesses = chosen.named;
    pitches = chosen.pitches;
    return changed;
  }

  /// Two readings in a row that do not agree, the second only the first
  /// with notes gone: a string died between them, and the chord is the
  /// first, so long as it makes as good a chord as what is left. On a
  /// guitar heard through an iPad a note fretted on the G string dies in a
  /// fifth of a second, and a C7 was named C, a Cm7 Cm, once its seventh
  /// had gone. What the attack throws up makes a worse chord than what is
  /// left (a C13 over an A that was never played, against a plain C), and
  /// loses. Otherwise neither is named yet.
  static ({List<ChordGuess> named, List<int> pitches})? _richer(
    ({List<ChordGuess> named, List<int> pitches}) first,
    ({List<ChordGuess> named, List<int> pitches}) then,
  ) {
    final before = {for (final pitch in first.pitches) pitch % 12};
    final after = {for (final pitch in then.pitches) pitch % 12};
    if (!before.containsAll(after)) return null;
    return first.named.first.score >= then.named.first.score - 0.12
        ? first
        : then;
  }
}
