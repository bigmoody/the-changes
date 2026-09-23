// Writing your own progression: bars of chords, a key, a tempo, and what
// each instrument in the band plays.
//
// Chords can be typed ("Dm7 G7") or built by tapping a root and then a chord
// type, for anyone who'd rather not hunt for ♭ and Δ on a phone keyboard.

import 'package:flutter/material.dart';

import '../audio/practice_player.dart';
import '../music/chord.dart';
import '../music/tune.dart';
import '../music/user_progression.dart';
import '../settings/app_settings.dart';
import '../settings/progression_store.dart';
import '../theme.dart';
import 'practice_screen.dart';

/// Asks before deleting [progression]: true if the player said yes.
Future<bool> confirmDelete(BuildContext context, UserProgression progression) =>
    _confirm(
      context,
      title: 'Delete "${progression.displayTitle}"?',
      message: "Are you sure? It can't be brought back.",
    );

/// Asks before deleting [count] progressions at once.
Future<bool> confirmDeleteMany(BuildContext context, int count) => _confirm(
  context,
  title: count == 1 ? 'Delete 1 progression?' : 'Delete $count progressions?',
  message: count == 1
      ? "Are you sure? It can't be brought back."
      : "Are you sure? They can't be brought back.",
);

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ??
    false;

/// How the editor was left, for whoever opened it.
enum EditorOutcome { saved, deleted }

class ProgressionEditorScreen extends StatefulWidget {
  const ProgressionEditorScreen({
    super.key,
    required this.store,
    required this.player,
    required this.settings,
    this.existing,
    this.fromPractice = false,
  });

  final ProgressionStore store;
  final PracticePlayer player;
  final AppSettings settings;

  /// The progression being edited, or null to write a new one.
  final UserProgression? existing;

  /// Opened from the progression's own practice screen: saving goes back
  /// there rather than opening another one.
  final bool fromPractice;

  @override
  State<ProgressionEditorScreen> createState() =>
      _ProgressionEditorScreenState();
}

class _ProgressionEditorScreenState extends State<ProgressionEditorScreen> {
  // Edits go to a copy; nothing is saved until Save is pressed.
  late final UserProgression _draft = widget.existing == null
      ? UserProgression.starter(id: widget.store.newId())
      : UserProgression.fromJson(widget.existing!.toJson());
  late final _name = TextEditingController(text: _draft.title);
  var _changed = false;

  /// Until the key is picked by hand, it follows the chords.
  late var _keyChosen = !_isNew;

  void _followChords() {
    if (!_keyChosen) _draft.key = UserProgression.guessKey(_draft.bars);
  }

  bool get _isNew => widget.existing == null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _edit(VoidCallback change) => setState(() {
    change();
    _changed = true;
  });

  Future<bool> _save() async {
    if (!_draft.isPlayable) return false;
    _draft.title = _name.text.trim();
    await widget.store.save(_draft);
    setState(() => _changed = false);
    return true;
  }

