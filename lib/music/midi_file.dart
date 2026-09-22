// Reading a MIDI file, as far as this app cares about one.
//
// A MIDI file is a list of events with delta times in ticks, and the header
// says how many ticks there are to a quarter note. That last number is the
// whole reason this is worth doing: dividing by it turns every event into a
// position in beats, and a position in beats is what the band already runs
// on. The file's own tempo is therefore ignored on purpose. An imported part
// plays at whatever the app is playing at, and follows the tempo slider and
// the ramp like everything else, because nothing here is in seconds.
//
// What comes out is parts rather than tracks. A format 1 file puts each
// instrument on its own track, a format 0 file puts everything on one track
// and separates them by channel, and a file written by hand may do both at
// once. Grouping by track and channel together covers all three without the
// rest of the app having to know which kind of file it was given.
//
// Only note events matter. Controllers, pitch bend, aftertouch and program
// changes are read past rather than understood, because the app plays the
// notes on its own recorded instruments and has nowhere to put a filter
// sweep. Anything on channel 10 is a drum part, which is marked but not
// translated: General MIDI drum numbering and this app's kit are different
// vocabularies and mapping them is its own piece of work.

import 'dart:typed_data';

/// A note from a file, placed in beats from the start of the file.
///
/// Velocity is 0 to 1 rather than 0 to 127, because that is what the synth
/// takes and converting once here means nothing downstream has to remember
/// which scale it is holding.
typedef MidiNote = ({int pitch, double beat, double beats, double velocity});

/// One instrument's worth of a file: everything on one track and one
/// channel.
class MidiPart {
  const MidiPart({
    required this.track,
    required this.name,
    required this.channel,
    required this.notes,
  });

  /// 0-based, in the order the file lists them.
  final int track;

  /// The track's name, from the file, or empty when it hasn't got one.
  /// A file written by a DAW usually names them; one written by a script
  /// usually doesn't.
  final String name;

  /// 0-based, so General MIDI's channel 10 is 9 here.
  final int channel;

  /// In playing order, earliest first.
  final List<MidiNote> notes;

  /// Channel 10 is drums by long convention, and its note numbers mean
  /// instruments rather than pitches. Marked so a part chooser can say so
  /// instead of offering to play a kick drum as a piano note.
  bool get isDrums => channel == 9;

  /// Where the last note finishes, in beats. What a part has to be given
  /// to repeat it.
  double get lengthBeats => notes.fold(
    0,
    (end, note) => note.beat + note.beats > end ? note.beat + note.beats : end,
  );

  /// The lowest and highest notes in it, or null when it is empty. Enough
  /// to guess whether a part is a bass line without being told.
  (int, int)? get range {
    if (notes.isEmpty) return null;
    var low = notes.first.pitch;
    var high = notes.first.pitch;
    for (final note in notes) {
      if (note.pitch < low) low = note.pitch;
      if (note.pitch > high) high = note.pitch;
    }
    return (low, high);
  }

  /// Reads like "2 Bass (12 notes)", which is what a failing test needs.
  @override
  String toString() =>
      '$track ${name.isEmpty ? 'ch${channel + 1}' : name} '
      '(${notes.length} notes)';
}

/// A file read: the parts in it, and what kind of file it was.
class MidiFile {
  const MidiFile({
    required this.format,
    required this.ticksPerBeat,
    required this.parts,
  });

  /// 0 (everything on one track), 1 (a track an instrument) or 2 (separate
  /// sequences, which is rare and is treated as 1).
  final int format;
  final int ticksPerBeat;

  /// Only the parts that actually contain notes, in track then channel
  /// order. A file's first track is usually nothing but tempo and time
  /// signature, and an empty part is not worth offering to anybody.
  final List<MidiPart> parts;

  /// The parts worth playing: everything that isn't a drum channel.
  List<MidiPart> get pitched => [
    for (final part in parts)
      if (!part.isDrums) part,
  ];
}

/// A file that cannot be read, with a reason worth showing someone.
class MidiFormatException implements Exception {
  const MidiFormatException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Reads [bytes] as a standard MIDI file.
///
/// Throws [MidiFormatException] with something a person can act on, because
/// every one of these cases is a file somebody chose in a file picker and
/// is entitled to be told about.
MidiFile readMidiFile(Uint8List bytes) {
  final reader = _Reader(bytes);
  if (!reader.matches('MThd')) {
    throw const MidiFormatException(
      'This is not a MIDI file. It should start with MThd.',
    );
  }
  reader.skip(4);
  final headerLength = reader.uint32();
  final format = reader.uint16();
  final trackCount = reader.uint16();
  final division = reader.uint16();
  // The header is allowed to be longer than the six bytes anyone uses.
  reader.seek(8 + headerLength);

  if (division & 0x8000 != 0) {
    throw const MidiFormatException(
      'This file counts time in film frames rather than in beats, which '
      'the app cannot line up with a tune. Export it again with a '
      'tick-per-beat resolution.',
    );
  }
  if (division == 0) {
    throw const MidiFormatException(
      'This file says there are no ticks in a '
      'beat, so nothing in it can be placed.',
    );
  }

  final parts = <(int, int), _Building>{};
  for (var track = 0; track < trackCount; track++) {
    if (reader.done) break;
    if (!reader.matches('MTrk')) {
      // Unknown chunk types are to be skipped rather than treated as an
      // error: the specification says so, and files in the wild use it.
      reader.skip(4);
      reader.skip(reader.uint32());
      track--;
      continue;
    }
    reader.skip(4);
    final end = reader.at + 4 + reader.uint32();
    _readTrack(reader, end: end, track: track, into: parts);
    reader.seek(end);
  }

  final found = parts.entries.toList()
    ..sort((a, b) {
      final byTrack = a.key.$1.compareTo(b.key.$1);
      return byTrack != 0 ? byTrack : a.key.$2.compareTo(b.key.$2);
    });
  return MidiFile(
    format: format,
    ticksPerBeat: division,
    parts: [
      for (final entry in found)
        if (entry.value.notes.isNotEmpty)
          MidiPart(
            track: entry.key.$1,
            name: entry.value.name,
            channel: entry.key.$2,
            notes: entry.value.finished(division),
          ),
    ],
  );
}

/// A part being collected while the file is read.
class _Building {
  String name = '';
  final notes = <({int pitch, int on, int off, int velocity})>[];

