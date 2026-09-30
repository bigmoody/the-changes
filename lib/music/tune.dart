import 'chord.dart';
import 'comping.dart';

/// One chord in a bar, with where it sits in time.
class ChordSlot {
  const ChordSlot({
    required this.chord,
    required this.barIndex,
    required this.startBeat,
    required this.beats,
  });

  final Chord chord;

  /// 0-based bar number.
  final int barIndex;

  /// 0-based beat counted from the start of the tune.
  final int startBeat;

  /// How many beats the chord lasts.
  final int beats;

  int get endBeat => startBeat + beats;
}

/// How the band plays: this picks the drum groove, the bass style and
/// whether eighth notes swing or are even.
enum Feel {
  /// Long-short jazz eighths, ride cymbal, walking bass.
  swing('Swing'),

  /// Even eighths, cross-stick playing the clave, root-and-fifth bass.
  bossa('Bossa nova'),

  /// Even eighths, backbeat on 2 and 4, syncopated root-heavy bass.
  funk('Funk'),

  /// Even eighths over the calypso 3-3-2 (1, the "and" of 2, 4) in the kick
  /// and bass, with a soft cross-stick on 2 and 4.
  calypso('Calypso'),

  /// Swing's long-short eighths with the back door open: every beat and
  /// its "a", a snare that cracks on 2 and 4 rather than whispering, and
  /// the bass still walking. What a blues does when it stops being polite.
  shuffle('Shuffle'),

  /// Brazilian, and quicker than a bossa: the surdo answering on 2 and 4,
  /// a tamborim figure across the bar, sixteenths running underneath.
  samba('Samba');

  const Feel(this.label);
  final String label;

  /// Where the "and" of a beat falls: late in the ones that swing,
  /// halfway in the ones that don't.
  double get andOfBeat => swings ? 2 / 3 : 0.5;

  /// Whether this feel's eighths are long-short.
  bool get swings => this == swing || this == shuffle;

  /// The tempos this feel lives at, in beats a minute.
  ///
  /// Swing is the whole range because it is: a ballad and a burner are both
  /// swung. The others are narrower (a samba at 90 is not a slow samba,
  /// it's a mistake) so changing the groove brings the tempo with it.
  ({int slowest, int fastest}) get tempos => switch (this) {
    swing => (slowest: 40, fastest: 320),
    shuffle => (slowest: 70, fastest: 200),
    bossa => (slowest: 90, fastest: 190),
    samba => (slowest: 150, fastest: 260),
    funk => (slowest: 60, fastest: 140),
    calypso => (slowest: 100, fastest: 200),
  };

  /// [tempo] brought into the range this feel is played at, staying as
  /// close to it as the feel allows.
  int tempoFor(int tempo) => tempo.clamp(tempos.slowest, tempos.fastest);
}

/// What kind of tune it is, for filtering the lists. A tune can be several:
/// Now's the Time is swing, bebop and blues.
enum Genre {
  swing('Swing'),
  latin('Latin'),

  /// Caribbean, not Latin: St. Thomas and the like.
  calypso('Calypso'),
  funk('Funk'),
  blues('Blues'),
  bebop('Bebop'),
  modal('Modal'),
  ballad('Ballad');

  const Genre(this.label);
  final String label;

  /// The genre a groove puts a tune in. Every tune has one; the rest are
  /// tagged by hand.
  static Genre ofFeel(Feel feel) => switch (feel) {
    Feel.swing => swing,
    Feel.shuffle => blues,
    Feel.bossa || Feel.samba => latin,
    Feel.calypso => calypso,
    Feel.funk => funk,
  };

  /// The genres that come from what a tune is rather than how it's played:
  /// the ones a player can tag their own progressions with.
  static const tags = [ballad, bebop, blues, modal]; // alphabetical
}

/// How the bass plays.
enum BassStyle {
  /// Four to the bar, with approach notes: the jazz default.
  walking('Walking'),

