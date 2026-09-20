// Standards from the swing era and the traditional repertoire: Basie's book,
// the Goodman small groups, the gypsy-jazz tunes, New Orleans staples and the
// riff blues everyone called at a dance. See tune_library.dart for what these
// charts contain (chord changes, form and titles only) and why.

import '../tune.dart';

const _jazzBluesF =
    '| F7 | Bb7 | F7 | Cm7 F7 '
    '| Bb7 | Bo7 | F7 | Am7 D7 '
    '| Gm7 | C7 | F7 D7 | Gm7 C7 |';

// Blowing changes shared by several tunes: each head is its own melody, but
// players solo over the same chords.
const _jazzBluesC =
    '| C7 | F7 | C7 | Gm7 C7 '
    '| F7 | F#o7 | C7 | Em7 A7 '
    '| Dm7 | G7 | C7 A7 | Dm7 G7 |';
const _riffBluesBb =
    '| Bb7 | Eb7 | Bb7 | Bb7 '
    '| Eb7 | Eb7 | Bb7 | Bb7 '
    '| F7 | Eb7 | Bb7 | F7 |';
// The plainer I–IV–V blues the riff bands played, with no ii–V turnaround.

// Sections repeated within a tune.
const _roseRoomA = 'Bbm7 | Eb7 | AbΔ7 | AbΔ7 | Ebm7 | Ab7 | DbΔ7 | DbΔ7';
const _motenA = 'Ab6 | Fm7 | Bbm7 | Eb7 | Ab6 | Fm7 | Bbm7 Eb7';
const _savoyA = 'Db6 | Ebm7 Ab7 | Db6 | Ebm7 Ab7 | Db6 Db7 | Gb6 | Db6 Bbm7';
const _limehouseA = 'Bb7 | Bb7 | Bb7 | Bb7 | Eb7 | Eb7 | Ab6 | Ab6';
const _jadaTurn = 'C6 | A7 | Dm7 | G7';
const _minorSwingA = 'Am6 | Am6 | Dm6 | Dm6 | Am6 | Am6 | E7 | E7';

