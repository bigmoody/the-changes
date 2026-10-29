// The Practice tab's roadmap: six stages from playing in time on a blues
// to a voice of your own, for each kind of instrument, and a day's routine
// cut to however long somebody has.
//
// Every stage works the same three things the whole way up, because that
// is what jazz competence is made of and what gets skipped:
//
//   Scales        the notes of the key, in every key, until they are not
//                 something you think about
//   Chord tones   the notes of the chord, which is what a line is built
//                 on and what the changes actually ask for
//   Repertoire    tunes, learned properly: melody, changes, form, from
//                 memory. Everything else is in service of this.
//
// Around them sit time and sound, the ear, the language of the music
// (patterns, enclosures, lines), and the job the instrument does in a
// band: comping for guitar and piano, walking for bass, sound and range
// for horns.
//
// Goals are ticked by the player. Nothing here pretends to grade what it
// cannot hear; the goals are written so that somebody can be honest with
// themselves about whether they can do it.

import 'dart:math' as math;

import '../music/scale_run.dart';
import 'line_exercise.dart';

/// Who the roadmap is for. Each plays the same music and has a different
/// job in the band, so the stages are shared and the work differs.
enum RoadmapInstrument {
  guitar('Guitar'),
  piano('Piano'),
  bass('Bass'),
  horn('Horns');

  const RoadmapInstrument(this.label);

  final String label;

  bool get comps => this == guitar || this == piano;
}

/// How far along somebody already is, which decides where they start on
/// the roadmap and how a day's practice is shared out.
///
/// The stages say what to work on. The level says how: a beginner on any
/// stage spends longer on the sound, the time and the scales, in the
/// easier keys, slower; somebody who gigs keeps the scales as a short
/// warm-up and spends the time on the ear, the vocabulary and the tunes,
/// faster and in every key.
enum PlayerLevel {
  beginner(
    'Beginner',
    'New to jazz, or still finding your way round the instrument.',
    startStage: 1,
    tempoScale: 0.8,
    tuneShare: 1 / 3,
    defaultMinutes: 30,
  ),
  intermediate(
    'Intermediate',
    'You can play a blues and a few standards, and improvise a little.',
    startStage: 2,
    tempoScale: 1,
    tuneShare: 1 / 3,
    defaultMinutes: 30,
  ),
  advanced(
    'Advanced',
    'You play sessions, know twenty or more tunes, and can play in every '
        'key.',
    startStage: 4,
    tempoScale: 1.15,
    tuneShare: 0.38,
    defaultMinutes: 60,
  ),
  professional(
    'Professional',
    'You gig: keeping it all up, and pushing further.',
    startStage: 5,
    tempoScale: 1.3,
    tuneShare: 0.4,
    defaultMinutes: 60,
  );

  const PlayerLevel(
    this.label,
    this.about, {
    required this.startStage,
    required this.tempoScale,
    required this.tuneShare,
    required this.defaultMinutes,
  });

  final String label;
  final String about;

  /// The stage somebody at this level starts on.
  final int startStage;

  /// How much faster (or slower) than the stage's own tempos the exercises
  /// start and aim for.
  final double tempoScale;

  /// How much of a session of half an hour or more goes on the tune.
  final double tuneShare;
  final int defaultMinutes;

  /// How much more (or less) of the day [area] gets than the stage's own
  /// balance gives it.
  double weightFor(Area area) => switch ((this, area)) {
    (beginner, Area.sound) => 1.5,
    (beginner, Area.scales) => 1.3,
    (beginner, Area.language) => 0.6,
    (beginner, Area.ear) => 0.8,
    (beginner, Area.session) => 0.5,
    (advanced, Area.sound || Area.scales) => 0.8,
    (advanced, Area.language || Area.ear || Area.session) => 1.2,
    (professional, Area.sound || Area.scales) => 0.6,
    (professional, Area.chordTones) => 0.9,
    (professional, Area.language) => 1.3,
    (professional, Area.ear) => 1.4,
    (professional, Area.role) => 1.1,
    _ => 1,
  };

  /// The keys today's key is drawn from, out of the stage's [keys]: a
  /// beginner stays in the keys the tunes are mostly written in until
  /// those are easy, whatever the stage says; everybody else takes them
  /// all.
  List<String> keysFrom(List<String> keys) {
    if (this != beginner) return keys;
    final easy = [
      for (final key in keys)
        if (_easyKeys.contains(key)) key,
    ];
    return easy.isEmpty ? keys : easy;
  }

  /// [tempo] at this level, to the nearest five.
  int tempo(int tempo) => ((tempo * tempoScale) / 5).round() * 5;
}

const _easyKeys = {'C', 'F', 'B♭', 'E♭', 'G', 'D'};

/// What a piece of practice works on.
enum Area {
  sound('Sound and Time'),
  scales('Scales'),
  chordTones('Chord Tones'),
  language('Language'),
  role('In the Band'),
  ear('Ear'),
  repertoire('Repertoire'),

  /// What a jam session asks for that practising alone does not, and the
  /// sessions themselves.
  session('On the Stand');

  const Area(this.label);

  final String label;

  /// What "in the band" means for [instrument].
  String labelFor(RoadmapInstrument instrument) => this != role
      ? label
      : switch (instrument) {
          RoadmapInstrument.guitar || RoadmapInstrument.piano => 'Comping',
          RoadmapInstrument.bass => 'Walking',
          RoadmapInstrument.horn => 'Sound and Range',
        };
}

