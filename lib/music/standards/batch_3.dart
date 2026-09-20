// More standards, batch 3 of 5. See tune_library.dart for what these
// charts contain (chord changes, form and titles only) and why.

import '../tune.dart';

const _mellowToneA = 'Bbm7 | Eb7 | AbΔ7 | AbΔ7 | Ebm7 | Ab7 | DbΔ7 | DbΔ7';
const _indianaA = 'FΔ7 | D7 | G7 | G7 | Gm7 | C7';
const _rhythmA = 'BbΔ7 G7 | Cm7 F7 | Dm7 G7 | Cm7 F7 | Fm7 Bb7 | EbΔ7 Ebm6';
const _aprilA =
    'G6 | G6 | G6 | G6 | Gm6 | Gm6 | Gm6 | Gm6 | Am7 | Bø7 E7 | Am7 | D7';
const _sentimentalA =
    'Dm Dm^7 | Dm7 Dm6 | Gm Gm^7 | Gm7 Gm6 | Eø7 A7 | Dm7 G7 | Gm7 C7';
const _dontMeanA = 'Gm Gm^7 | Gm7 C7 | Eb7 | D7 | Gm Gm^7 | Gm7 C7 | Cm7 F7';
const _joySpringA = 'FΔ7 | Gm7 C7 | FΔ7 | Bbm7 Eb7 | Am7 D7 | Gm7 C7';
const _killerJoeA =
    'C7 Bb7 | C7 Bb7 | C7 Bb7 | C7 Bb7 | C7 Bb7 | C7 Bb7 | C7 Bb7 | C7 Bb7';
const _valentineLine = 'Cm | Cm^7 | Cm7 | Cm6';
const _mistyA = 'EbΔ7 | Bbm7 Eb7 | AbΔ7 | Abm7 Db7 | EbΔ7 Cm7 | Fm7 Bb7';

