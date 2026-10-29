// The Changes: a practice app for musicians.
//
// Folder guide:
//   music/    chords, tunes and loop ranges (pure Dart, no UI)
//   audio/    generates backing tracks and plays them
//   practice/ the practice screen's state
//   screens/  what you see

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio/practice_player.dart';
import 'audio/recording_files.dart';
import 'audio/take_recorder.dart';
import 'audio/sample_bank.dart';
import 'library/library_store.dart';
import 'screens/home_screen.dart';
import 'screens/hush_snippets.dart';
import 'screens/note_ink.dart';
import 'screens/snippet_controls.dart';
import 'screens/sound_shelf.dart' show SoundFonts;
import 'settings/app_settings.dart';
import 'practice/take_store.dart';
import 'practice/part_store.dart';
import 'practice/phrase_store.dart';
import 'practice/soundfont_store.dart';
import 'practice/recording_store.dart';
import 'settings/progression_store.dart';
import 'practice/roadmap_progress.dart';
import 'theme.dart';
import 'library/shared_links.dart';
import 'screens/import_screen.dart';

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
  final phrases = await PhraseStore.load(
    files: DeviceRecordingFiles('phrases'),
  );
  final soundFont = await SoundFontStore.load(
    files: DeviceRecordingFiles('soundfont'),
  );
  final roadmap = await RoadmapProgress.load();
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
      phrases: phrases,
      soundFont: soundFont,
      roadmap: roadmap,
      audioError: audioError,
    ),
  );

  // Load the recorded instruments after the first screen appears, so launch
  // isn't slowed down. Until they're ready the band uses synthesised sounds.
  try {
    final stopwatch = Stopwatch()..start();
    final bank = await SampleBank.load(
      (path) async =>
          (await rootBundle.load('assets/sounds/$path')).buffer.asUint8List(),
    );
    // Whatever SoundFont somebody imported rides along with the bank, and
    // is put back whenever they change it. The bank is what goes to the
    // render isolate, so this is the only place it needs to be.
    player.samples = bank.withImported(
      chords: soundFont.chords,
      bass: soundFont.bass,
      arpeggio: soundFont.arpeggio,
      drums: soundFont.drums,
    );
    soundFont.addListener(
      () => player.samples = bank.withImported(
        chords: soundFont.chords,
        bass: soundFont.bass,
        arpeggio: soundFont.arpeggio,
        drums: soundFont.drums,
      ),
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
    required this.phrases,
    required this.soundFont,
    this.roadmap,
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
  final PhraseStore phrases;

  /// The SoundFont somebody imported, if any.
  final SoundFontStore soundFont;

  /// Where somebody is on the Practice tab's roadmap.
  final RoadmapProgress? roadmap;
  final String? audioError;

  @override
  Widget build(BuildContext context) {
    // Rebuilt when the settings change, because the paper is one of them
    // and a new paper is a new theme for the whole app.
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: 'The Changes',
        debugShowCheckedModeBanner: false,
        // Leaving a page stops whatever it was playing you.
        navigatorObservers: [HushSnippets(player)],
        // Held so a chart shared from another app can be opened from
        // above the navigator, where there is no route to push from.
        navigatorKey: _navigator,
        // A chosen paper is the paper, in the dark as well: it already has
        // its own lightness, and a tune does not change colour because the
        // sun went down.
        theme: appTheme(Brightness.light, paper: settings.paper),
        darkTheme: appTheme(Brightness.dark, paper: settings.paper),
        // Above the navigator rather than around the home screen, so that
        // a chord tone named three pushes deep is still in the colour its
        // reader sees it in.
        //
        // The SoundFonts too, so the mixer can offer them from any tune
        // without every screen on the way handing them down.
        builder: (context, child) => SoundFonts(
          store: soundFont,
          child: NoteInk(
            settings: settings,
            child: _Handover(
              progressions: progressions,
              // Pause and Stop for any example that is playing, over
              // whichever screen played it, clear of the buttons that
              // sit along the bottom of most of them.
              child: Stack(
                children: [
                  child ?? const SizedBox(),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: MediaQuery.paddingOf(context).bottom + 84,
                    child: Center(child: SnippetControls(player: player)),
                  ),
                ],
              ),
            ),
          ),
        ),
        home: HomeScreen(
          player: player,
          settings: settings,
          progressions: progressions,
          library: library,
          takes: takes,
          partStore: partStore,
          recordingStore: recordingStore,
          phrases: phrases,
          soundFont: soundFont,
          roadmap: roadmap,
          audioError: audioError,
        ),
      ),
    );
  }
}

/// The navigator, reached from outside any route.
final _navigator = GlobalKey<NavigatorState>();

/// Opens Import when a chart arrives from another app.
///
/// Sits above the navigator rather than on a screen, because a share can
/// land at any moment, including while the app is starting, and the
/// screen it should open is not the one you happen to be looking at.
class _Handover extends StatefulWidget {
  const _Handover({required this.progressions, required this.child});

  final ProgressionStore progressions;
  final Widget child;

  @override
  State<_Handover> createState() => _HandoverState();
}

class _HandoverState extends State<_Handover> {
  late final SharedLinks _links;

  /// Whether an import opened by a share is already up. A second share
  /// while the first is still being chosen from replaces it rather than
  /// stacking a second one behind it.
  var _open = false;

  @override
  void initState() {
    super.initState();
    _links = SharedLinks()..onText = _handed;
    // Whatever opened the app, if a share did. It arrives before any of
    // this is listening, so the native side holds it until asked.
    unawaited(
      _links.whatStartedUs().then((text) {
        if (text != null) _handed(text);
      }),
    );
  }

  @override
  void dispose() {
    _links.dispose();
    super.dispose();
  }

  void _handed(String text) {
    final navigator = _navigator.currentState;
    if (navigator == null) return;
    if (_open) navigator.pop();
    _open = true;
    unawaited(
      navigator
          .push(
            MaterialPageRoute<int>(
              builder: (_) =>
                  ImportScreen(store: widget.progressions, handed: text),
            ),
          )
          .then((_) => _open = false),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
