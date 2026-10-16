// A progression someone has written in the app, and how it's saved.
//
// It's kept as plain text (each bar's chords as the player typed them) so
// it can be saved as JSON and edited again exactly as it was written. It
// becomes a [Tune] only when it's played.

import 'chord.dart';
import 'meter.dart';
import 'tune.dart';

class UserProgression {
  UserProgression({
    required this.id,
    required this.title,
    required this.key,
    required this.tempo,
    required this.bars,
    required this.style,
    this.composer,
    this.meter = Meter.four,
    int? beatsPerBar,
    Set<Genre>? tags,
    Map<int, String>? sections,
    Map<int, int>? repeats,
    Map<int, int>? endings,
  }) : assert(
         beatsPerBar == null || meter == Meter.four,
         'say the meter or the beats, not both',
       ),
       tags = tags ?? {},
       sections = sections ?? {},
       repeats = repeats ?? {},
       endings = endings ?? {} {
    // A caller can say how many beats a bar has rather than what is
    // written at the front of the chart, which is how every chart in
    // quarter notes reads most naturally: beatsPerBar: 3 is a waltz.
    if (beatsPerBar != null) meter = Meter.ofPulses(beatsPerBar);
  }

  /// A fresh progression: no bars yet, a swing band at 120.
  factory UserProgression.starter({required String id}) => UserProgression(
    id: id,
    title: '',
    key: 'C',
    tempo: 120,
    bars: [],
    style: BandStyle.of(Feel.swing),
  );

  /// A tune written out as a progression, so one of the book's standards
  /// can be handed to anything that works on the player's own charts: the
  /// editor, or an export.
  ///
  /// A [Tune] holds its bars as they're played, with repeated sections
  /// written out in full, so what comes back is the long form: the chords
  /// are right, but a section played twice is two sections rather than one
  /// marked ×2.
  factory UserProgression.fromTune(Tune tune, {required String id}) =>
      UserProgression(
        id: id,
        title: tune.title,
        composer: tune.composer,
        key: tune.key,
        tempo: tune.defaultTempo,
        meter: tune.meter,
        style: tune.style,
        tags: {...tune.tags},
        sections: {...tune.sections},
        bars: [
          for (final bar in tune.bars)
            [for (final slot in bar) slot.chord.display].join(' '),
        ],
      );

  factory UserProgression.fromJson(Map<String, dynamic> json) =>
      UserProgression(
        id: json['id'] as String,
        title: json['title'] as String,
        key: json['key'] as String,
        tempo: json['tempo'] as int,
        bars: [for (final bar in json['bars'] as List) bar as String],
        composer: json['composer'] as String?,
        // Saved before meters were written down: every one of them was
        // counted in quarter notes.
        meter:
            Meter.parse(json['meter'] as String? ?? '') ??
            Meter.ofPulses(json['beats'] as int? ?? 4),
        style: BandStyle(
          drums: Feel.values.byName(json['drums'] as String),
          bass: BassStyle.values.byName(json['bass'] as String),
          piano: PianoStyle.values.byName(json['piano'] as String),
        ),
        // Saved before genres existed: none.
        tags: {
          for (final tag in json['tags'] as List? ?? const [])
            ?Genre.values.where((genre) => genre.name == tag).firstOrNull,
        },
        // Saved before sections existed: none.
        sections: {
          for (final MapEntry(:key, :value)
              in (json['sections'] as Map? ?? const {}).entries)
            int.parse(key as String): value as String,
        },
        repeats: {
          for (final MapEntry(:key, :value)
              in (json['repeats'] as Map? ?? const {}).entries)
            int.parse(key as String): value as int,
        },
        endings: {
          for (final MapEntry(:key, :value)
              in (json['endings'] as Map? ?? const {}).entries)
            int.parse(key as String): value as int,
        },
      );

  final String id;
  String title;

  /// Who wrote it, if anyone's named: an imported tune's composer.
  String? composer;

  /// The time signature on the chart: 4/4, a waltz, six eight.
  Meter meter;

