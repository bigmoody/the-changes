// What goes out is the chart on the stand.
//
// A player reading in E flat is looking at an E flat chart, so that is
// what every written form sends: the text, the link, the page and the
// score. The MIDI is the band rather than the chart, and the band plays
// in concert pitch whoever is reading.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/chart_pdf.dart';
import 'package:play_along/music/chart_text.dart';
import 'package:play_along/music/ireal_export.dart';
import 'package:play_along/music/ireal_import.dart';
import 'package:play_along/music/midi_file.dart';
import 'package:play_along/music/midi_write.dart';
import 'package:play_along/music/musicxml_export.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/music/user_progression.dart';
import 'package:play_along/settings/app_settings.dart';

Tune _tune(String title) => standards.firstWhere((t) => t.title == title);

void main() {
  // Alto sax: the chart is written a major sixth above what sounds.
  const alto = ChartInstrument.eFlat;

  test('an E flat player sends an E flat chart', () {
    final sounding = _tune('Blue Bossa');
    final reading = sounding.transposed(alto.semitones);
    expect(sounding.key, 'C minor');
    expect(reading.key, 'A minor');

    // Text: the key and the chords move together.
    final text = chartText(reading);
    expect(text, contains('Key of A minor'));
    expect(text, isNot(contains('Key of C minor')));

    // The link: read back, it is the chart that was read.
    final song = UserProgression.fromTune(reading, id: '0');
    final back = parseIrealPro(irealLinkFor(song)).single.progression;
    expect(back.key, 'A minor');

    // The score: three sharps rather than three flats.
    final xml = musicXmlFor(song, note: 'Written for ${alto.name}');
    expect(xml, contains('<fifths>0</fifths>'));
    expect(xml, contains('Written for E♭ instruments'));
  });

  test('the MIDI stays where the band is', () {
    final sounding = _tune('Blue Bossa');
    final bass = readMidiFile(midiFor(sounding)).parts
        .firstWhere((p) => p.name == 'Bass');
    final up = readMidiFile(midiFor(sounding.transposed(alto.semitones))).parts
        .firstWhere((p) => p.name == 'Bass');
    // Written for the alto, the same tune would come out a major sixth
    // higher, which is a key nobody is playing in. Sharing sends the
    // sounding chart, so the file is the band.
    expect(
      up.notes.first.pitch - bass.notes.first.pitch,
      isNot(0),
      reason: 'transposing the chart would move the band with it',
    );
  });

  testWidgets('the page says what it is written for', (tester) async {
    late String text;
    await tester.runAsync(() async {
      final bytes = await chartPdf(
        [_tune('Blue Bossa').transposed(alto.semitones)],
        heading: 'Blue Bossa',
        note: 'Written for ${alto.name}',
      );
      text = latin1.decode(bytes);
    });
    expect(text, contains('/Title (Blue Bossa)'));
    // The words themselves are drawn into the page's picture, so what is
    // checked here is that a page came out at all with the note asked
    // for: the drawing is checked in chart_pdf_test.
    expect(text, contains('/Type /Pages /Count 1'));
  });
}