  /// Half notes, mostly roots and 5ths: lighter, for heads and ballads.
  twoFeel('Two-feel'),

  /// Root and 5th figures with pickups.
  bossa('Bossa nova'),

  /// Syncopated and root-heavy, with octave pops.
  funk('Funk'),

  /// The 3-3-2: 1, the "and" of 2 held over 3, then 4.
  calypso('Calypso');

  const BassStyle(this.label);
  final String label;
}

/// How the piano comps.
enum PianoStyle {
  /// Charleston, pushes and off-beat stabs, swung.
  swing('Swing comping'),

  /// The same, with even eighths: for Latin and funk grooves.
  straight('Straight comping'),

  /// One chord, held, on each change: simple and uncluttered.
  held('Held chords'),

  /// Short chords in the calypso strum: 1, 2, the "and" of 2, the "and"
  /// of 3, 4, the "and" of 4; or a lighter version of it.
  calypso('Calypso strum');

  const PianoStyle(this.label);
  final String label;

  /// Whether the piano's eighths swing.
  Feel get feel => this == swing ? Feel.swing : Feel.bossa;
}

/// Who plays the chords: the pianist, or a guitarist in their place.
/// Whether choosing a comping figure does anything, given who is comping
/// and in what style.
///
/// Held chords and the calypso strum have rhythms of their own and never
/// look at the figures. The guitar borrows the comper's figures in swing
/// and nowhere else: in the Latin styles it plays the bossa guitar's own
/// two-bar figures instead, which are a different thing entirely.
bool figuresApply(PianoStyle style, Comping who) => switch (style) {
  PianoStyle.held || PianoStyle.calypso => false,
  PianoStyle.swing => true,
  PianoStyle.straight => who == Comping.piano,
};

enum Comping {
  piano('Piano'),
  guitar('Guitar'),

  /// Whatever SoundFont somebody imported. It falls back to the piano
  /// when there is not one, so a setting saved on a phone that has since
  /// lost the file still plays.
  imported('Imported Sound');

  const Comping(this.label);
  final String label;
}

/// Who plays the bass.
///
/// Its own list rather than [Comping]'s, because the choices are not the
/// same ones: nobody wants the bass part played on a guitar, and an
/// imported bass is a different file from an imported piano.
enum BassSound {
  upright('Upright Bass'),

  /// A SoundFont imported for the bass. Falls back to the upright when
  /// there is not one.
  imported('Imported Sound');

  const BassSound(this.label);
  final String label;
}

/// What each instrument plays. A standard's [Feel] sets all three together,
/// but they can be mixed: a bossa groove under a walking bass, say.
class BandStyle {
  const BandStyle({
    required this.drums,
    required this.bass,
    required this.piano,
    this.figure,
  });

  /// The whole band in one [feel], as the standards are played.
  factory BandStyle.of(Feel feel) => BandStyle(
    drums: feel,
    bass: switch (feel) {
      // A shuffle's bass walks like any other blues; the bounce is in the
      // drums and the comping, not in the notes it chooses.
      Feel.swing || Feel.shuffle => BassStyle.walking,
      Feel.bossa || Feel.samba => BassStyle.bossa,
      Feel.funk => BassStyle.funk,
      Feel.calypso => BassStyle.calypso,
    },
    piano: switch (feel) {
      Feel.swing || Feel.shuffle => PianoStyle.swing,
      Feel.calypso => PianoStyle.calypso,
      Feel.bossa || Feel.funk || Feel.samba => PianoStyle.straight,
    },
  );

  final Feel drums;
  final BassStyle bass;
  final PianoStyle piano;

  /// The one comping figure to play in every bar, or null to let the
  /// comper choose bar by bar as it always has.
  ///
  /// Null is what a band does: a comper who played the Charleston in
  /// every bar of every tune would be unbearable. It is here because
  /// hearing one figure held to for a whole chorus, against real changes
  /// and at your own tempo, is how anybody learns what it does, and the
  /// Learn screen can only offer it over two bars of a ii-V.
  final CompFigure? figure;

