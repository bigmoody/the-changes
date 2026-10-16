// Reading iReal Pro links, so players can bring in charts they already
// have. Everything happens on the phone, from text the player pastes in;
// nothing is fetched and nothing is shared.
//
// An iReal Pro link (irealb://…, or the older irealbook://…) holds one song
// or a whole playlist, URL-encoded. Songs are separated by "===", with the
// playlist's name last; each song's fields are separated by "=":
//
//   Title=Composer==Style=Key==<music>==<comp style>=<tempo>=<repeats>
//
// The music is lightly scrambled (irealb only) and, once unscrambled, is a
// string of cells: barlines (| [ ] { } Z), time signatures (T44), section
// marks (*A), endings (N1, N2), repeat signs (x for the last bar, r for the
// last two), chords (C^7, F-7, Bb7b9/D) and a few layout marks to skip.
//
// Each song becomes a [UserProgression]: its bars as written, its sections,
// a repeated section as ×2, and 1st and 2nd endings as endings, so it opens
// in the editor looking like the chart it came from.

import 'dart:convert';

import 'meter.dart';

import 'chord.dart';
import 'tune.dart';
import 'user_progression.dart';

/// A song found in an iReal Pro link, ready to save.
class ImportedSong {
  ImportedSong({
    required this.progression,
    required this.style,
    this.notes = const [],
  });

  /// The song as one of the player's own progressions (its id is a
  /// placeholder until it's saved).
  final UserProgression progression;

  /// iReal Pro's style for it ("Medium Swing", "Bossa Nova" …).
  final String style;

  /// Anything that didn't come across exactly, to tell the player.
  final List<String> notes;
}

/// Every song in the iReal Pro links anywhere in [text]: a link on its
/// own, several, or the text of a page that has them in it.
List<ImportedSong> parseIrealPro(String text) => [
  for (final match in RegExp(r'irealb(?:ook)?://[^\s"<>]+').allMatches(text))
    ..._parseLink(match[0]!),
];

/// [text] with its percent escapes decoded, leaving a stray `%` alone.
///
/// [Uri.decodeComponent] is all or nothing: one `%` that is not an
/// escape and it throws, and the whole link was then read exactly as it
/// arrived. A link whose separators are already literal still parses
/// that way, so the songs came through with their titles untouched:
/// "Blues%20One, 100%%20proof" and a style of "Medium%20Swing". A per
/// cent sign in one song's name was enough to do it to every song in
/// the playlist.
///
/// Decoded a byte at a time so that one bad escape costs only itself,
/// and through UTF-8 so an accented title survives, its letters
/// arriving as two escapes apiece.
String decodeEscapes(String text) {
  final out = StringBuffer();
  final bytes = <int>[];
  void flush() {
    if (bytes.isEmpty) return;
    out.write(utf8.decode(bytes, allowMalformed: true));
    bytes.clear();
  }

  for (var i = 0; i < text.length;) {
    if (text[i] == '%' &&
        i + 2 < text.length &&
        _hex.hasMatch(text.substring(i + 1, i + 3))) {
      bytes.add(int.parse(text.substring(i + 1, i + 3), radix: 16));
      i += 3;
      continue;
    }
    flush();
    out.write(text[i]);
    i++;
  }
  flush();
  return out.toString();
}

final _hex = RegExp(r'^[0-9a-fA-F]{2}$');

List<ImportedSong> _parseLink(String link) {
  final scrambled = link.startsWith('irealb://');
  final body = decodeEscapes(link.substring(link.indexOf('://') + 3));
  final songs = <ImportedSong>[];
  for (final part in body.split('===')) {
    final song = _parseSong(part, scrambled: scrambled);
    if (song != null) songs.add(song);
  }
  return songs;
}

const _prefix = '1r34LbKcu7';

