// An imported part: where its notes end up once they are laid against a
// form.
//
// The parser's tests say the notes come out of the file correctly. These
// say what happens to them afterwards, which is the part with opinions in
// it: repeating inside the form, starting again at the top of every
// chorus, and being cut off rather than allowed to run on.

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/imported_part.dart';
import 'package:play_along/music/midi_file.dart';

MidiPart _part(List<MidiNote> notes, {int channel = 0, String name = ''}) =>
    MidiPart(track: 0, name: name, channel: channel, notes: notes);

MidiNote _note(int pitch, double beat, [double beats = 1]) =>
    (pitch: pitch, beat: beat, beats: beats, velocity: 0.8);

ImportedPart _twoBarRiff() => ImportedPart(
  name: 'Riff',
  notes: [_note(60, 0), _note(62, 2), _note(64, 4), _note(65, 6)],
  lengthBeats: 8,
);

void main() {
  group('making one', () {
    test('its length is rounded up to a whole bar', () {
      // A note released halfway through bar 3 still makes a 3-bar part.
      final part = ImportedPart.of(
        _part([_note(60, 0), _note(62, 8, 2.5)]),
        beatsPerBar: 4,
      );
      expect(part.lengthBeats, 12);
      expect(part.bars(4), 3);
    });

    test('an empty-ish part is still at least one bar', () {
      final part = ImportedPart.of(_part([_note(60, 0, 0.5)]), beatsPerBar: 4);
      expect(part.lengthBeats, 4);
    });

    test('it takes the track name, or says where it came from', () {
      expect(
        ImportedPart.of(
          _part([_note(60, 0)], name: 'Bass'),
          beatsPerBar: 4,
        ).name,
        'Bass',
      );
      expect(
        ImportedPart.of(_part([_note(60, 0)], channel: 2), beatsPerBar: 4).name,
        'Track 1, channel 3',
      );
    });
  });

  group('laying it over the form', () {
    test('a two-bar riff comes round three times in a six-bar form', () {
      final laid = _twoBarRiff().laidOver(choruses: 1, formBeats: 24);
      expect(laid.length, 12);
      expect(
        [for (final note in laid) note.beat],
        [
          0, 2, 4, 6, //
          8, 10, 12, 14,
          16, 18, 20, 22,
        ],
      );
    });

    test('every chorus starts the part again from its top', () {
      final laid = _twoBarRiff().laidOver(choruses: 3, formBeats: 8);
      expect(laid.length, 12);
      // The first note of each chorus is the part's own first note.
      for (final chorus in [0, 1, 2]) {
        final first = laid[chorus * 4];
        expect(first.beat, chorus * 8);
        expect(first.pitch, 60);
      }
    });

    test('a form that is not a whole number of repeats cuts the last one', () {
      // Six beats of form, eight beats of riff: the last note is past the
      // end and does not play.
      final laid = _twoBarRiff().laidOver(choruses: 1, formBeats: 6);
      expect([for (final note in laid) note.beat], [0, 2, 4]);
    });

    test(
      'a note is cut at the end of the chorus, not left ringing into it',
      () {
        final long = ImportedPart(
          name: 'Held',
          notes: [_note(60, 0, 8)],
          lengthBeats: 8,
        );
        final laid = long.laidOver(choruses: 2, formBeats: 4);
        expect(laid.length, 2);
        expect(laid.first.beats, 4, reason: 'cut at the end of chorus one');
        expect(laid.last.beat, 4);
      },
    );

    test('transposing moves every note and nothing else', () {
      final laid = _twoBarRiff()
          .transposedBy(-3)
          .laidOver(choruses: 1, formBeats: 8);
      expect([for (final note in laid) note.pitch], [57, 59, 61, 62]);
      expect([for (final note in laid) note.beat], [0, 2, 4, 6]);
    });

    test('nothing in, nothing out', () {
      const empty = ImportedPart(name: 'x', notes: [], lengthBeats: 8);
      expect(empty.laidOver(choruses: 4, formBeats: 48), isEmpty);
      expect(empty.isEmpty, isTrue);
      expect(_twoBarRiff().laidOver(choruses: 0, formBeats: 48), isEmpty);
    });

    test('looping a stretch takes that stretch of the part', () {
      // The defect this is here for: the band comps bars 7 and 8, and the
      // part restarted from its own bar 1 underneath them.
      final twelveBars = ImportedPart(
        name: 'Line',
        notes: [
          for (var beat = 0; beat < 48; beat++) _note(60 + beat, beat + 0),
        ],
        lengthBeats: 48,
      );
      // Bars 7 and 8 of a 4/4 tune: beats 24 to 31.
      final laid = twelveBars.laidOver(choruses: 1, formBeats: 8, fromBeat: 24);
      expect(
        [for (final note in laid) note.pitch],
        [for (var beat = 24; beat < 32; beat++) 60 + beat],
      );
      // And they are played from the top of the loop, not 24 beats in.
      expect([for (final note in laid) note.beat], [0, 1, 2, 3, 4, 5, 6, 7]);
    });

    test('a loop that starts mid-repeat still lines up', () {
      // A two-bar riff under a loop starting at bar 4: the loop's first
      // beat is the riff's fifth, so the riff comes in on its second half.
      final laid = _twoBarRiff().laidOver(
        choruses: 1,
        formBeats: 8,
        fromBeat: 12,
      );
      expect([for (final note in laid) note.pitch], [64, 65, 60, 62]);
      expect([for (final note in laid) note.beat], [0, 2, 4, 6]);
    });

    test('with no loop offset it is the same as before', () {
      expect(
        _twoBarRiff().laidOver(choruses: 2, formBeats: 8),
        _twoBarRiff().laidOver(choruses: 2, formBeats: 8, fromBeat: 0),
      );
    });

    test('it says when the form will cut it short', () {
      final twelveBars = ImportedPart(
        name: 'Long',
        notes: [_note(60, 0)],
        lengthBeats: 48,
      );
      expect(twelveBars.overrunsForm(32), isTrue);
      expect(twelveBars.overrunsForm(48), isFalse);
    });
  });

  group('guessing which instrument it is for', () {
    test('a part that lives below the bass clef is a bass part', () {
      expect(
        suggestedVoice(_part([_note(40, 0), _note(43, 1), _note(36, 2)])),
        PartVoice.bass,
      );
    });

    test('a single line in the middle suits the guitar', () {
      expect(
        suggestedVoice(_part([_note(60, 0), _note(64, 1), _note(67, 2)])),
        PartVoice.guitar,
      );
    });

    test('notes sounding together are a comp, so the piano takes it', () {
      expect(
        suggestedVoice(
          _part([_note(60, 0, 2), _note(64, 0, 2), _note(67, 0, 2)]),
        ),
        PartVoice.piano,
      );
    });

    test('an empty part guesses rather than throwing', () {
      expect(suggestedVoice(_part([])), PartVoice.piano);
    });
  });

  group('storing one', () {
    test('it comes back the way it went in', () {
      final part = _twoBarRiff().withVoice(PartVoice.bass);
      final back = ImportedPart.fromJson(part.toJson())!;
      expect(back.name, part.name);
      expect(back.lengthBeats, part.lengthBeats);
      expect(back.voice, PartVoice.bass);
      expect(back.notes, part.notes);
    });

    test('rubbish comes back as nothing rather than throwing', () {
      expect(ImportedPart.fromJson({}), isNull);
      expect(
        ImportedPart.fromJson({'notes': 'nope', 'lengthBeats': 8}),
        isNull,
      );
      expect(
        ImportedPart.fromJson({
          'notes': [60, 0, 1],
          'lengthBeats': 8,
        }),
        isNull,
        reason: 'four numbers a note, or it is not a part',
      );
      expect(
        ImportedPart.fromJson({
          'notes': [60, 0, 1, 'loud'],
          'lengthBeats': 8,
        }),
        isNull,
      );
    });

    test('a voice it has never heard of falls back rather than failing', () {
      final json = _twoBarRiff().toJson()..['voice'] = 'trombone';
      expect(ImportedPart.fromJson(json)?.voice, PartVoice.piano);
    });
  });
}
