// Sending a chart out of the app: one tune, or a whole setlist.
//
// Several ways out, because they are for different ends. As text, the
// changes are laid out as they are on screen, to read anywhere: a
// message, a note, a printout on the stand. As an iReal Pro link, they go
// into the app most players already keep their charts in. As a PDF, they
// are a page to print and put on the stand. As MusicXML, they open in
// notation software to be engraved or arranged from. As MIDI, the band
// playing them goes into a DAW as notes.
//
// What goes out is the chart as the player is reading it: in the key
// they have put it in, and written for their instrument. An alto player
// who has been reading in E flat sends an E flat chart, because that is
// the chart they have in front of them.
//
// The MIDI is the exception, and has to be: it is not a chart to read but
// the band to listen to, and the band plays in concert pitch. Transposing
// that would hand a DAW a file in a key nobody is playing in.
//
// Only the changes leave, whichever way: there is no melody and no lyric
// in this app to send.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../music/chart_pdf.dart';
import '../music/chart_text.dart';
import '../music/ireal_export.dart';
import '../music/midi_write.dart';
import '../music/musicxml_export.dart';
import '../music/tune.dart';
import '../music/user_progression.dart';
import '../settings/app_settings.dart';

/// Shares [tune], asking first how.
///
/// [semitones] is the key the player has put it in, and [instrument] is
/// what they are reading it on: together they are the chart in front of
/// them, which is what goes out.
Future<void> shareChart(
  BuildContext context,
  Tune tune, {
  int semitones = 0,
  ChartInstrument instrument = ChartInstrument.concert,
}) => shareCharts(
  context,
  [tune.transposed(semitones)],
  heading: tune.title,
  instrument: instrument,
);

/// Shares several charts at once, one after another under [heading].
///
/// [tunes] are as the band sounds them; [instrument] is what the player is
/// reading them on, and everything but the MIDI is written for it.
Future<void> shareCharts(
  BuildContext context,
  List<Tune> tunes, {
  String? heading,
  ChartInstrument instrument = ChartInstrument.concert,
}) async {
  if (tunes.isEmpty) return;
  final subject = heading ?? tunes.first.title;
  final how = await _askHow(context, tunes.length, instrument);
  if (how == null || !context.mounted) return;
  // The chart as it is being read. The same tunes when the player reads
  // at concert pitch, which is most of them.
  final reading = instrument.semitones == 0
      ? tunes
      : [for (final tune in tunes) tune.transposed(instrument.semitones)];
  // Said once at the top of whatever carries words, so nobody opens an
  // E flat chart thinking it is in C.
  final written = instrument == ChartInstrument.concert
      ? null
      : 'Written for ${instrument.name}';
  switch (how) {
    case _How.text:
      await _share(
        context,
        chartsText(
          reading,
          heading: [?(tunes.length > 1 ? heading : null), ?written].join('\n'),
        ),
        subject: subject,
      );
    case _How.ireal:
      // The exporter works on the player's own progressions, so a standard
      // is written out as one first. Those stand-ins are never saved.
      final songs = [
        for (final (index, tune) in reading.indexed)
          UserProgression.fromTune(tune, id: '$index'),
      ];
      await _share(
        context,
        tunes.length == 1
            ? irealLinkFor(songs.first)
            : irealPlaylistLink(songs, subject),
        subject: subject,
      );
    case _How.musicXml:
      await _shareFiles(context, [
        for (final (index, tune) in reading.indexed)
          () {
            final song = UserProgression.fromTune(tune, id: '$index');
            return (
              name: musicXmlFileName(song),
              mime: 'application/vnd.recordare.musicxml+xml',
              bytes: utf8.encode(musicXmlFor(song, note: written)),
            );
          }(),
      ], subject: subject);
    case _How.pdf:
      // The page is drawn first: it takes a moment, and the share sheet
      // should come up with the file already made.
      final pdf = await chartPdf(reading, heading: subject, note: written);
      if (!context.mounted) return;
      await _shareFiles(context, [
        (
          name: '${fileNameFor(subject)}.pdf',
          mime: 'application/pdf',
          bytes: pdf,
        ),
      ], subject: subject);
    case _How.midi:
      await _shareFiles(context, [
        for (final tune in tunes)
          (
            name: midiFileName(tune.title),
            mime: 'audio/midi',
            bytes: midiFor(tune),
          ),
      ], subject: subject);
  }
}