/// The pages in the app a piece of practice is done on.
enum Tool {
  metronome('Metronome'),
  swing('Swing'),
  scalesReference('Scales & Modes'),
  scalePatterns('Scale Patterns'),
  numberPatterns('Number Patterns'),
  bebopScales('Bebop Scales'),
  chordTones('Chord Tones'),
  chordQuiz('Chord Quiz'),
  guideTones('Guide Tones'),
  changesInKeys('Changes in Twelve Keys'),
  throughTheChanges('Through the Changes'),
  enclosures('Enclosures'),
  passingChords('Between the Chords'),
  earTraining('Name What You Hear'),
  whereAmI('Where Am I?'),
  walkingBass('Walking Bass'),
  comping('Comping'),
  voicings('Voicings'),
  guitarChords('Guitar Chords'),
  trading('Trading Fours'),
  rhythmChanges('Rhythm Changes'),
  tritoneSubs('Tritone Subs'),
  upperStructures('Upper Structures'),
  modal('Modal'),
  listening('Listening'),
  tuner('Tuner');

  const Tool(this.label);

  final String label;
}

/// One thing a stage asks you to be able to do.
class Goal {
  const Goal(this.id, this.area, this.text);

  /// Kept with the tick, so it must never change once shipped.
  final String id;
  final Area area;
  final String text;
}

/// A kind of practice a stage's routine draws on.
class Block {
  const Block({
    required this.area,
    required this.title,
    required this.how,
    required this.weight,
    this.tool,
    this.modes = const [],
    this.exercise,
    this.line,
    this.licks,
    this.drills,
  });

  final Area area;
  final String title;

  /// What to do, in a sentence or two. `{key}` is today's key.
  final String how;

  /// Its share of the time. Repertoire is always the biggest: the scales
  /// are for the tunes, not the other way round.
  final int weight;
  final Tool? tool;

  /// The modes it works on, by their names in `modes`, so the routine can
  /// say where each is heard.
  final List<String> modes;

  /// For a block that is a scale to play, how to play it: the Practice
  /// tab opens it as an exercise rather than as a page to read.
  final ScaleExercise? exercise;

  /// For a block that is lines to play with marks on them (articulation),
  /// the lines: the Practice tab opens it as an exercise.
  final LineExercise? line;

  /// For a block of licks to play over their changes, their names in
  /// `licks`, or every lick when the list is empty.
  final List<String>? licks;

  /// For a block of session drills, which set.
  final SessionDrillSet? drills;
}

/// The drills a session block opens.
enum SessionDrillSet {
  /// Intros, choruses, trading, endings, signals, doing your job.
  skills,

  /// The band drops out, and you come back in with it.
  recover,
}

/// A scale to play, not read about: each of the block's modes in today's
/// key, run in each of [ways], at a tempo that climbs from [from] to [to].
class ScaleExercise {
  const ScaleExercise({
    required this.ways,
    required this.from,
    required this.to,
  });

  /// The shapes to run the scale in, by their names in `scalePatterns`,
  /// or [straight] for up and down.
  final List<String> ways;

  /// Where the tempo starts, and where the stage wants it to be, in beats
  /// a minute with two notes to the beat.
  final int from;
  final int to;

  static const straight = straightRun;
}

class Stage {
  const Stage({
    required this.number,
    required this.title,
    required this.aim,
    required this.keys,
    required this.goals,
    required this.blocks,
    required this.tunes,
  });

  final int number;
  final String title;

  /// What you can do at the end of it, in one line.
  final String aim;

  /// The keys today's key is taken from, in the order they come round.
  final List<String> keys;
  final List<Goal> goals;
  final List<Block> blocks;

  /// The tunes to learn on this stage, by their titles in the library.
  final List<String> tunes;
}

/// One block of today's routine, with its minutes.
class RoutineBlock {
  const RoutineBlock({
    required this.block,
    required this.minutes,
    required this.how,
    required this.key,
    required this.tuneOfTheDay,
    this.level = PlayerLevel.intermediate,
    this.tune,
  });

  final Block block;

  /// Today's key, which a tune the block's modes are heard in is moved to.
  final String key;
  final int minutes;

  /// The block's instructions with today's key (and tune) put in.
  final String how;

  /// The tune to play, for a repertoire block.
  final String? tune;

  /// Today's tune, which session drills are played on.
  final String tuneOfTheDay;

  /// Who it is for, which sets the tempos its exercises start at.
  final PlayerLevel level;
}

/// The session lengths on offer, in minutes.
const sessionLengths = [15, 30, 60, 90];

const _someKeys = ['C', 'F', 'B♭', 'G'];
const _allKeys = [
  'C', 'F', 'B♭', 'E♭', 'A♭', 'D♭', 'G♭', 'B', 'E', 'A', 'D', 'G', //
];

/// The six stages for [instrument].
List<Stage> stagesFor(RoadmapInstrument instrument) => [
  for (var n = 1; n <= 6; n++) _stage(n, instrument),
];

