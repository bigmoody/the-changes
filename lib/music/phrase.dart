// A phrase somebody played, kept as the sound of it.
//
// Audio, not notation. The app can hear pitches well enough to write a
// line down, and doing that throws away everything about the playing: the
// time feel, the articulation, the bend into the third, the breath. What
// comes back is a correct transcription of something that was not the
// point. A phrase is worth keeping because of how it was played.
//
// So it is a WAV and two facts: what key it was played in, and what it is
// called. Taking it to another key is then a question about sound rather
// than about notes, which is the next file along.

import 'dart:math' as math;

import 'recorded_take.dart' show TakeShift;

/// How to move a phrase to another key.
enum PhraseMove {
  /// The pitch moves and the tempo does not: the filter does the work.
  ///
  /// What you want to practise with, because the phrase keeps its time
  /// feel. It is also the one that can sound rough, since a filter is
  /// inventing what it does not have.
  inTime('Keep the Tempo'),

  /// The whole thing is played faster or slower, the way a tape does it.
  ///
  /// Nothing is invented, so it cannot sound wrong, but a phrase moved up
  /// a fourth comes out a third faster. Good for hearing a line cleanly
  /// at a new pitch, less good for playing along with.
  likeTape('Like Tape');

  const PhraseMove(this.label);

  final String label;
}

/// A recorded phrase: the sound, and where it sits.
class Phrase {
  const Phrase({
    required this.id,
    required this.name,
    required this.fileName,
    required this.key,
    required this.seconds,
  });

  final String id;
  final String name;

  /// The WAV, in the phrases folder.
  final String fileName;

  /// The key it was played in, as a pitch class. Everything is measured
  /// from here.
  final int key;

  final double seconds;

  /// How to play it [semitones] away from where it was played.
  ///
  /// The two moves are the two knobs the engine has, used one at a time:
  /// the filter alone keeps the tempo and shifts the pitch, the speed
  /// alone moves both together. Using both at once is how the recorded
  /// band holds a tempo *and* a key, and is not what either of these is.
  TakeShift shiftBy(int semitones, PhraseMove move) {
    final ratio = math.pow(2, semitones / 12).toDouble();
    return switch (move) {
      PhraseMove.inTime => TakeShift(speed: 1, shift: ratio),
      PhraseMove.likeTape => TakeShift(speed: ratio, shift: 1),
    };
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'file': fileName,
    'key': key,
    'seconds': seconds,
  };

  static Phrase? fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final file = json['file'];
    if (id is! String || file is! String) return null;
    return Phrase(
      id: id,
      name: json['name'] as String? ?? 'Phrase',
      fileName: file,
      key: (json['key'] as num?)?.toInt() ?? 0,
      seconds: (json['seconds'] as num?)?.toDouble() ?? 0,
    );
  }
}
