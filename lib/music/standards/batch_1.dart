// More standards, batch 1 of 5. See tune_library.dart for what these
// charts contain (chord changes, form and titles only) and why.

import '../tune.dart';

// Sections repeated within a tune are written once and reused.
const _rhythmA1C =
    'C6 A7 | Dm7 G7 | Em7 A7 | Dm7 G7 '
    '| Gm7 C7 | FΔ7 Fm6 | Em7 A7 | Dm7 G7';
const _rhythmA2C =
    'C6 A7 | Dm7 G7 | Em7 A7 | Dm7 G7 '
    '| Gm7 C7 | FΔ7 Fm6 | Dm7 G7 | C6';
const _rhythmA1Bb =
    'Bb6 G7 | Cm7 F7 | Dm7 G7 | Cm7 F7 '
    '| Fm7 Bb7 | EbΔ7 Ebm6 | Dm7 G7 | Cm7 F7';
const _rhythmA2Bb =
    'Bb6 G7 | Cm7 F7 | Dm7 G7 | Cm7 F7 '
    '| Fm7 Bb7 | EbΔ7 Ebm6 | Cm7 F7 | Bb6';
const _caravanA =
    'C7b9 | C7b9 | C7b9 | C7b9 | C7b9 | C7b9 | C7b9 | C7b9 '
    '| C7b9 | C7b9 | C7b9 | C7b9 | Fm6 | Fm6 | Fm6 | Fm6';
const _foggyA = 'F6 | Abo7 | Gm7 | C7 | F6 | Am7 D7 | Gm7 | C7';
const _aintA = 'Eb6 Eo7 | Fm7 F#o7 | Gm7 Gbo7 | Fm7 Bb7 | Eb6 Eb7 | AbΔ7 Abm6';
const _angelA = 'Dm | Bb7 A7 | Dm | Bb7 A7 | Dm | Gm7 C7';
const _beautifulA = 'Eø7 | A7b9 | Dm7 | Dm7 | Gm7 | C7 | FΔ7 | Eø7 A7b9';
const _blueMoonA =
    'EbΔ7 Cm7 | Fm7 Bb7 | EbΔ7 Cm7 | Fm7 Bb7 | EbΔ7 Cm7 | Fm7 Bb7';
const _bodyA = 'Ebm7 | Bb7 | Ebm7 Ab7 | DbΔ7 Gb7 | Fm7 Eo7 | Ebm7 Ab7';
const _butNotA = 'Fm7 | Bb7 | EbΔ7 | Cm7 | Fm7 | Bb7 | EbΔ7 | Bbm7 Eb7';