/// A file on its way out: what it is called, what it is, and what is in it.
typedef _OutFile = ({String name, String mime, List<int> bytes});

enum _How { text, ireal, musicXml, pdf, midi }

Future<_How?> _askHow(
  BuildContext context,
  int tunes,
  ChartInstrument instrument,
) => showModalBottomSheet<_How>(
  context: context,
  showDragHandle: true,
  builder: (context) => SafeArea(
    // Five ways out and a word about the trademark: more than fits on
    // a short screen, so the sheet scrolls rather than overflowing.
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              tunes == 1 ? 'Share This Chart' : 'Share These $tunes Charts',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ListTile(
            key: const ValueKey('share-text'),
            leading: const Icon(Icons.notes),
            title: const Text('As Text'),
            subtitle: const Text('The changes, laid out as they are here'),
            onTap: () => Navigator.of(context).pop(_How.text),
          ),
          ListTile(
            key: const ValueKey('share-ireal'),
            leading: const Icon(Icons.link),
            title: const Text('As an iReal Pro Link'),
            subtitle: const Text('Opens in iReal Pro on the other end'),
            onTap: () => Navigator.of(context).pop(_How.ireal),
          ),
          ListTile(
            key: const ValueKey('share-pdf'),
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('As a PDF'),
            subtitle: const Text('The chart as a page, to print or to read'),
            onTap: () => Navigator.of(context).pop(_How.pdf),
          ),
          ListTile(
            key: const ValueKey('share-midi'),
            leading: const Icon(Icons.piano_outlined),
            title: const Text('As MIDI'),
            subtitle: const Text('The band playing it, for a DAW'),
            onTap: () => Navigator.of(context).pop(_How.midi),
          ),
          ListTile(
            key: const ValueKey('share-musicxml'),
            leading: const Icon(Icons.library_music_outlined),
            title: const Text('As MusicXML'),
            subtitle: const Text('Opens in notation software, chords and form'),
            onTap: () => Navigator.of(context).pop(_How.musicXml),
          ),
          if (instrument != ChartInstrument.concert)
            Padding(
              key: const ValueKey('share-instrument'),
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Text(
                'The chart goes out as you are reading it, written for '
                '${instrument.name}.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Text(
              'iReal Pro is a trademark of its owner; The Changes isn\'t '
              'affiliated with it.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    ),
  ),
);

Future<void> _share(
  BuildContext context,
  String text, {
  required String subject,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  } catch (e) {
    debugPrint('Could not share the chart: $e');
    messenger?.showSnackBar(
      const SnackBar(content: Text("Couldn't share that chart.")),
    );
  }
}

/// Writes [files] out and hands them to the share sheet.
///
/// They go in the temporary folder because the copy that matters is
/// wherever the player puts it, and everything that can fail quietly
/// happens before the sheet comes up.
Future<void> _shareFiles(
  BuildContext context,
  List<_OutFile> files, {
  required String subject,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final folder = await getTemporaryDirectory();
    final written = <XFile>[];
    for (final out in files) {
      final file = File('${folder.path}/${out.name}');
      await file.writeAsBytes(out.bytes);
      written.add(XFile(file.path, mimeType: out.mime));
    }
    await SharePlus.instance.share(
      ShareParams(
        files: written,
        fileNameOverrides: [for (final out in files) out.name],
        subject: subject,
      ),
    );
  } catch (e) {
    debugPrint('Could not share the chart: $e');
    messenger?.showSnackBar(
      const SnackBar(content: Text("Couldn't share that chart.")),
    );
  }
}
