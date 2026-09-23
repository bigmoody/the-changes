// A lick: a line somebody played, and the changes they played it over.
//
// Kept as notes rather than as audio, because everything worth doing with
// a lick needs the notes. Written on a stave. Moved to any key, which is
// the whole point: a phrase you can only play in one key is a phrase you
// have memorised rather than learned. Played back by the band. Checked
// against what you play the next time you try it.
//
// The changes travel with it. A line is nothing on its own: the same
// eight notes are a ii-V lick or a blues lick or nonsense depending on
// what is underneath, and a lick saved without its context is a lick
// nobody can use six months later. The progression is copied into the
// lick rather than pointed at, so editing the progression you wrote it
// over later does not quietly change what the lick is about.
//
// The recording is kept too, where there is one. The notes are what the
// app works with, but they are a reading of what you played, and being
// able to hear the thing itself is how you find out when the reading is
// wrong.

import 'dart:math' as math;

import '../audio/transcribe.dart';
import 'chord.dart';
import 'midi_file.dart';
import 'tune.dart';
import 'user_progression.dart';

class Lick {
  const Lick({
    required this.id,
    required this.name,
    required this.over,
    required this.notes,
    required this.at,
    this.grid = NoteGrid.swungEighths,
    this.recording,
  });

  final String id;

  /// What it is called. Somebody's own words: "the one over rhythm
  /// changes", "Dexter thing".
  final String name;

  /// The changes it was played over, its own copy.
  final UserProgression over;

  /// The line, in beats from the first beat of the progression.
  final List<MidiNote> notes;

  final DateTime at;

  /// The grid it was written down on, kept so it can be written down
  /// again the same way.
  final NoteGrid grid;

  /// The file the playing itself is in, if it was recorded.
  final String? recording;

  int get beatsPerBar => over.beatsPerBar;
  int get bars => over.bars.length;
  bool get isEmpty => notes.isEmpty;

  /// The key it was played in, as a pitch class, whatever it is spelled.
  int get key => over.toTune().keyPitchClass;

  /// The lowest and highest notes in it, or null when there are none.
  (int, int)? get range {
    if (notes.isEmpty) return null;
    var low = notes.first.pitch;
    var high = low;
    for (final note in notes) {
      low = math.min(low, note.pitch);
      high = math.max(high, note.pitch);
    }
    return (low, high);
  }

  /// How far the line spans, in beats from its first note to the end of
  /// its last.
  double get lengthBeats {
    if (notes.isEmpty) return 0;
    var end = 0.0;
    for (final note in notes) {
      end = math.max(end, note.beat + note.beats);
    }
    return end;
  }

  /// The line moved by [semitones].
  ///
  /// The notes only. What the band plays is the progression moved by the
  /// same amount, which is [tuneUp]: the two are worked out from the same
  /// number rather than stored together, so the line cannot end up in a
  /// different key from the chords underneath it.
  List<MidiNote> notesUp(int semitones) => [
    for (final note in notes)
      (
        pitch: note.pitch + semitones,
        beat: note.beat,
        beats: note.beats,
        velocity: note.velocity,
      ),
  ];

  /// The changes moved by [semitones], for the band to play.
  Tune tuneUp(int semitones) => over.toTune().transposed(semitones);

  /// The chord sounding at [beat] of the progression.
  Chord? chordAt(double beat) {
    final slots = over.toTune().slots;
    Chord? found;
    for (final slot in slots) {
      if (slot.startBeat <= beat) found = slot.chord;
    }
    return found;
  }

  Lick renamed(String name) => _copy(name: name);
  Lick withNotes(List<MidiNote> notes) => _copy(notes: notes);

  Lick _copy({String? name, List<MidiNote>? notes}) => Lick(
    id: id,
    name: name ?? this.name,
    over: over,
    notes: notes ?? this.notes,
    at: at,
    grid: grid,
    recording: recording,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'at': at.millisecondsSinceEpoch,
    'grid': grid.name,
    if (recording != null) 'recording': recording,
    'over': over.toJson(),
    // Flat rather than a list of objects: the key names would be most of
    // the file, as with the imported parts.
    'notes': [
      for (final note in notes) ...[
        note.pitch,
        note.beat,
        note.beats,
        note.velocity,
      ],
    ],
  };

  /// Null rather than throwing when the stored shape is not what this
  /// version writes: one lick is never worth losing the rest of them.
  static Lick? fromJson(Map<String, dynamic> json) {
    final flat = json['notes'];
    final over = json['over'];
    if (flat is! List ||
        flat.length % 4 != 0 ||
        over is! Map<String, dynamic>) {
      return null;
    }
    final notes = <MidiNote>[];
    for (var i = 0; i < flat.length; i += 4) {
      final values = flat.sublist(i, i + 4);
      if (values.any((value) => value is! num)) return null;
      notes.add((
        pitch: (values[0] as num).round(),
        beat: (values[1] as num).toDouble(),
        beats: (values[2] as num).toDouble(),
        velocity: (values[3] as num).toDouble(),
      ));
    }
    try {
      return Lick(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Lick',
        over: UserProgression.fromJson(over),
        notes: notes,
        at: DateTime.fromMillisecondsSinceEpoch(
          (json['at'] as num?)?.toInt() ?? 0,
        ),
        grid: NoteGrid.values.firstWhere(
          (value) => value.name == json['grid'],
          orElse: () => NoteGrid.swungEighths,
        ),
        recording: json['recording'] as String?,
      );
    } catch (e) {
      return null;
    }
  }
}

/// The order the keys come round in a drill.
enum KeyOrder {
  fourths('Round the cycle'),
  chromatic('Up in semitones'),
  random('Shuffled');

  const KeyOrder(this.label);
  final String label;

  /// The twelve moves from the key a lick was played in, in this order,
  /// starting with none at all: you play it where you know it first.
  List<int> moves({int seed = 0}) => switch (this) {
    // Up a fourth each time, which is the order changes actually go in.
    fourths => [for (var i = 0; i < 12; i++) (i * 5) % 12],
    chromatic => [for (var i = 0; i < 12; i++) i],
    random => () {
      final rest = [for (var i = 1; i < 12; i++) i]..shuffle(math.Random(seed));
      return [0, ...rest];
    }(),
  };
}
