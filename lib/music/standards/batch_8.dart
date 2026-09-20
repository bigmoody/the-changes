// Standards, batch 8: Latin and Afro-Cuban tunes, and tunes that aren't in
// 4/4. See tune_library.dart for what these charts contain (chord changes,
// form and titles only) and why.

import '../tune.dart';

// Sections repeated within a tune.
const _shadowA = 'Bø7 | E7b9 | Am7 | Am7 | Dm7 | G7 | CΔ7 | CΔ7';
const _somedayHalf =
    'BbΔ7 | BbΔ7 | D7 | D7 | Gm7 | Gm7 | Bb7 | Bb7 '
    '| EbΔ7 | Ab7 | Bb6 | Gm7 | Cm7 | F7 | Bb6 | Cm7 F7';
const _greensleevesA = 'Em | D | Em | B7 | Em | D | Em B7 | Em';
const _greensleevesB = 'G | D | Em | B7 | G | D | Em B7 | Em';

final standardsBatch8 = <Tune>[
  // ── Latin and Afro-Cuban ───────────────────────────────────────────────
  Tune.fromChart(
    title: 'Oye Como Va',
    composer: 'Tito Puente',
    year: 1963,
    key: 'A minor',
    description: 'Two-chord cha-cha vamp',
    feel: Feel.bossa,
    defaultTempo: 104,
    chart:
        '| [A] Am7 | D7 | Am7 | D7 '
        '| Am7 | D7 | Am7 | D7 |',
  ),
  Tune.fromChart(
    title: 'Manteca',
    composer: 'Dizzy Gillespie & Chano Pozo',
    year: 1947,
    key: 'B♭',
    description: 'Solos on the B♭7 vamp',
    feel: Feel.bossa,
    defaultTempo: 190,
    chart:
        '| [A] Bb7 | Bb7 | Bb7 | Bb7 | Bb7 | Bb7 | Bb7 | Bb7 '
        '| Bb7 | Bb7 | Bb7 | Bb7 | Bb7 | Bb7 | Bb7 | Bb7 |',
  ),
  Tune.fromChart(
    title: 'The Shadow of Your Smile',
    composer: 'Johnny Mandel',
    year: 1964,
    key: 'C',
    feel: Feel.bossa,
    defaultTempo: 140,
    chart:
        '| [A] $_shadowA '
        '| [A] Bø7 | E7b9 | Am7 | A7 | Dm7 | G7 | CΔ7 | C7 '
        '| [B] FΔ7 | FΔ7 | Bø7 E7b9 | Am7 | D7 | D7 | Dm7 | G7 '
        '| [A] $_shadowA |',
  ),
  Tune.fromChart(
    title: 'Afro Blue',
    composer: 'Mongo Santamaría',
    year: 1959,
    key: 'F minor',
    description: 'Modal 3/4 vamp',
    feel: Feel.bossa,
    tags: {Genre.modal},
    beatsPerBar: 3,
    defaultTempo: 200,
    chart:
        '| [A] Fm7 | Fm7 | Fm7 | Fm7 '
        '| Fm7 | Fm7 | Fm7 | Fm7 |',
  ),

  // ── Waltzes and other metres ───────────────────────────────────────────
  Tune.fromChart(
    title: 'Take Five',
    composer: 'Paul Desmond',
    year: 1959,
    key: 'E♭ minor',
    description: 'Solos on the two-bar vamp',
    beatsPerBar: 5,
    defaultTempo: 174,
    chart:
        '| [A] Ebm7 | Bbm7 | Ebm7 | Bbm7 '
        '| Ebm7 | Bbm7 | Ebm7 | Bbm7 |',
  ),
  Tune.fromChart(
    title: 'All Blues',
    composer: 'Miles Davis',
    year: 1959,
    key: 'G',
    description: 'A 12-bar blues in 6/4, counted here in three',
    tags: {Genre.blues},
    beatsPerBar: 3,
    defaultTempo: 140,
    chart:
        '| G7 | G7 | G7 | G7 | G7 | G7 | G7 | G7 '
        '| Gm7 | Gm7 | Gm7 | Gm7 | G7 | G7 | G7 | G7 '
        '| D7#9 | D7#9 | Eb7#9 | D7#9 | G7 | G7 | G7 | G7 |',
  ),
  Tune.fromChart(
    title: 'Someday My Prince Will Come',
    composer: 'Frank Churchill',
    year: 1937,
    key: 'B♭',
    description: 'Jazz waltz',
    beatsPerBar: 3,
    defaultTempo: 160,
    chart:
        '| [A] $_somedayHalf '
        '| [A] $_somedayHalf |',
  ),
  Tune.fromChart(
    title: 'My Favorite Things',
    composer: 'Richard Rodgers',
    year: 1959,
    key: 'E minor',
    description: "Coltrane's modal vamp: E minor, then E major",
    tags: {Genre.modal},
    beatsPerBar: 3,
    defaultTempo: 176,
    chart:
        '| [A] Em7 | Em7 | Em7 | Em7 | Em7 | Em7 | Em7 | Em7 '
        '| [B] EΔ7 | EΔ7 | EΔ7 | EΔ7 | EΔ7 | EΔ7 | F#m7 | B7 |',
  ),
  Tune.fromChart(
    title: 'Greensleeves',
    composer: 'Traditional',
    key: 'E minor',
    description: 'Played as a jazz waltz',
    beatsPerBar: 3,
    defaultTempo: 180,
    chart:
        '| [A] $_greensleevesA '
        '| [B] $_greensleevesB |',
  ),
];
