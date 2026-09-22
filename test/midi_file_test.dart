// Reading a MIDI file.
//
// The files are built here byte by byte rather than kept as fixtures, so
// each test says in its own body exactly which part of the format it is
// about. Every one of these cases is something real files do: running
// status, note offs written as note ons, a tempo track with no notes in
// it, a note left hanging at the end.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/midi_file.dart';

List<int> _variable(int value) {
  if (value < 0x80) return [value];
  final out = <int>[value & 0x7F];
  var left = value >> 7;
  while (left > 0) {
    out.insert(0, (left & 0x7F) | 0x80);
    left >>= 7;
  }
  return out;
}

List<int> _on(int delta, int pitch, {int channel = 0, int velocity = 100}) => [
  ..._variable(delta),
  0x90 | channel,
  pitch,
  velocity,
];

List<int> _off(int delta, int pitch, {int channel = 0}) => [
  ..._variable(delta),
  0x80 | channel,
  pitch,
  0,
];

List<int> _name(String name) => [0, 0xFF, 0x03, name.length, ...name.codeUnits];

/// The tempo meta event, which the app reads past: 500,000 microseconds a
/// quarter note, which is 120 BPM.
const _tempo = [0, 0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20];
const _endOfTrack = [0, 0xFF, 0x2F, 0x00];

Uint8List _file(
  List<List<int>> tracks, {
  int format = 1,
  int ticksPerBeat = 480,
}) {
  final out = <int>[
    ...'MThd'.codeUnits,
    0, 0, 0, 6, //
    0, format,
    (tracks.length >> 8) & 0xFF, tracks.length & 0xFF,
    (ticksPerBeat >> 8) & 0xFF, ticksPerBeat & 0xFF,
  ];
  for (final track in tracks) {
    final body = [...track, ..._endOfTrack];
    out.addAll([
      ...'MTrk'.codeUnits,
      (body.length >> 24) & 0xFF,
      (body.length >> 16) & 0xFF,
      (body.length >> 8) & 0xFF,
      body.length & 0xFF,
    ]);
    out.addAll(body);
  }
  return Uint8List.fromList(out);
}

