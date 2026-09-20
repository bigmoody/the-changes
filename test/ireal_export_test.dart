// Writing iReal Pro links: a progression written out and read straight
// back in should be the same chart — bars, sections, repeats, endings, key,
// tempo, time signature, title and composer.

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/ireal_export.dart';
import 'package:play_along/music/ireal_import.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/user_progression.dart';

UserProgression _progression({
  required String title,
  required List<String> bars,
  String key = 'C',
  int tempo = 140,
  String? composer = 'Thelonious Monk',
  int beatsPerBar = 4,
  Feel feel = Feel.swing,
  Set<Genre>? tags,
  Map<int, String>? sections,
  Map<int, int>? repeats,
  Map<int, int>? endings,
}) => UserProgression(
  id: 'written',
  title: title,
  key: key,
  tempo: tempo,
  bars: bars,
  composer: composer,
  beatsPerBar: beatsPerBar,
  style: BandStyle.of(feel),
  tags: tags,
  sections: sections,
  repeats: repeats,
  endings: endings,
);

/// The progression as it comes home again.
UserProgression _roundTrip(UserProgression progression) =>
    parseIrealPro(irealLinkFor(progression)).single.progression;

/// Undoes iReal Pro's scrambling, done here independently of both the
/// writer and the reader: in each 50-character block but the last, the
/// first five characters swap with the last five, and 10–23 with 26–39.
String _unscramble(String text) {
  final out = StringBuffer();
  var rest = text;
  while (rest.length > 50) {
    final block = rest.substring(0, 50).split('');
    rest = rest.substring(50);
    if (rest.length >= 2) {
      for (final (a, b) in [
        for (var i = 0; i < 5; i++) (i, 49 - i),
        for (var i = 10; i < 24; i++) (i, 49 - i),
      ]) {
        final t = block[a];
        block[a] = block[b];
        block[b] = t;
      }
    }
    out.write(block.join());
  }
  out.write(rest);
  return out.toString();
}

/// The chart text inside the first song of [link], as iReal Pro would read
/// it once the scrambling is undone.
String _musicIn(String link) {
  final body = Uri.decodeComponent(link.substring(link.indexOf('://') + 3));
  final field = body.split('=').firstWhere((f) => f.startsWith('1r34LbKcu7'));
  return _unscramble(field.substring('1r34LbKcu7'.length));
}

