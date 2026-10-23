import 'dart:async';

import '../music/meter.dart';

import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../audio/sample_bank.dart';

import '../audio/arpeggios.dart';
import '../audio/backing_synth.dart';
import '../audio/felt_beat.dart';
import '../audio/now_playing_centre.dart';
import '../audio/practice_player.dart';
import '../audio/export_track.dart';
import '../audio/take_recorder.dart';
import '../audio/tuner_listener.dart';
import '../library/library_store.dart';
import '../music/arrangement.dart';
import '../music/chord_drill.dart';
import '../music/imported_part.dart';
import '../audio/wav_file.dart';
import '../music/loop_range.dart';
import '../music/recorded_take.dart';
import '../music/tune.dart';
import '../music/what_its_doing.dart';
import '../music/tuning.dart';
import '../settings/app_settings.dart';
import 'hiding_the_chart.dart';
import 'play_check.dart';
import 'part_store.dart';
import 'practice_record.dart';
import '../settings/progression_store.dart';
import 'recording_store.dart';
import 'take_store.dart';

/// Holds everything the practice screen shows and reacts to taps.
///
/// It's a [ChangeNotifier]: whenever something changes it calls
/// `notifyListeners()`, and the screen redraws.
class PracticeController extends ChangeNotifier {
  PracticeController({
    required Tune tune,
    required this.player,
    required this.settings,
    this.takes,
    this.partStore,
    this.recordingStore,
    this.progressions,
    this.library,
    TuneRef? ref,
    TakeRecorder? recorder,
    TunerListener? listener,
    this.nowPlaying,
  }) : // A private field can't be a named parameter, so these are assigned
       // rather than taken as initialising formals.
       // ignore: prefer_initializing_formals
       _recorder = recorder,
       _madeListener = listener,
       originalTune = tune,
       _ref = ref,
       _style = ref == null ? null : library?.styleFor(ref),
       _meter = ref == null ? null : library?.meterFor(ref),
       _tune = _asChosen(tune, ref, library),
       _chart = _asChosen(
         tune,
         ref,
         library,
       ).transposed(settings.instrument.semitones),
       // The tune as the player keeps it, which is the one with the
       // beats in it: a tune they count in six eight has half as many
       // of them in a bar as the one written in four.
       _loop = LoopRange.wholeTune(_asChosen(tune, ref, library)),
       // Where you left off, if you have been here before. The written
       // tempo is what the tune is played at; this is what *you* play it
       // at, which after a week of work is rarely the same number.
       //
       _tempo =
           (ref == null
               ? null
               : tempoToOpenAt(library?.runsFor(ref) ?? const [])) ??
           tune.defaultTempo {
    settings.addListener(_updateChart);
    recordingStore?.addListener(_recordingsChanged);
    _imported = partStore?.forTune(_ref);
    _applyMix();
  }

  static const minTempo = 40;
  static const maxTempo = 320;

  /// The tune in its written key.
  final Tune originalTune;

  /// Where the player's choice of how to play this tune is kept, if the
  /// screen was given one.
  final LibraryStore? library;
  final TuneRef? _ref;

  /// How this tune is named in the library, when it is one the app keeps
  /// anything about. Null for the Learn screens, which build a controller
  /// for a chart that is not in the library at all.
  TuneRef? get ref => _ref;

  /// The tune as the player keeps it: in the meter they count it in and
  /// played the way they have chosen, before any transposition.
  static Tune _asChosen(Tune tune, TuneRef? ref, LibraryStore? library) {
    if (ref == null || library == null) return tune;
    return tune
        .inMeter(library.meterFor(ref) ?? tune.meter)
        .withStyle(library.styleFor(ref) ?? tune.style);
  }

  /// The way the player has chosen to have it played, over the way it was
  /// written. Null means as written.
  BandStyle? _style;

  /// The meter the player counts it in, over the one it was written in.
  /// Null means as written.
  Meter? _meter;

  /// What it is counted in now: the player's choice, or the tune's own.
  Meter get meter => _meter ?? originalTune.meter;

  /// Whether that is something the player chose rather than what the
  /// tune was written in.
  bool get meterIsChosen => _meter != null;

  /// The tune before any transposition, counted the way the player
  /// counts it. Everything that rebuilds the chart or the band starts
  /// here, so the meter is never left behind by a key change.
  Tune get _source => originalTune.inMeter(meter);

  /// Counts it in [meter] from now on, and remembers it for next time. A
  /// null [meter] puts it back to the one the tune was written in.
  ///
  /// The loop goes back to the whole tune: loops are counted in beats,
  /// and a bar is not the same number of beats as it was.
  void setMeter(Meter? meter) {
    if (meter == _meter) return;
    _meter = meter;
    final ref = _ref;
    if (ref != null) library?.setMeter(ref, meter);
    _tune = _source.transposed(_semitones).withStyle(style);
    _loop = LoopRange.wholeTune(_tune);
    _updateChart();
    notifyListeners();
    _restartIfPlaying(delay: Duration.zero);
  }

  /// How the band is playing it: the player's choice, or the tune's own.
  BandStyle get style => _style ?? originalTune.style;

  /// Whether that is something the player chose rather than how the tune
  /// was written.
  bool get styleIsChosen => _style != null;

  /// Has the band play it another way, and remembers it for next time. A
  /// null [style] puts it back to the way the tune was written.
  void setStyle(BandStyle? style) {
    if (style == _style) return;
    _style = style;
    final ref = _ref;
    if (ref != null) library?.setStyle(ref, style);
    _tune = _source.transposed(_semitones).withStyle(this.style);
    // A groove carries its tempo with it: a samba at 90 is not a slow
    // samba. The tempo only moves when it has to, so a medium swing that
    // becomes a shuffle stays where it was.
    _tempo = this.style.drums.tempoFor(_tempo).clamp(minTempo, maxTempo);
    notifyListeners();
    _restartIfPlaying(delay: Duration.zero);
  }

  /// Where the "and" falls for this tune, or null to follow the tempo.
  double? get swing => style.swing;

  /// Sets it, and keeps it with the tune the way the feel is kept.
  ///
  /// Its own setter rather than going through [setStyle] for the wait: a
  /// swing is set by dragging, and restarting the band on every pixel of
  /// a drag would be unusable.
  void setSwing(double? swing) {
    if (swing == style.swing) return;
    final next = style.withSwing(swing);
    _style = next;
    final ref = _ref;
    if (ref != null) library?.setStyle(ref, next);
    _tune = _source.transposed(_semitones).withStyle(next);
    notifyListeners();
    _restartIfPlaying(delay: const Duration(milliseconds: 400));
  }

  /// The tune in the key currently chosen, at concert pitch. The band plays
  /// this.
  Tune get tune => _tune;
  Tune _tune;

