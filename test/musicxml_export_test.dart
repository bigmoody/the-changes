// Writing a chart out as MusicXML, the way notation software wants it:
// the chords over the right beats, the key and the meter, the section
// letters, and the repeats and endings that play the form back.

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/musicxml_export.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/user_progression.dart';

/// Every tag opened is closed, and in the right order: a score no reader
/// can open is no export at all.
void expectWellFormed(String xml) {
  final open = <String>[];
  for (final match in RegExp(
    r'<(/?)([A-Za-z-]+)([^>]*?)(/?)>',
  ).allMatches(xml)) {
    final closing = match[1] == '/';
    final name = match[2]!;
    final empty = match[4] == '/';
    if (empty) continue;
    if (closing) {
      expect(open, isNotEmpty, reason: '</$name> with nothing open');
      expect(open.removeLast(), name, reason: 'closed out of order');
    } else {
      open.add(name);
    }
  }
  expect(open, isEmpty, reason: 'left open: ${open.join(', ')}');
}

UserProgression _blues() => UserProgression(
  id: 'x',
  title: 'Two Endings',
  composer: 'Jane Doe',
  key: 'C minor',
  tempo: 132,
  beatsPerBar: 3,
  bars: ['C-7', 'F7 Bb7', 'E♭Δ7/G', 'A7', 'D-7', 'G7'],
  sections: {0: 'A', 4: 'B'},
  style: BandStyle.of(Feel.bossa),
);

void main() {
  test('a chart as a notation program reads it', () {
    final progression = _blues()
      ..endings[2] = 1
      ..endings[3] = 2;
    final xml = musicXmlFor(progression);
    expectWellFormed(xml);

    expect(xml, contains('<work-title>Two Endings</work-title>'));
    expect(xml, contains('<creator type="composer">Jane Doe</creator>'));
    // C minor: three flats, and a bar of three beats.
    expect(xml, contains('<fifths>-3</fifths>'));
    expect(xml, contains('<mode>minor</mode>'));
    expect(xml, contains('<beats>3</beats>'));
    expect(xml, contains('<per-minute>132</per-minute>'));
    expect(xml, contains('<words>Bossa Nova</words>'));
    // The chords themselves, with the slash bass under the third bar.
    expect(xml, contains('<root-step>C</root-step>'));
    expect(xml, contains('<kind text="m7">minor-seventh</kind>'));
    expect(xml, contains('<root-alter>-1</root-alter>'));
    expect(xml, contains('<bass-step>G</bass-step>'));
    expect(xml, contains('<kind text="maj7">major-seventh</kind>'));
    // Section letters are rehearsal marks.
    expect(xml, contains('<rehearsal>A</rehearsal>'));
    expect(xml, contains('<rehearsal>B</rehearsal>'));
    // The endings, with the repeat that sends you back for them.
    expect(xml, contains('<ending number="1" type="start"/>'));
    expect(xml, contains('<ending number="1" type="stop"/>'));
    expect(xml, contains('<ending number="2" type="start"/>'));
    expect(xml, contains('<repeat direction="forward"/>'));
    expect(xml, contains('<repeat direction="backward" times="2"/>'));
    expect(xml, contains('<bar-style>light-heavy</bar-style>'));
    expect(xml, hasLength(greaterThan(0)));
  });

  test('every bar is as long as the meter says', () {
    final xml = musicXmlFor(_blues());
    final measures = xml.split('<measure ').skip(1);
    expect(measures, hasLength(6));
    for (final measure in measures) {
      final durations = [
        for (final match in RegExp(
          r'<duration>(\d+)</duration>',
        ).allMatches(measure))
          int.parse(match[1]!),
      ];
      expect(
        durations.fold(0, (a, b) => a + b),
        // Durations are counted in divisions of a quarter note, and
        // there are two to a quarter, so three beats is six of them.
        6,
        reason: 'a bar of 3/4 holds three beats, however many chords',
      );
    }
    // Two chords in a bar take a beat and a half each way round: the
    // first one gets the longer half.
    expect(
      RegExp(r'<duration>2</duration>\s*<voice>1</voice>').hasMatch(xml),
      isTrue,
    );
  });

  test('a section played twice is written as a repeat', () {
    final progression = UserProgression(
      id: 'x',
      title: 'Round And Round',
      key: 'F',
      tempo: 160,
      bars: ['F6', 'B♭7', 'F6', 'C7'],
      sections: {0: 'A'},
      repeats: {0: 3},
      style: BandStyle.of(Feel.swing),
    );
    final xml = musicXmlFor(progression);
    expectWellFormed(xml);
    expect(xml, contains('<repeat direction="forward"/>'));
    expect(xml, contains('<repeat direction="backward" times="3"/>'));
    expect(xml, contains('<fifths>-1</fifths>'));
  });

  test('a bar nobody has filled in is a bar of rest, and the file is named '
      'after the tune', () {
    final progression = UserProgression(
      id: 'x',
      title: 'Half Written?',
      key: 'C',
      tempo: 120,
      bars: ['C', ''],
      style: BandStyle.of(Feel.swing),
    );
    final xml = musicXmlFor(progression);
    expectWellFormed(xml);
    expect(xml, contains('<rest measure="yes"/>'));
    expect(musicXmlFileName(progression), 'Half Written.musicxml');
  });
}
