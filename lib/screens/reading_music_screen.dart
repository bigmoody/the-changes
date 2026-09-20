// A guide to reading music: the stave, the four clefs, what the notes are
// called, how long each one lasts, the rests, and the rest of the marks on
// the page.
//
// The app's own charts write none of this pitch — that's the point of a
// chord chart — so this page is here for when you meet a written part, or
// want to know what the dots under the chords in the head actually say.

import 'package:flutter/material.dart';

import '../music/clef.dart';
import 'anchors.dart';
import 'stave_figure.dart';
import 'tunes_page.dart' show SectionHeader;

/// The guide in order: each one is a heading on the page and a line in the
/// contents.
const _sections = <(String, Widget)>[
  ('The Stave', _TheStave()),
  ('The Clefs', _TheClefs()),
  ('Lines and Spaces', _LinesAndSpaces()),
  ('Middle C and Ledger Lines', _MiddleC()),
  ('Note Values', _NoteValues()),
  ('Beams, Dots and Ties', _BeamsDotsAndTies()),
  ('Accidentals', _Accidentals()),
  ('Key Signatures', _KeySignatures()),
  ('Time Signatures', _TimeSignatures()),
  ('Bars and Repeats', _BarsAndRepeats()),
  ('Marks You\u2019ll Meet', _OtherMarks()),
  ('And on a Chart', _OnAChart()),
];

class ReadingMusicScreen extends StatefulWidget {
  const ReadingMusicScreen({super.key});

  @override
  State<ReadingMusicScreen> createState() => _ReadingMusicScreenState();
}

class _ReadingMusicScreenState extends State<ReadingMusicScreen> {
  final _scroll = ScrollController();
  late final _anchors = Anchors(_scroll)
    ..expect({
      for (final (i, section) in _sections.indexed)
        section.$1: i / _sections.length,
    });

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _showContents() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      // The whole guide has to be in here, and a sheet's usual height only
      // holds about half of it.
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      builder: (sheet) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 12),
          children: [
            for (final (title, _) in _sections)
              ListTile(
                dense: true,
                title: Text(title),
                onTap: () {
                  Navigator.of(sheet).pop();
                  _anchors.goTo(title);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading Music'),
        actions: [
          IconButton(
            key: const ValueKey('contents'),
            icon: const Icon(Icons.list),
            tooltip: 'Contents',
            onPressed: _showContents,
          ),
        ],
      ),
      body: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.only(bottom: 32),
        itemCount: _sections.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Prose(
                  'Everything on a page of music is one of three things: how '
                  'high a note is, how long it lasts, or where to go next. '
                  'Here they are in that order.',
                ),
                _Contents(onGoTo: _anchors.goTo),
              ],
            );
          }
          final (title, body) = _sections[index - 1];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(title, key: _anchors.keyFor(title)),
              body,
            ],
          );
        },
      ),
    );
  }
}

/// The directory at the top of the guide. It's a long page and most of the
/// time you've come to look one thing up, so the whole of it is a tap away
/// from here — and from the button in the bar, once you're past it.
class _Contents extends StatelessWidget {
  const _Contents({required this.onGoTo});

  final ValueChanged<String> onGoTo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'Contents',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 2,
                children: [
                  for (final (title, _) in _sections)
                    ActionChip(
                      key: ValueKey('contents-$title'),
                      visualDensity: VisualDensity.compact,
                      label: Text(title),
                      onPressed: () => onGoTo(title),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- how high

class _TheStave extends StatelessWidget {
  const _TheStave();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Prose(
          'Five lines with four spaces between them. Up the page is up in '
          'pitch, and a note sits either on a line or in a space — so going '
          'up one note at a time alternates between them, line, space, '
          'line, space.',
        ),
        _Panel(
          caption: 'One note at a time, from the bottom line to the top.',
          child: _Climb(),
        ),
      ],
    );
  }
}

