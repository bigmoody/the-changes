// A part imported from a MIDI file, sitting alongside the band.
//
// The band writes itself from the chart every time it plays. An imported
// part does not: it is a fixed set of notes somebody else decided on, and
// the only question is where to put them. Everything here is about that
// question.
//
// The notes are held in beats, never in seconds, so the part follows the
// tempo slider, the tempo ramp and the count-in without knowing they
// exist. It is transposed when the tune is, so it stays in the key being
// played. And it is laid from the top of the form on every chorus rather
// than running on its own clock, because a part that drifts against the
// chart is worse than no part at all: after three choruses it is playing
// a bass line over the wrong chords and there is nothing on screen to say
// why.
//
// A part shorter than the form repeats inside it, which is what a two-bar
// riff wants. A part longer than the form is cut off at the end of the
// chorus, which loses something, so whoever chose it is told.

import 'dart:math' as math;

import 'midi_file.dart';

/// Which of the app's instruments plays an imported part.
///
/// The file may have been written for a trumpet. The app has a piano, a
/// guitar and a bass, and one of those three has to play it.
enum PartVoice {
  piano('Piano'),
  guitar('Guitar'),
  bass('Bass');

  const PartVoice(this.label);
  final String label;
}

/// A MIDI part chosen for a tune.
class ImportedPart {
  const ImportedPart({
    required this.name,
    required this.notes,
    required this.lengthBeats,
    this.voice = PartVoice.piano,
    this.transpose = 0,
    this.offsetBeats = 0,
  });

  /// Built from a track of a file, for a tune in [beatsPerBar].
  ///
  /// The repeat length is rounded up to a whole bar. A part whose last
  /// note is released halfway through the final bar is still a part that
  /// many bars long, and repeating it at the release instead would push
  /// it half a bar early every time round.
  factory ImportedPart.of(
    MidiPart part, {
    required int beatsPerBar,
    PartVoice voice = PartVoice.piano,
    String? name,
  }) {
    final bars = math.max(1, (part.lengthBeats / beatsPerBar).ceil());
    return ImportedPart(
      name: name ?? _nameOf(part),
      notes: part.notes,
      lengthBeats: (bars * beatsPerBar).toDouble(),
      voice: voice,
    );
  }

  /// What the mixer calls it.
  final String name;

  /// In beats from the start of the part, in playing order.
  final List<MidiNote> notes;

  /// How long before it comes round again, always a whole number of bars.
  final double lengthBeats;

  final PartVoice voice;

  /// Semitones, applied when the notes are laid out. The tune's own
  /// transposition rather than a setting of its own: a part follows the
  /// key being played.
  final int transpose;

  /// Where the part's first beat sits against the tune's, in beats.
  ///
  /// Nothing in a MIDI file says where the music starts, so a file with a
  /// pick-up, a count-in or a bar of silence at the front lands in the
  /// wrong place and the app cannot tell. This is how it gets moved:
  /// negative pulls the part earlier, which is what takes a count-in off
  /// the front.
  final double offsetBeats;

  bool get isEmpty => notes.isEmpty;

  /// How many bars it is, given a tune in [beatsPerBar].
  int bars(int beatsPerBar) => (lengthBeats / beatsPerBar).round();

  ImportedPart withVoice(PartVoice voice) => _copy(voice: voice);
  ImportedPart transposedBy(int semitones) => _copy(transpose: semitones);
  ImportedPart renamed(String name) => _copy(name: name);
  ImportedPart movedTo(double offsetBeats) => _copy(offsetBeats: offsetBeats);

  /// A different repeat length, in beats, kept to at least one bar.
  ///
  /// Taking a count-in off the front with [movedTo] does not shorten the
  /// part, so the two go together: a file of two bars of clicks and twelve
  /// bars of music is moved back eight beats and set to twelve bars, or it
  /// comes round two bars late every time after the first.
  ImportedPart repeatingEvery(double beats, {int beatsPerBar = 4}) =>
      _copy(lengthBeats: math.max(beatsPerBar.toDouble(), beats));

  ImportedPart _copy({
    String? name,
    PartVoice? voice,
    int? transpose,
    double? offsetBeats,
    double? lengthBeats,
  }) => ImportedPart(
    name: name ?? this.name,
    notes: notes,
    lengthBeats: lengthBeats ?? this.lengthBeats,
    voice: voice ?? this.voice,
    transpose: transpose ?? this.transpose,
    offsetBeats: offsetBeats ?? this.offsetBeats,
  );

  /// The notes as they stand once [offsetBeats] has been applied: one
  /// cycle of the part, measured from the top of its repeat.
  ///
  /// Moving the part trims it rather than only sliding it. Anything pushed
  /// before the start of the cycle is dropped and does not come back on
  /// the next time round, which is the whole point: a file of two bars of
  /// clicks and twelve of music, moved back eight beats, has to lose the
  /// clicks for good, not hear them again in bar three.
  List<MidiNote> get placed => [
    for (final note in notes)
      if (note.beat + offsetBeats >= 0 && note.beat + offsetBeats < lengthBeats)
        (
          pitch: note.pitch,
          beat: note.beat + offsetBeats,
          beats: note.beats,
          velocity: note.velocity,
        ),
  ];

