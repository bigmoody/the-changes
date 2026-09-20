import 'package:flutter/material.dart';

import '../settings/app_settings.dart';

/// An app-bar button for choosing which instrument charts are written for.
class ChartInstrumentButton extends StatelessWidget {
  const ChartInstrumentButton({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MenuAnchor(
        menuChildren: [
          for (final instrument in ChartInstrument.values)
            MenuItemButton(
              leadingIcon: Icon(
                instrument == settings.instrument ? Icons.check : null,
              ),
              onPressed: () => settings.setInstrument(instrument),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(instrument.name),
                    Text(
                      instrument.examples,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
        ],
        builder: (context, menu, _) => TextButton.icon(
          onPressed: () => menu.isOpen ? menu.close() : menu.open(),
          icon: const Icon(Icons.arrow_drop_down),
          iconAlignment: IconAlignment.end,
          label: Text(
            settings.instrument.symbol,
            semanticsLabel: 'Charts for ${settings.instrument.name}',
          ),
          style: TextButton.styleFrom(
            textStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Which key the player's instrument is in: concert, B♭, E♭ or F. Notes are
/// named, played and heard as that player reads them. It's the same setting
/// as the charts' instrument, so both always agree.
class InstrumentKeyPicker extends StatelessWidget {
  const InstrumentKeyPicker({
    super.key,
    required this.instrument,
    required this.onChanged,
    this.showExamples = false,
  });

  final ChartInstrument instrument;
  final ValueChanged<ChartInstrument> onChanged;

  /// Which instruments read in the chosen key, underneath: for Settings,
  /// where it's chosen; elsewhere the letters speak for themselves.
  final bool showExamples;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<ChartInstrument>(
          key: const ValueKey('instrument-key'),
          showSelectedIcon: false,
          segments: [
            for (final value in ChartInstrument.values)
              ButtonSegment(
                value: value,
                label: Text(value.symbol),
                tooltip: value.name,
              ),
          ],
          selected: {instrument},
          onSelectionChanged: (value) => onChanged(value.first),
        ),
        if (showExamples) ...[
          const SizedBox(height: 6),
          Text(
            instrument == ChartInstrument.concert
                ? 'Concert pitch · ${instrument.examples}'
                : '${instrument.name} · ${instrument.examples}',
            key: const ValueKey('instrument-examples'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
