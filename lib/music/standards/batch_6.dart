// Bebop, batch 6: Parker, Gillespie and the bebop generation — the blues
// and rhythm-changes contrafacts that a bebop set is built from. See
// tune_library.dart for what these charts contain (chord changes, form and
// titles only) and why.

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
const _rhythmChangesC =
    '| [A] CΔ7 A7 | Dm7 G7 | Em7 A7 | Dm7 G7 '
    '| Gm7 C7 | FΔ7 Fm6 | Em7 A7 | Dm7 G7 '
    '| [A] CΔ7 A7 | Dm7 G7 | Em7 A7 | Dm7 G7 '
    '| Gm7 C7 | FΔ7 Fm6 | Dm7 G7 | C6 '
    '| [B] E7 | E7 | A7 | A7 | D7 | D7 | G7 | G7 '
    '| [A] CΔ7 A7 | Dm7 G7 | Em7 A7 | Dm7 G7 '
    '| Gm7 C7 | FΔ7 Fm6 | Dm7 G7 | C6 |';
const _jazzBluesBb =
    '| Bb7 | Eb7 | Bb7 | Fm7 Bb7 '
    '| Eb7 | Eo7 | Bb7 | Dm7 G7 '
    '| Cm7 | F7 | Bb7 G7 | Cm7 F7 |';
const _jazzBluesC =
    '| C7 | F7 | C7 | Gm7 C7 '
    '| F7 | F#o7 | C7 | Em7 A7 '
    '| Dm7 | G7 | C7 A7 | Dm7 G7 |';
// Sections repeated within a tune.
const _cherokeeA =
    'Bb6 | Bb6 | Bb6 | Bb6 | Fm7 | Bb7 | EbΔ7 | EbΔ7 '
    '| Ab7 | Ab7 | Bb6 | Bb6 | Cm7 | F7 | Bb6 | Bb6';
const _pentUpHouseA = 'FΔ7 | Bb7 | Am7 | D7 | Gm7 | C7';
const _minorBluesF =
    '| Fm7 | Fm7 | Fm7 | Fm7 '
    '| Bbm7 | Bbm7 | Fm7 | Fm7 '
    '| Db7 | C7 | Fm7 | C7 |';