Stage _stage(int n, RoadmapInstrument i) {
  final horn = i == RoadmapInstrument.horn;
  final bass = i == RoadmapInstrument.bass;
  final guitar = i == RoadmapInstrument.guitar;
  // How far up the instrument a scale goes: two octaves where it can.
  final range = horn
      ? 'across your whole comfortable range'
      : bass
      ? 'two octaves where the neck allows'
      : 'two octaves';
  return switch (n) {
    1 => Stage(
      number: 1,
      title: 'Time, Sound and the Blues',
      aim: 'Play in time with a good sound, in four keys, on a blues.',
      keys: _someKeys,
      tunes: const [
        'C Jam Blues',
        'Blue Monk',
        'Tenor Madness',
        'Sonnymoon for Two',
        'Jazz blues in F',
      ],
      goals: [
        const Goal(
          's1-time',
          Area.sound,
          'Keep eight bars steady with the click on 2 and 4 only, at 80.',
        ),
        Goal(
          's1-scales',
          Area.scales,
          'Major scales in C, F, B♭ and G, $range, in even eighths at 80.',
        ),
        const Goal(
          's1-arps',
          Area.chordTones,
          'Arpeggiate the Δ7, 7 and m7 chords on those four roots, up and '
              'down, without stopping to think.',
        ),
        const Goal(
          's1-blues',
          Area.chordTones,
          'Name the three chords of a blues in F and B♭, and play their '
              'roots, thirds and sevenths as they go past.',
        ),
        const Goal(
          's1-ear',
          Area.ear,
          'Hear where the IV chord and the turnaround come in a blues '
              'without looking at the chart.',
        ),
        ..._roleGoals(1, i),
        Goal(
          's1-tunes',
          Area.repertoire,
          horn
              ? 'Play the melodies of C Jam Blues, Blue Monk and Tenor '
                    'Madness from memory, with the band.'
              : 'Play C Jam Blues, Blue Monk and Tenor Madness with the '
                    'band: melody and your part, from memory.',
        ),
      ],
      blocks: [
        _warmUp(i, 1),
        Block(
          area: Area.scales,
          title: 'Scale of the Day',
          exercise: ScaleExercise(
            ways: ['Straight', 'In 3rds'],
            from: 70,
            to: 90,
          ),
          modes: ['Ionian'],
          how:
              '{key} major, $range, slowly and evenly at {from} to {to}. Then in '
              'thirds. Say each note name as you go.',
          weight: 3,
          tool: Tool.scalesReference,
        ),
        const Block(
          area: Area.chordTones,
          title: 'Arpeggios',
          modes: ['Ionian', 'Mixolydian', 'Dorian'],
          exercise: ScaleExercise(ways: [arpeggioRun], from: 70, to: 90),
          how:
              'Δ7, 7 and m7 on {key}: root to seventh and back, then from the '
              'seventh down. Hear each one before you play it.',
          weight: 3,
          tool: Tool.chordTones,
        ),
        _roleBlock(1, i),
        const Block(
          area: Area.ear,
          title: 'Hear the Form',
          modes: ['Mixolydian', 'Blues scale'],
          how:
              'Put on a blues and call out each chord change as it comes. '
              'Then check yourself against the chart.',
          weight: 1,
          tool: Tool.whereAmI,
        ),
        _lickBlock(['The Blue Third', 'The Lick']),
        _tuneBlock(i),
      ],
    ),
    2 => Stage(
      number: 2,
      title: 'Chord Tones and the ii–V–I',
      aim:
          'Outline the changes of a standard, in all twelve keys of the '
          'ii–V–I.',
      keys: _allKeys,
      tunes: const [
        'Autumn Leaves',
        'Blue Bossa',
        'All of Me',
        'Satin Doll',
        'Misty',
        'Major ii–V–I in three keys',
      ],
      goals: [
        Goal(
          's2-scales',
          Area.scales,
          'All twelve major scales, $range, at 100, round the cycle of '
              'fourths without stopping.',
        ),
        const Goal(
          's2-arps',
          Area.chordTones,
          'Δ7, 7, m7 and ø7 arpeggios in all twelve keys.',
        ),
        const Goal(
          's2-251',
          Area.chordTones,
          'Play a ii–V–I in every key, landing on the third of the I.',
        ),
        const Goal(
          's2-guide',
          Area.chordTones,
          'Play only the thirds and sevenths through Autumn Leaves, '
              'moving each by a step or less.',
        ),
        const Goal(
          's2-ear',
          Area.ear,
          'Tell a Δ7, a 7 and an m7 apart by ear, nine times out of ten.',
        ),
        ..._roleGoals(2, i),
        const Goal(
          's2-listen',
          Area.session,
          'Go to a jam session and listen to the whole night. Write down '
              'every tune called, and add them to My Session\'s Tunes.',
        ),
        const Goal(
          's2-recover',
          Area.session,
          'Keep your place through four bars with the band gone, and come '
              'back in with it, every time, on three tunes.',
        ),
        const Goal(
          's2-tunes',
          Area.repertoire,
          'Five tunes from memory, eight in all: melody, changes and form.',
        ),
      ],
      blocks: [
        _warmUp(i, 2),
        Block(
          area: Area.scales,
          title: 'Scale of the Day',
          exercise: ScaleExercise(
            ways: ['Straight', 'Sevenths'],
            from: 90,
            to: 110,
          ),
          modes: ['Ionian'],
          how:
              '{key} major, $range, at {from} to {to}. Then the seventh chord '
              'on every degree of it: the scale as the harmony it holds.',
          weight: 3,
          tool: Tool.scalePatterns,
        ),
        const Block(
          area: Area.chordTones,
          title: 'ii–V–I in Every Key',
          how:
              'The ii–V–I in {key}, then round the cycle. Arpeggiate each '
              'chord, and resolve the seventh of each down a step.',
          weight: 3,
          tool: Tool.changesInKeys,
        ),
        const Block(
          area: Area.chordTones,
          title: 'Guide Tones',
          how:
              'Thirds and sevenths only, through the tune of the day. The '
              'smallest move from each to the next.',
          weight: 2,
          tool: Tool.guideTones,
        ),
        _roleBlock(2, i),
        const Block(
          area: Area.ear,
          title: 'Chord Qualities',
          how: 'A round of Name What You Hear on seventh chords.',
          weight: 1,
          tool: Tool.earTraining,
        ),
        _lickBlock(['The Lick', '1 2 3 5 Down the Changes', 'The Blue Third']),
        _recoverBlock(),
        _tuneBlock(i),
      ],
    ),
    3 => Stage(
      number: 3,
      title: 'Minor Keys and the Language',
      aim:
          'Play lines, not scales: bebop vocabulary over major and minor '
          'ii–V–Is.',
      keys: _allKeys,
      tunes: const [
        'Summertime',
        'Solar',
        'Mr. P.C.',
        'Song for My Father',
        'Softly, as in a Morning Sunrise',
        'Black Orpheus',
        'My Funny Valentine',
        'Minor ii–V–i',
      ],
      goals: [
        Goal(
          's3-minor',
          Area.scales,
          'Dorian and melodic minor in all twelve keys, $range.',
        ),
        const Goal(
          's3-bebop',
          Area.scales,
          'The bebop dominant scale in all twelve keys, with the chord '
              'tones on the beat.',
        ),
        const Goal(
          's3-minor251',
          Area.chordTones,
          'ø7, 7♭9 and m6 arpeggios, and the minor ii–V–i, in every key.',
        ),
        const Goal(
          's3-enclose',
          Area.language,
          'Enclose the third and the root of any chord from above and below.',
        ),
        const Goal(
          's3-patterns',
          Area.language,
          '1–2–3–5 and 3–5–7–9 on every chord of a ii–V–I, in four keys.',
        ),
        const Goal(
          's3-transcribe',
          Area.ear,
          'Learn four bars of a solo off a record by ear, and play it in '
              'two keys.',
        ),
        ..._roleGoals(3, i),
        const Goal(
          's3-sit-in',
          Area.session,
          'Sit in on a blues at a jam: the head, a chorus or two, the head '
              'out, and end with the band.',
        ),
        const Goal(
          's3-intro',
          Area.session,
          'Come in on the last-four intro and play the head of three tunes '
              'from memory, landing on bar 1 every time.',
        ),
        const Goal(
          's3-tunes',
          Area.repertoire,
          'Five more tunes from memory, thirteen in all, two of them minor.',
        ),
      ],
      blocks: [
        _warmUp(i, 3),
        Block(
          area: Area.scales,
          title: 'Minor Scales',
          exercise: ScaleExercise(
            ways: ['Straight', 'In 3rds'],
            from: 100,
            to: 120,
          ),
          modes: ['Dorian', 'Melodic minor'],
          how:
              '{key} Dorian, then {key} melodic minor, $range. Then the '
              'bebop dominant on {key}, chord tones on the beat.',
          weight: 2,
          tool: Tool.bebopScales,
        ),
        const Block(
          area: Area.chordTones,
          title: 'Minor ii–V–i',
          how:
              'The minor ii–V–i to {key} minor: ø7, 7♭9, m6, arpeggiated, '
              'then joined into one line.',
          weight: 3,
          tool: Tool.changesInKeys,
        ),
        const Block(
          area: Area.language,
          title: 'Patterns and Enclosures',
          how:
              'One pattern, or one enclosure, through the changes of the '
              'tune of the day. Keep it until it sounds like music.',
          weight: 2,
          tool: Tool.enclosures,
        ),
        _roleBlock(3, i),
        const Block(
          area: Area.ear,
          title: 'Off the Record',
          how:
              'Two bars of a solo you love, by ear: sing it, then find it. '
              'No notation until you can play it.',
          weight: 2,
          tool: Tool.listening,
        ),
        _lickBlock([
          'Up the ii, 3 to ♭9 on the V',
          'Enclosure Into the Third',
          'ø Up, ♭9 Down',
        ]),
        _recoverBlock(),
        _sessionBlock(),
        _tuneBlock(i),
      ],
    ),
    4 => Stage(
      number: 4,
      title: 'Standards and Rhythm Changes',
      aim: 'Hold your own on a session: the common tunes, at session tempos.',
      keys: _allKeys,
      tunes: const [
        'All the Things You Are',
        'There Will Never Be Another You',
        'Oleo',
        'Anthropology',
        'Just Friends',
        'Have You Met Miss Jones?',
        'The Girl from Ipanema',
        'In a Sentimental Mood',
        'Rhythm changes in B♭',
      ],
      goals: [
        const Goal(
          's4-scales',
          Area.scales,
          'Every major and melodic minor scale, from any note of it, at 160.',
        ),
        const Goal(
          's4-rhythm',
          Area.chordTones,
          'Outline rhythm changes in B♭ at 160: the A sections with I–vi–ii–V '
              'and the bridge with its dominants.',
        ),
        const Goal(
          's4-through',
          Area.chordTones,
          'Play a continuous line of eighths through All the Things You Are, '
              'landing a chord tone on every change.',
        ),
        const Goal(
          's4-trade',
          Area.language,
          'Trade fours with the drums for three choruses without losing '
              'the form.',
        ),
        const Goal(
          's4-keys',
          Area.repertoire,
          'Play three tunes in a second key, by ear rather than by '
              'transposing the chart.',
        ),
        ..._roleGoals(4, i),
        const Goal(
          's4-call',
          Area.session,
          'Call a standard at a jam and count it off: the head, a solo, '
              'trade fours if asked, take it out and end together.',
        ),
        const Goal(
          's4-signals',
          Area.session,
          'Follow the signals (take it out, trade fours, the ending) without '
              'stopping, on the night.',
        ),
        const Goal(
          's4-ballad',
          Area.session,
          'Play a ballad and a bossa from memory at a session, as well as '
              'the swing tunes.',
        ),
        const Goal(
          's4-tunes',
          Area.repertoire,
          'Twenty tunes from memory, including two rhythm changes heads.',
        ),
      ],
      blocks: [
        _warmUp(i, 4),
        Block(
          area: Area.scales,
          title: 'Scales at Tempo',
          exercise: ScaleExercise(
            ways: ['Straight', 'In fours'],
            from: 140,
            to: 160,
          ),
          modes: ['Ionian', 'Melodic minor'],
          how:
              '{key} major and {key} melodic minor, $range, starting from '
              'each degree in turn. Push the tempo up five a week.',
          weight: 2,
          tool: Tool.scalePatterns,
        ),
        const Block(
          area: Area.chordTones,
          title: 'Through the Changes',
          how:
              'A line of eighths through the tune of the day, a chord tone '
              'on every change. Then the same with the band at tempo.',
          weight: 3,
          tool: Tool.throughTheChanges,
        ),
        const Block(
          area: Area.chordTones,
          title: 'Rhythm Changes',
          how:
              'The A section and the bridge of rhythm changes, in B♭ and then '
              'in {key}.',
          weight: 2,
          tool: Tool.rhythmChanges,
        ),
        _roleBlock(4, i),
        const Block(
          area: Area.language,
          title: 'Trading Fours',
          how: 'Four bars yours, four the drummer\'s, for three choruses.',
          weight: 1,
          tool: Tool.trading,
        ),
        _lickBlock([
          'Bebop Scale Down the V',
          'Enclosure Into the Third',
          'Up the ii, 3 to ♭9 on the V',
        ]),
        _sessionBlock(),
        _tuneBlock(i),
      ],
    ),
    5 => Stage(
      number: 5,
      title: 'Colour and Tension',
      aim:
          'Choose the tension: altered dominants, substitutions and modes '
          'on purpose.',
      keys: _allKeys,
      tunes: const [
        'Stella by Starlight',
        'Body and Soul',
        'Days of Wine and Roses',
        'So What',
        'Maiden Voyage',
        'Joy Spring',
        'Wave',
      ],
      goals: [
        const Goal(
          's5-altered',
          Area.scales,
          'The altered scale and the half-whole diminished in all twelve '
              'keys, and when to use each.',
        ),
        const Goal(
          's5-tritone',
          Area.chordTones,
          'Play a ii–V–I with a tritone sub in every key, and hear the '
              'difference.',
        ),
        const Goal(
          's5-upper',
          Area.chordTones,
          'Play the ♭9, ♯9, ♯11 and ♭13 of any dominant at once, and resolve '
              'each to a chord tone of the I.',
        ),
        const Goal(
          's5-modal',
          Area.language,
          'Solo for three choruses on So What with shape and space, not just '
              'the Dorian scale up and down.',
        ),
        const Goal(
          's5-ear',
          Area.ear,
          'Hear whether a dominant is natural or altered as it goes past.',
        ),
        ..._roleGoals(5, i),
        const Goal(
          's5-tunes',
          Area.repertoire,
          'Thirty tunes from memory, two ballads among them.',
        ),
      ],
      blocks: [
        _warmUp(i, 5),
        const Block(
          area: Area.scales,
          title: 'Altered and Diminished',
          exercise: ScaleExercise(
            ways: ['Straight', 'In 3rds'],
            from: 100,
            to: 140,
          ),
          modes: ['Altered', 'Half-whole diminished'],
          how:
              'The altered scale on {key}7, then the half-whole diminished '
              'on {key}7. Resolve each to the I.',
          weight: 2,
          tool: Tool.scalesReference,
        ),
        const Block(
          area: Area.chordTones,
          title: 'Tension and Release',
          how:
              'Through the tune of the day, alter every dominant and resolve '
              'the tension to the third of the next chord.',
          weight: 3,
          tool: Tool.upperStructures,
        ),
        const Block(
          area: Area.language,
          title: 'Substitutions',
          modes: ['Lydian dominant'],
          how: 'Tritone subs and passing chords on the ii–V–I in {key}.',
          weight: 2,
          tool: Tool.tritoneSubs,
        ),
        _roleBlock(5, i),
        const Block(
          area: Area.ear,
          title: 'Modal Space',
          modes: ['Dorian', 'Mixolydian'],
          how:
              'A chorus on a modal vamp with a motif you keep and develop. '
              'Leave as much space as you fill.',
          weight: 1,
          tool: Tool.modal,
        ),
        _lickBlock([
          'ø Up, ♭9 Down',
          'Up the ii, 3 to ♭9 on the V',
          'Bebop Scale Down the V',
        ]),
        _sessionBlock(),
        _tuneBlock(i),
      ],
    ),
    _ => Stage(
      number: 6,
      title: 'Your Own Voice',
      aim: 'Any tune, any key, any tempo, and something to say on it.',
      keys: _allKeys,
      tunes: const [
        'Giant Steps',
        'Donna Lee',
        'Confirmation',
        'Cherokee',
        'Countdown',
        'Inner Urge',
        'Corcovado',
      ],
      goals: [
        const Goal(
          's6-giant',
          Area.chordTones,
          'Arpeggiate the changes of Giant Steps at 160, then play a line '
              'through them at 120.',
        ),
        const Goal(
          's6-keys',
          Area.repertoire,
          'Play a standard you know in all twelve keys.',
        ),
        const Goal(
          's6-tempo',
          Area.sound,
          'A ballad at 50 and an up tune at 260, each with the time '
              'still swinging.',
        ),
        const Goal(
          's6-solo',
          Area.ear,
          'Learn a whole chorus of a solo by ear and play it with the record.',
        ),
        ..._roleGoals(6, i),
        const Goal(
          's6-tunes',
          Area.repertoire,
          'Fifty tunes from memory, and one of your own written on changes '
              'you know.',
        ),
      ],
      blocks: [
        _warmUp(i, 6),
        Block(
          area: Area.scales,
          title: 'Scales Without Thinking',
          exercise: ScaleExercise(
            ways: ['Straight', '1 2 3 5'],
            from: 160,
            to: 200,
          ),
          modes: [
            'Melodic minor',
            'Altered',
            'Whole tone',
            'Half-whole diminished',
          ],
          how:
              'Every scale on {key}: major, the minors, the bebop and the '
              'symmetric ones, $range, at the top of your tempo.',
          weight: 1,
          tool: Tool.scalesReference,
        ),
        const Block(
          area: Area.chordTones,
          title: 'Hard Changes',
          how:
              'Giant Steps or Countdown: arpeggios first, then lines, a '
              'metronome mark faster each week.',
          weight: 3,
          tool: Tool.throughTheChanges,
        ),
        const Block(
          area: Area.ear,
          title: 'A Chorus Off the Record',
          how: 'Four more bars of the solo you are learning, by ear.',
          weight: 2,
          tool: Tool.listening,
        ),
        _roleBlock(6, i),
        Block(
          area: Area.language,
          title: 'Twelve Keys',
          how: guitar || i == RoadmapInstrument.piano
              ? 'The tune of the day in {key}: melody and comping, by ear.'
              : 'The tune of the day in {key}: melody and a chorus, by ear.',
          weight: 2,
        ),
        _lickBlock(null),
        _sessionBlock(),
        _tuneBlock(i),
      ],
    ),
  };
}

