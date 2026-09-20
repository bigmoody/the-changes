// Writing iReal Pro links, so a chart written here can be opened in iReal
// Pro or passed to another player. This is the mirror of ireal_import.dart,
// and the two are tested against each other by writing a progression out
// and reading it straight back in.
//
// A song is its fields separated by "=", with the music in the middle:
//
//   Title=Composer==Style=Key==1r34LbKcu7<music>==<comp style>=<tempo>=3
//
// Several songs join with "===" and the playlist's name goes last; the
// whole thing is URL-encoded after "irealb://".
//
// The music is the chart as cells — an opening barline, a time signature,
// section marks, repeats, endings, chords and barlines, ending with Z.
// iReal Pro scrambles it by swapping characters about within each
// 50-character block, which undoes itself, so the same swapping writes it.
// It also shortens three common runs when it reads a chart ("XyQ" for three
// spaces, "LZ" for " |", "Kcl" for "| x"); those change the length, and so
// would throw the blocks out. Nothing written here uses the abbreviations
// or happens to contain those sequences — X, y, Q, L and K are never
// written — so swapping alone is enough.

import 'chord.dart';
import 'tune.dart';
import 'user_progression.dart';

/// [progression] as an iReal Pro link.
///
/// Almost everything survives the trip back: the bars, the sections, a
/// section played twice, 1st and 2nd endings, the key, the tempo, the time
/// signature, the title and the composer. What iReal Pro has no room for
/// does not: a section played three or four times comes back as twice, a
/// band with its instruments mixed by hand comes back playing the one feel,
/// and chords are written in iReal Pro's spelling, so a Dm7 comes home as
/// D-7 — the same chord, spelled its way.
String irealLinkFor(UserProgression progression) =>
    'irealb://${Uri.encodeComponent(_song(progression))}';

/// [progression]s as one iReal Pro playlist called [playlistName], which is
/// how iReal Pro itself shares a set of tunes.
String irealPlaylistLink(
  List<UserProgression> progressions,
  String playlistName,
) {
  final body = [
    for (final progression in progressions) _song(progression),
    _plain(playlistName),
  ].join('===');
  return 'irealb://${Uri.encodeComponent(body)}';
}

const _prefix = '1r34LbKcu7';

String _song(UserProgression progression) {
  final title = _plain(progression.displayTitle);
  final style = _styleFor(progression);
  return [
    title.isEmpty ? 'Untitled' : title,
    _composerField(progression.composer),
    '',
    style,
    _keyField(progression.key),
    '',
    '$_prefix${_scramble(_music(progression))}',
    '',
    // iReal Pro names the style twice: once for the chart, once for the
    // band. The last field is how many times it plays the chorus.
    style,
    '${progression.tempo}',
    '3',
  ].join('=');
}

/// A field with the separators taken out: an "=" in a title would split the
/// song into the wrong fields.
String _plain(String text) => text.replaceAll('=', ' ').trim();

/// iReal Pro writes composers surname first ("Kern Jerome"), so a two-part
/// name goes over the other way round. A longer name is left as it is,
/// because there's no telling which part is the surname. Nobody in
/// particular is "Unknown", which is iReal Pro's own way of saying so — and
/// it has to be something, since an empty composer would leave "===" in the
/// middle of the song, which is how songs are separated.
String _composerField(String? composer) {
  final name = _plain(composer ?? '');
  if (name.isEmpty) return 'Unknown';
  final words = name.split(RegExp(r'\s+'));
  return words.length == 2 ? '${words[1]} ${words[0]}' : name;
}

/// The key as iReal Pro writes it: "Eb", or "F#-" for a minor key.
String _keyField(String key) {
  final minor = key.endsWith('minor');
  return '${_ascii(key.split(' ').first)}${minor ? '-' : ''}';
}

/// One of iReal Pro's style names for the band's feel. A ballad is worth
/// naming, since iReal Pro's own style names carry that much; the other
/// genres a progression is tagged with have nowhere to go.
String _styleFor(UserProgression progression) =>
    switch (progression.style.drums) {
      Feel.swing =>
        progression.tags.contains(Genre.ballad)
            ? 'Ballad Swing'
            : 'Medium Swing',
      Feel.shuffle => 'Shuffle Blues',
      Feel.bossa => 'Bossa Nova',
      Feel.samba => 'Samba',
      Feel.funk => 'Funk',
      Feel.calypso => 'Calypso',
    };

/// The chart itself, before it's scrambled.
String _music(UserProgression progression) {
  final bars = progression.bars;
  final sections = progression.sections;
  final starts = sections.keys.where((i) => i < bars.length).toList()..sort();

  // Where the repeat signs and ending brackets go, worked out a section at
  // a time.
  final opens = <int>{};
  final closes = <int>{};
  final endings = <int, int>{};
  for (var s = 0; s < starts.length; s++) {
    final start = starts[s];
    final end = s + 1 < starts.length ? starts[s + 1] : bars.length;
    final pair = _endingsOf(progression, start, end);
    if (pair != null) {
      opens.add(start);
      closes.add(pair.firstEnd);
      endings[pair.firstStart] = 1;
      endings[pair.secondStart] = 2;
    } else if (progression.repeatsOf(start) > 1) {
      opens.add(start);
      closes.add(end - 1);
    }
  }

  final out = StringBuffer('[')..write(_meterMark(progression.beatsPerBar));
  for (var i = 0; i < bars.length; i++) {
    // A section starts behind a double barline, which also closes any
    // ending bracket still open from the section before.
    if (i > 0) out.write(sections.containsKey(i) ? ']' : '|');
    final section = sections[i];
    if (section != null) out.write('*${_sectionMark(section)}');
    if (opens.contains(i)) out.write('{');
    final ending = endings[i];
    if (ending != null) out.write('N$ending');
    out.write(_barOf(bars[i]));
    if (closes.contains(i)) out.write('}');
  }
  out.write('Z');
  return out.toString();
}

