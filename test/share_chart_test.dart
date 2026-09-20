// What leaves the app when a chart is shared.
//
// Sharing writes a standard out as though it were one of the player's own
// progressions, so this checks that step as well as the link itself: a tune
// sent to someone with iReal Pro has to arrive as the same tune.

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/chart_text.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/ireal_export.dart';
import 'package:play_along/music/ireal_import.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/music/user_progression.dart';

import 'package:play_along/music/tune.dart';

Tune _tune(String title) => standards.firstWhere((tune) => tune.title == title);

/// The bars as chords rather than as text. A link comes back spelled iReal
/// Pro's way — C-7 for Cm7, C^7 for CΔ7 — which is the same chord written
/// differently, so what's compared is the notes each bar asks for.
List<String> _chords(UserProgression progression) => [
  for (final bar in progression.bars)
    [
      for (final symbol in UserProgression.symbolsIn(bar))
        _sounds(Chord.parse(symbol)),
    ].join(' '),
];

String _sounds(Chord chord) =>
    '${chord.root}${chord.quality.intervals}/${chord.bass}';

void main() {
  group('as an iReal Pro link', () {
    test('a standard comes back the same tune', () {
      for (final title in [
        'Autumn Leaves',
        'Cherokee',
        'Blue Bossa',
        'All of Me',
      ]) {
        final written = UserProgression.fromTune(_tune(title), id: '0');
        final back = parseIrealPro(irealLinkFor(written)).single.progression;
        expect(back.title, title);
        expect(_chords(back), _chords(written), reason: title);
        expect(back.sections, written.sections, reason: title);
        expect(back.key, written.key, reason: title);
        expect(back.tempo, written.tempo, reason: title);
        expect(back.beatsPerBar, written.beatsPerBar, reason: title);
      }
    });

    test('a waltz keeps its three beats to the bar', () {
      final written = UserProgression.fromTune(
        _tune('Someday My Prince Will Come'),
        id: '0',
      );
      expect(written.beatsPerBar, 3);
      final back = parseIrealPro(irealLinkFor(written)).single.progression;
      expect(back.beatsPerBar, 3);
    });

    test('a modal tune keeps its chords, but loses the word Dorian', () {
      // iReal Pro's keys are major or minor, with no mode among them, so
      // So What goes out in D. The changes are untouched, which is what
      // the other end is reading.
      final written = UserProgression.fromTune(_tune('So What'), id: '0');
      final back = parseIrealPro(irealLinkFor(written)).single.progression;
      expect(written.key, 'D Dorian');
      expect(back.key, 'D');
      expect(_chords(back), _chords(written));
    });

    test('a setlist goes out as one playlist', () {
      final songs = [
        for (final title in ['Blue Bossa', 'So What', 'All of Me'])
          UserProgression.fromTune(_tune(title), id: '0'),
      ];
      final back = parseIrealPro(irealPlaylistLink(songs, 'Friday'));
      expect(back.map((song) => song.progression.title), [
        'Blue Bossa',
        'So What',
        'All of Me',
      ]);
    });
  });

  group('as text', () {
    test('a setlist is written out one chart after another', () {
      final text = chartsText([
        _tune('Blue Bossa'),
        _tune('So What'),
      ], heading: 'Friday at the Vortex');
      expect(text, startsWith('Friday at the Vortex'));
      expect(text, contains('Blue Bossa'));
      expect(text, contains('So What'));
    });
  });
}