  /// The same tune written for the player's instrument (see [ChartInstrument]).
  /// The screen shows this. Bars and beats line up exactly with [tune].
  Tune get chart => _chart;
  Tune _chart;
  int _semitones = 0;
  final PracticePlayer player;

  /// The phone's own transport, where there is one.
  ///
  /// Taken here so a test can watch it, and otherwise the player's own,
  /// which is where the running app keeps it. Null in a test that asks
  /// for neither: nothing here should need a lock screen to be stood up.
  final NowPlayingCentre? nowPlaying;

  NowPlayingCentre? get _card => nowPlaying ?? player.nowPlaying;
  final AppSettings settings;

  /// Where recordings of you are kept. Null when there's nowhere to put
  /// them, and then there's no recording.
  final TakeStore? takes;

  /// Where an imported part is kept between visits. Null where a
  /// controller is built without one: the Learn pages, and tests.
  final PartStore? partStore;

  /// Where recordings of real players imported for this tune are kept.
  final RecordingStore? recordingStore;

  /// The player's own progressions, so a take imported against one of
  /// them can be matched to other tunes. Without it only the book's
  /// standards are looked at, which is what tests get.
  final ProgressionStore? progressions;
  TakeRecorder? _recorder;
  TakeRecorder get _tape => _recorder ??= TakeRecorder();

  LoopRange _loop;
  int _tempo;
  int _countInBars = 1;
  bool _isPlaying = false;
  bool _isPaused = false;
  bool _isPreparing = false;
  int? _currentBeat;
  int? _countInBeat;
  int? _chorus;
  bool _finishing = false;

  /// Made the first time the checking is switched on, never before: asking
  /// for a microphone opens a plugin, and most of the time nobody wants one.
  TunerListener? _madeListener;
  TunerListener get _listener => _madeListener ??= TunerListener.forChecking();

  PlayCheck? _check;
  var _listenState = Listening.off;
  HeardNote? _heard;
  Timer? _finishTimer;
  Arrangement _arrangement = Arrangement.keepGoing;
  String? _error;
  Timer? _ticker;
  Timer? _restartTimer;
  final _tapTimes = <DateTime>[];
  final _random = math.Random();
  var _lastSeed = 0;
  final _volumes = {
    for (final instrument in Instrument.values) instrument: 1.0,
  };
  final _muted = <Instrument>{};
  final _soloed = <Instrument>{};

  /// The loop shown on screen: the one being dragged out, if any.
  LoopRange get loop => _dragLoop ?? _loop;
  int get tempo => _tempo;

  /// How many bars of clicks before the band comes in, nought for none.
  int get countInBars => _countInBars;

  /// Whether there is one at all.
  bool get countIn => _countInBars > 0;

  /// What a count-in can be: none, a bar, or the two-bar count-off, which
  /// in four is the eight beats somebody counts a band in with.
  static const countInChoices = [0, 1, 2];

  /// True from Play until Stop, including while paused.
  bool get isPlaying => _isPlaying;

  /// Holding its place: Play carries on from here rather than the top.
  bool get isPaused => _isPaused;
  bool get isPreparing => _isPreparing;
  int? get currentBeat => _currentBeat;

  int? get countInBeat => _countInBeat;

  /// Which time round the form is playing (1-based), or null when stopped
  /// or still counting in.
  int? get chorus => _chorus == null ? null : _chorus! + 1;

  /// What the band is doing on this chorus (the melody, trading, who's
  /// laid out) or null when nothing is playing.
  ChorusPlan? get chorusPlan =>
      _chorus == null ? null : _arrangement.planFor(_chorus!);

  /// How the band plays the form: choruses, heads, trading, who lays out.
  Arrangement get arrangement => _arrangement;

  /// What the band is playing at right now: the tempo you set, plus whatever
  /// a ramp has added by this time round the form.
  int get currentTempo => _arrangement.ramp.tempoAt(_chorus ?? 0, _tempo);

  /// True once the last chorus has been played and the band is ringing off.
  bool get isFinishing => _finishing;

  void setArrangement(Arrangement value) {
    if (value == _arrangement) return;
    _arrangement = value;
    notifyListeners();
    // A different arrangement is a different performance: it starts again
    // from the top, chorus one.
    _restartIfPlaying(delay: const Duration(milliseconds: 250));
  }

  String? get error => _error;
  bool get mixWithOthers => player.mixWithOthers;

  ChordSlot? get currentSlot =>
      _currentBeat == null ? null : chart.slotAtBeat(_currentBeat!);

  /// The chord being played, or the loop's first chord when stopped.
  ChordSlot get shownSlot => currentSlot ?? loop.slotsIn(chart).first;

  /// What the chord on screen is doing in this tune, or null when there
  /// is nothing certain to say about it.
  ///
  /// Read against the whole chart rather than the loop: a ii-V that
  /// straddles the end of a four-bar loop is still a ii-V, and a player
  /// looping those four bars is the one who most needs telling so.
  ChordMeaning? get shownChordDoing {
    final slots = chart.slots;
    final shown = shownSlot;
    final at = slots.indexWhere((s) => s.startBeat == shown.startBeat);
    if (at < 0) return null;
    return whatItIsDoing([for (final slot in slots) slot.chord], at);
  }

  /// The next *change* after [shownSlot], skipping bars that just repeat
  /// the same chord, and coming round to the start of the loop at its end.
  /// It's what an improviser needs to be looking at next.
  ChordSlot get nextSlot {
    final slots = loop.slotsIn(chart);
    final shown = shownSlot;
    final index = slots.indexWhere((s) => s.startBeat == shown.startBeat);
    for (var step = 1; step < slots.length; step++) {
      final slot = slots[(index + step) % slots.length];
      if (slot.chord.display != shown.chord.display) return slot;
    }
    return slots[(index + 1) % slots.length]; // one chord all the way round
  }

  // ── Choosing what to loop ──────────────────────────────────────────────

  void loopBar(int barIndex) =>
      _setLoop(LoopRange.bars(tune, barIndex, barIndex));

  void extendLoopToBar(int barIndex) =>
      _setLoop(_loop.extendedToBar(tune, barIndex));

  void loopChord(ChordSlot slot) => _setLoop(LoopRange.slot(slot));

  // Dragging across bars selects them. The highlight follows the finger, but
  // the band only restarts once the finger lifts, so it doesn't stutter.
  int? _dragAnchor;
  LoopRange? _dragLoop;

  void startLoopDrag(int barIndex) {
    _dragAnchor = barIndex;
    _dragLoop = LoopRange.bars(tune, barIndex, barIndex);
    notifyListeners();
  }

