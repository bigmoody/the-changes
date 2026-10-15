// Sending a chart out of the app: one tune, or a whole setlist.
//
// Several ways out, because they are for different ends. As text, the
// changes are laid out as they are on screen, to read anywhere: a
// message, a note, a printout on the stand. As an iReal Pro link, they go
// into the app most players already keep their charts in. As MusicXML,
// they open in notation software to be engraved or arranged from.
//
// Only the changes leave, whichever way: there is no melody and no lyric
// in this app to send.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../music/chart_text.dart';
import '../music/ireal_export.dart';
import '../music/musicxml_export.dart';
import '../music/tune.dart';
import '../music/user_progression.dart';

/// Shares [tune], asking first whether as text or as a link.
///
/// [semitones] sends it in the key it's being played in rather than the key
/// it's written in, so what goes out is what the player was reading.
Future<void> shareChart(BuildContext context, Tune tune, {int semitones = 0}) =>
    shareCharts(context, [tune.transposed(semitones)], heading: tune.title);

/// Shares several charts at once, one after another under [heading].
Future<void> shareCharts(
  BuildContext context,
  List<Tune> tunes, {
  String? heading,
}) async {
  if (tunes.isEmpty) return;
  final subject = heading ?? tunes.first.title;
  final how = await _askHow(context, tunes.length);
  if (how == null || !context.mounted) return;
  switch (how) {
    case _How.text:
      await _share(
        context,
        chartsText(tunes, heading: tunes.length > 1 ? heading : null),
        subject: subject,
      );
    case _How.ireal:
      // The exporter works on the player's own progressions, so a standard
      // is written out as one first. Those stand-ins are never saved.
      final songs = [
        for (final (index, tune) in tunes.indexed)
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
        for (final (index, tune) in tunes.indexed)
          () {
            final song = UserProgression.fromTune(tune, id: '$index');
            return (
              name: musicXmlFileName(song),
              mime: 'application/vnd.recordare.musicxml+xml',
              text: musicXmlFor(song),
            );
          }(),
      ], subject: subject);
  }
}

/// A file on its way out: what it is called, what it is, and what is in it.
typedef _OutFile = ({String name, String mime, String text});

enum _How { text, ireal, musicXml }

Future<_How?> _askHow(BuildContext context, int tunes) =>
    showModalBottomSheet<_How>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
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
              key: const ValueKey('share-musicxml'),
              leading: const Icon(Icons.library_music_outlined),
              title: const Text('As MusicXML'),
              subtitle: const Text(
                'Opens in notation software, chords and form',
              ),
              onTap: () => Navigator.of(context).pop(_How.musicXml),
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
      await file.writeAsString(out.text);
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
