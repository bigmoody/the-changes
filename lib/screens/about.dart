import 'package:flutter/material.dart';

/// App info and the credits the sample and font licences ask for.
void showAboutTheChanges(BuildContext context) {
  final theme = Theme.of(context);
  showAboutDialog(
    context: context,
    applicationName: 'The Changes',
    applicationLegalese:
        'Charts show chord changes only. Standards are played in many '
        'versions; these follow common jam-session changes.',
    children: [
      const SizedBox(height: 16),
      Text('Instrument Recordings', style: theme.textTheme.titleSmall),
      const SizedBox(height: 8),
      const Text(
        'Piano: Salamander Grand Piano V3 by Alexander Holm, licensed under '
        'CC BY 3.0 (creativecommons.org/licenses/by/3.0). Trimmed and '
        'converted to mono.',
      ),
      const SizedBox(height: 8),
      const Text('Upright bass: Sneakybass by Karoryfer Samples (CC0).'),
      const SizedBox(height: 8),
      const Text('Archtop guitar: Shinyguitar by Karoryfer Samples (CC0).'),
      const SizedBox(height: 8),
      const Text(
        'Drums: Virtuosity Drums by Versilian Studios and Karoryfer '
        'Samples (CC0).',
      ),
      const SizedBox(height: 8),
      const Text('Drums, brushes: Swirly Drums by Karoryfer Samples (CC0).'),
      const SizedBox(height: 8),
      const Text(
        'Lettering and notation: Petaluma Script and Petaluma by Steinberg '
        'Media Technologies, under the SIL Open Font License 1.1.',
      ),
      const SizedBox(height: 8),
      const Text(
        'Import reads iReal Pro links you share to the app, tap, or paste '
        'in. On a phone or tablet, sharing is the one that works: iReal '
        'Pro will not copy a playlist\'s link there, though it will on a '
        'computer. iReal Pro is a trademark of its owner; The Changes '
        'isn\'t affiliated with it.',
      ),
      const SizedBox(height: 8),
      const Text(
        'Sharing a chart sends it out as text, as an iReal Pro link, as a '
        'PDF to print, as MusicXML for notation software, or as MIDI of '
        'the band playing it. The band itself records as an audio file '
        'from the practice screen. Only the changes ever leave: there is '
        'no melody and no lyric in this app to send.',
      ),
    ],
  );
}
