// How the player's own library is organised: what they've starred, what
// they've played lately, and the setlists they've put together.
//
// None of this is about the music itself, so it isn't kept with the tunes.
// It's three small lists of references saved together as one piece of JSON,
// the same way the progressions are.
//
// A reference has to name a tune that may be either built in or written by
// the player, and the two are identified differently: the standards have no
// id, only a title (which is unique in the book, and is how takes name their
// tune too), while a player's progression has an id and a title they can
// change under it. So "s:Autumn Leaves" is the standard and "p:17…-0" is
// one of their own.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../music/comping.dart';
import '../music/tune.dart';
import '../music/user_progression.dart';
import '../practice/practice_record.dart';
import '../settings/progression_store.dart'
    show TextStorage, MemoryStorage, preferencesStorage;

/// Points at a tune: one of the book's, by title, or one of the player's
/// own, by id.
class TuneRef {
  const TuneRef(this.value);

  /// A standard or practice progression, named by its title.
  TuneRef.standard(String title) : value = 's:$title';

  /// One of the player's own progressions, named by its id.
  TuneRef.mine(String id) : value = 'p:$id';

  /// Whichever of the two [tune] is. Only the book's tunes reach here as a
  /// [Tune]: a player's progression becomes one only when it's played, and
  /// by then its title may not be the one it's saved under.
  TuneRef.of(Tune tune) : value = 's:${tune.title}';

  /// As it's saved: "s:Autumn Leaves" or "p:1758…-0".
  final String value;

  bool get isMine => value.startsWith('p:');

  /// The title or id inside the reference.
  String get name => value.substring(2);

  @override
  bool operator ==(Object other) => other is TuneRef && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// A list of tunes in the order they'll be played: a gig, a lesson, or the
/// half-dozen a player is working on this month.
class Setlist {
  Setlist({required this.id, required this.name, List<TuneRef>? tunes})
    : tunes = [...?tunes];

  factory Setlist.fromJson(Map<String, dynamic> json) => Setlist(
    id: json['id'] as String,
    name: json['name'] as String,
    tunes: [for (final ref in json['tunes'] as List) TuneRef(ref as String)],
  );

  final String id;
  String name;

  /// In the order they're played. A tune can only be in a setlist once.
  final List<TuneRef> tunes;

  String get displayName => name.trim().isEmpty ? 'Untitled Setlist' : name;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'tunes': [for (final ref in tunes) ref.value],
  };
}

/// A tune, and when it was last opened.
typedef Played = ({TuneRef tune, DateTime at});

/// Favourites, recently played and setlists, saved on the device.
class LibraryStore extends ChangeNotifier {
  LibraryStore._(
    this._storage,
    this._favourites,
    this._played,
    this._setlists,
    this._styles,
    this._runs,
  );

  /// Nothing saved anywhere, for tests.
  LibraryStore.inMemory({
    Set<TuneRef>? favourites,
    List<Played>? played,
    List<Setlist>? setlists,
    Map<TuneRef, BandStyle>? styles,
    Map<TuneRef, List<Run>>? runs,
  }) : _storage = MemoryStorage(),
       _favourites = {...?favourites},
       _played = [...?played],
       _setlists = [...?setlists],
       _styles = {...?styles},
       _runs = {...?runs};

  /// How far back the recently-played list goes. Long enough to find last
  /// week's practice, short enough to still be a shortcut.
  static const remembers = 20;

  /// Reads the saved library. If it can't be read, starts empty rather than
  /// stopping the app.
  static Future<LibraryStore> load([TextStorage? storage]) async {
    final store = storage ?? preferencesStorage('library');
    final favourites = <TuneRef>{};
    final played = <Played>[];
    final setlists = <Setlist>[];
    final styles = <TuneRef, BandStyle>{};
    final runs = <TuneRef, List<Run>>{};
    try {
      final text = await store.read();
      if (text != null) {
        final json = jsonDecode(text) as Map<String, dynamic>;
        favourites.addAll(readFavourites(json));
        played.addAll(readPlayed(json));
        setlists.addAll(readSetlists(json));
        styles.addAll(readStyles(json));
        runs.addAll(readRuns(json));
      }
    } catch (e) {
      debugPrint('Could not read the saved library: $e');
    }
    return LibraryStore._(store, favourites, played, setlists, styles, runs);
  }

