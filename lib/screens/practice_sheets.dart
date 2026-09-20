// The sheets the practice screen pulls up from the bottom: how the chart
// is written, the mixer, the arrangement, and the takes you've recorded.
//
// They share one presenter, so they all sit at the same height and scroll
// the same way however long they are.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/arpeggios.dart';
import '../audio/backing_synth.dart';
import '../music/arrangement.dart';
import '../music/chord_drill.dart';
import '../music/tune.dart';
import '../music/tuning.dart';
import '../practice/practice_controller.dart';
import '../practice/take_store.dart';
import '../settings/app_settings.dart';
import '../theme.dart';
import 'chart_instrument_button.dart';

/// The practice screen's sheets, all opened the same way.
///
/// Any of them can grow taller than the screen — a long arrangement, a mixer
/// with every channel, or simply large text — and a sheet that reaches the
/// top leaves nothing to tap to get out of it, while dragging its contents
/// only scrolls them. So they stop short of the top, and carry a Done button
/// underneath that can't be scrolled away.
Future<void> practiceSheet(
  BuildContext context,
  Widget Function(BuildContext context) content,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) => ConstrainedBox(
    // Measured inside the sheet, so it is the screen the sheet is actually
    // on. Short of the top, so there is always barrier left to tap.
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.85,
    ),
    child: SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: content(context),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('sheet-done'),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);