Block _warmUp(RoadmapInstrument i, int stage) => switch (i) {
  RoadmapInstrument.horn => Block(
    area: Area.sound,
    title: 'Long Tones',
    how: stage < 3
        ? 'Long tones from the middle of the horn outwards, against the '
              'tuner. Then the chromatic scale over your range.'
        : 'Long tones with crescendo and diminuendo, then overtones or lip '
              'slurs. The sound comes first.',
    weight: 2,
    tool: Tool.tuner,
  ),
  _ => Block(
    area: Area.sound,
    title: 'Time',
    how: stage < 3
        ? 'Click on 2 and 4 only at 80. Play quarter notes, then swung '
              'eighths, until the click disappears into them.'
        : 'Click on 4 only, or one beat in a bar, at a tempo that scares you '
              'a little. Lock in before you play anything hard.',
    weight: 1,
    tool: Tool.metronome,
  ),
};

/// Vocabulary: licks over the changes they belong to, in today's key,
/// played by the band and then answered. [names] are the stage's licks;
/// null is every one of them.
Block _lickBlock(List<String>? names) => Block(
  area: Area.language,
  title: 'Licks in Context',
  how:
      'Each lick over its changes in {key}: the band plays it, then the '
      'changes come round and you answer. Then change where it starts.',
  weight: 2,
  licks: names ?? const [],
);