  // Reading what was saved is shared with restoring from a backup file.

  /// How the player has chosen to have each tune played, where that isn't
  /// the way it was written. Anything unreadable is dropped rather than
  /// losing the rest of the library with it.
  static Map<TuneRef, BandStyle> readStyles(Map<String, dynamic> json) {
    final styles = <TuneRef, BandStyle>{};
    for (final entry in (json['styles'] as Map? ?? const {}).entries) {
      final parts = (entry.value as List).cast<String>();
      final drums = Feel.values.where((f) => f.name == parts[0]);
      final bass = BassStyle.values.where((b) => b.name == parts[1]);
      final piano = PianoStyle.values.where((p) => p.name == parts[2]);
      if (drums.isEmpty || bass.isEmpty || piano.isEmpty) continue;
      // The figure came later and the swing later still, so anything
      // written before either has fewer parts and nothing to read. The
      // swing is tagged rather than positional: with the figure optional,
      // a bare fourth value could be either of them.
      final extra = parts.skip(3);
      final swung = extra.where((part) => part.startsWith('swing:'));
      final named = extra.where((part) => !part.startsWith('swing:'));
      final figure = named.isEmpty
          ? const <CompFigure>[]
          : CompFigure.values.where((f) => f.name == named.first);
      styles[TuneRef(entry.key as String)] = BandStyle(
        drums: drums.first,
        bass: bass.first,
        piano: piano.first,
        figure: figure.isEmpty ? null : figure.first,
        swing: swung.isEmpty ? null : double.tryParse(swung.first.substring(6)),
      );
    }
    return styles;
  }

  /// Every run at every tune. Written as bare lists rather than named
  /// fields because there are a great many of them and they are all the
  /// same shape. Anything that doesn't read is dropped: a practice record
  /// is not worth losing the rest of the library over.
  static Map<TuneRef, List<Run>> readRuns(Map<String, dynamic> json) {
    final runs = <TuneRef, List<Run>>{};
    for (final entry in (json['runs'] as Map? ?? const {}).entries) {
      final forTune = <Run>[];
      for (final run in entry.value as List? ?? const []) {
        final parts = (run as List).cast<num>();
        if (parts.length < 4) continue;
        forTune.add((
          at: DateTime.fromMillisecondsSinceEpoch(parts[0].toInt()),
          tempo: parts[1].toInt(),
          asked: parts[2].toInt(),
          hits: parts[3].toInt(),
        ));
      }
      if (forTune.isNotEmpty) runs[TuneRef(entry.key as String)] = forTune;
    }
    return runs;
  }

  static Iterable<TuneRef> readFavourites(Map<String, dynamic> json) => [
    for (final ref in json['favourites'] as List? ?? const [])
      TuneRef(ref as String),
  ];

  static Iterable<Played> readPlayed(Map<String, dynamic> json) => [
    for (final entry in json['played'] as List? ?? const [])
      (
        tune: TuneRef((entry as Map)['tune'] as String),
        at: DateTime.fromMillisecondsSinceEpoch(entry['at'] as int),
      ),
  ];

  static Iterable<Setlist> readSetlists(Map<String, dynamic> json) => [
    for (final list in json['setlists'] as List? ?? const [])
      Setlist.fromJson(list as Map<String, dynamic>),
  ];

  final TextStorage _storage;
  final Set<TuneRef> _favourites;
  final List<Played> _played;
  final List<Setlist> _setlists;

  /// Tunes the player has chosen to have played another way, by [TuneRef].
  final Map<TuneRef, BandStyle> _styles;

  /// Every run at each tune, newest first: the practice record.
  final Map<TuneRef, List<Run>> _runs;

