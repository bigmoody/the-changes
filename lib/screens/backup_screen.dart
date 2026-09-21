// Backing up what the player has made, and putting it back.
//
// Everything in The Changes lives on the one phone, which is fine until the
// phone isn't. This screen is the way off it: one file holding the
// progressions they've written, their setlists and what they've starred,
// saved wherever they keep things, and the way back in again, on this
// phone or on the next one.
//
// Both halves sit on one page on purpose. Someone who has come here to put
// a backup back sees, on the way past, how to make the next one.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../library/backup.dart';
import '../library/library_store.dart';
import '../settings/progression_store.dart';
import 'tunes_page.dart' show SectionHeader;

class BackupScreen extends StatefulWidget {
  const BackupScreen({
    super.key,
    required this.progressions,
    required this.library,
    this.takeCount = 0,
  });

  final ProgressionStore progressions;
  final LibraryStore library;

  /// How many takes are on the phone. A backup doesn't carry them, so the
  /// screen says so plainly rather than letting the player find out on a
  /// new phone.
  final int takeCount;

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _text = TextEditingController();

  /// The pasted text, once it reads as a backup.
  Backup? _backup;

  /// Why the pasted text isn't a backup, in the words [readBackup] used;
  /// they're already written for the player rather than for a log.
  String? _problem;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String _wholeBackup() => backupText(
    progressions: widget.progressions.all,
    library: widget.library,
    takesLeftBehind: widget.takeCount,
  );

  /// What a backup made this minute would hold, said the way a pasted
  /// backup describes itself, so the two lines can be read against each
  /// other without translating between them.
  String get _hereNow => Backup(
    made: null,
    progressions: widget.progressions.all,
    library: widget.library.toJson(),
  ).describe;