/// Session skills on the tune of the day: intros, choruses, trading,
/// endings, signals, doing your job when it is not your solo.
Block _sessionBlock() => const Block(
  area: Area.session,
  title: 'Session Skills',
  how:
      'On today\'s tune: come in on a last-four intro, take two choruses '
      'between the heads, trade fours, and end together with the band.',
  weight: 2,
  drills: SessionDrillSet.skills,
);

/// Losing your place and finding it: the band drops out and comes back.
Block _recoverBlock() => const Block(
  area: Area.session,
  title: 'Get Lost and Recover',
  how:
      'On today\'s tune, the band drops out for two, four or eight bars at a '
      'time. Keep your place and come back in with it.',
  weight: 2,
  drills: SessionDrillSet.recover,
);

Block _tuneBlock(RoadmapInstrument i) => Block(
  area: Area.repertoire,
  title: 'Tune of the Day',
  how: switch (i) {
    RoadmapInstrument.horn =>
      '{tune}: the melody until it is memorised, then choruses over the '
          'changes with the band.',
    RoadmapInstrument.bass =>
      '{tune}: the melody, then walk choruses of it with the band from '
          'memory.',
    _ =>
      '{tune}: the melody, then comp a chorus and solo a chorus with the '
          'band, from memory.',
  },
  weight: 6,
);