  Future<void> _saveAndPlay() async {
    if (!await _save() || !mounted) return;
    if (widget.fromPractice) {
      Navigator.of(context).pop(EditorOutcome.saved);
      return;
    }
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PracticeScreen(
          tune: _draft.toTune(),
          player: widget.player,
          settings: widget.settings,
          progression: widget.store.byId(_draft.id),
          progressions: widget.store,
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final sure = await confirmDelete(context, _draft);
    if (!sure || !mounted) return;
    await widget.store.delete(_draft.id);
    if (mounted) Navigator.of(context).pop(EditorOutcome.deleted);
  }

  /// Asks before throwing away unsaved changes.
  Future<void> _leave() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text("Your changes haven't been saved."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  Future<_BarEdit?> _openBar(
    int number,
    String text, {
    required bool isNew,
    String? section,
    int repeats = 1,
    int? ending,
    bool hasEndings = false,
  }) => showModalBottomSheet<_BarEdit>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _BarSheet(
      number: number,
      text: text,
      section: section,
      repeats: repeats,
      ending: ending,
      hasEndings: hasEndings,
      canDelete: !isNew && _draft.bars.length > 1,
    ),
  );

  /// Opens the sheet on [index] and keeps it open, bar after bar, for as
  /// long as it is asked to carry on. Past the last bar it adds one, so
  /// writing a tune out is a chord and Next Bar the whole way down rather
  /// than closing and reopening the sheet thirty-two times.
  Future<void> _editBar(int index) async {
    var at = index;
    while (at <= _draft.bars.length) {
      // Past the end is a bar that does not exist yet.
      final isNew = at == _draft.bars.length;
      final result = await _openBar(
        at + 1,
        isNew ? '' : _draft.bars[at],
        isNew: isNew,
        section: isNew ? null : _draft.sections[at],
        repeats: isNew ? 1 : _draft.repeatsOf(at),
        ending: isNew ? null : _draft.endings[at],
        hasEndings:
            !isNew && _draft.sections.containsKey(at) && _draft.hasEndings(at),
      );
      if (result == null) return;

      if (isNew) {
        // A new bar is only kept once it has a chord in it, so backing out
        // of one leaves nothing behind.
        if (result.delete || result.text.isEmpty) return;
        _edit(() {
          _draft.bars.add(result.text);
          final added = _draft.bars.length - 1;
          _draft
            ..setSection(added, result.section)
            ..setRepeats(added, result.repeats);
          if (result.section == null) _draft.setEnding(added, result.ending);
          _followChords();
        });
      } else {
        _edit(() {
          if (result.delete) {
            _draft.removeBar(at);
          } else {
            _draft.bars[at] = result.text;
            _draft
              ..setSection(at, result.section)
              ..setRepeats(at, result.repeats);
            if (result.section == null) _draft.setEnding(at, result.ending);
          }
          _followChords();
        });
        // Deleting moves every bar after this one up, so carrying on would
        // land somewhere the player did not ask for.
        if (result.delete) return;
      }

      if (!result.next) return;
      at++;
    }
  }

  /// A new bar starts empty and opens straight away. It's only added once
  /// it has a chord, so closing the sheet leaves nothing behind. With
  /// [section], it starts that section of the form.
  Future<void> _addBar({String? section}) async {
    final result = await _openBar(
      _draft.bars.length + 1,
      '',
      isNew: true,
      section: section,
    );
    if (result == null || result.delete || result.text.isEmpty) return;
    _edit(() {
      _draft.bars.add(result.text);
      final index = _draft.bars.length - 1;
      _draft
        ..setSection(index, result.section)
        ..setRepeats(index, result.repeats);
      if (result.section == null) _draft.setEnding(index, result.ending);
      _followChords();
    });
    // Asked to carry on, so keep going from the bar after the new one.
    if (result.next) await _editBar(_draft.bars.length);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_changed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? 'New Progression' : 'Edit Progression'),
          actions: [
            if (!_isNew)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete',
                onPressed: _delete,
              ),
            TextButton(
              onPressed: _draft.isPlayable && (_changed || _isNew)
                  ? () async {
                      if (await _save() && context.mounted) {
                        Navigator.of(context).pop(EditorOutcome.saved);
                      }
                    }
                  : null,
              child: const Text('Save'),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: FilledButton.icon(
              onPressed: _draft.isPlayable ? _saveAndPlay : null,
              icon: Icon(widget.fromPractice ? Icons.check : Icons.play_arrow),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  widget.fromPractice ? 'Save Changes' : 'Save and Play',
                  style: const TextStyle(fontSize: 17),
                ),
              ),
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Minor blues in A',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() => _changed = true),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(_draft.key),
                    isExpanded: true,
                    initialValue: UserProgression.keys.contains(_draft.key)
                        ? _draft.key
                        : 'C',
                    decoration: const InputDecoration(
                      labelText: 'Key',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final key in UserProgression.keys)
                        DropdownMenuItem(value: key, child: Text(key)),
                    ],
                    onChanged: (key) => _edit(() {
                      _draft.key = key!;
                      _keyChosen = true;
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                // The time signature: 4/4, a waltz, or five.
                SizedBox(
                  width: 112,
                  child: DropdownButtonFormField<int>(
                    key: const ValueKey('meter'),
                    isExpanded: true,
                    initialValue: _draft.beatsPerBar,
                    decoration: const InputDecoration(
                      labelText: 'Time',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final beats in UserProgression.meters)
                        DropdownMenuItem(value: beats, child: Text('$beats/4')),
                    ],
                    onChanged: (beats) =>
                        _edit(() => _draft.beatsPerBar = beats!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Spacer(),
                _TempoStepper(
                  tempo: _draft.tempo,
                  onChanged: (tempo) => _edit(() => _draft.tempo = tempo),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('The Band', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            _Presets(
              onPick: (feel) => _edit(() => _draft.style = BandStyle.of(feel)),
            ),
            const SizedBox(height: 8),
            _StylePicker<Feel>(
              label: 'Drums',
              icon: Icons.album,
              value: _draft.style.drums,
              options: Feel.values,
              name: (feel) => feel.label,
              onChanged: (drums) => _edit(
                () => _draft.style = BandStyle(
                  drums: drums,
                  bass: _draft.style.bass,
                  piano: _draft.style.piano,
                ),
              ),
            ),
            _StylePicker<BassStyle>(
              label: 'Bass',
              icon: Icons.music_note,
              value: _draft.style.bass,
              options: BassStyle.values,
              name: (bass) => bass.label,
              onChanged: (bass) => _edit(
                () => _draft.style = BandStyle(
                  drums: _draft.style.drums,
                  bass: bass,
                  piano: _draft.style.piano,
                ),
              ),
            ),
            _StylePicker<PianoStyle>(
              label: 'Chords',
              icon: Icons.piano,
              value: _draft.style.piano,
              options: PianoStyle.values,
              name: (piano) => piano.label,
              onChanged: (piano) => _edit(
                () => _draft.style = BandStyle(
                  drums: _draft.style.drums,
                  bass: _draft.style.bass,
                  piano: piano,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text('Bars', style: theme.textTheme.titleMedium),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _draft.bars.isEmpty
                        ? 'Tap + to start'
                        : 'Tap a bar to change it',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _BarGrid(
              bars: _draft.bars,
              sections: _draft.sections,
              repeats: _draft.repeats,
              endings: _draft.endings,
              nextSection: _draft.nextSection,
              onTap: _editBar,
              onAdd: _addBar,
              onAddSection: () => _addBar(section: _draft.nextSection),
            ),
            const SizedBox(height: 24),
            Text('File Under', style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              '${Genre.ofFeel(_draft.style.drums).label} (from the drums), '
              'and any of these:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final genre in Genre.tags)
                  FilterChip(
                    key: ValueKey('genre-${genre.name}'),
                    label: Text(genre.label),
                    selected: _draft.tags.contains(genre),
                    onSelected: (on) => _edit(
                      () => on
                          ? _draft.tags.add(genre)
                          : _draft.tags.remove(genre),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick buttons that set the whole band to one feel.
class _Presets extends StatelessWidget {
  const _Presets({required this.onPick});

  final ValueChanged<Feel> onPick;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    children: [
      for (final feel in Feel.values)
        ActionChip(
          label: Text('All ${feel.label.toLowerCase()}'),
          onPressed: () => onPick(feel),
        ),
    ],
  );
}

class _StylePicker<T> extends StatelessWidget {
  const _StylePicker({
    required this.label,
    required this.icon,
    required this.value,
    required this.options,
    required this.name,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final T value;
  final List<T> options;
  final String Function(T) name;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        SizedBox(width: 56, child: Text(label)),
        Expanded(
          child: DropdownButtonFormField<T>(
            // A form field only reads its starting value, so a new key makes
            // it pick up a value set from elsewhere (the presets).
            key: ValueKey(value),
            isExpanded: true,
            initialValue: value,
            isDense: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: [
              for (final option in options)
                DropdownMenuItem(value: option, child: Text(name(option))),
            ],
            onChanged: (value) => onChanged(value as T),
          ),
        ),
      ],
    ),
  );
}

class _TempoStepper extends StatelessWidget {
  const _TempoStepper({required this.tempo, required this.onChanged});

  final int tempo;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        icon: const Icon(Icons.remove),
        tooltip: 'Slower',
        onPressed: tempo > 40 ? () => onChanged(tempo - 5) : null,
      ),
      Text('$tempo BPM', style: Theme.of(context).textTheme.titleMedium),
      IconButton(
        icon: const Icon(Icons.add),
        tooltip: 'Faster',
        onPressed: tempo < 320 ? () => onChanged(tempo + 5) : null,
      ),
    ],
  );
}

/// The bars, four to a row, with tiles at the end to add another bar or
/// start the next section of the form.
class _BarGrid extends StatelessWidget {
  const _BarGrid({
    required this.bars,
    required this.sections,
    required this.repeats,
    required this.endings,
    required this.nextSection,
    required this.onTap,
    required this.onAdd,
    required this.onAddSection,
  });

  final List<String> bars;
  final Map<int, String> sections;
  final Map<int, int> repeats;
  final Map<int, int> endings;
  final String nextSection;
  final ValueChanged<int> onTap;
  final VoidCallback onAdd;
  final VoidCallback onAddSection;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 6.0;
        const columns = 4;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < bars.length; i++)
              SizedBox(
                key: ValueKey('bar-$i'),
                width: width,
                height: 64,
                child: _BarTile(
                  number: i + 1,
                  text: bars[i],
                  section: sections[i],
                  repeats: repeats[i] ?? 1,
                  ending: endings[i],
                  onTap: () => onTap(i),
                ),
              ),
            _AddTile(
              key: const ValueKey('add-bar'),
              width: width,
              label: 'Add a bar',
              onTap: onAdd,
              child: const Icon(Icons.add),
            ),
            // Once there's a bar to follow, the next section can start.
            if (bars.isNotEmpty)
              _AddTile(
                key: const ValueKey('add-section'),
                width: width,
                label: 'Start section $nextSection',
                onTap: onAddSection,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SectionLetter(nextSection, size: 20),
                    const SizedBox(height: 2),
                    Text(
                      'New Section',
                      style: TextStyle(fontSize: 11, color: scheme.onSurface),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A tile at the end of the bars that adds something.
class _AddTile extends StatelessWidget {
  const _AddTile({
    super.key,
    required this.width,
    required this.label,
    required this.onTap,
    required this.child,
  });

  final double width;
  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: 64,
    child: Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Center(child: child),
        ),
      ),
    ),
  );
}

/// A section's rehearsal letter, boxed and hand-lettered as on the chart.
class _SectionLetter extends StatelessWidget {
  const _SectionLetter(this.letter, {super.key, this.size = 14});

  final String letter;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    return Container(
      width: size + 6,
      height: size + 6,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: ink, width: 1.3),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        letter,
        style: handLettered(TextStyle(fontSize: size, color: ink, height: 1)),
      ),
    );
  }
}

class _BarTile extends StatelessWidget {
  const _BarTile({
    required this.number,
    required this.text,
    required this.onTap,
    this.section,
    this.repeats = 1,
    this.ending,
  });

  final int number;
  final String text;
  final VoidCallback onTap;

  /// 1 or 2 if the bar is part of a 1st or 2nd ending.
  final int? ending;

  /// The section this bar starts, if any, and how many times it's played.
  final String? section;
  final int repeats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final problem = UserProgression.problemWith(text);
    final shown = problem == null
        ? UserProgression.symbolsIn(text)
              .map((s) => Chord.parse(s).display)
              .join('  ')
        : text.trim().isEmpty
        ? '?'
        : text;
    return Material(
      color: problem == null ? scheme.primaryContainer : scheme.errorContainer,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Stack(
          children: [
            // An ending bracketed across the top, as on the chart.
            if (ending != null)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Container(
                  key: ValueKey('ending-mark-$number'),
                  height: 3,
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            Positioned(
              left: 5,
              top: ending != null ? 4 : 2,
              child: Text(
                ending != null ? '$number  $ending.' : '$number',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: ending != null ? FontWeight.w800 : null,
                  color: ending != null
                      ? scheme.onSurface
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
            if (section != null)
              Positioned(
                right: 3,
                top: 3,
                child: Semantics(
                  label:
                      'Section $section starts here'
                      '${repeats > 1 ? ', played $repeats times' : ''}',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (repeats > 1)
                        Padding(
                          padding: const EdgeInsets.only(right: 3),
                          child: Text(
                            '×$repeats',
                            key: ValueKey('section-repeat-$section'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      _SectionLetter(
                        section!,
                        key: ValueKey('section-mark-$section'),
                        size: 11,
                      ),
                    ],
                  ),
                ),
              ),
            Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    shown,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the bar sheet hands back: the bar's new chords and the section it
/// starts (if any), or that it's gone.
typedef _BarEdit = ({
  String text,
  bool delete,
  String? section,
  int repeats,
  int? ending,

  /// Whether to carry straight on into the next bar rather than closing.
  /// Writing a tune out is one bar after another, and shutting the sheet
  /// between each of them is most of the work.
  bool next,
});

/// Edits one bar: type chords, or build them from a root and a chord type.
class _BarSheet extends StatefulWidget {
  const _BarSheet({
    required this.number,
    required this.text,
    required this.canDelete,
    this.section,
    this.repeats = 1,
    this.ending,
    this.hasEndings = false,
  });

  final int number;
  final String text;
  final bool canDelete;

  /// 1 or 2 if the bar is part of a 1st or 2nd ending.
  final int? ending;

  /// For a section's first bar: whether the section has 1st and 2nd
  /// endings, which decide how many times it's played.
  final bool hasEndings;

  /// The section this bar starts, if any, and how many times it's played.
  final String? section;
  final int repeats;

  @override
  State<_BarSheet> createState() => _BarSheetState();
}

class _BarSheetState extends State<_BarSheet> {
  late final _field = TextEditingController(text: _pretty(widget.text));
  String? _root;
  late String? _section = widget.section;
  late int _repeats = widget.repeats;
  late int? _ending = widget.ending;

  /// The first chord picked replaces what's in the bar; after that, picks
  /// add further chords to it. Typing in the box works as typing does.
  late var _replaceNext = widget.text.trim().isNotEmpty;

  /// After "/ bass": the next root picked is the bass note of the last chord.
  var _pickingBass = false;

  /// The last chord in the box, if it can take a bass note (it has none).
  bool get _canAddBass {
    final symbols = UserProgression.symbolsIn(_field.text);
    return symbols.isNotEmpty &&
        !symbols.last.contains('/') &&
        UserProgression.problemWith(symbols.last) == null;
  }

  void _setBass(String note) {
    final symbols = UserProgression.symbolsIn(_field.text);
    if (symbols.isEmpty) return;
    setState(() {
      symbols[symbols.length - 1] = '${symbols.last}/$note';
      _field.text = symbols.join(' ');
      _pickingBass = false;
      _root = null;
    });
  }

  static const _roots = [
    'C',
    'D♭',
    'D',
    'E♭',
    'E',
    'F',
    'G♭',
    'G',
    'A♭',
    'A',
    'B♭',
    'B',
  ];

  /// Every chord type the app knows, as written after the root.
  static final _qualities = [
    for (final quality in chordQualities) prettyQuality(quality.symbols.first),
  ];

  /// Chords shown the way they're read (B♭Δ7 rather than Bb^7).
  static String _pretty(String text) =>
      UserProgression.symbolsIn(text)
          .map((s) {
            try {
              return Chord.parse(s).display;
            } on FormatException {
              return s;
            }
          })
          .join(' ');

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _addChord(String quality) {
    final root = _root;
    if (root == null) return;
    final symbols = _replaceNext
        ? <String>[]
        : UserProgression.symbolsIn(_field.text);
    if (symbols.length >= UserProgression.maxChordsPerBar) return;
    setState(() {
      _field.text = [...symbols, '$root$quality'].join(' ');
      _root = null;
      _replaceNext = false;
    });
  }

  void _removeLast() {
    final symbols = UserProgression.symbolsIn(_field.text);
    if (symbols.isEmpty) return;
    setState(() {
      _field.text = (symbols..removeLast()).join(' ');
      _replaceNext = false;
      _pickingBass = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final problem = UserProgression.problemWith(_field.text);
    final full =
        UserProgression.symbolsIn(_field.text).length >=
        UserProgression.maxChordsPerBar;
    return Padding(
      // Stay above the keyboard while typing.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Bar ${widget.number}', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('bar-chords'),
              controller: _field,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'Chords',
                hintText: 'e.g. Dm7 G7',
                helperText: 'Up to four, split evenly across the bar',
                errorText: _field.text.trim().isEmpty ? null : problem,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.backspace_outlined),
                  tooltip: 'Remove the last chord',
                  onPressed: _removeLast,
                ),
              ),
              onChanged: (_) => setState(() {
                _replaceNext = false;
                _pickingBass = false;
              }),
            ),
            const SizedBox(height: 16),
            Text(
              _pickingBass
                  ? '…then the bass note for '
                        '${UserProgression.symbolsIn(_field.text).last}'
                  : _root != null
                  ? '…then a chord type for $_root'
                  : _replaceNext
                  ? 'Or pick a root to change the chord…'
                  : _field.text.trim().isEmpty
                  ? 'Or pick a root…'
                  : 'Pick a root to add another chord to the bar…',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final root in _roots)
                  ChoiceChip(
                    label: Text(root),
                    selected: _root == root,
                    onSelected: _pickingBass
                        ? (_) => _setBass(root)
                        : full
                        ? null
                        : (_) => setState(
                            () => _root = _root == root ? null : root,
                          ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final quality in _qualities)
                  ActionChip(
                    label: Text(quality.isEmpty ? 'major' : quality),
                    onPressed: _root == null || _pickingBass
                        ? null
                        : () => _addChord(quality),
                  ),
                // A slash chord: the last chord over a different bass note.
                FilterChip(
                  key: const ValueKey('slash-bass'),
                  label: const Text('/ bass'),
                  tooltip: 'Put the last chord over a bass note, e.g. FΔ7/C',
                  selected: _pickingBass,
                  onSelected: _canAddBass || _pickingBass
                      ? (_) => setState(() {
                          _pickingBass = !_pickingBass;
                          _root = null;
                          // Adding a bass keeps the chord that's there.
                          _replaceNext = false;
                        })
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Where the form's sections start: A, then B for the bridge…
            Text('Starts Section', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String?>(
                key: const ValueKey('section-picker'),
                showSelectedIcon: false,
                segments: [
                  const ButtonSegment(
                    value: null,
                    label: Text('None', key: ValueKey('section-none')),
                  ),
                  for (final letter in UserProgression.sectionLetters)
                    ButtonSegment(
                      value: letter,
                      label: Text(letter, key: ValueKey('section-$letter')),
                    ),
                ],
                selected: {_section},
                onSelectionChanged: (value) =>
                    setState(() => _section = value.first),
              ),
            ),
            // A section can be played more than once: written once on the
            // chart, marked ×2.
            if (_section != null && widget.hasEndings) ...[
              const SizedBox(height: 12),
              Text(
                'Played twice: through the 1st ending, then the 2nd.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (_section != null && !widget.hasEndings) ...[
              const SizedBox(height: 16),
              Text('Play It', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<int>(
                  key: const ValueKey('section-repeats'),
                  showSelectedIcon: false,
                  segments: [
                    for (
                      var times = 1;
                      times <= UserProgression.maxRepeats;
                      times++
                    )
                      ButtonSegment(
                        value: times,
                        label: Text(
                          times == 1 ? 'Once' : '×$times',
                          key: ValueKey('repeat-$times'),
                        ),
                      ),
                  ],
                  selected: {_repeats},
                  onSelectionChanged: (value) =>
                      setState(() => _repeats = value.first),
                ),
              ),
            ],
            // Part of a 1st or 2nd ending: the bars that change the second
            // time through a section. A section's first bar can't be.
            if (_section == null) ...[
              const SizedBox(height: 16),
              Text('Ending', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<int?>(
                  key: const ValueKey('ending-picker'),
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: null,
                      label: Text('None', key: ValueKey('ending-none')),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text('1st', key: ValueKey('ending-1')),
                    ),
                    ButtonSegment(
                      value: 2,
                      label: Text('2nd', key: ValueKey('ending-2')),
                    ),
                  ],
                  selected: {_ending},
                  onSelectionChanged: (value) =>
                      setState(() => _ending = value.first),
                ),
              ),
            ],
            const SizedBox(height: 20),
            // Writing a tune out is one bar after another, and closing the
            // sheet between each of them is most of the work. This keeps
            // it open and moves on, adding a bar when there is no next one
            // yet. Full width and on its own line because it is pressed
            // far more often than either button under it, and because
            // three buttons in a row did not fit a phone.
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                key: const ValueKey('next-bar'),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next Bar'),
                onPressed: problem == null && _field.text.trim().isNotEmpty
                    ? () => Navigator.of(context).pop<_BarEdit>((
                        text: _field.text.trim(),
                        delete: false,
                        section: _section,
                        repeats: _section == null ? 1 : _repeats,
                        ending: _section == null ? _ending : null,
                        next: true,
                      ))
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (widget.canDelete)
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete bar'),
                    onPressed: () => Navigator.of(context).pop<_BarEdit>((
                      text: '',
                      delete: true,
                      section: null,
                      repeats: 1,
                      ending: null,
                      next: false,
                    )),
                  ),
                const Spacer(),
                FilledButton(
                  key: const ValueKey('bar-done'),
                  onPressed: problem == null
                      ? () => Navigator.of(context).pop<_BarEdit>((
                          text: _field.text.trim(),
                          delete: false,
                          section: _section,
                          repeats: _section == null ? 1 : _repeats,
                          ending: _section == null ? _ending : null,
                          next: false,
                        ))
                      : null,
                  child: const Text('Done'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