  /// What the band counts in a bar, which is the written beats except in
  /// compound time: a bar of 6/8 is counted in two.
  ///
  /// Setting it says the chart is in quarter notes, which is the only
  /// meter it can say: six eight has to be set as a meter.
  int get beatsPerBar => meter.pulses;
  set beatsPerBar(int beats) => meter = Meter.ofPulses(beats);

  /// The time signatures to choose from.
  static const meters = Meter.choices;

  /// e.g. "B♭" or "C minor": decides how chords are spelled when the key is
  /// changed, and what B♭ and E♭ players see.
  String key;
  int tempo;

  /// Each bar's chords, as typed: "Dm7 G7".
  List<String> bars;
  BandStyle style;

  /// Genres the player has tagged it with. Its groove's genre (swing, Latin,
  /// funk) comes from [style] and isn't stored.
  Set<Genre> tags;

  /// Where each section of the form starts: bar index → its letter, e.g.
  /// {0: 'A', 8: 'B'}. Shown on the chart as rehearsal letters, as on a
  /// standard's.
  Map<int, String> sections;

  /// How many times a section is played, keyed by the bar it starts on:
  /// {0: 2} plays the A section twice. Sections not in it play once. The
  /// chart writes a repeated section once, marked ×2.
  Map<int, int> repeats;

  /// Bars that are a 1st or 2nd ending, keyed by bar: {6: 1, 7: 1, 8: 2,
  /// 9: 2}. Written as on a lead sheet (the section, its 1st ending, then
  /// its 2nd) and played twice: through the 1st ending, then the 2nd.
  Map<int, int> endings;

  /// The letters a section can have.
  static const sectionLetters = ['A', 'B', 'C', 'D', 'E'];

  /// The most times a section can repeat.
  static const maxRepeats = 4;

  /// How many times the section starting at bar [index] is played.
  int repeatsOf(int index) => repeats[index] ?? 1;

  /// Plays the section starting at bar [index] [times] times.
  void setRepeats(int index, int times) {
    if (times <= 1 || !sections.containsKey(index)) {
      repeats.remove(index);
    } else {
      repeats[index] = times.clamp(2, maxRepeats);
    }
  }

  /// Makes bar [index] part of the 1st or 2nd [ending] of its section, or
  /// neither. Endings belong to a section, so a progression without any
  /// gets an A.
  void setEnding(int index, int? ending) {
    if (ending == null) {
      endings.remove(index);
      return;
    }
    endings[index] = ending;
    if (sections.isEmpty) sections[0] = 'A';
  }

  /// The bars of the section starting at bar [start], up to the next one.
  Iterable<int> _barsOfSection(int start) sync* {
    final next = sections.keys.where((i) => i > start && i < bars.length);
    final end = next.isEmpty
        ? bars.length
        : next.reduce((a, b) => a < b ? a : b);
    for (var i = start; i < end; i++) {
      yield i;
    }
  }

  /// Whether the section starting at bar [start] has both a 1st and a 2nd
  /// ending, and so is played twice, one ending each time.
  bool hasEndings(int start) {
    final marks = {for (final i in _barsOfSection(start)) endings[i]};
    return marks.contains(1) && marks.contains(2);
  }

  /// The letter for a section added after the last one: the next letter
  /// along (B after A), or A for the first.
  String get nextSection {
    if (sections.isEmpty) return bars.isEmpty ? 'A' : 'B';
    final last = sections[sections.keys.reduce((a, b) => a > b ? a : b)]!;
    final index = sectionLetters.indexOf(last);
    return sectionLetters[(index + 1).clamp(0, sectionLetters.length - 1)];
  }

  /// Starts section [letter] at bar [index], or none there if null. A
  /// progression's first section is always marked: giving a later bar a
  /// letter labels the bars before it A, if they weren't already.
  void setSection(int index, String? letter) {
    if (letter == null) {
      sections.remove(index);
      repeats.remove(index);
      return;
    }
    sections[index] = letter;
    // A section starts with its own bars, not an ending.
    endings.remove(index);
    if (index > 0 && !sections.containsKey(0)) sections[0] = 'A';
  }

