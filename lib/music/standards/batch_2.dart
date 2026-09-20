// More standards, batch 2 of 5. See tune_library.dart for what these
// charts contain (chord changes, form and titles only) and why.

import '../tune.dart';

const _dontGetAroundA = 'C6 | C6 | A7 | A7 | Dm7 | G7';
const _missJonesA = 'FΔ7 | F#o7 | Gm7 | C7';
const _doxyA = 'Bb7 Ab7 | G7 | C7 F7';
const _digA = 'D7 | D7 | G7 | G7 | Gm7 | C7 | F6 | F6';
const _rhythmAbA =
    'AbΔ7 F7 | Bbm7 Eb7 | Cm7 F7 | Bbm7 Eb7 '
    '| Ebm7 Ab7 | DbΔ7 Dbm6 | Cm7 F7';
const _exactlyA = 'C6 | C6 | D7 | D7 | Dm7 | G7';
const _hotHouseA = 'Cø7 | F7b9 | Bbm6 | Bbm6 | Gø7 | C7b9 | FΔ7 | FΔ7';
const _howHighA = 'GΔ7 | GΔ7 | Gm7 | C7 | FΔ7 | FΔ7 | Fm7 | Bb7';
const _cantGetStartedA = 'C6 Am7 | Dm7 G7 | Em7 A7 | Dm7 G7 | Gm7 C7 | FΔ7 Bb7';