void main() {
  test('a 12-bar blues, with its details', () {
    final blues = _progression(
      title: 'Test Blues',
      composer: 'Thelonious Monk',
      key: 'B♭',
      tempo: 160,
      bars: [
        'Bb7', 'Eb7', 'Bb7', 'Bb7', 'Eb7', 'Eo7', //
        'Bb7', 'G7b9', 'C-7', 'F7', 'Bb7 G7', 'C-7 F7',
      ],
    );
    final home = _roundTrip(blues);
    expect(home.title, 'Test Blues');
    expect(home.composer, 'Thelonious Monk', reason: 'written surname first');
    expect(home.key, 'B♭');
    expect(home.tempo, 160);
    expect(home.beatsPerBar, 4);
    expect(home.bars, blues.bars);
    expect(home.sections, isEmpty);
    expect(home.style.drums, Feel.swing);

    // "Kern Jerome" is how iReal Pro itself writes a composer.
    final link = Uri.decodeComponent(irealLinkFor(blues));
    expect(link, contains('Test Blues=Monk Thelonious=='));
    expect(link, contains('=Bb=='));
  });

  test('an AABA form keeps its section letters', () {
    final aaba = _progression(
      title: 'Rhythm Changes',
      key: 'B♭',
      tempo: 200,
      bars: [for (var i = 0; i < 32; i++) i.isEven ? 'Bb6' : 'G-7'],
      sections: {0: 'A', 8: 'A', 16: 'B', 24: 'A'},
    );
    final home = _roundTrip(aaba);
    expect(home.bars, aaba.bars);
    expect(home.sections, {0: 'A', 8: 'A', 16: 'B', 24: 'A'});
    expect(home.repeats, isEmpty);
    expect(home.endings, isEmpty);
    expect(home.toTune().form, 'AABA');
  });

  test('a section played twice comes home marked ×2', () {
    final twice = _progression(
      title: 'Twice',
      bars: ['C^7', 'A-7', 'D-7', 'G7', 'E-7', 'A7', 'D-7', 'G7'],
      sections: {0: 'A', 4: 'B'},
      repeats: {0: 2},
    );
    final home = _roundTrip(twice);
    expect(home.bars, twice.bars);
    expect(home.sections, {0: 'A', 4: 'B'});
    expect(home.repeats, {0: 2});
    expect(home.toTune().form, 'AAB');
  });

  test('more repeats than iReal Pro can write come home as twice', () {
    final thrice = _progression(
      title: 'Vamp',
      bars: ['C-9', 'C-9', 'F7sus', 'F7sus'],
      sections: {0: 'A'},
      repeats: {0: 3},
    );
    expect(_roundTrip(thrice).repeats, {0: 2}, reason: '{…} means twice');
  });

  test('1st and 2nd endings come home as endings', () {
    final endings = _progression(
      title: 'Endings',
      key: 'D minor',
      feel: Feel.bossa,
      bars: [
        'D-7', 'G7', 'E-7', 'A7b9', 'C^7', 'C^7', //
        'F^7', 'Bh7 E7b9', 'A-6', 'A-6',
      ],
      sections: {0: 'A', 6: 'B'},
      endings: {2: 1, 3: 1, 4: 2, 5: 2},
    );
    final home = _roundTrip(endings);
    expect(home.bars, endings.bars);
    expect(home.sections, {0: 'A', 6: 'B'});
    expect(home.endings, {2: 1, 3: 1, 4: 2, 5: 2});
    expect(home.key, 'D minor');
    expect(home.style.drums, Feel.bossa);
    // Through the 1st ending, round again to the 2nd, then B.
    expect(home.toTune().form, 'AAB');
    expect(home.toTune().barCount, 12);
  });

  test('a waltz stays in 3/4', () {
    final waltz = _progression(
      title: 'Someday My Prince',
      key: 'B♭',
      beatsPerBar: 3,
      tags: {Genre.ballad},
      bars: ['Bb^7', 'Bb^7', 'G-7', 'C7', 'F7', 'Bb6'],
    );
    final home = _roundTrip(waltz);
    expect(home.beatsPerBar, 3);
    expect(home.bars, waltz.bars);
    expect(home.tags, {Genre.ballad});
    // A 3/4 chart plays as written, so there's nothing to warn about.
    expect(parseIrealPro(irealLinkFor(waltz)).single.notes, isEmpty);

    final five = _progression(
      title: 'Take Five',
      bars: ['E-7', 'A7', 'C-7', 'B7#9'],
      beatsPerBar: 5,
    );
    expect(_roundTrip(five).beatsPerBar, 5);
  });

  test('minor keys keep their minor', () {
    for (final key in UserProgression.keys) {
      final home = _roundTrip(
        _progression(title: 'Key', key: key, bars: ['C^7', 'A-7']),
      );
      expect(home.key, key, reason: key);
    }
  });

  test('slash chords and the far corners of the chord list survive', () {
    final chords = _progression(
      title: 'Chords',
      bars: [
        'C7alt', 'Fh7', 'Bo7', 'G7sus', 'Ab69', 'D-^7', 'E+', 'C7#5', //
        'Bb7b9/D', 'C/E', 'Dsus', 'F-9', 'A-6', 'G13', 'E7#9', 'Db^9',
        'Bb7#11', 'F#o', 'C9', 'A-',
      ],
    );
    final home = _roundTrip(chords);
    expect(home.bars, chords.bars);
    expect(home.isPlayable, isTrue);
  });

  test('chords are written iReal Pro\'s way, whatever they were typed as', () {
    final typed = _progression(
      title: 'Spellings',
      bars: ['CΔ7', 'Dm7', 'G7', 'Am7♭5', 'B°7', 'Fmaj7/A', 'Cmin', 'Esus4'],
    );
    expect(_musicIn(irealLinkFor(typed)), contains('C^7|D-7|G7|Ah7'));
    expect(_roundTrip(typed).bars, [
      'C^7', 'D-7', 'G7', 'Ah7', 'Bo7', 'F^7/A', 'C-', 'Esus', //
    ]);
  });

  test('a playlist holds every song, with its name last', () {
    final link = irealPlaylistLink([
      _progression(title: 'One', bars: ['C^7', 'A-7'], key: 'C'),
      _progression(
        title: 'Two',
        bars: ['F-7', 'Bb7'],
        key: 'E♭',
        feel: Feel.funk,
        tempo: 100,
      ),
      _progression(
        title: 'Three',
        bars: ['D-7', 'G7'],
        key: 'C',
        feel: Feel.calypso,
      ),
    ], 'My Jam List');
    final songs = parseIrealPro(link);
    expect(songs.map((s) => s.progression.title), ['One', 'Two', 'Three']);
    expect(songs[1].progression.style.drums, Feel.funk);
    expect(songs[1].progression.tempo, 100);
    expect(songs[2].progression.style.drums, Feel.calypso);
    expect(link, endsWith('My%20Jam%20List'));
  });

  test('the chart never uses the runs iReal Pro shortens', () {
    // "XyQ", "LZ" and "Kcl" stand for runs of spacing that iReal Pro puts
    // back as it reads, which would change the length of the chart and
    // throw the scrambling out. Nothing written here may contain them.
    final charts = [
      for (final progression in [
        _progression(title: 'Blues', bars: ['Bb7', 'Eb7', 'Bb7', 'F7']),
        _progression(
          title: 'Endings',
          bars: ['D-7', 'G7', 'E-7', 'A7', 'C^7', 'C^7', 'F^7', 'Bh7'],
          sections: {0: 'A', 6: 'B'},
          endings: {2: 1, 3: 1, 4: 2, 5: 2},
        ),
        _progression(
          title: 'Long',
          bars: [for (var i = 0; i < 64; i++) 'Bb7b9/D Ah7 F#o C7alt'],
          sections: {0: 'A', 32: 'B'},
          repeats: {0: 2},
        ),
      ])
        _musicIn(irealLinkFor(progression)),
    ];
    for (final chart in charts) {
      expect(chart, isNot(contains('XyQ')));
      expect(chart, isNot(contains('LZ')));
      expect(chart, isNot(contains('Kcl')));
    }
    expect(charts.last, startsWith('[T44*A{'));
    expect(charts.last, endsWith('Z'));
  });

  test('a long chart survives the scrambling', () {
    // Over 50 characters the chart is scrambled block by block, so a chart
    // long enough to have several blocks is the real test of it.
    final long = _progression(
      title: 'Long One',
      key: 'E♭',
      tempo: 180,
      bars: [for (var i = 0; i < 48; i++) i.isEven ? 'Eb^7 C-7' : 'F-7 Bb7'],
      sections: {0: 'A', 16: 'B', 32: 'C'},
      repeats: {16: 2},
    );
    final home = _roundTrip(long);
    expect(home.bars, long.bars);
    expect(home.sections, {0: 'A', 16: 'B', 32: 'C'});
    expect(home.repeats, {16: 2});
    expect(home.key, 'E♭');
    expect(home.tempo, 180);
  });

  test('a progression with no title or composer still writes', () {
    final bare = _progression(title: '', composer: null, bars: ['C^7', 'F^7']);
    final home = _roundTrip(bare);
    expect(home.title, 'Untitled');
    expect(home.composer, isNull);
    expect(home.bars, ['C^7', 'F^7']);
  });
}
