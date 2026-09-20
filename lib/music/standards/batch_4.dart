// More standards, batch 4 of 5. See tune_library.dart for what these
// charts contain (chord changes, form and titles only) and why.

import '../tune.dart';

// Blowing changes shared by several tunes: each head is its own melody, but
// players solo over the same chords.
const _rhythmChangesBb =
    '| [A] BbΔ7 G7 | Cm7 F7 | Dm7 G7 | Cm7 F7 '
    '| Fm7 Bb7 | EbΔ7 Ebm6 | Dm7 G7 | Cm7 F7 '
    '| [A] BbΔ7 G7 | Cm7 F7 | Dm7 G7 | Cm7 F7 '
    '| Fm7 Bb7 | EbΔ7 Ebm6 | Cm7 F7 | Bb6 '
    '| [B] D7 | D7 | G7 | G7 | C7 | C7 | F7 | F7 '
    '| [A] BbΔ7 G7 | Cm7 F7 | Dm7 G7 | Cm7 F7 '
    '| Fm7 Bb7 | EbΔ7 Ebm6 | Cm7 F7 | Bb6 |';
const _rhythmChangesF =
    '| [A] FΔ7 D7 | Gm7 C7 | Am7 D7 | Gm7 C7 '
    '| Cm7 F7 | BbΔ7 Bbm6 | Am7 D7 | Gm7 C7 '
    '| [A] FΔ7 D7 | Gm7 C7 | Am7 D7 | Gm7 C7 '
    '| Cm7 F7 | BbΔ7 Bbm6 | Gm7 C7 | F6 '
    '| [B] A7 | A7 | D7 | D7 | G7 | G7 | C7 | C7 '
    '| [A] FΔ7 D7 | Gm7 C7 | Am7 D7 | Gm7 C7 '
    '| Cm7 F7 | BbΔ7 Bbm6 | Gm7 C7 | F6 |';
const _jazzBluesBb =
    '| Bb7 | Eb7 | Bb7 | Fm7 Bb7 '
    '| Eb7 | Eo7 | Bb7 | Dm7 G7 '
    '| Cm7 | F7 | Bb7 G7 | Cm7 F7 |';
const _jazzBluesF =
    '| F7 | Bb7 | F7 | Cm7 F7 '
    '| Bb7 | Bo7 | F7 | Am7 D7 '
    '| Gm7 | C7 | F7 D7 | Gm7 C7 |';
const _jazzBluesEb =
    '| Eb7 | Ab7 | Eb7 | Bbm7 Eb7 '
    '| Ab7 | Ao7 | Eb7 | Gm7 C7 '
    '| Fm7 | Bb7 | Eb7 C7 | Fm7 Bb7 |';

// Sections repeated within a tune.
const _nightAndDayA =
    'AbΔ7 | G7 | CΔ7 | CΔ7 | AbΔ7 | G7 | CΔ7 | CΔ7 '
    '| F#ø7 | Fm7 | Em7 | Ebo7 | Dm7 | G7 | CΔ7 | CΔ7';
const _perdidoA = 'Cm7 F7 | Cm7 F7 | Bb6 | Bb6 | Cm7 F7 | Cm7 F7 | Bb6 | Bb6';
const _suedeShoesA = 'Gm7 C7 | Gm7 C7 | F6 | F6 | Gm7 C7 | Gm7 C7 | F6 | F6';
const _oneAndOnlyA = 'CΔ7 Am7 | Dm7 G7 | Em7 A7 | Dm7 G7 | Gm7 C7 | FΔ7 Bb7';
const _nardisA = 'Em | FΔ7 | B7 | CΔ7 | Am7 | FΔ7 | B7 | Em';
const _outOfNowhereA = 'GΔ7 | GΔ7 | Bbm7 | Eb7 | GΔ7 | GΔ7 | Bm7 | E7b9';
const _ladyBeGoodA = 'G6 | G6 | C7 | C7 | G6 | E7 | A7 D7';
const _sunnySideA = 'C6 | E7 | FΔ7 | FΔ7 | D7 | G7';
const _oneNoteA = 'Dm7 | Db7 | Cm7 | B7 | Dm7 | Db7';

