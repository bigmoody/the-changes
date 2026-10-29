// The app's home: five tabs along the bottom, one job each.
//
//   Tunes       the standards and practice progressions (the tuner opens
//               from the tuning fork at the top)
//   Practice    a roadmap to playing jazz, and today's routine on it
//   My Changes  progressions the player has written
//   Learn       the chord quiz, and the pages to look things up in:
//               chord symbols, chord tones, scales and modes
//   Settings    instrument, what shows while playing, sound, about
//
// Playing a tune opens full screen over the tabs, so the chart gets all the
// room.

import 'package:flutter/material.dart';

import '../audio/practice_player.dart';
import '../library/library_store.dart';
import '../settings/app_settings.dart';
import '../practice/take_store.dart';
import '../practice/part_store.dart';
import '../practice/phrase_store.dart';
import '../practice/soundfont_store.dart';
import '../practice/recording_store.dart';
import '../practice/roadmap_progress.dart';
import '../settings/progression_store.dart';
import 'learn_page.dart';
import 'my_progressions_page.dart';
import 'practice_page.dart';
import 'settings_page.dart';
import 'tunes_page.dart';

enum HomeTab { tunes, practice, mine, learn, settings }

class HomeScreen extends StatefulWidget {
  const HomeScreen({
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
    this.initialTab = HomeTab.tunes,
  });

  /// Where somebody is on the Practice tab's roadmap. Tests that do not
  /// look at it leave it out, and get one that is kept nowhere.
  final RoadmapProgress? roadmap;

  final PracticePlayer player;
  final AppSettings settings;
  final ProgressionStore progressions;
  final LibraryStore library;
  final TakeStore takes;
  final PartStore partStore;

  /// Where recordings of real players are kept.
  final RecordingStore recordingStore;

  /// Somebody's own book of phrases.
  final PhraseStore phrases;

  /// The SoundFont somebody imported, if any.
  final SoundFontStore soundFont;
  final String? audioError;
  final HomeTab initialTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late var _tab = widget.initialTab;
  late final _roadmap = widget.roadmap ?? RoadmapProgress.inMemory();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Each tab keeps its place (a search, a scroll position) while you're
      // away. (The quiz opens from Learn, so every round starts fresh.)
      body: IndexedStack(
        index: _tab.index,
        children: [
          TunesPage(
            player: widget.player,
            settings: widget.settings,
            progressions: widget.progressions,
            library: widget.library,
            takes: widget.takes,
            partStore: widget.partStore,
            recordingStore: widget.recordingStore,
            audioError: widget.audioError,
          ),
          PracticePage(
            progress: _roadmap,
            player: widget.player,
            settings: widget.settings,
            library: widget.library,
            progressions: widget.progressions,
            takes: widget.takes,
            partStore: widget.partStore,
            recordingStore: widget.recordingStore,
          ),
          MyProgressionsPage(
            player: widget.player,
            settings: widget.settings,
            progressions: widget.progressions,
            library: widget.library,
            takes: widget.takes,
            partStore: widget.partStore,
            recordingStore: widget.recordingStore,
          ),
          LearnPage(
            player: widget.player,
            settings: widget.settings,
            phrases: widget.phrases,
          ),
          SettingsPage(
            player: widget.player,
            settings: widget.settings,
            progressions: widget.progressions,
            library: widget.library,
            takes: widget.takes,
            soundFont: widget.soundFont,
          ),
        ],
      ),
      // Ruled off from the page above it, like the foot of a chart.
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _tab.index,
          onDestinationSelected: (index) =>
              setState(() => _tab = HomeTab.values[index]),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.library_music_outlined),
              selectedIcon: Icon(Icons.library_music),
              label: 'Tunes',
            ),
            NavigationDestination(
              icon: Icon(Icons.trending_up),
              selectedIcon: Icon(Icons.trending_up),
              label: 'Practice',
            ),
            NavigationDestination(
              icon: Icon(Icons.edit_note_outlined),
              selectedIcon: Icon(Icons.edit_note),
              label: 'My Changes',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'Learn',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
