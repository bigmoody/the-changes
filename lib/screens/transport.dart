// The controls under the chart: start and stop, the tempo, the key, and
// which of the band is playing.

import 'package:flutter/material.dart';

import '../audio/arpeggios.dart';
import '../audio/backing_synth.dart';
import '../music/tune.dart';
import '../practice/practice_controller.dart';
import '../theme.dart';
import 'practice_sheets.dart';

/// Two compact rows: play + tempo, then the key and the band's parts.
class Transport extends StatelessWidget {
  const Transport({super.key, required this.controller});

  final PracticeController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = controller;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (c.error != null)
            Text(
              c.error!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          Row(
            children: [
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: c.isPreparing ? null : c.togglePlay,
                  icon: c.isPreparing
                      ? SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : Icon(
                          c.isPlaying && !c.isPaused
                              ? Icons.pause
                              : Icons.play_arrow,
                        ),
                  label: Text(
                    c.isPlaying && !c.isPaused ? 'Pause' : 'Play',
                    style: const TextStyle(fontSize: 17),
                  ),
                ),
              ),
              // Stop goes back to the top of the loop; only there once
              // something is playing (or paused).
              if (c.isPlaying)
                IconButton.filledTonal(
                  icon: const Icon(Icons.stop),
                  tooltip: 'Stop',
                  onPressed: c.stop,
                ),
              if (c.canRecord && !c.isPlaying)
                IconButton(
                  key: const ValueKey('record'),
                  icon: Icon(
                    c.recording
                        ? Icons.fiber_manual_record
                        : Icons.fiber_manual_record_outlined,
                  ),
                  color: c.recording ? theme.colorScheme.error : null,
                  tooltip: c.recording
                      ? 'Recording is on: Play starts the take'
                      : 'Record yourself over the band',
                  onPressed: () => c.setRecording(!c.recording),
                ),
              if (c.isRecordingNow)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.fiber_manual_record,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                ),
              // Shrinks on the narrowest phones (with Stop showing) rather
              // than running off the edge.
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    children: [
                      GestureDetector(
                        onLongPress: () => c.setTempo(c.tempo - 10),
                        child: IconButton(
                          icon: const Icon(Icons.remove),
                          tooltip: 'Slower (hold for −10)',
                          onPressed: () => c.setTempo(c.tempo - 1),
                        ),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _showTempoDialog(context, c),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                          child: Text(
                            '${c.tempo} BPM',
                            semanticsLabel:
                                '${c.tempo} beats per minute, tap to type',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onLongPress: () => c.setTempo(c.tempo + 10),
                        child: IconButton(
                          icon: const Icon(Icons.add),
                          tooltip: 'Faster (hold for +10)',
                          onPressed: () => c.setTempo(c.tempo + 1),
                        ),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: c.tapTempo,
                        child: const Text('Tap'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _KeyButton(controller: c),
              const SizedBox(width: 4),
              // (The count-in switch lives in the mixer, to leave this row
              // room for every part at a readable size.)
              // Scales down on narrow phones instead of overflowing.
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    children: [
                      // Every part gets a chip, including the arpeggios,
                      // whose chip is how they are switched on in the
                      // first place. An imported part only has one once
                      // there is something imported.
                      for (final instrument in Instrument.values)
                        if (instrument != Instrument.imported ||
                            controller.importedPart != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: instrument == Instrument.arpeggio
                                ? _ArpeggioButton(controller: c)
                                : _PartChip(
                                    name: controller.partName(instrument),
                                    on: controller.isAudible(instrument),
                                    muted: controller.isMuted(instrument),
                                    onPressed: () =>
                                        controller.toggleMute(instrument),
                                  ),
                          ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.tune),
                tooltip: 'Mixer',
                onPressed: () => showMixer(context, controller),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Type an exact tempo, or drag the slider.
Future<void> _showTempoDialog(
  BuildContext context,
  PracticeController controller,
) => showDialog<void>(
  context: context,
  builder: (_) => _TempoDialog(controller: controller),
);

/// The dialog owns its text field, so the field lives exactly as long as the
/// dialog does. Disposing it when `showDialog` returns is too early: the
/// dialog carries on building while it animates away, and a field whose
/// controller has gone brings the whole screen down with it.
class _TempoDialog extends StatefulWidget {
  const _TempoDialog({required this.controller});

  final PracticeController controller;

  @override
  State<_TempoDialog> createState() => _TempoDialogState();
}

class _TempoDialogState extends State<_TempoDialog> {
  late final _field = TextEditingController(text: '${widget.controller.tempo}');

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _done(String text) {
    final bpm = int.tryParse(text);
    if (bpm != null) widget.controller.setTempo(bpm);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => AlertDialog(
      title: const Text('Tempo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _field,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(suffixText: 'BPM'),
            onSubmitted: _done,
          ),
          Slider(
            min: PracticeController.minTempo.toDouble(),
            max: PracticeController.maxTempo.toDouble(),
            value: widget.controller.tempo.toDouble(),
            onChanged: (value) {
              widget.controller.setTempo(value.round());
              _field.text = '${widget.controller.tempo}';
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _done(_field.text),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}

/// Shows the current key; opens a menu of all 12 keys.
class _KeyButton extends StatelessWidget {
  const _KeyButton({required this.controller});

  final PracticeController controller;

  @override
  Widget build(BuildContext context) {
    final original = controller.originalTune;
    return MenuAnchor(
      menuChildren: [
        // Offer keys from a fourth below to a fifth above the written key.
        for (var offset = -5; offset <= 6; offset++)
          MenuItemButton(
            leadingIcon: Icon(
              offset % 12 == controller.semitones ? Icons.check : null,
            ),
            trailingIcon: Text(
              offset == 0
                  ? 'written'
                  : '${offset > 0 ? '+' : '−'}${offset.abs()}',
            ),
            onPressed: () => controller.transpose(offset),
            child: Text(
              original.keyLabelBy(
                offset + controller.settings.instrument.semitones,
              ),
            ),
          ),
      ],
      builder: (context, menu, _) => ActionChip(
        visualDensity: VisualDensity.compact,
        avatar: const Icon(Icons.swap_vert, size: 18),
        label: Text(_shortKey(controller.chart.key)),
        tooltip: 'Change key',
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
      ),
    );
  }

  /// "C minor" → "Cm", "D Dorian" → "Dm", "B♭" → "B♭" to fit the chip.
  static String _shortKey(String key) =>
      key.replaceAll(' minor', 'm').replaceAll(' Dorian', 'm').split(',').first;
}

/// The Arpeggios button: off when a tune opens. A tap brings up the choices
/// (off, or which chord tone to start each arpeggio from) and what they're
/// played on.
class _ArpeggioButton extends StatelessWidget {
  const _ArpeggioButton({required this.controller});

  final PracticeController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final settings = c.settings;
    Widget tick(bool on) => Icon(on ? Icons.check : null, size: 20);
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          key: const ValueKey('arpeggio-off'),
          leadingIcon: tick(!c.arpeggios),
          onPressed: () => c.setArpeggios(false),
          child: const Text('Off'),
        ),
        for (final start in ArpeggioStart.values)
          MenuItemButton(
            key: ValueKey('arpeggio-${start.name}'),
            leadingIcon: tick(c.arpeggios && settings.arpeggioStart == start),
            onPressed: () {
              c.setArpeggioStart(start);
              c.setArpeggios(true);
            },
            child: Text(start.label),
          ),
        const Divider(height: 8),
        for (final sound in Comping.values)
          MenuItemButton(
            leadingIcon: tick(settings.arpeggioSound == sound),
            onPressed: () => c.setArpeggioSound(sound),
            child: Text('On ${sound.label.toLowerCase()}'),
          ),
      ],
      builder: (context, menu, _) {
        final on = c.arpeggios && c.isAudible(Instrument.arpeggio);
        final style = _partChipStyle(context, on: on);
        return FilterChip(
          key: const ValueKey('arpeggio-chip'),
          color: style.color,
          side: style.side,
          labelStyle: style.labelStyle,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: _partChipPadding,
          labelPadding: EdgeInsets.zero,
          showCheckmark: false,
          label: const Text('Arpeggios'),
          tooltip: c.arpeggios
              ? 'Arpeggios ${settings.arpeggioStart.label.toLowerCase()}'
              : 'Arpeggios off',
          selected: on,
          onSelected: (_) => menu.isOpen ? menu.close() : menu.open(),
        );
      },
    );
  }
}

/// Just enough room around a part's name for all four to fit on a phone
/// at full size.
const _partChipPadding = EdgeInsets.symmetric(horizontal: 6);

/// A part that's playing reads plainly, on paper; a muted one is faded and
/// struck through. (Filled chips are for choosing one of several: with
/// every part on, they'd be a row of black blocks.)
({WidgetStateProperty<Color?> color, BorderSide side, TextStyle labelStyle})
_partChipStyle(BuildContext context, {required bool on}) {
  final scheme = Theme.of(context).colorScheme;
  return (
    color: WidgetStatePropertyAll(on ? cardColour(scheme) : Colors.transparent),
    side: BorderSide(color: on ? scheme.outline : scheme.outlineVariant),
    labelStyle: TextStyle(
      fontSize: 14,
      fontWeight: on ? FontWeight.w700 : FontWeight.w500,
      color: on ? scheme.onSurface : scheme.onSurfaceVariant,
      decoration: on ? null : TextDecoration.lineThrough,
      decorationColor: scheme.onSurfaceVariant,
    ),
  );
}

/// One of the band's parts, to mute or bring back.
class _PartChip extends StatelessWidget {
  const _PartChip({
    required this.name,
    required this.on,
    required this.muted,
    required this.onPressed,
  });

  final String name;

  /// Heard: not muted, and not silenced by another part being soloed.
  final bool on;
  final bool muted;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final style = _partChipStyle(context, on: on);
    return FilterChip(
      color: style.color,
      side: style.side,
      labelStyle: style.labelStyle,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: _partChipPadding,
      labelPadding: EdgeInsets.zero,
      showCheckmark: false,
      label: Text(name),
      tooltip: muted
          ? 'Unmute ${name.toLowerCase()}'
          : 'Mute ${name.toLowerCase()}',
      selected: on,
      onSelected: (_) => onPressed(),
    );
  }
}
