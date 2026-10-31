// How It Works: every part of the app in a few plain steps, opened from
// the top of Settings.
//
// Written the way you would explain it to someone sitting next to you:
// where the button is, what to tap, what happens. One section per tab or
// per kind of job, each folded shut so the page reads as a list of what
// the app can do before it reads as instructions.

import 'package:flutter/material.dart';

import '../theme.dart';

typedef _Topic = ({String title, List<String> steps});
typedef _Section = ({String title, IconData icon, List<_Topic> topics});

const _sections = <_Section>[
  (
    title: 'Getting Around',
    icon: Icons.explore_outlined,
    topics: [
      (
        title: 'The Five Tabs',
        steps: [
          'Tunes: the standards and practice progressions to play over.',
          'Practice: a roadmap and a daily routine to work through.',
          'My Changes: progressions you write or import yourself.',
          'Learn: lessons, exercises and pages to look things up in.',
          'Settings: your instrument, what shows while playing, sound and '
              'backups.',
          'Tap the tab you are already on to go back to its first page.',
        ],
      ),
      (
        title: 'Pause and Stop',
        steps: [
          'Anything that plays an example shows a dark bar near the bottom '
              'of the screen.',
          'Tap Pause to hold it, Play to carry on, Stop to end it.',
        ],
      ),
    ],
  ),
  (
    title: 'Finding a Tune',
    icon: Icons.library_music_outlined,
    topics: [
      (
        title: 'Search and Sort',
        steps: [
          'On the Tunes tab, type a title, composer or key in the search '
              'box.',
          'Use the genre chips to narrow the list, and Sort to change the '
              'order.',
          'Tap Starred to see only the tunes you have starred.',
        ],
      ),
      (
        title: 'Just Play Something',
        steps: [
          'Tap the dice at the top of the Tunes tab and the app picks a tune '
              'for you.',
        ],
      ),
      (
        title: 'Where to Start',
        steps: [
          'Tap the signpost at the top of the Tunes tab for an order to learn '
              'the standards in, easiest first.',
        ],
      ),
      (
        title: 'Setlists',
        steps: [
          'Tap the list button at the top of the Tunes tab to make a setlist '
              'for a gig or a lesson.',
          'Add a tune to one from the tune itself: the three dots, then Add '
              'to Setlist.',
        ],
      ),
      (
        title: 'Tuner',
        steps: [
          'Tap the tuning fork at the top of the Tunes tab.',
          'Play a note and it shows the note and how far off it is.',
          'Tap a note on the keyboard to hear it, then play it back to match '
              'it.',
        ],
      ),
    ],
  ),
  (
    title: 'Playing a Tune',
    icon: Icons.play_circle_outline,
    topics: [
      (
        title: 'Play, Stop and Tempo',
        steps: [
          'Open a tune and press Play. The band counts you in.',
          'Pause holds it; Stop goes back to the top.',
          'Use minus and plus to change the tempo. Hold them to jump by 10, '
              'or tap the number to type one.',
        ],
      ),
      (
        title: 'Change Key',
        steps: [
          'Tap the key at the bottom of the screen and pick another. The '
              'chart and the band both move.',
        ],
      ),
      (
        title: 'Loop a Section',
        steps: [
          'Tap a bar on the chart to loop it, or drag across bars to loop '
              'a section.',
          'Hold a bar to start playing from there.',
          'The strip over the chart says what is looping, with shortcuts to '
              'change it.',
        ],
      ),
      (
        title: 'Mute a Part',
        steps: [
          'Tap a part name at the bottom (piano, bass, drums) to mute it, '
              'and again to bring it back.',
          'Mute the piano to practise comping, or the bass to practise '
              'walking.',
        ],
      ),
      (
        title: 'The Mixer',
        steps: [
          'Tap the sliders button at the bottom right.',
          'Set the volume of each part and of the count-in.',
          'Turn on Arpeggios to hear each chord broken up, 1 3 5 7.',
          'Reset puts every control back.',
        ],
      ),
      (
        title: 'The Arrangement',
        steps: [
          'Tap the arrangement button at the top of the tune.',
          'Choose how many choruses, or Keep Going to play forever.',
          'Head In & Out plays the melody chorus at the start and end.',
          'Make the tempo climb a little every chorus, up to a top speed.',
          'Trade eights, fours or twos with the drummer, and choose which parts '
              'lay out on the solos.',
        ],
      ),
      (
        title: 'Stage View',
        steps: [
          'Three dots, then Stage View: the chart as big as it goes, nothing '
              'else.',
          'Tap anywhere on the chart to start or stop.',
          'Scrolling Stage View shows a few big rows that move down the tune '
              'as it plays.',
        ],
      ),
      (
        title: 'Exercises for This Tune',
        steps: [
          'Three dots, then Exercises: written lines over this tune\'s '
              'changes, in levels.',
          'Tap Play to hear a line before you try it. Your level is kept per '
              'tune.',
        ],
      ),
      (
        title: 'Star, Share and Edit',
        steps: [
          'Three dots, then Star to add it to your starred tunes.',
          'Share Chart sends the chart to someone else.',
          'The pencil at the top opens the chords to edit.',
          'Practice Record lists every run at this tune and how fast.',
        ],
      ),
    ],
  ),
  (
    title: 'Recording Yourself',
    icon: Icons.fiber_manual_record_outlined,
    topics: [
      (
        title: 'Record a Take',
        steps: [
          'Put on headphones, or the band ends up on the recording too.',
          'Tap the round record button next to Play. It turns red: recording '
              'is ready.',
          'Press Play. The recording starts with the band.',
          'Press Stop when you are done. The take is saved.',
        ],
      ),
      (
        title: 'Listen Back',
        steps: [
          'Tap the sound wave button at the top of the tune to open Takes.',
          'Tap Play on a take. The band plays again around you.',
          'Use the You Against the Band slider to balance yourself and the '
              'band.',
          'Turn off Play the Band Too to hear only yourself.',
        ],
      ),
      (
        title: 'Share or Delete a Take',
        steps: [
          'The share button sends the take with the band mixed in.',
          'The bin deletes it.',
        ],
      ),
      (
        title: 'Check My Playing',
        steps: [
          'In the arrangement, turn on Check My Playing to have the app '
              'listen while you play and mark the notes it hears.',
          'Wear headphones, so it hears you rather than the band.',
        ],
      ),
    ],
  ),
  (
    title: 'Follow the Band by Ear',
    icon: Icons.hearing,
    topics: [
      (
        title: 'Start It',
        steps: [
          'Open a tune and tap the ear at the top. On iPhone and iPad.',
          'The chart goes big, as on Stage View, and the app follows a band '
              'that is not its own: a record, or real players.',
        ],
      ),
      (
        title: 'Choose Where the Music Is',
        steps: [
          'Broadcast hears another app on this device, such as Spotify or '
              'YouTube: tap Start Broadcast, choose The Changes, then play.',
          'Microphone hears the room: a record played out loud, or a band.',
        ],
      ),
      (
        title: 'Let It Listen',
        steps: [
          'It finds the beat, then which bar of the tune the band is in, '
              'and marks it as they go.',
          'Give it about half a minute. Until it knows the bar, none is '
              'marked.',
        ],
      ),
      (
        title: 'Help It Along',
        steps: [
          'Counting twice as fast as the band? Tap Half Time. Half as fast? '
              'Tap Double Time.',
          'Tap the Beat three or four times in time with the band to set '
              'the tempo.',
          'Tap Top of the Chorus as the band starts a chorus to jump to '
              'bar 1.',
          'Or tap the bar on the chart the band is playing, on its first '
              'beat.',
        ],
      ),
      (
        title: 'With a Foot Pedal',
        steps: [
          'A page-turner pedal works too: the right pedal taps the beat, '
              'the left is Top of the Chorus.',
        ],
      ),
    ],
  ),
  (
    title: 'Practice Tab',
    icon: Icons.route_outlined,
    topics: [
      (
        title: 'Today',
        steps: [
          'Choose how many minutes you have.',
          'Work down the list. Each block opens the page you do it on and '
              'ticks itself off when you finish.',
          'The key, the tune and the blocks change every day.',
        ],
      ),
      (
        title: 'The Roadmap',
        steps: [
          'Six stages, each with goals.',
          'Tick the goals yourself as you can do them. When they are all '
              'ticked, move up a stage.',
          'Tap Where Are You Now? to start on the stage that fits you.',
        ],
      ),
    ],
  ),
  (
    title: 'My Changes',
    icon: Icons.edit_note,
    topics: [
      (
        title: 'Write a Progression',
        steps: [
          'Tap New Progression, give it a title, key and tempo.',
          'Add chords bar by bar, then play it like any other tune.',
        ],
      ),
      (
        title: 'Import From iReal Pro',
        steps: [
          'Share a song or playlist from iReal Pro to The Changes, or tap '
              'Import from iReal Pro.',
          'On a computer you can copy a playlist link and paste it in.',
          'Load All 1,460 brings in iReal Pro\'s Jazz 1460 in one go.',
          'Tick the songs you want and tap Import.',
        ],
      ),
    ],
  ),
  (
    title: 'Learn Tab',
    icon: Icons.school_outlined,
    topics: [
      (
        title: 'Lessons',
        steps: [
          'Pages on a topic you can play along with: Swing, Comping, Guide '
              'Tones, Bebop Scales, Enclosures, Playing Fast, Rhythm '
              'Changes, Voicings and more.',
          'Each one plays its examples; use the Pause and Stop bar to hold '
              'or end them.',
        ],
      ),
      (
        title: 'Practice Pages',
        steps: [
          'Licks in Context, Scale Patterns, Phrases, Walking Bass, Trading '
              'Fours and Changes in Twelve Keys give you something to play '
              'with the band.',
          'Chord Quiz, Name What You Hear and Where Am I? test your ear.',
        ],
      ),
      (
        title: 'Look Things Up',
        steps: [
          'Chord Symbols, Chord Tones, Guitar Chords, Scales & Modes and '
              'Reading Music are reference pages, with every example playable.',
        ],
      ),
    ],
  ),
  (
    title: 'Settings',
    icon: Icons.settings_outlined,
    topics: [
      (
        title: 'Your Instrument',
        steps: [
          'Pick your instrument so charts and notes are written in your key. '
              'The band always plays at concert pitch.',
        ],
      ),
      (
        title: 'While Playing',
        steps: [
          'Fingering Diagram shows a keyboard or fretboard for each chord.',
          'Under the Chords adds numbers or guide tones under each chord.',
          'Mark the Bar sets how the bar being played is shown.',
          'Feel the Beat taps the phone on the beat.',
        ],
      ),
      (
        title: 'Look and Sound',
        steps: [
          'Paper, Chord Colours and Key Colours change how charts look.',
          'Drum Levels sets the balance of the kit.',
          'Keep Other Apps Playing lets music from another app carry on.',
        ],
      ),
      (
        title: 'Back Up & Restore',
        steps: [
          'Save your progressions, setlists and starred tunes to one file, '
              'and bring them back on this phone or a new one.',
        ],
      ),
    ],
  ),
];

class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('How It Works')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Everything the app does, in a few steps each. Tap a section '
              'to open it.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final (i, section) in _sections.indexed)
            ExpansionTile(
              key: ValueKey('how-$i'),
              leading: Icon(section.icon),
              title: Text(
                section.title,
                style: handLettered(theme.textTheme.titleLarge),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final topic in section.topics) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(topic.title, style: theme.textTheme.titleSmall),
                  ),
                  for (final (n, step) in topic.steps.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 22,
                            child: Text(
                              topic.steps.length > 1 ? '${n + 1}.' : '•',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              step,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
