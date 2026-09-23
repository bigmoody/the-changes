// Hearing a lick back.
//
// The rendering itself is the band's, and tested where the band is. What
// is tested here is the part that decides what is heard: which notes,
// how far from where they were played, and where they fall in time.

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/lick_sound.dart';
import 'package:play_along/music/lick.dart';
import 'package:play_along/music/midi_file.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/user_progression.dart';

MidiNote note(int pitch, double beat, {double beats = 0.5}) =>
    (pitch: pitch, beat: beat, beats: beats, velocity: 0.85);

Lick lick({List<MidiNote>? notes, UserProgression? over}) => Lick(
  id: 'l1',
  name: 'A line',
  over: over,
  notes: notes ?? [note(62, 0), note(64, 1), note(65, 2)],
  at: DateTime(2026, 9, 23),
);

final iiV = UserProgression(
  id: 'p1',
  title: 'ii V',
  key: 'C',
  tempo: 140,
  bars: const ['Dm7', 'G7'],
  style: BandStyle.of(Feel.swing),
);

void main() {
  group('what gets played', () {
    test('the notes as they were written', () {
      final notes = lickSnippetNotes(lick(), tempo: 120);
      expect(notes.map((n) => n.pitch).toList(), [62, 64, 65]);
      expect(notes.every((n) => n.bass == false), isTrue);
    });

    test('at the tempo being worked at, not the one it was caught at', () {
      // The notes are held in beats, so a beat is half a second at 120
      // and a third of one at 180.
      final slow = lickSnippetNotes(lick(), tempo: 120);
      final fast = lickSnippetNotes(lick(), tempo: 180);
      expect(slow[1].start, closeTo(0.5, 0.001));
      expect(fast[1].start, closeTo(1 / 3, 0.001));
      expect(slow[0].length, closeTo(0.25, 0.001));
      expect(fast[0].length, closeTo(1 / 6, 0.001));
    });

    test('in whatever key the drill has reached', () {
      final up = lickSnippetNotes(lick(), semitones: 5, tempo: 120);
      expect(up.map((n) => n.pitch).toList(), [67, 69, 70]);
      expect(
        up.map((n) => n.start).toList(),
        lickSnippetNotes(lick(), tempo: 120).map((n) => n.start).toList(),
        reason: 'moving key does not move the rhythm',
      );
    });

    test('a swung line stays swung, without being told to', () {
      // Written on the swung grid, the off-beat sits two thirds through.
      final swung = lick(notes: [note(62, 0), note(64, 2 / 3)]);
      final notes = lickSnippetNotes(swung, tempo: 120);
      expect(notes[1].start, closeTo(1 / 3, 0.001));
    });

    test('a lick with no changes plays like any other', () {
      expect(lickSnippetNotes(lick(), tempo: 120), hasLength(3));
      expect(lickSnippetNotes(lick(over: iiV), tempo: 120), hasLength(3));
    });
  });

  group('when there is nothing to play', () {
    test('no notes, nothing to hear', () {
      expect(lickSnippetNotes(lick(notes: const []), tempo: 120), isEmpty);
      expect(lickSnippet(lick(notes: const []), null, tempo: 120), isNull);
    });

    test('a nonsense tempo is not divided by', () {
      expect(lickSnippetNotes(lick(), tempo: 0), isEmpty);
    });

    test('without the recorded instruments it says nothing rather than '
        'playing silence', () {
      // Null so the screen can say they are still loading; silence would
      // look like a lick that did not record.
      expect(lickSnippet(lick(), null, tempo: 120), isNull);
    });
  });
}
