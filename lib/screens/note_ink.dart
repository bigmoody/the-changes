// Writing a note in the colour somebody sees it as, anywhere in the app.
//
// The chart had this to itself for a while, which was the wrong place to
// stop. If pitch is colour to you, then a D is that colour on the tuner,
// on the stave, under your fingers in a chord box and in the list of
// chord tones on a reference page. Colouring it in one of those and not
// the others is worse than colouring none of them, because every screen
// that stays black is the app telling somebody their D is not that colour.
//
// Most of the screens that name a note were never handed the settings, and
// threading them through twenty constructors to reach a reference page
// would be a lot of noise for one colour. So the colours are put above the
// app once and read from the context where they are needed. A screen built
// without them, which is most of the tests, simply gets no colour.
//
// Two ways in, because there are two kinds of note in the app:
//
//  • A note somebody wrote. B♭ is a B♭, and if they keep their sharps and
//    flats apart it is not an A♯.
//  • A pitch the app heard. The tuner hears 277 Hz, and no amount of
//    listening will say whether that was a C♯ or a D♭. Those get the
//    colour of the pitch class and show both names.

import 'package:flutter/material.dart';

import '../music/chord.dart';
import '../music/tuning.dart';
import '../settings/app_settings.dart';
import '../settings/chord_colours.dart';

/// Puts the colours in reach of every screen under it.
class NoteInk extends InheritedNotifier<AppSettings> {
  const NoteInk({
    required AppSettings settings,
    required super.child,
    super.key,
  }) : super(notifier: settings);

  /// The settings above this point, or null where there are none. Null is
  /// an ordinary answer, not a failure: it means nobody has said what
  /// their colours are, and everything stays the colour it was.
  static AppSettings? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NoteInk>()?.notifier;
}

/// The colour a written note should be drawn in, or null to leave it alone.
///
/// [on] is what it will be drawn against, so a colour too dark to read on
/// dark paper is lifted far enough to be read and no further. Defaults to
/// the surface, which is what text usually sits on.
Color? inkForNote(BuildContext context, Spelling note, {Color? on}) =>
    _readable(context, NoteInk.of(context)?.chordColourForNote(note), on);

/// The same for a pitch with no spelling, such as one the tuner heard.
Color? inkForPitch(BuildContext context, int pitchClass, {Color? on}) =>
    _readable(context, NoteInk.of(context)?.chordColourFor(pitchClass), on);

Color? _readable(BuildContext context, Color? colour, Color? on) {
  if (colour == null) return null;
  return readableOn(colour, on ?? Theme.of(context).colorScheme.surface);
}

/// A note name, written in its colour.
///
/// Falls back to whatever the surrounding text would have been, so this is
/// safe to use in place of a plain [Text] everywhere a note is named.
class NoteText extends StatelessWidget {
  /// A note somebody wrote, such as "B♭" or "F♯".
  const NoteText(this.name, {super.key, this.style, this.on, this.textAlign})
    : _pitchClass = null,
      _separator = '';

  /// A pitch with no spelling, shown under both its names with each one in
  /// its own colour. Somebody who keeps C♯ and D♭ apart sees them apart
  /// here too, which is the only honest way to show a pitch that could be
  /// either.
  const NoteText.pitchClass(
    int pitchClass, {
    super.key,
    this.style,
    this.on,
    this.textAlign,
    this._separator = '/',
  }) : _pitchClass = pitchClass,
       name = '';

  final String name;
  final TextStyle? style;
  final TextAlign? textAlign;

  /// What the text sits on, for readability. The surface by default.
  final Color? on;

  final int? _pitchClass;
  final String _separator;

  @override
  Widget build(BuildContext context) {
    if (_pitchClass case final pitchClass?) {
      final both = pitchClassName(pitchClass).split('/');
      // A white key has one name and no slash, so there is nothing to
      // take apart and nothing that could be spelled two ways.
      if (both.length == 1) {
        return Text(
          both.first,
          textAlign: textAlign,
          style: _with(context, inkForPitch(context, pitchClass, on: on)),
        );
      }
      return Text.rich(
        TextSpan(
          children: [
            _span(context, both.first),
            TextSpan(text: _separator, style: style),
            _span(context, both.last),
          ],
        ),
        textAlign: textAlign,
        style: style,
      );
    }
    return Text(
      name,
      textAlign: textAlign,
      style: _with(context, _inkFor(context, name)),
    );
  }

  TextSpan _span(BuildContext context, String written) =>
      TextSpan(text: written, style: _with(context, _inkFor(context, written)));

  Color? _inkFor(BuildContext context, String written) {
    final note = parseNoteName(written);
    return note == null ? null : inkForNote(context, note, on: on);
  }

  TextStyle? _with(BuildContext context, Color? ink) =>
      ink == null ? style : (style ?? const TextStyle()).copyWith(color: ink);
}

/// A row of note names, each in its own colour, joined by [separator].
///
/// For the reference pages, which list the notes of a chord or a scale and
/// which read as one line rather than as a column of widgets.
class NoteNames extends StatelessWidget {
  const NoteNames(
    this.names, {
    super.key,
    this.style,
    this.on,
    this.separator = '  ',
    this.maxLines,
  });

  final List<String> names;
  final TextStyle? style;
  final Color? on;
  final String separator;
  final int? maxLines;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        for (final (index, written) in names.indexed) ...[
          if (index > 0) TextSpan(text: separator, style: style),
          TextSpan(text: written, style: _styleFor(context, written)),
        ],
      ],
    ),
    maxLines: maxLines,
    style: style,
  );

  /// Only the note at the front of a name is coloured, because that is the
  /// part that is a pitch. "B♭Δ7" is a B♭ chord; the Δ7 is not a note and
  /// has no colour.
  TextStyle? _styleFor(BuildContext context, String written) {
    final note = parseNoteName(written);
    if (note == null) return style;
    final ink = inkForNote(context, note, on: on);
    return ink == null
        ? style
        : (style ?? const TextStyle()).copyWith(color: ink);
  }
}
