import 'chord.dart';
import 'meter.dart';
import 'swing.dart';
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
  samba('Samba'),

  /// Swing in three. The ride plays the figure a waltz is taught in,
  /// "one, two, and-of-two, three", so the lift is after 2 and beat 3
  /// is left plain, the hi-hat closes under 2 and 3, and the bass walks
  /// three to the bar.
  ///
  /// Swing in a three-beat bar is already close to this, and that is the
  /// point of giving the waltz its own name rather than leaving it to the
  /// time signature: the skip note after every beat is what a swing
  /// pattern does in four, and a waltz that keeps it sounds hurried.
  jazzWaltz('Jazz Waltz'),

  /// A slow swing played with the brushes: the left hand circling the
  /// head, the right hand touching the time in on 2 and 4, the bass in
  /// two and the chords held rather than comped.
  ///
  /// A ballad is not only a swing tune at a slow tempo. What changes is
  /// who plays what: the time moves off the cymbal and onto the head,
  /// the bass stops walking, and the piano stops answering.
  ballad('Ballad'),

  /// The New Orleans street beat: the kick carrying a syncopated figure
  /// against a backbeat with ghost notes around it, and the whole thing
  /// somewhere between swung eighths and loose sixteenths rather than
  /// squarely either.
  ///
  /// Nothing on the cymbal. A parade has no ride, and on a kit what
  /// stands in for the two drummers of a brass band is the kick and the
  /// snare, which is why this is the one swung groove here with no
  /// cymbal time in it at all.
  secondLine('Second Line'),

  /// Afro 6/8: the standard bell over a compound bar, with the bombo on
  /// the second beat of its four-pulse cycle.
  ///
  /// Called Afro 6/8 rather than bembé on purpose. Bembé is religious
  /// ceremonial music, specific in every aspect, and the groove jazz
  /// bands play is an approximation of it; drummers who know the
  /// difference say Afro 6 or Afro-Cuban 6/8, so that is what it is
  /// called here.
  afroSix('Afro 6/8'),

  /// Gypsy jazz, after Django Reinhardt's Quintette: la pompe on the
  /// guitar, "the pump", four short downstrokes a bar with 2 and 4
  /// carrying the accent.
  ///
  /// There is no drum part, because there was no drummer. The guitar's
  /// chop is the time, and it is percussive on purpose: that is what
  /// drives the music where a kit otherwise would.
  gypsy('Gypsy Jazz');

  const Feel(this.label);
  final String label;

  /// Where the "and" of a beat falls: late in the ones that swing,
  /// halfway in the ones that don't.
  double get andOfBeat => swings ? 2 / 3 : 0.5;

  /// Whether this feel's eighths are long-short.
  bool get swings =>
      this == swing ||
      this == shuffle ||
      this == jazzWaltz ||
      this == ballad ||
      this == secondLine ||
      this == gypsy ||
      // Its bell is written in thirds of a beat, which is where a swung
      // off-beat lands anyway: a compound bar swings by being compound.
      this == afroSix;

  /// Where the off-beats sit before anybody touches the slider: the
  /// tempo's own swing for the feels that swing, even for the rest.
  ///
  /// The slider overrides this for any of them, which is the point: a
  /// groove that is even by convention is still a groove somebody may
  /// want to lean.
  double swingBy(int tempo) => swings ? swingAt(tempo) : straight;

  /// Whether what moves is the sixteenths rather than the eighths.
  ///
  /// Funk, and only funk. Its eighths stay where they are and the second
  /// of each pair of sixteenths is the one that leans, which is why
  /// swinging its eighths like a jazz tune sounds nothing like funk.
  bool get swingsSixteenths => this == funk;

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
    // A waltz is played from a slow three up to a bright one; Someday My
    // Prince Will Come and Bluesette sit near the middle of that.
    jazzWaltz => (slowest: 80, fastest: 260),
    // Faster than this and the brushes and the two-feel stop making
    // sense: it is a medium swing tune by then, whatever it is called.
    ballad => (slowest: 40, fastest: 85),
    // A parade walks, and then it does not: slow enough for a dirge
    // coming back from the cemetery, bright enough for the street.
    secondLine => (slowest: 70, fastest: 220),
    // Minor Swing was cut at better than two hundred, and the repertoire
    // runs faster still.
    gypsy => (slowest: 90, fastest: 300),
    // The pulse, which in six eight is the dotted quarter: slow enough
    // for a vamp, quick enough for the bright end of one.
    afroSix => (slowest: 50, fastest: 160),
  };

  /// Whether this groove has a figure for a bar of [meter].
  ///
  /// Some grooves are written beat by beat and fit any bar: swing, a
  /// ballad, a waltz, and the bell, which is a cycle laid over whatever
  /// bar it meets. Others *are* a bar-length figure: a clave, a 3-3-2, a
  /// street beat, a samba's two bars. Cut to a bar of another length
  /// they are not themselves but a fragment of themselves, which is how
  /// a calypso counted in six eight came out as half a 3-3-2 with its
  /// off-beats dragged onto triplets.
  ///
  /// A bar of three is played as itself too, but for the street beat:
  /// the 3-3-2 becomes the 3+3 a calypso in three is, the bossa's clave
  /// still turns over two bars, and a funk backbeat lands on 2 and 3.
  /// Played in its place, swing made every groove on a waltz-time tune
  /// the same groove.
  bool suits(Meter meter) =>
      !_isAFigure ||
      (!meter.compound &&
          (meter.pulses == 4 || (meter.pulses == 3 && this != secondLine)));

  /// Whether what makes this groove itself is a figure that takes a bar
  /// of four to play.
  bool get _isAFigure =>
      this == bossa ||
      this == samba ||
      this == funk ||
      this == calypso ||
      this == secondLine;

  /// What the band plays instead where this groove has no figure for the
  /// bar: the bell in compound time, and swing everywhere else, which is
  /// written beat by beat and fits any bar there is.
  ///
  /// A stand-in and not a silent swap: wherever it happens the mixer
  /// says which groove is playing and why.
  Feel standIn(Meter meter) =>
      suits(meter) ? this : (meter.compound ? afroSix : swing);

  /// Whether there is a drummer at all.
  ///
  /// Gypsy jazz is the one groove here played without one: the
  /// Quintette's rhythm was two guitars and a bass, and the chop does
  /// what a kit would. Silence is the part, not a part missing.
  bool get hasDrums => this != gypsy;

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
    Feel.jazzWaltz => swing,
    Feel.ballad => ballad,
    Feel.secondLine || Feel.gypsy => swing,
    Feel.afroSix => latin,
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
  calypso('Calypso strum'),

  /// La pompe, gypsy jazz's own: four short downstrokes a bar, 2 and 4
  /// the ones that carry, and a quick upstroke lifting into 1 and 3.
  laPompe('La Pompe');

  const PianoStyle(this.label);
  final String label;

  /// Whether the piano's eighths swing.
  Feel get feel => this == swing || this == laPompe ? Feel.swing : Feel.bossa;
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
  PianoStyle.held || PianoStyle.calypso || PianoStyle.laPompe => false,
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

