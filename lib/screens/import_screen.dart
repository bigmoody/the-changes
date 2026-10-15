// Bringing charts in from iReal Pro: a link, one song or a whole
// playlist, see what's in it, choose, and they're saved to My Changes,
// to play and edit like any of your own.
//
// The link arrives by being shared to the app, by being tapped, or by
// being pasted. Which of those is available is not the player's choice:
// on a phone or tablet iReal Pro will not hand a playlist's link to the
// clipboard, so sharing is the route, and on a computer it will, so a
// link copied there can be pasted here. The screen says so, because a
// paste box with nothing to paste into it reads as a broken feature
// rather than as the wrong half of one.
//
// It reads only what the player hands it, on the phone: nothing is
// downloaded, and nothing leaves the phone.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../music/ireal_import.dart';
import '../settings/progression_store.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key, required this.store, this.handed});

  final ProgressionStore store;

  /// A link handed to the app from somewhere else, rather than pasted.
  /// Read on the way in, so the songs are already there to choose from.
  final String? handed;

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _text = TextEditingController();
  var _songs = <ImportedSong>[];

  /// Which songs will be imported, by their place in [_songs].
  final _chosen = <int>{};

  /// Titles already in My Changes: those songs start unticked.
  late final _existing = {
    for (final p in widget.store.all) p.displayTitle.toLowerCase(),
  };

  @override
  void initState() {
    super.initState();
    final handed = widget.handed;
    if (handed != null) {
      _text.text = handed;
      _read(handed);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _read(String text) => setState(() {
    _songs = parseIrealPro(text);
    _chosen
      ..clear()
      ..addAll([
        for (var i = 0; i < _songs.length; i++)
          if (!_isAlreadyIn(_songs[i])) i,
      ]);
  });

  bool _isAlreadyIn(ImportedSong song) =>
      _existing.contains(song.progression.displayTitle.toLowerCase());

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    _text.text = text;
    _read(text);
  }

  Future<void> _import() async {
    final songs = [
      for (var i = 0; i < _songs.length; i++)
        if (_chosen.contains(i)) _songs[i].progression,
    ];
    await widget.store.addAll(songs);
    if (mounted) Navigator.of(context).pop(songs.length);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final count = _chosen.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Import')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text('From iReal Pro', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Share a song or a playlist to The Changes, or tap its link, '
            'and it opens here. That is the way on a phone or tablet, '
            'where iReal Pro will not let you copy a link out of a '
            'playlist. On a computer it will, so you can copy one there '
            'and paste it below. Every song in it comes in, sections, '
            'repeats and endings included.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('import-text'),
            controller: _text,
            minLines: 3,
            maxLines: 5,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(hintText: 'irealb://…'),
            onChanged: _read,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey('import-paste'),
              icon: const Icon(Icons.content_paste),
              label: const Text('Paste'),
              onPressed: _paste,
            ),
          ),
          const SizedBox(height: 16),
          if (_text.text.trim().isNotEmpty && _songs.isEmpty)
            Text(
              'No iReal Pro songs found in that. Paste the whole link: it '
              'starts irealb://. On a phone or tablet you cannot copy '
              'one, so share the song or playlist to The Changes '
              'instead, or copy the link in iReal Pro on a computer.',
              style: muted,
            ),
          if (_songs.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    _songs.length == 1
                        ? 'Found 1 Song'
                        : 'Found ${_songs.length} Songs',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    if (count == _songs.length) {
                      _chosen.clear();
                    } else {
                      _chosen.addAll([
                        for (var i = 0; i < _songs.length; i++) i,
                      ]);
                    }
                  }),
                  child: Text(count == _songs.length ? 'None' : 'All'),
                ),
              ],
            ),
            for (final (i, song) in _songs.indexed)
              CheckboxListTile(
                key: ValueKey('import-song-$i'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _chosen.contains(i),
                onChanged: (on) => setState(
                  () => on == true ? _chosen.add(i) : _chosen.remove(i),
                ),
                title: Text(song.progression.displayTitle),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [
                        ?song.progression.composer,
                        song.progression.key,
                        if (song.progression.beatsPerBar != 4)
                          song.progression.meter,
                        if (song.style.isNotEmpty) song.style,
                      ].join(' · '),
                    ),
                    for (final note in [
                      if (_isAlreadyIn(song)) 'Already in My Changes',
                      ...song.notes,
                    ])
                      Text(note, style: TextStyle(color: scheme.tertiary)),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 24),
          Text(
            'Import only charts you have the right to use. They stay on '
            'this phone. iReal Pro is a trademark of its owner; The Changes '
            'isn\'t affiliated with it.',
            style: muted,
          ),
        ],
      ),
      bottomNavigationBar: _songs.isEmpty
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton(
                key: const ValueKey('import-go'),
                onPressed: count == 0 ? null : _import,
                child: Text(
                  count == 1 ? 'Import 1 Song' : 'Import $count Songs',
                ),
              ),
            ),
    );
  }
}
