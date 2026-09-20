// What's written under each chord on the chart, when a player has asked
// for something to learn by.
//
// One line per chord, worked out for the whole tune at once: the numbers
// need the tune's key, and the guide tones need the chord before, so
// neither can be worked out from a bar on its own.
//
// Whatever goes under there is read at a glance, at a size a good deal
// smaller than the chord above it, while the band is playing. So it is
// kept to a few characters: a numeral, or two note names.

import '../settings/app_settings.dart';
import 'chord_numbers.dart';
import 'guide_tones.dart';
import 'tune.dart';

/// The line to write under each chord, bar by bar. A bar's list is in the
/// same order as its chords, and an entry is null where there's nothing to
/// say. Empty when the player has asked for nothing.
///
/// [tune] must be the chart as it's shown — transposed, if it has been —
/// so the numbers are read against the key the player is looking at.
Map<int, List<String?>> aidsFor(Tune tune, ChordAid aid) {
  if (aid == ChordAid.off) return const {};

  final lines = <int, List<String?>>{};
  if (aid == ChordAid.guideTones) {
    // The lines run through the tune in playing order, so they're worked
    // out in one pass and then dealt back out to the bars.
    final slots = tune.slots;
    final tones = guideTonesThrough([for (final slot in slots) slot.chord]);
    for (final (index, slot) in slots.indexed) {
      lines.putIfAbsent(slot.barIndex, () => []).add(_twoNotes(tones[index]));
    }
    return lines;
  }

  for (final (barIndex, bar) in tune.bars.indexed) {
    lines[barIndex] = [
      for (final slot in bar)
        aid == ChordAid.roman
            ? romanFor(slot.chord, tune.key)
            : nashvilleFor(slot.chord, tune.key),
    ];
  }
  return lines;
}

/// The two guide tones, upper first, as a player would say them: "B F".
///
/// Nothing marks a note that's held. The two lines keep their places, so a
/// note standing still while the chord changes under it shows itself: the
/// same letter, in the same spot, two bars running. A dot or a tie beside
/// it would read as a musical mark it isn't.
String _twoNotes(GuideTones tones) => '${tones.upper} ${tones.lower}';
