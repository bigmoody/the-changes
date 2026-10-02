// One tune, ready to play: the chart, what's sounding now, the loop and
// the transport, laid out to suit the screen it's on.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/practice_player.dart';
import '../audio/tuner_listener.dart';
import '../library/library_store.dart';
import '../music/guitar_voicing.dart';
import '../music/tune.dart';
import '../music/user_progression.dart';
import '../practice/play_check.dart';
import '../practice/hiding_the_chart.dart';
import '../practice/practice_controller.dart';
import '../practice/practice_record.dart';
import '../practice/take_store.dart';
import '../practice/part_store.dart';
import '../practice/recording_store.dart';
import '../settings/app_settings.dart';
import '../settings/progression_store.dart';
import 'chord_chart.dart';
import 'loop_bar.dart';
import 'now_playing.dart';
import 'play_shortcuts.dart';
import 'practice_sheets.dart';
import 'progression_editor_screen.dart';
import 'setlists_screen.dart' show showAddToSetlist;
import 'share_chart.dart';
import 'stage_screen.dart';
import 'transport.dart';
import 'note_ink.dart';

/// The main practice view: the whole chord chart on one screen, with compact
/// controls underneath.
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({
    super.key,
    required this.tune,
    required this.player,
    required this.settings,
    this.progression,
    this.progressions,
    this.takes,
    this.partStore,
    this.recordingStore,
    this.library,
    this.listener,
  });

  final Tune tune;
  final PracticePlayer player;
  final AppSettings settings;

  /// Starring, setlists and what's been played lately. Without it the
  /// screen simply doesn't offer them.
  final LibraryStore? library;

  /// The microphone that checks what you play. Only passed by tests; the
  /// screen makes its own.
  @visibleForTesting
  final TunerListener? listener;

  /// Set when [tune] is one of the player's own progressions: only those can
  /// be edited from here.
  final UserProgression? progression;
  final ProgressionStore? progressions;

  /// Where recordings of you are kept; without it there's no recording.
  final TakeStore? takes;
  final PartStore? partStore;

  /// Where recordings of real players are kept.
  final RecordingStore? recordingStore;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  late final _controller = PracticeController(
    tune: widget.tune,
    player: widget.player,
    settings: widget.settings,
    takes: widget.takes,
    partStore: widget.partStore,
    recordingStore: widget.recordingStore,
    progressions: widget.progressions,
    library: widget.library,
    ref: _ref,
    listener: widget.listener,
  );

  /// What the library knows this tune as: one of the player's own by id,
  /// or one of the book's by title.
  TuneRef get _ref => widget.progression == null
      ? TuneRef.of(widget.tune)
      : TuneRef.mine(widget.progression!.id);

  /// The last score shown, so it isn't shown twice.
  PlayCheck? _scored;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_showScore);
    // Work out this tune's guitar shapes now rather than on the frame where
    // a chord first comes round: searching the fretboard takes a few
    // milliseconds, and they're cached once found.
    Future(() {
      for (final slot in _controller.chart.slots) {
        guitarVoicingFor(slot.chord);
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_showScore);
    _controller.dispose();
    super.dispose();
  }

  /// How you did, once the band has stopped. It arrives mid-build, so it is
  /// shown on the next frame rather than this one.
  void _showScore() {
    final result = _controller.lastCheck;
    if (result == null) {
      _scored = null;
      return;
    }
    if (identical(result, _scored)) return;
    _scored = result;
    final target = _controller.settings.aimFor;
    // The run has been written down by now, so the record can already say
    // whether this one earned the next four beats a minute.
    final next = _controller.nextTempo;
    final at = _controller.tempo;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const ValueKey('score'),
          duration: const Duration(seconds: 8),
          content: Text(
            'You found the ${target?.label ?? 'note'} on '
            '${result.hits} of ${result.asked} '
            '${result.asked == 1 ? 'change' : 'changes'}.'
            '${next == null ? '' : " That's $runsToMoveUp clean at $at."}',
          ),
          action: next == null
              ? null
              : SnackBarAction(
                  label: 'Try $next',
                  onPressed: () => _controller.setTempo(next),
                ),
        ),
      );
    });
  }

  /// Opens the editor; after a save, this screen is replaced by one playing
  /// the new version. After a delete there's nothing left to play.
  Future<void> _edit() async {
    final store = widget.progressions!;
    final id = widget.progression!.id;
    await _controller.stop();
    if (!mounted) return;
    final outcome = await Navigator.of(context).push<EditorOutcome>(
      MaterialPageRoute(
        builder: (_) => ProgressionEditorScreen(
          store: store,
          player: widget.player,
          settings: widget.settings,
          existing: store.byId(id) ?? widget.progression,
          fromPractice: true,
        ),
      ),
    );
    if (!mounted) return;
    switch (outcome) {
      case EditorOutcome.deleted:
        Navigator.of(context).pop();
      case EditorOutcome.saved:
        final updated = store.byId(id);
        if (updated == null) return;
        await Navigator.of(context).pushReplacement(
          PageRouteBuilder<void>(
            // In place: it's the same screen, with the changes.
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (_, _, _) => PracticeScreen(
              tune: updated.toTune(),
              player: widget.player,
              settings: widget.settings,
              progression: updated,
              progressions: store,
            ),
          ),
        );
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // ListenableBuilder rebuilds this part whenever the controller changes.
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => PlayPauseShortcut(
        onPlayPause: () {
          if (!_controller.isPreparing) _controller.togglePlay();
        },
        child: Scaffold(
          appBar: AppBar(
            // The key from the chart rather than the tune, so a B♭
            // player gets the colour of the key they are reading.
            title: _TuneTitle(
              widget.tune.title,
              keyName: _controller.chart.key,
            ),
            actions: [
              if (widget.progression != null && widget.progressions != null)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit progression',
                  onPressed: _edit,
                ),
              if (_controller.canRecord)
                IconButton(
                  key: const ValueKey('takes'),
                  icon: const Icon(Icons.graphic_eq),
                  tooltip: 'Takes',
                  onPressed: () => showTakes(context, _controller),
                ),
              IconButton(
                key: const ValueKey('arrangement'),
                icon: const Icon(Icons.queue_music_outlined),
                // Filled in once it's more than a loop, so a performance set
                // up earlier isn't forgotten about.
                isSelected: !_controller.arrangement.isPlain,
                selectedIcon: const Icon(Icons.queue_music),
                tooltip: 'Arrangement',
                onPressed: () => showArrangement(context, _controller),
              ),
              TextButton(
                onPressed: () => showViewOptions(context, _controller),
                child: const Text('View'),
              ),
              _MoreMenu(
                library: widget.library,
                tune: _ref,
                title: widget.tune.title,
                onShare: () => shareChart(
                  context,
                  _controller.originalTune,
                  semitones: _controller.semitones,
                ),
                // The same controller goes with it, so the band carries on
                // playing as you walk on and off.
                onStage: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => StageScreen(controller: _controller),
                  ),
                ),
                onRecord: () => showPracticeRecord(context, _controller),
              ),
            ],
          ),
          body: SafeArea(child: _Reading(controller: _controller)),
        ),
      ),
    );
  }
}