  void updateLoopDrag(int barIndex) {
    final anchor = _dragAnchor;
    if (anchor == null) return;
    final selection = LoopRange.bars(tune, anchor, barIndex);
    if (selection == _dragLoop) return;
    _dragLoop = selection;
    notifyListeners();
  }

  void endLoopDrag() {
    final selection = _dragLoop;
    _dragAnchor = null;
    _dragLoop = null;
    if (selection == null || selection == _loop) {
      notifyListeners();
    } else {
      _setLoop(selection);
    }
  }

  void loopWholeTune() => _setLoop(LoopRange.wholeTune(tune));

  void _setLoop(LoopRange loop) {
    if (loop == _loop) return;
    _loop = loop;
    // A different stretch of the tune is a different plan, and a pick-up
    // into the old one would land somewhere you didn't choose.
    if (!loop.overlapsBar(tune, startBar ?? -1)) _startBeat = null;
    notifyListeners();
    _restartIfPlaying(delay: Duration.zero);
  }

  // ── Coming in part-way through ─────────────────────────────────────────

  /// Where the first time through starts, as a beat of the tune, or null to
  /// start at the top of the loop.
  int? _startBeat;

  /// The bar the band comes in on, or null when it starts at the top.
  int? get startBar =>
      _startBeat == null ? null : _startBeat! ~/ tune.beatsPerBar;

  /// How far into the form the band comes in, in beats. Nought is the top.
  int get pickUpBeats => (_startBeat ?? _loop.startBeat) - _loop.startBeat;

  /// Takes it from [barIndex]: the first time through starts there and runs
  /// to the end of the form, and after that it comes round to the top and
  /// plays whole, the way "take it from the bridge" means it.
  ///
  /// Asking for the bar it already starts on puts it back to the top.
  void startFromBar(int barIndex) {
    if (!_loop.overlapsBar(tune, barIndex)) return;
    final beat = tune.barStartBeat(barIndex);
    _startBeat = (beat == _startBeat || beat == _loop.startBeat) ? null : beat;
    notifyListeners();
    _restartIfPlaying(delay: Duration.zero);
  }

  void startFromTheTop() {
    if (_startBeat == null) return;
    _startBeat = null;
    notifyListeners();
    _restartIfPlaying(delay: Duration.zero);
  }

  // ── Key ────────────────────────────────────────────────────────────────

  /// How many semitones above the written key we are (0–11).
  int get semitones => _semitones;

  /// Moves the chart and the backing band into a new key. Loops are counted
  /// in beats, so the looped section stays the same.
  void transpose(int semitones) {
    final normalised = semitones % 12;
    if (normalised == _semitones) return;
    _semitones = normalised;
    _tune = _source.transposed(normalised).withStyle(style);
    _updateChart();
    _restartIfPlaying(delay: Duration.zero);
  }

  /// Rewrites the displayed chart after a key or instrument change.
  void _updateChart() {
    _chart = _source.transposed(_semitones + settings.instrument.semitones);
    // Turning the beat on or off changes how often the clock is read, and
    // somebody who turns it on while the band is going should feel it on
    // the next beat rather than the next tune.
    final wanted = settings.feelTheBeat == FeelTheBeat.off ? 30 : 10;
    // Only while the band is actually going: the ticker is cancelled on
    // stop but not thrown away, so it being non-null proves nothing.
    if (_isPlaying && _tickEvery != wanted) _startTicker();
    // A drum's level is baked into the rendered stem rather than set on a
    // playing one, so the only way to hear a change is to render again.
    // Compared against what was last rendered rather than restarting on
    // every settings change, most of which the band does not care about.
    final levels = settings.drumLevels.toJson().toString();
    if (_renderedLevels != null && _renderedLevels != levels) {
      // Enough of a wait that dragging a slider does not re-render on
      // every pixel of it.
      _restartIfPlaying(delay: const Duration(milliseconds: 400));
    }
    _renderedLevels = levels;
    notifyListeners();
  }

  /// The drum levels the band was last built with.
  String? _renderedLevels;

  /// How often the clock is being read, so a change can be noticed.
  int? _tickEvery;

  // ── Tempo ──────────────────────────────────────────────────────────────

  /// What the tune is written at, which is not always where it opens: a
  /// tune you have been working on opens at the tempo you last got it up
  /// to, which is the useful thing and also the thing you sometimes want
  /// to get out of.
  int get writtenTempo => originalTune.defaultTempo;

  /// Whether the tempo has been moved off the written one.
  bool get tempoIsChosen => _tempo != writtenTempo;

  /// Back to the written tempo.
  void resetTempo() => setTempo(writtenTempo);

  void setTempo(int bpm) {
    final clamped = bpm.clamp(minTempo, maxTempo);
    if (clamped == _tempo) return;
    _tempo = clamped;
    notifyListeners();
    // Wait until the slider stops moving before re-rendering.
    _restartIfPlaying(delay: const Duration(milliseconds: 300));
  }

  /// Tap along to set the tempo: averages the gaps between recent taps.
  void tapTempo() {
    final now = DateTime.now();
    if (_tapTimes.isNotEmpty &&
        now.difference(_tapTimes.last) > const Duration(seconds: 2)) {
      _tapTimes.clear();
    }
    _tapTimes.add(now);
    if (_tapTimes.length > 5) _tapTimes.removeAt(0);
    if (_tapTimes.length < 2) return;
    final totalMs = _tapTimes.last.difference(_tapTimes.first).inMilliseconds;
    setTempo((60000 / (totalMs / (_tapTimes.length - 1))).round());
  }

  // ── Options ────────────────────────────────────────────────────────────

  void setCountInBars(int bars) {
    if (bars == _countInBars) return;
    _countInBars = bars;
    notifyListeners();
  }

  /// What a part is called on screen: the chords are "Piano" or "Guitar".
  ///
  /// Piano or Guitar for the chords, which say who is playing them. An
  /// imported sound is "Chords": "Imported Sound" says where it came
  /// from rather than what it plays, and does not fit beside a fader.
  String partName(Instrument part) => part == Instrument.chords
      ? (settings.comping == Comping.imported
            ? part.label
            : settings.comping.label)
      : part.label;

  /// The parts with a mixer channel: the band, plus the arpeggios when
  /// they're on and an imported part when there is one.
  List<Instrument> get parts => [
    for (final part in Instrument.values)
      if (switch (part) {
        Instrument.arpeggio => arpeggios,
        Instrument.imported => _imported != null,
        _ => true,
      })
        part,
  ];

  /// A part read out of a MIDI file, playing alongside the band. Null
  /// until one is imported, which is nearly always.
  ImportedPart? get importedPart => _imported;
  ImportedPart? _imported;

