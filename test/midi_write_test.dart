// Writing the band out as MIDI, and reading it straight back in with the
// app's own reader: a file this app cannot open is a file a DAW has no
// reason to open either.

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/midi_file.dart';
import 'package:play_along/music/midi_write.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';

Tune _tune(String title) => standards.firstWhere((t) => t.title == title);

void main() {
  test('the band comes back as parts a DAW can read', () {
    final tune = _tune('Autumn Leaves');
    final file = readMidiFile(midiFor(tune, tempo: 140, choruses: 2));

    expect(file.format, 1, reason: 'a track for each instrument');
    expect(file.ticksPerBeat, 480);
    // The conductor track carries no notes, so the reader hands back the
    // three that play.
    expect(file.parts.map((p) => p.name), ['Piano', 'Bass', 'Drums']);
    expect(file.parts.map((p) => p.channel), [0, 1, 9]);
    expect(file.pitched.map((p) => p.name), ['Piano', 'Bass']);
    for (final part in file.parts) {
      expect(part.notes, isNotEmpty, reason: '${part.name} plays nothing');
    }
  });

  test('it starts with a bar of count-in and runs for the choruses asked', () {
    final tune = _tune('Blue Bossa');
    final file = readMidiFile(midiFor(tune, choruses: 2));
    final drums = file.parts.firstWhere((p) => p.isDrums);
    final bass = file.parts.firstWhere((p) => p.name == 'Bass');

    // The count-in is the only thing in the first bar, and it is sticks.
    final countIn = drums.notes.where((n) => n.beat < tune.beatsPerBar);
    expect(countIn, hasLength(tune.beatsPerBar));
    expect(countIn.map((n) => n.pitch).toSet(), {37});
    expect(
      bass.notes.first.beat,
      greaterThanOrEqualTo(tune.beatsPerBar.toDouble()),
      reason: 'the bass waits for the count-in',
    );
    // Two choruses of the form, after that bar.
    final played = tune.totalBeats * 2 + tune.beatsPerBar;
    expect(bass.lengthBeats, lessThanOrEqualTo(played + 1.0));
    expect(bass.lengthBeats, greaterThan(tune.totalBeats.toDouble()));
  });

  test('the drums are in General MIDI numbering', () {
    final file = readMidiFile(midiFor(_tune('Blue Bossa')));
    final drums = file.parts.firstWhere((p) => p.isDrums);
    // Everything played sits in the General MIDI percussion range, so a
    // stock kit plays it as drums.
    for (final note in drums.notes) {
      expect(note.pitch, inInclusiveRange(35, 59));
    }
    expect(drums.notes.map((n) => n.pitch).toSet(), contains(36));
  });

  test('a waltz is written in three, and the tempo is the one asked for', () {
    final bytes = midiFor(_tune('Someday My Prince Will Come'), tempo: 180);
    // The time signature and tempo metas, read out of the conductor track
    // by hand: the app's reader only keeps the notes.
    final signature = _meta(bytes, 0x58);
    expect(signature?.first, 3, reason: 'three beats in the bar');
    final tempo = _meta(bytes, 0x51);
    final microseconds = (tempo![0] << 16) + (tempo[1] << 8) + tempo[2];
    expect((60000000 / microseconds).round(), 180);
  });

  test('the file is named after the tune', () {
    expect(
      midiFileName('All The Things You Are?'),
      'All The Things You Are.mid',
    );
    expect(midiFileName('  '), 'Chart.mid');
  });
}

/// The body of the first meta event of [kind] in [bytes].
List<int>? _meta(List<int> bytes, int kind) {
  for (var i = 0; i < bytes.length - 2; i++) {
    if (bytes[i] == 0xFF && bytes[i + 1] == kind) {
      final length = bytes[i + 2];
      return bytes.sublist(i + 3, i + 3 + length);
    }
  }
  return null;
}
