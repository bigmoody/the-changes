// Writing a MIDI file: the band's own playing, as notes, for a DAW.
//
// This is the mirror of midi_file.dart, which reads one. What goes out is
// what the band would play if you pressed play: the same bass line, the
// same comping, the same drums, at the tempo and in the key on the chart,
// with the swing where the band puts it. The parts come from the same
// code the speakers hear, so the file is the performance rather than a
// description of one.
//
// Three tracks and a conductor: the piano on channel 1, the bass on 2 and
// the drums on channel 10, which is where every instrument expects to find
// them. The drums are written in General MIDI numbering (36 kick, 38
// snare, 42 hi-hat, 51 ride), so a stock kit in any DAW plays them as
// drums rather than as a tune.
//
// It starts with a bar of count-in, as the band does.

import 'dart:math' as math;
import 'dart:typed_data';

import '../audio/drum_patterns.dart';
import '../audio/piano_comping.dart';
import '../audio/walking_bass.dart';
import 'meter.dart';
import 'swing.dart';
import 'tune.dart';

/// Ticks to a quarter note. 480 divides by 2, 3, 4 and 5, so swung
/// eighths, triplets and sixteenths all land on whole numbers.
const _ticksPerQuarter = 480;

/// Ticks to one of the band's beats. A beat is a quarter note in simple
/// time and a dotted quarter in compound, which is where the app's beat
/// and the file's quarter part company: everything inside is counted in
/// beats, and a DAW counts in quarters.
int _ticksPerBeatIn(Meter meter) =>
    meter.compound ? _ticksPerQuarter * 3 ~/ 2 : _ticksPerQuarter;

const _pianoChannel = 0;
const _bassChannel = 1;
const _drumChannel = 9;

/// [tune] as a MIDI file: [choruses] times through the form, after a bar
/// of count-in.
Uint8List midiFor(
  Tune tune, {
  int? tempo,
  int choruses = 1,
  int countInBars = 1,
  int seed = 0,
}) {
  final beatsPerMinute = tempo ?? tune.defaultTempo;
  final beatsPerBar = tune.beatsPerBar;
  // The same stand-in the band makes when a groove has no figure for
  // the bar: a file of the band is a file of what the band plays.
  final style = tune.style.inMeter(tune.meter);
  final swing = tune.meter.compound
      ? tripletSwing
      : style.drums.swingBy(beatsPerMinute);
  final random = math.Random(seed);
  // Everything is written from the top of the count-in.
  final offset = (countInBars * beatsPerBar).toDouble();

  final tracks = <Uint8List>[
    _conductor(tune, beatsPerMinute),
    _piano(
      tune,
      style: style,
      swing: swing,
      choruses: choruses,
      offset: offset,
      seed: seed,
    ),
    _bass(
      tune,
      style: style,
      swing: swing,
      choruses: choruses,
      offset: offset,
      random: random,
    ),
    _drums(
      tune,
      style: style,
      swing: swing,
      choruses: choruses,
      offset: offset,
      countInBars: countInBars,
      random: random,
    ),
  ];

  final out = BytesBuilder()
    ..add(_ascii('MThd'))
    ..add(_int32(6))
    ..add(_int16(1))
    ..add(_int16(tracks.length))
    ..add(_int16(_ticksPerQuarter));
  for (final track in tracks) {
    out
      ..add(_ascii('MTrk'))
      ..add(_int32(track.length))
      ..add(track);
  }
  return out.takeBytes();
}

/// The file name a tune is saved under.
String midiFileName(String title) {
  final name = title
      .replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return '${name.isEmpty ? 'Chart' : name}.mid';
}

/// An event waiting to be written: when, and what.
typedef _Event = ({int tick, List<int> bytes, int order});

/// The tempo and the time signature, which a DAW reads before anything
/// else.
Uint8List _conductor(Tune tune, int tempo) {
  final meter = tune.meter;
  // A DAW reads the denominator as a power of two and the tempo as
  // microseconds to a quarter note, neither of which is what the app
  // counts in compound time: the tempo on a 6/8 chart is its dotted
  // quarters, which is a quarter and a half of them.
  final denominator = meter.unit == 8 ? 3 : 2;
  final clocksPerClick = meter.compound ? 36 : 24;
  final perQuarter = tune.meter.compound ? tempo * 1.5 : tempo.toDouble();
  final events = <_Event>[
    (tick: 0, order: 0, bytes: _meta(0x03, _ascii(tune.title))),
    (
      tick: 0,
      order: 1,
      bytes: _meta(0x58, [meter.beats, denominator, clocksPerClick, 8]),
    ),
    (
      tick: 0,
      order: 2,
      bytes: _meta(0x51, _int24((60000000 / perQuarter).round())),
    ),
  ];
  return _track(events);
}