  /// Puts an imported part in, takes it out (with null), or changes which
  /// instrument plays it. The band is rebuilt, because the part is mixed
  /// into it rather than played over the top.
  void setImportedPart(ImportedPart? part) {
    if (identical(part, _imported)) return;
    _imported = part;
    // Kept for next time. Choosing a file, picking a track out of it and
    // nudging it into place is several minutes of work to throw away when
    // the tune closes.
    final store = partStore;
    final ref = _ref;
    if (store != null && ref != null) unawaited(store.set(ref, part));
    // Putting one in means wanting to hear it, the same as the arpeggios.
    if (part != null) _muted.remove(Instrument.imported);
    _applyMix();
    notifyListeners();
    _restartIfPlaying(delay: Duration.zero);
  }

  /// Whether the band adds each chord as a broken chord. Off whenever a tune
  /// is opened: a practice aid to switch on when you want it.
  bool get arpeggios => _arpeggios;
  bool _arpeggios = false;

  /// Adds or removes the arpeggios; the band picks it up straight away.
  void setArpeggios(bool value) {
    if (value == _arpeggios) return;
    _arpeggios = value;
    // Switching them on means wanting to hear them.
    if (value) _muted.remove(Instrument.arpeggio);
    _applyMix();
    _restartIfPlaying(delay: Duration.zero);
  }

  /// Which chord tone the arpeggios start from.
  Future<void> setArpeggioReach(ArpeggioReach value) async {
    if (value == settings.arpeggioReach) return;
    await settings.setArpeggioReach(value);
    notifyListeners();
    _restartIfPlaying(delay: Duration.zero);
  }

  Future<void> setArpeggioRate(ArpeggioRate value) async {
    if (value == settings.arpeggioRate) return;
    await settings.setArpeggioRate(value);
    notifyListeners();
    _restartIfPlaying(delay: Duration.zero);
  }

  Future<void> setArpeggioStart(ArpeggioStart value) async {
    if (value == settings.arpeggioStart) return;
    await settings.setArpeggioStart(value);
    notifyListeners();
    _restartIfPlaying(delay: Duration.zero);
  }

  /// Piano or guitar for the arpeggios.
  Future<void> setArpeggioSound(Comping value) async {
    if (value == settings.arpeggioSound) return;
    await settings.setArpeggioSound(value);
    notifyListeners();
    _restartIfPlaying(delay: Duration.zero);
  }

  /// Piano or guitar on the chords, for every tune; the band picks it up
  /// straight away.
  /// Whether there is an imported bass to choose at all, so the mixer can
  /// leave the row out when there is not.
  bool get hasImportedBass => player.samples?.importedBass != null;

  /// Whether an imported kit has anything in it, so the mixer can leave
  /// the row out when there is not.
  bool get hasImportedDrums => player.samples?.hasImportedDrums ?? false;

  /// The kits worth offering: both of the band's own, and an imported one
  /// only once there is one. A segment for a kit nobody has imported is a
  /// button that can only disappoint.
  ///
  /// A sound already chosen is always offered, so somebody whose imported
  /// kit has not finished loading is not silently moved off it.
  List<DrumSound> get kitChoices => [
    for (final sound in DrumSound.values)
      if (sound != DrumSound.imported ||
          hasImportedDrums ||
          settings.drumSound == sound)
        sound,
  ];

  Future<void> setDrumSound(DrumSound value) async {
    if (value == settings.drumSound) return;
    await settings.setDrumSound(value);
    notifyListeners();
    _restartIfPlaying(delay: Duration.zero);
  }

  Future<void> setBassSound(BassSound value) async {
    if (value == settings.bassSound) return;
    await settings.setBassSound(value);
    notifyListeners();
    _restartIfPlaying(delay: Duration.zero);
  }

  /// A different sound on a part that was already imported: the setting
  /// is the same, so nothing above notices, and the band has to be told
  /// to play it.
  void soundsChanged() {
    notifyListeners();
    _restartIfPlaying(delay: Duration.zero);
  }

  Future<void> setComping(Comping value) async {
    if (value == settings.comping) return;
    await settings.setComping(value);
    notifyListeners();
    _restartIfPlaying(delay: Duration.zero);
  }

  Future<void> setMixWithOthers(bool value) async {
    await settings.setMixWithOthers(value);
    await player.setMixWithOthers(value);
    // The card comes and goes with the switch, mid-run as well as
    // between them: turning the mixing back on while the band plays has
    // to hand the lock screen back to whatever else is sounding.
    await _tellTheSystem();
    notifyListeners();
  }

  /// Puts the Now Playing card up, takes it down, or changes what it
  /// says, to match what the band is actually doing.
  ///
  /// Only when the app has the sound to itself. Mixing, the card belongs
  /// to whatever you are playing along to, and taking it would mean the
  /// pause button on the lock screen stopped pausing them.
  Future<void> _tellTheSystem() async {
    final card = _card;
    if (card == null) return;
    if (!_isPlaying || settings.mixWithOthers) {
      await card.hide();
      return;
    }
    card.onPlay = resume;
    card.onPause = pause;
    card.onToggle = () {
      unawaited(togglePlay());
    };
    card.onStop = () {
      unawaited(stop());
    };
    await card.show(
      title: chart.title,
      // What a sleeve would put the artist on. The two things you would
      // want to know from a pocket: what key it is in and how fast.
      line: '${chart.key} · $currentTempo',
      playing: !_isPaused,
    );
  }

  // ── Mixer ──────────────────────────────────────────────────────────────

  double volumeOf(Instrument instrument) => _volumes[instrument]!;
  bool isMuted(Instrument instrument) => _muted.contains(instrument);
  bool isSoloed(Instrument instrument) => _soloed.contains(instrument);

  /// True when the instrument can actually be heard with the current
  /// mute/solo settings (used to grey out silent channels).
  bool isAudible(Instrument instrument) =>
      !_bandSilent &&
      !isMuted(instrument) &&
      (_soloed.isEmpty || isSoloed(instrument));

  /// True while a take is being played on its own: the band is still
  /// written, because it's what the chart follows, but nothing of it is
  /// heard.
  var _bandSilent = false;

  void setVolume(Instrument instrument, double volume) {
    _volumes[instrument] = volume.clamp(0.0, 1.0);
    _applyMix();
  }

  void toggleMute(Instrument instrument) {
    if (!_muted.remove(instrument)) _muted.add(instrument);
    _applyMix();
  }

  /// Solo plays only the soloed instrument(s), e.g. just the bass.
  void toggleSolo(Instrument instrument) {
    if (!_soloed.remove(instrument)) _soloed.add(instrument);
    _applyMix();
  }

  void resetMix() {
    _volumes.updateAll((_, _) => 1.0);
    _muted.clear();
    _soloed.clear();
    _applyMix();
  }

