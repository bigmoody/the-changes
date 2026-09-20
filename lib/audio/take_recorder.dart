// Recording you while the band plays.
//
// The microphone is started at the moment the band's first beat sounds, so
// the recording begins exactly where the form does. Nothing else needs
// lining up later: playing it back puts the band around it from the top.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../practice/take_store.dart';

class TakeRecorder {
  late final _recorder = AudioRecorder();
  var _opened = false;
  final _clock = Stopwatch();

  bool get isRecording => _clock.isRunning;

  /// How long the take is so far.
  Duration get length => _clock.elapsed;

  Future<bool> hasPermission() {
    _opened = true;
    return _recorder.hasPermission();
  }

  /// Starts recording to [path]. Uncompressed, because it's played back
  /// through the same engine as the band and that reads plain WAV.
  Future<void> start(String path) async {
    _opened = true;
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 44100,
        numChannels: 1,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
        iosConfig: IosRecordConfig(
          categoryOptions: [
            IosAudioCategoryOption.defaultToSpeaker,
            IosAudioCategoryOption.allowBluetooth,
            IosAudioCategoryOption.allowBluetoothA2DP,
            // Or starting the microphone would silence the band.
            IosAudioCategoryOption.mixWithOthers,
          ],
        ),
      ),
      path: path,
    );
    _clock
      ..reset()
      ..start();
  }

  /// Stops, and says how long the take was.
  Future<Duration> stop() async {
    final length = _clock.elapsed;
    _clock.stop();
    try {
      if (_opened) await _recorder.stop();
    } catch (e) {
      debugPrint('Could not stop the recording: $e');
    }
    return length;
  }

  Future<void> dispose() async {
    await stop();
    if (_opened) await _recorder.dispose();
  }
}

/// Takes kept in the app's own documents folder.
class DeviceTakeFiles implements TakeFiles {
  Future<Directory> _folder() async {
    final documents = await getApplicationDocumentsDirectory();
    final folder = Directory('${documents.path}/takes');
    if (!folder.existsSync()) await folder.create(recursive: true);
    return folder;
  }

  @override
  Future<({String path, String name})> place(String id) async {
    final folder = await _folder();
    final name = '$id.wav';
    return (path: '${folder.path}/$name', name: name);
  }

  @override
  Future<String?> pathOf(String name) async {
    final folder = await _folder();
    final file = File('${folder.path}/$name');
    return file.existsSync() ? file.path : null;
  }

  @override
  Future<void> remove(String name) async {
    final folder = await _folder();
    final file = File('${folder.path}/$name');
    if (file.existsSync()) await file.delete();
  }
}