Uint8List _piano(
  Tune tune, {
  required BandStyle style,
  required double swing,
  required int choruses,
  required double offset,
  required int seed,
}) {
  final events = <_Event>[
    (tick: 0, order: 0, bytes: _meta(0x03, _ascii('Piano'))),
    (tick: 0, order: 1, bytes: [0xC0 | _pianoChannel, 0]),
  ];
  final comper = Comper(math.Random(seed + 11));
  final slots = tune.slots;
  final beatsPerBar = tune.beatsPerBar;
  var order = 2;
  for (var chorus = 0; chorus < choruses; chorus++) {
    for (var index = 0; index < slots.length; index++) {
      final slot = slots[index];
      final next = slots[(index + 1) % slots.length].chord;
      final hits = comper.comp(
        slot.chord,
        slot.beats,
        style.piano.feel,
        next: next,
        held: style.piano == PianoStyle.held,
        calypso: style.piano == PianoStyle.calypso,
        pompe: style.piano == PianoStyle.laPompe,
        figure: style.figure,
        beatsPerBar: beatsPerBar,
        swing: swing,
        beatInBar: (slot.startBeat % beatsPerBar).toDouble(),
        startsSection: tune.sections.containsKey(slot.startBeat ~/ beatsPerBar),
        intoSection: tune.sections.containsKey(slot.endBeat ~/ beatsPerBar),
        bar: slot.startBeat ~/ beatsPerBar,
      );
      for (final hit in hits) {
        final at =
            offset + chorus * tune.totalBeats + slot.startBeat + hit.beat;
        for (final note in hit.notes) {
          order = _note(
            events,
            channel: _pianoChannel,
            pitch: note,
            beat: at,
            beats: hit.length,
            velocity: hit.velocity,
            order: order,
            ticks: _ticksPerBeatIn(tune.meter),
          );
        }
      }
    }
  }
  return _track(events);
}

Uint8List _bass(
  Tune tune, {
  required BandStyle style,
  required double swing,
  required int choruses,
  required double offset,
  required math.Random random,
}) {
  final events = <_Event>[
    (tick: 0, order: 0, bytes: _meta(0x03, _ascii('Bass'))),
    // Acoustic bass, which is what the band is playing.
    (tick: 0, order: 1, bytes: [0xC0 | _bassChannel, 32]),
  ];
  final walk = switch (style.bass) {
    BassStyle.walking => walkingBassLine,
    BassStyle.twoFeel => twoFeelBassLine,
    BassStyle.bossa => bossaBassLine,
    BassStyle.funk => funkBassLine,
    BassStyle.calypso => calypsoBassLine,
  };
  final line = walk(
    [for (final slot in tune.slots) (slot.chord, slot.beats)],
    choruses: choruses,
    random: random,
    swing: swing,
    beatsPerBar: tune.beatsPerBar,
  );
  var order = 2;
  for (final note in line) {
    order = _note(
      events,
      channel: _bassChannel,
      pitch: note.pitch,
      beat: offset + note.beat,
      beats: note.length,
      velocity: note.velocity,
      order: order,
      ticks: _ticksPerBeatIn(tune.meter),
    );
  }
  return _track(events);
}

