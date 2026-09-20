// Checks the built-in standards: every chart parses, no title appears
// twice, and each tune has what it needs. Prints one batch's tunes with
// their forms, for a read-through.
//
//   dart run tool/check_standards.dart        (everything)
//   dart run tool/check_standards.dart 3      (batch 3's tunes listed)

import 'dart:io';

import 'package:play_along/music/standards/batch_1.dart';
import 'package:play_along/music/standards/batch_2.dart';
import 'package:play_along/music/standards/batch_3.dart';
import 'package:play_along/music/standards/batch_4.dart';
import 'package:play_along/music/standards/batch_5.dart';
import 'package:play_along/music/standards/batch_6.dart';
import 'package:play_along/music/standards/batch_7.dart';
import 'package:play_along/music/standards/batch_8.dart';
import 'package:play_along/music/standards/batch_9.dart';
import 'package:play_along/music/standards/batch_10.dart';
import 'package:play_along/music/tune_library.dart';

/// A title with case, punctuation and a leading "The" or "A" ignored, so
/// near-duplicates ("The Song Is You" / "Song Is You") are caught.
String _normal(String title) => title
    .toLowerCase()
    .replaceAll(RegExp(r"[^a-z0-9 ]"), '')
    .replaceFirst(RegExp(r'^(the|a) '), '')
    .trim();

final _keyPattern = RegExp(r'^[A-G][♭♯]?( minor| Dorian)?$');

void main(List<String> args) {
  final batches = {
    1: standardsBatch1,
    2: standardsBatch2,
    3: standardsBatch3,
    4: standardsBatch4,
    5: standardsBatch5,
    6: standardsBatch6,
    7: standardsBatch7,
    8: standardsBatch8,
    9: standardsBatch9,
    10: standardsBatch10,
  };
  final errors = <String>[];

  // Duplicates across the whole library.
  final seen = <String, String>{};
  for (final tune in [...standards, ...practiceProgressions]) {
    final key = _normal(tune.title);
    if (seen.containsKey(key)) {
      errors.add('"${tune.title}" appears twice (also "${seen[key]}")');
    }
    seen[key] = tune.title;
  }

  final added = {for (final tunes in batches.values) ...tunes};
  for (final tune in standards) {
    final where = '"${tune.title}"';
    if (tune.composer == null || tune.composer!.isEmpty) {
      errors.add('$where has no composer');
    }
    // A traditional tune has no year to give: nobody wrote it down first.
    if (added.contains(tune) &&
        tune.year == null &&
        tune.composer != 'Traditional') {
      errors.add('\$where has no year');
    }
    if (!_keyPattern.hasMatch(tune.key)) {
      errors.add(
        '$where: key "${tune.key}" should be like "B♭", "C minor" or "D Dorian"',
      );
    }
    if (tune.defaultTempo < 40 || tune.defaultTempo > 320) {
      errors.add('$where: tempo ${tune.defaultTempo} is out of range');
    }
    if (tune.barCount < 8) errors.add('$where has only ${tune.barCount} bars');
    if (tune.sections.isNotEmpty && !tune.sections.containsKey(0)) {
      errors.add('$where: its first section should start on bar 1');
    }
    for (final bar in tune.bars) {
      if (bar.length > 4) errors.add('$where has a bar with over 4 chords');
    }
  }

  final batch = args.isEmpty ? null : int.parse(args.first);
  if (batch != null) {
    final tunes = batches[batch]!;
    stdout.writeln('Batch $batch: ${tunes.length} tunes');
    for (final tune in tunes) {
      final chords = {
        for (final bar in tune.bars)
          for (final slot in bar) slot.chord.display,
      };
      stdout.writeln(
        '  ${tune.title} — ${tune.key}, ${tune.defaultTempo} bpm, '
        '${tune.form.isEmpty ? 'no sections' : tune.form}, '
        '${tune.barCount} bars, ${chords.length} different chords',
      );
    }
  }
  stdout.writeln(
    'Library: ${standards.length} standards, '
    '${practiceProgressions.length} practice progressions',
  );
  if (errors.isEmpty) {
    stdout.writeln('All good.');
    return;
  }
  for (final error in errors) {
    stderr.writeln('✗ $error');
  }
  exitCode = 1;
}