  Set<TuneRef> get favourites => {..._favourites};

  /// Newest first.
  List<Played> get played => [..._played];

  List<Setlist> get setlists => [..._setlists];

  Setlist? setlistById(String id) =>
      _setlists.where((list) => list.id == id).firstOrNull;

  bool isFavourite(TuneRef tune) => _favourites.contains(tune);

  Future<void> setFavourite(TuneRef tune, bool on) async {
    if (on == isFavourite(tune)) return;
    if (on) {
      _favourites.add(tune);
    } else {
      _favourites.remove(tune);
    }
    notifyListeners();
    await _write();
  }

  Future<void> toggleFavourite(TuneRef tune) =>
      setFavourite(tune, !isFavourite(tune));

  /// Notes that [tune] has just been opened. Playing the same tune twice
  /// running moves it up rather than listing it twice.
  Future<void> justPlayed(TuneRef tune, {DateTime? at}) async {
    _played.removeWhere((entry) => entry.tune == tune);
    _played.insert(0, (tune: tune, at: at ?? DateTime.now()));
    if (_played.length > remembers) {
      _played.removeRange(remembers, _played.length);
    }
    notifyListeners();
    await _write();
  }

  /// Every run at [tune], newest first.
  List<Run> runsFor(TuneRef tune) => [...?_runs[tune]];

  /// Notes a run at [tune]: how fast it was and how it was marked.
  ///
  /// A run nobody could learn anything from isn't kept: you start the
  /// band, change your mind and stop, and that is not practice. With the
  /// microphone off there is nothing to judge that by, so the test is
  /// simply whether anything was marked or the tune was left running.
  Future<void> noteRun(TuneRef tune, Run run) async {
    _runs[tune] = withRun(runsFor(tune), run);
    notifyListeners();
    await _write();
  }

  Future<void> clearRuns(TuneRef tune) async {
    if (_runs.remove(tune) == null) return;
    notifyListeners();
    await _write();
  }

  Future<void> clearPlayed() async {
    if (_played.isEmpty) return;
    _played.clear();
    notifyListeners();
    await _write();
  }

  /// A new id that isn't in use, unique even when two are made in the same
  /// instant.
  String newId() => '${DateTime.now().microsecondsSinceEpoch}-${_made++}';
  var _made = 0;

  Future<Setlist> addSetlist(String name) async {
    final list = Setlist(id: newId(), name: name);
    _setlists.add(list);
    notifyListeners();
    await _write();
    return list;
  }

  Future<void> renameSetlist(String id, String name) async {
    final list = setlistById(id);
    if (list == null || list.name == name) return;
    list.name = name;
    notifyListeners();
    await _write();
  }

  Future<void> deleteSetlist(String id) async {
    _setlists.removeWhere((list) => list.id == id);
    notifyListeners();
    await _write();
  }

  /// Puts [tune] at the end of the setlist, or takes it out. A tune that's
  /// already in it stays where it is.
  Future<void> setInSetlist(String id, TuneRef tune, bool inIt) async {
    final list = setlistById(id);
    if (list == null) return;
    if (inIt) {
      if (list.tunes.contains(tune)) return;
      list.tunes.add(tune);
    } else {
      if (!list.tunes.remove(tune)) return;
    }
    notifyListeners();
    await _write();
  }

  /// Moves the tune at [from] to [to], as dragging it up or down the list.
  Future<void> moveInSetlist(String id, int from, int to) async {
    final list = setlistById(id);
    if (list == null || from == to) return;
    if (from < 0 || from >= list.tunes.length) return;
    final tune = list.tunes.removeAt(from);
    list.tunes.insert(to.clamp(0, list.tunes.length), tune);
    notifyListeners();
    await _write();
  }

  /// The setlists [tune] is in.
  List<Setlist> setlistsWith(TuneRef tune) => [
    for (final list in _setlists)
      if (list.tunes.contains(tune)) list,
  ];

