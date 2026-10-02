// The handful of changes worth running round all twelve keys.
//
// A ii-V, a turnaround, a blues, rhythm changes: the shapes that come up
// often enough that playing them in every key is the work rather than an
// exercise. Anything they do not cover can be written in the progression
// editor and played from there instead.
//
// All in C, because they are moved to each key afterwards and C is where
// the app can spell everything plainly.

import 'tune.dart';
import 'tune_library.dart';
import 'user_progression.dart';

/// One of the ready-made contexts, as a progression.
UserProgression lickContext({
  required String id,
  required String title,
  required List<String> bars,
  int tempo = 140,
}) => UserProgression(
  id: id,
  title: title,
  key: 'C',
  tempo: tempo,
  bars: bars,
  style: BandStyle.of(Feel.swing),
);

/// The contexts offered when a lick is saved, commonest first.
List<UserProgression> get shortChanges => [
  lickContext(
    id: 'ctx-ii-v-i',
    title: 'ii V I',
    bars: const ['Dm7', 'G7', 'CΔ7', 'CΔ7'],
  ),
  lickContext(
    id: 'ctx-ii-v-i-short',
    title: 'ii V I, two bars',
    bars: const ['Dm7 G7', 'CΔ7'],
  ),
  lickContext(id: 'ctx-ii-v', title: 'ii V', bars: const ['Dm7', 'G7']),
  lickContext(
    id: 'ctx-minor-ii-v-i',
    title: 'Minor ii V i',
    bars: const ['Dm7♭5', 'G7alt', 'Cm7', 'Cm7'],
  ),
  lickContext(
    id: 'ctx-turnaround',
    title: 'Turnaround',
    bars: const ['CΔ7', 'A7', 'Dm7', 'G7'],
  ),
  lickContext(
    id: 'ctx-dominant',
    title: 'One dominant',
    bars: const ['G7', 'G7'],
  ),
  lickContext(
    id: 'ctx-minor',
    title: 'One minor chord',
    bars: const ['Dm7', 'Dm7'],
  ),
  lickContext(
    id: 'ctx-blues',
    title: 'Blues, first four',
    bars: const ['C7', 'F7', 'C7', 'C7'],
  ),
];

/// The changes offered for running round the twelve keys.
///
/// Everything a lick can be saved over, and then the two whole forms:
/// the blues and rhythm changes. Those are not in [shortChanges] because
/// they are the wrong size for catching a lick. A chorus of rhythm
/// changes is thirty-two bars, which is the best part of a minute to
/// wait for the two bars you wanted to keep.
///
/// Taken from the app's own charts rather than written out again here,
/// so there is one blues in the app and not two of them drifting apart.
/// They arrive in the key they are written in, so the round starts in F
/// for the blues and B flat for rhythm changes, which is where anybody
/// would start them.
List<UserProgression> get changesToRun => [
  ...shortChanges,
  _wholeForm('Jazz blues in F', id: 'ctx-blues-12', called: 'Blues'),
  _wholeForm(
    'Rhythm changes in B♭',
    id: 'ctx-rhythm',
    called: 'Rhythm changes',
  ),
];

/// One of the app's own charts, as a progression to run round the keys.
UserProgression _wholeForm(
  String title, {
  required String id,
  required String called,
}) => UserProgression.fromTune(
  practiceProgressions.firstWhere((tune) => tune.title == title),
  id: id,
)..title = called;
