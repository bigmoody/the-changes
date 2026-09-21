// Turning a saved reference back into something playable.
//
// Favourites, recently played and setlists hold references rather than
// tunes, because what they point at may be a standard that comes with the
// app or a progression the player has written and may since have changed or
// deleted. Looking one up can come back empty, and every screen that shows
// a saved list has to cope with that.

import '../music/tune.dart';
import '../music/tune_library.dart';
import '../music/user_progression.dart';
import '../settings/progression_store.dart';
import 'library_store.dart';

/// A reference resolved: the tune to play, and the progression it came from
/// if it was one of the player's own (which is what the practice screen
/// needs to let them edit it).
class FoundTune {
  const FoundTune(this.tune, {this.progression});

  final Tune tune;
  final UserProgression? progression;

  bool get isMine => progression != null;
}

/// What [ref] points at, or null if it isn't there any more: a progression
/// that's been deleted, or a standard from a backup made by a later version
/// of the app.
FoundTune? findTune(TuneRef ref, {ProgressionStore? progressions}) {
  if (ref.isMine) {
    final progression = progressions?.byId(ref.name);
    if (progression == null) return null;
    return FoundTune(progression.toTune(), progression: progression);
  }
  final tune = [
    ...standards,
    ...practiceProgressions,
  ].where((tune) => tune.title == ref.name).firstOrNull;
  return tune == null ? null : FoundTune(tune);
}

/// Every reference in [refs] that still points at something, in order.
List<FoundTune> findTunes(
  Iterable<TuneRef> refs, {
  ProgressionStore? progressions,
}) => [for (final ref in refs) ?findTune(ref, progressions: progressions)];
