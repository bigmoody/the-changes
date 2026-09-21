// The records, because that is how this music is actually passed on.
//
// Every other page in Learn is about what is written down. This one is
// about the thing that is not: jazz repertoire travels on recordings,
// not on paper, and a chart is a reminder of a performance rather than
// the work itself. You can read Autumn Leaves off a page and play every
// chord correctly and still have no idea what the tune is, because what
// the tune is lives in a version of it.
//
// So a chart on its own is half a job. Learn the changes here, then go
// and hear somebody mean them.
//
// What is stored is fact and nothing else: who played it, what it came
// out on, and when. No lyrics, no melodies, no transcriptions, nothing
// lifted from anybody's work. A discography is a card index, and this is
// a short one.
//
// Every tune named here has a chart in this app, which is checked rather
// than trusted: naming a tune the library has not got would make the
// cross-reference a lie. It is also how the list stays honest about what
// it is, which is somewhere to start and not a discography.
//
// The early sides are attributed to a player and a stretch of years
// rather than an album, because in the seventy-eights era there was no
// album to name and pretending otherwise would be worse than saying
// less.

/// A record worth knowing, and the tunes on it that this app has charts
/// for.
///
/// [album] is null where the music predates albums: then it is a player
/// and the years they cut those sides.
typedef Listening = ({
  String artist,
  String? album,
  String year,
  String about,
  List<String> tunes,
});