  BandStyle withFigure(CompFigure? figure) =>
      BandStyle(drums: drums, bass: bass, piano: piano, figure: figure);

  @override
  bool operator ==(Object other) =>
      other is BandStyle &&
      other.drums == drums &&
      other.bass == bass &&
      other.piano == piano &&
      other.figure == figure;

  @override
  int get hashCode => Object.hash(drums, bass, piano, figure);
}

/// A chord chart: a list of bars, each holding one or more chords.
class Tune {
  const Tune._({
    required this.title,
    required this.composer,
    required this.year,
    required this.key,
    required this.description,
    required this.feel,
    required this.style,
    required this.defaultTempo,
    required this.beatsPerBar,
    required this.bars,
    required this.sections,
    required this.tags,
  });

  /// Builds a tune from a simple text chart such as
  /// `"| [A] Dm7 | G7 | CΔ7 Am7 | Dm7 G7 |"`.
  ///
  /// `[A]` at the start of a bar marks where a section of the form begins.
  /// Chords sharing a bar split its beats evenly; any leftover beat goes to
  /// the first chord (so three chords in 4/4 last 2 + 1 + 1 beats).
  factory Tune.fromChart({
    required String title,
    required String key,
    required String chart,
    required int defaultTempo,
    String? composer,
    int? year,
    String description = '',
    Feel feel = Feel.swing,
    BandStyle? style,
    Set<Genre> tags = const {},
    int beatsPerBar = 4,
  }) {
    final barTexts = chart
        .split('|')
        .map((bar) => bar.trim())
        .where((bar) => bar.isNotEmpty)
        .toList();

    final bars = <List<ChordSlot>>[];
    final sections = <int, String>{};
    for (var barIndex = 0; barIndex < barTexts.length; barIndex++) {
      var text = barTexts[barIndex];
      final section = RegExp(r'^\[([^\]]+)\]\s*').firstMatch(text);
      if (section != null) {
        sections[barIndex] = section[1]!;
        text = text.substring(section.end);
      }

      final symbols = text.split(RegExp(r'\s+'));
      final baseBeats = beatsPerBar ~/ symbols.length;
      final leftover = beatsPerBar % symbols.length;
      var beat = barIndex * beatsPerBar;
      final slots = <ChordSlot>[];
      for (var i = 0; i < symbols.length; i++) {
        final beats = baseBeats + (i < leftover ? 1 : 0);
        slots.add(
          ChordSlot(
            chord: Chord.parse(symbols[i]),
            barIndex: barIndex,
            startBeat: beat,
            beats: beats,
          ),
        );
        beat += beats;
      }
      bars.add(slots);
    }

    return Tune._(
      title: title,
      composer: composer,
      year: year,
      key: key,
      description: description,
      feel: feel,
      style: style ?? BandStyle.of(feel),
      defaultTempo: defaultTempo,
      beatsPerBar: beatsPerBar,
      bars: bars,
      sections: sections,
      tags: tags,
    );
  }

  final String title;
  final String? composer;
  final int? year;

  /// The key the chart is written in, e.g. "B♭" or "C minor".
  final String key;
  final String description;

  /// The groove the tune is known for (what the list shows).
  final Feel feel;

  /// What each instrument actually plays: [feel] for every instrument unless
  /// the chart says otherwise.
  final BandStyle style;
  final int defaultTempo;
  final int beatsPerBar;
  final List<List<ChordSlot>> bars;

  /// Section letters by the bar they start on, e.g. {0: 'A', 8: 'A', 16: 'B'}.
  final Map<int, String> sections;

  /// Genres tagged by hand: blues, bebop …
  final Set<Genre> tags;

  /// Every genre the tune is in: its groove's, then its tags.
  Set<Genre> get genres => {Genre.ofFeel(style.drums), ...tags};