  /// Forgets a progression the player has deleted, so it doesn't sit in a
  /// setlist as a tune that no longer exists.
  Future<void> forget(Iterable<TuneRef> tunes) async {
    final gone = tunes.toSet();
    if (gone.isEmpty) return;
    _favourites.removeAll(gone);
    _played.removeWhere((entry) => gone.contains(entry.tune));
    for (final list in _setlists) {
      list.tunes.removeWhere(gone.contains);
    }
    notifyListeners();
    await _write();
  }

  /// Everything, as it's saved; also what goes into a backup file.
  /// How [ref] should be played, or null to play it as it was written.
  BandStyle? styleFor(TuneRef ref) => _styles[ref];

  /// Plays [ref] this way from now on. A null [style] puts it back to the
  /// way the tune was written.
  void setStyle(TuneRef ref, BandStyle? style) {
    if (style == null) {
      if (_styles.remove(ref) == null) return;
    } else {
      if (_styles[ref] == style) return;
      _styles[ref] = style;
    }
    _write();
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
    'favourites': [for (final ref in _favourites) ref.value],
    'played': [
      for (final entry in _played)
        {'tune': entry.tune.value, 'at': entry.at.millisecondsSinceEpoch},
    ],
    'setlists': [for (final list in _setlists) list.toJson()],
    'runs': {
      for (final entry in _runs.entries)
        entry.key.value: [
          for (final run in entry.value)
            [run.at.millisecondsSinceEpoch, run.tempo, run.asked, run.hits],
        ],
    },
    'styles': {
      for (final entry in _styles.entries)
        entry.key.value: [
          entry.value.drums.name,
          entry.value.bass.name,
          entry.value.piano.name,
          if (entry.value.figure case final figure?) figure.name,
          if (entry.value.swing case final swing?) 'swing:$swing',
        ],
    },
  };

  /// Replaces the lot with what's in [json], restoring a backup.
  Future<void> replaceWith(Map<String, dynamic> json) async {
    _favourites
      ..clear()
      ..addAll(readFavourites(json));
    _played
      ..clear()
      ..addAll(readPlayed(json));
    _setlists
      ..clear()
      ..addAll(readSetlists(json));
    _styles
      ..clear()
      ..addAll(readStyles(json));
    notifyListeners();
    await _write();
  }

  Future<void> _write() async {
    try {
      await _storage.write(jsonEncode(toJson()));
    } catch (e) {
      debugPrint('Could not save the library: $e');
    }
  }
}

/// How a list of tunes is put in order.
enum TuneOrder {
  title('Title'),
  key('Key'),
  tempo('Tempo'),
  composer('Composer');

  const TuneOrder(this.label);

  final String label;

  /// Whether a list in this order runs A to Z, and so can have a letter
  /// strip beside it. Key and tempo don't.
  bool get hasAnAlphabet => this == title || this == composer;
}

/// The circle of fifths, which is the order a musician thinks of keys in:
/// C, F, B♭ … round to B. Sorting alphabetically would put A♭ next to A,
/// which are nothing like each other to play.
const _keyOrder = [
  'C', 'F', 'B♭', 'E♭', 'A♭', 'D♭', 'G♭', 'B', 'E', 'A', 'D', 'G', //
];

/// Where [key] sits in the circle of fifths, minors after the majors so a
/// sort by key lists the major keys first and then the minor ones.
int keyRank(String key) {
  final tonic = RegExp(r'^[A-G][♭♯b#]?').stringMatch(key) ?? 'C';
  final spelled = tonic.replaceAll('b', '♭').replaceAll('#', '♯');
  // A Dorian key (So What's D Dorian) is a minor key to a player, and the
  // rest of the app treats it as one.
  final minor = key.toLowerCase().contains('minor') || key.contains('Dorian');
  // Spelled the other way round from the list (A♯ rather than B♭).
  final at = _keyOrder.indexOf(spelled);
  final rank = at == -1 ? _keyOrder.length : at;
  return (minor ? _keyOrder.length + 1 : 0) + rank;
}