  /// Notes still sounding, by pitch. A list rather than one note each,
  /// because a sustained chord can strike the same pitch again before the
  /// first one is released and both have to come out.
  final sounding = <int, List<({int on, int velocity})>>{};

  List<MidiNote> finished(int ticksPerBeat) {
    final out = [
      for (final note in notes)
        (
          pitch: note.pitch,
          beat: note.on / ticksPerBeat,
          beats: (note.off - note.on) / ticksPerBeat,
          velocity: note.velocity / 127,
        ),
    ];
    out.sort((a, b) {
      final byBeat = a.beat.compareTo(b.beat);
      return byBeat != 0 ? byBeat : a.pitch.compareTo(b.pitch);
    });
    return out;
  }
}

void _readTrack(
  _Reader reader, {
  required int end,
  required int track,
  required Map<(int, int), _Building> into,
}) {
  var now = 0;
  var status = 0;
  // A track's name arrives as a meta event before any note, and belongs to
  // every channel the track turns out to use.
  final names = <String>[];

  _Building partFor(int channel) =>
      into.putIfAbsent((track, channel), _Building.new);

  while (reader.at < end && !reader.done) {
    now += reader.variable();
    var byte = reader.byte();
    if (byte < 0x80) {
      // Running status: a event with no status byte repeats the last one,
      // and the byte just read was really its first data byte.
      reader.back();
      byte = status;
    } else {
      status = byte;
    }
    final kind = byte & 0xF0;
    final channel = byte & 0x0F;

    switch (kind) {
      case 0x80 || 0x90:
        final pitch = reader.byte();
        final velocity = reader.byte();
        final part = partFor(channel);
        // A note on with no velocity is how most files write a note off.
        if (kind == 0x90 && velocity > 0) {
          part.sounding.putIfAbsent(pitch, () => []).add((
            on: now,
            velocity: velocity,
          ));
        } else {
          final open = part.sounding[pitch];
          if (open != null && open.isNotEmpty) {
            final started = open.removeAt(0);
            part.notes.add((
              pitch: pitch,
              on: started.on,
              off: now,
              velocity: started.velocity,
            ));
          }
        }
      case 0xA0 || 0xB0 || 0xE0:
        reader.skip(2);
      case 0xC0 || 0xD0:
        reader.skip(1);
      case 0xF0:
        if (byte == 0xFF) {
          final type = reader.byte();
          final length = reader.variable();
          if (type == 0x03) {
            names.add(reader.text(length));
          } else {
            reader.skip(length);
          }
        } else {
          // Sysex, which carries its own length and nothing we want.
          reader.skip(reader.variable());
        }
      default:
        // A byte that is no known status means the track is not what it
        // claims to be. Stopping here keeps whatever was read before it
        // rather than throwing away the file.
        return;
    }
  }

  // Anything still held at the end of the track is closed there, so a file
  // missing its last note off still plays.
  for (final entry in into.entries) {
    if (entry.key.$1 != track) continue;
    if (names.isNotEmpty) entry.value.name = names.first;
    for (final held in entry.value.sounding.entries) {
      for (final note in held.value) {
        entry.value.notes.add((
          pitch: held.key,
          on: note.on,
          off: now,
          velocity: note.velocity,
        ));
      }
    }
    entry.value.sounding.clear();
  }
}

/// A cursor over the bytes, which is all the parsing needs.
class _Reader {
  _Reader(this.bytes);

  final Uint8List bytes;
  int at = 0;

  bool get done => at >= bytes.length;

  void seek(int to) => at = to;
  void skip(int count) => at += count;
  void back() => at--;

  int byte() {
    if (at >= bytes.length) {
      throw const MidiFormatException(
        'This MIDI file stops in the middle of an event. It may have been '
        'cut short in transit.',
      );
    }
    return bytes[at++];
  }

  int uint16() => (byte() << 8) | byte();
  int uint32() => (uint16() << 16) | uint16();

  /// MIDI's variable-length number: seven bits a byte, top bit set on
  /// every byte but the last.
  int variable() {
    var value = 0;
    for (var i = 0; i < 4; i++) {
      final next = byte();
      value = (value << 7) | (next & 0x7F);
      if (next & 0x80 == 0) break;
    }
    return value;
  }

  String text(int length) {
    final end = (at + length).clamp(0, bytes.length);
    final out = String.fromCharCodes(bytes.sublist(at, end)).trim();
    at += length;
    return out;
  }

  bool matches(String tag) {
    if (at + tag.length > bytes.length) return false;
    for (var i = 0; i < tag.length; i++) {
      if (bytes[at + i] != tag.codeUnitAt(i)) return false;
    }
    return true;
  }
}
