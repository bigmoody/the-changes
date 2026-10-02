// How hard the band swings.
//
// It follows the tempo by default, and that is the better answer for
// nearly everybody: the short half of a swung pair stays about the same
// length whatever the tempo, roughly a tenth of a second, and the beat
// shrinks around it. So a ballad swings hard, a burning tempo comes out
// nearly straight, and nobody has to say so. The Swing page in Learn is
// about that curve and why it is the shape it is.
//
// This is where you disagree with it. Somebody working on one thing wants
// it held still: playing the same phrase at six tempos is a different
// exercise if the swing moves underneath you, and a player whose own time
// sits harder or flatter than the curve wants the band to meet them
// rather than the other way about.
//
// The slider is the one from the Learn page, deliberately, down to the
// ratio under it. The two should not disagree about what a 2 : 1 is.
//
// You can hear it before you commit to it. A swing you cannot hear is a
// number, and nobody knows what number they want.

import 'package:flutter/material.dart';

import '../audio/backing_synth.dart';
import '../audio/practice_player.dart';
import '../music/swing.dart';
import '../settings/app_settings.dart';
import 'swing_screen.dart' show ridePattern;

/// The tempo the example plays at when the band is following the tempo,
/// and the one the slider starts from.
///
/// Medium-up, where the curve gives about the triplet everybody is
/// taught, so the first thing anybody hears is the familiar one.
const _exampleTempo = 160;

class BandSwingScreen extends StatefulWidget {
  const BandSwingScreen({
    super.key,
    required this.settings,
    required this.player,
  });

  final AppSettings settings;
  final PracticePlayer player;

  @override
  State<BandSwingScreen> createState() => _BandSwingScreenState();
}

class _BandSwingScreenState extends State<BandSwingScreen> {
  late double _at = widget.settings.swing ?? swingAt(_exampleTempo);

  bool get _follows => widget.settings.swing == null;

  Future<void> _hear() async {
    final bank = widget.player.samples;
    if (bank == null) return;
    await widget.player.playSnippet(
      renderSnippet(
        bank,
        const [],
        drums: ridePattern(
          tempo: _exampleTempo,
          // What the band will actually do at this tempo, which is the
          // only thing worth listening to.
          at: _follows ? swingAt(_exampleTempo) : _at,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.settings,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final theme = Theme.of(context);
    final showing = _follows ? swingAt(_exampleTempo) : _at;
    return Scaffold(
      appBar: AppBar(title: const Text('Swing')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'How late the "and" is when the band plays swung eighths. '
                'Left to itself it follows the tempo, swinging harder at a '
                'ballad and flattening towards straight as the tempo '
                'climbs, which is what a player does without thinking '
                'about it.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            SwitchListTile(
              key: const ValueKey('swing-follows'),
              secondary: const Icon(Icons.show_chart),
              title: const Text('Follow the Tempo'),
              subtitle: const Text(
                'Swing it the way a player would at that tempo',
              ),
              value: _follows,
              onChanged: (on) => widget.settings.setSwing(on ? null : _at),
            ),
            Slider(
              key: const ValueKey('band-swing-slider'),
              min: straight,
              max: widestSwing,
              value: showing,
              label: ratioText(showing),
              // Taking hold of it is a way of saying you would rather
              // choose, so it stops following. The same as the Learn page
              // does, because it is the same gesture meaning the same
              // thing.
              onChanged: (value) {
                setState(() => _at = value);
                widget.settings.setSwing(value);
              },
            ),
            ListTile(
              key: const ValueKey('hear-swing'),
              leading: const Icon(Icons.volume_up_outlined),
              title: Text('${swingName(showing)}, ${ratioText(showing)}'),
              subtitle: Text(
                _follows
                    ? 'What it comes to at $_exampleTempo. Tap to hear it'
                    : 'At every tempo. Tap to hear it',
              ),
              onTap: _hear,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                _follows
                    ? 'The short note stays about the same length whatever '
                          'the tempo: a tenth of a second, about as fast as '
                          'a hand plays a note and means it. It is the beat '
                          'that shrinks around it, so the swing flattens on '
                          'its own as the tempo climbs. There is more about '
                          'this in Learn, under Swing.'
                    : 'Held here at every tempo, which is what you want '
                          'when you are working on one thing and the swing '
                          'moving underneath you would make it a different '
                          'exercise. The band starts again from the top of '
                          'the loop when this moves.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