/// Where the chart was, at the last rung: paper, and a way back.
class _BlankPaper extends StatelessWidget {
  const _BlankPaper({required this.controller});

  final PracticeController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      key: const ValueKey('blank-paper'),
      behavior: HitTestBehavior.opaque,
      onTap: controller.showTheChart,
      child: Center(
        child: Text(
          'Tap for the chart',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

/// The tune's name across the top, as large as it will go.
///
/// It used to shrink to whatever fitted on one line, with no floor, and
/// with the back arrow, three buttons and a menu beside it there isn't much
/// line to fit into. "On the Sunny Side of the Street" came out at under
/// seven points, which is not a title, it's a smudge.
///
/// So it takes two lines when it needs them. The bar is the same height
/// either way, so this costs the chart nothing, and a long name stays
/// readable instead of trailing off or disappearing.
class _TuneTitle extends StatelessWidget {
  const _TuneTitle(this.title, {this.keyName});

  final String title;

  /// The key the chart is in, for somebody who sees keys as colours. The
  /// title is the biggest thing on the screen that belongs to the whole
  /// tune rather than to one bar of it, so it is where that colour goes.
  final String? keyName;

  /// Tried largest first. The first one that fits is the one used.
  static const _sizes = <double>[26, 24, 22, 20, 18, 16, 14, 13, 12];

  /// How small it's worth going to keep a title on one line. Past this a
  /// second line buys back more than it costs.
  static const _onOneLine = 20.0;

  /// Measured a little short of the room there is, so a title that only
  /// just fits doesn't come out with its last word docked anyway.
  static const _margin = 6.0;

  /// Three lines only at the small sizes, where they fit the bar without
  /// crowding it. The longest name in the book needs them: the title has
  /// about a third of the width, and the rest is buttons.
  static const _onThreeLines = 16.0;

  @override
  Widget build(BuildContext context) {
    final plain =
        Theme.of(context).appBarTheme.titleTextStyle ??
        Theme.of(context).textTheme.titleLarge!;
    final ink = keyName == null
        ? null
        : inkForKey(
            context,
            keyName!,
            on: Theme.of(context).colorScheme.surface,
          );
    final style = ink == null ? plain : plain.copyWith(color: ink);
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // What is left of the toolbar once the title's own padding is out
        // of it. Two lines of the smallest size still sit inside this.
        final room = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : kToolbarHeight - 8;
        bool fits(double size, int lines) {
          final painter = TextPainter(
            text: TextSpan(
              text: title,
              style: style.copyWith(fontSize: size),
            ),
            textDirection: Directionality.of(context),
            textScaler: scaler,
            maxLines: lines,
            // Turn the text size right up on a narrow phone and the
            // buttons can take the whole bar; a width below zero is not
            // something a text layout will accept.
          )..layout(maxWidth: math.max(0, constraints.maxWidth - _margin));
          return !painter.didExceedMaxLines && painter.height <= room;
        }

        // One line reads better than two, so a little of the size is worth
        // giving up for it, but not much, and not all of it.
        for (final size in _sizes) {
          if (size < _onOneLine) break;
          if (fits(size, 1)) {
            return Text(
              title,
              style: style.copyWith(fontSize: size),
              maxLines: 1,
            );
          }
        }
        // Then two lines, and for the few names long enough to need it,
        // three. The bar is the same height whichever it is, so the lines
        // cost the chart nothing, and a name you can read all of beats a
        // bigger one with its end taken off.
        for (final lines in [2, 3]) {
          for (final size in _sizes) {
            if (lines == 3 && size > _onThreeLines) continue;
            if (fits(size, lines)) {
              return Text(
                title,
                style: style.copyWith(fontSize: size),
                maxLines: lines,
              );
            }
          }
        }
        // Longer than two lines even at the smallest size: the end goes.
        return Text(
          title,
          style: style.copyWith(fontSize: _sizes.last),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

/// Everything under the app bar: the chart, and the controls that go with
/// it.
///
/// Stacked on a phone held upright. Turned sideways there is width to spare
/// and hardly any height (stacking there would leave the chart a couple of
/// centimetres tall) so the controls move to a column beside it and the
/// chart keeps the whole height of the screen. A tablet has room either
/// way and reads better stacked, as a page does.
class _Reading extends StatelessWidget {
  const _Reading({required this.controller});

  final PracticeController controller;

  /// Under this much height there isn't room to stack the chart and the
  /// controls: a phone on its side, but not a tablet.
  static const _tooShortToStack = 500.0;

  /// How much of the width the controls take when they sit beside the
  /// chart. Enough for the transport to lay out as it does upright.
  static const _sideWidth = 340.0;

  @override
  Widget build(BuildContext context) {
    // At the last rung there is no chart at all: blank paper, which a tap
    // anywhere on brings back. A big target, because someone reaching for
    // it has already lost their place and doesn't want to hunt.
    final gone = controller.chartShows == ChartShows.nothing;
    final chart = Stack(
      key: const ValueKey('chart'),
      children: [
        if (gone)
          _BlankPaper(controller: controller)
        else
          ChordChart(controller: controller),
        if (controller.countInBeat != null)
          CountInBubble(beat: controller.countInBeat!),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight >= _tooShortToStack) {
          return Column(
            children: [
              LoopBar(controller: controller),
              Expanded(child: chart),
              NowPlaying(controller: controller),
              const Divider(height: 1),
              Transport(controller: controller),
            ],
          );
        }
        // Wider when Larger Text is turned up, because the transport is
        // laid out in words and buttons that grow with it, but never more
        // than half the screen, so the chart is always the bigger half.
        final textScale = MediaQuery.textScalerOf(context)
            .scale(1)
            .clamp(1.0, 2.0);
        final side = math.min(_sideWidth * textScale, constraints.maxWidth / 2);
        return Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  LoopBar(controller: controller),
                  Expanded(child: chart),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            SizedBox(
              width: side,
              // The controls are laid out for an upright phone's width, so
              // on a short screen they can be taller than there is room
              // for; scrolling is better than clipping the Play button.
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    NowPlaying(controller: controller),
                    const Divider(height: 1),
                    Transport(controller: controller),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The app bar's last button: the things you do with a tune rather than to
/// the way it's played: star it, put it on a setlist, send the chart to
/// someone.
class _MoreMenu extends StatelessWidget {
  const _MoreMenu({
    required this.library,
    required this.tune,
    required this.title,
    required this.onShare,
    required this.onStage,
    required this.onRecord,
  });

  final LibraryStore? library;
  final TuneRef tune;
  final String title;
  final VoidCallback onShare;

  /// Opens the stage: the chart and nothing else.
  final VoidCallback onStage;

  /// Opens the practice record for this tune.
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final library = this.library;
    // Without a library there's nothing to listen to: the menu is just the
    // one item, and it never changes.
    if (library == null) return _menu(context, starred: false);
    return ListenableBuilder(
      listenable: library,
      builder: (context, _) =>
          _menu(context, starred: library.isFavourite(tune)),
    );
  }

  Widget _menu(BuildContext context, {required bool starred}) =>
      PopupMenuButton<String>(
        key: const ValueKey('tune-menu'),
        tooltip: 'More',
        onSelected: (choice) {
          switch (choice) {
            case 'star':
              library?.toggleFavourite(tune);
            case 'setlist':
              showAddToSetlist(context, library!, tune, title);
            case 'record':
              onRecord();
            case 'share':
              onShare();
            case 'stage':
              onStage();
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'stage',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.fullscreen),
              title: Text('Stage View'),
            ),
          ),
          if (library != null) ...[
            PopupMenuItem(
              value: 'star',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(starred ? Icons.star : Icons.star_border),
                title: Text(starred ? 'Starred' : 'Star'),
              ),
            ),
            const PopupMenuItem(
              value: 'setlist',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.list_alt_outlined),
                title: Text('Add to Setlist'),
              ),
            ),
            const PopupMenuItem(
              value: 'record',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.trending_up),
                title: Text('Practice Record'),
              ),
            ),
          ],
          const PopupMenuItem(
            value: 'share',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.ios_share),
              title: Text('Share Chart'),
            ),
          ),
        ],
      );
}
