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
import '../music/chord.dart' show MinorSign;
import '../music/chord_drill.dart';
import '../music/comping.dart';
import '../music/swing.dart';
import 'swing_screen.dart' show ridePattern;
import '../music/meter.dart';
import '../music/tune.dart';
import '../music/tuning.dart';
import '../practice/hiding_the_chart.dart';
import '../practice/practice_controller.dart';
import '../practice/practice_record.dart';
import '../practice/soundfont_store.dart' show SoundFontRole;
import '../practice/take_store.dart';
import '../settings/app_settings.dart';
import '../theme.dart';
import 'chart_instrument_button.dart';
import 'bring_in_sheet.dart';
import 'import_recording_sheet.dart';
import 'sound_shelf.dart';

/// The practice screen's sheets, all opened the same way.
///
/// Any of them can grow taller than the screen (a long arrangement, a mixer
/// with every channel, or simply large text) and a sheet that reaches the
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
            heading('Counted In'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final meter in <Meter?>[null, ...Meter.choices])
                  ChoiceChip(
                    key: ValueKey('meter-${meter?.label ?? 'written'}'),
                    label: Text(meter?.label ?? 'As Written'),
                    selected: meter == null
                        ? !controller.meterIsChosen
                        : controller.meterIsChosen && controller.meter == meter,
                    onSelected: (_) => controller.setMeter(meter),
                  ),
              ],
            ),
            if (controller.meterIsChosen)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${controller.originalTune.title} is written in '
                  '${controller.originalTune.meter.label}. Counting it '
                  'another way is your exercise, not the tune: the bars '
                  'keep their chords and the beats inside them are shared '
                  'out again, and a bar with more chords than the new one '
                  'has beats plays the ones that fit.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            heading('Chart Font'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final face in ChartFont.values)
                  ChoiceChip(
                    key: ValueKey('font-${face.name}'),
                    // Each chip in the hand it is offering, so the choice
                    // is made by reading rather than by guessing.
                    label: Text(
                      face.label,
                      // Size only: the colour is the chip's, which turns
                      // to paper when it is the one chosen.
                      style: letteredIn(face, const TextStyle(fontSize: 15)),
                    ),
                    selected: settings.chartFont == face,
                    onSelected: (_) => settings.setChartFont(face),
                  ),
              ],
            ),
            heading('Minor Chords'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final sign in MinorSign.values)
                  ChoiceChip(
                    key: ValueKey('minor-${sign.name}'),
                    // The chip is the chord itself, written that way, so
                    // the choice is read rather than described.
                    label: Text(sign.label),
                    selected: settings.minorSign == sign,
                    onSelected: (_) => settings.setMinorSign(sign),
                  ),
              ],
            ),
            heading('Under the Chords'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final aid in ChordAid.values)
                  ChoiceChip(
                    key: ValueKey('aid-${aid.name}'),
                    label: Text(aid.label),
                    selected: settings.chordAid == aid,
                    onSelected: (_) => settings.setChordAid(aid),
                  ),
              ],
            ),
            if (settings.chordAid != ChordAid.off)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  settings.chordAid.legend,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            heading('Hide the Chart'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final fade in FadeChart.values)
                  ChoiceChip(
                    key: ValueKey('fade-${fade.name}'),
                    label: Text(fade.label),
                    selected: settings.fadeChart == fade,
                    onSelected: (_) => settings.setFadeChart(fade),
                  ),
              ],
            ),
            if (settings.fadeChart.isOn)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'While the band plays on, the chart goes a rung at a '
                  'time: the chords first, then the bars as well. Keeping '
                  'your place with nothing to look at is a different skill '
                  'from knowing the changes, and it is the one that comes '
                  'apart first. It all comes back when you stop, and you '
                  'can ask for it back sooner, which is not cheating.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
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
              'band as well as you, and what it hears loudest is what it '
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
/// something and it moves, which is the difference between "this doesn't
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
                  ? 'Too quiet: play a note'
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
      "The microphone is blocked: allow it in the phone's settings",
    Listening.failed => "The microphone wouldn't start",
    Listening.starting => 'Starting the microphone…',
    Listening.listening => 'Listening',
    Listening.off => 'Listening starts when the band does',
  };
}