/// What the chart shows, chosen while practising: the key it's written in,
/// a fingering diagram and a chord tone to aim for. Everything else lives in
/// the Settings tab.
Future<void> showViewOptions(
  BuildContext context,
  PracticeController controller,
) {
  final settings = controller.settings;
  return practiceSheet(
    context,
    (context) => ListenableBuilder(
      listenable: Listenable.merge([settings, controller]),
      builder: (context, _) {
        final theme = Theme.of(context);
        Widget heading(String text) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(text, style: theme.textTheme.titleSmall),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            heading('Chart Written For'),
            InstrumentKeyPicker(
              instrument: settings.instrument,
              onChanged: settings.setInstrument,
            ),
            heading('Fingering Diagram'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final diagram in ChordDiagram.values)
                  ChoiceChip(
                    key: ValueKey('diagram-${diagram.name}'),
                    label: Text(diagram.label),
                    selected: settings.diagram == diagram,
                    onSelected: (_) => settings.setDiagram(diagram),
                  ),
              ],
            ),
            heading('Aim For'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final target in <DrillTarget?>[
                  null,
                  ...DrillTarget.values,
                ])
                  ChoiceChip(
                    key: ValueKey('aim-${target?.name ?? 'off'}'),
                    label: Text(target?.label ?? 'Off'),
                    selected: settings.aimFor == target,
                    onSelected: (_) => settings.setAimFor(target),
                  ),
              ],
            ),
            SwitchListTile(
              key: const ValueKey('check-playing'),
              contentPadding: EdgeInsets.zero,
              secondary: Icon(controller.checking ? Icons.mic : Icons.mic_none),
              title: const Text('Check My Playing'),
              subtitle: Text(_listenLine(controller)),
              value: controller.checking,
              onChanged: controller.setChecking,
            ),
            if (controller.listenState == Listening.listening)
              _MicMeter(controller: controller),
            Text(
              'Wear headphones. Through a speaker the microphone hears the '
              'band as well as you — and what it hears loudest is what it '
              'marks.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// Proof that the microphone is hearing you: how loud, and what note. Play
/// something and it moves — which is the difference between "this doesn't
/// work" and "hold it nearer".
class _MicMeter extends StatelessWidget {
  const _MicMeter({required this.controller});

  final PracticeController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heard = controller.heard;
    // Quiet playing sits far too low on a straight scale to see, so this is
    // a rough decibel one covering everything from a whisper upwards.
    final level = (1 + math.log(controller.listenLevel.clamp(0.0002, 1)) / 9)
        .clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: LinearProgressIndicator(
              key: const ValueKey('mic-level'),
              value: level,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              color: heard == null
                  ? theme.colorScheme.onSurfaceVariant
                  : successColour(theme.colorScheme),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              // Three different problems, said apart: nothing arriving,
              // plenty arriving but nothing nameable in it (which is what a
              // band through a speaker sounds like), and a note.
              // A meter is meant to move, so this says what is true right
              // now rather than waiting to be sure.
              heard != null
                  ? 'Hearing ${pitchClassName(heard.midi % 12)}'
                  : controller.tooQuiet
                  ? 'Too quiet — play a note'
                  : 'Sound, but no clear note',
              key: const ValueKey('mic-hearing'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: heard == null
                    ? theme.colorScheme.onSurfaceVariant
                    : successColour(theme.colorScheme),
                fontWeight: heard == null ? null : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What the microphone is doing, said plainly.
String _listenLine(PracticeController controller) {
  if (!controller.checking) {
    return 'The app listens, and marks each change you land on';
  }
  return switch (controller.listenState) {
    Listening.denied =>
      "The microphone is blocked — allow it in the phone's settings",
    Listening.failed => "The microphone wouldn't start",
    Listening.starting => 'Starting the microphone…',
    Listening.listening => 'Listening',
    Listening.off => 'Listening starts when the band does',
  };
}

/// A bottom sheet with a volume slider, mute and solo for each instrument.
void showMixer(BuildContext context, PracticeController controller) {
  // As tall as it needs (the arpeggios add a channel), scrolling if the
  // screen is short or the text large.
  practiceSheet(
    context,
    (context) => ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final theme = Theme.of(context);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Expanded rather than a Spacer: at a large text size the
                // heading and the button together are wider than the sheet,
                // and this lets the heading wrap instead of overflowing.
                Expanded(
                  child: Text('Mixer', style: theme.textTheme.titleLarge),
                ),
                TextButton(
                  onPressed: controller.resetMix,
                  child: const Text('Reset'),
                ),
              ],
            ),
            Text(
              'Mute your own part, or solo one to hear it alone.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            // Who plays the chords, for every tune.
            Row(
              children: [
                Text('Chords', style: theme.textTheme.titleSmall),
                const SizedBox(width: 12),
                Expanded(
                  child: SegmentedButton<Comping>(
                    key: const ValueKey('comping'),
                    showSelectedIcon: false,
                    segments: [
                      for (final comping in Comping.values)
                        ButtonSegment(
                          value: comping,
                          label: Text(comping.label),
                        ),
                    ],
                    selected: {controller.settings.comping},
                    onSelectionChanged: (value) =>
                        controller.setComping(value.first),
                  ),
                ),
              ],
            ),
            SwitchListTile(
              key: const ValueKey('count-in'),
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                controller.countIn
                    ? Icons.timer_outlined
                    : Icons.timer_off_outlined,
              ),
              title: const Text('Count-In'),
              subtitle: const Text('One bar of clicks first'),
              value: controller.countIn,
              onChanged: controller.setCountIn,
            ),
            SwitchListTile(
              key: const ValueKey('arpeggios'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Arpeggios'),
              subtitle: const Text('Each chord broken up: 1 3 5 7'),
              value: controller.arpeggios,
              onChanged: controller.setArpeggios,
            ),
            if (controller.arpeggios)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text('Played On', style: theme.textTheme.titleSmall),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SegmentedButton<Comping>(
                        key: const ValueKey('arpeggio-sound'),
                        showSelectedIcon: false,
                        segments: [
                          for (final sound in Comping.values)
                            ButtonSegment(
                              value: sound,
                              label: Text(sound.label),
                            ),
                        ],
                        selected: {controller.settings.arpeggioSound},
                        onSelectionChanged: (value) =>
                            controller.setArpeggioSound(value.first),
                      ),
                    ),
                  ],
                ),
              ),
            if (controller.arpeggios)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text('Start On', style: theme.textTheme.titleSmall),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SegmentedButton<ArpeggioStart>(
                        key: const ValueKey('arpeggio-start'),
                        showSelectedIcon: false,
                        segments: [
                          for (final start in ArpeggioStart.values)
                            ButtonSegment(
                              value: start,
                              label: Text(start.short),
                            ),
                        ],
                        selected: {controller.settings.arpeggioStart},
                        onSelectionChanged: (value) =>
                            controller.setArpeggioStart(value.first),
                      ),
                    ),
                  ],
                ),
              ),
            for (final instrument in controller.parts)
              _MixerChannel(controller: controller, instrument: instrument),
          ],
        );
      },
    ),
  );
}

class _MixerChannel extends StatelessWidget {
  const _MixerChannel({required this.controller, required this.instrument});

