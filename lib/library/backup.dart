// A backup of everything the player has made: their own progressions and
// the way they've organised the book.
//
// Everything in the app lives on the one phone, which is fine until the
// phone doesn't. A backup is a single piece of JSON the player can put
// wherever they keep things — iCloud Drive, Files, an email to themselves —
// and read back into the app, on this phone or a new one.
//
// The standards aren't in it: they come with the app, so a backup only has
// to hold what the player couldn't write again. That keeps the file small
// enough to paste.
//
// Takes aren't in it either. They're audio files rather than text, and a
// take is a moment rather than something you'd want carried between
// phones; the backup says how many were left behind so nobody is misled.

import 'dart:convert';

import '../music/user_progression.dart';
import 'library_store.dart';

/// What a backup file says it is, so a file that isn't one is turned away
/// rather than half-read.
const _marker = 'the-changes-backup';

/// Bumped if the shape of the file ever changes in a way an older app
/// couldn't read.
const _version = 1;

/// Everything worth keeping, as text to save somewhere safe.
String backupText({
  required List<UserProgression> progressions,
  required LibraryStore library,
  DateTime? at,
  int takesLeftBehind = 0,
}) => const JsonEncoder.withIndent('  ').convert({
  'app': _marker,
  'version': _version,
  'made': (at ?? DateTime.now()).toIso8601String(),
  'progressions': [for (final p in progressions) p.toJson()],
  'library': library.toJson(),
  if (takesLeftBehind > 0) 'takesNotIncluded': takesLeftBehind,
});

/// A backup that's been read and understood, ready to put back.
class Backup {
  Backup({
    required this.made,
    required this.progressions,
    required this.library,
  });

  final DateTime? made;
  final List<UserProgression> progressions;

  /// Favourites, recently played and setlists, in the shape [LibraryStore]
  /// saves them.
  final Map<String, dynamic> library;

  int get favourites => (library['favourites'] as List? ?? const []).length;
  int get setlists => (library['setlists'] as List? ?? const []).length;

  /// What's in it, for the player to read before they replace anything.
  String get describe {
    final parts = [
      progressions.length == 1
          ? '1 progression'
          : '${progressions.length} progressions',
      if (setlists > 0) setlists == 1 ? '1 setlist' : '$setlists setlists',
      if (favourites > 0) '$favourites starred',
    ];
    return parts.join(' · ');
  }
}

/// Why a piece of text isn't a backup.
class NotABackup implements Exception {
  NotABackup(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Reads [text] as a backup file, or says why it isn't one.
Backup readBackup(String text) {
  Object? json;
  try {
    json = jsonDecode(text.trim());
  } on FormatException {
    throw NotABackup("That isn't a backup file — paste the whole thing.");
  }
  if (json is! Map<String, dynamic> || json['app'] != _marker) {
    throw NotABackup("That isn't a backup from The Changes.");
  }
  if ((json['version'] as num? ?? 0) > _version) {
    throw NotABackup('That backup was made by a newer version of the app.');
  }
  final progressions = <UserProgression>[];
  try {
    for (final saved in json['progressions'] as List? ?? const []) {
      progressions.add(UserProgression.fromJson(saved as Map<String, dynamic>));
    }
  } catch (e) {
    throw NotABackup("The progressions in that file couldn't be read.");
  }
  return Backup(
    made: DateTime.tryParse(json['made'] as String? ?? ''),
    progressions: progressions,
    library: json['library'] as Map<String, dynamic>? ?? const {},
  );
}

/// "The Changes backup 2026-09-20.json", fit to be a filename.
String backupFileName([DateTime? at]) {
  final day = (at ?? DateTime.now()).toIso8601String().split('T').first;
  return 'The Changes backup $day.json';
}
