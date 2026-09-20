// More standards, batch 5 of 5. See tune_library.dart for what these
// charts contain (chord changes, form and titles only) and why.

import '../tune.dart';

const _sweetGeorgiaA = 'D7 | D7 | D7 | D7 | G7 | G7 | G7 | G7';
const _woodyA = 'Gø7 | C7b9 | Fø7 | Bb7b9 | Ebm7 | Ab7 | DbΔ7 | DbΔ7';
const _weeA = 'AbΔ7 F7 | Bbm7 Eb7 | Cm7 F7 | Bbm7 Eb7 | Ebm7 Ab7 | DbΔ7 Dbm6';
const _weeA1 = '$_weeA | Cm7 F7 | Bbm7 Eb7';
const _weeA2 = '$_weeA | Bbm7 Eb7 | Ab6';

final standardsBatch5 = <Tune>[
  Tune.fromChart(
    title: 'Sweet Georgia Brown',
    composer: 'Ben Bernie & Maceo Pinkard',
    year: 1925,
    key: 'F',
    defaultTempo: 200,
    chart:
        '| [A] $_sweetGeorgiaA '
        '| [B] C7 | C7 | C7 | C7 | F6 | F6 | F6 | F6 '
        '| [A] $_sweetGeorgiaA '
        '| [C] Gm7 | D7 | Gm7 | D7 | F6 | D7 | Gm7 C7 | F6 |',
  ),
  Tune.fromChart(
    title: "Things Ain't What They Used to Be",
    composer: 'Mercer Ellington',
    year: 1942,
    key: 'D♭',
    description: 'Blues',
    tags: {Genre.blues},
    defaultTempo: 120,
    chart:
        '| Db7 | Gb7 | Db7 | Db7 '
        '| Gb7 | Go7 | Db7 | Bb7 '
        '| Ebm7 | Ab7 | Db7 Bb7 | Ebm7 Ab7 |',
  ),
  Tune.fromChart(
    title: "Walkin'",
    composer: 'Richard Carpenter',
    year: 1954,
    key: 'F',
    description: 'Blues',
    tags: {Genre.blues},
    defaultTempo: 150,
    chart:
        '| F7 | Bb7 | F7 | Cm7 F7 '
        '| Bb7 | Bo7 | F7 | Am7 D7 '
        '| Gm7 | C7 | F7 D7 | Gm7 C7 |',
  ),
  Tune.fromChart(
    title: 'Wee',
    composer: 'Denzil Best',
    year: 1947,
    key: 'A♭',
    description: 'Rhythm changes',
    tags: {Genre.bebop},
    defaultTempo: 280,
    chart:
        '| [A] $_weeA1 '
        '| [A] $_weeA2 '
        '| [B] C7 | C7 | F7 | F7 | Bb7 | Bb7 | Eb7 | Eb7 '
        '| [A] $_weeA2 |',
  ),
  Tune.fromChart(
    title: "Woody'n You",
    composer: 'Dizzy Gillespie',
    year: 1942,
    key: 'D♭',
    tags: {Genre.bebop},
    defaultTempo: 200,
    chart:
        '| [A] $_woodyA '
        '| [A] $_woodyA '
        '| [B] Ebm7 | Ab7 | DbΔ7 | DbΔ7 | Ebm7 | Ab7 | DbΔ7 | DbΔ7 '
        '| [A] $_woodyA |',
  ),
];