final standardsBatch2 = <Tune>[
  Tune.fromChart(
    title: 'Dig',
    composer: 'Miles Davis',
    year: 1951,
    key: 'F',
    description: 'Changes of "Sweet Georgia Brown"',
    tags: {Genre.bebop},
    defaultTempo: 220,
    chart:
        '| [A] $_digA '
        '| [B] D7 | D7 | Gm7 | Gm7 | D7 | D7 | Gm7 | Gm7 '
        '| [A] $_digA '
        '| [C] Bb6 | Bo7 | F/C | D7 | G7 | C7 | F6 | Gm7 C7 |',
  ),
  Tune.fromChart(
    title: 'Dizzy Atmosphere',
    composer: 'Dizzy Gillespie',
    year: 1945,
    key: 'A♭',
    description: 'Rhythm changes',
    tags: {Genre.bebop},
    defaultTempo: 260,
    chart:
        '| [A] $_rhythmAbA | Bbm7 Eb7 '
        '| [A] $_rhythmAbA | Ab6 '
        '| [B] C7 | C7 | F7 | F7 | Bb7 | Bb7 | Eb7 | Eb7 '
        '| [A] $_rhythmAbA | Ab6 |',
  ),
  Tune.fromChart(
    title: "Don't Get Around Much Anymore",
    composer: 'Duke Ellington',
    year: 1942,
    key: 'C',
    defaultTempo: 130,
    chart:
        '| [A] $_dontGetAroundA | C6 | Dm7 G7 '
        '| [A] $_dontGetAroundA | C6 | C6 '
        '| [B] F6 | F#o7 | C6 | A7 | D7 | D7 | G7 | G7 '
        '| [A] $_dontGetAroundA | C6 | Dm7 G7 |',
  ),
  Tune.fromChart(
    title: "Doodlin'",
    composer: 'Horace Silver',
    year: 1954,
    key: 'E♭',
    description: 'Jazz blues',
    tags: {Genre.blues},
    defaultTempo: 120,
    chart:
        '| Eb7 | Ab7 | Eb7 | Bbm7 Eb7 '
        '| Ab7 | Ao7 | Eb7 | Gm7 C7 '
        '| Fm7 | Bb7 | Eb7 C7 | Fm7 Bb7 |',
  ),
  Tune.fromChart(
    title: 'Doxy',
    composer: 'Sonny Rollins',
    year: 1954,
    key: 'B♭',
    description: '16-bar form',
    defaultTempo: 130,
    chart:
        '| $_doxyA | Bb7 F7 '
        '| $_doxyA | Bb7 '
        '| Eb7 | Eo7 | Bb7 | G7 '
        '| C7 | F7 | Bb7 G7 | C7 F7 |',
  ),
  Tune.fromChart(
    title: 'Exactly Like You',
    composer: 'Jimmy McHugh',
    year: 1930,
    key: 'C',
    defaultTempo: 150,
    chart:
        '| [A] $_exactlyA | C6 A7 | Dm7 G7 '
        '| [A] $_exactlyA | C6 | C6 '
        '| [B] C7 | C7 | F6 | F6 | D7 | D7 | Dm7 | G7 '
        '| [A] $_exactlyA | C6 A7 | Dm7 G7 |',
  ),
  Tune.fromChart(
    title: 'Freedom Jazz Dance',
    composer: 'Eddie Harris',
    year: 1965,
    key: 'B♭',
    description: 'One-chord vamp',
    feel: Feel.funk,
    defaultTempo: 120,
    chart:
        '| Bb7 | Bb7 | Bb7 | Bb7 | Bb7 | Bb7 | Bb7 | Bb7 '
        '| Bb7 | Bb7 | Bb7 | Bb7 | Bb7 | Bb7 | Bb7 | Bb7 |',
  ),
  Tune.fromChart(
    title: 'Half Nelson',
    composer: 'Miles Davis',
    year: 1947,
    key: 'C',
    description: 'Changes of "Lady Bird"',
    tags: {Genre.bebop},
    defaultTempo: 180,
    chart:
        '| CΔ7 | CΔ7 | Fm7 | Bb7 | CΔ7 | CΔ7 | Bbm7 | Eb7 '
        '| AbΔ7 | AbΔ7 | Am7 | D7 | Dm7 | G7 | CΔ7 Eb7 | AbΔ7 Db7 |',
  ),
  Tune.fromChart(
    title: 'Have You Met Miss Jones?',
    composer: 'Richard Rodgers',
    year: 1937,
    key: 'F',
    description: 'Bridge moves in major thirds',
    defaultTempo: 160,
    chart:
        '| [A] $_missJonesA | Am7 D7 | Gm7 C7 | Am7 D7 | Gm7 C7 '
        '| [A] $_missJonesA | Am7 D7 | Gm7 C7 | F6 | Cm7 F7 '
        '| [B] BbΔ7 | Abm7 Db7 | GbΔ7 | Em7 A7 '
        '| DΔ7 | Abm7 Db7 | GbΔ7 | Gm7 C7 '
        '| [A] $_missJonesA | Am7 D7 | Gm7 C7 | F6 | Gm7 C7 |',
  ),
  Tune.fromChart(
    title: 'Hot House',
    composer: 'Tadd Dameron',
    year: 1945,
    key: 'F',
    description: 'Changes of "What Is This Thing Called Love"',
    tags: {Genre.bebop},
    defaultTempo: 220,
    chart:
        '| [A] $_hotHouseA | [A] $_hotHouseA '
        '| [B] Fm7 | Bb7 | EbΔ7 | EbΔ7 | Db7 | Db7 | Gø7 | C7 '
        '| [A] $_hotHouseA |',
  ),
  Tune.fromChart(
    title: 'How High the Moon',
    composer: 'Morgan Lewis',
    year: 1940,
    key: 'G',
    defaultTempo: 200,
    chart:
        '| [A] $_howHighA '
        '| [B] EbΔ7 | Am7 D7 | GΔ7 | Am7 D7 | Bm7 | E7 | Am7 | D7 '
        '| [A] $_howHighA '
        '| [C] EbΔ7 | Am7 D7 | GΔ7 | Am7 D7 | Bm7 E7 | Am7 D7 | G6 '
        '| Am7 D7 |',
  ),
  Tune.fromChart(
    title: "I Can't Get Started",
    composer: 'Vernon Duke',
    year: 1936,
    key: 'C',
    description: 'Ballad',
    tags: {Genre.ballad},
    defaultTempo: 70,
    chart:
        '| [A] $_cantGetStartedA | Em7 A7 | Dm7 G7 '
        '| [A] $_cantGetStartedA | Dm7 G7 | C6 '
        '| [B] Am7 D7 | Am7 D7 | GΔ7 | GΔ7 '
        '| Gm7 C7 | Gm7 C7 | FΔ7 | Dm7 G7 '
        '| [A] $_cantGetStartedA | Dm7 G7 | C6 |',
  ),
];