ImportedSong? _parseSong(String text, {required bool scrambled}) {
  final fields = text.split('=');
  // A playlist's name is a single field; a song has several.
  if (fields.length < 4) return null;
  final title = fields[0].trim();
  if (title.isEmpty) return null;

  // Find the music, then read the fields around it.
  var musicIndex = fields.indexWhere((f) => f.startsWith(_prefix));
  String music;
  if (musicIndex >= 0) {
    music = _unscramble(fields[musicIndex].substring(_prefix.length));
  } else {
    // The old format: Title=Composer=Style=Key=n=Music, as plain text.
    musicIndex = fields.lastIndexWhere((f) => f.contains('|'));
    if (musicIndex < 0) return null;
    music = fields[musicIndex];
  }
  final before = fields.sublist(1, musicIndex);
  final after = fields.sublist(musicIndex + 1);
  final keyField = before.lastWhere(
    (f) => RegExp(r'^[A-G][b#]?-?$').hasMatch(f.trim()),
    orElse: () => '',
  );
  final composer = _composer(fields[1]);
  final style = before
      .skip(1)
      .firstWhere(
        (f) => f.trim().isNotEmpty && f != keyField && f.trim() != 'n',
        orElse: () => '',
      )
      .trim();
  final tempo = after
      .map((f) => int.tryParse(f.trim()))
      .firstWhere((n) => n != null && n >= 40 && n <= 400, orElse: () => null);

  final chart = _readMusic(music);
  if (chart.bars.isEmpty) return null;

  final notes = <String>[...chart.notes];
  final feel = _feelOf(style);
  // Whatever the chart says, where the app can count it. 6/8 and 12/8
  // come over as themselves now, felt in two and in four; what is left
  // over (9/8, and anything stranger) plays in 4/4 and says so.
  final meter = Meter.parse(chart.timeSignature) ?? Meter.four;
  final progression = chart.toProgression()
    ..meter = meter
    ..title = title
    ..composer = composer
    ..tempo = tempo ?? _tempoOf(style)
    ..style = BandStyle.of(feel)
    ..tags = _tagsOf(style);
  progression.key =
      _keyOf(keyField.trim()) ?? UserProgression.guessKey(progression.bars);
  if (chart.timeSignature != '4/4' && meter == Meter.four) {
    notes.add('In ${chart.timeSignature}: plays in 4/4 for now');
  }
  return ImportedSong(progression: progression, style: style, notes: notes);
}

/// iReal Pro writes composers surname first ("Kern Jerome"): put a
/// two-part name the usual way round.
String? _composer(String field) {
  final name = field.trim();
  if (name.isEmpty || name.toLowerCase().contains('unknown')) return null;
  final words = name.split(RegExp(r'\s+'));
  return words.length == 2 ? '${words[1]} ${words[0]}' : name;
}

/// Undoes iReal Pro's scrambling: in each full 50-character block (but not
/// the very end), the first five characters swap with the last five, and
/// characters 10–23 with 26–39.
String _unscramble(String text) {
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
  return out
      .toString()
      .replaceAll('XyQ', '   ')
      .replaceAll('LZ', ' |')
      .replaceAll('Kcl', '| x');
}

/// One bar as written in the chart.
class _Bar {
  final chords = <String>[];
  String? section;
  int? ending;
  bool opensRepeat = false;
  bool closesRepeat = false;
}

class _Chart {
  final bars = <_Bar>[];
  final notes = <String>[];
  String timeSignature = '4/4';