/// Which of the imported sounds a part plays, chosen without leaving the
/// tune.
///
/// The segments above say piano, guitar or imported; this says which
/// imported, and opens every sound on the shelf to change it. It is only
/// there once something has been brought in that could play the part.
class _FromTheShelf extends StatelessWidget {
  const _FromTheShelf({required this.controller, required this.role});

  final PracticeController controller;
  final SoundFontRole role;

  bool get _isOn => switch (role) {
    SoundFontRole.chords => controller.settings.comping == Comping.imported,
    SoundFontRole.bass => controller.settings.bassSound == BassSound.imported,
    SoundFontRole.arpeggio =>
      controller.settings.arpeggioSound == Comping.imported,
    SoundFontRole.drums => controller.settings.drumSound == DrumSound.imported,
  };

  Future<void> _putOn() async {
    // Already on: the setting does not change, so the band is told.
    if (_isOn) return controller.soundsChanged();
    switch (role) {
      case SoundFontRole.chords:
        await controller.setComping(Comping.imported);
      case SoundFontRole.bass:
        await controller.setBassSound(BassSound.imported);
      case SoundFontRole.arpeggio:
        await controller.setArpeggioSound(Comping.imported);
      case SoundFontRole.drums:
        await controller.setDrumSound(DrumSound.imported);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = SoundFonts.maybeOf(context);
    if (store == null) return const SizedBox.shrink();
    final drums = role == SoundFontRole.drums;
    if (!(drums ? store.hasKitsToChoose : store.hasInstrumentsToChoose)) {
      return const SizedBox.shrink();
    }
    final name = drums ? store.drumsFrom : store.nameFor(role);
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: TextButton.icon(
        key: ValueKey('shelf-${role.name}'),
        icon: const Icon(Icons.graphic_eq, size: 18),
        label: Text(
          name == null ? 'Choose an Imported Sound' : 'Imported: $name',
          overflow: TextOverflow.ellipsis,
        ),
        onPressed: () async {
          final done = drums
              ? await chooseKit(context, store)
              : await chooseInstrument(context, store, role, offerOurs: false);
          if (done.outcome == ShelfOutcome.chosen) await _putOn();
          if (done.problem case final problem? when context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(problem)));
          }
        },
      ),
    );
  }
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
        final shelf = SoundFonts.maybeOf(context);
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
                  key: const ValueKey('mixer-reset'),
                  onPressed: controller.resetSheet,
                  child: const Text('Reset'),
                ),
              ],
            ),
            Text(
              'Mute your own part, or solo one to hear it alone. Reset '
              'puts the band, the levels and the count-in back; the kit '
              'and who plays the chords are yours and stay.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _TheBand(controller: controller),
            const SizedBox(height: 8),
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
            _FromTheShelf(controller: controller, role: SoundFontRole.chords),
            const SizedBox(height: 8),
            // And who plays the bass, which is only a choice once somebody
            // has imported something for it.
            if (controller.settings.bassSound == BassSound.imported ||
                controller.hasImportedBass ||
                (shelf?.hasInstrumentsToChoose ?? false))
              Row(
                children: [
                  Text('Bass', style: theme.textTheme.titleSmall),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SegmentedButton<BassSound>(
                      key: const ValueKey('bass-sound'),
                      showSelectedIcon: false,
                      segments: [
                        for (final sound in BassSound.values)
                          ButtonSegment(value: sound, label: Text(sound.label)),
                      ],
                      selected: {controller.settings.bassSound},
                      onSelectionChanged: (value) =>
                          controller.setBassSound(value.first),
                    ),
                  ),
                ],
              ),
            _FromTheShelf(controller: controller, role: SoundFontRole.bass),
            const SizedBox(height: 8),
            // Always shown now there are two kits in the app. It used to
            // appear only once something had been imported, which was
            // right when the only other choice was a kit you had to go
            // and find yourself.
            Row(
              children: [
                // "Kit" and not "Drums": there is already a Drums row
                // above, and it means the groove rather than the sound.
                Text('Kit', style: theme.textTheme.titleSmall),
                const SizedBox(width: 12),
                Expanded(
                  child: SegmentedButton<DrumSound>(
                    key: const ValueKey('drum-sound'),
                    showSelectedIcon: false,
                    segments: [
                      for (final sound in controller.kitChoices)
                        ButtonSegment(value: sound, label: Text(sound.label)),
                    ],
                    selected: {controller.settings.drumSound},
                    onSelectionChanged: (value) =>
                        controller.setDrumSound(value.first),
                  ),
                ),
              ],
            ),
            _FromTheShelf(controller: controller, role: SoundFontRole.drums),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Count-In', style: theme.textTheme.titleSmall),
                const SizedBox(width: 12),
                Expanded(
                  child: SegmentedButton<int>(
                    key: const ValueKey('count-in'),
                    showSelectedIcon: false,
                    segments: [
                      for (final bars in PracticeController.countInChoices)
                        ButtonSegment(
                          value: bars,
                          label: Text(switch (bars) {
                            0 => 'Off',
                            1 => '1 Bar',
                            _ => '2 Bars',
                          }),
                        ),
                    ],
                    selected: {controller.countInBars},
                    onSelectionChanged: (value) =>
                        controller.setCountInBars(value.first),
                  ),
                ),
              ],
            ),
            // Two bars is what somebody counting a band in actually
            // does: "one, two, one two three four". It is eight beats
            // in four, six in a waltz, and twelve eighths in six eight.
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                controller.countInBars == 2
                    ? 'Two bars of clicks: the count-off.'
                    : controller.countInBars == 1
                    ? 'One bar of clicks first.'
                    : 'The band starts where you do.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
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
              _FromTheShelf(
                controller: controller,
                role: SoundFontRole.arpeggio,
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
            if (controller.arpeggios)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text('Rate', style: theme.textTheme.titleSmall),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SegmentedButton<ArpeggioRate>(
                        key: const ValueKey('arpeggio-rate'),
                        showSelectedIcon: false,
                        segments: [
                          for (final rate in ArpeggioRate.values)
                            ButtonSegment(value: rate, label: Text(rate.label)),
                        ],
                        selected: {controller.settings.arpeggioRate},
                        onSelectionChanged: (value) =>
                            controller.setArpeggioRate(value.first),
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
                    Text('Up To', style: theme.textTheme.titleSmall),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SegmentedButton<ArpeggioReach>(
                        key: const ValueKey('arpeggio-reach'),
                        showSelectedIcon: false,
                        segments: [
                          for (final reach in ArpeggioReach.values)
                            ButtonSegment(
                              value: reach,
                              label: Text(reach.label),
                            ),
                        ],
                        selected: {controller.settings.arpeggioReach},
                        onSelectionChanged: (value) =>
                            controller.setArpeggioReach(value.first),
                      ),
                    ),
                  ],
                ),
              ),
            if (controller.recordingStore != null && controller.ref != null)
              ListTile(
                key: const ValueKey('import-recording'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.groups_outlined),
                title: const Text('Recorded Band'),
                subtitle: Text(_recordedBandSays(controller)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showImportRecording(context, controller),
              ),
            if (!controller.recordedTakes.isEmpty)
              SwitchListTile(
                key: const ValueKey('use-recording'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Play the Recording'),
                subtitle: const Text('Off plays the generated band instead'),
                value: controller.useRecording,
                onChanged: controller.setUseRecording,
              ),
            // One way in. The file says what it is, so nobody has to
            // decide whether theirs is a "part" or a "recording" before
            // the app will look at it. The rows above and below stay for
            // what is already in, which is a different question.
            ListTile(
              key: const ValueKey('bring-in'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.file_open_outlined),
              title: const Text('Bring Something In'),
              subtitle: Text(
                controller.importedPart == null
                    ? 'A MIDI part to play alongside, or real players to '
                          'take over'
                    : '${controller.importedPart!.name}, on the '
                          '${controller.importedPart!.voice.label.toLowerCase()}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => bringSomethingIn(context, controller),
            ),
            for (final instrument in controller.parts)
              _MixerChannel(controller: controller, instrument: instrument),
          ],
        );
      },
    ),
  );
}

