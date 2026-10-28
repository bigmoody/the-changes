// The common changes, in all twelve keys, played to you.
//
// Everybody is told to learn their ii-V-Is in all twelve. Almost nobody
// does, and the reason is not that it is hard: it is that setting it up
// is twelve pieces of admin before a note is played, and by the time you
// have written out a minor ii-V in G flat you no longer want to play it.
//
// So the changes are already here (they are the same ones a lick is
// saved over) and the only decisions left are which ones, how fast, and
// whether to move on by yourself or let it move on for you.
//
// Letting it move on for you is the point. Set it going and it walks the
// cycle while you play, which is the thing you would do with a teacher
// and cannot easily do alone.

import 'package:flutter/material.dart';

import '../audio/practice_player.dart';
import '../music/chord.dart';
import '../music/key_order.dart';
import '../music/changes_to_run.dart';
import '../music/tune.dart';
import '../music/user_progression.dart';
import '../practice/practice_controller.dart';
import '../settings/app_settings.dart';
import '../theme.dart';
import 'chord_diagram.dart';
import 'key_round.dart';
import 'transport.dart';
import 'note_ink.dart';

class ChangesInKeysScreen extends StatefulWidget {
  const ChangesInKeysScreen({
    super.key,
    required this.player,
    required this.settings,
  });

  final PracticePlayer player;
  final AppSettings settings;

  @override
  State<ChangesInKeysScreen> createState() => _ChangesInKeysScreenState();
}

class _ChangesInKeysScreenState extends State<ChangesInKeysScreen> {
  late UserProgression _over = changesToRun.first;
  late PracticeController _controller = _controllerFor(_over);

  var _order = KeyOrder.fourths;
  late List<int> _moves = _order.moves();
  var _at = 0;
  final _done = <int>{};

  /// Whether it moves to the next key by itself, and after how many times
  /// round.
  var _auto = true;
  var _every = 2;

  int get move => _moves[_at];

  /// What the key is called [by] semitones along, spelled as the app
  /// spells it everywhere else and as the player reads it.
  String _keyName(int by) =>
      _over.toTune().keyLabelBy(by + widget.settings.instrument.semitones);

  PracticeController _controllerFor(UserProgression over) => PracticeController(
    tune: over.toTune(),
    player: widget.player,
    settings: widget.settings,
  );

  @override
  void initState() {
    super.initState();
    _controller.addListener(_watchChoruses);
  }

  @override
  void dispose() {
    _controller.removeListener(_watchChoruses);
    _controller.dispose();
    super.dispose();
  }

  /// Moves on once this key has been round enough times.
  ///
  /// The chorus count comes from the band's own clock, so it cannot drift
  /// from what is being heard. Changing key restarts the band and takes
  /// that count back to the top, but not in the same instant: the clock
  /// is read every thirtieth of a second and a reading taken from the old
  /// band arriving after the new one has been asked for would move the
  /// key on twice. So having moved, it waits to see the count actually
  /// come back down before it will move again.
  void _watchChoruses() {
    if (!_auto) return;
    final chorus = _controller.chorus;
    if (_waiting) {
      // Only a count that has actually come round again clears the wait.
      // Nothing at all is what the clock says for the moment between the
      // old band stopping and the new one starting, and treating that as
      // a fresh start lets the last reading of the old band through and
      // moves the key on twice.
      if (chorus != null && chorus <= 1) _waiting = false;
      return;
    }
    if (chorus == null || chorus <= _every) return;
    _waiting = true;
    _goTo(_at + 1);
  }

  /// Set after moving on, until the band's clock has started over.
  var _waiting = false;

  void _setContext(UserProgression over) {
    final old = _controller;
    old.removeListener(_watchChoruses);
    old.stop();
    setState(() {
      _over = over;
      _controller = _controllerFor(over)..addListener(_watchChoruses);
      _at = 0;
      _done.clear();
    });
    old.dispose();
  }

  void _goTo(int index) {
    setState(() {
      _done.add(move);
      _at = index % _moves.length;
      _waiting = true;
    });
    _controller.transpose(move);
  }

  void _setOrder(KeyOrder order) {
    setState(() {
      _order = order;
      _moves = order.moves(seed: DateTime.now().millisecond);
      _at = 0;
      _done.clear();
      _waiting = true;
    });
    _controller.transpose(move);
  }

  /// Which diagram the chords open with here: the one chosen in Settings,
  /// or the guitar where that is off, and whatever was last picked in the
  /// sheet after that.
  late var _diagram = widget.settings.diagram == ChordDiagram.none
      ? ChordDiagram.guitar
      : widget.settings.diagram;