  /// The bars as a progression: sections, a section repeated as ×2, and
  /// 1st and 2nd endings; or, where a repeat doesn't line up with a
  /// section, written out in full so it still plays right.
  UserProgression toProgression() {
    final out = UserProgression.starter(id: 'import');

    void addBar(_Bar bar, {String? section, int? ending}) {
      final index = out.bars.length;
      out.bars.add(bar.chords.join(' '));
      if (section != null) out.sections[index] = section;
      if (ending != null) out.endings[index] = ending;
    }

    var i = 0;
    while (i < bars.length) {
      final bar = bars[i];
      if (!bar.opensRepeat) {
        addBar(bar, section: bar.section);
        i++;
        continue;
      }
      // A repeat: find where it closes, and any 2nd ending after it.
      var close = i;
      while (close < bars.length - 1 && !bars[close].closesRepeat) {
        close++;
      }
      final first = [
        for (var b = i; b <= close; b++)
          if (bars[b].ending == 1) b,
      ];
      var afterRepeat = close + 1;
      final second = <int>[];
      if (first.isNotEmpty) {
        while (afterRepeat < bars.length &&
            second.length < first.length &&
            bars[afterRepeat].section == null &&
            !bars[afterRepeat].opensRepeat) {
          second.add(afterRepeat++);
        }
      }
      final section =
          bar.section ??
          (i == 0 && out.sections.isEmpty && !_hasSections ? 'A' : null);
      // It lines up with a section if it starts one and the next thing
      // after it (the 2nd ending, if any) starts another, or the end.
      final aligned =
          section != null &&
          (afterRepeat >= bars.length || bars[afterRepeat].section != null);
      if (aligned && (first.isEmpty || second.length == first.length)) {
        final start = out.bars.length;
        for (var b = i; b <= close; b++) {
          addBar(
            bars[b],
            section: b == i ? section : null,
            ending: first.contains(b) ? 1 : null,
          );
        }
        for (final b in second) {
          addBar(bars[b], ending: 2);
        }
        if (first.isEmpty) out.repeats[start] = 2;
      } else {
        // Written out: through the 1st ending, then again to the 2nd.
        for (var pass = 0; pass < 2; pass++) {
          for (var b = i; b <= close; b++) {
            if (pass == 1 && first.contains(b)) continue;
            addBar(bars[b], section: b == i ? bar.section : null);
          }
          if (pass == 1) {
            for (final b in second) {
              addBar(bars[b]);
            }
          }
        }
      }
      i = afterRepeat;
    }
    return out;
  }

  bool get _hasSections => bars.any((bar) => bar.section != null);
}

final _chordPattern = RegExp(
  r'([A-G][b#]?)([+\-^\dhob#suadlt]*)(?:/([A-G][b#]?))?',
);