final standardsBatch4 = <Tune>[
  Tune.fromChart(
    title: 'My Little Suede Shoes',
    composer: 'Charlie Parker',
    year: 1951,
    key: 'F',
    feel: Feel.calypso,
    defaultTempo: 170,
    chart:
        '| [A] $_suedeShoesA '
        '| [A] $_suedeShoesA '
        '| [B] Cm7 | F7 | BbΔ7 | BbΔ7 | Bbm7 | Eb7 | Am7 D7 | Gm7 C7 '
        '| [A] $_suedeShoesA |',
  ),
  Tune.fromChart(
    title: 'My One and Only Love',
    composer: 'Guy Wood',
    year: 1953,
    key: 'C',
    description: 'Ballad',
    tags: {Genre.ballad},
    defaultTempo: 66,
    chart:
        '| [A] $_oneAndOnlyA | Em7 A7 | Dm7 G7 '
        '| [A] $_oneAndOnlyA | Dm7 G7 | C6 '
        '| [B] Gm7 C7 | FΔ7 | Fm7 Bb7 | Em7 A7 | Dm7 | G7 | Em7 A7 | Dm7 G7 '
        '| [A] $_oneAndOnlyA | Dm7 G7 | C6 |',
  ),
  Tune.fromChart(
    title: 'Nardis',
    composer: 'Miles Davis',
    year: 1958,
    key: 'E minor',
    defaultTempo: 160,
    chart:
        '| [A] $_nardisA '
        '| [A] $_nardisA '
        '| [B] Am7 | FΔ7 | Em | Em | Am7 | FΔ7 | B7 | Em '
        '| [A] $_nardisA |',
  ),
  Tune.fromChart(
    title: 'Night and Day',
    composer: 'Cole Porter',
    year: 1932,
    key: 'C',
    defaultTempo: 160,
    chart:
        '| [A] $_nightAndDayA '
        '| [A] $_nightAndDayA '
        '| [B] EbΔ7 | EbΔ7 | CΔ7 | CΔ7 | EbΔ7 | EbΔ7 | CΔ7 | CΔ7 '
        '| [C] F#ø7 | Fm7 | Em7 | Ebo7 | Dm7 | G7 | C6 | C6 |',
  ),
  Tune.fromChart(
    title: 'Night Train',
    composer: 'Jimmy Forrest',
    year: 1951,
    key: 'A♭',
    description: 'Riff blues',
    tags: {Genre.blues},
    defaultTempo: 120,
    chart:
        '| Ab7 | Ab7 | Ab7 | Ab7 | Db7 | Db7 | Ab7 | Ab7 '
        '| Eb7 | Db7 | Ab7 | Eb7 |',
  ),
  Tune.fromChart(
    title: 'Nostalgia',
    composer: 'Fats Navarro',
    year: 1947,
    key: 'G',
    description: 'Out of Nowhere changes',
    tags: {Genre.bebop},
    defaultTempo: 180,
    chart:
        '| [A] $_outOfNowhereA '
        '| [B] Am7 | E7b9 | Am7 | Am7 | Eb7 | Eb7 | Am7 | D7 '
        '| [A] $_outOfNowhereA '
        '| [C] Am7 | E7b9 | Am7 | Cm6 | Bm7 Bbo7 | Am7 D7 | G6 | Am7 D7 |',
  ),
  Tune.fromChart(
    title: 'Oh, Lady Be Good!',
    composer: 'George Gershwin',
    year: 1924,
    key: 'G',
    defaultTempo: 180,
    chart:
        '| [A] $_ladyBeGoodA | G6 D7 '
        '| [A] $_ladyBeGoodA | G6 '
        '| [B] C6 | C#o7 | G6 | E7 | A7 | A7 | Am7 | D7 '
        '| [A] $_ladyBeGoodA | G6 |',
  ),
  Tune.fromChart(
    title: 'On the Sunny Side of the Street',
    composer: 'Jimmy McHugh',
    year: 1930,
    key: 'C',
    defaultTempo: 130,
    chart:
        '| [A] $_sunnySideA | C6 A7 | Dm7 G7 '
        '| [A] $_sunnySideA | C6 | C6 '
        '| [B] Gm7 C7 | FΔ7 | Am7 D7 | G7 | Gm7 C7 | FΔ7 | D7 | Dm7 G7 '
        '| [A] $_sunnySideA | C6 | Dm7 G7 |',
  ),
  Tune.fromChart(
    title: 'One Note Samba',
    composer: 'Antônio Carlos Jobim',
    year: 1961,
    key: 'B♭',
    feel: Feel.samba,
    defaultTempo: 140,
    chart:
        '| [A] $_oneNoteA | Cm7 | B7 '
        '| Gm7 | Gb7 | Fm7 | E7 | Dm7 | Db7 | Cm7 | B7 '
        '| [B] Ebm7 | Ab7 | DbΔ7 | DbΔ7 | Dbm7 | Gb7 | BΔ7 | Cm7 B7 '
        '| [A] $_oneNoteA | Cm7 B7 | Bb6 |',
  ),
  Tune.fromChart(
    title: "One O'Clock Jump",
    composer: 'Count Basie',
    year: 1937,
    key: 'F',
    description: 'Riff blues',
    tags: {Genre.blues},
    defaultTempo: 170,
    chart: _jazzBluesF,
  ),
  Tune.fromChart(
    title: 'Perdido',
    composer: 'Juan Tizol',
    year: 1942,
    key: 'B♭',
    defaultTempo: 160,
    chart:
        '| [A] $_perdidoA '
        '| [A] $_perdidoA '
        '| [B] Am7 D7 | Am7 D7 | Dm7 G7 | Dm7 G7 '
        '| Gm7 C7 | Gm7 C7 | Cm7 F7 | Cm7 F7 '
        '| [A] $_perdidoA |',
  ),
  Tune.fromChart(
    title: "Relaxin' at Camarillo",
    composer: 'Charlie Parker',
    year: 1947,
    key: 'C',
    description: 'Bebop blues',
    tags: {Genre.bebop, Genre.blues},
    defaultTempo: 170,
    chart:
        '| C7 | F7 | C7 | Gm7 C7 '
        '| F7 | Fm7 Bb7 | Em7 A7 | Ebm7 Ab7 '
        '| Dm7 | G7 | C7 A7 | Dm7 G7 |',
  ),
  Tune.fromChart(
    title: 'Rhythm-a-Ning',
    composer: 'Thelonious Monk',
    year: 1957,
    key: 'B♭',
    description: 'Rhythm changes',
    tags: {Genre.bebop},
    defaultTempo: 240,
    chart: _rhythmChangesBb,
  ),
  Tune.fromChart(
    title: 'Salt Peanuts',
    composer: 'Dizzy Gillespie & Kenny Clarke',
    year: 1942,
    key: 'F',
    description: 'Rhythm changes',
    tags: {Genre.bebop},
    defaultTempo: 280,
    chart: _rhythmChangesF,
  ),
  Tune.fromChart(
    title: "Shaw 'Nuff",
    composer: 'Dizzy Gillespie & Charlie Parker',
    year: 1945,
    key: 'B♭',
    description: 'Rhythm changes',
    tags: {Genre.bebop},
    defaultTempo: 280,
    chart: _rhythmChangesBb,
  ),
  Tune.fromChart(
    title: 'Some Other Blues',
    composer: 'John Coltrane',
    year: 1959,
    key: 'E♭',
    description: 'Jazz blues',
    tags: {Genre.blues},
    defaultTempo: 160,
    chart: _jazzBluesEb,
  ),
  Tune.fromChart(
    title: 'Sonnymoon for Two',
    composer: 'Sonny Rollins',
    year: 1957,
    key: 'B♭',
    description: 'Jazz blues',
    tags: {Genre.blues},
    defaultTempo: 170,
    chart: _jazzBluesBb,
  ),
  Tune.fromChart(
    title: 'Spain',
    composer: 'Chick Corea',
    year: 1972,
    key: 'B minor',
    description: 'Solo section changes',
    feel: Feel.bossa,
    defaultTempo: 220,
    chart:
        '| GΔ7 | GΔ7 | F#7 | F#7 | Em7 | Em7 | A7 | A7 '
        '| DΔ7 | DΔ7 | GΔ7 | GΔ7 | C#ø7 | C#ø7 | F#7 | F#7 '
        '| Bm7 | Bm7 | B7 | B7 |',
  ),
];
