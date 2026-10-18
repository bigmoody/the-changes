// Writing a chart as MusicXML, the format notation software reads.
//
// What goes out is a lead sheet with no melody: the chord symbols over
// the bars they are played in, the key, the time signature, the section
// letters as rehearsal marks, and the repeats and endings as the
// barlines that play them back the same way. That is the whole of what
// this app holds. There is no tune in it to write down and none goes
// out, here or anywhere else.
//
// Each bar is written as rests the length of the chords over them, so a
// bar of two chords puts the second one on beat three in Sibelius,
// MuseScore or anything else that reads the format, rather than both at
// the top of the bar.

import 'chart_form.dart';
import 'meter.dart';
import 'chord.dart';
import 'tune.dart';
import 'user_progression.dart';

/// [progression] as a MusicXML score, ready to write to a .musicxml file.
///
/// [note] is written above the first bar beside the feel: what the chart
/// is written for, when that is not concert pitch. The chords themselves
/// are already written that way, so nothing here transposes.
String musicXmlFor(UserProgression progression, {String? note}) {
  final out = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8" standalone="no"?>')
    ..writeln(
      '<!DOCTYPE score-partwise PUBLIC '
      '"-//Recordare//DTD MusicXML 4.0 Partwise//EN" '
      '"http://www.musicxml.org/dtds/partwise.dtd">',
    )
    ..writeln('<score-partwise version="4.0">')
    ..writeln('  <work>')
    ..writeln('    <work-title>${_text(progression.displayTitle)}</work-title>')
    ..writeln('  </work>')
    ..writeln('  <identification>');
  final composer = progression.composer?.trim();
  if (composer != null && composer.isNotEmpty) {
    out.writeln('    <creator type="composer">${_text(composer)}</creator>');
  }
  out
    ..writeln('    <encoding>')
    ..writeln('      <software>The Changes</software>')
    ..writeln('    </encoding>')
    ..writeln('  </identification>')
    ..writeln('  <part-list>')
    ..writeln('    <score-part id="P1">')
    ..writeln('      <part-name>Chords</part-name>')
    ..writeln('    </score-part>')
    ..writeln('  </part-list>')
    ..writeln('  <part id="P1">');
  _measures(out, progression, note);
  out
    ..writeln('  </part>')
    ..writeln('</score-partwise>');
  return out.toString();
}

/// The file name a score is saved under: the title, with anything a file
/// system would rather not see taken out.
String musicXmlFileName(UserProgression progression) =>
    '${fileNameFor(progression.displayTitle)}.musicxml';

/// [title] as a file name, without its extension.
String fileNameFor(String title) {
  final name = title
      .replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return name.isEmpty ? 'Chart' : name;
}

/// Divisions are counted per quarter note, and two of them is as fine as
/// a chart ever gets: a chord lasts a whole number of beats, and the
/// shortest beat here is the dotted quarter of a compound bar, which is
/// three of these.
const _divisions = 2;

/// How long one of the band's beats is, in divisions: a quarter note in
/// simple time, a dotted quarter in compound.
int _perPulse(Meter meter) => meter.compound ? 3 : 2;

