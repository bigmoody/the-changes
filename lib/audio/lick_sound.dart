// Hearing a lick back.
//
// Two jobs, and they are the same job. Just after catching one, playing
// it back is how you find out whether the app heard you: a reading can
// be wrong, and the fastest way to know is to listen to it rather than
// to read it. Then, going round the keys, it is how you find the phrase
// in a key you have never played it in, which for most people is by ear
// long before it is from the stave.
//
// It plays the notes that were written down, not the recording that was
// made. That is the point: what you hear is exactly what the app kept,
// so anything wrong with it is something you can see on the stave and
// fix, rather than something hiding between the two.

import 'dart:typed_data';

import '../music/lick.dart';
import 'backing_synth.dart';
import 'sample_bank.dart';

/// The lick's notes as a snippet, [semitones] from where it was played
/// and at [tempo].
///
/// The notes are held in beats, so the tempo is whatever is being worked
/// at rather than whatever it happened to be caught at, and a phrase
/// written on a swung grid swings on its own without being told to.
List<SnippetNote> lickSnippetNotes(
  Lick lick, {
  int semitones = 0,
  required int tempo,
}) {
  if (tempo <= 0) return const [];
  final perBeat = 60 / tempo;
  return [
    for (final note in lick.notesUp(semitones))
      (
        pitch: note.pitch,
        start: note.beat * perBeat,
        length: note.beats * perBeat,
        velocity: note.velocity,
        // A lick is a line, and a line is not the bass player's.
        bass: false,
      ),
  ];
}

/// The lick as a few seconds of audio, or null when it cannot be made.
///
/// Null rather than silence when the recorded instruments have not
/// finished loading, so the screen can say so instead of appearing to
/// play nothing.
Uint8List? lickSnippet(
  Lick lick,
  SampleBank? bank, {
  int semitones = 0,
  required int tempo,
  bool guitar = false,
}) {
  final notes = lickSnippetNotes(lick, semitones: semitones, tempo: tempo);
  if (bank == null || notes.isEmpty) return null;
  return renderSnippet(bank, notes, guitar: guitar);
}