  int get barCount => bars.length;
  int get totalBeats => barCount * beatsPerBar;
  List<ChordSlot> get slots => [for (final bar in bars) ...bar];

  /// The form spelled out, e.g. "AABA". Empty if the chart has no sections.
  String get form => sections.values.join();

  int barStartBeat(int barIndex) => barIndex * beatsPerBar;

  // ── Changing key ───────────────────────────────────────────────────────

  /// How each tonic is usually written: flat keys for major (D♭, not C♯),
  /// but sharps where minor keys are normally sharp (F♯ minor, not G♭ minor).
  static const _majorKeyNames = [
    'C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B', //
  ];
  static const _minorKeyNames = [
    'C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'G#', 'A', 'Bb', 'B', //
  ];

  bool get _isMinorKey => key.contains('minor') || key.contains('Dorian');

  /// The first note name in [key], e.g. B♭ in "B♭" or C in "C minor".
  Spelling get _tonic =>
      parseNoteName(RegExp(r'^[A-G][♭♯b#]?').stringMatch(key) ?? 'C')!;

  /// The key as a pitch class, C being 0, however it is spelled.
  ///
  /// For matching a chart against a recording, where G flat and F sharp
  /// are the same thing and the spelling is nobody's business.
  int get keyPitchClass => pitchClassOf(_tonic);

  /// The letter-aware move from this key to the key [semitones] above it.
  Transposition _transpositionBy(int semitones) {
    final tonic = _tonic;
    final names = _isMinorKey ? _minorKeyNames : _majorKeyNames;
    final target = parseNoteName(
      names[(pitchClassOf(tonic) + semitones) % 12],
    )!;
    return Transposition(
      letterSteps: (target.letter - tonic.letter) % 7,
      semitones: semitones % 12,
    );
  }

  /// The key label [semitones] higher, e.g. "G minor" up 9 → "E minor".
  String keyLabelBy(int semitones) {
    final transposition = _transpositionBy(semitones);
    // A capital A–G not followed by a lowercase letter, so the D in
    // "Dorian" isn't mistaken for a note.
    return key.replaceAllMapped(RegExp(r'[A-G][♭♯b#]?(?![a-z])'), (match) {
      final note = parseNoteName(match[0]!);
      return note == null ? match[0]! : noteNameOf(transposition.apply(note));
    });
  }

  /// A copy of this tune [semitones] higher, with every chord respelled for
  /// the new key. The backing band plays whatever chords the tune holds, so
  /// the audio changes key too.
  /// The same tune with the band playing it another way. What the player
  /// chose in the mixer, over what the tune was written with.
  Tune withStyle(BandStyle style) => style == this.style
      ? this
      : Tune._(
          title: title,
          composer: composer,
          year: year,
          key: key,
          description: description,
          feel: style.drums,
          style: style,
          defaultTempo: defaultTempo,
          beatsPerBar: beatsPerBar,
          sections: sections,
          tags: tags,
          bars: bars,
        );

  Tune transposed(int semitones) {
    if (semitones % 12 == 0) return this;
    final transposition = _transpositionBy(semitones);
    return Tune._(
      title: title,
      composer: composer,
      year: year,
      key: keyLabelBy(semitones),
      description: description,
      feel: feel,
      style: style,
      defaultTempo: defaultTempo,
      beatsPerBar: beatsPerBar,
      sections: sections,
      tags: tags,
      bars: [
        for (final bar in bars)
          [
            for (final slot in bar)
              ChordSlot(
                chord: slot.chord.transposed(transposition),
                barIndex: slot.barIndex,
                startBeat: slot.startBeat,
                beats: slot.beats,
              ),
          ],
      ],
    );
  }

  /// The chord sounding on [beat] (0-based, from the start of the tune).
  ChordSlot slotAtBeat(int beat) => slots.lastWhere(
    (slot) => slot.startBeat <= beat,
    orElse: () => slots.first,
  );
}
