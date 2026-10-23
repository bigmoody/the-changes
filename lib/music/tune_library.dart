// The built-in tunes.
//
// Legal note: these charts contain only chord changes, form and titles.
// Chord progressions and song titles generally aren't protected by
// copyright; melodies and lyrics are, so they are never included.
//
// Standards are played in many versions. These follow common jam-session
// changes in their usual keys. Report mistakes rather than trusting them
// blindly.

import 'standards/batch_1.dart';
import 'standards/batch_2.dart';
import 'standards/batch_3.dart';
import 'standards/batch_4.dart';
import 'standards/batch_5.dart';
import 'standards/batch_6.dart';
import 'standards/batch_7.dart';
import 'standards/batch_8.dart';
import 'standards/batch_9.dart';
import 'standards/batch_10.dart';
import 'tune.dart';

/// Short, generic progressions for drilling a specific skill.
final practiceProgressions = <Tune>[
  Tune.fromChart(
    title: 'Jazz blues in F',
    key: 'F',
    description: '12-bar blues with jazz substitutions',
    tags: {Genre.blues},
    defaultTempo: 120,
    chart: _jazzBluesF,
  ),
  Tune.fromChart(
    title: 'Rhythm changes in B♭',
    key: 'B♭',
    description: 'The I–vi–ii–V cycle behind hundreds of bebop tunes',
    tags: {Genre.bebop},
    defaultTempo: 160,
    chart: _rhythmChanges,
  ),
  Tune.fromChart(
    title: 'Major ii–V–I in three keys',
    key: 'C, B♭, A♭',
    description: 'Moving down a whole step each time',
    defaultTempo: 110,
    chart:
        '| Dm7 | G7 | CΔ7 | CΔ7 '
        '| Cm7 | F7 | BbΔ7 | BbΔ7 '
        '| Bbm7 | Eb7 | AbΔ7 | Ab6 |',
  ),
  Tune.fromChart(
    title: 'Jazz Waltz ii–V–I',
    key: 'C',
    description: 'Three to the bar',
    defaultTempo: 160,
    beatsPerBar: 3,
    chart: '| Dm7 | G7 | CΔ7 | CΔ7 | Dm7 | G7 | CΔ7 | A7b9 |',
  ),
  Tune.fromChart(
    title: 'Minor ii–V–i',
    key: 'C minor, F minor',
    description: 'Half-diminished to altered dominant',
    defaultTempo: 100,
    chart: '| Dø7 | G7b9 | Cm6 | Cm6 | Gø7 | C7b9 | Fm6 | Fm6 |',
  ),
];

// Blowing changes shared by many tunes: a head is its own melody, but players
// solo over the same chords.
const _jazzBluesF =
    '| F7 | Bb7 | F7 | Cm7 F7 '
    '| Bb7 | Bo7 | F7 | Am7 D7 '
    '| Gm7 | C7 | F7 D7 | Gm7 C7 |';
const _jazzBluesBb =
    '| Bb7 | Eb7 | Bb7 | Fm7 Bb7 '
    '| Eb7 | Eo7 | Bb7 | Dm7 G7 '
    '| Cm7 | F7 | Bb7 G7 | Cm7 F7 |';
const _rhythmChanges =
    '| [A] BbΔ7 G7 | Cm7 F7 | Dm7 G7 | Cm7 F7 '
    '| Fm7 Bb7 | EbΔ7 Ebm6 | Dm7 G7 | Cm7 F7 '
    '| [A] BbΔ7 G7 | Cm7 F7 | Dm7 G7 | Cm7 F7 '
    '| Fm7 Bb7 | EbΔ7 Ebm6 | Cm7 F7 | Bb6 '
    '| [B] D7 | D7 | G7 | G7 | C7 | C7 | F7 | F7 '
    '| [A] BbΔ7 G7 | Cm7 F7 | Dm7 G7 | Cm7 F7 '
    '| Fm7 Bb7 | EbΔ7 Ebm6 | Cm7 F7 | Bb6 |';
const _dorianAABA =
    '| [A] Dm7 | Dm7 | Dm7 | Dm7 | Dm7 | Dm7 | Dm7 | Dm7 '
    '| [A] Dm7 | Dm7 | Dm7 | Dm7 | Dm7 | Dm7 | Dm7 | Dm7 '
    '| [B] Ebm7 | Ebm7 | Ebm7 | Ebm7 | Ebm7 | Ebm7 | Ebm7 | Ebm7 '
    '| [A] Dm7 | Dm7 | Dm7 | Dm7 | Dm7 | Dm7 | Dm7 | Dm7 |';

// Sections that repeat within a tune are written once and reused.
const _autumnA = 'Cm7 | F7 | BbΔ7 | EbΔ7 | Aø7 | D7 | Gm6 | Gm6';
const _cherokeeA =
    'Bb6 | Bb6 | Fm7 | Bb7 | Eb6 | Eb6 | Ebm7 | Ab7 '
    '| Bb6 | Bb6 | C7 | C7 | Cm7 | F7';
const _satinDollA =
    'Dm7 G7 | Dm7 G7 | Em7 A7 | Em7 A7 | Am7 D7 | Abm7 Db7 | C6 | C6';