  /// How to play [chord]: its diagram, in a sheet over the changes.
  void _showChord(Chord chord) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => _ChordSheet(
      chord: chord,
      diagram: _diagram,
      onDiagram: (diagram) => _diagram = diagram,
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Changes in Twelve Keys'),
        actions: [KeyOrderButton(order: _order, onPick: _setOrder)],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                children: [
                  DropdownButtonFormField<String>(
                    key: const ValueKey('changes-pick'),
                    initialValue: _over.id,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Changes',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final one in changesToRun)
                        DropdownMenuItem(value: one.id, child: Text(one.title)),
                    ],
                    onChanged: (id) => _setContext(
                      changesToRun.firstWhere((one) => one.id == id),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: KeyText(
                          'Key of ${_keyName(move)}',
                          name: _keyName(move),
                          key: const ValueKey('round-key'),
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      Text(
                        '${_at + 1} of ${_moves.length}',
                        key: const ValueKey('round-progress'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _Bars(
                    tune: _over.toTune().transposed(
                      move + widget.settings.instrument.semitones,
                    ),
                    onChord: _showChord,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    key: const ValueKey('move-on'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Move on by Itself'),
                    subtitle: Text(
                      _auto
                          ? 'After $_every ${_every == 1 ? 'time' : 'times'} '
                                'round, it goes to the next key'
                          : 'Stays put until you move it',
                    ),
                    value: _auto,
                    onChanged: (value) => setState(() => _auto = value),
                  ),
                  if (_auto)
                    Row(
                      children: [
                        Text('Times round', style: theme.textTheme.bodyMedium),
                        const Spacer(),
                        IconButton.outlined(
                          key: const ValueKey('fewer-choruses'),
                          icon: const Icon(Icons.remove, size: 18),
                          tooltip: 'One fewer',
                          visualDensity: VisualDensity.compact,
                          onPressed: _every <= 1
                              ? null
                              : () => setState(() => _every -= 1),
                        ),
                        SizedBox(
                          width: 36,
                          child: Text(
                            '$_every',
                            key: const ValueKey('choruses-each'),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        IconButton.outlined(
                          key: const ValueKey('more-choruses'),
                          icon: const Icon(Icons.add, size: 18),
                          tooltip: 'One more',
                          visualDensity: VisualDensity.compact,
                          onPressed: _every >= 8
                              ? null
                              : () => setState(() => _every += 1),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  KeyChips(
                    moves: _moves,
                    label: _keyName,
                    at: _at,
                    done: _done,
                    onPick: _goTo,
                  ),
                ],
              ),
            ),
            KeyStep(onBack: () => _goTo(_at - 1), onNext: () => _goTo(_at + 1)),
            Transport(controller: _controller),
          ],
        ),
      ),
    );
  }
}

/// The changes written out, a box to a bar, as a chart would have them.
/// Each chord can be tapped for how to play it.
class _Bars extends StatelessWidget {
  const _Bars({required this.tune, required this.onChord});

  final Tune tune;
  final ValueChanged<Chord> onChord;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.titleMedium?.copyWith(
      fontFamily: 'PetalumaScript',
    );
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (i, bar) in tune.bars.indexed)
          Container(
            key: ValueKey('round-bar-$i'),
            constraints: const BoxConstraints(minWidth: 72),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final (j, slot) in bar.indexed)
                  Semantics(
                    button: true,
                    label: 'How to play ${slot.chord.display}',
                    excludeSemantics: true,
                    child: InkWell(
                      key: ValueKey('round-chord-$i-$j'),
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => onChord(slot.chord),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Text(
                          handSymbol(slot.chord.display),
                          textAlign: TextAlign.center,
                          style: style,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A chord and how to play it: on the guitar (open or barre), the
/// keyboard or the bass, whichever is picked.
class _ChordSheet extends StatefulWidget {
  const _ChordSheet({
    required this.chord,
    required this.diagram,
    required this.onDiagram,
  });

  final Chord chord;
  final ChordDiagram diagram;
  final ValueChanged<ChordDiagram> onDiagram;

  @override
  State<_ChordSheet> createState() => _ChordSheetState();
}

class _ChordSheetState extends State<_ChordSheet> {
  late var _diagram = widget.diagram;

  static const _choices = [
    ChordDiagram.guitar,
    ChordDiagram.barre,
    ChordDiagram.keyboard,
    ChordDiagram.bass,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              handSymbol(widget.chord.display),
              key: const ValueKey('chord-sheet-name'),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontFamily: 'PetalumaScript',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: Center(
                child: FingeringDiagram(
                  key: ValueKey('chord-sheet-${_diagram.name}'),
                  chord: widget.chord,
                  diagram: _diagram,
                  height: 200,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<ChordDiagram>(
              showSelectedIcon: false,
              segments: [
                for (final diagram in _choices)
                  ButtonSegment(
                    value: diagram,
                    label: FittedBox(
                      child: Text(switch (diagram) {
                        ChordDiagram.barre => 'Barre',
                        _ => diagram.label,
                      }),
                    ),
                  ),
              ],
              selected: {_diagram},
              onSelectionChanged: (picked) {
                setState(() => _diagram = picked.first);
                widget.onDiagram(picked.first);
              },
            ),
          ],
        ),
      ),
    );
  }
}
