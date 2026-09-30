import 'package:flutter/material.dart';

import '../audio/practice_player.dart';
import '../library/library_store.dart';
import '../music/chord_drill.dart';
import '../music/tune.dart';
import '../practice/soundfont_store.dart';
import '../practice/take_store.dart';
import '../settings/app_settings.dart';
import '../settings/progression_store.dart';
import 'about.dart';
import 'backup_screen.dart';
import 'import_soundfont_screen.dart';
import 'chart_instrument_button.dart';
import 'tunes_page.dart' show SectionHeader;

/// The Settings tab: everything that holds across the whole app, gathered
/// in one place so the other screens can stay clear. The Learn tab is
/// where things are looked up: chord symbols, tones, scales.
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.player,
    required this.settings,
    required this.progressions,
    required this.library,
    this.takes,
    this.soundFont,
  });

  final PracticePlayer player;
  final AppSettings settings;
  final ProgressionStore progressions;
  final LibraryStore library;
  final TakeStore? takes;

  /// Where an imported SoundFont lives. Without it the row that imports
  /// one is not offered, which is what tests that do not care about sound
  /// get.
  final SoundFontStore? soundFont;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const SectionHeader('Your Instrument'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: InstrumentKeyPicker(
                instrument: settings.instrument,
                onChanged: settings.setInstrument,
                showExamples: true,
              ),
            ),
            const _Note('The band always plays at concert pitch.'),
            const SectionHeader('While Playing'),
            _ChoiceTile<ChordDiagram>(
              icon: Icons.piano_outlined,
              title: 'Fingering Diagram',
              value: settings.diagram,
              options: ChordDiagram.values,
              label: (diagram) => diagram.label,
              onChanged: settings.setDiagram,
            ),
            _ChoiceTile<ChordAid>(
              icon: Icons.school_outlined,
              title: 'Under the Chords',
              value: settings.chordAid,
              options: ChordAid.values,
              label: (aid) => aid.label,
              onChanged: settings.setChordAid,
            ),
            const _Note(
              'A small line under each chord on the chart. The numbers say '
              'what the chord is in the key, so you learn the shape of a '
              'tune rather than a list of names; the guide tones are the '
              '3rd and 7th, the notes that move least between changes.',
            ),
            _ChoiceTile<DrillTarget?>(
              icon: Icons.gps_fixed,
              title: 'Aim For',
              value: settings.aimFor,
              options: [null, ...DrillTarget.values],
              label: (target) => target?.label ?? 'Off',
              onChanged: settings.setAimFor,
            ),
            const SectionHeader('Sound'),
            _ChoiceTile<Comping>(
              icon: Icons.piano_outlined,
              title: 'Chords Played By',
              value: settings.comping,
              options: Comping.values,
              label: (comping) => comping.label,
              onChanged: settings.setComping,
            ),
            _ChoiceTile<Comping>(
              icon: Icons.music_note_outlined,
              title: 'Arpeggios Played On',
              value: settings.arpeggioSound,
              options: Comping.values,
              label: (sound) => sound.label,
              onChanged: settings.setArpeggioSound,
            ),
            if (soundFont case final store?)
              ListenableBuilder(
                listenable: store,
                builder: (context, _) => ListTile(
                  key: const ValueKey('import-soundfont'),
                  leading: const Icon(Icons.graphic_eq),
                  title: const Text('Import a Sound'),
                  subtitle: Text(
                    store.name == null
                        ? 'Play the chords with a SoundFont of your own'
                        : '${store.name} is ready, under Chords Played By',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ImportSoundFontScreen(store: store),
                    ),
                  ),
                ),
              ),
            SwitchListTile(
              secondary: const Icon(Icons.queue_music),
              title: const Text('Keep Other Apps Playing'),
              subtitle: const Text(
                'Play along with Spotify, Apple Music or a video while the '
                'band plays',
              ),
              value: settings.mixWithOthers,
              onChanged: (value) async {
                await settings.setMixWithOthers(value);
                await player.setMixWithOthers(value);
              },
            ),
            const SectionHeader('Your Library'),
            ListTile(
              key: const ValueKey('backup'),
              leading: const Icon(Icons.cloud_upload_outlined),
              title: const Text('Back Up & Restore'),
              subtitle: const Text(
                'Save your progressions and setlists somewhere safe',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                final came = await Navigator.of(context).push<int>(
                  MaterialPageRoute(
                    builder: (_) => BackupScreen(
                      progressions: progressions,
                      library: library,
                      takeCount: takes?.all.length ?? 0,
                    ),
                  ),
                );
                if (came == null) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      came == 1
                          ? 'Restored 1 progression'
                          : 'Restored $came progressions',
                    ),
                  ),
                );
              },
            ),
            const SectionHeader('About'),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About & Credits'),
              onTap: () => showAboutTheChanges(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A setting with a few options: shows the current one, and a tap opens
/// the list. Holds up at any text size, unlike a drop-down squeezed beside
/// the title.
class _ChoiceTile<T> extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.options,
    required this.label,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final T value;
  final List<T> options;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(label(value)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                for (final option in options)
                  ListTile(
                    leading: Icon(option == value ? Icons.check : null),
                    title: Text(label(option)),
                    selected: option == value,
                    onTap: () {
                      onChanged(option);
                      Navigator.of(context).pop();
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