void _measures(StringBuffer out, UserProgression progression, String? note) {
  final bars = progression.bars;
  final sections = chartForm(progression);
  final beatsPerBar = progression.beatsPerBar;

  // The barlines each bar carries, worked out from the form.
  final opensRepeat = <int>{};
  final closesRepeat = <int, int>{};
  final endingStarts = <int, int>{};
  final endingEnds = <int, int>{};
  final sectionEnds = <int>{};
  for (final section in sections) {
    final endings = section.endings;
    if (endings != null) {
      opensRepeat.add(section.start);
      closesRepeat[endings.firstEnd] = 2;
      endingStarts[endings.firstStart] = 1;
      endingEnds[endings.firstEnd] = 1;
      endingStarts[endings.secondStart] = 2;
      endingEnds[endings.secondEnd] = 2;
    } else if (section.times > 1) {
      opensRepeat.add(section.start);
      closesRepeat[section.end - 1] = section.times;
    }
    if (section.end < bars.length) sectionEnds.add(section.end - 1);
  }
  final letters = {
    for (final section in sections)
      if (section.letter != null) section.start: section.letter!,
  };

  for (var i = 0; i < bars.length; i++) {
    out.writeln('    <measure number="${i + 1}">');
    if (i == 0) _attributes(out, progression);
    // The repeat sign and the ending bracket open on the left of the bar.
    final opensEnding = endingStarts[i];
    if (opensRepeat.contains(i) || opensEnding != null) {
      out.writeln('      <barline location="left">');
      if (opensRepeat.contains(i)) {
        out.writeln('        <bar-style>heavy-light</bar-style>');
      }
      if (opensEnding != null) {
        out.writeln('        <ending number="$opensEnding" type="start"/>');
      }
      if (opensRepeat.contains(i)) {
        out.writeln('        <repeat direction="forward"/>');
      }
      out.writeln('      </barline>');
    }
    final letter = letters[i];
    if (letter != null) {
      out
        ..writeln('      <direction placement="above">')
        ..writeln('        <direction-type>')
        ..writeln('          <rehearsal>${_text(letter)}</rehearsal>')
        ..writeln('        </direction-type>')
        ..writeln('      </direction>');
    }
    if (i == 0) _tempo(out, progression, note);
    _bar(out, bars[i], beatsPerBar, progression.meter);
    // The ending bracket and the repeat sign close on the right of it, as
    // does a double barline between sections and the end of the chart.
    final closesEnding = endingEnds[i];
    final times = closesRepeat[i];
    final last = i == bars.length - 1;
    if (closesEnding != null ||
        times != null ||
        sectionEnds.contains(i) ||
        last) {
      out.writeln('      <barline location="right">');
      if (last) {
        out.writeln('        <bar-style>light-heavy</bar-style>');
      } else if (times != null) {
        out.writeln('        <bar-style>light-heavy</bar-style>');
      } else if (sectionEnds.contains(i)) {
        out.writeln('        <bar-style>light-light</bar-style>');
      }
      if (closesEnding != null) {
        // The bracket over the last ending is open at the end: nothing
        // comes back to it.
        final how = closesEnding == 1 ? 'stop' : 'discontinue';
        out.writeln('        <ending number="$closesEnding" type="$how"/>');
      }
      if (times != null) {
        out.writeln('        <repeat direction="backward" times="$times"/>');
      }
      out.writeln('      </barline>');
    }
    out.writeln('    </measure>');
  }
}

void _attributes(StringBuffer out, UserProgression progression) {
  final fifths = _fifthsOf(progression.key);
  final minor = progression.key.endsWith('minor');
  out
    ..writeln('      <attributes>')
    ..writeln('        <divisions>$_divisions</divisions>')
    ..writeln('        <key>')
    ..writeln('          <fifths>$fifths</fifths>')
    ..writeln('          <mode>${minor ? 'minor' : 'major'}</mode>')
    ..writeln('        </key>')
    ..writeln('        <time>')
    ..writeln('          <beats>${progression.meter.beats}</beats>')
    ..writeln('          <beat-type>${progression.meter.unit}</beat-type>')
    ..writeln('        </time>')
    ..writeln('        <clef>')
    ..writeln('          <sign>G</sign>')
    ..writeln('          <line>2</line>')
    ..writeln('        </clef>')
    ..writeln('      </attributes>');
}

/// The feel in words and the tempo in numbers, the way they sit at the top
/// of a lead sheet.
void _tempo(StringBuffer out, UserProgression progression, String? note) {
  out
    ..writeln('      <direction placement="above">')
    ..writeln('        <direction-type>')
    ..writeln(
      '          <words>'
      '${_text([_feelWords(progression), ?note].join(' · '))}'
      '</words>',
    )
    ..writeln('        </direction-type>')
    ..writeln('      </direction>')
    ..writeln('      <direction placement="above">')
    ..writeln('        <direction-type>')
    ..writeln('          <metronome>')
    ..writeln('            <beat-unit>quarter</beat-unit>')
    ..writeln('            <per-minute>${progression.tempo}</per-minute>')
    ..writeln('          </metronome>')
    ..writeln('        </direction-type>')
    ..writeln('        <sound tempo="${progression.tempo}"/>')
    ..writeln('      </direction>');
}