/// The bits of a name that belong to the surname rather than in front of
/// it: Gene de Paul is filed under D, Jimmy Van Heusen under V.
const _particles = {
  'de', 'del', 'della', 'da', 'das', 'di', 'do', 'dos', 'du', //
  'van', 'von', 'der', 'den', 'ten', 'ter', 'la', 'le', 'los',
};

/// Credits that are a band rather than a person, and so have no surname to
/// take: the New Orleans Rhythm Kings are filed under N, not under Kings.
///
/// There's no telling a band from a person by looking (plenty of people
/// are called King), so the few in the book are simply named here.
const _bands = {'new orleans rhythm kings'};

/// The name a composer is filed under: their surname, as a book's index of
/// composers would have it. Thelonious Monk goes under Monk, not Thelonious.
///
/// Where two are credited, the first one names the entry (Dizzy Gillespie
/// & Chano Pozo is under Gillespie) because that's the one anybody would
/// look for.
String filedUnder(String? composer) {
  final first = (composer ?? '').split(RegExp(r'\s*[&/]\s*')).first.trim();
  if (first.isEmpty) return '';
  // A band is read from its first word, the way it's said.
  if (_bands.contains(first.toLowerCase())) return first;
  final words = first.split(RegExp(r'\s+'));
  var start = words.length - 1;
  while (start > 0 &&
      _particles.contains(words[start - 1].toLowerCase().replaceAll('.', ''))) {
    start--;
  }
  return words.sublist(start).join(' ');
}

/// A composer written the way an index writes them: "Monk, Thelonious".
///
/// Only where one person is credited. Two names turned round would read
/// worse than they do as written, and a band isn't a surname at all.
String indexName(String? composer) {
  final name = composer?.trim() ?? '';
  final surname = filedUnder(name);
  if (name.isEmpty || surname == name || name.contains(RegExp(r'[&/]'))) {
    return name;
  }
  return '$surname, ${name.substring(0, name.length - surname.length).trim()}';
}

/// How a composer sorts: by surname, and nobody-in-particular last.
String _composerRank(String? composer) {
  final surname = filedUnder(composer);
  // '~' is past every letter, so uncredited tunes fall off the end.
  return surname.isEmpty ? '~' : '${surname.toLowerCase()} $composer';
}

/// [tunes] in [order]. Ties fall back to the title so the list doesn't
/// shuffle about between rebuilds.
List<Tune> sortedTunes(Iterable<Tune> tunes, TuneOrder order) {
  int byTitle(Tune a, Tune b) =>
      a.title.toLowerCase().compareTo(b.title.toLowerCase());
  final sorted = [...tunes];
  sorted.sort((a, b) {
    final first = switch (order) {
      TuneOrder.title => 0,
      TuneOrder.key => keyRank(a.key).compareTo(keyRank(b.key)),
      TuneOrder.tempo => a.defaultTempo.compareTo(b.defaultTempo),
      TuneOrder.composer => _composerRank(
        a.composer,
      ).compareTo(_composerRank(b.composer)),
    };
    return first != 0 ? first : byTitle(a, b);
  });
  return sorted;
}

/// The player's own progressions in [order].
List<UserProgression> sortedProgressions(
  Iterable<UserProgression> progressions,
  TuneOrder order,
) {
  int byTitle(UserProgression a, UserProgression b) =>
      a.displayTitle.toLowerCase().compareTo(b.displayTitle.toLowerCase());
  final sorted = [...progressions];
  sorted.sort((a, b) {
    final first = switch (order) {
      TuneOrder.title => 0,
      TuneOrder.key => keyRank(a.key).compareTo(keyRank(b.key)),
      TuneOrder.tempo => a.tempo.compareTo(b.tempo),
      TuneOrder.composer => _composerRank(
        a.composer,
      ).compareTo(_composerRank(b.composer)),
    };
    return first != 0 ? first : byTitle(a, b);
  });
  return sorted;
}
