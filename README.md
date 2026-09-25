# The Changes

A jazz play-along and practice app. Around 200 standards with a band that
plays the changes behind you, a practice screen built around one tune, and a
Learn tab of drills and reference pages. Flutter, iOS and Android, everything
on the phone.

## What's in it

### Tunes

The book is around 200 standards. Search it, index it A to Z, filter by genre,
star what you are working on. **Where to Start** puts the book in a suggested
learning order, five stages, with a line on each tune saying what it is there
to teach. **Setlists** hold the tunes for a gig or a lesson in order, by
reference, so editing a chart updates it everywhere it appears. The tuning
fork at the top opens a **tuner**: chromatic, or tap one of the twelve notes
to set a target and play or sing it back.

### Playing a tune

The whole form on one page in lead-sheet lettering, with the current bar lit
as the band plays.

| | |
|---|---|
| The band | Bass, drums and comping, generated from the chart. Piano or guitar comping, fifteen named comping figures |
| Transport | Tempo, key (transpose while it plays), count-in, and which of the band is playing |
| Mixer | Levels per instrument, arpeggios on any instrument, which note to start on |
| Arrangement | Choruses, head in and out, two-feel on the head, who lays out behind you, and a tempo that climbs each time round |
| Loop | Any range of bars, set by tapping the chart |
| Under the chords | Roman numerals or guide tones under each chord, plus fingering diagrams for keys, guitar or bass |
| Aim For | The app names a chord tone to land on as each change goes past |
| Check My Playing | The microphone hears what you play against the changes and marks it, change by change and as a score |
| Hide the Chart | Takes the chords away, then the bar lines too, while the band keeps going |
| Stage | The chart and nothing else, for a phone on a stand |
| Takes | Record yourself over the band. Only your playing is saved; the band is written again identically on playback |
| Practice Record | Every run at a tune, how fast, how it went, and when you have earned the next four beats a minute |
| Import a Part | A MIDI file as an extra voice |
| Recorded Band | Real players as the band, with tempo and transpose still live within limits |
| Share | The changes as text, or as an iReal Pro link |

### My Changes

Progressions you have written yourself, played by the same band and with the
same practice tools as anything in the book. Written in the chart editor, or
brought in from iReal Pro by pasting a link.

### Learn

**Practise:** Walking Bass, Name What You Hear, Scale Patterns, Changes in
Twelve Keys, Licks, Chord Quiz, Metronome, Where Am I?, Trading Fours, Side by
Side.

**Concepts**, one idea a page with the sound and the notation: Bebop Scales,
Number Patterns, Tritone Subs, Between the Chords, Where Phrases Start, Swing,
Rhythm Changes, Comping, Modal, Enclosures, Voicings, Upper Structures, Guide
Tones, Through the Changes. Alongside them sit Chord Identifier, which names a
chord you play, and Listening, which says which records these charts come from
and deliberately plays nothing.

**Look It Up:** Reading Music, Chord Symbols, Guitar Chords, Chord Tones,
Scales & Modes.

### Settings

Set your instrument once and every chart, drill and reference is written the
way you read it, while the band always plays at concert pitch. Then what shows
while playing, the comping and arpeggio sounds, whether to keep Spotify or a
video playing underneath, and Back Up & Restore.

## What the charts are, and are not

Every chart in the book is written here from scratch: **chord changes, form,
title, composer and year, and nothing else**. There are no melodies and no
lyrics anywhere in the app, and no compiled collection, fake book or chord
database has been copied.

The iReal Pro import reads only what the player pastes, on their own phone.
Nothing is downloaded and nothing leaves the device. iReal Pro is a trademark
of Technimo LLC, which has nothing to do with this app.

## Running it

```bash
flutter pub get
flutter run
```

Flutter 3.47.4 is what CI pins; Dart SDK `^3.13.3`. The app needs a real
device or a simulator for sound. Microphone features (the tuner, Check My
Playing, Chord Identifier, recording a lick or a take) do nothing on the iOS
simulator, which has no microphone: they have to be tried on a phone.

## Tests

1758 tests, and three more that render the backing for every tune in the book.

```bash
flutter test                             # the everyday run, about half a minute
flutter test --tags sweep --run-skipped  # the three sweeps, about four minutes
```

The sweeps are skipped by default because between them they were three
quarters of the suite's running time, which is long enough that you stop
running it after every change. See `dart_test.yaml`.

CI (`.github/workflows/checks.yml`) runs three checks on every push and pull
request: `dart format --set-exit-if-changed`, `flutter analyze` and
`flutter test`. The sweep job runs on merges only. The Flutter version and the
runner image are both pinned, so a release or a new image cannot turn a green
check red on a morning nobody touched anything.

## How the code is laid out

```
lib/music/     the music itself: chords, scales, tunes, progressions.
               No Flutter, no audio, no state. Everything else reads from here
lib/audio/     turning that into sound: the synth, the sample bank, comping,
               walking bass, drums, and the listening side (pitch, onsets, FFT)
lib/practice/  what happens while you play: the controller, takes, licks,
               imported parts, the practice record
lib/screens/   the screens
lib/library/   the book, starring, backup, the starting order
lib/settings/  preferences and stored progressions
tool/          sample processing, the app icon, chart checks
```

Two principles hold the thing together and are worth knowing before changing
it:

- **Derived, not stored.** A screen works its facts out from the same data the
  band plays from, so what is taught cannot drift from what is heard. Learn's
  comping figures and bass shapes are the band's own lists, asked for by name.
- **Everything on one screen.** The chart is the whole form at once. It never
  scrolls and never pages; the layout shrinks to fit instead.

## Sound, lettering and credits

Recorded instruments come from free sample libraries (Sneakybass, Salamander
Grand Piano, Emilyguitar, Virtuosity Drums), processed by
`tool/process_samples.py`. Chord symbols and staves are lettered in Petaluma
Script and Petaluma, under the SIL Open Font License. Full credits and licence
terms are in [assets/sounds/CREDITS.md](assets/sounds/CREDITS.md), and the
attribution CC BY asks for is shown in the app's About screen.

## The recorded-band pilot

Recordings of real players are a private pilot. Nothing recorded for it is
published, streamed, uploaded, shared or sold; the players keep all their
rights; and distributing any of it would need a separate written agreement
made first. The template that says what to record, and at what tempo and key,
is kept outside the repository.
