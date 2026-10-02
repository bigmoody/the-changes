// What a chord is doing in the tune in front of you.
//
// A chart gives you the names of the chords and leaves the rest to you.
// Everything the app teaches about harmony sits one tab away, in the
// abstract, where you have to already know what you are looking for to go
// and look it up. This joins the two: point at a chord, and it says what
// that chord is for.
//
// The one decision that makes this work: it reads relationships, not keys.
//
// Naming a chord by the key would be the obvious way and it is a trap.
// Roman numerals are measured from the key the tune is written in, and a
// tune that modulates leaves that key behind. Cherokee is written in B♭
// and its bridge is three ii-V-Is stepping down from B through A to G,
// which against B♭ read as ♭iii7 ♭VI7 ♭IIΔ7, ♭ii7 ♯IV7 VIIΔ7, vii7 III7
// VIΔ7. Every one of those is true and not one of them is what anybody
// thinks. A chart that explained itself that way would be most wrong
// exactly where it is most interesting.
//
// So nothing here claims a key. "Dm7 G7 CΔ7 is a ii-V-I into C" is true
// whatever the tune is written in, and so is "this dominant went
// somewhere other than where it was pointing". The analysis is local,
// which is also how it is heard: a player hearing a ii-V does not work
// out the key first, they hear two chords leaning somewhere.
//
// Where it cannot say anything it is confident of, it says nothing. A
// chart that labels a chord wrongly, with the authority of being printed
// under it, is worse than a chart that stays quiet, because somebody
// learning cannot tell which it has done.

import 'chord.dart';

/// The jobs a chord can be doing that this can recognise.
enum ChordJob {
  /// The chord a phrase is heading for.
  tonic,

  /// The dominant of the chord that follows it.
  dominant,

  /// The minor chord in front of a dominant, leaning on it.
  approach,

  /// A dominant standing in for the one a tritone away.
  tritoneSub,

  /// A dominant that went somewhere other than where it pointed.
  deceptive,

  /// The ♭VII7 of a backdoor cadence, or the iv7 in front of it.
  backdoor,

  /// A chord repeated or held while nothing moves under it.
  staying,

  /// One chord of a run of dominants, each a fourth above the next.
  chain,
}

/// What one chord is doing, in three lengths, because it is read in three
/// places.
///
/// [tag] goes under the chord on the chart, where there is room for a
/// numeral or two note names and no more, and where it is read at a
/// glance with a band playing. [short] heads the sheet you get by tapping
/// the chord. [long] is the part worth reading once you have stopped.
/// [learn] names the page that covers it, where there is one.
typedef ChordMeaning = ({
  ChordJob job,
  String tag,
  String short,
  String long,
  String? learn,
});

/// How a chord behaves, which is all the harmony here needs of it.
enum _Kind { major, minor, dominant, halfDiminished, diminished, suspended }

_Kind _kindOf(Chord chord) {
  final formula = chord.quality.formula;
  final third = formula.contains('b3');
  final flatFive = formula.contains('b5');
  final seventh = formula.contains('b7');
  if (formula.contains('4') && !formula.contains('3') && !third) {
    return _Kind.suspended;
  }
  if (formula.contains('bb7')) return _Kind.diminished;
  if (third && flatFive) {
    return seventh ? _Kind.halfDiminished : _Kind.diminished;
  }
  if (third) return _Kind.minor;
  if (seventh) return _Kind.dominant;
  return _Kind.major;
}

/// Whether [chord] is a dominant 7th of any colour, which is the one
/// quality the whole of this turns on.
bool _isDominant(Chord chord) {
  final kind = _kindOf(chord);
  // A 7sus is still a dominant for the purposes of where it is going: it
  // is the same bass and the same destination with the 3rd held back.
  return kind == _Kind.dominant ||
      (kind == _Kind.suspended && chord.quality.formula.contains('b7'));
}

bool _resolvesTo(Chord from, Chord to) => (to.root - from.root) % 12 == 5;