/// Nine notes up the stave with nothing written under them: the point here
/// is the alternation, not the letters, which come later.
class _Climb extends StatelessWidget {
  const _Climb();

  @override
  Widget build(BuildContext context) {
    return StaveFigure(
      space: 9,
      columns: [
        for (var step = 0; step <= 8; step++)
          StaveColumn.one(
            Smufl.noteheadWhole,
            step: step.toDouble(),
            marked: step.isEven,
            gap: 1,
          ),
      ],
      semanticsLabel: 'Nine notes climbing the stave, line then space',
    );
  }
}

class _TheClefs extends StatelessWidget {
  const _TheClefs();

  static const _who = {
    Clef.treble:
        'Its curl wraps the second line up, and that line is the G above '
        'middle C. Trumpet, alto and tenor sax, flute, violin, guitar, '
        'vocals, and the right hand at the piano.',
    Clef.bass:
        'Its two dots sit either side of the fourth line, and that line is '
        'the F below middle C. Bass, trombone, baritone sax, tuba, and the '
        'left hand.',
    Clef.alto:
        'The middle of the C clef points at the middle line, which makes it '
        'middle C. The viola reads this and almost nothing else does.',
    Clef.tenor:
        'The same C clef moved up a line, putting middle C on the fourth. '
        'Cello, bassoon and trombone switch to it up high, to keep out of '
        'the ledger lines.',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Prose(
          'The symbol at the front of the stave is the clef, and it is what '
          'gives the lines their pitches: it fixes one note to one line and '
          'the rest follow. Move the clef and every note on the stave '
          'changes its name.',
        ),
        for (final clef in Clef.values)
          _ClefCard(clef: clef, blurb: _who[clef]!),
      ],
    );
  }
}

class _ClefCard extends StatelessWidget {
  const _ClefCard({required this.clef, required this.blurb});

  final Clef clef;
  final String blurb;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = clef.fixes;
    final name = '${note.letter}${note.octave}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${clef.label} Clef', style: theme.textTheme.titleMedium),
              Text(
                'The ${clef.otherName}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              _Scroller(
                child: StaveFigure(
                  clef: clef,
                  columns: [
                    StaveColumn.one(
                      Smufl.noteheadWhole,
                      step: clef.originStep.toDouble(),
                      marked: true,
                      label: name,
                      gap: 5,
                    ),
                  ],
                  semanticsLabel:
                      '${clef.label} clef, with $name on the line it names',
                ),
              ),
              const SizedBox(height: 10),
              Text(blurb, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinesAndSpaces extends StatelessWidget {
  const _LinesAndSpaces();

  /// Every line and space of [clef], bottom to top, each with its letter
  /// underneath.
  static StaveFigure _ladder(Clef clef) => StaveFigure(
    clef: clef,
    space: 9,
    columns: [
      for (var step = 0; step <= 8; step++)
        StaveColumn.one(
          Smufl.noteheadWhole,
          step: step.toDouble(),
          marked: step.isEven,
          label: clef.noteAt(step).letter,
          gap: 0.9,
        ),
    ],
    semanticsLabel:
        'The ${clef.label.toLowerCase()} stave from bottom line to top: '
        '${[for (var s = 0; s <= 8; s++) clef.noteAt(s).letter].join(' ')}',
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Prose(
          'In the treble clef the lines going up are E G B D F, and the four '
          'spaces between them spell F A C E — which is the one everybody '
          'remembers.',
        ),
        _Panel(
          note: const Column(
            children: [
              _Mnemonic(
                label: 'Lines',
                phrase: 'Every Good Boy Deserves Football',
                accent: true,
              ),
              _Mnemonic(label: 'Spaces', phrase: 'F A C E'),
            ],
          ),
          child: _ladder(Clef.treble),
        ),
        const _Prose(
          'In the bass clef the lines are G B D F A and the spaces between '
          'them are A C E G.',
        ),
        _Panel(
          note: const Column(
            children: [
              _Mnemonic(
                label: 'Lines',
                phrase: 'Good Boys Deserve Fine Apples',
                accent: true,
              ),
              _Mnemonic(label: 'Spaces', phrase: 'All Cows Eat Grass'),
            ],
          ),
          child: _ladder(Clef.bass),
        ),
        const _Prose(
          'Learn one clef properly before starting the other. Reading both '
          'at once is a piano player’s problem and it can wait.',
        ),
      ],
    );
  }
}

