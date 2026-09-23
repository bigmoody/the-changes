// The Changes: a practice app for musicians.
//
// Folder guide:
//   music/    chords, tunes and loop ranges (pure Dart, no UI)
//   audio/    generates backing tracks and plays them
//   practice/ the practice screen's state
//   screens/  what you see

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio/practice_player.dart';
import 'audio/recording_files.dart';
import 'audio/take_recorder.dart';
import 'audio/sample_bank.dart';
import 'library/library_store.dart';
import 'screens/home_screen.dart';
import 'settings/app_settings.dart';
import 'practice/take_store.dart';
import 'practice/part_store.dart';
import 'practice/recording_store.dart';
import 'settings/progression_store.dart';
import 'theme.dart';

Future<void> main() async {
  // Needed before talking to native code (the audio engine) in main().
  WidgetsFlutterBinding.ensureInitialized();

  final settings = await AppSettings.load();
  final progressions = await ProgressionStore.load();
  final library = await LibraryStore.load();
  final takes = await TakeStore.load(files: DeviceTakeFiles());
  final partStore = await PartStore.load();
  final recordingStore = await RecordingStore.load(
    files: DeviceRecordingFiles(),
  );
  final player = PracticePlayer();
  String? audioError;
  try {
    await player.init(mixWithOthers: settings.mixWithOthers);
  } catch (e) {
    audioError = '$e';
  }

  runApp(
    TheChangesApp(
      player: player,
      settings: settings,
      progressions: progressions,
      library: library,
      takes: takes,
      partStore: partStore,
      recordingStore: recordingStore,
      audioError: audioError,
    ),
  );

  // Load the recorded instruments after the first screen appears, so launch
  // isn't slowed down. Until they're ready the band uses synthesised sounds.
  try {
    final stopwatch = Stopwatch()..start();
    player.samples = await SampleBank.load(
      (path) async =>
          (await rootBundle.load('assets/sounds/$path')).buffer.asUint8List(),
    );
    debugPrint(
      'Loaded instrument samples in ${stopwatch.elapsedMilliseconds} ms',
    );
  } catch (e) {
    debugPrint('Could not load instrument samples: $e');
  }
}

class TheChangesApp extends StatelessWidget {
  const TheChangesApp({
    super.key,
    required this.player,
    required this.settings,
    required this.progressions,
    required this.library,
    required this.takes,
    required this.partStore,
    required this.recordingStore,
    this.audioError,
  });

  final PracticePlayer player;
  final AppSettings settings;
  final ProgressionStore progressions;
  final LibraryStore library;
  final TakeStore takes;
  final PartStore partStore;

  /// Where recordings of real players are kept.
  final RecordingStore recordingStore;
  final String? audioError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Changes',
      debugShowCheckedModeBanner: false,
      theme: appTheme(Brightness.light),
      darkTheme: appTheme(Brightness.dark),
      home: HomeScreen(
        player: player,
        settings: settings,
        progressions: progressions,
        library: library,
        takes: takes,
        partStore: partStore,
        recordingStore: recordingStore,
        audioError: audioError,
      ),
    );
  }
}