String _feelWords(UserProgression progression) {
  final feel = switch (progression.style.drums) {
    Feel.swing => 'Swing',
    Feel.shuffle => 'Shuffle',
    Feel.bossa => 'Bossa Nova',
    Feel.samba => 'Samba',
    Feel.funk => 'Funk',
    Feel.calypso => 'Calypso',
    Feel.jazzWaltz => 'Jazz Waltz',
    Feel.ballad => 'Ballad',
    Feel.secondLine => 'Second Line',
    Feel.gypsy => 'Gypsy Jazz',
    Feel.afroSix => 'Afro 6/8',
  };
  return progression.tags.contains(Genre.ballad) ? 'Ballad ($feel)' : feel;
}

/// One bar: a chord symbol over each rest, for as long as that chord is
/// played. A bar nobody has written in yet is a bar's rest on its own.
void _bar(StringBuffer out, String bar, int beatsPerBar, Meter meter) {
  final perPulse = _perPulse(meter);
  final symbols = UserProgression.symbolsIn(bar);
  if (symbols.isEmpty) {
    out
      ..writeln('      <note>')
      ..writeln('        <rest measure="yes"/>')
      ..writeln('        <duration>${beatsPerBar * perPulse}</duration>')
      ..writeln('        <voice>1</voice>')
      ..writeln('      </note>');
    return;
  }
  // The beats share out as they do everywhere else: the earlier chords
  // take the longer half of an uneven split.
  final base = beatsPerBar ~/ symbols.length;
  final leftover = beatsPerBar % symbols.length;
  for (final (i, symbol) in symbols.indexed) {
    final beats = base + (i < leftover ? 1 : 0);
    _harmony(out, symbol);
    out
      ..writeln('      <note>')
      ..writeln('        <rest/>')
      ..writeln('        <duration>${beats * perPulse}</duration>')
      ..writeln('        <voice>1</voice>')
      ..writeln('      </note>');
  }
}

void _harmony(StringBuffer out, String symbol) {
  final Chord chord;
  try {
    chord = Chord.parse(symbol);
  } on FormatException {
    // Something the app itself cannot read: written as words above the
    // bar rather than dropped, so nothing goes missing from the chart.
    out
      ..writeln('      <direction placement="above">')
      ..writeln('        <direction-type>')
      ..writeln('          <words>${_text(symbol)}</words>')
      ..writeln('        </direction-type>')
      ..writeln('      </direction>');
    return;
  }
  final kind = _kinds[chord.quality.name] ?? const (kind: 'other', text: '');
  out
    ..writeln('      <harmony>')
    ..writeln('        <root>')
    ..writeln('          <root-step>${_letterOf(chord.rootName)}</root-step>');
  if (chord.rootAccidental != 0) {
    out.writeln('          <root-alter>${chord.rootAccidental}</root-alter>');
  }
  out
    ..writeln('        </root>')
    ..writeln('        <kind text="${_text(kind.text)}">${kind.kind}</kind>');
  final bassLetter = chord.bassLetter;
  if (bassLetter != null) {
    final name = chord.display.split('/').last;
    out
      ..writeln('        <bass>')
      ..writeln('          <bass-step>${_letterOf(name)}</bass-step>');
    if (chord.bassAccidental != 0) {
      out.writeln('          <bass-alter>${chord.bassAccidental}</bass-alter>');
    }
    out.writeln('        </bass>');
  }
  for (final degree in _degrees[chord.quality.name] ?? const <_Degree>[]) {
    out
      ..writeln('        <degree>')
      ..writeln('          <degree-value>${degree.value}</degree-value>')
      ..writeln('          <degree-alter>${degree.alter}</degree-alter>')
      ..writeln('          <degree-type>${degree.type}</degree-type>')
      ..writeln('        </degree>');
  }
  out.writeln('      </harmony>');
}