class _MiddleC extends StatelessWidget {
  const _MiddleC();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Prose(
          'When a note falls off the end of the stave it gets a short line '
          'of its own to sit on — a ledger line — and they carry on one at '
          'a time as far as the music needs.',
        ),
        const _Prose(
          'Middle C is where the two staves meet, and it belongs to '
          'neither: one ledger line below the treble stave, one above the '
          'bass. Same note, same key on the piano, written two ways.',
        ),
        _Panel(
          wraps: true,
          child: Wrap(
            spacing: 20,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              for (final clef in [Clef.treble, Clef.bass])
                StaveFigure(
                  clef: clef,
                  columns: [
                    StaveColumn.one(
                      Smufl.noteheadWhole,
                      step: clef.stepOf('C', 4).toDouble(),
                      marked: true,
                      ledgers: true,
                      label: 'Middle C',
                    ),
                  ],
                  semanticsLabel:
                      'Middle C on a ledger line in the '
                      '${clef.label.toLowerCase()} clef',
                ),
            ],
          ),
        ),
        _Panel(
          caption:
              'Climbing off the top of the treble stave, a ledger line '
              'at a time.',
          child: StaveFigure(
            clef: Clef.treble,
            columns: [
              for (final note in ['F', 'G', 'A', 'B', 'C'])
                StaveColumn.one(
                  Smufl.noteheadWhole,
                  step: Clef.treble
                      .stepOf(note, note == 'C' ? 6 : 5)
                      .toDouble(),
                  ledgers: true,
                  label: note,
                ),
            ],
            above: 10,
            semanticsLabel: 'F G A B C climbing above the treble stave',
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- how long

/// One length of note, with the rest that matches it.
typedef _Value = ({
  String note,
  String rest,
  double restStep,
  String british,
  String american,
  String lasts,
});

class _NoteValues extends StatelessWidget {
  const _NoteValues();

  static const _values = <_Value>[
    (
      note: Smufl.noteWhole,
      rest: Smufl.restWhole,
      restStep: 6,
      british: 'Semibreve',
      american: 'whole note',
      lasts: '4 beats',
    ),
    (
      note: Smufl.noteHalfUp,
      rest: Smufl.restHalf,
      restStep: 4,
      british: 'Minim',
      american: 'half note',
      lasts: '2 beats',
    ),
    (
      note: Smufl.noteQuarterUp,
      rest: Smufl.restQuarter,
      restStep: 4,
      british: 'Crotchet',
      american: 'quarter note',
      lasts: '1 beat',
    ),
    (
      note: Smufl.note8thUp,
      rest: Smufl.rest8th,
      restStep: 4,
      british: 'Quaver',
      american: 'eighth note',
      lasts: 'half a beat',
    ),
    (
      note: Smufl.note16thUp,
      rest: Smufl.rest16th,
      restStep: 4,
      british: 'Semiquaver',
      american: 'sixteenth note',
      lasts: 'a quarter of a beat',
    ),
    (
      note: Smufl.note32ndUp,
      rest: Smufl.rest32nd,
      restStep: 4,
      british: 'Demisemiquaver',
      american: 'thirty-second note',
      lasts: 'an eighth of a beat',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Prose(
          'How long a note lasts is drawn into it: whether the head is '
          'filled in, whether it has a stem, and how many flags hang off '
          'the stem. Each one below is half the length of the one above it. '
          'A rest is a silence of exactly the same length, and every note '
          'has one.',
        ),
        const _Prose(
          'The beats here are counted in 4/4, where the crotchet gets the '
          'beat — which is nearly everything you’ll play.',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: Row(
                      children: [
                        for (final (width, heading) in [
                          (50.0, 'Note'),
                          (58.0, 'Rest'),
                        ])
                          SizedBox(
                            width: width,
                            child: Text(
                              heading,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  for (final value in _values) _ValueRow(value),
                ],
              ),
            ),
          ),
        ),
        const _Prose(
          'The semibreve rest hangs underneath a line and the minim rest '
          'sits on top of one. That is the only difference between them, '
          'and it catches everybody out.',
        ),
        const _Prose(
          'A semibreve rest also means a whole bar’s rest whatever the '
          'time signature — the one rest whose length depends on where it '
          'is.',
        ),
        const _Prose(
          'Stems point up from the right of the head below the middle line '
          'and down from the left above it, so they stay on the stave. It '
          'makes no difference to the sound.',
        ),
      ],
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow(this.value);

  final _Value value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          // The note on its own: its length is in its shape, and a stave
          // would say nothing. The rest gets one, because which line it
          // hangs from or sits on is exactly what tells them apart.
          SizedBox(
            width: 50,
            child: Center(
              child: StaveFigure(
                columns: [StaveColumn.one(value.note, step: 2)],
                lines: false,
                space: 6,
                above: 8,
                below: 3,
                semanticsLabel: value.british,
              ),
            ),
          ),
          SizedBox(
            width: 58,
            child: Center(
              child: StaveFigure(
                columns: [
                  StaveColumn.one(value.rest, step: value.restStep, gap: 1.6),
                ],
                space: 6,
                above: 8,
                below: 3,
                semanticsLabel: '${value.british} rest',
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value.british, style: theme.textTheme.titleSmall),
                Text(
                  '${value.american} · ${value.lasts}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BeamsDotsAndTies extends StatelessWidget {
  const _BeamsDotsAndTies();

  /// A note on the second line with its dot in the space above it, which is
  /// where a dot goes when the note is on a line.
  static StaveColumn _dotted(String note, String label, {double gap = 1.2}) =>
      StaveColumn(
        [
          sym(note, step: 2),
          // A note on a line takes its dot in the space above, just past
          // the head.
          sym(Smufl.augmentationDot, step: 3, marked: true, dx: 1.5),
        ],
        label: label,
        gap: gap,
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Prose(
          'Quavers and anything shorter are usually joined up with beams '
          'rather than drawn with flags. It is the same note either way, and '
          'the number of beams is the number of flags — so two beams means '
          'semiquavers. Beams are drawn to show the beat, which is most of '
          'why they help.',
        ),
        _Panel(
          caption: 'Two quavers, then four semiquavers: one beat each.',
          child: StaveFigure(
            columns: [
              for (var i = 0; i < 2; i++)
                const StaveColumn.one(Smufl.noteheadBlack, step: 2, stem: true),
              const StaveColumn([], gap: 2),
              for (var i = 0; i < 4; i++)
                const StaveColumn.one(
                  Smufl.noteheadBlack,
                  step: 2,
                  stem: true,
                  gap: 0.9,
                ),
            ],
            beams: const [
              (from: 0, to: 1, count: 1),
              (from: 3, to: 6, count: 2),
            ],
            semanticsLabel: 'Two beamed quavers and four beamed semiquavers',
          ),
        ),
        const _Prose(
          'A dot after a note adds half as much again: a dotted minim is '
          'three beats, a dotted crotchet is a beat and a half. Rests take '
          'dots the same way.',
        ),
        _Panel(
          child: StaveFigure(
            columns: [
              _dotted(Smufl.noteHalfUp, '3 beats', gap: 3),
              _dotted(Smufl.noteQuarterUp, '1½ beats'),
            ],
            semanticsLabel: 'A dotted minim and a dotted crotchet',
          ),
        ),
        const _Prose(
          'A tie is a curve between two notes of the same pitch, and it '
          'makes them one sound as long as both together. It is how a note '
          'is held across a bar line, which is where you will meet it most.',
        ),
        const _Prose(
          'The same curve between notes of different pitches is a slur, and '
          'it means something else entirely: play them smoothly, joined up. '
          'Same mark, and you tell them apart by whether the notes match.',
        ),
        _Panel(
          child: StaveFigure(
            columns: [
              const StaveColumn.one(
                Smufl.noteQuarterUp,
                step: 2,
                label: 'Tie',
                gap: 2,
              ),
              const StaveColumn.one(Smufl.noteQuarterUp, step: 2, gap: 4),
              const StaveColumn.one(
                Smufl.noteQuarterUp,
                step: 2,
                label: 'Slur',
                gap: 2,
              ),
              const StaveColumn.one(Smufl.noteQuarterUp, step: 5),
            ],
            ties: const [(from: 0, to: 1), (from: 2, to: 3)],
            semanticsLabel: 'Two notes tied, then two different notes slurred',
          ),
        ),
        const _Prose(
          'A bracketed 3 over a group means a triplet: three of them in the '
          'time of two.',
        ),
        _Panel(
          child: StaveFigure(
            columns: [
              for (var i = 0; i < 3; i++)
                const StaveColumn.one(Smufl.noteheadBlack, step: 2, stem: true),
            ],
            beams: const [(from: 0, to: 2, count: 1)],
            tuplet: const (from: 0, to: 2, label: '3'),
            above: 8,
            semanticsLabel: 'Three quavers beamed together under a 3',
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ what the key

class _Accidentals extends StatelessWidget {
  const _Accidentals();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Prose(
          'A sharp raises a note by a semitone, a flat lowers it by one, and '
          'a natural cancels either of them. Doubles move it by two, and you '
          'will meet them in the keys with a lot of sharps or flats.',
        ),
        _Panel(
          child: StaveFigure(
            lines: false,
            above: 0,
            below: 0,
            columns: [
              StaveColumn.one(Smufl.sharp, label: 'Sharp'),
              StaveColumn.one(Smufl.flat, label: 'Flat'),
              StaveColumn.one(Smufl.natural, label: 'Natural'),
              StaveColumn.one(Smufl.doubleSharp, label: 'Double sharp'),
              StaveColumn.one(Smufl.doubleFlat, label: 'Double flat'),
            ],
            semanticsLabel:
                'Sharp, flat, natural, double sharp and double flat',
          ),
        ),
        _Prose(
          'The accidental goes before the note, and it holds for the rest of '
          'that bar — on that line or space only, not on the same letter an '
          'octave away. The next bar line clears it.',
        ),
      ],
    );
  }
}

class _KeySignatures extends StatelessWidget {
  const _KeySignatures();

  /// The sharps or flats of a key, laid out after the clef as a signature.
  static StaveFigure _signature(
    String name, {
    required int count,
    required bool sharp,
    Clef clef = Clef.treble,
  }) => StaveFigure(
    clef: clef,
    space: 9,
    columns: [
      for (final step in keySignatureSteps(clef, count: count, sharp: sharp))
        StaveColumn.one(
          sharp ? Smufl.sharp : Smufl.flat,
          step: step.toDouble(),
          gap: 0.1,
        ),
      StaveColumn([], label: name, gap: 0.2),
    ],
    semanticsLabel: '$name: $count ${sharp ? 'sharps' : 'flats'}',
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Prose(
          'Rather than mark the same accidental over and over, the sharps or '
          'flats the key needs are written once, straight after the clef, '
          'and they hold for every bar and every octave until the music says '
          'otherwise.',
        ),
        const _Prose(
          'They are always added in the same order, and they are always '
          'drawn in the same places — a signature has to be readable at a '
          'glance, so it never gets rearranged.',
        ),
        _Panel(
          caption: 'Sharps go on in this order: F C G D A E B.',
          note: const _Mnemonic(
            phrase: 'Father Charles Goes Down And Ends Battle',
          ),
          child: _signature('', count: 7, sharp: true),
        ),
        _Panel(
          caption: 'Flats go on in exactly the reverse: B E A D G C F.',
          note: const _Mnemonic(
            phrase: 'Battle Ends And Down Goes Charles\u2019 Father',
          ),
          child: _signature('', count: 7, sharp: false),
        ),
        const _Prose(
          'To read one: with sharps, the last one is a semitone below the '
          'key, so go up one letter from it. With flats, the second to last '
          'flat names the key — and one flat on its own is F.',
        ),
        _Panel(
          wraps: true,
          child: Wrap(
            spacing: 18,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _signature('C', count: 0, sharp: true),
              _signature('F', count: 1, sharp: false),
              _signature('B♭', count: 2, sharp: false),
              _signature('E♭', count: 3, sharp: false),
              _signature('G', count: 1, sharp: true),
              _signature('D', count: 2, sharp: true),
            ],
          ),
        ),
        const _Prose(
          'The bass clef uses the same shapes one line lower. Horn and sax '
          'parts are written in a different key from the one the band is '
          'in — which is what the chart’s instrument setting is for.',
        ),
      ],
    );
  }
}

class _TimeSignatures extends StatelessWidget {
  const _TimeSignatures();

  static StaveColumn _signature(int top, int bottom, {String? label}) =>
      StaveColumn(
        [
          sym(Smufl.timeSigDigit(top), step: 6, scale: _digit),
          sym(Smufl.timeSigDigit(bottom), step: 2, scale: _digit),
        ],
        label: label,
        gap: 2.5,
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Prose(
          'Two numbers after the key signature, and they are not a fraction. '
          'The top one counts the beats in a bar. The bottom one says what '
          'kind of note is worth one of those beats: 4 for a crotchet, 8 for '
          'a quaver, 2 for a minim.',
        ),
        _Panel(
          child: StaveFigure(
            clef: Clef.treble,
            columns: [
              _signature(4, 4, label: 'Four in a bar'),
              _signature(3, 4, label: 'A waltz'),
              _signature(6, 8, label: 'Two groups of three'),
            ],
            semanticsLabel: 'Time signatures: four four, three four, six eight',
          ),
        ),
        const _Prose(
          'Two of them are written as letters instead. C is 4/4, and a C '
          'with a line through it is 2/2 — cut time, counted in two. The '
          'notes are the same; it is telling you to feel it twice as fast.',
        ),
        _Panel(
          child: StaveFigure(
            clef: Clef.treble,
            columns: const [
              StaveColumn.one(
                Smufl.timeSigCommon,
                scale: _letterSig,
                label: 'Common time, 4/4',
                gap: 3,
              ),
              StaveColumn.one(
                Smufl.timeSigCutCommon,
                scale: _letterSig,
                label: 'Cut time, 2/2',
              ),
            ],
            semanticsLabel: 'Common time and cut common time',
          ),
        ),
        const _Prose(
          'Nearly every standard is in 4/4. A handful are waltzes in 3/4, '
          'and a few are written in 12/8 — four beats with three quavers in '
          'each, which is a swung feel written out.',
        ),
      ],
    );
  }
}

// ------------------------------------------------------------- where next

class _BarsAndRepeats extends StatelessWidget {
  const _BarsAndRepeats();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Prose(
          'A bar line cuts the music into bars of the length the time '
          'signature sets. A double bar marks the start of a new section, '
          'and a thin line followed by a thick one is the end.',
        ),
        const _Panel(
          child: StaveFigure(
            columns: [
              StaveColumn.one(
                Smufl.barlineSingle,
                step: 0,
                label: 'Bar line',
                gap: 3,
              ),
              StaveColumn.one(
                Smufl.barlineDouble,
                step: 0,
                label: 'New section',
                gap: 3,
              ),
              StaveColumn.one(Smufl.barlineFinal, step: 0, label: 'The end'),
            ],
            semanticsLabel: 'A single, double and final bar line',
          ),
        ),
        const _Prose(
          'Two dots before a thick bar line send you back to the dots facing '
          'the other way, and you play the stretch between them again. If '
          'there is no opening pair, go back to the beginning.',
        ),
        const _Panel(
          child: StaveFigure(
            columns: [
              StaveColumn.one(
                Smufl.repeatStart,
                step: 0,
                label: 'Repeat from here',
                gap: 3,
              ),
              StaveColumn.one(
                Smufl.repeatEnd,
                step: 0,
                label: 'Go back',
                gap: 3,
              ),
              StaveColumn.one(
                Smufl.repeatRightLeft,
                step: 0,
                label: 'Back, then on',
              ),
            ],
            semanticsLabel: 'Repeat marks',
          ),
        ),
        const _Prose(
          'Brackets numbered 1 and 2 over the last bars of a repeat are time '
          'bars: play the first one, take the repeat, then skip it and play '
          'the second. The app folds these into the chart for you, so you '
          'see the bars already in the order you play them.',
        ),
        const _Prose(
          'D.C. sends you back to the top and D.S. back to the sign. Either '
          'one followed by al Fine means stop where it says Fine; al Coda '
          'means carry on until To Coda, then jump to the coda sign and play '
          'the tail.',
        ),
        const _Panel(
          child: StaveFigure(
            lines: false,
            above: 0,
            below: 0,
            columns: [
              StaveColumn.one(
                Smufl.segno,
                step: 2.5,
                label: 'Segno, the sign',
                gap: 3,
              ),
              StaveColumn.one(Smufl.coda, step: 2.3, label: 'Coda, the tail'),
            ],
            semanticsLabel: 'The segno and the coda sign',
          ),
        ),
      ],
    );
  }
}