final standardsBatch10 = <Tune>[
  Tune.fromChart(
    title: 'After Hours',
    composer: 'Avery Parrish',
    year: 1940,
    key: 'C',
    description: 'Slow blues',
    tags: {Genre.blues},
    defaultTempo: 60,
    chart: _jazzBluesC,
  ),
  Tune.fromChart(
    title: 'Basin Street Blues',
    composer: 'Spencer Williams',
    year: 1928,
    key: 'B♭',
    description: 'New Orleans, 16 bars',
    defaultTempo: 96,
    chart:
        '| Bb6 | Bo7 | Cm7 | F7 | Bb6 | Bb6 | Cm7 | F7 '
        '| Bb7 | Bb7 | Eb6 | Ebm6 | Bb6 | G7 | Cm7 F7 | Bb6 |',
  ),
  Tune.fromChart(
    title: 'Centerpiece',
    composer: 'Harry "Sweets" Edison',
    year: 1958,
    key: 'C',
    description: 'Jazz blues',
    tags: {Genre.blues},
    defaultTempo: 120,
    chart: _jazzBluesC,
  ),
  Tune.fromChart(
    title: 'Dark Eyes',
    composer: 'Traditional',
    key: 'D minor',
    description: 'Gypsy jazz, 16 bars',
    defaultTempo: 200,
    chart:
        '| Dm | Dm | A7 | A7 | A7 | A7 | Dm | Dm '
        '| D7 | D7 | Gm | Gm | Dm | A7 | Dm | Dm |',
  ),
  Tune.fromChart(
    title: 'In the Mood',
    composer: 'Joe Garland',
    year: 1939,
    key: 'A♭',
    description: 'Riff blues',
    tags: {Genre.blues},
    defaultTempo: 170,
    chart:
        '| Ab7 | Ab7 | Ab7 | Ab7 | Db7 | Db7 | Ab7 | Ab7 '
        '| Eb7 | Db7 | Ab7 | Eb7 |',
  ),
  Tune.fromChart(
    title: 'Ja-Da',
    composer: 'Bob Carleton',
    year: 1918,
    key: 'C',
    description: 'Dixieland, two 8-bar strains',
    defaultTempo: 180,
    chart:
        '| [A] $_jadaTurn | $_jadaTurn '
        '| [B] C7 | C7 | F6 | F6 | C6 | A7 | Dm7 G7 | C6 |',
  ),
  Tune.fromChart(
    title: 'Just a Closer Walk with Thee',
    composer: 'Traditional',
    key: 'F',
    description: 'New Orleans, 16 bars',
    defaultTempo: 92,
    chart:
        '| F6 | F6 | F6 | F6 | C7 | C7 | C7 | C7 '
        '| F6 | F7 | Bb6 | Bbm6 | F6 | C7 | F6 | F6 |',
  ),
  Tune.fromChart(
    title: 'Limehouse Blues',
    composer: 'Philip Braham',
    year: 1922,
    key: 'A♭',
    description: 'Gypsy jazz',
    defaultTempo: 220,
    chart:
        '| [A] $_limehouseA '
        '| [A] $_limehouseA '
        '| [B] Db6 | Db6 | Db6 | Db6 | Ab6 | Ab6 | Bb7 | Eb7 '
        '| [A] $_limehouseA |',
  ),
  Tune.fromChart(
    title: 'Minor Swing',
    composer: 'Django Reinhardt & Stéphane Grappelli',
    year: 1937,
    key: 'A minor',
    description: 'Gypsy jazz, 16 bars',
    defaultTempo: 210,
    chart:
        '| $_minorSwingA '
        '| Am6 | Am6 | Dm6 | Dm6 | Am6 | E7 | Am6 | E7 |',
  ),
  Tune.fromChart(
    title: 'Moten Swing',
    composer: 'Bennie Moten & Buster Moten',
    year: 1932,
    key: 'A♭',
    defaultTempo: 170,
    chart:
        '| [A] $_motenA | Ab6 '
        '| [A] $_motenA | Ab6 '
        '| [B] C7 | C7 | F7 | F7 | Bb7 | Bb7 | Eb7 | Eb7 '
        '| [A] $_motenA | Ab6 |',
  ),
  Tune.fromChart(
    title: 'Rose Room',
    composer: 'Art Hickman',
    year: 1917,
    key: 'A♭',
    defaultTempo: 160,
    chart:
        '| [A] $_roseRoomA '
        '| [B] Dbm7 | Gb7 | AbΔ7 | F7 | Bb7 | Bb7 | Bbm7 | Eb7 '
        '| [A] $_roseRoomA '
        '| [C] DbΔ7 | Dbm7 Gb7 | AbΔ7 | F7 | Bbm7 | Eb7 | Ab6 | Bbm7 Eb7 |',
  ),
  Tune.fromChart(
    title: 'Route 66',
    composer: 'Bobby Troup',
    year: 1946,
    key: 'F',
    description: 'Jazz blues',
    tags: {Genre.blues},
    defaultTempo: 150,
    chart: _jazzBluesF,
  ),
  Tune.fromChart(
    title: 'Sent for You Yesterday',
    composer: 'Count Basie, Eddie Durham & Jimmy Rushing',
    year: 1938,
    key: 'B♭',
    description: 'Riff blues',
    tags: {Genre.blues},
    defaultTempo: 120,
    chart: _riffBluesBb,
  ),
  Tune.fromChart(
    title: 'Soft Winds',
    composer: 'Benny Goodman',
    year: 1940,
    key: 'F',
    description: 'Jazz blues',
    tags: {Genre.blues},
    defaultTempo: 140,
    chart: _jazzBluesF,
  ),
  Tune.fromChart(
    title: 'St. James Infirmary',
    composer: 'Traditional',
    key: 'D minor',
    description: 'New Orleans, 8 bars',
    defaultTempo: 80,
    chart: '| Dm | A7 | Dm | D7 | Gm | Dm | A7 | Dm |',
  ),
  Tune.fromChart(
    title: 'St. Louis Blues',
    composer: 'W. C. Handy',
    year: 1914,
    key: 'G',
    description: 'Blues strain, minor strain, blues strain',
    tags: {Genre.blues},
    defaultTempo: 140,
    chart:
        '| [A] G7 | G7 | G7 | G7 | C7 | C7 | G7 | G7 '
        '| D7 | C7 | G7 | D7 '
        '| [B] Gm | Gm | Gm | Gm | D7 | D7 | Gm | Gm '
        '| Gm | Gm | Gm | Gm | D7 | D7 | G7 | G7 '
        '| [A] G7 | G7 | G7 | G7 | C7 | C7 | G7 | G7 '
        '| D7 | C7 | G7 | D7 |',
  ),
  Tune.fromChart(
    title: "Stompin' at the Savoy",
    composer: 'Edgar Sampson',
    year: 1934,
    key: 'D♭',
    defaultTempo: 180,
    chart:
        '| [A] $_savoyA | Ebm7 Ab7 '
        '| [A] $_savoyA | Ebm7 Ab7 '
        '| [B] Gb6 | Gb6 | Gb6 | Gb6 | Ab7 | Ab7 | Ab7 | Ab7 '
        '| [A] $_savoyA | Db6 |',
  ),
  Tune.fromChart(
    title: 'Tin Roof Blues',
    composer: 'New Orleans Rhythm Kings',
    year: 1923,
    key: 'B♭',
    description: 'New Orleans blues',
    tags: {Genre.blues},
    defaultTempo: 92,
    chart: _riffBluesBb,
  ),
  Tune.fromChart(
    title: 'When the Saints Go Marching In',
    composer: 'Traditional',
    key: 'F',
    description: 'New Orleans, 16 bars',
    defaultTempo: 190,
    chart:
        '| F6 | F6 | F6 | F6 | C7 | C7 | C7 | C7 '
        '| F6 | F6 | F7 | Bb6 | F6 | C7 | F6 | F6 |',
  ),
];
