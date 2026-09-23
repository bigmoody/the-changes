// The changes a lick is usually played over.
//
// Somebody saving a lick has to say what it is a lick over, and asking
// them to write out a ii-V every time would mean nobody saved anything.
// So these are here to be picked in one tap, and anything they do not
// cover can be written in the progression editor and picked from there
// instead.
//
// All in C, because the lick is taken round the keys afterwards and C is
// where the app can spell everything plainly. The key a lick was caught
// in is not worth preserving: what matters is the shape.

import 'tune.dart';
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
List<UserProgression> get lickContexts => [
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