class _OtherMarks extends StatelessWidget {
  const _OtherMarks();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Prose(
          'How loud: p is quiet and f is loud, m in front of either softens '
          'it, and doubling the letter goes further — pp is very quiet, ff '
          'very loud. A long wedge opening out means get louder, and closing '
          'means get quieter.',
        ),
        _Panel(
          child: StaveFigure(
            columns: [
              StaveColumn.one(Smufl.piano, step: _sits, label: 'Quiet'),
              StaveColumn.one(
                Smufl.mezzo + Smufl.piano,
                step: _sits,
                label: 'Fairly quiet',
              ),
              StaveColumn.one(
                Smufl.mezzo + Smufl.forte,
                step: _sits,
                label: 'Fairly loud',
              ),
              StaveColumn.one(Smufl.forte, step: _sits, label: 'Loud'),
            ],
            lines: false,
            above: 0,
            below: 0,
            semanticsLabel: 'Dynamics: p, mp, mf and f',
          ),
        ),
        _Prose(
          'How to play it: a dot over the note means short and detached, a '
          'wedge means give it an accent, and a line means hold it for its '
          'full length. A fermata means stop counting and hold it until the '
          'band moves on.',
        ),
        _Panel(
          child: StaveFigure(
            lines: false,
            above: 0,
            below: 0,
            columns: [
              StaveColumn.one(Smufl.staccato, step: 3.7, label: 'Short'),
              StaveColumn.one(Smufl.accent, step: 3.35, label: 'Accented'),
              StaveColumn.one(Smufl.tenuto, step: 3.9, label: 'Held full'),
              StaveColumn.one(Smufl.fermata, step: 3.1, label: 'Pause'),
              StaveColumn.one(Smufl.trill, step: 2.9, label: 'Trill'),
            ],
            semanticsLabel: 'Staccato, accent, tenuto, fermata and trill',
          ),
        ),
        _Prose(
          '8va over a passage means play it an octave higher than it is '
          'written, and it is there to save you counting ledger lines. '
          'Underneath the stave it means an octave lower.',
        ),
        _Panel(
          child: StaveFigure(
            lines: false,
            above: 0,
            below: 0,
            columns: [
              StaveColumn.one(
                Smufl.ottavaAlta,
                step: 3.15,
                label: 'An octave up',
              ),
            ],
            semanticsLabel: 'The 8va sign',
          ),
        ),
      ],
    );
  }
}

