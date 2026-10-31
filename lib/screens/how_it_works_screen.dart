// How It Works: every part of the app in a few plain steps, opened from
// the top of Settings.
//
// Written the way you would explain it to someone sitting next to you:
// where the button is, what to tap, what happens. One section per tab or
// per kind of job, each folded shut so the page reads as a list of what
// the app can do before it reads as instructions.
//
// Every line here was checked against the screen it describes. When a
// screen changes, change its line here too.

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
          'Settings: your instrument, what shows while playing, the sound '
              'and backups.',
        ],
      ),
      (
        title: 'Moving Between Them',
        steps: [
          'Each tab keeps its place: switch away and back and your search '
              'and scroll are still there.',
          'Tap the tab you are already on to go back to its first page.',
          'Back closes the page you are on first, and only leaves the app '
              'from a tab\'s first page.',
          'A tune you play opens over the tabs, full screen.',
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
      (
        title: 'With a Keyboard',
        steps: ['On a tune or on the stage, the spacebar plays and pauses.'],
      ),
    ],
  ),
  (
    title: 'Tunes Tab',
    icon: Icons.library_music_outlined,
    topics: [
      (
        title: 'Search',
        steps: [
          'Type a title, composer or key in the search box.',
          'The X at the end clears it.',
        ],
      ),
      (
        title: 'Starred, Sort and Genres',
        steps: [
          'Tap the star beside a tune to star it, and again to unstar it.',
          'Tap Starred to see only the tunes you have starred.',
          'Sort puts the list By Title, By Key (round the circle of '
              'fifths), By Tempo (slowest first) or By Composer (by '
              'surname).',
          'The genre chips narrow the list to one genre at a time. Tap the '
              'chosen one again to go back to All.',
        ],
      ),
      (
        title: 'Jump to a Letter',
        steps: [
          'In title or composer order, a long list has A to Z down the '
              'right edge.',
          'Tap a letter, or drag down the strip, to jump there.',
        ],
      ),
      (
        title: 'Recently Played',
        steps: [
          'The last six tunes you played sit at the top of the list.',
          'Clear empties it.',
        ],
      ),
      (
        title: 'Open a Tune',
        steps: [
          'Tap a tune to open it and play.',
          'Hold a tune to add it to a setlist without opening it.',
        ],
      ),
      (
        title: 'Just Play Something',
        steps: [
          'Tap the dice at the top of the tab.',
          'The app picks a tune, a key, a feel and a tempo, and starts it '
              'straight away.',
          'If you have starred tunes, it picks from those.',
          'A note at the bottom says what it chose.',
        ],
      ),
      (
        title: 'Where to Start',
        steps: [
          'Tap the signpost at the top of the tab.',
          'Twenty-one tunes in five stages, in an order worth learning '
              'them in, each with a line on what it teaches.',
          'Tap one to play it. Once played it says Played, or the tempo you '
              'played it clean at.',
          'Nothing is locked: start anywhere.',
        ],
      ),
    ],
  ),
  (
    title: 'Setlists',
    icon: Icons.format_list_numbered,
    topics: [
      (
        title: 'Make One',
        steps: [
          'Tap the list button at the top of the Tunes tab.',
          'Tap New Setlist and give it a name.',
          'Tap Add Tunes, tick the tunes you want and tap Add.',
        ],
      ),
      (
        title: 'Add From Anywhere',
        steps: [
          'Hold a tune in the Tunes list, or open it and use the three '
              'dots, then Add to Setlist.',
          'Tick the setlists it belongs in, or start a new one.',
        ],
      ),
      (
        title: 'Change One',
        steps: [
          'Drag the handle on the right to reorder.',
          'The minus takes a tune out.',
          'The three dots at the top rename or delete the setlist. The tunes '
              'themselves stay.',
          'Tap a tune to play it.',
        ],
      ),
      (
        title: 'Share One',
        steps: [
          'Tap Share at the top to send every chart in it: as text, an '
              'iReal Pro link, a PDF, MIDI or MusicXML.',
        ],
      ),
    ],
  ),
  (
    title: 'Tuner',
    icon: Icons.graphic_eq,
    topics: [
      (
        title: 'Tune Up',
        steps: [
          'Tap the tuning fork at the top of the Tunes tab. The band stops '
              'so it hears only you.',
          'Pick your instrument at the top so the notes are named in your '
              'key.',
          'Play a note. It shows the note, the hertz and how many cents off '
              'you are, and says Flat, go up or Sharp, go down.',
          'The screen goes green when you are within 5 cents.',
        ],
      ),
      (
        title: 'Pitch Practice',
        steps: [
          'Tap a note on the keyboard. It plays, and becomes the note to '
              'aim for.',
          'Sing or play it back. It tells you how close you are.',
          'The octave buttons move the note up or down. Any note goes back '
              'to plain tuning.',
        ],
      ),
    ],
  ),
  (
    title: 'Playing a Tune',
    icon: Icons.play_circle_outline,
    topics: [
      (
        title: 'Play, Pause and Stop',
        steps: [
          'Open a tune and press Play. The band counts you in.',
          'Pause holds it where it is; Play carries on.',
          'Stop goes back to the top.',
        ],
      ),
      (
        title: 'Tempo',
        steps: [
          'Minus and plus change the tempo by 1. Hold them to move by 10.',
          'Tap Tap in time, a few times, to set the tempo from your taps.',
          'Tap the BPM number to type a tempo or use a slider. Reset puts '
              'the tune\'s own tempo back.',
        ],
      ),
      (
        title: 'Change Key',
        steps: [
          'Tap the key at the bottom left and pick another.',
          'The chart and the band both move. Written marks the key the '
              'tune is written in.',
        ],
      ),
      (
        title: 'Mute a Part',
        steps: [
          'Tap a part name at the bottom (piano or guitar, bass, drums) to '
              'mute it, and again to bring it back.',
          'Mute the piano to practise comping, or the bass to practise '
              'walking.',
        ],
      ),
      (
        title: 'Arpeggios',
        steps: [
          'Tap Arpeggios at the bottom to hear each chord broken up.',
          'Choose which note it starts from, what plays it, how fast (Rate) '
              'and how high it goes (Up To).',
          'Off turns it off again.',
        ],
      ),
      (
        title: 'Loop a Section',
        steps: [
          'Tap a bar to loop it, or drag across bars to loop a section.',
          'In a bar of several chords, the strip above the chart lets you '
              'loop just one of them.',
          'Whole Tune, in the strip, goes back to the whole tune.',
        ],
      ),
      (
        title: 'Start Part-Way Through',
        steps: [
          'Hold a bar to start from there. A small wedge marks it.',
          'The first time through starts there, then it comes round to the '
              'top.',
          'Hold the same bar again, or tap the X on From in the strip, to '
              'start from the top again.',
        ],
      ),
      (
        title: 'How Many Choruses',
        steps: [
          'While the whole tune is looping, the flag in the strip sets how '
              'many times round before the band ends, or Keep Going.',
        ],
      ),
      (
        title: 'Reading the Chart',
        steps: [
          'The bar being played is marked, and the chord sounding now is '
              'underlined, pulsing on the beat.',
          'Bars outside the loop are faded, and the loop has repeat signs '
              'at each end.',
          'Boxed letters are the sections. 1. and 2. are first and second '
              'endings.',
          'Turned sideways on a phone, the controls move to the right.',
        ],
      ),
      (
        title: 'Now Playing',
        steps: [
          'The strip under the chart names the chord, its notes and its '
              'top note.',
          'With Aim For on, it shows the note to aim for, and the one on '
              'the next chord.',
          'Tap it for more on the chord and what it is doing here.',
        ],
      ),
      (
        title: 'Edit Your Own',
        steps: [
          'On a progression of your own, the pencil at the top opens it to '
              'edit. Save Changes brings you back to it.',
        ],
      ),
    ],
  ),
  (
    title: 'The View Sheet',
    icon: Icons.visibility_outlined,
    topics: [
      (
        title: 'Open It',
        steps: [
          'Tap View at the top of a tune.',
          'Everything here changes what you see, not what the band plays.',
        ],
      ),
      (
        title: 'What Is in It',
        steps: [
          'Chart Written For: C, B♭, E♭ or F. The chart moves to your '
              'instrument; the band stays at concert pitch.',
          'Fingering Diagram: a keyboard, guitar, barre chord or bass '
              'diagram for each chord.',
          'Counted In: count the tune in another time signature. The bars '
              'keep their chords.',
          'Chart Font: Hand Lettered, Printed or Serif.',
          'Minor Chords: written Dm7 or D-7.',
          'Under the Chords: Roman numerals, Nashville numbers, guide tones '
              'or what each chord is doing, in red under it.',
          'Hide the Chart: the chords fade, then the bars, after 1, 2 or 4 '
              'choruses. Everything comes back when you stop, or tap the '
              'chart.',
          'Aim For: the chord tone to aim at on every change.',
          'Check My Playing: the app listens and marks the changes you land '
              'on.',
        ],
      ),
    ],
  ),
  (
    title: 'The Mixer',
    icon: Icons.tune,
    topics: [
      (
        title: 'Open It',
        steps: ['Tap the sliders button at the bottom right of a tune.'],
      ),
      (
        title: 'The Band',
        steps: [
          'Tap a groove (Swing, Bossa nova, Funk, Ballad and so on) and the '
              'whole band changes to it.',
          'Or set the drums, bass and comping on their own.',
          'Swing sets how swung the eighths are. Hear the Swing plays it on '
              'the ride. Left alone, it follows the tempo.',
          'Figure picks the comping rhythm, such as the Charleston.',
          'As Written puts the tune\'s own style back.',
        ],
      ),
      (
        title: 'The Sounds',
        steps: [
          'Chords: piano, guitar, or a sound you have imported.',
          'Kit: sticks or brushes.',
          'Count-In: off, 1 bar or 2 bars.',
          'Arpeggios: turn them on, and choose what plays them and how.',
        ],
      ),
      (
        title: 'The Levels',
        steps: [
          'Each part has a volume slider, a mute and a solo.',
          'Solo plays only the soloed parts.',
        ],
      ),
      (
        title: 'Reset',
        steps: [
          'Reset at the top puts everything on the sheet back: the band, '
              'the sounds, the levels, the count-in, the arpeggios and the '
              'tempo.',
        ],
      ),
    ],
  ),
  (
    title: 'The Arrangement',
    icon: Icons.queue_music,
    topics: [
      (
        title: 'Open It',
        steps: [
          'Tap the arrangement button at the top of a tune. It turns solid '
              'when the arrangement is more than a plain loop.',
        ],
      ),
      (
        title: 'What Is in It',
        steps: [
          'Choruses: how many times round, or Keep Going. The band ends on '
              'the home chord.',
          'Head In & Out: the first and last chorus are the melody.',
          'Two-Feel on the Head: the bass plays in two on the melody and '
              'walks on the solos.',
          'Tempo Ramp: a little faster every chorus, up to a top speed.',
          'Trading: eights, fours or twos, answered by the drummer or by '
              'just the time.',
          'Lay Out on the Solos: the chords or bass drop out for the solos '
              'and come back for the head.',
          'Reset goes back to a plain loop.',
        ],
      ),
      (
        title: 'Export a Backing Track',
        steps: [
          'Set a number of choruses (a track has to end).',
          'Tap Export Backing Track. It writes the band out as audio to '
              'save or send.',
        ],
      ),
    ],
  ),
  (
    title: 'More on a Tune',
    icon: Icons.more_horiz,
    topics: [
      (
        title: 'The Three Dots',
        steps: [
          'Exercises, Stage View, Star, Add to Setlist, Practice Record and '
              'Share Chart are all under the three dots at the top right.',
        ],
      ),
      (
        title: 'Exercises',
        steps: [
          'Five written exercises over this tune\'s own changes: '
              'Arpeggios, Guide Tones, 3 to 7, Bebop Scales and Enclosures.',
          'Pick a level, tap Hear It to hear it slowly, then play it.',
          'Your level is kept for each tune.',
        ],
      ),
      (
        title: 'Stage View',
        steps: [
          'The chart as big as it goes, nothing else, for the stand.',
          'Tap anywhere on the chart to play or pause.',
          'The X leaves the stage. The band keeps playing.',
        ],
      ),
      (
        title: 'Scrolling Stage View',
        steps: [
          'A few big rows that move down the tune as it plays.',
          'Where the ear button is at the top of the tune, the ear is the '
              'way in.',
        ],
      ),
      (
        title: 'Practice Record',
        steps: [
          'Every run at this tune: when, how many, and the best tempo you '
              'played it clean at.',
          'With Check My Playing on, a run is clean when you land on 8 '
              'changes in 10.',
          'Two clean runs in a row and it offers a tempo 4 faster.',
          'Forget This Record clears it. The tune stays.',
        ],
      ),
      (
        title: 'Share Chart',
        steps: [
          'As Text, As an iReal Pro Link, As a PDF, As MIDI or As MusicXML.',
          'It goes out in the key you are in and written for your '
              'instrument. MIDI stays at concert pitch.',
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
          'The bin deletes it straight away.',
        ],
      ),
      (
        title: 'Check My Playing',
        steps: [
          'Tap View, then turn on Check My Playing.',
          'Wear headphones, so it hears you rather than the band.',
          'Press Play. It marks each change you land on, and with Aim For '
              'on, says whether it heard the note.',
          'At the end it tells you how many changes you found.',
        ],
      ),
    ],
  ),
  (
    title: 'Bring Something In',
    icon: Icons.file_open_outlined,
    topics: [
      (
        title: 'Start Here',
        steps: [
          'Open the Mixer and tap Bring Something In.',
          'Choose a file. A MIDI file becomes a part; WAV files become a '
              'recorded band.',
          'Nothing is uploaded: the files stay on the phone.',
        ],
      ),
      (
        title: 'A MIDI Part',
        steps: [
          'Tap the part of the file you want.',
          'Choose whether it plays on piano, guitar or bass.',
          'Move its start a beat or a bar at a time until it lines up, and '
              'set how many bars it repeats over.',
          'It follows your tempo and key, and has its own chip to mute it.',
        ],
      ),
      (
        title: 'A Recorded Band',
        steps: [
          'Choose the stems: bass, drums and comping, as WAV files.',
          'Give the take its name, tempo and key.',
          'Check the Timing listens to it and lines up bar 1.',
          'Add This Take. It plays instead of the band, moved to your key '
              'and tempo.',
          'Turn off Play the Recording, in the Mixer, to hear the band '
              'instead.',
        ],
      ),
      (
        title: 'A SoundFont',
        steps: ['SoundFonts go in from Settings, under Imported Sounds.'],
      ),
    ],
  ),
  (
    title: 'Follow the Band',
    icon: Icons.hearing,
    topics: [
      (
        title: 'What It Is For',
        steps: [
          'The chart follows a band that is not the app\'s own: a record, '
              'or real players.',
          'The chart goes big, as on Stage View, and marks the bar they '
              'are in.',
        ],
      ),
      (
        title: 'By Ear',
        steps: [
          'Open a tune and tap the ear at the top. On iPhone and iPad.',
          'Broadcast hears another app on this device, such as Spotify or '
              'YouTube: tap Start Broadcast, choose The Changes, then play. '
              'Music protected by Apple Music comes through silent.',
          'Microphone hears the room: a record played out loud, or a band.',
          'It finds the beat, then the bar. Give it about half a minute; '
              'until it knows the bar, none is marked.',
          'Stop Listening ends it. How Listening Works, beside it, explains '
              'it all again.',
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
              'beat. A bar you tap is always believed.',
          'Without drums it listens to the chords instead, and may need a '
              'bar tapped.',
        ],
      ),
      (
        title: 'Which Tune Is It?',
        steps: [
          'After about half a minute it says which tunes the band sounds '
              'like. Tap one to change to it and keep listening.',
        ],
      ),
      (
        title: 'By Taps',
        steps: [
          'Without the ear, use the three dots, then Scrolling Stage View, '
              'then the hand: Follow a Band by Taps.',
          'The app\'s own band stops. Count the band in on Tap the Beat, '
              'and bar 1 comes on the next beat.',
          'Already playing? Tap the beat, then the bar it is on.',
          'Top of the Chorus jumps to bar 1.',
        ],
      ),
      (
        title: 'With a Foot Pedal',
        steps: [
          'A page-turner pedal works too: the right pedal taps the beat, '
              'the left is Top of the Chorus.',
          'On a keyboard, the right or down arrow taps the beat and the left '
              'or up arrow is Top of the Chorus.',
        ],
      ),
    ],
  ),
  (
    title: 'Practice Tab',
    icon: Icons.route_outlined,
    topics: [
      (
        title: 'First Time',
        steps: [
          'Pick your instrument: Guitar, Piano, Bass or Horns. Horns '
              'covers saxophones, trumpet, trombone, clarinet and flute.',
          'On Horns, pick your horn\'s key under Your Horn: B♭ for trumpet, '
              'tenor and soprano sax or clarinet, E♭ for alto and baritone '
              'sax, F for French horn, C for flute and trombone. The '
              'exercises are then written in your key.',
          'Pick your level: Beginner, Intermediate, Advanced or '
              'Professional. It sets the stage you start on, the tempos, the '
              'keys and how the time is shared out.',
        ],
      ),
      (
        title: 'Today',
        steps: [
          'Choose how many minutes you have: 15, 30, 60 or 90.',
          'Work down the list. Each block says what to do, in today\'s key '
              'and on today\'s tune.',
          'Tap a block to open the page you do it on. Exercises tick '
              'themselves off when you finish; tick the rest yourself.',
          'The key and the tune change every day. Ticks clear at midnight.',
        ],
      ),
      (
        title: 'Heard In',
        steps: [
          'Blocks on a mode have a Heard In chip: tunes that use it, to play '
              'in today\'s key.',
        ],
      ),
      (
        title: 'The Exercises',
        steps: [
          'Scale blocks open a stave of the scale. Set the tempo, the '
              'octaves and whether the band plays it too, then Play Along.',
          'Horns get their own blocks: Long Tones as the warm-up, then '
              'Articulation, Range, Ghosting and Phrasing, Bebop Heads at '
              'Tempo, The Ballad Sound, and Altissimo and Extremes.',
          'Guitar and piano get comping blocks, and bass gets walking '
              'blocks, in their place.',
          'Each starts in today\'s key. Tap In F (or whichever key) at the '
              'top to choose any of the twelve, or the skip button to go on '
              'to the next key round the cycle.',
          'Next moves on a step. Done, on the last one, ticks the block.',
        ],
      ),
      (
        title: 'Session Tools',
        steps: [
          'Licks in Context: the band plays a lick, then you answer it, in '
              'any key.',
          'Session Skills: intros, choruses, trading, endings and the '
              'signals, played on the tune of the day.',
          'Get Lost and Recover: the band drops out and comes back; keep '
              'your place.',
          'Playing Fast: what fast players do, and how to get there.',
        ],
      ),
      (
        title: 'My Session\'s Tunes',
        steps: [
          'Add a Tune adds the tunes your local session calls.',
          'They become the tune of the day two days in three.',
          'Tap one to play it; the X takes it off.',
        ],
      ),
      (
        title: 'The Roadmap',
        steps: [
          'Six stages, from time and the blues to a voice of your own, each '
              'with goals and tunes.',
          'Tick the goals yourself as you can do them. Nothing is marked '
              'for you.',
          'When every goal is ticked, Move Up starts the next stage.',
          'Work on This Stage, on any other stage, switches to it.',
        ],
      ),
      (
        title: 'Change Instrument or Level',
        steps: [
          'The instrument buttons at the top switch the roadmap. Each '
              'instrument keeps its own stage and ticks.',
          'Tap another level under Your Level to start on its stage. Goals '
              'already ticked are kept.',
        ],
      ),
    ],
  ),
  (
    title: 'My Changes',
    icon: Icons.edit_note,
    topics: [
      (
        title: 'Your List',
        steps: [
          'Search, Starred, Sort and the genre chips work as on the Tunes '
              'tab. Mine shows only the ones you wrote here.',
          'Tap one to play it. The pencil edits it, the bin deletes it, or '
              'swipe it left.',
          'Tap Select, or hold one, to delete several at once.',
        ],
      ),
      (
        title: 'Write a Progression',
        steps: [
          'Tap New Progression.',
          'Give it a name, then set the key, the time signature and the '
              'tempo.',
          'Under The Band, pick a feel for everyone, or the drums, bass and '
              'chords one by one.',
          'Tap + to add the first bar.',
        ],
      ),
      (
        title: 'What Goes in a Bar',
        steps: [
          'Type the chords, such as Dm7 G7. Several in a bar share it '
              'evenly.',
          'Or tap a root, then a chord type. / Bass puts the chord over a '
              'bass note.',
          'Starts Section gives the bar a letter, and Play It repeats that '
              'section.',
          'Ending marks a first or second ending.',
          'Next Bar goes on to the next one. Done closes it.',
        ],
      ),
      (
        title: 'Save It',
        steps: [
          'Under File Under, add it to Ballad, Bebop, Blues or Modal as well '
              'as its own genre.',
          'Save and Play saves it and opens it. Leaving without saving asks '
              'first.',
        ],
      ),
      (
        title: 'Import From iReal Pro',
        steps: [
          'Share a song or playlist from iReal Pro to The Changes, or tap '
              'Import at the top.',
          'On a computer you can copy a playlist link and paste it in.',
          'Load All 1,460 brings in iReal Pro\'s Jazz 1460 in one go.',
          'Tick the songs you want and tap Import. Ones you already have '
              'start unticked.',
        ],
      ),
    ],
  ),
  (
    title: 'Learn Tab',
    icon: Icons.school_outlined,
    topics: [
      (
        title: 'Finding a Page',
        steps: [
          'Three lists: Practise (things to play with the band), Concepts '
              '(what an idea is, with examples) and Look It Up.',
          'Type in Search Learn to find a page by its name or what it does.',
        ],
      ),
      (
        title: 'Things Most Pages Share',
        steps: [
          'Tap an example to hear it. The Pause and Stop bar holds or ends '
              'it.',
          'Key chips jump to a key; Back and Next Key step through them.',
          'The button at the top right sets the order the keys come in: '
              'round the cycle, up in semitones, or shuffled.',
          'Pages with written notes follow your instrument, C, B♭, E♭ or F.',
        ],
      ),
    ],
  ),
  (
    title: 'Learn: Practise',
    icon: Icons.music_note_outlined,
    topics: [
      (
        title: 'Changes in Twelve Keys',
        steps: [
          'Pick the changes: a ii V I, a turnaround, a minor ii V, a blues '
              'and more.',
          'Press Play. The band plays them in one key; Next Key moves on.',
          'Turn on Move On by Itself and set the times round, and it changes '
              'key for you while you play.',
        ],
      ),
      (
        title: 'Chord Identifier',
        steps: [
          'Play a chord on the guitar or the keys, near the phone.',
          'It names the chord and the notes it heard, with other names it '
              'could have, and shows it on the keys and the guitar.',
        ],
      ),
      (
        title: 'Chord Quiz',
        steps: [
          'Spell It: tap the notes of the chord on the pad, against the '
              'clock.',
          'Aim For: tap just the root, the 3rd, the 3rd and 7th and so on.',
          'Choose any chord or ii V Is, and a level from triads to altered.',
          'The speaker plays the chord. Next gives the next one.',
        ],
      ),
      (
        title: 'Licks in Context',
        steps: [
          'Seven stock licks, each over the changes it belongs to.',
          'Band, Then You: the band plays it, then you answer. Together, or '
              'Just the Changes, are the other ways.',
          'Choose the key at the top, the tempo and how many times.',
        ],
      ),
      (
        title: 'Metronome',
        steps: [
          'Set the tempo and the time, and press Start. Tap sets it by '
              'tapping.',
          'Click On: beats, eighths, triplets or swing. Which Beats: every '
              'beat, or 2 and 4.',
          'Dropout leaves bars silent, so you keep the time yourself.',
        ],
      ),
      (
        title: 'Name What You Hear',
        steps: [
          'Choose chords, two chords or cadences.',
          'Press Play It, then tap what you think it was.',
          'It says if you were right and why it sounds like that. Hear any '
              'of the choices to compare.',
        ],
      ),
      (
        title: 'Phrases',
        steps: [
          'Tap Record a Phrase, play something worth keeping, then Stop.',
          'Say what key it was in.',
          'Open it to hear it moved to any key: your own playing, not '
              'written down.',
        ],
      ),
      (
        title: 'Scale Patterns',
        steps: [
          'Pick a scale and a pattern: in 3rds, 4ths, triads, 1 2 3 5 and '
              'more.',
          'It is written on the stave. Hear It plays it, up or down, in '
              'every key.',
        ],
      ),
      (
        title: 'Side by Side',
        steps: [
          'Two or three tunes on the same form, bar against bar.',
          'Bars that differ are tinted. Play a column to hear it through.',
        ],
      ),
      (
        title: 'Trading Fours',
        steps: [
          'Choose eights, fours or twos, and who answers.',
          'Tap Start Trading. A big word on screen says whose turn it is.',
        ],
      ),
      (
        title: 'Walking Bass',
        steps: [
          'Fifteen shapes the band\'s bassist uses to get from one chord to '
              'the next.',
          'Choose the chords to walk through, and tap Hear on a shape.',
        ],
      ),
      (
        title: 'Where Am I?',
        steps: [
          'Pick a tune and tap Start. The band plays with nothing on '
              'screen, then stops.',
          'Tap the bar you think it stopped in. Again plays another.',
        ],
      ),
    ],
  ),
  (
    title: 'Learn: Concepts',
    icon: Icons.lightbulb_outline,
    topics: [
      (
        title: 'How These Pages Work',
        steps: [
          'Each one explains one idea, then lets you hear it: pick from the '
              'chips, then play.',
        ],
      ),
      (
        title: 'Lines',
        steps: [
          'Bebop Scales: the extra note that keeps chord tones on the beat.',
          'Enclosures: five ways round a note before landing on it.',
          'Guide Tones: the 3rd and 7th held through the changes.',
          'Number Patterns: one shape, such as 1 2 3 5, through every chord. '
              'Play Along loops the band under it.',
          'Through the Changes: a whole chorus of nothing but chord tones.',
          'Where Phrases Start: the same four notes moved round the bar.',
          'Palm Keys: for saxophone, runs up into the top of the range.',
        ],
      ),
      (
        title: 'Harmony',
        steps: [
          'Between the Chords: the chords you can add that are not on the '
              'chart.',
          'Chains of Dominants: dominants leaning on each other.',
          'Tritone Subs: why one dominant can stand in for another.',
          'Upper Structures: a triad on top of a dominant.',
          'Voicings: one chord arranged as close, drop 2, shells, rootless '
              'and more.',
          'Modal: what to play when one chord lasts sixteen bars.',
          'Rhythm Changes: the form, and the bridge to learn first.',
        ],
      ),
      (
        title: 'Time and Feel',
        steps: [
          'Swing: how late the \'and\' really is. Move the slider, or let it '
              'follow the tempo.',
          'Comping: when to put the chord down. Pick a rhythm and hear it.',
          'Playing Fast: what fast players do, how to get from slow to fast, '
              'and a tempo ladder on Cherokee.',
        ],
      ),
    ],
  ),
  (
    title: 'Learn: Look It Up',
    icon: Icons.menu_book_outlined,
    topics: [
      (
        title: 'Chord Symbols',
        steps: [
          'What Δ7, ø, alt and the rest mean. Search for one. Nothing plays '
              'on this page.',
        ],
      ),
      (
        title: 'Chord Tones',
        steps: [
          'Every chord on any root, on the keys, guitar or bass. Tap Hear on '
              'one.',
        ],
      ),
      (
        title: 'Guitar Chords',
        steps: [
          'Pick a root and a type: every shape up the neck. Tap one to hear '
              'it. Inversions adds shapes with another note in the bass.',
        ],
      ),
      (
        title: 'Listening',
        steps: [
          'The records these tunes come from, oldest first, with the tunes '
              'on each.',
        ],
      ),
      (
        title: 'Reading Music',
        steps: [
          'The stave, the clefs, note values and the marks on the page. '
              'Contents, at the top, jumps to a part.',
        ],
      ),
      (
        title: 'Scales & Modes',
        steps: [
          'Every mode in any key, in treble or bass clef, with the chord it '
              'goes with.',
          'Hear plays it. Heard In opens a tune that uses it.',
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
          'C, B♭, E♭ or F. Charts and notes are written in your key all '
              'through the app.',
          'The band always plays at concert pitch.',
        ],
      ),
      (
        title: 'While Playing',
        steps: [
          'Fingering Diagram: Off, Keyboard, Guitar, Guitar with barre '
              'chords, or Bass.',
          'Under the Chords: Roman numerals, Nashville numbers, guide tones '
              'or what each chord is doing.',
          'Mark the Bar: the bar being played filled, outlined, or not '
              'marked.',
          'Feel the Beat: the phone taps on every beat, on 2 and 4, or on '
              'the 1.',
          'Aim For: the chord tone to aim at.',
        ],
      ),
      (
        title: 'Paper',
        steps: [
          'Follow the System for warm paper by day and near black at '
              'night, or Choose a Paper for a colour of your own.',
          'Everything else on the chart is worked out from it.',
        ],
      ),
      (
        title: 'Chord Colours and Key Colours',
        steps: [
          'If you see pitches or keys as colours, set yours here.',
          'Tap a note or a key to give it a colour. Chords take their '
              'root\'s colour; a tune takes its key\'s.',
          'Sharps and Flats Apart, or Major and Minor Apart, gives each its '
              'own.',
          'The switch at the top turns them off without losing them. Clear '
              'removes them all.',
        ],
      ),
      (
        title: 'Sound',
        steps: [
          'Chords Played By and Arpeggios Played On: piano, guitar or an '
              'imported sound.',
          'Bass Played By: the upright, or an imported sound.',
          'Drums Played By: sticks, brushes or an imported kit.',
          'Drum Levels: turn the cymbals, or any drum, up or down, and tap '
              'it to hear it.',
          'Keep Other Apps Playing: on, music from another app carries on '
              'under the band. Off, the app has the sound to itself and its '
              'own controls on the lock screen.',
        ],
      ),
      (
        title: 'Imported Sounds',
        steps: [
          'Tap Add a SoundFont and choose an .sf2 file.',
          'Tap a sound in it to choose what it plays: the chords, the bass '
              'or the arpeggios. Tap a kit to take the whole kit, or one '
              'drum.',
          'Play the Whole Band Again puts the band\'s own sounds back. The '
              'SoundFonts stay.',
        ],
      ),
      (
        title: 'Back Up & Restore',
        steps: [
          'Save Backup makes one file of your progressions, setlists and '
              'stars. Keep it in Files, iCloud Drive or an email.',
          'To restore, paste the backup in.',
          'Add To What\'s Here adds its progressions beside yours. Replace '
              'Everything swaps in its progressions, setlists and stars.',
          'Takes are not in it: they stay on the phone.',
        ],
      ),
      (
        title: 'About & Credits',
        steps: [
          'Who recorded the instruments the band plays, and the lettering.',
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