  final PracticeController controller;
  final Instrument instrument;

  @override
  Widget build(BuildContext context) {
    final audible = controller.isAudible(instrument);
    final name = controller.partName(instrument).toLowerCase();
    return Opacity(
      opacity: audible ? 1 : 0.5,
      child: Row(
        children: [
          Icon(_iconFor(instrument, controller.settings.comping)),
          const SizedBox(width: 8),
          SizedBox(width: 56, child: Text(controller.partName(instrument))),
          Expanded(
            child: Slider(
              value: controller.volumeOf(instrument),
              label: '${(controller.volumeOf(instrument) * 100).round()}%',
              divisions: 20,
              semanticFormatterCallback: (v) =>
                  '$name volume ${(v * 100).round()}%',
              onChanged: (value) => controller.setVolume(instrument, value),
            ),
          ),
          IconButton(
            isSelected: controller.isMuted(instrument),
            icon: const Icon(Icons.volume_up),
            selectedIcon: const Icon(Icons.volume_off),
            tooltip: controller.isMuted(instrument)
                ? 'Unmute $name'
                : 'Mute $name',
            onPressed: () => controller.toggleMute(instrument),
          ),
          IconButton(
            isSelected: controller.isSoloed(instrument),
            icon: const Icon(Icons.headphones_outlined),
            selectedIcon: const Icon(Icons.headphones),
            tooltip: controller.isSoloed(instrument)
                ? 'Unsolo $name'
                : 'Solo $name',
            onPressed: () => controller.toggleSolo(instrument),
          ),
        ],
      ),
    );
  }
}

IconData _iconFor(Instrument instrument, Comping comping) =>
    switch (instrument) {
      Instrument.chords =>
        comping == Comping.piano ? Icons.piano : Icons.queue_music,
      Instrument.bass => Icons.music_note,
      Instrument.drums => Icons.album,
      Instrument.arpeggio => Icons.stairs_outlined,
    };