/// The records, oldest first, so reading down them is also the story of
/// how the music got from one place to the next.
const listening = <Listening>[
  (
    artist: 'Duke Ellington',
    album: null,
    year: '1932–53',
    about:
        'The band everybody else was measured against. Listen for what '
        'the ensemble does that a chart cannot write down, which is most '
        'of why these tunes sound like themselves.',
    tunes: [
      'It Don\'t Mean a Thing',
      'Caravan',
      'Cotton Tail',
      'Take the "A" Train',
      'In a Mellow Tone',
      'Perdido',
      'Satin Doll',
    ],
  ),
  (
    artist: 'Count Basie',
    album: null,
    year: '1937–39',
    about:
        'Where a rhythm section stopped being four people playing '
        'together and became one instrument. Also the clearest lesson in '
        'leaving space that exists.',
    tunes: [
      'One O\'Clock Jump',
      'Jumpin\' at the Woodside',
      'Sent for You Yesterday',
      'Lester Leaps In',
    ],
  ),
  (
    artist: 'Coleman Hawkins',
    album: null,
    year: '1939',
    about:
        'Three minutes that made the tenor saxophone a solo instrument, '
        'and the record people mean when they say a solo can be about '
        'the changes rather than the melody.',
    tunes: ['Body and Soul'],
  ),
  (
    artist: 'Dizzy Gillespie',
    album: null,
    year: '1945–47',
    about:
        'Bebop arriving, and then Afro-Cuban music arriving with it. '
        'Fast, and meant to be.',
    tunes: [
      'Salt Peanuts',
      'Groovin\' High',
      'Shaw \'Nuff',
      'A Night in Tunisia',
      'Woody\'n You',
      'Manteca',
    ],
  ),
  (
    artist: 'Charlie Parker',
    album: null,
    year: '1945–51',
    about:
        'The sides the rest of it comes from. Most of the bebop heads in '
        'this app are his, and hearing him play them is the difference '
        'between knowing the notes and knowing the tune.',
    tunes: [
      'Ko-Ko',
      'Billie\'s Bounce',
      'Now\'s the Time',
      'Ornithology',
      'Yardbird Suite',
      'Moose the Mooche',
      'Donna Lee',
      'Scrapple from the Apple',
      'Confirmation',
      'Au Privave',
      'Blues for Alice',
    ],
  ),
  (
    artist: 'Thelonious Monk',
    album: null,
    year: '1947–58',
    about:
        'Tunes nobody else would have written, played as though they '
        'were the obvious thing to do. The space between the notes is '
        'the point, not a shortage of technique.',
    tunes: [
      'Well You Needn\'t',
      'Misterioso',
      'Blue Monk',
      'Hackensack',
      'Rhythm-a-Ning',
    ],
  ),
  (
    artist: 'Clifford Brown and Max Roach',
    album: 'Clifford Brown and Max Roach',
    year: '1955',
    about:
        'Bebop with a warmth people forget it could have. Brown never '
        'plays a note he has not meant.',
    tunes: ['Joy Spring'],
  ),
  (
    artist: 'Sonny Rollins',
    album: 'Saxophone Colossus',
    year: '1956',
    about:
        'The one to put on if somebody asks what a jazz solo is. Blue '
        'Seven builds a whole improvisation out of almost nothing.',
    tunes: ['St. Thomas', 'Blue Seven'],
  ),
  (
    artist: 'Sonny Rollins',
    album: 'Tenor Madness',
    year: '1956',
    about:
        'The only studio meeting between Rollins and Coltrane, on a '
        'blues, at length. Two ways of thinking about the same twelve '
        'bars, back to back.',
    tunes: ['Tenor Madness'],
  ),
  (
    artist: 'Miles Davis',
    album: 'Walkin\'',
    year: '1957',
    about:
        'Usually called the record where hard bop starts. After the '
        'cool, a band playing loud and blues-shaped again.',
    tunes: ['Walkin\'', 'Blue \'n Boogie', 'Solar'],
  ),
  (
    artist: 'Miles Davis',
    album: 'Bags\' Groove',
    year: '1957',
    about:
        'The Christmas Eve session, with Monk comping behind Miles and '
        'both of them plainly having opinions about it.',
    tunes: ['Bags\' Groove', 'Oleo', 'Doxy', 'But Not for Me'],
  ),
  (
    artist: 'Miles Davis',
    album: '\'Round About Midnight',
    year: '1957',
    about:
        'The first great quintet, with Coltrane. The ballad playing is '
        'the thing: nothing hurried, nothing wasted.',
    tunes: ['Bye Bye Blackbird', 'Ah-Leu-Cha'],
  ),
  (
    artist: 'Sonny Rollins',
    album: 'A Night at the Village Vanguard',
    year: '1958',
    about:
        'Saxophone, bass and drums, with nothing to hide behind. If you '
        'want to hear somebody keep a form without a chord instrument '
        'telling them where it is, it is this.',
    tunes: ['A Night in Tunisia', 'Softly, as in a Morning Sunrise'],
  ),
  (
    artist: 'John Coltrane',
    album: 'Blue Train',
    year: '1958',
    about:
        'Coltrane before the famous part, writing hard bop as well as '
        'anybody did, and the best blues head of the lot.',
    tunes: ['Blue Train'],
  ),
  (
    artist: 'Cannonball Adderley',
    album: 'Somethin\' Else',
    year: '1958',
    about:
        'Cannonball\'s date with Miles on it, which is why it sounds like '
        'a Miles record. The Autumn Leaves is the version everybody has '
        'in their head.',
    tunes: ['Autumn Leaves'],
  ),
  (
    artist: 'Miles Davis',
    album: 'Milestones',
    year: '1958',
    about:
        'The sextet, and the first sign of what was coming: the title '
        'tune sits on two scales and hardly moves.',
    tunes: ['Milestones', 'Straight, No Chaser'],
  ),
  (
    artist: 'Horace Silver',
    album: 'Blowin\' the Blues Away',
    year: '1959',
    about:
        'Silver writing tunes that are catchy on purpose and hard '
        'underneath, which is a rarer combination than it sounds.',
    tunes: ['Sister Sadie'],
  ),
  (
    artist: 'Art Blakey and the Jazz Messengers',
    album: 'Moanin\'',
    year: '1959',
    about:
        'Hard bop at its most direct, and a drummer who pushes from '
        'behind rather than waiting to be asked.',
    tunes: ['Moanin\'', 'Blues March'],
  ),
  (
    artist: 'Miles Davis',
    album: 'Kind of Blue',
    year: '1959',
    about:
        'The one everybody owns, and it earns it. Four of its five tunes '
        'have charts here, and the whole modal idea starts on it.',
    tunes: ['So What', 'Freddie Freeloader', 'Blue in Green', 'All Blues'],
  ),
  (
    artist: 'Dave Brubeck',
    album: 'Time Out',
    year: '1959',
    about:
        'A record made entirely out of time signatures nobody was using, '
        'which somehow became the best selling jazz album there was.',
    tunes: ['Take Five'],
  ),
  (
    artist: 'John Coltrane',
    album: 'Giant Steps',
    year: '1960',
    about:
        'The harmonic deep end. Learn Cousin Mary and Mr. P.C. off it '
        'long before you go anywhere near the title tune.',
    tunes: ['Giant Steps', 'Cousin Mary', 'Countdown', 'Mr. P.C.'],
  ),
  (
    artist: 'Bill Evans',
    album: 'Portrait in Jazz',
    year: '1960',
    about:
        'The trio where nobody is accompanying anybody. Worth it for '
        'LaFaro\'s bass alone, which stopped being a walking part and '
        'became a third voice.',
    tunes: [
      'Autumn Leaves',
      'What Is This Thing Called Love',
      'Someday My Prince Will Come',
    ],
  ),
  (
    artist: 'John Coltrane',
    album: 'My Favorite Things',
    year: '1961',
    about:
        'A waltz from a musical turned into fourteen minutes on two '
        'chords, which is as clear a demonstration of modal playing as '
        'there is.',
    tunes: ['My Favorite Things'],
  ),
  (
    artist: 'Joe Henderson',
    album: 'Page One',
    year: '1963',
    about:
        'Two tunes off this are on every jam session list in the world, '
        'and this is where they came from.',
    tunes: ['Blue Bossa', 'Recorda Me'],
  ),
  (
    artist: 'John Coltrane',
    album: 'Impressions',
    year: '1963',
    about:
        'The title tune is So What with a new melody and a great deal '
        'more urgency. Worth hearing the two together.',
    tunes: ['Impressions'],
  ),
  (
    artist: 'Stan Getz and João Gilberto',
    album: 'Getz/Gilberto',
    year: '1964',
    about:
        'Where bossa nova arrived for most of the world. The feel is the '
        'lesson: nothing is pushed, and it still moves.',
    tunes: ['The Girl from Ipanema', 'Corcovado'],
  ),
  (
    artist: 'Herbie Hancock',
    album: 'Empyrean Isles',
    year: '1964',
    about:
        'A quartet with no politeness in it anywhere. Cantaloupe Island '
        'is four bars of vamp and an education.',
    tunes: ['Cantaloupe Island'],
  ),
  (
    artist: 'Lee Morgan',
    album: 'The Sidewinder',
    year: '1964',
    about:
        'The boogaloo record that paid for a lot of other Blue Note '
        'albums. A twenty-four bar blues that will not leave you alone.',
    tunes: ['The Sidewinder'],
  ),
  (
    artist: 'Herbie Hancock',
    album: 'Maiden Voyage',
    year: '1965',
    about:
        'Suspended chords held long enough to live in, and the template '
        'for a great deal of what came after it.',
    tunes: ['Maiden Voyage'],
  ),
  (
    artist: 'Horace Silver',
    album: 'Song for My Father',
    year: '1965',
    about:
        'A bossa bass line, a hard bop band, and a tune that has been '
        'borrowed more often than anybody admits.',
    tunes: ['Song for My Father'],
  ),
  (
    artist: 'Wayne Shorter',
    album: 'Speak No Evil',
    year: '1966',
    about:
        'Harmony that does not resolve where you expect, with melodies '
        'that make it sound inevitable anyway.',
    tunes: ['Speak No Evil'],
  ),
  (
    artist: 'Joe Henderson',
    album: 'Inner Urge',
    year: '1966',
    about:
        'Henderson with Coltrane\'s rhythm section, on tunes that move '
        'in ways hard bop did not.',
    tunes: ['Inner Urge', 'Night and Day'],
  ),
  (
    artist: 'Freddie Hubbard',
    album: 'Backlash',
    year: '1967',
    about:
        'Hubbard at his most singing. Little Sunflower is one chord for '
        'a long time and never dull.',
    tunes: ['Little Sunflower'],
  ),
  (
    artist: 'Miles Davis',
    album: 'Miles Smiles',
    year: '1967',
    about:
        'The second quintet playing standards-shaped tunes as though the '
        'bar lines were a suggestion. The furthest this app\'s '
        'repertoire goes.',
    tunes: ['Footprints', 'Freedom Jazz Dance'],
  ),
  (
    artist: 'Herbie Hancock',
    album: 'Head Hunters',
    year: '1973',
    about:
        'Jazz with a rhythm section borrowed from funk, and the record '
        'that made a lot of people very cross at the time.',
    tunes: ['Chameleon', 'Watermelon Man'],
  ),
];

/// Every tune named across all the records.
Set<String> get tunesListened => {
  for (final record in listening) ...record.tunes,
};

/// How a record is written on one line: "Miles Davis, Kind of Blue
/// (1959)", or "Charlie Parker, 1945–51" where there was no album.
String titleOf(Listening record) => record.album == null
    ? '${record.artist}, ${record.year}'
    : '${record.artist}, ${record.album} (${record.year})';