/// How far [to] is above [from], in semitones, 0 to 11.
int _up(Chord from, Chord to) => (to.root - from.root) % 12;

/// What the chord at [at] in [chords] is doing, or null when nothing here
/// is confident enough to say.
///
/// [chords] is the tune's chords in order, one per change rather than one
/// per bar, so that two chords in a bar read as two chords. Repeats are
/// left in: a bar of CΔ7 followed by another is two entries, and saying
/// so is the point of [ChordJob.staying].
ChordMeaning? whatItIsDoing(List<Chord> chords, int at) {
  if (at < 0 || at >= chords.length) return null;
  final chord = chords[at];

  // Everything else reads the chords as *changes*: a bar of C7 followed
  // by another bar of C7 is one chord, so a run of dominants a bar each
  // is still a run. A chart writes those repeats as % and nobody hears
  // them as separate events.
  final nextAt = _nextChange(chords, at);
  final afterAt = nextAt == null ? null : _nextChange(chords, nextAt);
  final beforeAt = _lastChange(chords, at);
  final next = nextAt == null ? null : chords[nextAt];
  final after = afterAt == null ? null : chords[afterAt];
  final before = beforeAt == null ? null : chords[beforeAt];
  final kind = _kindOf(chord);

  // A dominant, which is where nearly all of the movement in this music
  // comes from. What it is doing is decided by where it goes.
  if (_isDominant(chord)) {
    if (next != null) {
      if (_resolvesTo(chord, next)) {
        // Landing on another dominant is a link in a chain rather than an
        // arrival: the run of dominants round the bridge of rhythm
        // changes is six of these, not three cadences.
        if (_isDominant(next) && after != null && _resolvesTo(next, after)) {
          return (
            job: ChordJob.chain,
            tag: 'V of ${next.rootName}',
            short: 'One of a run of dominants',
            long:
                'Each of these is the dominant of the next, a fourth up '
                'every time. Nothing lands until the end of the run, which '
                'is what makes a bridge built this way feel like it is '
                'being pulled along.',
            learn: 'Rhythm Changes',
          );
        }
        final home = _kindOf(next);
        return (
          job: ChordJob.dominant,
          tag: 'V of ${next.rootName}',
          short: 'The V of ${next.rootName}',
          long:
              'A dominant going where it points: up a fourth to '
              '${next.display}. The 3rd and the ♭7 of this chord are a '
              'tritone apart, and both of them move by a semitone into '
              '${next.rootName}, which is the whole of why it sounds '
              'like an arrival${home == _Kind.minor ? ', minor or not' : ''}.',
          learn: 'Guide Tones',
        );
      }
      // Down a semitone is the tritone sub's giveaway: the bass walks
      // down by step where a plain dominant would have leapt a fourth.
      if (_up(chord, next) == 11) {
        return (
          job: ChordJob.tritoneSub,
          tag: 'sub → ${next.rootName}',
          short: 'Tritone sub, for the V of ${next.rootName}',
          long:
              'Standing in for the dominant a tritone away, which would '
              'have been ${Chord.parse('${_nameOf((chord.root + 6) % 12)}7').display}. '
              'Both chords hold the same two notes in the middle, the 3rd '
              'and the ♭7 swapped over, so the ear lets the change pass; '
              'what you hear instead is the bass walking down a semitone '
              'into ${next.rootName}.',
          learn: 'Tritone Subs',
        );
      }
      // A ♭VII7 going to the I, the long way home.
      if (_up(chord, next) == 2 && _kindOf(next) == _Kind.major) {
        return (
          job: ChordJob.backdoor,
          tag: 'backdoor',
          short: 'Backdoor, into ${next.rootName}',
          long:
              'Coming home from a whole tone below rather than from the '
              'dominant above. The ♭7 of this chord is the 3rd of '
              '${next.rootName}, which is the note that makes it land, '
              'and it arrives from underneath instead of falling into '
              'place.',
          learn: 'Passing Chords',
        );
      }
      // Anywhere else, and only when the ii in front of it had set the
      // resolution up. Without that there is no expectation to thwart:
      // most of the dominants in a blues go somewhere other than up a
      // fourth, and they are the sound of the style rather than failures.
      // Calling every one of them a V that did not land put the words
      // under half the bars of a twelve-bar and told its reader something
      // untrue about all of them.
      if (before != null &&
          _kindOf(before) == _Kind.minor &&
          _resolvesTo(before, chord)) {
        return (
          job: ChordJob.deceptive,
          tag: 'V, no land',
          short: 'A ii-V that does not land',
          long:
              'The chord before this one set up a resolution to '
              '${_nameOf((chord.root + 5) % 12)}, and ${next.display} is '
              'not it. A dominant that goes somewhere other than where it '
              'leans is how a tune keeps moving at the point you expected '
              'it to stop.',
          learn: null,
        );
      }
      return null;
    }
    return null;
  }

  // A minor chord in front of a dominant is the ii of a ii-V, whether or
  // not the I ever turns up.
  if ((kind == _Kind.minor || kind == _Kind.halfDiminished) &&
      next != null &&
      _isDominant(next) &&
      _resolvesTo(chord, next)) {
    final lands = after != null && _resolvesTo(next, after);
    final into = lands ? after.rootName : _nameOf((next.root + 5) % 12);
    return (
      job: ChordJob.approach,
      tag: 'ii of $into',
      short: lands ? 'ii of a ii-V-I into $into' : 'ii of a ii-V into $into',
      long: lands
          ? 'The first of a ii-V-I into $into, which is the phrase most of '
                'this music is built out of. The three roots fall a fourth '
                'each time, and the 3rds and 7ths of the three chords move '
                'by a semitone or not at all.'
          : 'A ii-V leaning on $into that never gets there. The pair is '
                'the gesture; where it goes instead is the tune making its '
                'own mind up.',
      learn: 'Changes in Twelve Keys',
    );
  }

  // The chord a ii-V was heading for.
  if (before != null &&
      _isDominant(before) &&
      _resolvesTo(before, chord) &&
      (kind == _Kind.major || kind == _Kind.minor)) {
    return (
      job: ChordJob.tonic,
      tag: 'lands',
      short: 'Where the ii-V was going',
      long:
          'The chord the dominant in front of it was leaning on. Everything '
          'before it was movement; this is the bar that stops.',
      learn: null,
    );
  }

  // Nothing moving, and nothing else to say about it. Last rather than
  // first: a dominant held for two bars is still the V of wherever it
  // goes, and saying where it goes is worth more than saying it is being
  // held. What this catches is the chord that is held and then does
  // nothing nameable, which is most of a modal tune.
  if (at + 1 < chords.length && _same(chord, chords[at + 1])) {
    return (
      job: ChordJob.staying,
      tag: 'stays',
      short: 'Staying put',
      long:
          'The same chord again. Nothing is being approached and nothing '
          'is resolving, so what you play over it has to come from the '
          'line rather than from the changes.',
      learn: 'Modal Playing',
    );
  }

  return null;
}

/// Whether two chords are the same chord, as a chart would mean it: a bar
/// of C7 followed by a % is this.
bool _same(Chord a, Chord b) => a.display == b.display;

/// Where the next actual change is after [at], skipping repeats, or null
/// at the end of the tune.
int? _nextChange(List<Chord> chords, int at) {
  for (var i = at + 1; i < chords.length; i++) {
    if (!_same(chords[at], chords[i])) return i;
  }
  return null;
}

/// The same backwards: the chord that changed into this one.
int? _lastChange(List<Chord> chords, int at) {
  for (var i = at - 1; i >= 0; i--) {
    if (!_same(chords[at], chords[i])) return i;
  }
  return null;
}

/// The flat-ish name of a pitch class, for a chord this is only talking
/// about rather than writing on the chart.
String _nameOf(int pitchClass) => const [
  'C',
  'D♭',
  'D',
  'E♭',
  'E',
  'F',
  'G♭',
  'G',
  'A♭',
  'A',
  'B♭',
  'B',
][pitchClass % 12];