/// Who plays the drums.
enum DrumSound {
  /// The band's own kit, played with sticks.
  kit('Sticks'),

  /// The same grooves played with brushes, on a kit recorded that way
  /// rather than the stick kit quietened. Brushes are not a softer stick:
  /// the snare answers with a wash instead of a crack, and the ride loses
  /// most of its ping.
  brushes('Brushes'),

  /// A drum kit out of an imported SoundFont. Each drum falls back to the
  /// band's own when the kit does not have it, so a font with no cowbell
  /// costs you a cowbell and not a calypso.
  imported('Imported Kit');

  const DrumSound(this.label);
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
    this.swing,
  });

  /// The whole band in one [feel], as the standards are played.
  factory BandStyle.of(Feel feel) => BandStyle(
    drums: feel,
    bass: switch (feel) {
      // A shuffle's bass walks like any other blues; the bounce is in the
      // drums and the comping, not in the notes it chooses.
      // A waltz walks too, three to the bar rather than four.
      // Second line walks too: the tuba or the bass holds the pulse the
      // kick is playing against. So does a gypsy bass, which can play
      // two instead, and the Bass dropdown is where that lives.
      Feel.swing ||
      Feel.shuffle ||
      Feel.jazzWaltz ||
      Feel.secondLine ||
      Feel.gypsy => BassStyle.walking,
      // A ballad is held up by two notes a bar, not four: roots and
      // fifths, with the space left in.
      // Roots and fifths on the pulse under the bell. A 6/8 tumbao is
      // its own line and is not written yet; this is the plain thing
      // rather than a guess at one.
      Feel.ballad || Feel.afroSix => BassStyle.twoFeel,
      Feel.bossa || Feel.samba => BassStyle.bossa,
      Feel.funk => BassStyle.funk,
      Feel.calypso => BassStyle.calypso,
    },
    piano: switch (feel) {
      Feel.swing ||
      Feel.shuffle ||
      Feel.jazzWaltz ||
      Feel.secondLine => PianoStyle.swing,
      Feel.gypsy => PianoStyle.laPompe,
      // Long chords, one to a change. A comper answering every phrase is
      // what a ballad does not want.
      Feel.ballad => PianoStyle.held,
      Feel.calypso => PianoStyle.calypso,
      Feel.bossa ||
      Feel.funk ||
      Feel.samba ||
      Feel.afroSix => PianoStyle.straight,
    },
  );

  final Feel drums;
  final BassStyle bass;
  final PianoStyle piano;

  /// The band as it can actually be played in [meter].
  ///
  /// A groove whose figure needs a bar of four hands over to one that
  /// does not, and the whole band goes with it: a bossa bass under a
  /// bell is two different grooves at once.
  BandStyle inMeter(Meter meter) => drums.suits(meter)
      ? this
      : BandStyle.of(drums.standIn(meter)).withFigure(figure).withSwing(swing);

  /// The one comping figure to play in every bar, or null to let the
  /// comper choose bar by bar as it always has.
  ///
  /// Null is what a band does: a comper who played the Charleston in
  /// every bar of every tune would be unbearable. It is here because
  /// hearing one figure held to for a whole chorus, against real changes
  /// and at your own tempo, is how anybody learns what it does, and the
  /// Learn screen can only offer it over two bars of a ii-V.
  final CompFigure? figure;

  /// Where the "and" falls, or null to let it follow the tempo.
  ///
  /// Null is the usual case and the better one: the short half of a swung
  /// pair stays about the same length whatever the tempo and the beat
  /// shrinks around it, so a band left alone swings hard at a ballad and
  /// nearly straight at a burn-up without being told. A number here holds
  /// it still, which is what somebody wants when they are working on one
  /// thing and the swing moving underneath them would make it a different
  /// exercise.
  ///
  /// It sits with the feel rather than in the settings because it is the
  /// same kind of fact: how this tune is played, not how the app behaves.
  final double? swing;

  BandStyle withFigure(CompFigure? figure) => BandStyle(
    drums: drums,
    bass: bass,
    piano: piano,
    figure: figure,
    swing: swing,
  );

  BandStyle withSwing(double? swing) => BandStyle(
    drums: drums,
    bass: bass,
    piano: piano,
    figure: figure,
    swing: swing,
  );

  @override
  bool operator ==(Object other) =>
      other is BandStyle &&
      other.drums == drums &&
      other.bass == bass &&
      other.piano == piano &&
      other.figure == figure &&
      other.swing == swing;

  @override
  int get hashCode => Object.hash(drums, bass, piano, figure, swing);
}