final standardsBatch3 = <Tune>[
  Tune.fromChart(
    title: "I'll Remember April",
    composer: 'Gene de Paul',
    year: 1941,
    key: 'G',
    defaultTempo: 190,
    chart:
        '| [A] $_aprilA | GΔ7 | GΔ7 | F#ø7 | B7 '
        '| [B] Em7 | F#ø7 B7 | Em7 | F#ø7 B7 | Em7 | Am7 D7 | GΔ7 | GΔ7 '
        '| Gm7 | Aø7 D7 | Gm7 | Aø7 D7 | Gm7 | Cm7 F7 | BbΔ7 | Am7 D7 '
        '| [A] $_aprilA | G6 | G6 | Am7 | D7 |',
  ),
  Tune.fromChart(
    title: 'In a Mellow Tone',
    composer: 'Duke Ellington',
    year: 1940,
    key: 'A♭',
    defaultTempo: 140,
    chart:
        '| [A] $_mellowToneA '
        '| [B] Dbm7 | Gb7 | AbΔ7 | F7 | Bb7 | Bb7 | Bbm7 | Eb7 '
        '| [A] $_mellowToneA '
        '| [C] DbΔ7 | Dbm7 Gb7 | AbΔ7 | F7 | Bbm7 | Eb7 | Ab6 | Bbm7 Eb7 |',
  ),
  Tune.fromChart(
    title: 'In a Sentimental Mood',
    composer: 'Duke Ellington',
    year: 1935,
    key: 'D minor',
    description: 'Ballad',
    tags: {Genre.ballad},
    defaultTempo: 60,
    chart:
        '| [A] $_sentimentalA | Eø7 A7 '
        '| [A] $_sentimentalA | FΔ7 '
        '| [B] DbΔ7 Bbm7 | Ebm7 Ab7 | DbΔ7 Bbm7 | Ebm7 Ab7 '
        '| DbΔ7 Bbm7 | Ebm7 Ab7 | Gm7 | C7 '
        '| [A] $_sentimentalA | FΔ7 |',
  ),
  Tune.fromChart(
    title: 'Indiana',
    composer: 'James F. Hanley',
    year: 1917,
    key: 'F',
    description: 'The changes behind "Donna Lee"',
    defaultTempo: 200,
    chart:
        '| [A] $_indianaA | FΔ7 | Cm7 F7 '
        '| [B] BbΔ7 | Bbm7 Eb7 | FΔ7 | D7 | G7 | G7 | Gm7 | C7 '
        '| [A] $_indianaA | Dm7 | A7b9 '
        '| [C] Dm7 | A7b9 | Dm7 | Abo7 | Am7 D7 | Gm7 C7 | F6 | Gm7 C7 |',
  ),
  Tune.fromChart(
    title: "It Don't Mean a Thing",
    composer: 'Duke Ellington',
    year: 1931,
    key: 'G minor',
    defaultTempo: 180,
    chart:
        '| [A] $_dontMeanA | Aø7 D7 '
        '| [A] $_dontMeanA | Bb6 '
        '| [B] Fm7 Bb7 | Fm7 Bb7 | EbΔ7 | EbΔ7 '
        '| Gm7 C7 | Gm7 C7 | Cm7 F7 | Aø7 D7 '
        '| [A] $_dontMeanA | Bb6 |',
  ),
  Tune.fromChart(
    title: 'Joy Spring',
    composer: 'Clifford Brown',
    year: 1954,
    key: 'F',
    description: 'Second A a half step up',
    defaultTempo: 170,
    chart:
        '| [A] $_joySpringA | Am7 D7 | Abm7 Db7 '
        '| [A] GbΔ7 | Abm7 Db7 | GbΔ7 | Bm7 E7 '
        '| Bbm7 Eb7 | Abm7 Db7 | Bbm7 Eb7 | Am7 D7 '
        '| [B] Gm7 | C7 | FΔ7 | FΔ7 | Fm7 | Bb7 | EbΔ7 | Gm7 C7 '
        '| [A] $_joySpringA | F6 | Gm7 C7 |',
  ),
  Tune.fromChart(
    title: "Jumpin' at the Woodside",
    composer: 'Count Basie',
    year: 1938,
    key: 'B♭',
    description: 'Rhythm changes',
    defaultTempo: 230,
    chart:
        '| [A] $_rhythmA | Dm7 G7 | Cm7 F7 '
        '| [A] $_rhythmA | Cm7 F7 | Bb6 '
        '| [B] D7 | D7 | G7 | G7 | C7 | C7 | F7 | F7 '
        '| [A] $_rhythmA | Cm7 F7 | Bb6 |',
  ),
  Tune.fromChart(
    title: 'K.C. Blues',
    composer: 'Charlie Parker',
    year: 1951,
    key: 'C',
    description: 'Jazz blues',
    tags: {Genre.blues},
    defaultTempo: 120,
    chart:
        '| C7 | F7 | C7 | Gm7 C7 '
        '| F7 | F#o7 | C7 | Em7 A7 '
        '| Dm7 | G7 | C7 A7 | Dm7 G7 |',
  ),
  Tune.fromChart(
    title: 'Killer Joe',
    composer: 'Benny Golson',
    year: 1959,
    key: 'C',
    defaultTempo: 130,
    chart:
        '| [A] $_killerJoeA '
        '| [A] $_killerJoeA '
        '| [B] Eø7 | A7#9 | Ebm7 | Ab7 | Dm7 | G7 | Dm7 | G7 '
        '| [A] $_killerJoeA |',
  ),
  Tune.fromChart(
    title: 'Lester Leaps In',
    composer: 'Lester Young',
    year: 1939,
    key: 'B♭',
    description: 'Rhythm changes',
    defaultTempo: 220,
    chart:
        '| [A] $_rhythmA | Dm7 G7 | Cm7 F7 '
        '| [A] $_rhythmA | Cm7 F7 | Bb6 '
        '| [B] D7 | D7 | G7 | G7 | C7 | C7 | F7 | F7 '
        '| [A] $_rhythmA | Cm7 F7 | Bb6 |',
  ),
  Tune.fromChart(
    title: 'Misty',
    composer: 'Erroll Garner',
    year: 1954,
    key: 'E♭',
    description: 'Ballad',
    tags: {Genre.ballad},
    defaultTempo: 66,
    chart:
        '| [A] $_mistyA | Gm7 C7 | Fm7 Bb7 '
        '| [A] $_mistyA | Eb6 | Bbm7 Eb7 '
        '| [B] Bbm7 | Eb7b9 | AbΔ7 | AbΔ7 | Am7 | D7 | Gm7 C7 | Fm7 Bb7 '
        '| [A] $_mistyA | Eb6 | Fm7 Bb7 |',
  ),
  Tune.fromChart(
    title: 'My Funny Valentine',
    composer: 'Richard Rodgers',
    year: 1937,
    key: 'C minor',
    description: 'Ballad',
    tags: {Genre.ballad},
    defaultTempo: 60,
    chart:
        '| [A] $_valentineLine | AbΔ7 | Fm7 | Dø7 | G7 '
        '| [A] $_valentineLine | AbΔ7 | Fm7 | Dø7 | G7 '
        '| [B] EbΔ7 Fm7 | Gm7 Fm7 | EbΔ7 Fm7 | Gm7 Fm7 '
        '| EbΔ7 Gm7 | Cm7 F7 | Fm7 Bb7 | Dø7 G7 '
        '| [A] $_valentineLine | AbΔ7 | Dø7 G7 | Cm | Bbm7 Eb7 '
        '| AbΔ7 | Dø7 G7 | Cm | Dø7 G7 |',
  ),
];