final standardsBatch6 = <Tune>[
  Tune.fromChart(
    title: 'Cheryl',
    composer: 'Charlie Parker',
    year: 1947,
    key: 'C',
    description: 'Bebop blues',
    tags: {Genre.bebop, Genre.blues},
    defaultTempo: 220,
    chart: _jazzBluesC,
  ),
  Tune.fromChart(
    title: 'Bloomdido',
    composer: 'Charlie Parker',
    year: 1950,
    key: 'B♭',
    description: 'Bebop blues',
    tags: {Genre.bebop, Genre.blues},
    defaultTempo: 200,
    chart: _jazzBluesBb,
  ),
  Tune.fromChart(
    title: 'Buzzy',
    composer: 'Charlie Parker',
    year: 1947,
    key: 'B♭',
    description: 'Bebop blues',
    tags: {Genre.bebop, Genre.blues},
    defaultTempo: 200,
    chart: _jazzBluesBb,
  ),
  Tune.fromChart(
    title: 'Perhaps',
    composer: 'Charlie Parker',
    year: 1948,
    key: 'B♭',
    description: 'Bebop blues',
    tags: {Genre.bebop, Genre.blues},
    defaultTempo: 210,
    chart: _jazzBluesBb,
  ),
  Tune.fromChart(
    title: 'Mohawk',
    composer: 'Charlie Parker',
    year: 1950,
    key: 'B♭',
    description: 'Bebop blues',
    tags: {Genre.bebop, Genre.blues},
    defaultTempo: 190,
    chart: _jazzBluesBb,
  ),
  Tune.fromChart(
    title: "Parker's Mood",
    composer: 'Charlie Parker',
    year: 1948,
    key: 'B♭',
    description: 'Slow blues',
    tags: {Genre.bebop, Genre.blues},
    defaultTempo: 70,
    chart: _jazzBluesBb,
  ),
  Tune.fromChart(
    title: 'Back Home Blues',
    composer: 'Charlie Parker',
    year: 1951,
    key: 'B♭',
    description: 'Bebop blues',
    tags: {Genre.bebop, Genre.blues},
    defaultTempo: 180,
    chart: _jazzBluesBb,
  ),
  Tune.fromChart(
    title: 'Wee Dot',
    composer: 'J.J. Johnson',
    year: 1949,
    key: 'B♭',
    description: 'Bebop blues',
    tags: {Genre.bebop, Genre.blues},
    defaultTempo: 200,
    chart: _jazzBluesBb,
  ),
  Tune.fromChart(
    title: "Blue 'n Boogie",
    composer: 'Dizzy Gillespie',
    year: 1945,
    key: 'B♭',
    description: 'Riff blues',
    tags: {Genre.bebop, Genre.blues},
    defaultTempo: 200,
    chart:
        '| Bb7 | Bb7 | Bb7 | Bb7 '
        '| Eb7 | Eb7 | Bb7 | Bb7 '
        '| F7 | Eb7 | Bb7 | F7 |',
  ),
  Tune.fromChart(
    title: 'Birks Works',
    composer: 'Dizzy Gillespie',
    year: 1951,
    key: 'F minor',
    description: 'Minor blues',
    tags: {Genre.bebop, Genre.blues},
    defaultTempo: 130,
    chart: _minorBluesF,
  ),
  Tune.fromChart(
    title: 'Moose the Mooche',
    composer: 'Charlie Parker',
    year: 1946,
    key: 'B♭',
    description: 'Rhythm changes',
    tags: {Genre.bebop},
    defaultTempo: 240,
    chart: _rhythmChangesBb,
  ),
  Tune.fromChart(
    title: 'Dexterity',
    composer: 'Charlie Parker',
    year: 1947,
    key: 'B♭',
    description: 'Rhythm changes',
    tags: {Genre.bebop},
    defaultTempo: 240,
    chart: _rhythmChangesBb,
  ),
  Tune.fromChart(
    title: 'Red Cross',
    composer: 'Charlie Parker',
    year: 1944,
    key: 'B♭',
    description: 'Rhythm changes',
    tags: {Genre.bebop},
    defaultTempo: 230,
    chart: _rhythmChangesBb,
  ),
  Tune.fromChart(
    title: 'The Eternal Triangle',
    composer: 'Sonny Stitt',
    year: 1957,
    key: 'B♭',
    description: 'Rhythm changes',
    tags: {Genre.bebop},
    defaultTempo: 260,
    chart: _rhythmChangesBb,
  ),
  Tune.fromChart(
    title: 'Little Benny',
    composer: 'Benny Harris',
    year: 1946,
    key: 'B♭',
    description: 'Rhythm changes',
    tags: {Genre.bebop},
    defaultTempo: 250,
    chart: _rhythmChangesBb,
  ),
  Tune.fromChart(
    title: 'Ah-Leu-Cha',
    composer: 'Charlie Parker',
    year: 1948,
    key: 'C',
    description: 'Rhythm changes',
    tags: {Genre.bebop},
    defaultTempo: 230,
    chart: _rhythmChangesC,
  ),
  Tune.fromChart(
    title: 'Ow!',
    composer: 'Dizzy Gillespie',
    year: 1947,
    key: 'B♭',
    description: 'Rhythm changes',
    tags: {Genre.bebop},
    defaultTempo: 240,
    chart: _rhythmChangesBb,
  ),
  Tune.fromChart(
    title: 'Ko-Ko',
    composer: 'Charlie Parker',
    year: 1945,
    key: 'B♭',
    description: 'Cherokee changes',
    tags: {Genre.bebop},
    defaultTempo: 300,
    chart:
        '| [A] $_cherokeeA '
        '| [A] $_cherokeeA '
        '| [B] C#m7 | F#7 | BΔ7 | BΔ7 | Bm7 | E7 | AΔ7 | AΔ7 '
        '| Am7 | D7 | GΔ7 | GΔ7 | Gm7 | C7 | Cm7 | F7 '
        '| [A] $_cherokeeA |',
  ),
  Tune.fromChart(
    title: 'Pent-Up House',
    composer: 'Sonny Rollins',
    year: 1956,
    key: 'F',
    tags: {Genre.bebop},
    defaultTempo: 200,
    chart:
        '| [A] $_pentUpHouseA | FΔ7 | FΔ7 '
        '| [A] $_pentUpHouseA | FΔ7 | Gm7 C7 |',
  ),
  Tune.fromChart(
    title: 'Bird of Paradise',
    composer: 'Charlie Parker',
    year: 1947,
    key: 'A♭',
    description: 'All the Things You Are changes',
    tags: {Genre.bebop},
    defaultTempo: 200,
    chart:
        '| [A] Fm7 | Bbm7 | Eb7 | AbΔ7 | DbΔ7 | Dm7 G7 | CΔ7 | CΔ7 '
        '| [A] Cm7 | Fm7 | Bb7 | EbΔ7 | AbΔ7 | Am7 D7 | GΔ7 | GΔ7 '
        '| [B] Am7 | D7 | GΔ7 | GΔ7 | F#m7 | B7 | EΔ7 | C7alt '
        '| [C] Fm7 | Bbm7 | Eb7 | AbΔ7 | DbΔ7 | Dbm7 | Cm7 | Bo7 '
        '| Bbm7 | Eb7 | Ab6 | Gø7 C7b9 |',
  ),
];