const _songForMyFatherA = 'Fm7 | Fm7 | Eb7 | Eb7 | Db7 | C7 | Fm7 | Fm7';
const _aTrainA = 'C6 | C6 | D7#11 | D7#11 | Dm7 | G7';
const _ipanemaA = 'FΔ7 | FΔ7 | G7 | G7 | Gm7 | Gb7';
const _neverAnotherA = 'EbΔ7 | EbΔ7 | Dø7 | G7b9 | Cm7 | Cm7 | Bbm7 | Eb7';
const _flyMeA = 'Am7 | Dm7 | G7 | CΔ7 | FΔ7 | Bø7 | E7 | Am7 A7';
const _justFriendsA = 'CΔ7 | CΔ7 | Cm7 | F7 | GΔ7 | GΔ7 | Bbm7 | Eb7';
const _noGreaterLoveA = 'BbΔ7 | Eb7 | Ab7#11 | G7';
const _softlyA = 'Cm7 | Dø7 G7b9 | Cm7 | Dø7 G7b9 | Cm7 | Dø7 G7b9';
const _greenDolphinA = 'EbΔ7 | EbΔ7 | Ebm7 | Ebm7 | F7/Eb | EΔ7/Eb | EbΔ7 | C7';
const _winesA = 'FΔ7 | Eb7#11 | Am7 | D7b9 | Gm7 | Gm7 | Bbm7 | Eb7';
const _honeysuckleA = 'Gm7 C7 | Gm7 C7 | Gm7 C7 | Gm7 C7 | F6 F7/A | Bb6 C7';
const _outOfNowhereA = 'GΔ7 | GΔ7 | Bbm7 | Eb7 | GΔ7 | GΔ7 | Bm7 | E7b9';
const _thisThingA = 'Gø7 | C7b9 | Fm6 | Fm6 | Dø7 | G+7 | CΔ7 | CΔ7';
const _confirmationA = 'FΔ7 | Eø7 A7b9 | Dm7 G7 | Cm7 F7 | Bb7 | Am7 D7';
const _scrappleA = 'Gm7 | C7 | Gm7 | C7 | FΔ7 F7/A | BbΔ7 Bo7';
const _groovinHighA = 'EbΔ7 | EbΔ7 | Am7 | D7 | EbΔ7 | EbΔ7 | Gm7 | C7';
const _ornithologyA = 'GΔ7 | GΔ7 | Gm7 | C7 | FΔ7 | FΔ7 | Fm7 | Bb7';
const _yardbirdA = 'C6 | Fm7 Bb7 | C7 Bb7 | A7 | D7 | G7';
const _moaninA =
    'Fm7 Ab7 | G7 C7 | Fm7 Ab7 | G7 C7 | Fm7 Ab7 | G7 C7 | Fm7 Ab7 | G7 C7';
const _fourA = 'EbΔ7 | EbΔ7 | Ebm7 | Ab7 | Fm7 | Fm7 | Abm7 | Db7';
const _fourB = 'EbΔ7/G | F#m7 B7 | Fm7 | Bb7';
const _tuneUpA =
    'Em7 | A7 | DΔ7 | DΔ7 | Dm7 | G7 | CΔ7 | CΔ7 | Cm7 | F7 | BbΔ7 | BbΔ7';
const _speakNoEvilA =
    'Cm7 | DbΔ7 | Cm7 | DbΔ7 | Cm7 | DbΔ7 | Cm7 | DbΔ7 Ebm7 '
    '| Em7 Cm7 | Dm7 Bbm7 | A7alt | Bbm7 | A7alt | Bbm7';
const _maidenVoyageA =
    'D7sus4 | D7sus4 | D7sus4 | D7sus4 | F7sus4 | F7sus4 | F7sus4 | F7sus4';
const _waveA =
    'DΔ7 | Bbo7 | Am7 | D7b9 | GΔ7 | Gm6 | F#13 F#7alt | B9 B7b9 '
    '| E9 | Bb7 A7 | Dm7 G7 | Dm7 G7';
const _tunisiaA = 'Eb7 | Dm6 | Eb7 | Dm6 | Eb7 | Dm6 | Eø7 A7b9 | Dm6';

/// Well-known jazz standards, sorted by title: the first set, written here,
/// and the rest in `standards/`.
final standards = <Tune>[
  ..._firstStandards,
  ...standardsBatch1,
  ...standardsBatch2,
  ...standardsBatch3,
  ...standardsBatch4,
  ...standardsBatch5,
  ...standardsBatch6,
  ...standardsBatch7,
  ...standardsBatch8,
  ...standardsBatch9,
  ...standardsBatch10,
]..sort((a, b) => a.title.compareTo(b.title));