/// Where a section's 1st and 2nd endings are, if it has a pair iReal Pro
/// can write: a run of 1st-ending bars after some body, then as many
/// 2nd-ending bars running to the end of the section. Anything else — an
/// odd ending on its own, endings of different lengths, an ending in the
/// middle of a section — has no repeat sign that would play it back the
/// same way, so it's written out with no endings at all.
({int firstStart, int firstEnd, int secondStart})? _endingsOf(
  UserProgression progression,
  int start,
  int end,
) {
  List<int> marked(int ending) => [
    for (var i = start; i < end; i++)
      if (progression.endings[i] == ending) i,
  ];
  final first = marked(1);
  final second = marked(2);
  if (first.isEmpty || second.isEmpty) return null;
  if (first.length != second.length) return null;
  bool unbroken(List<int> bars) => bars.last - bars.first == bars.length - 1;
  if (!unbroken(first) || !unbroken(second)) return null;
  // The section needs bars of its own before the 1st ending, and the 2nd
  // ending has to be the last of it.
  if (first.first <= start) return null;
  if (second.first != first.last + 1 || second.last != end - 1) return null;
  return (
    firstStart: first.first,
    firstEnd: first.last,
    secondStart: second.first,
  );
}

/// iReal Pro's time signature mark. Its bar is as long as the app's, so
/// there's nothing to convert.
String _meterMark(int beats) => switch (beats) {
  2 => 'T24',
  3 => 'T34',
  5 => 'T54',
  6 => 'T64',
  7 => 'T74',
  _ => 'T44',
};

/// The letter after a section's star. iReal Pro has its own marks for an
/// intro and a verse.
String _sectionMark(String section) => switch (section) {
  'Intro' => 'i',
  'Verse' => 'V',
  _ => section.isEmpty ? 'A' : section[0].toUpperCase(),
};

/// One bar's chords. An empty bar — one still being written — becomes
/// iReal Pro's "no chord", which holds the chord before it.
String _barOf(String bar) {
  final chords = [
    for (final symbol in UserProgression.symbolsIn(bar)) _chordSymbol(symbol),
  ];
  return chords.isEmpty ? 'n' : chords.join(' ');
}

/// iReal Pro's spelling for each chord this app knows. The app takes
/// several spellings of the same chord, so this goes by what the chord is
/// rather than how it was typed: an F-7, an Fm7 and an Fmin7 all come out
/// as F-7.
const _irealQualities = {
  'Major': '',
  'Major 7th': '^7',
  'Major 6th': '6',
  'Six-nine': '69',
  'Major 9th': '^9',
  'Dominant 7th': '7',
  'Dominant 9th': '9',
  'Dominant 13th': '13',
  'Dominant 7th flat 9': '7b9',
  'Dominant 7th sharp 9': '7#9',
  'Dominant 7th sharp 11': '7#11',
  'Altered dominant': '7alt',
  'Dominant 7th suspended 4th': '7sus',
  'Suspended 4th': 'sus',
  'Minor': '-',
  'Minor 7th': '-7',
  'Minor 6th': '-6',
  'Minor 9th': '-9',
  'Minor-major 7th': '-^7',
  'Half-diminished': 'h7',
  'Diminished 7th': 'o7',
  'Diminished': 'o',
  'Augmented': '+',
  'Augmented 7th': '7#5',
};

/// One chord as iReal Pro writes it: "C^7", "D-7", "Bb7b9/D".
String _chordSymbol(String symbol) {
  final Chord chord;
  try {
    chord = Chord.parse(symbol);
  } on FormatException {
    // A bar the player is still working on: written as typed, so at least
    // it's there to see and fix.
    return _ascii(symbol);
  }
  final bassLetter = chord.bassLetter;
  final bass = bassLetter == null
      ? ''
      : '/${_ascii(noteNameOf((letter: bassLetter, accidental: chord.bassAccidental)))}';
  final quality = _irealQualities[chord.quality.name] ?? chord.qualitySymbol;
  return '${_ascii(chord.rootName)}$quality$bass';
}

/// The plain-text form iReal Pro reads: it has no sharp or flat signs, and
/// writes a triangle as "^", a half-diminished circle as "h" and a
/// diminished one as "o".
String _ascii(String text) => text
    .replaceAll('♭', 'b')
    .replaceAll('♯', '#')
    .replaceAll('Δ', '^')
    .replaceAll('ø', 'h')
    .replaceAll('°', 'o')
    .replaceAll('−', '-');

/// iReal Pro's scrambling: in each full 50-character block (but not the
/// very end), the first five characters swap with the last five, and
/// characters 10–23 with 26–39. Swapping puts a character where the one it
/// swapped with came from, so this is the same operation the importer uses
/// to read a chart back.
String _scramble(String text) {
  final out = StringBuffer();
  var rest = text;
  while (rest.length > 50) {
    final block = rest.substring(0, 50);
    rest = rest.substring(50);
    if (rest.length < 2) {
      out.write(block);
      continue;
    }
    final chars = block.split('');
    for (var i = 0; i < 5; i++) {
      chars[49 - i] = block[i];
      chars[i] = block[49 - i];
    }
    for (var i = 10; i < 24; i++) {
      chars[49 - i] = block[i];
      chars[i] = block[49 - i];
    }
    out.write(chars.join());
  }
  out.write(rest);
  return out.toString();
}
