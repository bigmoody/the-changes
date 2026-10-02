// What the app is printed on.
//
// The default follows the system: warm paper by day, near black by night.
// Choosing one instead fixes it, in the dark as well, because a paper
// already has its own lightness and a tune does not change colour because
// the sun went down.
//
// Everything else is worked out from it rather than chosen separately.
// Boxes, rules and the greys between take the paper's hue and keep the
// distances the two built-in schemes were written with, so a chart on
// green paper is the same chart. The ink stays ink, and is swapped for
// black or white if the paper would make it unreadable: a paper you
// cannot read off is not a choice worth offering.

import 'package:flutter/material.dart';

import '../settings/app_settings.dart';
import '../theme.dart';
import 'colour_picker.dart';

class PaperScreen extends StatelessWidget {
  const PaperScreen({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final paper = settings.paper;
    return Scaffold(
      appBar: AppBar(title: const Text('Paper')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'What the app is printed on. Everything else is worked out '
                'from it, so the chart stays a chart.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _Sample(scheme: scheme),
            ),
            ListTile(
              key: const ValueKey('follow-system'),
              leading: const Icon(Icons.brightness_auto_outlined),
              title: const Text('Follow the System'),
              subtitle: const Text('Warm paper by day, near black at night'),
              trailing: paper == null ? const Icon(Icons.check) : null,
              onTap: paper == null ? null : () => settings.setPaper(null),
            ),
            ListTile(
              key: const ValueKey('choose-paper'),
              leading: Icon(
                Icons.palette_outlined,
                color: paper == null ? null : scheme.onSurface,
              ),
              title: const Text('Choose a Paper'),
              subtitle: Text(paper == null ? 'Pick your own colour' : 'Yours'),
              trailing: paper == null ? null : const Icon(Icons.check),
              onTap: () => _pick(context),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'A chosen paper is used in the dark as well: it has its own '
                'lightness already. The ink is swapped for black or white if '
                'the paper would make it hard to read.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final chosen = await pickColour(
      context,
      title: 'Paper',
      start: settings.paper ?? Theme.of(context).colorScheme.surface,
      clearLabel: 'Follow the System',
      // A bar of the chart, built from the paper being chosen, so what is
      // on screen is what the app will look like rather than a swatch.
      preview: (colour) => _Sample(scheme: schemeForPaper(colour)),
    );
    if (chosen == null) return;
    await settings.setPaper(chosen == noColour ? null : chosen);
  }
}

/// Two bars of a chart in [scheme], which is the only preview worth
/// having: the paper, the boxes, the rules and the ink together.
class _Sample extends StatelessWidget {
  const _Sample({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('paper-sample'),
    height: 96,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: scheme.outlineVariant),
    ),
    child: Row(
      children: [
        for (final (i, chord) in ['Dm7', 'G7', 'CΔ7'].indexed)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Container(
                decoration: BoxDecoration(
                  // The middle one as the bar that is playing, so the
                  // pencil shows against the paper too.
                  color: i == 1
                      ? scheme.tertiaryContainer
                      : scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: i == 1 ? scheme.tertiary : scheme.outlineVariant,
                    width: i == 1 ? 2 : 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  handSymbol(chord),
                  style: handLettered(
                    TextStyle(
                      fontSize: 24,
                      color: i == 1
                          ? scheme.onTertiaryContainer
                          : scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
