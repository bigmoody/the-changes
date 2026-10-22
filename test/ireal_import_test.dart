// Reading iReal Pro links: the fields of each song, the scrambled music,
// sections, repeats and endings, and chords the app writes differently.

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/chart_layout.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/ireal_import.dart';
import 'package:play_along/music/loop_range.dart';
import 'package:play_along/music/user_progression.dart';
import 'package:play_along/music/tune.dart';

/// iReal Pro's scrambling, done here independently: in each 50-character
/// block but the last, the first five characters swap with the last five,
/// and 10–23 with 26–39. (It undoes itself.)
String _scramble(String text) {
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

/// A song as iReal Pro writes it in an irealb:// link.
String _song(
  String title,
  String composer,
  String style,
  String key,
  String music, {
  int bpm = 0,
}) =>
    '$title=$composer==$style=$key==1r34LbKcu7${_scramble(music)}'
    '==Medium Swing=$bpm=3';

String _link(List<String> songs, {String? playlist}) =>
    'irealb://${Uri.encodeComponent([...songs, ?playlist].join('==='))}';

void main() {
  group('a stray per cent sign', () {
    // One % that is not an escape used to cost the whole link. Decoding
    // was all or nothing: Uri.decodeComponent throws on it, and the
    // catch read the link exactly as it arrived. Where the separators
    // were already literal the songs still parsed, out of text that was
    // still escaped, so a title came through as "Take%20The%20A%20Train"
    // and the music, which is unscrambled character by character, came
    // through as nonsense: single letters for chords, three chords in a
    // bar that holds one, and qualities dropped.
    //
    // A per cent sign in a song's name is enough to do it, and it does
    // it to every song in the playlist, not just that one.
    const body =
        'Blues%20One,%20100%%20proof=Doe%20Jane=Medium%20Swing=F=n='
        '[T44F7%20|Bb7%20|F7%20|C7%20Z';

    test('does not leave the other escapes in the words', () {
      final song = parseIrealPro('irealbook://$body').single;
      expect(song.progression.title, 'Blues One, 100% proof');
      expect(song.style, 'Medium Swing');
      expect(song.progression.composer, 'Jane Doe');
    });

    test('and does not reach the music', () {
      final song = parseIrealPro('irealbook://$body').single;
      expect(song.progression.bars, ['F7', 'Bb7', 'F7', 'C7']);
    });

    test('itself survives, being a per cent sign and not an escape', () {
      expect(decodeEscapes('100% proof'), '100% proof');
      expect(decodeEscapes('%'), '%');
      expect(decodeEscapes('%2'), '%2');
    });

    test('an accented title still arrives as its letters', () {
      // Two escapes to the letter, so decoding a byte at a time has to
      // put them back together rather than hand over two half-letters.
      expect(decodeEscapes('Caf%C3%A9 100% Bleu'), 'Café 100% Bleu');
    });
  });
  const blues =
      '[T44Bb7XyQ|Eb7XyQ|Bb7XyQKcl  LZEb7XyQ|Eo7XyQ|Bb7XyQ|G7b9XyQ|'
      'C-7XyQ|F7XyQ|Bb7 G7LZC-7 F7 Z ';
  const bossa =
      '[T44*A{D-7XyQ|G7XyQ|N1E-7XyQ|A7b9XyQ}XyQ|N2C^7XyQ|C^7XyQ]'
      '[*BF^7XyQ|Bh7 E7b9LZA-6XyQ|A-6XyQZ';

  test('a playlist: every song, with its details', () {
    final songs = parseIrealPro(
      _link([
        _song(
          'Test Blues',
          'Monk Thelonious',
          'Medium Swing',
          'Bb',
          blues,
          bpm: 160,
        ),
        _song('Test Bossa', 'Jobim Antonio Carlos', 'Bossa Nova', 'D-', bossa),
      ], playlist: 'My Jam List'),
    );
    expect(songs, hasLength(2));

    final blues12 = songs[0].progression;
    expect(blues12.title, 'Test Blues');
    expect(blues12.composer, 'Thelonious Monk', reason: 'surname first');
    expect(blues12.key, 'B♭');
    expect(blues12.tempo, 160);
    expect(blues12.style.drums, Feel.swing);
    // Kcl: the bar before, again.
    expect(blues12.bars, [
      'Bb7', 'Eb7', 'Bb7', 'Bb7', 'Eb7', 'Eo7', 'Bb7', 'G7b9', //
      'C-7', 'F7', 'Bb7 G7', 'C-7 F7',
    ]);
    expect(blues12.toTune().barCount, 12);

    final bossaNova = songs[1].progression;
    expect(bossaNova.key, 'D minor');
    expect(bossaNova.style.drums, Feel.bossa);
    expect(bossaNova.tempo, 140, reason: 'no tempo given: one for the style');
    expect(bossaNova.composer, 'Jobim Antonio Carlos', reason: 'left alone');
  });

  test('sections and 1st and 2nd endings come across as written', () {
    final song = parseIrealPro(
      _link([_song('Endings', 'Doe Jane', 'Bossa Nova', 'D-', bossa)]),
    ).single.progression;
    expect(song.bars, [
      'D-7', 'G7', 'E-7', 'A7b9', 'C^7', 'C^7', 'F^7', 'Bh7 E7b9', //
      'A-6', 'A-6',
    ]);
    expect(song.sections, {0: 'A', 6: 'B'});
    expect(song.endings, {2: 1, 3: 1, 4: 2, 5: 2});

    // Played through the 1st ending, round again to the 2nd, then B…
    final tune = song.toTune();
    expect(tune.barCount, 12);
    expect(tune.form, 'AAB');
    // …and charted with its endings bracketed.
    final lines = layOutChart(tune, 4);
    expect([for (final c in lines.first.cells) c?.ending], [null, null, 1, 1]);
  });

  test('a repeated section plays ×2; a repeat mid-section is written out', () {
    final twice = parseIrealPro(
      _link([
        _song(
          'Twice',
          'Doe Jane',
          'Medium Swing',
          'C',
          '*A{C^7XyQ|A-7XyQ|D-7XyQ|G7XyQ}[*BE-7XyQ|A7XyQ|D-7XyQ|G7XyQZ',
        ),
      ]),
    ).single.progression;
    expect(twice.sections, {0: 'A', 4: 'B'});
    expect(twice.repeats, {0: 2});
    expect(twice.toTune().form, 'AAB');

    final midway = parseIrealPro(
      _link([
        _song(
          'Midway',
          'Doe Jane',
          'Medium Swing',
          'C',
          '*AC^7XyQ|{D-7XyQ|G7XyQ}C^7XyQZ',
        ),
      ]),
    ).single.progression;
    expect(midway.bars, ['C^7', 'D-7', 'G7', 'D-7', 'G7', 'C^7']);
    expect(midway.repeats, isEmpty);
  });

  test('repeat signs, no-chord, invisible roots, and what to skip', () {
    final song = parseIrealPro(
      _link([
        _song(
          'Signs',
          'Doe Jane',
          'Medium Swing',
          'C',
          '[T44C^7XyQ|D-7XyQ|r|XyQ|G7(Db7)XyQ|<D.C. al Coda>nXyQ|W/BXyQZ',
        ),
      ]),
    ).single.progression;
    expect(song.bars, [
      'C^7', 'D-7', // then both again (r)
      'C^7', 'D-7',
      'G7', // its small alternative chord skipped
      'G7', // no chord: G7 held
      'G7/B', // the invisible root: G7 again, over B
    ]);
  });

  test('chords the app writes differently become their nearest', () {
    final song = parseIrealPro(
      _link([
        _song(
          'Chords',
          'Doe Jane',
          'Medium Swing',
          'C',
          'C^7#11XyQ|F-11XyQ|Bb7b9b13XyQ|E7#9#5XyQ|D9susXyQ|GhXyQ|'
              'A-^9XyQ|C2XyQZ',
        ),
      ]),
    ).single.progression;
    final qualities = [
      for (final bar in song.bars) Chord.parse(bar).quality.name,
    ];
    expect(qualities, [
      'Major 7th', 'Minor 9th', 'Dominant 7th flat 9', 'Altered dominant', //
      'Dominant 7th suspended 4th', 'Half-diminished', 'Minor-major 7th',
      'Major',
    ]);
    expect(song.isPlayable, isTrue);
  });

  test('old irealbook links, links inside a page, and waltzes', () {
    final songs = parseIrealPro(
      '<p>My charts:</p><a href="irealbook://'
      '${Uri.encodeComponent('Old Tune=Doe John=Ballad=F=n=[T44F^7 |D-7 |G-7 |C7 Z')}'
      '">Old Tune</a> and '
      '${_link([_song('Waltz', 'Doe Jane', 'Jazz Waltz', 'Bb', '[T34Bb^7XyQ|G-7XyQ|C-7XyQ|F7XyQZ')])}',
    );
    expect(songs.map((s) => s.progression.title), ['Old Tune', 'Waltz']);
    final old = songs[0].progression;
    expect(old.bars, ['F^7', 'D-7', 'G-7', 'C7']);
    expect(old.tags, {Genre.ballad});
    expect(old.tempo, 70);
    // A waltz plays in 3/4, so there's nothing to warn about.
    expect(songs[1].progression.beatsPerBar, 3);
    expect(songs[1].notes, isEmpty);
  });

  test('nothing to import in text without a link', () {
    expect(parseIrealPro('just some text'), isEmpty);
    expect(parseIrealPro('irealb://'), isEmpty);
  });

  test(
    'an intro comes across, and survives being saved, to be played once',
    () {
      // Valse Hot's shape: iReal Pro's "in" box over four bars here, then
      // the A section. The intro is what is played once before the band
      // goes round the rest, so the mark has to come all the way through:
      // read from the link, kept when the progression is saved, and still
      // the first section of the tune it plays.
      const valse =
          '[T34*iBb-7XyQ|Eb7XyQ|Ab^7XyQ|Ab^7XyQ]'
          '[*AAb^7XyQ|Db^7XyQ|C-7XyQ|F7XyQZ';
      final song = parseIrealPro(
        _link([_song('Valse', 'Rollins Sonny', 'Waltz', 'Ab', valse)]),
      ).single;
      expect(song.progression.sections[0], 'Intro');
      final saved = UserProgression.fromJson(song.progression.toJson());
      final tune = saved.toTune();
      final intro = introOf(tune)!;
      expect(intro.firstBar(tune), 0);
      expect(intro.lastBar(tune), 3);
    },
  );
}
