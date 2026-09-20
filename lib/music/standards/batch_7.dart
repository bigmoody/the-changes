// Great American Songbook standards, batch 7. See tune_library.dart for what
// these charts contain (chord changes, form and titles only) and why.

import '../tune.dart';

// Sections repeated within a tune. Most of these are AABA, so the A is
// written once and the last bar or two varied at the call site.
const _bellA = 'FΔ7 | Cm7 F7 | BbΔ7 | Bbm7 Eb7 | Am7 | D7';
const _seeingA = 'F6 | Dm7 | Gm7 | C7';
const _worldA = 'FΔ7 | Abo7 | Gm7 | C7 | Am7 | D7';
const _likeSomeoneA = 'EbΔ7 | Bbm7 Eb7 | AbΔ7 | Gm7 C7 | Fm7 | Bb7';
const _myRomanceA =
    'C6 | Bø7 E7b9 | Am7 | Gm7 C7 | FΔ7 | Fm7 Bb7 | Em7 | Ebo7 '
    '| Dm7 | G7';
const _someoneA = 'Eb6 Cm7 | Fm7 Bb7 | Eb6 Cm7 | Fm7 Bb7 | Eb6 Eb7 | Ab6 Abm6';
const _trampA = 'C6 Am7 | Dm7 G7 | C6 Am7 | Dm7 G7 | C6 C7 | F6 F#o7';
const _nearnessA = 'FΔ7 | Gm7 C7 | FΔ7 | FΔ7 | Fm7 | Bb7 | EbΔ7 | EbΔ7';

final standardsBatch7 = <Tune>[
  Tune.fromChart(
    title: 'I Fall in Love Too Easily',
    composer: 'Jule Styne',
    year: 1944,
    key: 'E♭',
    description: 'Ballad, 16 bars',
    tags: {Genre.ballad},
    defaultTempo: 58,
    chart:
        '| [A] Cø7 | F7b9 | Fm7 | Bb7 | Gm7 | C7b9 | Fm7 | Bb7 '
        '| [B] Cø7 | F7b9 | Fm7 | Bb7 | EbΔ7 | Cø7 F7 | Fm7 Bb7 | EbΔ7 |',
  ),
  Tune.fromChart(
    title: 'If I Were a Bell',
    composer: 'Frank Loesser',
    year: 1950,
    key: 'F',
    defaultTempo: 160,
    chart:
        '| [A] $_bellA | Gm7 | C7 '
        '| [A] $_bellA | Gm7 C7 | F6 '
        '| [B] Gm7 | C7 | FΔ7 | FΔ7 | Am7 | D7 | Gm7 | C7 '
        '| [A] $_bellA | Gm7 C7 | F6 |',
  ),
  Tune.fromChart(
    title: 'I\'ll Be Seeing You',
    composer: 'Sammy Fain',
    year: 1938,
    key: 'F',
    description: 'Ballad',
    tags: {Genre.ballad},
    defaultTempo: 72,
    chart:
        '| [A] $_seeingA | F6 | F#o7 | Gm7 | C7 '
        '| [A] $_seeingA | Am7 | D7 | Gm7 C7 | F6 '
        '| [B] Bb6 | Bbm6 | F6 | D7 | Gm7 | C7 | F6 | C7 '
        '| [A] $_seeingA | Am7 | D7 | Gm7 C7 | F6 |',
  ),
  Tune.fromChart(
    title: 'I\'ve Got the World on a String',
    composer: 'Harold Arlen',
    year: 1932,
    key: 'F',
    defaultTempo: 140,
    chart:
        '| [A] $_worldA | Gm7 | C7 '
        '| [A] $_worldA | Gm7 C7 | F6 '
        '| [B] BbΔ7 | BbΔ7 | Bbm7 | Eb7 | FΔ7 | D7 | Gm7 | C7 '
        '| [A] $_worldA | Gm7 C7 | F6 |',
  ),
  Tune.fromChart(
    title: 'Like Someone in Love',
    composer: 'Jimmy Van Heusen',
    year: 1944,
    key: 'E♭',
    defaultTempo: 130,
    chart:
        '| [A] $_likeSomeoneA | EbΔ7 | Fm7 Bb7 '
        '| [A] $_likeSomeoneA | EbΔ7 | EbΔ7 '
        '| [B] Dø7 | G7b9 | Cm7 | Cm7 | Cø7 | F7b9 | Bbm7 | Eb7 '
        '| [A] $_likeSomeoneA | EbΔ7 | EbΔ7 |',
  ),
  Tune.fromChart(
    title: 'My Romance',
    composer: 'Richard Rodgers',
    year: 1935,
    key: 'C',
    description: 'Ballad',
    tags: {Genre.ballad},
    defaultTempo: 84,
    chart:
        '| [A] $_myRomanceA | C6 | Am7 | Dm7 | G7 | C6 | C6 '
        '| [B] $_myRomanceA | C6 | A7 | Dm7 | G7 | C6 | Dm7 G7 |',
  ),
  Tune.fromChart(
    title: 'Someone to Watch Over Me',
    composer: 'George Gershwin',
    year: 1926,
    key: 'E♭',
    description: 'Ballad',
    tags: {Genre.ballad},
    defaultTempo: 66,
    chart:
        '| [A] $_someoneA | Eb6 Cm7 | Fm7 Bb7 '
        '| [A] $_someoneA | Eb6 | Eb6 '
        '| [B] Ab6 | Ab6 | Eb6 | Eb6 | F7 | F7 | Fm7 | Bb7 '
        '| [A] $_someoneA | Eb6 | Eb6 |',
  ),
  Tune.fromChart(
    title: 'The Lady Is a Tramp',
    composer: 'Richard Rodgers',
    year: 1937,
    key: 'C',
    defaultTempo: 190,
    chart:
        '| [A] $_trampA | C6 A7 | Dm7 G7 '
        '| [A] $_trampA | C6 | C6 '
        '| [B] F6 | F6 | C6 | C6 | D7 | D7 | Dm7 | G7 '
        '| [A] $_trampA | C6 | C6 |',
  ),
  Tune.fromChart(
    title: 'The Nearness of You',
    composer: 'Hoagy Carmichael',
    year: 1938,
    key: 'F',
    description: 'Ballad',
    tags: {Genre.ballad},
    defaultTempo: 62,
    chart:
        '| [A] $_nearnessA '
        '| [B] Aø7 | D7b9 | Gm7 | Gm7 | Gm7 | C7 | FΔ7 | Gm7 C7 '
        '| [A] $_nearnessA '
        '| [C] Aø7 | D7b9 | Gm7 | C7 | FΔ7 | Dm7 | Gm7 | C7 |',
  ),
];
