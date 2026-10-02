// One way in, for anything a tune can take.
//
// A tune can take two kinds of file: a MIDI file to play alongside the
// band, and the audio of real players to replace it. They were two rows
// and two pickers, which asked somebody to classify their own file before
// the app would look at it. The file already says what it is.
//
// So: one row, one picker, and the app works out which sheet you wanted.
// A SoundFont arriving here is not an error either, it is just at the
// wrong door, and the answer says which door rather than no.
//
// The sheets themselves are untouched. They are the two most intricate
// screens in the app (stem matching, tempo checking, onset detection) and
// nothing here needed them changed, only told what had already been
// picked.

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../audio/what_file.dart';
import '../practice/practice_controller.dart';
import 'import_part_sheet.dart';
import 'import_recording_sheet.dart';

/// How a file is chosen. Tests hand in their own, because there is no
/// picker to tap in a widget test.
typedef PickFiles = Future<List<({String name, Uint8List bytes})>> Function();

Future<List<({String name, Uint8List bytes})>> _pickFiles() async {
  // Several at once, because a recorded band is three files and asking
  // for them one at a time would be three trips through the picker.
  final picked = await FilePicker.platform.pickFiles(
    withData: true,
    allowMultiple: true,
  );
  return [
    for (final file in picked?.files ?? const [])
      if (file.bytes case final bytes?) (name: file.name, bytes: bytes),
  ];
}

/// Picks a file and opens whichever sheet it belongs in.
Future<void> bringSomethingIn(
  BuildContext context,
  PracticeController controller, {
  PickFiles pick = _pickFiles,
}) async {
  final files = await pick();
  if (files.isEmpty || !context.mounted) return;

  // What the first one is decides where they all go. Several files only
  // happen for a recorded band, whose three stems arrive together.
  final kind = whatIsThisFile(files.first.bytes);
  switch (kind) {
    case FileKind.midi:
      await showImportPart(context, controller, first: files.first);
    case FileKind.wav:
      await showImportRecording(context, controller, first: files);
    case FileKind.soundFont:
    case FileKind.unknown:
      await _wrongDoor(context, files.first.name, kind);
  }
}

Future<void> _wrongDoor(BuildContext context, String name, FileKind kind) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(name),
        content: Text(
          kind == FileKind.soundFont
              ? 'That is a SoundFont. Sounds for the band go in from Settings, '
                    'under Imported Sounds, because they play on every tune '
                    'rather than this one.'
              : 'A tune can take a MIDI file to play alongside the band, or '
                    'WAV files of real players to replace it. That is neither.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Right'),
          ),
        ],
      ),
    );