/// A chord chart: a list of bars, each holding one or more chords.
/// Whether a key label is a minor one.
///
/// The modal tunes are counted with the minor keys because that is what
/// they sound like: D Dorian is a minor tonic with a raised 6th, and
/// somebody who sees minor keys as their own colour sees that one too.
bool isMinorKeyLabel(String key) =>
    key.contains('minor') || key.contains('Dorian');

/// The note a key label is on, e.g. B♭ in "B♭" or C in "C minor".
///
/// A tune that moves key is written with the keys in order, so the first
/// one is the one it is in: "C minor, F minor" is a C minor tune.
Spelling keyTonicOf(String key) =>
    parseNoteName(RegExp(r'^[A-G][♭♯b#]?').stringMatch(key) ?? 'C')!;

/// A key, as much of it as a colour cares about: which note it is on, and
/// whether it is minor.
typedef KeyOf = ({int pitchClass, bool minor});

/// What key a label such as "G minor", "B♭" or "D Dorian" is naming.
KeyOf readKeyLabel(String key) =>
    (pitchClass: pitchClassOf(keyTonicOf(key)), minor: isMinorKeyLabel(key));

/// Which way the quartal figure moves on a modal tune.
///
/// The shape is the same either way: a stack of fourths, slid a whole
/// step. What differs is which end of the move the chord is on, and that
/// is the difference between the two tunes everybody knows the sound of.
enum QuartalSlide {
  /// No figure: the fourths are voiced and left to be comped like any
  /// other chord.
  ///
  /// The default, and it has to be. The slide is one tune's lick and not
  /// a modal device: played on every tune tagged modal it made six of
  /// them sound like So What, which is what happens when the thing a
  /// tune is known for is treated as a property of its genre.
  none,

  /// Down onto the chord, as So What does. The shape above leans and
  /// falls, and the figure resolves.
  down,

  /// Up off the chord, as Impressions does. The chord lifts to the shape
  /// above and is left there, so the figure opens instead of closing.
  up,
}