Uint8List _drums(
  Tune tune, {
  required BandStyle style,
  required double swing,
  required int choruses,
  required double offset,
  required int countInBars,
  required math.Random random,
}) {
  final events = <_Event>[
    (tick: 0, order: 0, bytes: _meta(0x03, _ascii('Drums'))),
  ];
  final beatsPerBar = tune.beatsPerBar;
  var order = 1;
  // The count-in, as the band counts it: a stick on every beat, the first
  // of the bar harder.
  for (var beat = 0; beat < countInBars * beatsPerBar; beat++) {
    order = _note(
      events,
      channel: _drumChannel,
      pitch: 37,
      beat: beat.toDouble(),
      beats: 0.25,
      velocity: beat % beatsPerBar == 0 ? 0.9 : 0.6,
      order: order,
      ticks: _ticksPerBeatIn(tune.meter),
    );
  }
  for (var chorus = 0; chorus < choruses; chorus++) {
    for (var bar = 0; bar < tune.barCount; bar++) {
      for (final hit in drumBar(
        feel: style.drums,
        bar: chorus * tune.barCount + bar,
        beatsPerBar: beatsPerBar,
        random: random,
        swing: swing,
      )) {
        order = _note(
          events,
          channel: _drumChannel,
          pitch: _generalMidi[hit.drum]!,
          beat:
              offset + chorus * tune.totalBeats + bar * beatsPerBar + hit.beat,
          // A drum is struck rather than held: the length is only so a
          // DAW has something to draw.
          beats: 0.25,
          velocity: hit.velocity,
          order: order,
          ticks: _ticksPerBeatIn(tune.meter),
        );
      }
    }
  }
  return _track(events);
}

/// General MIDI's drum numbers. The brush swirl has no number of its own
/// anywhere, so it is written where it is played: on the snare head,
/// softly.
const _generalMidi = {
  Drum.ride: 51,
  Drum.hiHatPedal: 44,
  Drum.hiHatClosed: 42,
  Drum.hiHatOpen: 46,
  Drum.kick: 36,
  Drum.snare: 38,
  Drum.crossStick: 37,
  Drum.cowbell: 56,
  Drum.tomHigh: 48,
  Drum.tomLow: 45,
  Drum.swirl: 38,
};

/// Adds a note on and its note off, and returns the next order number.
///
/// [order] keeps events written at the same tick in the order they were
/// made, so a note off never overtakes the note on it belongs to.
int _note(
  List<_Event> events, {
  required int channel,
  required int pitch,
  required double beat,
  required double beats,
  required double velocity,
  required int order,
  required int ticks,
}) {
  if (pitch < 0 || pitch > 127) return order;
  final on = math.max(0, (beat * ticks).round());
  final off = math.max(on + 1, ((beat + beats) * ticks).round());
  final strength = (velocity * 127).round().clamp(1, 127);
  events
    ..add((tick: on, order: order, bytes: [0x90 | channel, pitch, strength]))
    ..add((tick: off, order: order + 1, bytes: [0x80 | channel, pitch, 0]));
  return order + 2;
}

/// The events as a track chunk: in time order, each behind the gap since
/// the one before, and the end-of-track mark every file must carry.
Uint8List _track(List<_Event> events) {
  final sorted = [...events]
    ..sort((a, b) {
      final byTick = a.tick.compareTo(b.tick);
      return byTick != 0 ? byTick : a.order.compareTo(b.order);
    });
  final out = BytesBuilder();
  var last = 0;
  for (final event in sorted) {
    out
      ..add(_variable(event.tick - last))
      ..add(event.bytes);
    last = event.tick;
  }
  out
    ..add(_variable(0))
    ..add(_meta(0x2F, const []));
  return out.takeBytes();
}

List<int> _meta(int kind, List<int> body) => [
  0xFF,
  kind,
  ..._variable(body.length),
  ...body,
];

/// A number as MIDI writes one: seven bits at a time, with the top bit set
/// on every byte but the last.
List<int> _variable(int value) {
  var left = value < 0 ? 0 : value;
  final bytes = <int>[left & 0x7F];
  left >>= 7;
  while (left > 0) {
    bytes.insert(0, (left & 0x7F) | 0x80);
    left >>= 7;
  }
  return bytes;
}

List<int> _ascii(String text) => [
  for (final unit in text.codeUnits) unit < 128 ? unit : 0x3F,
];

List<int> _int16(int value) => [(value >> 8) & 0xFF, value & 0xFF];

List<int> _int24(int value) => [
  (value >> 16) & 0xFF,
  (value >> 8) & 0xFF,
  value & 0xFF,
];

List<int> _int32(int value) => [
  (value >> 24) & 0xFF,
  (value >> 16) & 0xFF,
  (value >> 8) & 0xFF,
  value & 0xFF,
];