/// What the Recorded Band row says underneath itself.
///
/// The take in use and how hard it is being pushed to get here, because
/// that is the thing somebody wants to know when the band sounds odd and
/// they have come to the mixer to find out why.
String _recordedBandSays(PracticeController controller) {
  final takes = controller.recordedTakes;
  if (takes.isEmpty) return 'Play a recording of real players instead';
  final take = controller.recordingInUse;
  final shift = controller.recordingShift;
  // Where it came from, always, when it came from somewhere else. A take
  // imported against another tune is the whole point of this working at
  // all, and also the one thing nobody should ever discover by ear.
  final borrowed = controller.borrowedInUse;
  final from = borrowed == null ? '' : ' Played for ${borrowed.from}.';
  if (take == null || shift == null) {
    final waiting = controller.borrowedTakes.length;
    final mine = controller.ownTakes.length;
    final counted = [
      if (mine > 0) '$mine ${mine == 1 ? 'take' : 'takes'}',
      if (waiting > 0)
        '$waiting from ${waiting == 1 ? 'another tune' : 'other tunes'}',
    ].join(', ');
    return '$counted, not being played';
  }
  return '${take.name}.$from '
      '${shift.strain.label}, ${shift.cents.round()} cents';
}

/// Two bars of the ride figure at [at], so a swing can be heard without
/// waiting for the band to be built again.
///
/// The ride alone and nothing under it. The "and" is the whole of what
/// moves, and it is far easier to hear on its own than inside a band.
Future<void> _hearSwing(PracticeController controller, double at) async {
  final bank = controller.player.samples;
  if (bank == null) return;
  await controller.player.playSnippet(
    renderSnippet(
      bank,
      const [],
      drums: ridePattern(tempo: controller.tempo, at: at),
    ),
  );
}