  /// Writes the backup to a file the share sheet can hand on to iCloud
  /// Drive, Files or Mail. The file goes in the temporary folder because
  /// the copy that matters is wherever the player puts it.
  Future<void> _save() async {
    final name = backupFileName();
    try {
      final folder = await getTemporaryDirectory();
      final file = File('${folder.path}/$name');
      await file.writeAsString(_wholeBackup());
      // The share sheet comes last, so everything that can fail quietly
      // (gathering the text, writing the file) has already happened by the
      // time the player is looking at somewhere to put it.
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          fileNameOverrides: [name],
          subject: name,
        ),
      );
    } catch (e) {
      debugPrint('Could not write the backup: $e');
      _say("Couldn't write the backup file.");
    }
  }

  /// The same text on the clipboard, for a player who'd rather paste it
  /// into a note or a message than deal with a file.
  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _wholeBackup()));
    _say('Backup copied');
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Reads what's in the box on every keystroke, so the player sees what
  /// they've pasted before either button is within reach.
  void _read(String text) => setState(() {
    _backup = null;
    _problem = null;
    if (text.trim().isEmpty) return;
    try {
      _backup = readBackup(text);
    } on NotABackup catch (e) {
      _problem = e.message;
    }
  });

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    _text.text = text;
    _read(text);
  }

  /// The safe half: the progressions in the backup come in beside what's
  /// already here, each with a fresh id, so nothing on the phone is
  /// touched. Setlists and stars are deliberately left out; merging two
  /// libraries would half-work without saying which half.
  Future<void> _add() async {
    final backup = _backup;
    if (backup == null) return;
    await widget.progressions.addAll(backup.progressions);
    if (mounted) Navigator.of(context).pop(backup.progressions.length);
  }

  /// The other half: the backup becomes the library, and what was here is
  /// gone. Worth asking about, and worth naming what goes.
  Future<void> _replace() async {
    final backup = _backup;
    if (backup == null) return;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace Everything?'),
        content: Text(_whatGoes()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Replace Everything'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    await widget.progressions.replaceAllWith(backup.progressions);
    await widget.library.replaceWith(backup.library);
    if (mounted) Navigator.of(context).pop(backup.progressions.length);
  }

  /// What's on the phone now, counted and named, so nobody agrees to lose
  /// something they'd forgotten was there.
  String _whatGoes() {
    final progressions = widget.progressions.all.length;
    final setlists = widget.library.setlists.length;
    final parts = [
      if (progressions > 0) _count(progressions, 'progression'),
      if (setlists > 0) _count(setlists, 'setlist'),
    ];
    if (parts.isEmpty) {
      return "There's nothing on this phone yet, so nothing will be lost.";
    }
    return 'The ${parts.join(' and ')} on this phone will be replaced.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final backup = _backup;
    final coming = backup?.progressions.length ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Back Up & Restore')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const SectionHeader('Back Up'),
          const _Note(
            'A backup is one file holding what you\'ve made here: the '
            'progressions you\'ve written, your setlists and what you\'ve '
            'starred. Keep it somewhere that outlives this phone: iCloud '
            'Drive, Files, or an email to yourself.',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Right now that\'s $_hereNow',
              style: theme.textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                FilledButton(
                  key: const ValueKey('backup-save'),
                  onPressed: _save,
                  child: const Text('Save Backup…'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  key: const ValueKey('backup-copy'),
                  onPressed: _copy,
                  child: const Text('Copy'),
                ),
              ],
            ),
          ),
          const _Note(
            'The standards aren\'t in it. They come with the app, so a '
            'backup only has to hold what you couldn\'t write again.',
          ),
          if (widget.takeCount > 0)
            _Note(
              'Your ${_count(widget.takeCount, 'take')} aren\'t in it '
              'either. They\'re audio rather than text, and they stay on '
              'this phone.',
            ),
          const _Note(
            'If iCloud Backup is switched on for this phone, iOS is already '
            'saving all of this along with everything else on it. A file is '
            'for the times that isn\'t enough: a phone set up from scratch, '
            'or wanting a copy you can put your hands on.',
          ),
          const SectionHeader('Restore'),
          const _Note(
            'Paste a backup here: the whole thing. Nothing changes until '
            'you choose what to do with it.',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              key: const ValueKey('restore-text'),
              controller: _text,
              minLines: 3,
              maxLines: 5,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                hintText: '{ "app": "the-changes-backup" …',
              ),
              onChanged: _read,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const ValueKey('restore-paste'),
                icon: const Icon(Icons.content_paste),
                label: const Text('Paste'),
                onPressed: _paste,
              ),
            ),
          ),
          if (_problem case final problem?) _Note(problem),
          if (backup != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text('In That Backup', style: theme.textTheme.titleMedium),
            ),
            _Note(
              [
                backup.describe,
                if (backup.made case final made?) 'Made ${_when(made)}',
              ].join('\n'),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  key: const ValueKey('restore-add'),
                  onPressed: coming == 0 ? null : _add,
                  child: const Text('Add To What\'s Here'),
                ),
              ),
            ),
            _Note(
              coming == 0
                  ? 'There are no progressions in that backup, so there\'s '
                        'nothing to add.'
                  : 'Puts the ${_count(coming, 'progression')} from the '
                        'backup beside what\'s already in My Changes. '
                        'Nothing here is overwritten, and your setlists and '
                        'stars are left exactly as they are.',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  key: const ValueKey('restore-replace'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                  ),
                  onPressed: _replace,
                  child: const Text('Replace Everything'),
                ),
              ),
            ),
            const _Note(
              'Puts the backup in place of what\'s on this phone: '
              'progressions, setlists and stars. What\'s here now goes. '
              'This is the one for a phone you\'ve just set up.',
            ),
          ],
        ],
      ),
    );
  }
}

/// "3 setlists", "1 setlist". Worth getting right in a sentence that's
/// telling someone what they're about to lose.
String _count(int howMany, String thing) =>
    '$howMany $thing${howMany == 1 ? '' : 's'}';

/// "19 Sep 2026 at 14:32", enough for the player to tell one backup from
/// another, which is all the date is for.
String _when(DateTime at) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final clock =
      '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}';
  return '${at.day} ${months[at.month - 1]} ${at.year} at $clock';
}

/// A line of explanation under something, in the quieter ink the rest of
/// the app uses for the same job.
class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