/// The job [i] does in a band, at [stage].
Block _roleBlock(int stage, RoadmapInstrument i) {
  final (title, how, tool) = switch ((i, stage)) {
    (RoadmapInstrument.guitar, 1) => (
      'Shell Voicings',
      'Root, third and seventh, roots on the sixth and fifth strings, '
          'through a blues in quarter notes, Freddie Green style.',
      Tool.guitarChords,
    ),
    (RoadmapInstrument.guitar, 2) => (
      'Drop 2 Voicings',
      'Drop 2 voicings on the top four strings through the ii–V–I in '
          '{key}, each voice moving as little as it can.',
      Tool.voicings,
    ),
    (RoadmapInstrument.guitar, 3) => (
      'Comping Rhythms',
      'The Charleston and its variations, comping through the tune of the '
          'day. Short chords, and let the bass have the bottom.',
      Tool.comping,
    ),
    (RoadmapInstrument.guitar, 4) => (
      'Chord Melody',
      'A ballad\'s melody on top, harmonised with the voicings you know.',
      Tool.guitarChords,
    ),
    (RoadmapInstrument.guitar, 5) => (
      'Altered Voicings',
      'Upper-structure and altered voicings on the dominants of the tune '
          'of the day.',
      Tool.upperStructures,
    ),
    (RoadmapInstrument.guitar, _) => (
      'Comp and Solo Together',
      'Solo with chords between your phrases, the way a trio guitarist '
          'has to.',
      Tool.comping,
    ),
    (RoadmapInstrument.piano, 1) => (
      'Left-Hand Shells',
      'Root and seventh, or root and third, in the left hand under the '
          'melody of the tune of the day.',
      Tool.voicings,
    ),
    (RoadmapInstrument.piano, 2) => (
      'Rootless Voicings',
      'The A and B rootless voicings through the ii–V–I in {key}, then '
          'round the cycle.',
      Tool.voicings,
    ),
    (RoadmapInstrument.piano, 3) => (
      'Comping Rhythms',
      'The Charleston and its variations with two-hand voicings, behind '
          'the band. Leave room.',
      Tool.comping,
    ),
    (RoadmapInstrument.piano, 4) => (
      'Solo Piano',
      'A ballad alone: stride or walking tenths in the left hand, melody '
          'and fills in the right.',
      Tool.voicings,
    ),
    (RoadmapInstrument.piano, 5) => (
      'Upper Structures',
      'Upper-structure triads over the dominants of the tune of the day.',
      Tool.upperStructures,
    ),
    (RoadmapInstrument.piano, _) => (
      'Quartal and Modal Voicings',
      'Fourths and So What voicings, moved in parallel and against the '
          'line, on a modal tune.',
      Tool.modal,
    ),
    (RoadmapInstrument.bass, 1) => (
      'Roots and Fifths',
      'A two-feel, roots on 1 and fifths on 3, through a blues. Lock in '
          'with the drums.',
      Tool.walkingBass,
    ),
    (RoadmapInstrument.bass, 2) => (
      'Walking on Chord Tones',
      'Quarter notes, a chord tone on every beat, the root on every '
          'change, through the tune of the day.',
      Tool.walkingBass,
    ),
    (RoadmapInstrument.bass, 3) => (
      'Approach Notes',
      'Walk with a chromatic approach into every new root, from above '
          'and from below.',
      Tool.walkingBass,
    ),
    (RoadmapInstrument.bass, 4) => (
      'Walking at Tempo',
      'Three choruses of rhythm changes at 160, then a ballad in two at 60.',
      Tool.rhythmChanges,
    ),
    (RoadmapInstrument.bass, 5) => (
      'Pedals and Subs',
      'Pedal points under ii–Vs and tritone subs in the line, on the tune '
          'of the day.',
      Tool.tritoneSubs,
    ),
    (RoadmapInstrument.bass, _) => (
      'Bass Solos',
      'A chorus of solo that still says where the form is, then walk '
          'straight back in.',
      Tool.trading,
    ),
    (RoadmapInstrument.horn, 1) => (
      'Articulation',
      'Swung eighths with the legato tongue: tongue the off-beats, slur '
          'into the beats, accent the top of a line.',
      Tool.swing,
    ),
    (RoadmapInstrument.horn, 2) => (
      'Range',
      'The scale of the day to the top and bottom of your range, a '
          'semitone further each week.',
      Tool.scalesReference,
    ),
    (RoadmapInstrument.horn, 3) => (
      'Ghosting and Phrasing',
      'Ghost the notes between the accents, and start phrases off the '
          'beat as well as on it.',
      Tool.swing,
    ),
    (RoadmapInstrument.horn, 4) => (
      'Bebop Heads at Tempo',
      'A bebop head at the record\'s tempo, clean, with the band.',
      Tool.rhythmChanges,
    ),
    (RoadmapInstrument.horn, 5) => (
      'The Ballad Sound',
      'A ballad melody played straight, with vibrato and the sound '
          'you want, before a single embellishment.',
      Tool.tuner,
    ),
    (RoadmapInstrument.horn, _) => (
      'Altissimo and Extremes',
      'The top of the horn and the very bottom, at a whisper and at full '
          'sound.',
      Tool.tuner,
    ),
  };
  final horn = i == RoadmapInstrument.horn;
  return Block(
    area: Area.role,
    title: title,
    how: how,
    weight: 3,
    tool: tool,
    // The horn's work is played, not read about: articulation and
    // ghosting as lines with marks on them, and range as a scale that
    // goes to the edges.
    line: horn && stage == 1
        ? articulation
        : horn && stage == 3
        ? ghosting
        : null,
    modes: horn && stage == 2 ? const ['Ionian'] : const [],
    exercise: horn && stage == 2
        ? const ScaleExercise(ways: [straightRun], from: 70, to: 100)
        : null,
  );
}