  /// The part laid over [choruses] passes of a stretch [formBeats] long
  /// starting at [fromBeat] of the tune, in beats from the start of the
  /// run, transposed and ready to play.
  ///
  /// The part belongs to the tune, not to the stretch being played. It is
  /// measured from the tune's first beat and repeats every [lengthBeats]
  /// along it, and what comes out is the window of that which the loop is
  /// actually playing. So looping bars 7 and 8 gives the part's bars 7 and
  /// 8, the same two bars the band is comping, rather than its first two
  /// against the chart's seventh and eighth.
  ///
  /// It is never allowed to run on its own clock: see the note at the top
  /// of this file for what that would cost.
  List<MidiNote> laidOver({
    required int choruses,
    required double formBeats,
    double fromBeat = 0,
  }) {
    final cycle = placed;
    if (cycle.isEmpty || lengthBeats <= 0 || formBeats <= 0) return const [];
    final out = <MidiNote>[];
    final firstRound = (fromBeat / lengthBeats).floor();
    for (var chorus = 0; chorus < choruses; chorus++) {
      final top = chorus * formBeats;
      final end = top + formBeats;
      for (
        var round = firstRound;
        round * lengthBeats < fromBeat + formBeats;
        round++
      ) {
        for (final note in cycle) {
          // Where this note falls along the tune, and then where that is
          // in what is being played.
          final alongTune = round * lengthBeats + note.beat;
          if (alongTune < fromBeat || alongTune >= fromBeat + formBeats) {
            continue;
          }
          final beat = top + (alongTune - fromBeat);
          out.add((
            pitch: note.pitch + transpose,
            beat: beat,
            // A note that would ring past the end of the chorus is cut
            // there, so the next chorus starts clean rather than with the
            // last one still sounding underneath it.
            beats: math.min(note.beats, end - beat),
            velocity: note.velocity,
          ));
        }
      }
    }
    out.sort((a, b) => a.beat.compareTo(b.beat));
    return out;
  }

  /// How many notes land in each bar of a form [bars] long.
  ///
  /// For drawing the part against the chart, which is the only way anyone
  /// can see whether it starts where they think it does. Counting what
  /// [laidOver] actually produces rather than working it out again, so the
  /// picture cannot disagree with the playing.
  List<int> notesByBar({required int bars, required int beatsPerBar}) {
    final counts = List.filled(math.max(bars, 0), 0);
    if (counts.isEmpty) return counts;
    for (final note in laidOver(
      choruses: 1,
      formBeats: (bars * beatsPerBar).toDouble(),
    )) {
      final bar = note.beat ~/ beatsPerBar;
      if (bar >= 0 && bar < bars) counts[bar]++;
    }
    return counts;
  }

  /// The bars of a form [bars] long where the part starts again, so the
  /// picture can mark them.
  ///
  /// The repeat is measured from the tune's first bar whatever the offset
  /// is: moving a part moves its notes inside the cycle, it does not move
  /// the cycle.
  Set<int> repeatsAt({required int bars, required int beatsPerBar}) {
    if (lengthBeats <= 0 || bars <= 0) return const {};
    return {
      for (var beat = 0.0; beat < bars * beatsPerBar; beat += lengthBeats)
        beat ~/ beatsPerBar,
    };
  }

  /// Whether laying this part over a form [formBeats] long loses notes off
  /// the end. Worth saying out loud when it is true.
  bool overrunsForm(double formBeats) => lengthBeats > formBeats;

  Map<String, Object?> toJson() => {
    'name': name,
    'lengthBeats': lengthBeats,
    'offsetBeats': offsetBeats,
    'voice': voice.name,
    // Flat rather than a list of objects: a busy part is a few thousand
    // numbers and the key names would be most of the file.
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
  /// version writes, because a part is never worth losing a tune over.
  static ImportedPart? fromJson(Map<String, Object?> json) {
    final flat = json['notes'];
    final length = json['lengthBeats'];
    if (flat is! List || length is! num || flat.length % 4 != 0) return null;
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
    return ImportedPart(
      name: json['name'] as String? ?? 'Imported',
      notes: notes,
      lengthBeats: length.toDouble(),
      offsetBeats: (json['offsetBeats'] as num?)?.toDouble() ?? 0,
      voice: PartVoice.values.firstWhere(
        (value) => value.name == json['voice'],
        orElse: () => PartVoice.piano,
      ),
    );
  }
}

/// What to call a track that may or may not have named itself.
String _nameOf(MidiPart part) {
  if (part.name.isNotEmpty) return part.name;
  return 'Track ${part.track + 1}, channel ${part.channel + 1}';
}

/// Which of the three instruments a part is probably for, from where it
/// sits on the keyboard.
///
/// A guess, and offered as one: it saves picking the bass by hand for
/// every bass line, and is wrong harmlessly when it is wrong. Below the C
/// two octaves under middle C is where a bass line lives and almost
/// nothing else does.
PartVoice suggestedVoice(MidiPart part) {
  final range = part.range;
  if (range == null) return PartVoice.piano;
  final (low, high) = range;
  if (high <= 55) return PartVoice.bass;
  // A part that never plays two notes at once is more likely a line than
  // a comp, and a line in the middle of the instrument suits the guitar.
  return low >= 55 && high <= 88 && !_hasChords(part)
      ? PartVoice.guitar
      : PartVoice.piano;
}

/// Whether any two notes in [part] sound at the same time.
bool _hasChords(MidiPart part) {
  for (var i = 1; i < part.notes.length; i++) {
    final previous = part.notes[i - 1];
    if (part.notes[i].beat < previous.beat + previous.beats - 0.01) return true;
  }
  return false;
}