void main() {
  group('files it will not read', () {
    test('something that is not a MIDI file at all', () {
      expect(
        () => readMidiFile(Uint8List.fromList('not midi'.codeUnits)),
        throwsA(
          isA<MidiFormatException>().having(
            (e) => e.message,
            'message',
            contains('not a MIDI file'),
          ),
        ),
      );
    });

    test('one counting in film frames rather than beats', () {
      final bytes = _file([[]])..[12] = 0xE7; // SMPTE, 25 frames
      expect(
        () => readMidiFile(bytes),
        throwsA(
          isA<MidiFormatException>().having(
            (e) => e.message,
            'message',
            contains('film frames'),
          ),
        ),
      );
    });

    test('one that stops in the middle', () {
      final whole = _file([
        [..._on(0, 60), ..._off(480, 60)],
      ]);
      expect(
        () => readMidiFile(whole.sublist(0, whole.length - 6)),
        throwsA(isA<MidiFormatException>()),
      );
    });
  });

  group('placing the notes', () {
    test('ticks become beats, whatever the file counts in', () {
      for (final ticks in [96, 480, 960]) {
        final file = readMidiFile(
          _file([
            [
              ..._on(0, 60),
              ..._off(ticks, 60),
              ..._on(0, 62),
              ..._off(ticks ~/ 2, 62),
            ],
          ], ticksPerBeat: ticks),
        );
        final notes = file.parts.single.notes;
        expect(notes[0].beat, 0);
        expect(notes[0].beats, 1, reason: 'a note $ticks ticks long is a beat');
        expect(notes[1].beat, 1);
        expect(notes[1].beats, 0.5);
      }
    });

    test('the file\'s own tempo is read past and does not move anything', () {
      final without = readMidiFile(
        _file([
          [..._on(0, 60), ..._off(960, 60)],
        ]),
      );
      final with_ = readMidiFile(
        _file([
          [..._tempo, ..._on(0, 60), ..._off(960, 60)],
        ]),
      );
      expect(with_.parts.single.notes, without.parts.single.notes);
    });

    test('velocity comes out as a fraction, not a MIDI number', () {
      final file = readMidiFile(
        _file([
          [..._on(0, 60, velocity: 127), ..._off(480, 60)],
        ]),
      );
      expect(file.parts.single.notes.single.velocity, 1);
    });

    test(
      'a note on with no velocity is a note off, as most files write it',
      () {
        final file = readMidiFile(
          _file([
            [..._on(0, 60), ..._on(480, 60, velocity: 0)],
          ]),
        );
        expect(file.parts.single.notes.single.beats, 1);
      },
    );

    test('running status: an event with its status byte left off', () {
      // Three note ons in a row, the second and third without the 0x90.
      final file = readMidiFile(
        _file([
          [
            ..._on(0, 60),
            ..._variable(0), 62, 100, //
            ..._variable(0), 64, 100,
            ..._off(480, 60),
            ..._off(0, 62),
            ..._off(0, 64),
          ],
        ]),
      );
      expect(
        [for (final note in file.parts.single.notes) note.pitch],
        [60, 62, 64],
      );
    });

    test('the same pitch struck again before it is released', () {
      final file = readMidiFile(
        _file([
          [..._on(0, 60), ..._on(240, 60), ..._off(240, 60), ..._off(240, 60)],
        ]),
      );
      final notes = file.parts.single.notes;
      expect(notes.length, 2);
      expect(notes[0].beat, 0);
      expect(notes[1].beat, 0.5);
    });

    test('a note still held when the track ends is closed there', () {
      final file = readMidiFile(
        _file([
          [..._on(0, 60), ..._on(480, 62)],
        ]),
      );
      expect(file.parts.single.notes.length, 2);
      expect(file.parts.single.lengthBeats, 1);
    });

    test('notes come out in playing order', () {
      final file = readMidiFile(
        _file([
          [..._on(0, 72), ..._off(480, 72), ..._on(0, 60), ..._off(480, 60)],
        ]),
      );
      expect([for (final note in file.parts.single.notes) note.beat], [0, 1]);
    });
  });

  group('sorting it into parts', () {
    test('a track with nothing but tempo in it is not offered', () {
      final file = readMidiFile(
        _file([
          [..._tempo],
          [..._on(0, 60), ..._off(480, 60)],
        ]),
      );
      expect(file.parts.length, 1);
      expect(file.parts.single.track, 1);
    });

    test('a format 0 file splits by channel', () {
      final file = readMidiFile(
        _file([
          [
            ..._on(0, 60, channel: 0),
            ..._on(0, 40, channel: 1),
            ..._off(480, 60, channel: 0),
            ..._off(0, 40, channel: 1),
          ],
        ], format: 0),
      );
      expect(file.parts.length, 2);
      expect([for (final part in file.parts) part.channel], [0, 1]);
    });

    test('a format 1 file splits by track, and keeps the names', () {
      final file = readMidiFile(
        _file([
          [..._tempo],
          [..._name('Bass'), ..._on(0, 40), ..._off(480, 40)],
          [..._name('Piano'), ..._on(0, 60), ..._off(480, 60)],
        ]),
      );
      expect([for (final part in file.parts) part.name], ['Bass', 'Piano']);
    });

    test('an unnamed part says so rather than inventing one', () {
      final file = readMidiFile(
        _file([
          [..._on(0, 60), ..._off(480, 60)],
        ]),
      );
      expect(file.parts.single.name, '');
    });

    test('channel 10 is marked as drums and left out of the pitched parts', () {
      final file = readMidiFile(
        _file([
          [
            ..._name('Kit'),
            ..._on(0, 36, channel: 9),
            ..._off(480, 36, channel: 9),
          ],
          [..._name('Bass'), ..._on(0, 40), ..._off(480, 40)],
        ]),
      );
      expect(file.parts.length, 2);
      expect(file.parts.first.isDrums, isTrue);
      expect(file.parts.last.isDrums, isFalse);
      expect([for (final part in file.pitched) part.name], ['Bass']);
    });

    test('a chunk that is not a track is skipped, not treated as one', () {
      final good = _file([
        [..._on(0, 60), ..._off(480, 60)],
      ]);
      // An unknown chunk of 2 bytes, spliced in before the track.
      final withJunk = Uint8List.fromList([
        ...good.sublist(0, 14),
        ...'XYZW'.codeUnits,
        0,
        0,
        0,
        2,
        0xAA,
        0xBB,
        ...good.sublist(14),
      ]);
      final file = readMidiFile(withJunk);
      expect(file.parts.single.notes.length, 1);
      expect(file.parts.single.track, 0, reason: 'the junk is not a track');
    });
  });

  group('what a part can say about itself', () {
    test('how long it is, and how low and high it goes', () {
      final file = readMidiFile(
        _file([
          [..._on(0, 40), ..._off(480, 40), ..._on(0, 64), ..._off(960, 64)],
        ]),
      );
      final part = file.parts.single;
      expect(part.lengthBeats, 3);
      expect(part.range, (40, 64));
    });

    test('the header is reported as it was read', () {
      final file = readMidiFile(
        _file(
          [
            [..._on(0, 60), ..._off(96, 60)],
          ],
          format: 0,
          ticksPerBeat: 96,
        ),
      );
      expect(file.format, 0);
      expect(file.ticksPerBeat, 96);
    });
  });
}