  /// Takes out bar [index]. A section that started on it starts on the next
  /// bar instead (unless that one starts its own), and later sections move
  /// back a bar.
  void removeBar(int index) {
    bars.removeAt(index);
    // A section's start and its repeat count move together.
    final starts = <int, ({String letter, int? times})>{};
    for (final MapEntry(:key, :value) in sections.entries) {
      final section = (letter: value, times: repeats[key]);
      if (key < index) {
        starts[key] = section;
      } else if (key == index) {
        if (index < bars.length) starts.putIfAbsent(index, () => section);
      } else {
        starts[key - 1] = section;
      }
    }
    sections = {
      for (final MapEntry(:key, :value) in starts.entries) key: value.letter,
    };
    repeats = {
      for (final MapEntry(:key, :value) in starts.entries)
        if (value.times != null) key: value.times!,
    };
    endings = {
      for (final MapEntry(:key, :value) in endings.entries)
        if (key != index) (key < index ? key : key - 1): value,
    };
  }

  /// Up to four chords can share a bar of 4/4 (one a beat). A bar of
  /// another meter holds its own number of beats: see [problemWith].
  static const maxChordsPerBar = 4;

  /// The bars with more chords than this meter has beats, by bar number
  /// (1 for the first), so the editor can say which bars no longer fit
  /// before the extra chords are dropped from the chart.
  List<int> get crowdedBars => [
    for (var i = 0; i < bars.length; i++)
      if (symbolsIn(bars[i]).length > beatsPerBar) i + 1,
  ];

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (composer != null) 'composer': composer,
    // Both, so a chart saved here still opens in a version that only
    // knew how many beats a bar had: 'beats' is what the band counts.
    if (meter != Meter.four) ...{'beats': beatsPerBar, 'meter': meter.label},
    'key': key,
    'tempo': tempo,
    'bars': bars,
    'drums': style.drums.name,
    'bass': style.bass.name,
    'piano': style.piano.name,
    'tags': [for (final tag in tags) tag.name],
    'sections': {
      for (final MapEntry(:key, :value) in sections.entries)
        if (key < bars.length) '$key': value,
    },
    'repeats': {
      for (final MapEntry(:key, :value) in repeats.entries)
        if (sections.containsKey(key) && key < bars.length) '$key': value,
    },
    'endings': {
      for (final MapEntry(:key, :value) in endings.entries)
        if (key < bars.length) '$key': value,
    },
  };

  /// The chord symbols in one bar's text. Spaces around a slash are
  /// allowed: "Fmaj7 / C" is one chord, Fmaj7 over C.
  static List<String> symbolsIn(String bar) => bar
      .trim()
      .replaceAll(RegExp(r'\s*/\s*'), '/')
      .split(RegExp(r'\s+'))
      .where((s) => s.isNotEmpty)
      .toList();

  /// What's wrong with a bar's chords, or null if they're fine.
  ///
  /// A bar holds one chord a beat at the most, so the limit is the meter's:
  /// four in 4/4, three in a waltz. A fifth chord in 4/4 has no beat to
  /// sound on, and the band is never given a chord that lasts no time.
  static String? problemWith(String bar, {Meter meter = Meter.four}) {
    final symbols = symbolsIn(bar);
    if (symbols.isEmpty) return 'A bar needs at least one chord';
    // One chord a beat, and in compound time the beat is the pulse: a
    // bar of 6/8 is two, not six, because that is what it is counted in.
    if (symbols.length > meter.pulses) {
      return 'At most ${meter.pulses} chords in a bar of ${meter.label}';
    }
    for (final symbol in symbols) {
      try {
        Chord.parse(symbol);
      } on FormatException {
        return '"$symbol" isn\'t a chord symbol this app knows';
      }
    }
    return null;
  }

  /// Ready to play: a title (or a stand-in), at least one bar, every bar
  /// valid.
  bool get isPlayable =>
      bars.isNotEmpty &&
      bars.every((bar) => problemWith(bar, meter: meter) == null);

  String get displayTitle => title.trim().isEmpty ? 'Untitled' : title.trim();

  /// Its genres (the groove's and any it's tagged with), without building
  /// the whole tune, for filtering a long list quickly.
  Set<Genre> get genres => {Genre.ofFeel(style.drums), ...tags};

  Tune toTune() => Tune.fromChart(
    title: displayTitle,
    composer: composer,
    key: key,
    description: 'Your progression',
    defaultTempo: tempo,
    feel: style.drums,
    style: style,
    tags: tags,
    meter: meter,
    chart: '| ${_playedBars().join(' | ')} |',
  );

  /// Every bar as the band plays it, repeated sections written out each
  /// time and each time marked with its letter, which is how the chart
  /// knows to fold them back into one, marked ×2 or with its 1st and 2nd
  /// endings.
  List<String> _playedBars() {
    final starts = sections.keys.where((i) => i < bars.length).toList()..sort();
    String bar(int i) => symbolsIn(bars[i]).join(' ');
    final played = <String>[
      // Any bars before the first section.
      for (var i = 0; i < (starts.firstOrNull ?? bars.length); i++) bar(i),
    ];
    void pass(int start, bool Function(int bar) plays) {
      var first = true;
      for (final i in _barsOfSection(start)) {
        if (!plays(i)) continue;
        played.add(first ? '[${sections[start]}] ${bar(i)}' : bar(i));
        first = false;
      }
    }

    for (final start in starts) {
      if (hasEndings(start)) {
        // Through the 1st ending, then round again to the 2nd.
        pass(start, (i) => endings[i] != 2);
        pass(start, (i) => endings[i] != 1);
      } else {
        // Until it has both endings, every bar plays as written.
        for (var time = 0; time < repeatsOf(start); time++) {
          pass(start, (_) => true);
        }
      }
    }
    return played;
  }

  /// Keys to choose from, spelled the usual way for each.
  static const keys = [
    'C', 'D♭', 'D', 'E♭', 'E', 'F', 'G♭', 'G', 'A♭', 'A', 'B♭', 'B', //
    'C minor', 'C♯ minor', 'D minor', 'E♭ minor', 'E minor', 'F minor',
    'F♯ minor', 'G minor', 'G♯ minor', 'A minor', 'B♭ minor', 'B minor',
  ];

  /// A sensible key for [bars]. Progressions come home towards the end, so
  /// the last home-type chord (Δ7, 6, m6 …) names the key: a ii–V–I on to
  /// CΔ7 is in C, though it starts on Dm7, even with a turnaround after
  /// it. With no home chord at all (a blues, a vamp), the first chord does.
  static String guessKey(List<String> bars) {
    final chords = [
      for (final bar in bars)
        for (final symbol in symbolsIn(bar)) ?_tryParse(symbol),
    ];
    if (chords.isEmpty) return 'C';
    const homeChords = {
      'Major', 'Major 7th', 'Major 6th', 'Six-nine', 'Major 9th', //
      'Minor', 'Minor 6th', 'Minor-major 7th',
    };
    final home = chords.lastWhere(
      (chord) => homeChords.contains(chord.quality.name),
      orElse: () => chords.first,
    );
    final intervals = home.quality.intervals;
    final minor = intervals.contains(3) && !intervals.contains(6); // not ø, °
    final wanted = minor ? '${home.rootName} minor' : home.rootName;
    if (keys.contains(wanted)) return wanted;
    // Spelled differently from the list (A♯ rather than B♭): match by sound.
    return keys.firstWhere(
      (key) =>
          key.endsWith('minor') == minor &&
          pitchClassOf(parseNoteName(key.split(' ').first)!) == home.root,
    );
  }

  static Chord? _tryParse(String symbol) {
    try {
      return Chord.parse(symbol);
    } on FormatException {
      return null;
    }
  }
}
