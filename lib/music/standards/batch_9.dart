// Hard bop, modal and post-bop, batch 9 of the standards. See
// tune_library.dart for what these charts contain (chord changes, form and
// titles only) and why.

import '../tune.dart';

const _jazzBluesF =
    '| F7 | Bb7 | F7 | Cm7 F7 '
    '| Bb7 | Bo7 | F7 | Am7 D7 '
    '| Gm7 | C7 | F7 D7 | Gm7 C7 |';

// Blowing changes shared by several tunes: each head is its own melody, but
// players solo over the same chords.
const _jazzBluesBb =
    '| Bb7 | Eb7 | Bb7 | Fm7 Bb7 '
    '| Eb7 | Eo7 | Bb7 | Dm7 G7 '
    '| Cm7 | F7 | Bb7 G7 | Cm7 F7 |';
const _plainBluesBb =
    '| Bb7 | Eb7 | Bb7 | Bb7 '
    '| Eb7 | Eb7 | Bb7 | Bb7 '
    '| F7 | Eb7 | Bb7 | F7 |';
const _plainBluesF =
    '| F7 | Bb7 | F7 | F7 '
    '| Bb7 | Bb7 | F7 | F7 '
    '| C7 | Bb7 | F7 | C7 |';
const _minorBluesC =
    '| Cm7 | Cm7 | Cm7 | Cm7 '
    '| Fm7 | Fm7 | Cm7 | Cm7 '
    '| Ab7 | G7 | Cm7 | G7 |';

// Sections repeated within a tune.
const _hackensackA = 'Bb6 | Bb6 | Eb7 | Eb7 | Bb6 | G7 | C7 F7';
const _needntA = 'F7 | Gb7 | F7 | Gb7 | F7 | Gb7 | F7 | F7';
const _whisperNotA = 'Cm7 | Fm7 | Dø7 | G7b9 | Cm7 | Fm7 | Dø7 G7b9';

final standardsBatch9 = <Tune>[
  Tune.fromChart(
    title: 'Birdlike',
    composer: 'Freddie Hubbard',
    year: 1961,
    key: 'B♭',
    description: 'Jazz blues',
    tags: {Genre.blues, Genre.bebop},
    defaultTempo: 260,
    chart: _jazzBluesBb,
  ),
  Tune.fromChart(
    title: 'Blues March',
    composer: 'Benny Golson',
    year: 1958,
    key: 'B♭',
    description: 'Jazz blues, played as a march',
    tags: {Genre.blues},
    defaultTempo: 150,
    chart: _jazzBluesBb,
  ),
  Tune.fromChart(
    title: 'Cousin Mary',
    composer: 'John Coltrane',
    year: 1959,
    key: 'B♭',
    description: '12-bar blues',
    tags: {Genre.blues},
    defaultTempo: 150,
    chart: _plainBluesBb,
  ),
  Tune.fromChart(
    title: 'Hackensack',
    composer: 'Thelonious Monk',
    year: 1954,
    key: 'B♭',
    description: 'Oh, Lady Be Good! changes',
    tags: {Genre.bebop},
    defaultTempo: 220,
    chart:
        '| [A] $_hackensackA | Bb6 F7 '
        '| [A] $_hackensackA | Bb6 '
        '| [B] Eb6 | Eo7 | Bb6 | G7 | C7 | C7 | Cm7 | F7 '
        '| [A] $_hackensackA | Bb6 |',
  ),
  Tune.fromChart(
    title: 'Misterioso',
    composer: 'Thelonious Monk',
    year: 1948,
    key: 'B♭',
    description: '12-bar blues',
    tags: {Genre.blues},
    defaultTempo: 120,
    chart: _plainBluesBb,
  ),
  Tune.fromChart(
    title: 'No Blues',
    composer: 'Miles Davis',
    year: 1961,
    key: 'F',
    description: 'Jazz blues, also called Pfrancing',
    tags: {Genre.blues},
    defaultTempo: 150,
    chart: _jazzBluesF,
  ),
  Tune.fromChart(
    title: 'Sister Sadie',
    composer: 'Horace Silver',
    year: 1959,
    key: 'F',
    description: '12-bar blues',
    tags: {Genre.blues},
    defaultTempo: 160,
    chart: _plainBluesF,
  ),
  Tune.fromChart(
    title: 'Village Blues',
    composer: 'John Coltrane',
    year: 1960,
    key: 'C minor',
    description: 'Minor blues',
    tags: {Genre.blues},
    defaultTempo: 130,
    chart: _minorBluesC,
  ),
  Tune.fromChart(
    title: "Well You Needn't",
    composer: 'Thelonious Monk',
    year: 1947,
    key: 'F',
    defaultTempo: 200,
    chart:
        '| [A] $_needntA '
        '| [A] $_needntA '
        '| [B] Db7 | D7 | Eb7 | E7 | F7 | E7 | Eb7 | D7 '
        '| [A] $_needntA |',
  ),
  Tune.fromChart(
    title: 'Whisper Not',
    composer: 'Benny Golson',
    year: 1956,
    key: 'C minor',
    defaultTempo: 140,
    chart:
        '| [A] $_whisperNotA | Cm7 '
        '| [A] $_whisperNotA | Cm7 '
        '| [B] Fm7 | Bb7 | EbΔ7 | EbΔ7 | Am7 | D7 | GΔ7 | G7b9 '
        '| [A] $_whisperNotA | Cm6 |',
  ),
];