class _OnAChart extends StatelessWidget {
  const _OnAChart();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Prose(
          'A chord chart writes none of the pitch: no stave, no note heads, '
          'nothing about which notes to play or when. What it keeps is the '
          'bars, the bar lines, the repeats and the time bars you have just '
          'read, with a chord symbol over each bar.',
        ),
        _Prose(
          'That is the trade. It tells you the harmony and the shape of the '
          'tune, and it leaves the notes to you.',
        ),
      ],
    );
  }
}

/// Sizes and heights measured off Petaluma itself, because the font draws
/// some symbols for somewhere other than the middle of one stave.
///
/// Its time signature digits are a whole stave tall each, so a stacked pair
/// would be twice the height of the stave; halving them makes each the two
/// spaces it should be. The C of common time is nearly right already.
const _digit = 0.5;
const _letterSig = 0.85;

/// Where a dynamic marking sits so its body lands on the middle line: its
/// origin is at the foot of the letter, not the middle of it.
const _sits = 3.2;

// ------------------------------------------------------------------ pieces

/// A paragraph of the guide.
class _Prose extends StatelessWidget {
  const _Prose(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

/// A figure, boxed, centred, and free to scroll sideways on a narrow phone
/// rather than be cut off.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.caption,
    this.note,
    this.wraps = false,
  });

  final Widget child;
  final String? caption;

  /// A memory hook under the figure, for the ones that have one.
  final Widget? note;

  /// Set when the child lays itself out over several rows. A [Wrap] given
  /// the endless width of a sideways scroller never wraps, so a panel like
  /// this one keeps the width it was handed.
  final bool wraps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            children: [
              if (wraps) child else _Scroller(child: child),
              if (caption != null) ...[
                const SizedBox(height: 10),
                Text(
                  caption!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (note != null) ...[const SizedBox(height: 6), note!],
            ],
          ),
        ),
      ),
    );
  }
}