_Chart _readMusic(String music) {
  final chart = _Chart();
  var bar = _Bar();
  // Whether a chord or repeat sign has been written since the last
  // barline. A stretch with nothing in it is only spacing, not a bar.
  var cells = false;
  // A two-bar repeat sign fills its own bar with the first of the two, and
  // the bar after it with the second.
  List<String>? repeatNext;
  List<String>? repeatSecond;
  String? pendingSection;
  int? pendingEnding;
  var pendingRepeat = false;
  String? lastChord;
  var truncated = false;

  void startContent() {
    if (cells) return;
    cells = true;
    bar
      ..section ??= pendingSection
      ..ending ??= pendingEnding
      ..opensRepeat |= pendingRepeat;
    pendingSection = null;
    pendingRepeat = false;
  }

  void closeBar() {
    if (!cells && bar.chords.isEmpty) {
      final second = repeatSecond;
      if (second == null) return;
      startContent();
      bar.chords.addAll(second);
    }
    repeatSecond = repeatNext;
    repeatNext = null;
    if (bar.chords.isEmpty && lastChord != null) bar.chords.add(lastChord);
    if (bar.chords.isNotEmpty) {
      if (bar.chords.length > UserProgression.maxChordsPerBar) {
        bar.chords.removeRange(
          UserProgression.maxChordsPerBar,
          bar.chords.length,
        );
        truncated = true;
      }
      chart.bars.add(bar);
    }
    bar = _Bar();
    cells = false;
  }

  var i = 0;
  while (i < music.length) {
    final c = music[i];
    switch (c) {
      case '|' || '[' || ']' || 'Z':
        closeBar();
        // A double barline ends an ending's bracket.
        if (c != '|') pendingEnding = null;
        i++;
      case '{':
        closeBar();
        pendingRepeat = true;
        pendingEnding = null;
        i++;
      case '}':
        if (cells || bar.chords.isNotEmpty) {
          bar.closesRepeat = true;
          closeBar();
        } else if (chart.bars.isNotEmpty) {
          chart.bars.last.closesRepeat = true;
        }
        pendingEnding = null;
        i++;
      case 'T' when i + 2 < music.length:
        final top = music[i + 1];
        final bottom = music[i + 2];
        final signature = switch ('$top$bottom') {
          '12' => '12/8',
          _ => '$top/$bottom',
        };
        if (chart.bars.isEmpty) chart.timeSignature = signature;
        i += 3;
      case '*' when i + 1 < music.length:
        final mark = music[i + 1];
        pendingSection = switch (mark) {
          'i' => 'Intro',
          'V' => 'Verse',
          _ => mark.toUpperCase(),
        };
        if (cells) {
          // Written mid-bar: it belongs to this bar.
          bar.section ??= pendingSection;
          pendingSection = null;
        }
        i += 2;
      case 'N' when i + 1 < music.length:
        final number = int.tryParse(music[i + 1]);
        pendingEnding = number == 1 || number == 2 ? number : null;
        if (cells) bar.ending ??= pendingEnding;
        i += 2;
      case '<':
        // A comment ("D.C. al Coda", "Fine"): skipped.
        final end = music.indexOf('>', i);
        i = end < 0 ? music.length : end + 1;
      case '(':
        // An alternative chord, written small above: skipped.
        final end = music.indexOf(')', i);
        i = end < 0 ? music.length : end + 1;
      case 'x':
        // The bar before, again.
        startContent();
        if (chart.bars.isNotEmpty) {
          bar.chords.addAll(chart.bars.last.chords);
        }
        i++;
      case 'r':
        // The two bars before, again: the sign spans this bar and the next.
        if (chart.bars.length >= 2) {
          final repeated = chart.bars.sublist(chart.bars.length - 2);
          startContent();
          bar.chords.addAll(repeated[0].chords);
          repeatNext = repeated[1].chords;
        }
        i++;
      case 'n':
        // No chord: the last one is held.
        startContent();
        i++;
      case 'W':
        // An invisible chord: the last one again, perhaps over a new bass.
        final match = RegExp(r'W(?:/([A-G][b#]?))?').matchAsPrefix(music, i)!;
        final held = lastChord;
        if (held != null) {
          startContent();
          final bass = match[1];
          bar.chords.add(
            bass == null ? held : '${held.split('/').first}/$bass',
          );
        }
        i = match.end;
      default:
        final match = _chordPattern.matchAsPrefix(music, i);
        if (match != null) {
          startContent();
          final symbol = _symbolFor(match[1]!, match[2]!, match[3]);
          bar.chords.add(symbol);
          lastChord = symbol;
          i = match.end;
        } else {
          // Spacing and layout marks (spaces, s, l, p, f, S, Q, U, Y,
          // commas): skipped.
          i++;
        }
    }
  }
  closeBar();
  if (truncated) {
    chart.notes.add('A bar had more than four chords: the first four kept');
  }
  return chart;
}

/// iReal Pro's chord qualities that this app writes differently, or knows
/// by a near relation.
const _qualities = {
  '^': '^7',
  'h': 'h7',
  '-7b5': 'h7',
  'h9': 'h7',
  'o^7': 'o7',
  '-11': 'm9',
  '-^9': 'm^7',
  '-69': 'm6',
  '-b6': 'm',
  '-#5': 'm',
  '^7#11': '^7',
  '^#11': '^7',
  '^9#11': '^9',
  '^13': '^9',
  '^7#5': '+',
  '^#5': '+',
  '7b5': '7#11',
  '9#11': '7#11',
  '13#11': '7#11',
  '7b13': '7',
  '9b13': '9',
  '13b9': '7b9',
  '7b9b13': '7b9',
  '7b9#11': '7b9',
  '7#9#11': '7#9',
  '7b9#5': '7alt',
  '7#9#5': '7alt',
  '7b9b5': '7alt',
  '7#9b5': '7alt',
  '7#5#9': '7alt',
  '9#5': '+7',
  '9b5': '7alt',
  '7b9sus': '7sus4',
  '9sus': '7sus4',
  '13sus': '7sus4',
  '7susadd3': '7sus4',
  '11': '7sus4',
  '2': '',
  'add9': '',
  '5': '',
};