/// What the instrument's job asks for at [stage].
List<Goal> _roleGoals(int stage, RoadmapInstrument i) {
  final text = switch ((i, stage)) {
    (RoadmapInstrument.guitar, 1) =>
      'Comp a whole blues in F with shell voicings, four to the bar, at 100.',
    (RoadmapInstrument.guitar, 2) =>
      'Drop 2 voicings of ii–V–I in all twelve keys on the top four '
          'strings.',
    (RoadmapInstrument.guitar, 3) =>
      'Comp through a minor tune with Charleston rhythms, never on top of '
          'the melody.',
    (RoadmapInstrument.guitar, 4) =>
      'Play a ballad as chord melody, from memory.',
    (RoadmapInstrument.guitar, 5) =>
      'Altered and upper-structure voicings on every dominant of a '
          'standard.',
    (RoadmapInstrument.guitar, _) =>
      'Accompany yourself: solo a chorus with comping between phrases.',
    (RoadmapInstrument.piano, 1) =>
      'Left-hand shells under the melody of three blues heads.',
    (RoadmapInstrument.piano, 2) =>
      'A and B rootless voicings of ii–V–I in all twelve keys.',
    (RoadmapInstrument.piano, 3) =>
      'Comp two-handed through a standard behind the band, with rhythm '
          'and space.',
    (RoadmapInstrument.piano, 4) => 'Play a ballad as solo piano, from memory.',
    (RoadmapInstrument.piano, 5) =>
      'Upper-structure triads on every dominant of a standard.',
    (RoadmapInstrument.piano, _) =>
      'Comp a modal tune in fourths, and solo with the left hand comping.',
    (RoadmapInstrument.bass, 1) =>
      'A two-feel through a blues in F at 100 for five choruses, '
          'never losing the form.',
    (RoadmapInstrument.bass, 2) =>
      'Walk Autumn Leaves at 120, a chord tone on every beat.',
    (RoadmapInstrument.bass, 3) =>
      'Walk a minor blues with chromatic approaches into every root.',
    (RoadmapInstrument.bass, 4) =>
      'Walk three choruses of rhythm changes at 160, and a ballad in two.',
    (RoadmapInstrument.bass, 5) =>
      'Use pedals and tritone subs in a walking line, and still sound '
          'like the changes.',
    (RoadmapInstrument.bass, _) =>
      'Solo a chorus that keeps the form audible, and walk back in on time.',
    (RoadmapInstrument.horn, 1) =>
      'The chromatic scale over your whole comfortable range with an even '
          'sound top to bottom.',
    (RoadmapInstrument.horn, 2) =>
      'Swung eighths at 120 with legato tonguing, the scale of the day '
          'through your range.',
    (RoadmapInstrument.horn, 3) =>
      'Ghosted notes and phrases starting on the off-beats, over a minor '
          'blues.',
    (RoadmapInstrument.horn, 4) =>
      'Two bebop heads clean at the record\'s tempo.',
    (RoadmapInstrument.horn, 5) =>
      'A ballad melody, played straight with your best sound, that holds '
          'a room.',
    (RoadmapInstrument.horn, _) =>
      'An even sound from the bottom of the horn to the top of your range, '
          'loud and soft.',
  };
  return [Goal('s$stage-role-${i.name}', Area.role, text)];
}