  /// Everything the mixer sheet changes, put back.
  ///
  /// The levels, the mutes and the solos; the band as the tune is written
  /// (the groove, the bass, the comping, the figure and the swing); the
  /// count-in to a bar and the arpeggios off. And the sounds: the kit
  /// (sticks, not brushes), the upright bass, the piano on the chords and
  /// the arpeggios, the arpeggios as they start out, and a recording
  /// played if there is one. Those follow the player from tune to tune,
  /// and were left alone once for that reason; but a Reset at the top of
  /// the sheet that leaves brushes on is not a reset.
  Future<void> resetSheet() async {
    setStyle(null);
    setCountInBars(1);
    setArpeggios(false);
    setUseRecording(true);
    resetMix();
    await setDrumSound(DrumSound.kit);
    await setBassSound(BassSound.upright);
    await setComping(Comping.piano);
    await setArpeggioSound(Comping.piano);
    await setArpeggioStart(ArpeggioStart.root);
    await setArpeggioRate(ArpeggioRate.eighths);
    await setArpeggioReach(ArpeggioReach.plain);
  }

  /// Sends the effective volume of every instrument to the audio engine.
  /// This happens instantly, without restarting playback.
  void _applyMix() {
    for (final instrument in Instrument.values) {
      player.setVolume(
        instrument,
        isAudible(instrument) ? _volumes[instrument]! : 0,
      );
    }
    notifyListeners();
  }

  // ── Checking what you play ─────────────────────────────────────────────

  /// Whether the microphone is marking what you play against the chart.
  bool get checking => _checking;
  var _checking = false;

  Listening get listenState => _listenState;

  /// The note the microphone heard a moment ago, as written for your
  /// instrument, or null when it hears nothing it can name.
  HeardNote? get heard => _heard;

  /// How you did: the change being played, and the running score.
  PlayCheck? get check => _check;

  /// The last run's marking, kept after Stop so the score can be shown.
  PlayCheck? get lastCheck => _lastCheck;
  PlayCheck? _lastCheck;

  void clearLastCheck() {
    if (_lastCheck == null) return;
    _lastCheck = null;
    notifyListeners();
  }

  /// Turns the checking on or off. It needs a note to aim for, so switching
  /// it on without one picks the 3rd, the one that names the chord.
  Future<void> setChecking(bool value) async {
    if (value == _checking) return;
    _checking = value;
    if (!value) {
      await _stopListening();
      notifyListeners();
      return;
    }
    if (settings.aimFor == null) await settings.setAimFor(DrillTarget.third);
    notifyListeners();
    // Start listening straight away, not when the band does, so you can
    // play a note and see that it's heard before committing to a chorus.
    await _startListening();
  }

  /// How loud the microphone is hearing you (RMS, 0–1).
  double get listenLevel => _madeListener?.level ?? 0;

  /// True when there's barely any sound arriving, a different problem from
  /// hearing plenty but not being able to name a note in it.
  bool get tooQuiet =>
      _listenState == Listening.listening &&
      listenLevel < (_madeListener?.silence ?? 0.004);

  /// When something was last heard clearly, so silence can be reported as
  /// silence rather than as a miss.
  DateTime? _lastNote;

  /// True when the microphone is going but has heard nothing for a while.
  bool get hearingNothing =>
      _listenState == Listening.listening &&
      (_lastNote == null ||
          DateTime.now().difference(_lastNote!) > const Duration(seconds: 3));

  Future<void> _startListening() async {
    if (!_checking || _listenState == Listening.listening) return;
    _listenState = Listening.starting;
    notifyListeners();
    try {
      if (!await _listener.hasPermission()) {
        _listenState = Listening.denied;
        notifyListeners();
        return;
      }
      await _listener.start(_onHeard, alongsideMusic: true);
      _listenState = Listening.listening;
    } catch (e) {
      debugPrint('Could not listen while the band plays: $e');
      _listenState = Listening.failed;
    }
    notifyListeners();
  }

  Future<void> _stopListening() async {
    _heard = null;
    if (_listenState == Listening.off || _madeListener == null) return;
    _listenState = Listening.off;
    await _listener.stop();
    // The microphone changes how the phone's audio is set up; put it back.
    await player.restoreAudioSession();
  }

  void _onHeard(Heard heard) {
    if (heard == null) {
      _heard = null;
      // Always, even when there's nothing: a meter that stops moving is
      // indistinguishable from a microphone that isn't working.
      notifyListeners();
      return;
    }
    final concert = hzToMidi(heard.hz);
    _lastNote = DateTime.now();
    _check?.note(concert);
    // Shown as your instrument reads it, so it matches the chart.
    _heard = noteNear(concert + settings.instrument.semitones);
    notifyListeners();
  }

  // ── Recording yourself ─────────────────────────────────────────────────

  /// Whether the next Play records you as well.
  bool get recording => _recording;
  var _recording = false;

  /// True while a take is actually being captured.
  bool get isRecordingNow => _takePath != null;

  /// The take being played back, if any.
  Take? get playingTake => _playingTake;
  Take? _playingTake;

  String? _takePath;
  String? _takeName;
  String? _takeId;
  Duration _leadIn = Duration.zero;

  bool get canRecord => takes != null;

  /// Arms or disarms recording. It starts with the band, not now.
  Future<void> setRecording(bool value) async {
    if (value == _recording || takes == null) return;
    if (value && !await _tape.hasPermission()) {
      _error = 'The microphone is blocked. Allow it to record yourself.';
      notifyListeners();
      return;
    }
    _recording = value;
    notifyListeners();
  }

  /// Plays [take] with the band put back around it, exactly as it was.
  Future<void> playTake(Take take) async {
    await stop();
    final path = await takes?.files.pathOf(take.file);
    if (path == null) {
      _error = 'That take has gone missing.';
      notifyListeners();
      return;
    }
    _playingTake = take;
    _recording = false;
    _bandSilent = !settings.takesWithBand;
    transpose(take.semitones);
    _tempo = take.tempo;
    _loop = LoopRange(startBeat: take.loopStart, lengthBeats: take.loopBeats);
    _arrangement = take.arrangement;
    await play(withCountIn: false, take: take, takePath: path);
    if (!_isPlaying) return;
    _takeTimer?.cancel();
    _takeTimer = Timer(take.length + const Duration(milliseconds: 600), stop);
  }

  Timer? _takeTimer;

  /// Whether playing a take back puts the band around it.
  bool get takesWithBand => settings.takesWithBand;

  Future<void> setTakesWithBand(bool value) async {
    await settings.setTakesWithBand(value);
    notifyListeners();
    if (_playingTake != null) {
      _bandSilent = !value;
      _applyMix();
    }
  }

  /// How loud you are against the band, when playing a take back.
  double get takeVolume => _takeVolume;
  var _takeVolume = 1.0;