/// How hard the band swings this tune.
///
/// Left alone it follows the tempo, which is the better answer for nearly
/// everybody: the short half of a swung pair stays about the same length
/// whatever the tempo and the beat shrinks around it, so a ballad swings
/// hard and a burn-up comes out nearly straight without anybody saying
/// so. The Swing page in Learn is an argument for that curve.
///
/// This is where you disagree with it, and it is in the mixer rather than
/// in the settings for two reasons. It belongs to the tune, the way the
/// feel does, and gets saved with it. And the band is usually playing
/// while this sheet is open, so the slider is its own demonstration:
/// nobody can choose a swing they have not heard.
class _BandSwing extends StatelessWidget {
  const _BandSwing({required this.controller, required this.style});

  final PracticeController controller;
  final BandStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final follows = style.swing == null;
    final feel = style.drums;
    // Where this groove sits when nobody has touched it, which is the
    // tempo's own swing for the ones that swing and even for the rest.
    // Reading the swing feel's answer here showed a bossa resting at
    // "dotted" while the band played it even.
    final resting = feel.swingBy(controller.tempo);
    final at = style.swing ?? resting;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 72,
                child: Text('Swing', style: theme.textTheme.bodyMedium),
              ),
              Expanded(
                child: Slider(
                  key: const ValueKey('band-swing'),
                  min: straight,
                  max: widestSwing,
                  value: at,
                  label: ratioText(at),
                  // Taking hold of it is a way of saying you would rather
                  // choose, so it stops following. The same gesture means
                  // the same thing on the Learn page.
                  onChanged: controller.setSwing,
                ),
              ),
              // Hearing it should not mean dragging, waiting for the band
              // to build again and trying to remember what the last one
              // sounded like. This is the ride figure on its own, at the
              // tempo this tune is set to, the instant it is asked for.
              IconButton(
                key: const ValueKey('hear-swing'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.volume_up_outlined),
                tooltip: 'Hear the swing',
                onPressed: () => _hearSwing(controller, at),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 72),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    switch ((follows, feel.swings)) {
                      // Left alone, a swinging feel follows the tempo and
                      // an even one simply stays even.
                      (true, true) =>
                        'Follows the tempo: '
                            '${swingName(at).toLowerCase()}, '
                            '${ratioText(at)} at ${controller.tempo}',
                      (true, false) =>
                        'Even, as a ${feel.label.toLowerCase()} is played',
                      // Moved, it is that much at every tempo, and in a
                      // feel that leans its sixteenths it is those.
                      (false, _) =>
                        '${swingName(at)}, ${ratioText(at)}, at every tempo'
                            '${feel.swingsSixteenths ? ', on the sixteenths' : ''}',
                    },
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                // Always there, greyed when there is nothing to undo.
                // Shown only once the fader had been moved, it was a
                // button you could not find by looking: you had to
                // already have done the thing you wanted undone.
                TextButton(
                  key: const ValueKey('swing-follow-again'),
                  onPressed: follows ? null : () => controller.setSwing(null),
                  // Called what it is. Where it goes back to differs by
                  // groove, following the tempo in one and sitting even
                  // in another, and the line beside it says which: the
                  // button only has to say that it undoes.
                  child: const Text('Reset'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// How this tune is played: the groove, and what the bass and the chords
/// do with it.
///
/// It lives in the mixer because that is where you go when the band isn't
/// doing what you want. A standard is written with a feel, and this is
/// where you disagree with it; the choice is kept with the tune, so it is
/// still yours the next time you open it.
class _TheBand extends StatelessWidget {
  const _TheBand({required this.controller});

  final PracticeController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = controller.style;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('The Band', style: theme.textTheme.titleSmall),
            ),
            if (controller.styleIsChosen)
              TextButton(
                key: const ValueKey('style-reset'),
                onPressed: () => controller.setStyle(null),
                child: const Text('As written'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        // A block that wraps, not a row that scrolls sideways: this is
        // where a player chooses the groove, and a groove they cannot
        // see is one they will not find. The sheet itself scrolls, so
        // the cost of another line here is paid there.
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final feel in Feel.values)
              ChoiceChip(
                key: ValueKey('groove-${feel.name}'),
                visualDensity: VisualDensity.compact,
                showCheckmark: false,
                label: Text(feel.label),
                // The figure and the swing are set apart from the groove,
                // so a band playing the Charleston in B flat bossa is
                // still a bossa, and a swing somebody has set harder than
                // the curve is still a swing. Both are kept when the
                // groove changes, so going away and coming back finds
                // them where they were.
                selected:
                    style.withFigure(null).withSwing(null) ==
                    BandStyle.of(feel),
                onSelected: (_) => controller.setStyle(
                  BandStyle.of(feel)
                      .withFigure(style.figure)
                      .withSwing(style.swing),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _BandPart<Feel>(
          label: 'Drums',
          value: style.drums,
          options: Feel.values,
          name: (feel) => feel.label,
          onPick: (feel) => controller.setStyle(
            BandStyle(
              drums: feel,
              bass: style.bass,
              piano: style.piano,
              figure: style.figure,
              swing: style.swing,
            ),
          ),
        ),
        // A groove whose figure takes a bar of four, in a bar that is
        // not four: the band hands over to one that fits, and says so.
        // Hearing a calypso chopped into six eight with no explanation
        // is how this was found in the first place.
        if (!style.drums.suits(controller.meter))
          Padding(
            key: const ValueKey('stands-in'),
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              '${style.drums.label} is a figure for a bar of four. In '
              '${controller.meter.label} the band plays '
              '${style.drums.standIn(controller.meter).label}.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        // A kit that plays nothing looks like one that is broken, so it
        // says why. Picking any other groove brings the drummer back.
        if (!style.drums.hasDrums)
          Padding(
            key: const ValueKey('no-drummer'),
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              'No drummer: the guitar\'s chop is the time.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        _BandPart<BassStyle>(
          label: 'Bass',
          value: style.bass,
          options: BassStyle.values,
          name: (bass) => bass.label,
          onPick: (bass) => controller.setStyle(
            BandStyle(
              drums: style.drums,
              bass: bass,
              piano: style.piano,
              figure: style.figure,
              swing: style.swing,
            ),
          ),
        ),
        _BandPart<PianoStyle>(
          label: 'Comping',
          value: style.piano,
          options: PianoStyle.values,
          name: (piano) => piano.label,
          onPick: (piano) => controller.setStyle(
            BandStyle(
              drums: style.drums,
              bass: style.bass,
              piano: piano,
              figure: style.figure,
              swing: style.swing,
            ),
          ),
        ),
        // Every groove, now that the swing reaches every groove. It used
        // to be here only for the swing feel, which was right when the
        // value went nowhere else: a shuffle was pinned to the triplet
        // and an even feel ignored it, so the slider would have been a
        // control that did nothing. All six lean now, each from its own
        // resting place, so all six have one.
        _BandSwing(controller: controller, style: style),
        // Only where it would do anything. Held chords and the calypso
        // strum have rhythms of their own, and the guitar borrows these
        // figures in swing and nowhere else.
        if (figuresApply(style.piano, controller.settings.comping))
          _BandPart<CompFigure?>(
            label: 'Figure',
            value: style.figure,
            options: const [null, ...CompFigure.values],
            name: (figure) => figure?.label ?? 'As it comes',
            onPick: (figure) => controller.setStyle(style.withFigure(figure)),
          ),
        if (figuresApply(style.piano, controller.settings.comping) &&
            style.figure != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${strikeCount(style.figure!)} '
              '${strikeCount(style.figure!) == 1 ? 'chord' : 'chords'}, '
              '${whereItLands(style.figure!, 0.5)}, in every bar, with any '
              'change it misses caught on its own beat. A comper would '
              'not: put it back to As it comes for a band that chooses bar '
              'by bar. Learn has what each one is for.',
              key: const ValueKey('about-band-figure'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// One of the three: a label, and what that part of the band is playing.
class _BandPart<T> extends StatelessWidget {
  const _BandPart({
    required this.label,
    required this.value,
    required this.options,
    required this.name,
    required this.onPick,
  });

  final String label;
  final T value;
  final List<T> options;
  final String Function(T) name;
  final ValueChanged<T> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Expanded(
            child: DropdownButtonFormField<T>(
              key: ValueKey('band-$label'),
              initialValue: value,
              isDense: true,
              // "Straight comping" is wider than the room beside its
              // label; without this the button lays itself out at whatever
              // the longest name wants and runs off the sheet.
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
              items: [
                for (final option in options)
                  DropdownMenuItem(
                    value: option,
                    child: Text(name(option), overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (picked) {
                // Where the choice can be nothing, as the comping figure
                // can, nothing is one of the answers rather than the menu
                // being waved away.
                if (picked != null || null is T) onPick(picked as T);
              },
            ),
          ),
        ],
      ),
    );
  }
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
      Instrument.imported => Icons.file_open_outlined,
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
            heading('Trading'),
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
                    : 'You take ${a.trading.bars}, whoever answers takes '
                          '${a.trading.bars}, all the way round, '
                          'except on the head.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (a.trading != Trading.off) ...[
              heading('Who Answers'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final who in TradeWith.values)
                    ChoiceChip(
                      key: ValueKey('trade-with-${who.name}'),
                      label: Text(who.label),
                      showCheckmark: false,
                      selected: a.tradeWith == who,
                      onSelected: (_) =>
                          controller.setArrangement(a.copyWith(tradeWith: who)),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  a.tradeWith == TradeWith.drums
                      ? 'The drummer fills the bars you are not playing.'
                      : 'Nobody fills them: the time keeps going and the '
                            'four bars are yours to keep your place in.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
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
                    : 'Nobody plays it but you; the band comes back '
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
                        'written out as a file: a track has to end.'
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

/// "1:04": how long an exported track will run.
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

/// The practice record: what you have actually done at this tune.
///
/// The app was already working all of this out and throwing it away. Kept,
/// it answers the only question that matters between sessions: am I
/// getting anywhere, and what do I play next.
void showPracticeRecord(BuildContext context, PracticeController controller) {
  if (controller.library == null) return;
  practiceSheet(
    context,
    (context) => ListenableBuilder(
      listenable: Listenable.merge([controller.library, controller]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final quiet = theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        );
        final runs = controller.runs;
        final graded = runs.where((run) => run.isGraded).toList();
        final best = bestCleanTempo(runs);
        final next = controller.nextTempo;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Practice Record', style: theme.textTheme.titleLarge),
            Text(
              'Every run at this tune, how fast, and how it went. The '
              'marked ones are the runs the microphone was on for.',
              style: quiet,
            ),
            const SizedBox(height: 12),
            if (runs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Nothing yet. Play the tune and it starts keeping count; '
                  'switch the microphone on and it marks the changes too.',
                  key: const ValueKey('record-empty'),
                  style: theme.textTheme.bodyMedium,
                ),
              )
            else ...[
              // What to do next, which is the whole point of keeping it.
              if (next != null)
                Card(
                  key: const ValueKey('record-move-up'),
                  color: theme.colorScheme.tertiaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$runsToMoveUp clean runs at ${controller.tempo}. '
                            'Time to try $next.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onTertiaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          key: const ValueKey('record-take-it-up'),
                          onPressed: () {
                            controller.setTempo(next);
                            Navigator.of(context).pop();
                          },
                          child: Text('$next'),
                        ),
                      ],
                    ),
                  ),
                ),
              _RecordLine(
                'Last played',
                howLongAgo(runs.first.at),
                key: const ValueKey('record-last'),
              ),
              _RecordLine('Runs', '${runs.length}'),
              if (best != null)
                _RecordLine(
                  'Best clean tempo',
                  '$best BPM',
                  key: const ValueKey('record-best'),
                ),
              if (graded.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('By Tempo', style: theme.textTheme.titleSmall),
                Text(
                  'Only the marked runs: a run nobody was listening to is '
                  'not a verdict on anything.',
                  style: quiet,
                ),
                const SizedBox(height: 6),
                for (final row in byTempo(runs))
                  _RecordLine(
                    '${row.tempo} BPM',
                    '${row.clean} of ${row.runs} clean',
                  ),
              ],
              const SizedBox(height: 16),
              Text('Lately', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              for (final run in runs.take(8))
                _RecordLine(
                  '${howLongAgo(run.at)} · ${run.tempo} BPM',
                  run.asked == 0
                      ? 'not marked'
                      : '${run.hits} of ${run.asked}'
                            '${run.isClean ? ' ✓' : ''}',
                ),
              const SizedBox(height: 12),
              TextButton(
                key: const ValueKey('record-clear'),
                onPressed: () async {
                  final sheet = Navigator.of(context);
                  final sure = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Forget This Record?'),
                      content: const Text(
                        'Every run at this tune goes, and it cannot be got '
                        'back. The tune itself is untouched.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Keep It'),
                        ),
                        FilledButton(
                          key: const ValueKey('record-clear-confirm'),
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Forget It'),
                        ),
                      ],
                    ),
                  );
                  if (sure ?? false) {
                    await controller.clearRuns();
                    sheet.pop();
                  }
                },
                child: const Text('Forget This Record'),
              ),
            ],
          ],
        );
      },
    ),
  );
}

/// One line of the record: what it is on the left, the number on the right.
class _RecordLine extends StatelessWidget {
  const _RecordLine(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          const SizedBox(width: 12),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