/// A bottom sheet for how the band plays the form: how many choruses, which
/// of them are the melody, trading with the drummer, and who lays out.
void showArrangement(BuildContext context, PracticeController controller) {
  practiceSheet(
    context,
    (context) => ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final theme = Theme.of(context);
        final a = controller.arrangement;
        final swings = controller.tune.style.bass == BassStyle.walking;
        Widget heading(String text) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: Text(text, style: theme.textTheme.titleSmall),
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                // Expanded rather than a Spacer: at a large text size the
                // heading and the button together are wider than the sheet,
                // and this lets the heading wrap instead of overflowing.
                Expanded(
                  child: Text('Arrangement', style: theme.textTheme.titleLarge),
                ),
                TextButton(
                  key: const ValueKey('arrangement-reset'),
                  onPressed: () =>
                      controller.setArrangement(Arrangement.keepGoing),
                  child: const Text('Reset'),
                ),
              ],
            ),
            Text(
              'A performance rather than a loop: play the head, take '
              'your choruses, trade with the drummer, come back in.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            heading('Choruses'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  key: const ValueKey('choruses-keep'),
                  label: const Text('Keep Going'),
                  showCheckmark: false,
                  selected: a.choruses == null,
                  onSelected: (_) =>
                      controller.setArrangement(a.copyWith(keepGoing: true)),
                ),
                for (final count in [2, 3, 4, 5, 6, 8, 12])
                  ChoiceChip(
                    key: ValueKey('choruses-$count'),
                    label: Text('$count'),
                    showCheckmark: false,
                    selected: a.choruses == count,
                    onSelected: (_) =>
                        controller.setArrangement(a.copyWith(choruses: count)),
                  ),
              ],
            ),
            SwitchListTile(
              key: const ValueKey('head-in-out'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Head In & Out'),
              subtitle: Text(
                a.choruses == null
                    ? 'The first time round is the melody; set a number '
                          'of choruses to come back to it at the end'
                    : 'The first and last time round is the melody, '
                          'with ${a.choruses! - 2 < 1 ? 'no' : a.choruses! - 2} '
                          'chorus${a.choruses! - 2 == 1 ? '' : 'es'} to solo',
              ),
              value: a.headInAndOut,
              onChanged: (on) =>
                  controller.setArrangement(a.copyWith(headInAndOut: on)),
            ),
            if (swings)
              SwitchListTile(
                key: const ValueKey('two-feel'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Two-Feel on the Head'),
                subtitle: const Text(
                  'The bass plays in two on the melody and walks for '
                  'the solos',
                ),
                value: a.twoFeelOnHead,
                onChanged: a.headInAndOut
                    ? (on) => controller.setArrangement(
                        a.copyWith(twoFeelOnHead: on),
                      )
                    : null,
              ),
            heading('Tempo Ramp'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final step in [0, 2, 5, 10])
                  ChoiceChip(
                    key: ValueKey('ramp-$step'),
                    label: Text(step == 0 ? 'Off' : '+$step'),
                    showCheckmark: false,
                    selected: a.ramp.step == step,
                    onSelected: (_) => controller.setArrangement(
                      a.copyWith(
                        ramp: TempoRamp(
                          step: step,
                          // A sensible ceiling the first time it's
                          // switched on; changed just below.
                          climb: a.ramp.climb ?? 40,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (a.ramp.isOn) ...[
              const SizedBox(height: 10),
              Text('Up To', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final climb in <int?>[20, 40, 60, null])
                    ChoiceChip(
                      key: ValueKey('climb-${climb ?? 'none'}'),
                      label: Text(
                        climb == null
                            ? 'No Limit'
                            : '${controller.tempo + climb}',
                      ),
                      showCheckmark: false,
                      selected: a.ramp.climb == climb,
                      onSelected: (_) => controller.setArrangement(
                        a.copyWith(
                          ramp: TempoRamp(step: a.ramp.step, climb: climb),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _rampLine(controller),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            heading('Trade With the Drums'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final trading in Trading.values)
                  ChoiceChip(
                    key: ValueKey('trading-${trading.name}'),
                    label: Text(trading.label),
                    showCheckmark: false,
                    selected: a.trading == trading,
                    onSelected: (_) =>
                        controller.setArrangement(a.copyWith(trading: trading)),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                a.trading == Trading.off
                    ? 'The band plays all the way through.'
                    : 'You take ${a.trading.bars}, the drummer takes '
                          '${a.trading.bars}, all the way round — '
                          'except on the head.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            heading('Lay Out on the Solos'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final part in LayOut.values)
                  FilterChip(
                    key: ValueKey('lay-out-${part.name}'),
                    label: Text(
                      part == LayOut.chords
                          ? controller.settings.comping.label
                          : part.label,
                    ),
                    selected: a.layOut.contains(part),
                    onSelected: (on) => controller.setArrangement(
                      a.copyWith(
                        layOut: {
                          for (final other in LayOut.values)
                            if (other == part ? on : a.layOut.contains(other))
                              other,
                        },
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                a.layOut.isEmpty
                    ? "Drop a part and it's yours to cover."
                    : 'Nobody plays it but you — the band comes back '
                          'for the head.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            heading('Save It as Audio'),
            Text(
              a.choruses == null
                  ? 'Set a number of choruses above and the band can be '
                        'written out as a file — a track has to end.'
                  : 'The whole arrangement as a file, to send somewhere or '
                        'play on anything.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              key: const ValueKey('export'),
              icon: controller.isExporting
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share),
              label: Text(
                controller.isExporting
                    ? 'Writing it out…'
                    : switch (controller.exportLengthNow) {
                        final length? =>
                          'Export ${_minutes(length)} of Backing',
                        null => 'Export Backing Track',
                      },
              ),
              onPressed: a.choruses == null || controller.isExporting
                  ? null
                  : controller.exportBacking,
            ),
          ],
        );
      },
    ),
  );
}

/// What the ramp will actually do, in the tempos you'd count off.
String _rampLine(PracticeController controller) {
  final ramp = controller.arrangement.ramp;
  final from = controller.tempo;
  if (!ramp.isOn) {
    return 'The band plays the whole thing at $from. Ramp it and every '
        'time round is a little faster.';
  }
  final toTop = ramp.chorusesToTop(from);
  final total = controller.arrangement.choruses;
  // It can only climb for as long as the performance lasts.
  final last = total == null ? toTop : math.min(toTop, total - 1);
  final end = ramp.tempoAt(last, from);
  if (end == from) return 'Already at the top of the ramp.';
  if (total != null && toTop > total - 1) {
    return 'Starts at $from and ends at $end on the last chorus.';
  }
  return 'Starts at $from and reaches $end on chorus ${last + 1}'
      '${ramp.climb == null ? '' : ', then stays there'}.';
}

/// The takes recorded over this tune: play one back with the band around
/// it, or throw it away.
void showTakes(BuildContext context, PracticeController controller) {
  final store = controller.takes;
  if (store == null) return;
  practiceSheet(
    context,
    (context) => ListenableBuilder(
      listenable: Listenable.merge([store, controller]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final takes = store.forTune(controller.originalTune.title);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Takes', style: theme.textTheme.titleLarge),
            Text(
              'Recordings of you over the band. Only your playing is kept; '
              'the band is played again around it.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              key: const ValueKey('record-switch'),
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                controller.recording
                    ? Icons.fiber_manual_record
                    : Icons.fiber_manual_record_outlined,
                color: controller.recording ? theme.colorScheme.error : null,
              ),
              title: const Text('Record the Next Take'),
              subtitle: const Text(
                'The microphone starts with the band. Wear headphones, or '
                'the band ends up on the recording too',
              ),
              value: controller.recording,
              onChanged: controller.setRecording,
            ),
            SwitchListTile(
              key: const ValueKey('takes-with-band'),
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.groups_outlined),
              title: const Text('Play the Band Too'),
              subtitle: const Text(
                'The band plays again around your take. Turn it off to hear '
                'only what the microphone heard',
              ),
              value: controller.takesWithBand,
              onChanged: controller.setTakesWithBand,
            ),
            if (controller.playingTake != null) ...[
              const SizedBox(height: 8),
              Text('You Against the Band', style: theme.textTheme.titleSmall),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 20),
                  Expanded(
                    child: Slider(
                      key: const ValueKey('take-volume'),
                      value: controller.takeVolume,
                      onChanged: controller.setTakeVolume,
                    ),
                  ),
                  Text('${(controller.takeVolume * 100).round()}%'),
                ],
              ),
            ],
            const SizedBox(height: 8),
            if (takes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Nothing recorded yet. Switch it on, play, and your take '
                  'turns up here.',
                  key: const ValueKey('no-takes'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final (i, take) in takes.indexed)
                ListTile(
                  key: ValueKey('take-$i'),
                  contentPadding: EdgeInsets.zero,
                  leading: IconButton(
                    icon: Icon(
                      controller.playingTake?.id == take.id &&
                              controller.isPlaying
                          ? Icons.stop_circle_outlined
                          : Icons.play_circle_outline,
                    ),
                    tooltip: 'Play this take with the band',
                    onPressed: () =>
                        controller.playingTake?.id == take.id &&
                            controller.isPlaying
                        ? controller.stop()
                        : controller.playTake(take),
                  ),
                  title: Text(_takeWhen(take.at)),
                  subtitle: Text(_takeAbout(take)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.ios_share),
                        tooltip: 'Send this take, with the band mixed in',
                        onPressed: controller.isExporting
                            ? null
                            : () => controller.exportBacking(take: take),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete this take',
                        onPressed: () => store.delete(take.id),
                      ),
                    ],
                  ),
                ),
          ],
        );
      },
    ),
  );
}

/// "1:04" — how long an exported track will run.
String _minutes(Duration length) {
  final seconds = (length.inSeconds % 60).toString().padLeft(2, '0');
  return '${length.inMinutes}:$seconds';
}

/// "Just now", "14:32", "Yesterday 14:32", "19 Sep 14:32".
String _takeWhen(DateTime at) {
  final now = DateTime.now();
  final clock =
      '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}';
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(at.year, at.month, at.day)).inDays;
  if (days == 0) {
    return now.difference(at).inMinutes < 2 ? 'Just now' : clock;
  }
  if (days == 1) return 'Yesterday $clock';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${at.day} ${months[at.month - 1]} $clock';
}

/// "1:04 · 140 BPM · bars 5–8".
String _takeAbout(Take take) {
  final length = take.length;
  final minutes = length.inMinutes;
  final seconds = (length.inSeconds % 60).toString().padLeft(2, '0');
  final bars = take.loopStart == 0 ? null : 'from beat ${take.loopStart + 1}';
  return [
    '$minutes:$seconds',
    '${take.tempo} BPM',
    if (take.semitones != 0) 'up ${take.semitones}',
    ?bars,
  ].join(' · ');
}