/// Today's routine on [stage], cut to [minutes].
///
/// Each block gets time in proportion to its weight. When there is not
/// enough time for all of them, the smallest drop out, taking turns from
/// day to day so nothing is left out for good. Repertoire and the warm-up
/// never drop: the tune is what all of it is for, and a cold start is how
/// bad habits are practised in.
///
/// [sessionTunes] are the tunes somebody's own jam session calls. Where
/// there are any, they are the tune of the day two days in three: learning
/// the tunes that will actually be called comes first. The third day is
/// the stage's, so the roadmap still moves on.
List<RoutineBlock> routineFor(
  Stage stage,
  int minutes, {
  required int day,
  List<String> sessionTunes = const [],
  PlayerLevel level = PlayerLevel.intermediate,
}) {
  // The stage's balance, tilted for the level.
  double weight(Block block) => block.weight * level.weightFor(block.area);
  // How many blocks there is room for: the tune, and then a block for
  // every five minutes of what is left in a short session, every eight in
  // a long one. Nine blocks of five minutes is a session spent changing
  // what you are doing; fewer, longer blocks are where the level shows,
  // since it decides which of them stay.
  final rest = minutes * (1 - (minutes < 30 ? 0.45 : level.tuneShare));
  final int room = (1 + rest ~/ (minutes >= 60 ? 8 : 5)).clamp(
    math.min(3, stage.blocks.length),
    stage.blocks.length,
  );
  final kept = <Block>[];
  final always = stage.blocks
      .where((b) => b.area == Area.sound || b == stage.blocks.last)
      .toList();
  final others = stage.blocks.where((b) => !always.contains(b)).toList();
  final spare = room - always.length;
  if (spare >= others.length) {
    kept.addAll(others);
  } else if (spare > 0) {
    // Heaviest first, and among blocks of the same weight, a different
    // one each day.
    final order = [
      for (var k = 0; k < others.length; k++) others[(k + day) % others.length],
    ]..sort((a, b) => weight(b).compareTo(weight(a)));
    kept.addAll(order.take(spare));
  }
  kept.addAll(always);
  // Back in the stage's own order: warm up, fundamentals, the band, the tune.
  final blocks = [
    for (final block in stage.blocks)
      if (kept.contains(block)) block,
  ];

  // A third of the session is the tune's, whatever else is in it (a bit
  // more in a short one, where a third is barely a chorus). The
  // rest is handed out a piece at a time (five minutes, or one in a short
  // session), each to whichever block is furthest below its share by
  // weight. Every block starts with one piece, so nothing is shorter than
  // that, and the pieces always add up to the session exactly.
  final step = minutes >= 30 ? 5 : 1;
  final pieces = List.filled(blocks.length, 1);
  pieces[blocks.length - 1] = math.max(
    1,
    (minutes * (minutes < 30 ? 0.45 : level.tuneShare) / step).round(),
  );
  for (
    var left = minutes ~/ step - pieces.fold(0, (sum, p) => sum + p);
    left > 0;
    left--
  ) {
    var most = 0;
    for (var b = 1; b < blocks.length - 1; b++) {
      if (weight(blocks[b]) / pieces[b] > weight(blocks[most]) / pieces[most]) {
        most = b;
      }
    }
    pieces[most]++;
  }
  final given = [for (final p in pieces) p * step];
  given[given.length - 1] += minutes - given.fold(0, (sum, m) => sum + m);

  final keys = level.keysFrom(stage.keys);
  final key = keys[day % keys.length];
  final tuneTitle = sessionTunes.isNotEmpty && day % 3 != 2
      ? sessionTunes[(day - day ~/ 3) % sessionTunes.length]
      : stage.tunes[day % stage.tunes.length];
  return [
    for (var b = 0; b < blocks.length; b++)
      RoutineBlock(
        block: blocks[b],
        minutes: given[b],
        how: blocks[b].how
            .replaceAll('{key}', key)
            .replaceAll('{tune}', tuneTitle)
            .replaceAll(
              '{from}',
              '${level.tempo(blocks[b].exercise?.from ?? 0)}',
            )
            .replaceAll('{to}', '${level.tempo(blocks[b].exercise?.to ?? 0)}'),
        key: key,
        tuneOfTheDay: tuneTitle,
        level: level,
        tune: blocks[b] == stage.blocks.last ? tuneTitle : null,
      ),
  ];
}

/// Days since the epoch, in local time: what makes today's key and tune
/// change at midnight rather than at some hour in the afternoon.
int dayNumber(DateTime now) =>
    DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;