final standardsBatch1 = <Tune>[
  Tune.fromChart(
    title: '52nd Street Theme',
    composer: 'Thelonious Monk',
    year: 1944,
    key: 'C',
    description: 'Rhythm changes',
    tags: {Genre.bebop},
    defaultTempo: 260,
    chart:
        '| [A] $_rhythmA1C | [A] $_rhythmA2C '
        '| [B] E7 | E7 | A7 | A7 | D7 | D7 | G7 | G7 '
        '| [A] $_rhythmA2C |',
  ),
  Tune.fromChart(
    title: 'A Foggy Day',
    composer: 'George Gershwin',
    year: 1937,
    key: 'F',
    defaultTempo: 150,
    chart:
        '| [A] $_foggyA '
        '| [B] F6 | Cm7 F7 | BbΔ7 | Bbm6 Eb7 | FΔ7 | Am7 D7 | G7 | Gm7 C7 '
        '| [A] $_foggyA '
        '| [C] F6 | Cm7 F7 | BbΔ7 | Bbm6 Eb7 | Am7 D7 | Gm7 C7 | F6 '
        '| Gm7 C7 |',
  ),
  Tune.fromChart(
    title: "Ain't Misbehavin'",
    composer: 'Fats Waller',
    year: 1929,
    key: 'E♭',
    defaultTempo: 120,
    chart:
        '| [A] $_aintA | Gm7 C7 | Fm7 Bb7 '
        '| [A] $_aintA | Fm7 Bb7 | Eb6 '
        '| [B] Cm Cm^7 | Cm7 Cm6 | Ab7 | G7 | Cm Cm^7 | Cm7 F7 | Bb7 | Bb7 '
        '| [A] $_aintA | Fm7 Bb7 | Eb6 |',
  ),
  Tune.fromChart(
    title: 'Angel Eyes',
    composer: 'Matt Dennis',
    year: 1946,
    key: 'D minor',
    description: 'Ballad',
    feel: Feel.ballad,
    tags: {Genre.ballad},
    defaultTempo: 70,
    chart:
        '| [A] $_angelA | FΔ7 | Eø7 A7b9 '
        '| [A] $_angelA | FΔ7 | Eø7 A7b9 '
        '| [B] Ebm7 Ab7 | DbΔ7 | Ebm7 Ab7 | DbΔ7 | Dm7 G7 | CΔ7 | Eø7 '
        '| A7b9 '
        '| [A] $_angelA | Eø7 A7b9 | Dm6 |',
  ),
  Tune.fromChart(
    title: 'Barbados',
    composer: 'Charlie Parker',
    year: 1948,
    key: 'F',
    description: 'Blues with a Latin head',
    tags: {Genre.bebop, Genre.blues},
    defaultTempo: 180,
    chart:
        '| F7 | Gm7 C7 | F7 | Cm7 F7 '
        '| Bb7 | Bbm7 Eb7 | Am7 | D7b9 '
        '| Gm7 | C7 | F7 D7 | Gm7 C7 |',
  ),
  Tune.fromChart(
    title: 'Beautiful Love',
    composer: 'Victor Young & Wayne King',
    year: 1931,
    key: 'D minor',
    defaultTempo: 140,
    chart:
        '| [A] $_beautifulA '
        '| [B] Dm7 | G7 | Bb7 | A7b9 | Dm7 | Dm7 | Eø7 | A7b9 '
        '| [A] $_beautifulA '
        '| [C] Dm7 | G7 | Bb7 | A7b9 | Dm7 Bb7 | Eø7 A7b9 | Dm6 '
        '| Eø7 A7b9 |',
  ),
  Tune.fromChart(
    title: "Bessie's Blues",
    composer: 'John Coltrane',
    year: 1964,
    key: 'E♭',
    description: 'Blues',
    tags: {Genre.blues},
    defaultTempo: 250,
    chart:
        '| Eb7 | Eb7 | Eb7 | Eb7 '
        '| Ab7 | Ab7 | Eb7 | Eb7 '
        '| Bb7 | Ab7 | Eb7 | Bb7 |',
  ),
  Tune.fromChart(
    title: 'Blue in Green',
    composer: 'Miles Davis & Bill Evans',
    year: 1959,
    key: 'D minor',
    description: '10-bar ballad',
    feel: Feel.ballad,
    tags: {Genre.ballad},
    defaultTempo: 60,
    chart:
        '| BbΔ7 | A7#9 | Dm7 Db7 | Cm7 F7 | BbΔ7 '
        '| A7#9 | Dm6 | E7#9 | Am7 | Dm7 |',
  ),
  Tune.fromChart(
    title: 'Blue Moon',
    composer: 'Richard Rodgers',
    year: 1934,
    key: 'E♭',
    defaultTempo: 130,
    chart:
        '| [A] $_blueMoonA | EbΔ7 Cm7 | Fm7 Bb7 '
        '| [A] $_blueMoonA | Eb6 | Eb6 '
        '| [B] Fm7 Bb7 | EbΔ7 Cm7 | Fm7 Bb7 | EbΔ7 | Abm7 Db7 | GbΔ7 '
        '| Fm7 | Bb7 '
        '| [A] $_blueMoonA | Eb6 | Eb6 |',
  ),
  Tune.fromChart(
    title: 'Blue Seven',
    composer: 'Sonny Rollins',
    year: 1956,
    key: 'B♭',
    description: 'Blues',
    tags: {Genre.blues},
    defaultTempo: 130,
    chart:
        '| Bb7 | Eb7 | Bb7 | Bb7 '
        '| Eb7 | Eb7 | Bb7 | Bb7 '
        '| F7 | Eb7 | Bb7 | F7 |',
  ),
  Tune.fromChart(
    title: 'Blues in the Closet',
    composer: 'Oscar Pettiford',
    year: 1953,
    key: 'F',
    description: 'Jazz blues',
    tags: {Genre.bebop, Genre.blues},
    defaultTempo: 200,
    chart:
        '| F7 | Bb7 | F7 | Cm7 F7 '
        '| Bb7 | Bo7 | F7 | Am7 D7 '
        '| Gm7 | C7 | F7 D7 | Gm7 C7 |',
  ),
  Tune.fromChart(
    title: 'Body and Soul',
    composer: 'Johnny Green',
    year: 1930,
    key: 'D♭',
    description: 'Ballad',
    feel: Feel.ballad,
    tags: {Genre.ballad},
    defaultTempo: 60,
    chart:
        '| [A] $_bodyA | DbΔ7 Gb7 | Fm7 Bb7 '
        '| [A] $_bodyA | Db6 | Db6 '
        '| [B] Em7 A7 | DΔ7 | Em7 A7 | DΔ7 | Dm7 G7 | CΔ7 | Cm7 B7 | Bb7 '
        '| [A] $_bodyA | Db6 | Db6 |',
  ),
  Tune.fromChart(
    title: 'But Not for Me',
    composer: 'George Gershwin',
    year: 1930,
    key: 'E♭',
    defaultTempo: 160,
    chart:
        '| [A] $_butNotA '
        '| [B] AbΔ7 | Db7 | EbΔ7 | Cm7 | F7 | F7 | Fm7 | Bb7 '
        '| [A] $_butNotA '
        '| [C] AbΔ7 | Db7 | Gm7 | C7 | Fm7 | Bb7 | Eb6 | Fm7 Bb7 |',
  ),
  Tune.fromChart(
    title: 'Caravan',
    composer: 'Juan Tizol & Duke Ellington',
    year: 1936,
    key: 'F minor',
    description: 'Latin A sections, swing bridge',
    defaultTempo: 200,
    chart:
        '| [A] $_caravanA | [A] $_caravanA '
        '| [B] F7 | F7 | F7 | F7 | Bb7 | Bb7 | Bb7 | Bb7 '
        '| Eb7 | Eb7 | Eb7 | Eb7 | Ab6 | Ab6 | Gø7 | C7b9 '
        '| [A] $_caravanA |',
  ),
  Tune.fromChart(
    title: 'Chi Chi',
    composer: 'Charlie Parker',
    year: 1953,
    key: 'A♭',
    description: 'Jazz blues',
    tags: {Genre.bebop, Genre.blues},
    defaultTempo: 170,
    chart:
        '| Ab7 | Db7 | Ab7 | Ebm7 Ab7 '
        '| Db7 | Dbm7 Gb7 | Cm7 | F7 '
        '| Bbm7 | Eb7 | Ab7 F7 | Bbm7 Eb7 |',
  ),
  Tune.fromChart(
    title: 'Cool Blues',
    composer: 'Charlie Parker',
    year: 1947,
    key: 'C',
    description: 'Jazz blues',
    tags: {Genre.bebop, Genre.blues},
    defaultTempo: 190,
    chart:
        '| C7 | F7 | C7 | Gm7 C7 '
        '| F7 | F#o7 | C7 | Em7 A7 '
        '| Dm7 | G7 | C7 A7 | Dm7 G7 |',
  ),
  Tune.fromChart(
    title: 'Cotton Tail',
    composer: 'Duke Ellington',
    year: 1940,
    key: 'B♭',
    description: 'Rhythm changes',
    tags: {Genre.bebop},
    defaultTempo: 240,
    chart:
        '| [A] $_rhythmA1Bb | [A] $_rhythmA2Bb '
        '| [B] D7 | D7 | G7 | G7 | C7 | C7 | F7 | F7 '
        '| [A] $_rhythmA2Bb |',
  ),
  Tune.fromChart(
    title: 'Countdown',
    composer: 'John Coltrane',
    year: 1959,
    key: 'D',
    description: 'Tune Up with Coltrane changes',
    defaultTempo: 300,
    chart:
        '| Em7 F7 | BbΔ7 Db7 | GbΔ7 A7 | DΔ7 '
        '| Dm7 Eb7 | AbΔ7 B7 | EΔ7 G7 | CΔ7 '
        '| Cm7 Db7 | GbΔ7 A7 | DΔ7 F7 | BbΔ7 '
        '| Em7 | F7 | BbΔ7 | BbΔ7 |',
  ),
];
