// The Learn tab: everything for learning the language rather than playing
// a tune — a quiz to drill chords against the clock, and the pages to look
// things up in. Each opens full screen and starts fresh every time, so a
// quiz is always a new round.

import 'package:flutter/material.dart';

import '../audio/practice_player.dart';
import '../settings/app_settings.dart';
import '../theme.dart';
import 'chord_identifier_screen.dart';
import 'chord_reference_screen.dart';
import 'chord_tones_reference_screen.dart';
import 'chord_tones_screen.dart';
import 'guitar_chords_screen.dart';
import 'metronome_screen.dart';
import 'reading_music_screen.dart';
import 'scales_reference_screen.dart';
import 'stave_figure.dart';
import 'tunes_page.dart' show SectionHeader;

class LearnPage extends StatelessWidget {
  const LearnPage({super.key, required this.player, required this.settings});

  final PracticePlayer player;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    void open(Widget page) =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => page));

    return Scaffold(
      appBar: AppBar(title: const Text('Learn')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const SectionHeader('Practise'),
          _LearnCard(
            key: const ValueKey('learn-quiz'),
            icon: Icons.timer_outlined,
            title: 'Chord Quiz',
            subtitle:
                'Spell chords and find their tones against the clock, '
                'through ii–V–Is or any chord',
            onTap: () =>
                open(ChordTonesScreen(player: player, settings: settings)),
          ),
          _LearnCard(
            key: const ValueKey('learn-metronome'),
            icon: Icons.av_timer,
            title: 'Metronome',
            subtitle:
                'Any tempo and time signature, with the beat divided '
                'as you like it',
            onTap: () =>
                open(MetronomeScreen(player: player, settings: settings)),
          ),
          _LearnCard(
            key: const ValueKey('learn-identify'),
            icon: Icons.hearing,
            title: 'Chord Identifier',
            subtitle:
                'Play a chord on the guitar or the keys and the app '
                'names it',
            onTap: () =>
                open(ChordIdentifierScreen(player: player, settings: settings)),
          ),
          const SectionHeader('Look It Up'),
          _LearnCard(
            key: const ValueKey('learn-reading'),
            music: Clef.treble.glyph,
            title: 'Reading Music',
            subtitle:
                'The stave, the clefs, note values, rests and the rest of '
                'the marks on the page',
            onTap: () => open(const ReadingMusicScreen()),
          ),
          _LearnCard(
            // A chord symbol, lettered as on the chart.
            symbol: 'ø7',
            title: 'Chord Symbols',
            subtitle: 'What Δ7, ø, alt and the rest mean',
            onTap: () => open(const ChordReferenceScreen()),
          ),
          _LearnCard(
            key: const ValueKey('learn-guitar-chords'),
            icon: Icons.grid_on,
            title: 'Guitar Chords',
            subtitle: 'Every way to play each chord up the neck, to hear',
            onTap: () =>
                open(GuitarChordsScreen(player: player, settings: settings)),
          ),
          _LearnCard(
            icon: Icons.piano_outlined,
            title: 'Chord Tones',
            subtitle:
                'The notes in every chord, in any key — on the keys, '
                'guitar and bass',
            onTap: () => open(
              ChordTonesReferenceScreen(player: player, settings: settings),
            ),
          ),
          _LearnCard(
            icon: Icons.stairs_outlined,
            title: 'Scales & Modes',
            subtitle: 'Every mode, in any key, to hear',
            onTap: () =>
                open(ScalesReferenceScreen(player: player, settings: settings)),
          ),
        ],
      ),
    );
  }
}

class _LearnCard extends StatelessWidget {
  const _LearnCard({
    super.key,
    this.icon,
    this.symbol,
    this.music,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  /// What's in the square beside the title: an icon, or a few letters of
  /// the chart's hand lettering.
  final IconData? icon;
  final String? symbol;

  /// A notation symbol, in the music font.
  final String? music;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: switch ((symbol, music)) {
                    (final String written, _) => Text(
                      written,
                      style: handLettered(
                        TextStyle(fontSize: 22, color: scheme.onSurface),
                      ),
                    ),
                    (_, final String drawn) => Text(
                      drawn,
                      style: TextStyle(
                        fontFamily: musicFont,
                        fontSize: 30,
                        height: 1,
                        color: scheme.onSurface,
                      ),
                    ),
                    _ => Icon(icon, color: scheme.onSurface),
                  },
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