  void setTakeVolume(double value) {
    _takeVolume = value.clamp(0.0, 1.0);
    player.setTakeVolume(_takeVolume);
    notifyListeners();
  }

  /// Saves whatever has just been recorded.
  Future<void> _saveTake() async {
    final store = takes;
    final id = _takeId;
    final name = _takeName;
    _takePath = null;
    _takeName = null;
    _takeId = null;
    if (store == null || id == null || name == null) return;
    final length = await _tape.stop();
    final played = length - _leadIn;
    // Anything shorter than a bar or two isn't a take, it's a false start.
    if (played < const Duration(seconds: 4)) {
      await store.files.remove(name);
      return;
    }
    await store.add(
      Take(
        id: id,
        at: DateTime.now(),
        file: name,
        tune: originalTune.title,
        seconds: length.inMilliseconds / 1000,
        leadIn: _leadIn.inMilliseconds / 1000,
        tempo: _tempo,
        semitones: _semitones,
        loopStart: _loop.startBeat,
        loopBeats: _loop.lengthBeats,
        seed: _lastSeed,
        arrangement: _arrangement,
      ),
    );
  }

  /// The lead-in of the take being recorded: the band has to be written
  /// before it can play, and the microphone is running all the while.
  Duration get takeLeadIn => _leadIn;

  // ── Real players instead of the generated band ─────────────────────────

  /// The recordings imported for this tune, which is usually none.
  TakeSet get ownTakes => recordingStore?.forTune(_ref) ?? TakeSet.empty;

  /// Takes imported against another tune whose changes are these changes,
  /// moved. Worked out from the charts, so a blues played in F backs every
  /// blues in the book and not only the one it was imported against.
  List<BorrowedTake> get borrowedTakes =>
      recordingStore?.fitting(_tune, _ref, progressions: progressions) ??
      const [];

  /// Everything the band could be played from: this tune's own takes
  /// first, then anything that fits.
  TakeSet get recordedTakes => TakeSet([
    ...ownTakes.takes,
    for (final borrowed in borrowedTakes) borrowed.take,
  ]);

  /// Where the take now in use came from, when it was not imported for
  /// this tune. Null for one of this tune's own.
  ///
  /// Said out loud wherever the take is named. Putting another tune's
  /// players under a chart without saying so is the worst thing this could
  /// do: it does not sound like the app made a mistake, it sounds like you
  /// did.
  BorrowedTake? get borrowedInUse {
    final take = recordingInUse;
    if (take == null) return null;
    if (ownTakes.takes.any((own) => own.name == take.name)) return null;
    for (final borrowed in borrowedTakes) {
      if (borrowed.take.name == take.name) return borrowed;
    }
    return null;
  }

  /// Whether the band should be real players when there are some.
  bool get useRecording => _useRecording && !recordedTakes.isEmpty;
  var _useRecording = true;

  void setUseRecording(bool value) {
    if (value == _useRecording) return;
    _useRecording = value;
    _restartIfPlaying(delay: Duration.zero);
    notifyListeners();
  }

  /// The take that lands closest to the tempo and key being played.
  ///
  /// Whichever needs the least from the pitch shifter, because that is
  /// where every artefact comes from. It is worked out rather than chosen
  /// by hand so it cannot disagree with what is actually playing.
  RecordedTake? get recordingInUse => !useRecording
      ? null
      : recordedTakes.bestFor(tempo: _tempo, soundingKey: soundingKey);

  /// The key being played, as a pitch class, whatever it is spelled as.
  int get soundingKey => _tune.keyPitchClass;

  /// How hard that take is being pushed to get here.
  TakeShift? get recordingShift =>
      recordingInUse?.shiftTo(tempo: _tempo, soundingKey: soundingKey);

  /// The audio of the take being used, once it has been read.
  ///
  /// Only one take's worth is held. Three stems of six choruses is a
  /// hundred megabytes or so decoded, and a set of four would be most of
  /// what a phone will give you.
  final _decoded = <String, Map<TakeStem, WavAudio>>{};

  void _recordingsChanged() {
    _decoded.clear();
    notifyListeners();
  }

  Future<PlayableRecording?> _playableRecording() async {
    final take = recordingInUse;
    final store = recordingStore;
    if (take == null || store == null) return null;
    var stems = _decoded[take.name];
    if (stems == null) {
      stems = {};
      for (final entry in take.files.entries) {
        try {
          final bytes = await store.read(entry.value);
          if (bytes != null) stems[entry.key] = readWav(bytes);
        } catch (e) {
          // One stem that will not read loses that stem, not the take.
          // A bass and drums with no comp is still a rhythm section.
          debugPrint('Could not read ${entry.value}: $e');
        }
      }
      if (stems.isEmpty) return null;
      _decoded
        ..clear()
        ..[take.name] = stems;
    }
    return PlayableRecording(
      take: take,
      stems: stems,
      shift: take.shiftTo(tempo: _tempo, soundingKey: soundingKey),
    );
  }

  // ── Writing it out as a file ───────────────────────────────────────────

  /// True while an export is being written.
  bool get isExporting => _exporting;
  var _exporting = false;

  /// How long an export of the arrangement as it stands would be, or null
  /// when it never ends and so can't be a file.
  Duration? get exportLengthNow {
    if (_arrangement.choruses == null) return null;
    return exportLength(_exportRequest());
  }

  /// The band exactly as it was when [take] was recorded.
  /// The tune's intro, played once before the band goes round the rest,
  /// when the whole tune is being played from the top: how iReal Pro plays
  /// a chart that opens with one. A loop somebody has set, or a start
  /// partway in, is played as asked, intro or not.
  LoopRange? get _intro =>
      _loop.isWholeTune(tune) && pickUpBeats == 0 ? introOf(tune) : null;

  /// What the band goes round: the whole of the loop, or all of it after
  /// the intro.
  LoopRange get _goesRound {
    final intro = _intro;
    if (intro == null) return _loop;
    return LoopRange(
      startBeat: intro.endBeat,
      lengthBeats: _loop.endBeat - intro.endBeat,
    );
  }

  BackingRequest _requestFor(Take take, {Arrangement? arrangement}) =>
      BackingRequest(
        tune: originalTune.transposed(take.semitones),
        loop: LoopRange(startBeat: take.loopStart, lengthBeats: take.loopBeats),
        tempo: take.tempo,
        countInBars: _countInBars,
        seed: take.seed,
        samples: player.samples,
        comping: settings.comping,
        bassSound: settings.bassSound,
        drumSound: settings.drumSound,
        arpeggios: _arpeggios,
        arpeggioSound: settings.arpeggioSound,
        arpeggioStart: settings.arpeggioStart,
        arpeggioRate: settings.arpeggioRate,
        arpeggioReach: settings.arpeggioReach,
        arrangement: arrangement ?? take.arrangement,
        imported: _imported?.transposedBy(take.semitones),
        drumLevels: settings.drumLevels,
        swing: style.swing,
      );