/// One bar's chords, given the beats of the bar to share between them.
///
/// They split it evenly and any leftover beat goes to the first chord,
/// so three chords in 4/4 last 2 + 1 + 1. A bar holds only as many
/// chords as it has beats for: the ones past that have nowhere to
/// sound, so they are left off rather than written in with no beats.
/// Nothing downstream, the band least of all, has any use for a chord
/// that lasts no time.
List<ChordSlot> _shareOut(
  List<Chord> chords, {
  required int barIndex,
  required int pulses,
}) {
  final kept = chords.length > pulses ? chords.sublist(0, pulses) : chords;
  final baseBeats = pulses ~/ kept.length;
  final leftover = pulses % kept.length;
  var beat = barIndex * pulses;
  final slots = <ChordSlot>[];
  for (var i = 0; i < kept.length; i++) {
    final beats = baseBeats + (i < leftover ? 1 : 0);
    slots.add(
      ChordSlot(
        chord: kept[i],
        barIndex: barIndex,
        startBeat: beat,
        beats: beats,
      ),
    );
    beat += beats;
  }
  return slots;
}

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
    required this.meter,
    required this.bars,
    required this.sections,
    required this.tags,
    required this.quartalSlide,
  });

  /// Builds a tune from a simple text chart such as
  /// `"| [A] Dm7 | G7 | CΔ7 Am7 | Dm7 G7 |"`.
  ///
  /// `[A]` at the start of a bar marks where a section of the form begins.
  /// Chords sharing a bar split its beats evenly; any leftover beat goes to
  /// the first chord (so three chords in 4/4 last 2 + 1 + 1 beats).
  ///
  /// A bar holds only as many chords as it has beats for: the chords past
  /// that have nowhere to sound, so they are left off rather than written
  /// in with no beats. Nothing downstream, the band least of all, has any
  /// use for a chord that lasts no time.
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
    Meter? meter,
    QuartalSlide quartalSlide = QuartalSlide.none,
  }) {
    // A tune says either what it counts (beatsPerBar, which is how every
    // standard here is written) or what is on the chart (meter, which is
    // the only way to say 6/8). They are the same thing in simple time.
    final written = meter ?? Meter.ofPulses(beatsPerBar);
    final pulses = written.pulses;
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

      bars.add(
        _shareOut(
          [
            for (final symbol in text.split(RegExp(r'\s+')))
              Chord.parse(symbol),
          ],
          barIndex: barIndex,
          pulses: pulses,
        ),
      );
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
      meter: written,
      bars: bars,
      sections: sections,
      tags: tags,
      quartalSlide: quartalSlide,
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

  /// The time signature on the chart.
  final Meter meter;

  /// What the band counts in a bar: the same as the written beats except
  /// in compound time, where a bar of 6/8 is counted in two.
  int get beatsPerBar => meter.pulses;

  final List<List<ChordSlot>> bars;

  /// Section letters by the bar they start on, e.g. {0: 'A', 8: 'A', 16: 'B'}.
  final Map<int, String> sections;

  /// Which way the quartal figure moves, for a tune voiced in fourths.
  /// Ignored by any tune that is not modal, which has no such figure.
  final QuartalSlide quartalSlide;

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

  bool get _isMinorKey => isMinorKeyLabel(key);

  /// The first note name in [key], e.g. B♭ in "B♭" or C in "C minor".
  Spelling get _tonic => keyTonicOf(key);

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
          meter: meter,
          sections: sections,
          tags: tags,
          quartalSlide: quartalSlide,
          bars: bars,
        );

  /// The same tune, counted in [meter].
  ///
  /// The bars keep their chords and the form keeps its letters. What
  /// changes is how the beats inside each bar are shared out, which is
  /// the whole of what a time signature decides here: Autumn Leaves in
  /// three is its changes, two beats to the first chord of a bar and one
  /// to the second. A bar with more chords than the new meter has beats
  /// loses the ones there is no room for, exactly as a chart written
  /// that way would.
  Tune inMeter(Meter meter) => meter == this.meter
      ? this
      : Tune._(
          title: title,
          composer: composer,
          year: year,
          key: key,
          description: description,
          feel: feel,
          style: style,
          defaultTempo: defaultTempo,
          meter: meter,
          sections: sections,
          tags: tags,
          quartalSlide: quartalSlide,
          bars: [
            for (var i = 0; i < bars.length; i++)
              _shareOut(
                [for (final slot in bars[i]) slot.chord],
                barIndex: i,
                pulses: meter.pulses,
              ),
          ],
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
      meter: meter,
      sections: sections,
      tags: tags,
      quartalSlide: quartalSlide,
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