final _firstStandards = <Tune>[
  Tune.fromChart(
    title: 'All of Me',
    composer: 'Gerald Marks & Seymour Simons',
    year: 1931,
    key: 'C',
    defaultTempo: 140,
    chart:
        '| [A] C6 | C6 | E7 | E7 | A7 | A7 | Dm7 | Dm7 '
        '| [B] E7 | E7 | Am7 | Am7 | D7 | D7 | Dm7 | G7 '
        '| [A] C6 | C6 | E7 | E7 | A7 | A7 | Dm7 | Dm7 '
        '| [C] F6 | Fm6 | Em7 | A7 | Dm7 | G7 | C6 | Dm7 G7 |',
  ),
  Tune.fromChart(
    title: 'Anthropology',
    composer: 'Charlie Parker & Dizzy Gillespie',
    year: 1946,
    key: 'B♭',
    description: 'Rhythm changes',
    tags: {Genre.bebop},
    defaultTempo: 220,
    chart: _rhythmChanges,
  ),
  Tune.fromChart(
    title: 'C Jam Blues',
    composer: 'Duke Ellington',
    year: 1942,
    key: 'C',
    description: 'Jazz blues',
    tags: {Genre.blues},
    defaultTempo: 150,
    chart:
        '| C7 | F7 | C7 | Gm7 C7 '
        '| F7 | F#o7 | C7 | Em7 A7 '
        '| Dm7 | G7 | C7 A7 | Dm7 G7 |',
  ),
  Tune.fromChart(
    title: 'Chameleon',
    composer: 'Herbie Hancock',
    year: 1973,
    key: 'B♭ Dorian',
    description: 'The vamp everyone solos over',
    feel: Feel.funk,
    tags: {Genre.modal},
    defaultTempo: 96,
    chart: '| Bbm7 | Eb7 | Bbm7 | Eb7 | Bbm7 | Eb7 | Bbm7 | Eb7 |',
  ),
  Tune.fromChart(
    title: 'Equinox',
    composer: 'John Coltrane',
    year: 1964,
    key: 'C♯ minor',
    description: 'Minor blues',
    tags: {Genre.blues},
    defaultTempo: 140,
    chart:
        '| C#m7 | C#m7 | C#m7 | C#m7 | F#m7 | F#m7 | C#m7 | C#m7 '
        '| A7 | G#7 | C#m7 | C#m7 |',
  ),
  Tune.fromChart(
    title: 'Impressions',
    composer: 'John Coltrane',
    year: 1963,
    key: 'D Dorian',
    description: 'Same form as So What, usually much faster',
    tags: {Genre.modal},
    defaultTempo: 240,
    chart: _dorianAABA,
    // The same figure as So What's, the other way up: the chord lifts to
    // the shape above and is left there rather than the shape above
    // falling onto the chord. Same two voicings, opposite gesture, and it
    // is most of why two tunes on one form do not sound like one tune.
    quartalSlide: QuartalSlide.up,
  ),
  Tune.fromChart(
    title: "Now's the Time",
    composer: 'Charlie Parker',
    year: 1945,
    key: 'F',
    description: 'Jazz blues',
    tags: {Genre.bebop, Genre.blues},
    defaultTempo: 160,
    chart: _jazzBluesF,
  ),
  Tune.fromChart(
    title: 'Oleo',
    composer: 'Sonny Rollins',
    year: 1954,
    key: 'B♭',
    description: 'Rhythm changes',
    tags: {Genre.bebop},
    defaultTempo: 220,
    chart: _rhythmChanges,
  ),
  Tune.fromChart(
    title: 'Sandu',
    composer: 'Clifford Brown',
    year: 1955,
    key: 'E♭',
    description: 'Jazz blues',
    tags: {Genre.blues},
    defaultTempo: 130,
    chart:
        '| Eb7 | Ab7 | Eb7 | Bbm7 Eb7 '
        '| Ab7 | Ao7 | Eb7 | Gm7 C7 '
        '| Fm7 | Bb7 | Eb7 C7 | Fm7 Bb7 |',
  ),
  Tune.fromChart(
    title: 'Straight, No Chaser',
    composer: 'Thelonious Monk',
    year: 1951,
    // Monk's key. The F version comes from Miles Davis's Milestones, via
    // the Real Book; the key button gets there in one tap.
    key: 'B♭',
    description: 'Jazz blues',
    tags: {Genre.blues},
    defaultTempo: 150,
    chart: _jazzBluesBb,
  ),
  Tune.fromChart(
    title: 'All the Things You Are',
    composer: 'Jerome Kern',
    year: 1939,
    key: 'A♭',
    defaultTempo: 140,
    chart:
        '| [A] Fm7 | Bbm7 | Eb7 | AbΔ7 | DbΔ7 | Dm7 G7 | CΔ7 | CΔ7 '
        '| [A] Cm7 | Fm7 | Bb7 | EbΔ7 | AbΔ7 | Aø7 D7 | GΔ7 | GΔ7 '
        '| [B] Am7 | D7 | GΔ7 | GΔ7 | F#m7 | B7 | EΔ7 | C7#5 '
        '| [A] Fm7 | Bbm7 | Eb7 | AbΔ7 | DbΔ7 | Dbm7 | Cm7 | Bo7 '
        '| Bbm7 | Eb7 | AbΔ7 | Gø7 C7 |',
  ),
  Tune.fromChart(
    title: 'Autumn Leaves',
    composer: 'Joseph Kosma',
    year: 1945,
    key: 'G minor',
    defaultTempo: 130,
    chart:
        '| [A] $_autumnA | [A] $_autumnA '
        '| [B] Aø7 | D7 | Gm6 | Gm6 | Cm7 | F7 | BbΔ7 | EbΔ7 '
        '| [C] Aø7 | D7 | Gm7 C7 | Fm7 Bb7 | EbΔ7 | Aø7 D7 | Gm6 | Gm6 |',
  ),
  Tune.fromChart(
    title: 'Blue Bossa',
    composer: 'Kenny Dorham',
    year: 1963,
    key: 'C minor',
    feel: Feel.bossa,
    defaultTempo: 140,
    chart:
        '| [A] Cm6 | Cm6 | Fm7 | Fm7 | Dø7 | G7b9 | Cm6 | Cm6 '
        '| [B] Ebm7 | Ab7 | DbΔ7 | DbΔ7 | Dø7 | G7b9 | Cm6 | Dø7 G7b9 |',
  ),
  Tune.fromChart(
    title: 'Blues for Alice',
    composer: 'Charlie Parker',
    year: 1951,
    key: 'F',
    tags: {Genre.bebop, Genre.blues},
    defaultTempo: 150,
    chart:
        '| FΔ7 | Eø7 A7b9 | Dm7 G7 | Cm7 F7 '
        '| Bb7 | Bbm7 Eb7 | Am7 D7 | Abm7 Db7 '
        '| Gm7 | C7 | FΔ7 D7 | Gm7 C7 |',
  ),
  Tune.fromChart(
    title: 'Cantaloupe Island',
    composer: 'Herbie Hancock',
    year: 1964,
    key: 'F minor',
    feel: Feel.funk,
    tags: {Genre.modal},
    defaultTempo: 110,
    chart:
        '| Fm7 | Fm7 | Fm7 | Fm7 | Db7 | Db7 | Db7 | Db7 '
        '| Dm7 | Dm7 | Dm7 | Dm7 | Fm7 | Fm7 | Fm7 | Fm7 |',
  ),
  Tune.fromChart(
    title: 'Cherokee',
    composer: 'Ray Noble',
    year: 1938,
    key: 'B♭',
    tags: {Genre.bebop},
    defaultTempo: 200,
    chart:
        '| [A] $_cherokeeA | Bb6 | Cm7 F7 '
        '| [A] $_cherokeeA | Bb6 | Bb6 '
        '| [B] C#m7 | F#7 | BΔ7 | BΔ7 | Bm7 | E7 | AΔ7 | AΔ7 '
        '| Am7 | D7 | GΔ7 | GΔ7 | Gm7 | C7 | Cm7 | F7 '
        '| [A] $_cherokeeA | Bb6 | Cm7 F7 |',
  ),
  Tune.fromChart(
    title: 'Fly Me to the Moon',
    composer: 'Bart Howard',
    year: 1954,
    key: 'C',
    defaultTempo: 120,
    chart:
        '| [A] $_flyMeA '
        '| [B] Dm7 | G7 | CΔ7 | A7 | Dm7 | G7 | CΔ7 | Bø7 E7 '
        '| [A] $_flyMeA '
        '| [C] Dm7 | G7 | Em7 | A7 | Dm7 | G7 | CΔ7 | Bø7 E7 |',
  ),
  Tune.fromChart(
    title: 'Freddie Freeloader',
    composer: 'Miles Davis',
    year: 1959,
    key: 'B♭',
    tags: {Genre.blues},
    defaultTempo: 120,
    chart:
        '| Bb7 | Bb7 | Bb7 | Bb7 | Eb7 | Eb7 | Bb7 | Bb7 '
        '| F7 | Eb7 | Ab7 | Bb7 |',
  ),
  Tune.fromChart(
    title: 'Giant Steps',
    composer: 'John Coltrane',
    year: 1960,
    key: 'B',
    defaultTempo: 140,
    chart:
        '| BΔ7 D7 | GΔ7 Bb7 | EbΔ7 | Am7 D7 '
        '| GΔ7 Bb7 | EbΔ7 F#7 | BΔ7 | Fm7 Bb7 '
        '| EbΔ7 | Am7 D7 | GΔ7 | C#m7 F#7 '
        '| BΔ7 | Fm7 Bb7 | EbΔ7 | C#m7 F#7 |',
  ),
  Tune.fromChart(
    title: 'Lady Bird',
    composer: 'Tadd Dameron',
    key: 'C',
    tags: {Genre.bebop},
    defaultTempo: 150,
    chart:
        '| CΔ7 | CΔ7 | Fm7 | Bb7 | CΔ7 | CΔ7 | Bbm7 | Eb7 '
        '| AbΔ7 | AbΔ7 | Am7 | D7 | Dm7 | G7 | CΔ7 Eb7 | AbΔ7 Db7 |',
  ),
  Tune.fromChart(
    title: 'Mr. P.C.',
    composer: 'John Coltrane',
    year: 1960,
    key: 'C minor',
    tags: {Genre.blues},
    defaultTempo: 200,
    chart:
        '| Cm7 | Cm7 | Cm7 | Cm7 | Fm7 | Fm7 | Cm7 | Cm7 '
        '| Ab7 | G7 | Cm7 | Cm7 |',
  ),
  Tune.fromChart(
    title: 'Satin Doll',
    composer: 'Duke Ellington & Billy Strayhorn',
    year: 1953,
    key: 'C',
    defaultTempo: 130,
    chart:
        '| [A] $_satinDollA | [A] $_satinDollA '
        '| [B] Gm7 | C7 | FΔ7 | FΔ7 | Am7 | D7 | Dm7 | G7 '
        '| [A] $_satinDollA |',
  ),
  Tune.fromChart(
    title: 'So What',
    composer: 'Miles Davis',
    year: 1959,
    key: 'D Dorian',
    tags: {Genre.modal},
    defaultTempo: 140,
    chart: _dorianAABA,
    // The shape above falls onto the chord: the figure the tune, and the
    // chord, are named after.
    quartalSlide: QuartalSlide.down,
  ),
  Tune.fromChart(
    title: 'Solar',
    composer: 'Miles Davis',
    year: 1954,
    key: 'C minor',
    defaultTempo: 140,
    chart:
        '| CmΔ7 | CmΔ7 | Gm7 | C7 | FΔ7 | FΔ7 | Fm7 | Bb7 '
        '| EbΔ7 | Ebm7 Ab7 | DbΔ7 | Dø7 G7 |',
  ),
  Tune.fromChart(
    title: 'Song for My Father',
    composer: 'Horace Silver',
    year: 1965,
    key: 'F minor',
    feel: Feel.bossa,
    defaultTempo: 120,
    chart:
        '| [A] $_songForMyFatherA | [A] $_songForMyFatherA '
        '| [B] Eb7 | Eb7 | Fm7 | Fm7 | Eb7 | Db7 C7 | Fm7 | Fm7 |',
  ),
  Tune.fromChart(
    title: 'Stella by Starlight',
    composer: 'Victor Young',
    year: 1944,
    key: 'B♭',
    defaultTempo: 120,
    chart:
        '| [A] Eø7 | A7b9 | Cm7 | F7 | Fm7 | Bb7 | EbΔ7 | Ab7 '
        '| [B] BbΔ7 | Eø7 A7b9 | Dm7 | Bbm7 Eb7 | FΔ7 | Eø7 A7b9 | Aø7 | D7b9 '
        '| [C] G7#5 | G7#5 | Cm7 | Cm7 | Ab7 | Ab7 | BbΔ7 | BbΔ7 '
        '| [D] Eø7 | A7b9 | Dø7 | G7b9 | Cø7 | F7b9 | BbΔ7 | BbΔ7 |',
  ),
  Tune.fromChart(
    title: 'Take the "A" Train',
    composer: 'Billy Strayhorn',
    year: 1939,
    key: 'C',
    defaultTempo: 160,
    chart:
        '| [A] $_aTrainA | C6 | Dm7 G7 '
        '| [A] $_aTrainA | C6 | C6 '
        '| [B] FΔ7 | FΔ7 | FΔ7 | FΔ7 | D7 | D7 | Dm7 | G7 '
        '| [A] $_aTrainA | C6 | C6 |',
  ),
  Tune.fromChart(
    title: 'Tenor Madness',
    composer: 'Sonny Rollins',
    year: 1956,
    key: 'B♭',
    tags: {Genre.blues},
    defaultTempo: 160,
    chart: _jazzBluesBb,
  ),
  Tune.fromChart(
    title: 'The Girl from Ipanema',
    composer: 'Antônio Carlos Jobim',
    year: 1962,
    key: 'F',
    feel: Feel.bossa,
    defaultTempo: 130,
    chart:
        '| [A] $_ipanemaA | FΔ7 | Gb7 '
        '| [A] $_ipanemaA | FΔ7 | FΔ7 '
        '| [B] GbΔ7 | GbΔ7 | B7 | B7 | F#m7 | F#m7 | D7 | D7 '
        '| Gm7 | Gm7 | Eb7 | Eb7 | Am7 | D7 | Gm7 | C7 '
        '| [A] $_ipanemaA | FΔ7 | FΔ7 |',
  ),
  Tune.fromChart(
    title: 'There Will Never Be Another You',
    composer: 'Harry Warren',
    year: 1942,
    key: 'E♭',
    defaultTempo: 140,
    chart:
        '| [A] $_neverAnotherA '
        '| [B] AbΔ7 | Db7 | EbΔ7 | Cm7 | F7 | F7 | Fm7 | Bb7 '
        '| [A] $_neverAnotherA '
        '| [C] AbΔ7 | Db7 | Gm7 | C7 | Fm7 | Bb7 | Eb6 | Fm7 Bb7 |',
  ),
  // ── Swing standards ──
  Tune.fromChart(
    title: 'Bye Bye Blackbird',
    composer: 'Ray Henderson',
    year: 1926,
    key: 'F',
    defaultTempo: 130,
    chart:
        '| [A] FΔ7 | Gm7 C7 | FΔ7 | Gm7 C7 | FΔ7 | Aø7 D7b9 | Gm7 | C7 '
        '| [B] Gm7 | D7 | Gm7 | C7 | Gm7 | C7 | F6 | F6 '
        '| [C] F7 | E7 | Eb7 | D7b9 | Gm7 | Gm7 | Db7 | C7 '
        '| [A] FΔ7 | Gm7 C7 | FΔ7 | Aø7 D7b9 | Gm7 | C7 | F6 | Gm7 C7 |',
  ),
  Tune.fromChart(
    title: 'Days of Wine and Roses',
    composer: 'Henry Mancini',
    year: 1962,
    key: 'F',
    defaultTempo: 140,
    chart:
        '| [A] $_winesA '
        '| [B] Am7 | Dm7 | Gm7 | C7 | Eø7 A7b9 | Dm7 G7 | Gm7 | C7 '
        '| [A] $_winesA '
        '| [C] Am7 | Dm7 | Bø7 | E7b9 | Am7 Dm7 | Gm7 C7 | F6 | Gm7 C7 |',
  ),
  Tune.fromChart(
    title: 'Honeysuckle Rose',
    composer: 'Fats Waller',
    year: 1929,
    key: 'F',
    defaultTempo: 170,
    chart:
        '| [A] $_honeysuckleA | F6 Bb7 | Am7 D7 '
        '| [A] $_honeysuckleA | F6 | F6 '
        '| [B] F7 | F7 | Bb6 | Bb6 | G7 | G7 | C7 | C7 '
        '| [A] $_honeysuckleA | F6 Bb7 | Am7 D7 |',
  ),
  Tune.fromChart(
    title: 'I Got Rhythm',
    composer: 'George Gershwin',
    year: 1930,
    key: 'B♭',
    description: 'The original rhythm changes',
    defaultTempo: 200,
    chart: _rhythmChanges,
  ),
  Tune.fromChart(
    title: 'Just Friends',
    composer: 'John Klenner',
    year: 1931,
    key: 'G',
    defaultTempo: 160,
    chart:
        '| [A] $_justFriendsA '
        '| [B] Am7 | D7 | GΔ7 | Em7 | A7 | A7 | Am7 D7 | Dm7 G7 '
        '| [A] $_justFriendsA '
        '| [C] Am7 | D7 | F#ø7 B7b9 | Em7 | A7 | Am7 D7 | G6 | Dm7 G7 |',
  ),
  Tune.fromChart(
    title: 'On Green Dolphin Street',
    composer: 'Bronisław Kaper',
    year: 1947,
    key: 'E♭',
    description: 'A sections often played Latin',
    defaultTempo: 170,
    chart:
        '| [A] $_greenDolphinA '
        '| [B] Fm7 | Bb7 | EbΔ7 | EbΔ7 | Abm7 | Db7 | GbΔ7 | Fm7 Bb7 '
        '| [A] $_greenDolphinA '
        '| [C] Fm7 | Dø7 G7b9 | Cm7 | Aø7 D7b9 | Gm7 C7 | Fm7 Bb7 | Eb6 '
        '| Fm7 Bb7 |',
  ),
  Tune.fromChart(
    title: 'Out of Nowhere',
    composer: 'Johnny Green',
    year: 1931,
    key: 'G',
    defaultTempo: 150,
    chart:
        '| [A] $_outOfNowhereA '
        '| [B] Am7 | E7b9 | Am7 | Am7 | Eb7 | Eb7 | Am7 | D7 '
        '| [A] $_outOfNowhereA '
        '| [C] Am7 | E7b9 | Am7 | Cm6 | Bm7 Bbo7 | Am7 D7 | G6 | Am7 D7 |',
  ),
  Tune.fromChart(
    title: 'Softly, as in a Morning Sunrise',
    composer: 'Sigmund Romberg',
    year: 1928,
    key: 'C minor',
    defaultTempo: 160,
    chart:
        '| [A] $_softlyA | Cm7 | Dø7 G7b9 '
        '| [A] $_softlyA | Cm7 | Fm7 Bb7 '
        '| [B] EbΔ7 | EbΔ7 | C7b9 | C7b9 | Fm7 | F#o7 | Dø7 | G7b9 '
        '| [A] $_softlyA | Cm7 | Dø7 G7b9 |',
  ),
  Tune.fromChart(
    title: 'Summertime',
    composer: 'George Gershwin',
    year: 1935,
    // The Real Book and iReal Pro key; D minor (Coltrane's) is one tap away.
    key: 'A minor',
    description: '16-bar minor form',
    defaultTempo: 100,
    chart:
        '| Am7 | Bø7 E7b9 | Am7 | Am7 A7b9 | Dm7 | F7 | Bø7 | E7b9 '
        '| Am7 | Bø7 E7b9 | Am7 | D7 G7 | CΔ7 Am7 | Bø7 E7b9 | Am7 '
        '| Bø7 E7b9 |',
  ),
  Tune.fromChart(
    title: 'There Is No Greater Love',
    composer: 'Isham Jones',
    year: 1936,
    key: 'B♭',
    defaultTempo: 150,
    chart:
        '| [A] $_noGreaterLoveA | C7 | C7 | Cm7 | F7 '
        '| [A] $_noGreaterLoveA | C7 | Cm7 F7 | Bb6 | Bb6 '
        '| [B] Aø7 D7b9 | Gm6 | Aø7 D7b9 | Gm6 | Aø7 D7b9 | Gm6 | C7 | F7 '
        '| [A] $_noGreaterLoveA | C7 | Cm7 F7 | Bb6 | Cm7 F7 |',
  ),
  Tune.fromChart(
    title: 'What Is This Thing Called Love',
    composer: 'Cole Porter',
    year: 1929,
    key: 'C',
    defaultTempo: 240,
    chart:
        '| [A] $_thisThingA | [A] $_thisThingA '
        '| [B] Cm7 | F7 | BbΔ7 | BbΔ7 | Ab7 | Ab7 | Dø7 | G7 '
        '| [A] $_thisThingA |',
  ),
  // ── Bebop ──
  Tune.fromChart(
    title: 'Donna Lee',
    composer: 'Charlie Parker',
    year: 1947,
    key: 'A♭',
    description: 'Changes of "Indiana"',
    tags: {Genre.bebop},
    defaultTempo: 240,
    chart:
        '| [A] AbΔ7 | F7 | Bb7 | Bb7 | Bbm7 | Eb7 | AbΔ7 | Ebm7 Ab7 '
        '| DbΔ7 | Dbm7 Gb7 | AbΔ7 | F7 | Bb7 | Bb7 | Bbm7 | Eb7 '
        '| [B] AbΔ7 | F7 | Bb7 | Bb7 | Gø7 | C7b9 | Fm7 | C7b9 '
        '| Fm7 | C7b9 | Fm7 | Bo7 | Cm7 F7 | Bbm7 Eb7 | Ab6 | Bbm7 Eb7 |',
  ),
  Tune.fromChart(
    title: 'Confirmation',
    composer: 'Charlie Parker',
    year: 1945,
    key: 'F',
    tags: {Genre.bebop},
    defaultTempo: 200,
    chart:
        '| [A] $_confirmationA | G7 | C7b9 '
        '| [A] $_confirmationA | Gm7 C7 | FΔ7 '
        '| [B] Cm7 | F7 | BbΔ7 | BbΔ7 | Ebm7 | Ab7 | DbΔ7 | Gm7 C7alt '
        '| [A] $_confirmationA | Gm7 C7 | FΔ7 C7 |',
  ),
  Tune.fromChart(
    title: 'Scrapple from the Apple',
    composer: 'Charlie Parker',
    year: 1947,
    key: 'F',
    description: 'Honeysuckle Rose A, rhythm-changes bridge',
    tags: {Genre.bebop},
    defaultTempo: 200,
    chart:
        '| [A] $_scrappleA | FΔ7 Gm7 | Am7 D7 '
        '| [A] $_scrappleA | FΔ7 C7 | FΔ7 '
        '| [B] A7 | A7 | D7 | D7 | G7 | G7 | C7 | C7 '
        '| [A] $_scrappleA | FΔ7 Gm7 | Am7 D7 |',
  ),
  Tune.fromChart(
    title: "Groovin' High",
    composer: 'Dizzy Gillespie',
    year: 1945,
    key: 'E♭',
    description: 'Changes of "Whispering"',
    tags: {Genre.bebop},
    defaultTempo: 200,
    chart:
        '| [A] $_groovinHighA '
        '| [B] F7 | F7 | Fm7 | Bb7 | Gm7 | Gbm7 | Fm7 | Bb7 '
        '| [A] $_groovinHighA '
        '| [C] F7 | F7 | Fm7 | Bb7 | Fm7 | Abm7 Db7 | Eb6 | Fm7 Bb7 |',
  ),
  Tune.fromChart(
    title: 'Ornithology',
    composer: 'Charlie Parker & Benny Harris',
    year: 1946,
    key: 'G',
    description: 'Changes of "How High the Moon"',
    tags: {Genre.bebop},
    defaultTempo: 210,
    chart:
        '| [A] $_ornithologyA '
        '| [B] Eb7 | Aø7 D7b9 | GΔ7 | Aø7 D7b9 | Bm7 | Em7 | Am7 | D7 '
        '| [A] $_ornithologyA '
        '| [C] Eb7 | Aø7 D7b9 | GΔ7 | Am7 D7 | Bm7 E7 | Am7 D7 | G6 '
        '| Am7 D7 |',
  ),
  Tune.fromChart(
    title: 'Yardbird Suite',
    composer: 'Charlie Parker',
    year: 1946,
    key: 'C',
    tags: {Genre.bebop},
    defaultTempo: 170,
    chart:
        '| [A] $_yardbirdA | Em7 A7 | Dm7 G7 '
        '| [A] $_yardbirdA | C6 | F#ø7 B7b9 '
        '| [B] Em7 | F#ø7 B7b9 | Em7 | A7 | Dm7 | Eø7 A7 | D7 | Dm7 G7 '
        '| [A] $_yardbirdA | C6 | Dm7 G7 |',
  ),
  // ── Blues ──
  Tune.fromChart(
    title: "Billie's Bounce",
    composer: 'Charlie Parker',
    year: 1945,
    key: 'F',
    description: 'Jazz blues',
    tags: {Genre.bebop, Genre.blues},
    defaultTempo: 170,
    chart: _jazzBluesF,
  ),
  Tune.fromChart(
    title: 'Blue Monk',
    composer: 'Thelonious Monk',
    year: 1954,
    key: 'B♭',
    description: 'Blues',
    tags: {Genre.blues},
    defaultTempo: 130,
    chart:
        '| Bb7 | Eb7 | Bb7 | Bb7 '
        '| Eb7 | Eo7 | Bb7 | Bb7 '
        '| F7 | F7 | Bb7 | Bb7 |',
  ),
  Tune.fromChart(
    title: "Bags' Groove",
    composer: 'Milt Jackson',
    year: 1952,
    key: 'F',
    description: 'Blues',
    tags: {Genre.blues},
    defaultTempo: 130,
    chart:
        '| F7 | Bb7 | F7 | F7 '
        '| Bb7 | Bb7 | F7 | Am7 D7 '
        '| Gm7 | C7 | F7 D7 | Gm7 C7 |',
  ),
  Tune.fromChart(
    title: 'Blue Train',
    composer: 'John Coltrane',
    year: 1957,
    key: 'E♭',
    description: 'Blues with a minor-ish ♯9 sound',
    tags: {Genre.blues},
    defaultTempo: 140,
    chart:
        '| Eb7#9 | Ab7 | Eb7#9 | Eb7#9 '
        '| Ab7 | Ab7 | Eb7#9 | C7 '
        '| Fm7 | Bb7 | Eb7#9 | Eb7#9 |',
  ),
  Tune.fromChart(
    title: 'Au Privave',
    composer: 'Charlie Parker',
    year: 1951,
    key: 'F',
    description: 'Jazz blues',
    tags: {Genre.bebop, Genre.blues},
    defaultTempo: 200,
    chart:
        '| F7 | Bb7 | F7 | Cm7 F7 '
        '| Bb7 | Bb7 | F7 | Aø7 D7b9 '
        '| Gm7 | C7 | F7 D7 | Gm7 C7 |',
  ),
  // ── Hard bop ──
  Tune.fromChart(
    title: "Moanin'",
    composer: 'Bobby Timmons',
    year: 1958,
    key: 'F minor',
    // The head is call and response over F minor; these are the blowing
    // changes most bands use under it and the solos.
    description: 'Hard bop, blowing changes',
    defaultTempo: 130,
    chart:
        '| [A] $_moaninA | [A] $_moaninA '
        '| [B] Bbm7 Ab7 | G7b9 C7#9 | Fm7 | F7b9 | Bbm7 Ab7 | G7b9 | Gø7 '
        '| C7#9 '
        '| [A] $_moaninA |',
  ),
  Tune.fromChart(
    title: 'Four',
    // Credited to Miles Davis; Eddie "Cleanhead" Vinson claimed it.
    composer: 'Miles Davis / Eddie Vinson',
    year: 1954,
    key: 'E♭',
    defaultTempo: 180,
    chart:
        '| [A] $_fourA | [B] $_fourB | $_fourB '
        '| [A] $_fourA | [C] $_fourB | Gm7 Gbm7 | Fm7 Bb7 | EbΔ7 '
        '| Fm7 Bb7 |',
  ),
  Tune.fromChart(
    title: 'Tune Up',
    // Credited to Miles Davis; usually attributed to Eddie Vinson.
    composer: 'Miles Davis / Eddie Vinson',
    year: 1953,
    key: 'D',
    description: 'ii–V–Is falling by whole steps',
    defaultTempo: 190,
    chart:
        '| [A] $_tuneUpA | Em7 | F7 | BbΔ7 | A7 '
        '| [A] $_tuneUpA | Em7 | A7 | DΔ7 | DΔ7 |',
  ),
  Tune.fromChart(
    title: 'Speak No Evil',
    composer: 'Wayne Shorter',
    year: 1964,
    key: 'C minor',
    description: 'AABA with 14-bar A sections',
    defaultTempo: 136,
    chart:
        '| [A] $_speakNoEvilA | [A] $_speakNoEvilA '
        '| [B] Aø7 | Ab7 | Gm7 | Gb7#11 | Fm7 | Bb7#11 | D/Eb | DbΔ7 '
        '| [A] $_speakNoEvilA |',
  ),
  Tune.fromChart(
    title: 'Inner Urge',
    composer: 'Joe Henderson',
    year: 1964,
    key: 'G',
    description: 'Lydian chords moving down, 24 bars',
    defaultTempo: 220,
    chart:
        '| [A] F#ø7 | F#ø7 | F#ø7 | F#ø7 | FΔ7 | FΔ7 | FΔ7 | FΔ7 '
        '| EbΔ7 | EbΔ7 | EbΔ7 | EbΔ7 | DbΔ7 | DbΔ7 | DbΔ7 | DbΔ7 '
        '| [B] EΔ7 | DbΔ7 | DΔ7 | BΔ7 | CΔ7 | AΔ7 | Bb7#11 | GΔ7 |',
  ),
  // ── Modal ──
  Tune.fromChart(
    title: 'Maiden Voyage',
    composer: 'Herbie Hancock',
    year: 1965,
    key: 'D',
    description: 'Sus chords',
    feel: Feel.funk,
    tags: {Genre.modal},
    defaultTempo: 116,
    chart:
        '| [A] $_maidenVoyageA | [A] $_maidenVoyageA '
        '| [B] Eb7sus4 | Eb7sus4 | Eb7sus4 | Eb7sus4 | C#m7 | C#m7 | C#m7 '
        '| C#m7 '
        '| [A] $_maidenVoyageA |',
  ),
  Tune.fromChart(
    title: 'Milestones',
    composer: 'Miles Davis',
    year: 1958,
    key: 'G Dorian',
    description: 'Modal, AABBA',
    tags: {Genre.modal},
    defaultTempo: 230,
    chart:
        '| [A] Gm7 | Gm7 | Gm7 | Gm7 | Gm7 | Gm7 | Gm7 | Gm7 '
        '| [A] Gm7 | Gm7 | Gm7 | Gm7 | Gm7 | Gm7 | Gm7 | Gm7 '
        '| [B] Am7 | Am7 | Am7 | Am7 | Am7 | Am7 | Am7 | Am7 '
        '| [B] Am7 | Am7 | Am7 | Am7 | Am7 | Am7 | Am7 | Am7 '
        '| [A] Gm7 | Gm7 | Gm7 | Gm7 | Gm7 | Gm7 | Gm7 | Gm7 |',
  ),
  Tune.fromChart(
    title: 'Little Sunflower',
    composer: 'Freddie Hubbard',
    year: 1967,
    key: 'D Dorian',
    feel: Feel.bossa,
    tags: {Genre.modal},
    defaultTempo: 116,
    chart:
        '| [A] Dm7 | Dm7 | Dm7 | Dm7 | Dm7 | Dm7 | Dm7 | Dm7 '
        '| [A] Dm7 | Dm7 | Dm7 | Dm7 | Dm7 | Dm7 | Dm7 | Dm7 '
        '| [B] EbΔ7 | EbΔ7 | EbΔ7 | EbΔ7 | DΔ7 | DΔ7 | DΔ7 | DΔ7 '
        '| [A] Dm7 | Dm7 | Dm7 | Dm7 | Dm7 | Dm7 | Dm7 | Dm7 |',
  ),
  Tune.fromChart(
    title: 'Footprints',
    composer: 'Wayne Shorter',
    year: 1966,
    key: 'C minor',
    // Written in 6/4. Here each 6/4 bar is one 4/4 bar: its two
    // dotted-half pulses become two half notes, so the 12-bar form stays.
    description: 'Minor blues shape, originally in 6/4',
    tags: {Genre.modal, Genre.blues},
    defaultTempo: 140,
    chart:
        '| Cm7 | Cm7 | Cm7 | Cm7 | Fm7 | Fm7 | Cm7 | Cm7 '
        '| F#ø7 F7#11 | E7#9 A7#9 | Cm7 | Cm7 |',
  ),
  // ── Latin ──
  Tune.fromChart(
    title: 'A Night in Tunisia',
    composer: 'Dizzy Gillespie',
    year: 1942,
    key: 'D minor',
    // The A sections are Latin and the bridge usually swings; one feel per
    // tune here, so it stays Latin. The interlude and break are left out.
    feel: Feel.bossa,
    tags: {Genre.bebop},
    defaultTempo: 170,
    chart:
        '| [A] $_tunisiaA | [A] $_tunisiaA '
        '| [B] Aø7 | D7b9 | Gm7 | Gm7 | Gø7 | C7b9 | FΔ7 | Eø7 A7b9 '
        '| [A] $_tunisiaA |',
  ),
  Tune.fromChart(
    title: 'Black Orpheus',
    composer: 'Luiz Bonfá',
    year: 1959,
    key: 'A minor',
    description: 'Manhã de Carnaval',
    feel: Feel.bossa,
    defaultTempo: 130,
    chart:
        '| [A] Am7 | Bø7 E7b9 | Am7 | Bø7 E7b9 | Am7 | Dm7 G7 | CΔ7 | A7b9 '
        '| Dm7 | G7 | CΔ7 | FΔ7 | Bø7 | E7b9 | Am7 | Bø7 E7b9 '
        '| [B] Am7 | Bø7 E7b9 | Am7 | Am7 | Eø7 | A7b9 | Dm7 | Dm7 '
        '| Dm7 Dm7/C | Bø7 E7b9 | Am7 Am7/G | FΔ7 | Bø7 | E7b9 | Am7 '
        '| Bø7 E7b9 |',
  ),
  Tune.fromChart(
    title: 'Corcovado',
    composer: 'Antônio Carlos Jobim',
    year: 1960,
    key: 'C',
    description: 'Also known as Quiet Nights of Quiet Stars',
    feel: Feel.bossa,
    defaultTempo: 110,
    chart:
        '| [A] D7/A | D7/A | Abo7 | Abo7 | Gm7 | C7 | FΔ7 | FΔ7 '
        '| [B] Fm7 | Bb7 | Em7 | A7alt | D7 | D7 | Dm7 | Abo7 '
        '| [A] D7/A | D7/A | Abo7 | Abo7 | Gm7 | C7 | FΔ7 | FΔ7 '
        '| [C] Fm7 | Bb7#11 | Em7 | Am7 | Dm7 | G7 | Em7 | A7alt | Dm7 '
        '| G7 |',
  ),
  Tune.fromChart(
    title: 'How Insensitive',
    composer: 'Antônio Carlos Jobim',
    year: 1961,
    key: 'D minor',
    description: 'Insensatez',
    feel: Feel.bossa,
    defaultTempo: 120,
    chart:
        '| [A] Dm7 | Dm7 | C#o7 | C#o7 | Cm6 | Cm6 | G7/B | G7/B '
        '| BbΔ7 | BbΔ7 | EbΔ7 | EbΔ7 | Eø7 | A7b9 | Dm7 | Dm7 Db7 '
        '| [B] Cm6 | Cm6 | Bo7 | Bo7 | BbΔ7 | Eø7 A7b9 | Dm7 | Dm7 Db7 '
        '| Cm7 | F7 | Bm7 | E7b9 | BbΔ7 | A7b9 | Dm7 | Dm7 |',
  ),
  Tune.fromChart(
    title: 'Recorda Me',
    composer: 'Joe Henderson',
    year: 1963,
    key: 'A minor',
    feel: Feel.samba,
    defaultTempo: 180,
    chart:
        '| [A] Am6 | Am6 | Am6 | Am6 | Cm6 | Cm6 | Cm6 | Cm7 F7 '
        '| [B] BbΔ7 | Bbm7 Eb7 | AbΔ7 | Abm7 Db7 | GbΔ7 | Gm7 C7 | FΔ7 '
        '| E7#9 |',
  ),
  Tune.fromChart(
    title: 'St. Thomas',
    composer: 'Sonny Rollins',
    year: 1956,
    key: 'C',
    feel: Feel.calypso,
    defaultTempo: 150,
    chart:
        '| [A] CΔ7 F7 | Em7 A7 | Dm7 G7 | C6 | CΔ7 F7 | Em7 A7 | Dm7 G7 | C6 '
        '| [B] Eø7 | A7b9 | Dm7 | G7 | CΔ7 C7/E | FΔ7 F#o7 | G7 | C6 |',
  ),
  Tune.fromChart(
    title: 'Wave',
    composer: 'Antônio Carlos Jobim',
    year: 1967,
    key: 'D',
    feel: Feel.bossa,
    defaultTempo: 120,
    chart:
        '| [A] $_waveA | [A] $_waveA '
        '| [B] Gm7 | C7 | FΔ7 | FΔ7 | Fm7 | Bb7 | EbΔ7 | A7b9 '
        '| [A] $_waveA |',
  ),
  // ── Funk and soul jazz ──
  Tune.fromChart(
    title: 'Mercy, Mercy, Mercy',
    composer: 'Joe Zawinul',
    year: 1966,
    key: 'B♭',
    description: 'Soul jazz',
    feel: Feel.funk,
    defaultTempo: 72,
    chart:
        '| [A] Bb7 | Eb7 | Bb7 | Eb7 | Bb7 | Eb7 | Bb7 | Eb7 '
        '| [B] Bb Eb/Bb | Bb7 Eb/Bb | Bb Eb/Bb | Bb7 Eb/Bb '
        '| Bb Bb/D Eb | F7sus4 | Bb Bb/D Eb | F7sus4 '
        '| Cm7 | Dm7 | Gm F Gm F | Gm |',
  ),
  Tune.fromChart(
    title: 'Red Clay',
    composer: 'Freddie Hubbard',
    year: 1970,
    key: 'C minor',
    feel: Feel.funk,
    defaultTempo: 104,
    chart:
        '| [A] Cm7 | Bbm7 | Db7sus4 Eb7sus4 | F7sus4 G7sus4 '
        '| Cm7 | Bbm7 | Db7sus4 Eb7sus4 | F7sus4 G7sus4 '
        '| [B] Cm7 | Bbm7 Eb7 | AbΔ7 | Dø7 G7alt '
        '| Cm7 | Bbm7 Eb7 | AbΔ7 | Dø7 G7alt |',
  ),
  Tune.fromChart(
    title: 'The Sidewinder',
    composer: 'Lee Morgan',
    year: 1963,
    key: 'E♭',
    description: '24-bar blues',
    feel: Feel.funk,
    tags: {Genre.blues},
    defaultTempo: 140,
    chart:
        '| Eb7 | Eb7 | Eb7 | Eb7 | Eb7 | Eb7 | Eb7 | Eb7 '
        '| Ab7 | Ab7 | Ab7 | Ab7 | Eb7 | Eb7 | Eb7 | C7b9 '
        '| Fm7 | Fm7 | Bb7 | Bb7 | Eb7 | Eb7 | Eb7 | Eb7 |',
  ),
  Tune.fromChart(
    title: 'Watermelon Man',
    composer: 'Herbie Hancock',
    year: 1962,
    key: 'F',
    description: '16-bar form',
    feel: Feel.funk,
    defaultTempo: 120,
    chart:
        '| F7 | F7 | F7 | F7 | Bb7 | Bb7 | F7 | F7 '
        '| C7 | Bb7 | C7 | Bb7 | C7 | Bb7 | F7 | F7 |',
  ),
];