  BackingRequest _exportRequest({Arrangement? arrangement}) => BackingRequest(
    tune: tune,
    loop: _goesRound,
    intro: _intro,
    tempo: _tempo,
    countInBars: _countInBars,
    seed: _lastSeed == 0 ? 1 : _lastSeed,
    samples: player.samples,
    comping: settings.comping,
    bassSound: settings.bassSound,
    drumSound: settings.drumSound,
    arpeggios: _arpeggios,
    arpeggioSound: settings.arpeggioSound,
    arpeggioStart: settings.arpeggioStart,
    arpeggioRate: settings.arpeggioRate,
    arpeggioReach: settings.arpeggioReach,
    arrangement: arrangement ?? _arrangement,
    imported: _imported?.transposedBy(_semitones),
    drumLevels: settings.drumLevels,
    swing: style.swing,
  );

  /// Writes the band out as a WAV and hands it to the share sheet. With
  /// [take], your recording is mixed in on top.
  ///
  /// Nothing is kept: the file goes in the temporary folder, which the
  /// system empties on its own once it has been shared.
  Future<void> exportBacking({Take? take}) async {
    if (_exporting) return;
    // A take brings its own length: the band runs as long as you played and
    // no further. Without one, the arrangement has to say where to stop.
    if (take == null && _arrangement.choruses == null) {
      _error = 'Set a number of choruses first: an export has to end.';
      notifyListeners();
      return;
    }
    await stop();
    _exporting = true;
    _error = null;
    notifyListeners();
    try {
      Int16List? recorded;
      if (take != null) {
        final path = await takes?.files.pathOf(take.file);
        if (path != null) recorded = decodeWav(await File(path).readAsBytes());
      }
      final request = take == null ? _exportRequest() : _requestFor(take);
      // The band stops where you did, rounded up to the end of the
      // section you finished in, so it lands on a rehearsal letter rather
      // than in the middle of a phrase.
      int? endBeat;
      var toRender = request;
      if (take != null) {
        final played = beatsIn(request, take.length);
        endBeat = finishSectionAfter(request.tune, request.loop, played);
        final choruses = (endBeat / request.loop.lengthBeats).ceil();
        toRender = _requestFor(
          take,
          arrangement: take.arrangement.copyWith(choruses: choruses),
        );
      }
      final leadIn = take?.leadIn ?? 0;
      final level = _takeVolume;
      final end = endBeat;
      final wav = await Isolate.run(
        () => exportTrack(
          toRender,
          take: recorded,
          takeLeadIn: leadIn,
          takeLevel: level,
          endBeat: end,
        ),
      );
      final folder = await getTemporaryDirectory();
      final name = _fileName(take == null ? null : 'my take');
      final file = File('${folder.path}/$name');
      await file.writeAsBytes(wav);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'audio/wav')],
          fileNameOverrides: [name],
          subject: originalTune.title,
        ),
      );
    } catch (e) {
      debugPrint('Could not export: $e');
      _error = "Couldn't write the audio file.";
    }
    _exporting = false;
    notifyListeners();
  }

  /// "Autumn Leaves 140bpm.wav", fit to be a filename.
  String _fileName(String? what) {
    final title = originalTune.title.replaceAll(RegExp(r'[^A-Za-z0-9 ]'), '');
    final key = _semitones == 0 ? '' : ' up $_semitones';
    return '$title$key ${_tempo}bpm${what == null ? '' : ' $what'}.wav';
  }

  // ── Transport ──────────────────────────────────────────────────────────

  /// The main button: play from the top, pause, or carry on from a pause.
  Future<void> togglePlay() async {
    if (!_isPlaying) return play();
    if (_isPaused) {
      resume();
    } else {
      pause();
    }
  }

  void pause() {
    if (!_isPlaying || _isPreparing || _isPaused) return;
    player.pause();
    _isPaused = true;
    _ticker?.cancel(); // the highlight stays on the bar where it stopped
    unawaited(_tellTheSystem());
    notifyListeners();
  }

  void resume() {
    if (!_isPaused) return;
    player.resume();
    _isPaused = false;
    _startTicker();
    unawaited(_tellTheSystem());
    notifyListeners();
  }

  Future<void> play({
    bool withCountIn = true,
    Take? take,
    String? takePath,
  }) async {
    _finishTimer?.cancel();
    _finishing = false;
    _chorus = null;
    if (_checking) {
      if (settings.aimFor case final target?) {
        _check = PlayCheck(tune: tune, target: target);
        _lastCheck = null;
      }
    }
    _isPlaying = true;
    unawaited(_tellTheSystem());
    _isPaused = false;
    _isPreparing = true;
    _error = null;
    if (take == null) {
      _playingTake = null;
      _bandSilent = false;
    }
    _applyMix();
    notifyListeners();

    // The microphone goes on before the band, because the band has to be
    // written first and that takes a moment. How much of the recording is
    // that wait is measured, and wound past when the take is played back.
    final store = takes;
    if (_recording && store != null && takePath == null) {
      try {
        final id = store.newId();
        final where = await store.files.place(id);
        await _tape.start(where.path);
        _takeId = id;
        _takePath = where.path;
        _takeName = where.name;
        _leadIn = Duration.zero;
      } catch (e) {
        debugPrint('Could not start recording: $e');
        _recording = false;
      }
    }
    final waiting = Stopwatch()..start();

    // The same seed plays the same performance again, which is what lets a
    // take be recorded without the band in it.
    _lastSeed = take?.seed ?? _random.nextInt(1 << 31);
    // Real players, when there are some and they have not been turned
    // off. Reading them takes a moment, so it happens before the band is
    // written rather than after, while nothing is being heard anyway.
    final recording = take == null ? await _playableRecording() : null;
    try {
      await player.start(
        BackingRequest(
          tune: tune,
          loop: _goesRound,
          intro: _intro,
          tempo: _tempo,
          countInBars: withCountIn ? _countInBars : 0,
          seed: _lastSeed,
          comping: settings.comping,
          bassSound: settings.bassSound,
          drumSound: settings.drumSound,
          arpeggios: _arpeggios,
          arpeggioSound: settings.arpeggioSound,
          arpeggioStart: settings.arpeggioStart,
          arpeggioRate: settings.arpeggioRate,
          arpeggioReach: settings.arpeggioReach,
          arrangement: _arrangement,
          imported: _imported?.transposedBy(_semitones),
          drumLevels: settings.drumLevels,
          swing: style.swing,
        ),
        alongside: takePath,
        recording: recording,
        pickUpBeats: pickUpBeats,
        leadIn: take == null
            ? Duration.zero
            : Duration(milliseconds: (take.leadIn * 1000).round()),
      );
      if (_takePath != null) _leadIn = waiting.elapsed;
      if (takePath != null) player.setTakeVolume(_takeVolume);
    } catch (e) {
      _error = takePath == null
          ? "Couldn't start audio: $e"
          : "Couldn't play that take. The recording wouldn't open.";
      _isPlaying = false;
      _playingTake = null;
      _bandSilent = false;
      _applyMix();
      debugPrint('Playback failed: $e');
    }
    _isPreparing = false;
    if (_isPlaying) {
      _startTicker();
      unawaited(_startListening());
    }
    notifyListeners();
  }

  Future<void> stop() async {
    _takeTimer?.cancel();
    _restartTimer?.cancel();
    _finishTimer?.cancel();
    _ticker?.cancel();
    // Mark whatever was still sounding, and keep the score to show.
    final marking = _check;
    if (marking != null) {
      marking.finish();
      _lastCheck = marking.asked > 0 ? marking : null;
      _check = null;
    }
    _noteRun(marking);
    // The chart comes back the moment the band stops: this is an exercise,
    // not a punishment, and the next run has to be set up.
    _gaveIn = false;
    unawaited(_stopListening());
    if (_takePath != null) unawaited(_saveTake());
    _isPlaying = false;
    unawaited(_card?.hide());
    _isPaused = false;
    _finishing = false;
    _currentBeat = null;
    _countInBeat = null;
    _chorus = null;
    notifyListeners();
    await player.stop();
  }

  /// How much of the chart is showing: the whole thing, the bars without
  /// their chords, or nothing at all.
  ///
  /// Reading is a crutch, so it goes a rung at a time while the band plays
  /// on. Giving in puts it back for the rest of the run, and stopping puts
  /// it back for good: you have to be able to set up the next one.
  ChartShows get chartShows =>
      _gaveIn ? ChartShows.everything : settings.fadeChart.showsOn(chorus);

  /// Whether the chart is being taken away on this run at all, which is
  /// what the screen needs to know to offer a way back to it.
  bool get chartIsFading => settings.fadeChart.isOn && isPlaying && !_gaveIn;

  bool _gaveIn = false;

  /// Puts the chart back for the rest of this run. No shame in it: being
  /// lost with no way out is not an exercise, it is just being lost.
  void showTheChart() {
    if (_gaveIn) return;
    _gaveIn = true;
    notifyListeners();
  }

  /// Every run at this tune, newest first: the practice record.
  List<Run> get runs {
    final ref = _ref;
    if (ref == null) return const [];
    return library?.runsFor(ref) ?? const [];
  }

  /// Forgets this tune's record. There is no undo, so the screen asks
  /// first.
  Future<void> clearRuns() async {
    final ref = _ref;
    if (ref == null) return;
    await library?.clearRuns(ref);
  }

  /// The tempo the record says to try next, once a run has earned it, or
  /// null. Read by the screen when it shows the score.
  int? get nextTempo {
    final ref = _ref;
    if (ref == null) return null;
    final next = readyToMoveUp(library?.runsFor(ref) ?? const [], at: _tempo);
    return next == null || next > maxTempo ? null : next;
  }

  /// Keeps what has just been played: the tempo, and how it was marked.
  ///
  /// A false start isn't practice. Stopping before a bar has gone by is
  /// someone changing their mind, so it isn't written down; but anything
  /// longer is, marked or not, because the tempo alone is worth keeping.
  void _noteRun(PlayCheck? marking) {
    final ref = _ref;
    final store = library;
    final reached = _currentBeat;
    if (ref == null || store == null) return;
    if ((marking?.asked ?? 0) == 0 &&
        (reached == null || reached < tune.beatsPerBar)) {
      return;
    }
    unawaited(
      store.noteRun(ref, (
        at: DateTime.now(),
        tempo: _tempo,
        asked: marking?.asked ?? 0,
        hits: marking?.hits ?? 0,
      )),
    );
  }

  void _restartIfPlaying({required Duration delay}) {
    if (!_isPlaying) return;
    // A new tempo, key or loop means a new performance, which starts from
    // the top of the loop, so a pause can't be carried on from. End it, and
    // Play starts afresh with the change.
    if (_isPaused) {
      stop();
      return;
    }
    _restartTimer?.cancel();
    _restartTimer = Timer(delay, () => play(withCountIn: false));
  }

  /// Checks the playback position often enough to move the highlight, and
  /// faster than that when the beat is being felt as well.
  ///
  /// The highlight is forgiving about arriving a frame late; a tap on the
  /// wrist is not, because a pulse you cannot trust is worse than none.
  /// This is the only beat signal there is on the Dart side, so when
  /// somebody is feeling the beat it is worth looking more often.
  void _startTicker() {
    _ticker?.cancel();
    final every = settings.feelTheBeat == FeelTheBeat.off ? 30 : 10;
    _tickEvery = every;
    _ticker = Timer.periodic(Duration(milliseconds: every), (_) {
      final position = player.position();
      if (position == null) return;
      // The last chorus has gone by: let the final chord ring, then stop.
      final total = _arrangement.choruses;
      if (total != null &&
          position.chorus != null &&
          position.chorus! >= total) {
        _finishing = true;
        _ticker?.cancel();
        notifyListeners();
        _finishTimer = Timer(const Duration(milliseconds: 1400), () {
          if (_finishing) stop();
        });
        return;
      }
      if (position.tuneBeat != _currentBeat ||
          position.countInBeat != _countInBeat ||
          position.chorus != _chorus) {
        // Felt before anything is rebuilt, because the tap is the thing
        // with a deadline on it.
        if (position.tuneBeat case final beat? when beat != _currentBeat) {
          feelBeat(
            settings.feelTheBeat,
            beat: beat,
            beatsPerBar: chart.beatsPerBar,
          );
        } else if (position.countInBeat case final beat?
            when beat != _countInBeat) {
          feelCountIn(settings.feelTheBeat);
        }
        _currentBeat = position.tuneBeat;
        _countInBeat = position.countInBeat;
        _chorus = position.chorus;
        if (position.tuneBeat != null && position.chorus != null) {
          _check?.moveTo(position.tuneBeat!, position.chorus!);
        }
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _restartTimer?.cancel();
    _finishTimer?.cancel();
    _ticker?.cancel();
    _takeTimer?.cancel();
    _madeListener?.dispose();
    _recorder?.dispose();
    settings.removeListener(_updateChart);
    recordingStore?.removeListener(_recordingsChanged);
    player.stop();
    unawaited(_card?.hide());
    super.dispose();
  }
}

/// Whether the microphone is going, and why not if it isn't.
enum Listening { off, starting, listening, denied, failed }