/// A way of remembering a figure, with the letters that are the point of it
/// picked out — in the colour of the notes they belong to on the stave, so
/// it's plain which is which.
class _Mnemonic extends StatelessWidget {
  const _Mnemonic({required this.phrase, this.label, this.accent = false});

  final String phrase;

  /// What it's a way of remembering, e.g. "Lines".
  final String? label;

  /// Whether its letters are the ones drawn in the accent colour above.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final base =
        theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant) ??
        const TextStyle();
    final letter = base.copyWith(
      fontWeight: FontWeight.w700,
      color: accent ? scheme.tertiary : scheme.onSurface,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text.rich(
        TextSpan(
          children: [
            if (label != null) TextSpan(text: '$label\u2003', style: base),
            for (final (i, word) in phrase.split(' ').indexed) ...[
              if (i > 0) const TextSpan(text: ' '),
              TextSpan(text: word.substring(0, 1), style: letter),
              TextSpan(text: word.substring(1)),
            ],
          ],
        ),
        textAlign: TextAlign.center,
        style: base,
      ),
    );
  }
}

/// Keeps a figure whole: if it is wider than the phone, it scrolls instead
/// of shrinking or overflowing.
class _Scroller extends StatelessWidget {
  const _Scroller({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Center(child: child),
    );
  }
}