/// The letter of a note name, without its accidental glyph.
String _letterOf(String name) => name.isEmpty ? 'C' : name[0].toUpperCase();

typedef _Degree = ({int value, int alter, String type});

/// MusicXML's name for each chord this app knows, and the text notation
/// software prints for it. Gone by what the chord is rather than how it
/// was typed, so an Fm7, an F-7 and an Fmin7 all come out the same.
const _kinds = <String, ({String kind, String text})>{
  'Major': (kind: 'major', text: ''),
  'Major 7th': (kind: 'major-seventh', text: 'maj7'),
  'Major 6th': (kind: 'major-sixth', text: '6'),
  'Six-nine': (kind: 'major-sixth', text: '6/9'),
  'Major 9th': (kind: 'major-ninth', text: 'maj9'),
  'Dominant 7th': (kind: 'dominant', text: '7'),
  'Dominant 9th': (kind: 'dominant-ninth', text: '9'),
  'Dominant 13th': (kind: 'dominant-13th', text: '13'),
  'Dominant 7th flat 9': (kind: 'dominant-ninth', text: '7b9'),
  'Dominant 7th sharp 9': (kind: 'dominant-ninth', text: '7#9'),
  'Dominant 7th sharp 11': (kind: 'dominant', text: '7#11'),
  'Altered dominant': (kind: 'dominant', text: '7alt'),
  'Dominant 7th suspended 4th': (kind: 'suspended-fourth', text: '7sus4'),
  'Suspended 4th': (kind: 'suspended-fourth', text: 'sus4'),
  'Minor': (kind: 'minor', text: 'm'),
  'Minor 7th': (kind: 'minor-seventh', text: 'm7'),
  'Minor 6th': (kind: 'minor-sixth', text: 'm6'),
  'Minor 9th': (kind: 'minor-ninth', text: 'm9'),
  'Minor-major 7th': (kind: 'major-minor', text: 'mMaj7'),
  'Half-diminished': (kind: 'half-diminished', text: 'm7b5'),
  'Diminished 7th': (kind: 'diminished-seventh', text: 'dim7'),
  'Diminished': (kind: 'diminished', text: 'dim'),
  'Augmented': (kind: 'augmented', text: 'aug'),
  'Augmented 7th': (kind: 'augmented-seventh', text: '7#5'),
};

/// The notes a kind on its own doesn't carry: the 9th on a six-nine, the
/// alterations on a dominant, the 7th under a 7sus4.
const _degrees = <String, List<_Degree>>{
  'Six-nine': [(value: 9, alter: 0, type: 'add')],
  'Dominant 7th flat 9': [(value: 9, alter: -1, type: 'alter')],
  'Dominant 7th sharp 9': [(value: 9, alter: 1, type: 'alter')],
  'Dominant 7th sharp 11': [(value: 11, alter: 1, type: 'add')],
  'Altered dominant': [
    (value: 9, alter: -1, type: 'add'),
    (value: 5, alter: 1, type: 'alter'),
  ],
  'Dominant 7th suspended 4th': [(value: 7, alter: -1, type: 'add')],
};

/// How many sharps (or flats, below zero) a key is written with.
int _fifthsOf(String key) {
  final tonic = key.split(' ').first;
  final minor = key.endsWith('minor');
  final table = minor ? _minorFifths : _majorFifths;
  return table[tonic] ?? 0;
}

const _majorFifths = {
  'C': 0, 'G': 1, 'D': 2, 'A': 3, 'E': 4, 'B': 5, 'F♯': 6, 'C♯': 7, //
  'F': -1, 'B♭': -2, 'E♭': -3, 'A♭': -4, 'D♭': -5, 'G♭': -6, 'C♭': -7,
};

const _minorFifths = {
  'A': 0, 'E': 1, 'B': 2, 'F♯': 3, 'C♯': 4, 'G♯': 5, 'D♯': 6, 'A♯': 7, //
  'D': -1, 'G': -2, 'C': -3, 'F': -4, 'B♭': -5, 'E♭': -6, 'A♭': -7,
};

/// Text safe to put in an XML element.
String _text(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