/// The chord as this app writes it: iReal Pro's own symbol if the app
/// knows it, else the nearest it does (a D7♭9♯5 is played as D7alt).
String _symbolFor(String root, String quality, String? bass) {
  final slash = bass == null ? '' : '/$bass';
  bool known(String q) {
    try {
      Chord.parse('$root$q$slash');
      return true;
    } on FormatException {
      return false;
    }
  }

  if (known(quality)) return '$root$quality$slash';
  final mapped = _qualities[quality];
  if (mapped != null && known(mapped)) return '$root$mapped$slash';
  // Drop alterations from the end until it's a chord the app knows.
  for (var length = quality.length - 1; length > 0; length--) {
    final shorter = quality.substring(0, length);
    if (known(shorter)) return '$root$shorter$slash';
  }
  return quality.startsWith('-') ? '${root}m$slash' : '$root$slash';
}

/// iReal Pro's key ("Eb", "F#-") as one of the app's keys.
String? _keyOf(String field) {
  final match = RegExp(r'^([A-G])([b#]?)(-?)$').firstMatch(field);
  if (match == null) return null;
  final root =
      match[1]! +
      (match[2] == 'b'
          ? '♭'
          : match[2] == '#'
          ? '♯'
          : '');
  final minor = match[3] == '-';
  final wanted = minor ? '$root minor' : root;
  if (UserProgression.keys.contains(wanted)) return wanted;
  final pitch = pitchClassOf(parseNoteName(root)!);
  return UserProgression.keys
      .where(
        (key) =>
            key.endsWith('minor') == minor &&
            pitchClassOf(parseNoteName(key.split(' ').first)!) == pitch,
      )
      .firstOrNull;
}

Feel _feelOf(String style) {
  final s = style.toLowerCase();
  bool any(List<String> words) => words.any(s.contains);
  if (any(['calypso', 'soca', 'reggae', 'ska'])) return Feel.calypso;
  // Before the Latin names, so an Afro waltz is still played in three.
  if (any(['waltz', '3/4'])) return Feel.jazzWaltz;
  if (any(['second line', 'new orleans', 'dixieland', 'trad'])) {
    return Feel.secondLine;
  }
  if (any(['gypsy', 'manouche', 'django'])) return Feel.gypsy;
  if (any([
    'bossa', 'latin', 'samba', 'afro', 'cuban', 'mambo', 'cha', 'rhumba', //
    'rumba', 'bolero', 'salsa', 'montuno', 'songo', 'tango', 'baiao',
  ])) {
    return Feel.bossa;
  }
  if (any([
    'funk', 'rock', 'pop', 'soul', 'r&b', 'rnb', 'even 8', 'hip hop', //
    'disco', 'fusion', 'groove', 'gospel', 'blues rock',
  ])) {
    return Feel.funk;
  }
  // Last, so that a Latin or even-eighths ballad keeps its own groove
  // and only a swung one comes here.
  if (any(['ballad', 'slow swing'])) return Feel.ballad;
  return Feel.swing;
}

Set<Genre> _tagsOf(String style) {
  final s = style.toLowerCase();
  return {
    if (s.contains('ballad')) Genre.ballad,
    if (s.contains('bebop')) Genre.bebop,
    if (s.contains('blues')) Genre.blues,
  };
}

int _tempoOf(String style) {
  final s = style.toLowerCase();
  if (s.contains('ballad')) return 70;
  if (s.contains('up tempo') || s.contains('bebop')) return 220;
  if (s.contains('medium up')) return 180;
  if (s.contains('slow')) return 90;
  if (s.contains('funk') || s.contains('soul')) return 100;
  if (s.contains('bossa') || s.contains('latin') || s.contains('samba')) {
    return 140;
  }
  return 140;
}
