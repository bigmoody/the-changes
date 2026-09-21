// Where to start, and what to learn next.
//
// The book is alphabetical, which is no help at all to someone who has
// never played any of it. Alphabetical puts "All the Things You Are" (
// which changes key every four bars) third, and buries the tunes you
// could actually get through on a first evening somewhere in the S's.
//
// So this is an order: five stages, each one asking for something the last
// did not, and a line on every tune saying what it is there to teach. It
// is a suggestion and nothing more: nothing is locked, nothing has to be
// finished, and the whole book stays where it was.
//
// The order is ours, argued from what each tune does harmonically and how
// long the form is. The tunes themselves are only named: what they are and
// who wrote them, the same as everywhere else in the app.

/// One tune on the path, and why it is there.
typedef PathStep = ({String title, String why});

/// A stage of the path: a few tunes that ask for the same thing.
class Stage {
  const Stage({required this.name, required this.about, required this.tunes});

  final String name;

  /// What this stage is for, in a line.
  final String about;

  final List<PathStep> tunes;
}

/// The path. Five stages, roughly twenty tunes.
const startingOrder = <Stage>[
  Stage(
    name: 'Start Here',
    about:
        'Few chords, and they stay put long enough to hear what they are. '
        'The work here is keeping your place, not finding the notes.',
    tunes: [
      (
        title: 'So What',
        why:
            'Two chords in thirty-two bars, and the second is the first '
            'moved up a semitone. Nothing to fight, so you can spend the '
            'whole tune on where you are in it.',
      ),
      (
        title: 'Maiden Voyage',
        why:
            'Four chords, eight bars each. They hang about long enough '
            'that you can hear one arrive, which is harder than it sounds '
            'and is the whole skill.',
      ),
      (
        title: 'Blue Bossa',
        why:
            'Sixteen bars and one move: minor for eight, its relative '
            'major for four, back again. The shortest tune that still '
            'teaches you a ii–V.',
      ),
      (
        title: 'Summertime',
        why:
            'Minor, sixteen bars, and it goes where your ear expects. A '
            'good one to try playing without looking.',
      ),
    ],
  ),
  Stage(
    name: 'The First ii–V–Is',
    about:
        'The two-chord move most of the music is made of. These tunes are '
        'ii–V–Is with the least possible wrapped round them.',
    tunes: [
      (
        title: 'Autumn Leaves',
        why:
            'A ii–V–I in major, then the same thing in its relative minor, '
            'over and over. If one tune is going to teach you what a ii–V '
            'sounds like, it is this one.',
      ),
      (
        title: 'Tune Up',
        why:
            'Three ii–V–Is, each landing in a new key, and nothing else in '
            'the way at all. Almost an exercise, which is the point.',
      ),
      (
        title: 'Solar',
        why:
            'Twelve bars that fall a tone at a time. Short enough to hold '
            'in your head, and the descent is easy to hear coming.',
      ),
      (
        title: 'Recorda Me',
        why:
            'The same move in three keys, with a bossa under it so the '
            'time is doing something other than swinging.',
      ),
    ],
  ),
  Stage(
    name: 'The Blues',
    about:
        'Twelve bars everyone knows, then what bebop did to them. Worth '
        'coming back to at every stage, because the form never gets harder '
        'and what you play over it always can.',
    tunes: [
      (
        title: "Now's the Time",
        why:
            'Twelve bars, three chords. Nearly everything in the language '
            'got tried out on this form first.',
      ),
      (
        title: 'Blue Monk',
        why:
            'The same twelve bars with the corners knocked off. Slow '
            'enough to hear yourself think.',
      ),
      (
        title: "Billie's Bounce",
        why:
            'The blues with more in it: a quick change in bar two, and a '
            'ii–V to turn it round at the end.',
      ),
      (
        title: 'Blues for Alice',
        why:
            'The blues with a ii–V–I in nearly every other bar. Once this '
            'one is under your fingers, the ordinary blues sounds enormous.',
      ),
    ],
  ),
  Stage(
    name: 'Thirty-Two Bars And A Bridge',
    about:
        'AABA: eight bars said three times with something else in the '
        'middle. Most of the songbook is this shape, and knowing you are '
        'in the bridge is half of playing it.',
    tunes: [
      (
        title: 'Take the "A" Train',
        why:
            'A bridge that stays in one place long enough to learn, and '
            'the II7 in bar three is the whole sound of the tune.',
      ),
      (
        title: 'Satin Doll',
        why:
            'ii–Vs all the way down, and a bridge that moves to the IV and '
            'says so plainly.',
      ),
      (
        title: 'All of Me',
        why:
            'Chords borrowed from keys the tune is not in, a bar at a '
            'time. The first tune here where your ear has to follow rather '
            'than predict.',
      ),
      (
        title: 'Oleo',
        why:
            'Rhythm changes: the second most played form there is, and '
            'the bridge is four dominants going round the circle. Learn it '
            'once and you can busk a hundred tunes.',
      ),
    ],
  ),
  Stage(
    name: 'Tunes That Move',
    about:
        'These change key faster than you can remember them, so you have '
        'to hear where you are. This is where the earlier work either '
        'shows up or does not.',
    tunes: [
      (
        title: 'All the Things You Are',
        why:
            'It never sits in one key for more than four bars, and every '
            'move is a ii–V. The test of whether you are hearing or '
            'remembering.',
      ),
      (
        title: 'Stella by Starlight',
        why:
            'The chords do not resolve where the ear asks them to, which '
            'is exactly why it is worth the trouble.',
      ),
      (
        title: 'Body and Soul',
        why:
            'A ballad in a flat key with a bridge that changes key twice. '
            'Slow, exposed, and nowhere at all to hide.',
      ),
      (
        title: 'Cherokee',
        why:
            'Fast, and the bridge walks down through four keys. People '
            'practise this one for years; that is not a reason to put it '
            'off, only to start it slowly.',
      ),
      (
        title: 'Giant Steps',
        why:
            'Three keys a major third apart, two chords each. Everyone '
            'gets lost in it at first. Take it at half the tempo and it is '
            'a pattern, not a wall.',
      ),
    ],
  ),
];

/// Every title on the path, in order.
List<String> get pathTitles => [
  for (final stage in startingOrder)
    for (final step in stage.tunes) step.title,
];
