// Recording a lick.
//
// Its own small interface rather than the recorder itself, for two
// reasons. A test has no microphone and needs to hand over a recording it
// made; and what the lick screen wants is not what a take wants, which is
// a file kept in the library with a tune and a seed beside it. This one
// records to somewhere temporary and gives the bytes back, because the
// notes are what is kept and the audio is only the way to them.

import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../audio/take_recorder.dart';

abstract interface class LickTape {
  Future<bool> hasPermission();

  Future<void> start();

  /// Stops, and gives back what was recorded, or null if nothing was.
  Future<Uint8List?> stop();

  bool get isRecording;
}

/// The microphone, recording to a temporary file.
class DeviceLickTape implements LickTape {
  final _tape = TakeRecorder();
  String? _path;

  @override
  bool get isRecording => _tape.isRecording;

  @override
  Future<bool> hasPermission() => _tape.hasPermission();

  @override
  Future<void> start() async {
    final folder = await getTemporaryDirectory();
    final path =
        '${folder.path}/lick-${DateTime.now().microsecondsSinceEpoch}.wav';
    _path = path;
    await _tape.start(path);
  }

  @override
  Future<Uint8List?> stop() async {
    await _tape.stop();
    final path = _path;
    _path = null;
    if (path == null) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    final bytes = await file.readAsBytes();
    // The audio is the way to the notes, not the thing being kept, so it
    // does not outlive the reading of it unless somebody saves it.
    try {
      await file.delete();
    } catch (_) {}
    return bytes;
  }

  Future<void> dispose() => _tape.dispose();
}
