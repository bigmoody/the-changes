// The Learn tab: everything for learning the language rather than playing
// a tune: a quiz to drill chords against the clock, and the pages to look
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
import 'enclosures_screen.dart';
import 'guide_tones_screen.dart';
import 'listening_screen.dart';
import 'metronome_screen.dart';
import 'modal_screen.dart';
import 'reading_music_screen.dart';
import 'rhythm_changes_screen.dart';
import 'bebop_scales_screen.dart';
import 'number_patterns_screen.dart';
import 'passing_chords_screen.dart';
import 'phrasing_screen.dart';
import 'trading_screen.dart';
import 'tritone_subs_screen.dart';
import 'side_by_side_screen.dart';
import 'where_am_i_screen.dart';
import 'scales_reference_screen.dart';
import 'comping_screen.dart';
import 'stave_figure.dart';
import 'swing_screen.dart';
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
                'Any tempo and time signature, and it can click on 2 and '
                '4, or drop out and leave the time to you',
            onTap: () =>
                open(MetronomeScreen(player: player, settings: settings)),
          ),
          _LearnCard(
            key: const ValueKey('learn-where-am-i'),
            icon: Icons.explore_outlined,
            title: 'Where Am I?',
            subtitle:
                'The band plays from the top and cuts out: say which bar '
                'it stopped in',
            onTap: () =>
                open(WhereAmIScreen(player: player, settings: settings)),
          ),
          _LearnCard(
            key: const ValueKey('learn-trading'),
            icon: Icons.swap_vert,
            title: 'Trading Fours',
            subtitle:
                'They play four, you play four, round and round: the '
                'oldest way of learning this music',
            onTap: () =>
                open(TradingScreen(player: player, settings: settings)),
          ),
          _LearnCard(
            key: const ValueKey('learn-side-by-side'),
            icon: Icons.compare_arrows,
            title: 'Side by Side',
            subtitle:
                'Two or three versions of the same form, bar against bar: '
                'what bebop did to the blues, in one look',
            onTap: () =>
                open(SideBySideScreen(player: player, settings: settings)),
          ),
          _LearnCard(
            key: const ValueKey('learn-bebop-scales'),
            icon: Icons.stairs,
            title: 'Bebop Scales',
            subtitle:
                'The extra note that keeps the chord tones on the beat, '
                'and what happens without it',
            onTap: () =>
                open(BebopScalesScreen(player: player, settings: settings)),
          ),
          _LearnCard(
            key: const ValueKey('learn-number-patterns'),
            icon: Icons.pin_outlined,
            title: 'Number Patterns',
            subtitle:
                'One shape (1-2-3-5) run through the changes, so your '
                'hand stays still while the notes move',
            onTap: () =>
                open(NumberPatternsScreen(player: player, settings: settings)),
          ),
          _LearnCard(
            key: const ValueKey('learn-tritone-subs'),
            icon: Icons.swap_horiz,
            title: 'Tritone Subs',
            subtitle:
                'Why one dominant can stand in for another: they are the '
                'same two notes in the middle',
            onTap: () =>
                open(TritoneSubsScreen(player: player, settings: settings)),
          ),
          _LearnCard(
            key: const ValueKey('learn-passing'),
            icon: Icons.more_horiz,
            title: 'Between the Chords',
            subtitle:
                'The chords that are not on the chart: what you can put '
                'in the gap, and why it fits',
            onTap: () =>
                open(PassingChordsScreen(player: player, settings: settings)),
          ),
          _LearnCard(
            key: const ValueKey('learn-phrasing'),
            icon: Icons.graphic_eq,
            title: 'Where Phrases Start',
            subtitle:
                'The same four notes moved around the bar: when a line '
                'comes in, and which notes get the weight',
            onTap: () =>
                open(PhrasingScreen(player: player, settings: settings)),
          ),
          _LearnCard(
            key: const ValueKey('learn-swing'),
            icon: Icons.waves,
            title: 'Swing',
            subtitle:
                'How late the "and" really is, and why it is not the '
                'triplet you were taught, except at one tempo',
            onTap: () => open(SwingScreen(player: player, settings: settings)),
          ),
          _LearnCard(
            key: const ValueKey('learn-rhythm-changes'),
            icon: Icons.repeat,
            title: 'Rhythm Changes',
            subtitle:
                'The other form worth knowing by heart, and the eight '
                'bars of it to learn first',
            onTap: () =>
                open(RhythmChangesScreen(player: player, settings: settings)),
          ),
          _LearnCard(
            key: const ValueKey('learn-comping'),
            icon: Icons.piano,
            title: 'Comping',
            subtitle:
                'When to put the chord down, and when to leave the bar '
                'alone: the other half of playing changes',
            onTap: () =>
                open(CompingScreen(player: player, settings: settings)),
          ),
          _LearnCard(
            key: const ValueKey('learn-modal'),
            icon: Icons.blur_on,
            title: 'Modal',
            subtitle:
                'What to do when one chord lasts sixteen bars, and the '
                'question the chart will not answer',
            onTap: () => open(ModalScreen(player: player, settings: settings)),
          ),
          _LearnCard(
            key: const ValueKey('learn-enclosures'),
            icon: Icons.all_inclusive,
            title: 'Enclosures',
            subtitle:
                'Going round a note before landing on it: five shapes, on '
                'the stave and under the fingers',
            onTap: () =>
                open(EnclosuresScreen(player: player, settings: settings)),
          ),
          _LearnCard(
            key: const ValueKey('learn-guide-tones'),
            icon: Icons.linear_scale,
            title: 'Guide Tones',
            subtitle:
                'The two notes that make the changes audible, held through '
                'a progression while everything else moves',
            onTap: () =>
                open(GuideTonesScreen(player: player, settings: settings)),
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
          _LearnCard(
            key: const ValueKey('learn-listening'),
            icon: Icons.album_outlined,
            title: 'Listening',
            subtitle:
                'The records these tunes come from, because a chart is a '
                'reminder of a performance and not the tune',
            onTap: () => open(const ListeningScreen()),
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
                'The notes in every chord, in any key: on the keys, '
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
