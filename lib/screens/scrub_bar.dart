// Dragging to any point in a phrase.
//
// A lick is four bars that came out right, and the bit you need is
// usually not the start of it. Playing it from the top every time means
// sitting through the run-up to hear the one turn you were after, which
// is the practice time going somewhere other than practice.
//
// So the bar is a point rather than a progress readout. Drag it and that
// is where the next play begins; drag it while something is playing and
// the sound moves with the thumb. When a play runs out it comes back to
// the point it started from rather than resting at the end, because the
// thing you do with four bars that came out right is hear them again,
// and a bar that ended at the end would make you set it twice.

import 'package:flutter/material.dart';

/// A draggable point in a recording.
class ScrubBar extends StatelessWidget {
  const ScrubBar({
    super.key,
    required this.at,
    required this.length,
    required this.onMoved,
    this.onSettled,
    this.peaks = const [],
  });

  /// Where the thumb is: either where playing has got to or where it has
  /// been dragged to.
  final Duration at;

  /// How long the recording is, in its own time.
  final Duration length;

  /// Called all the way through a drag, so the sound follows the thumb
  /// rather than jumping when it is let go.
  final ValueChanged<Duration> onMoved;

  /// Called once when the finger lifts.
  final ValueChanged<Duration>? onSettled;

  /// The recording drawn down to one level per column, nought to one.
  ///
  /// Empty draws a plain bar, which is what a phrase recorded before
  /// this existed, or one whose file will not decode, falls back to. The
  /// dragging is the feature and the picture is the help.
  final List<double> peaks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final seconds = length.inMilliseconds / 1000;
    // A recording with no length yet is a slider with nothing to say.
    // Shown rather than hidden, so the bar does not appear and disappear
    // under the finger.
    final usable = seconds > 0;
    final position = _within(at, length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Where in the phrase to play from',
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (peaks.isNotEmpty)
                Padding(
                  // Inside the thumb's own radius, so the first and last
                  // columns line up with nought and the end rather than
                  // running under the thumb at either extreme.
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: CustomPaint(
                    key: const ValueKey('waveform'),
                    size: const Size(double.infinity, 46),
                    painter: _Waveform(
                      peaks: peaks,
                      upTo: usable && position < length
                          ? position.inMilliseconds / length.inMilliseconds
                          : 1,
                      played: theme.colorScheme.tertiary,
                      toCome: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: peaks.isEmpty ? 3 : 1,
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 14,
                  ),
                  // Out of the way of the drawing: with a waveform behind
                  // it the track would be a line ruled through the middle
                  // of the notes.
                  activeTrackColor: peaks.isEmpty
                      ? null
                      : theme.colorScheme.tertiary.withValues(alpha: 0.25),
                  inactiveTrackColor: peaks.isEmpty
                      ? null
                      : theme.colorScheme.outlineVariant,
                ),
                child: Slider(
                  key: const ValueKey('scrub'),
                  value: usable ? position.inMilliseconds / 1000 : 0,
                  max: usable ? seconds : 1,
                  // Named for a listener rather than for a slider: this
                  // is not a quantity being set, it is a place in the
                  // music.
                  label: _clock(position),
                  onChanged: usable
                      ? (value) => onMoved(
                          Duration(milliseconds: (value * 1000).round()),
                        )
                      : null,
                  onChangeEnd: usable && onSettled != null
                      ? (value) => onSettled!(
                          Duration(milliseconds: (value * 1000).round()),
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _clock(position),
                key: const ValueKey('scrub-at'),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.tertiary,
                ),
              ),
              Text(
                _clock(length),
                key: const ValueKey('scrub-length'),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Keeps a point inside the recording, since a position read a moment
/// after the end can be past it.
Duration _within(Duration at, Duration length) {
  if (at < Duration.zero) return Duration.zero;
  if (length > Duration.zero && at > length) return length;
  return at;
}

/// Seconds and tenths rather than minutes and seconds.
///
/// A phrase is four bars. Told as 0:03 the useful part of the number is
/// the bit that got rounded away, and a tenth of a second is about where
/// a dragged thumb stops being able to tell the difference anyway.
String _clock(Duration at) {
  final tenths = (at.inMilliseconds / 100).round();
  return '${tenths ~/ 10}.${tenths % 10}s';
}

/// The recording, drawn as the loudest point of each slice mirrored
/// about the middle.
///
/// Up to the thumb it is in the accent colour and past it in the quieter
/// one, so the picture says where you are without a second marker drawn
/// over the top of the notes.
class _Waveform extends CustomPainter {
  const _Waveform({
    required this.peaks,
    required this.upTo,
    required this.played,
    required this.toCome,
  });

  final List<double> peaks;
  final double upTo;
  final Color played;
  final Color toCome;

  @override
  void paint(Canvas canvas, Size size) {
    if (peaks.isEmpty || size.width <= 0) return;
    final middle = size.height / 2;
    final column = size.width / peaks.length;
    // A hair narrower than its slot, so the columns read as a comb
    // rather than as one filled shape.
    final width = (column * 0.72).clamp(0.6, 3.0);
    final brush = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < peaks.length; i++) {
      final x = column * (i + 0.5);
      // Never nothing: a silent column is still a moment of the
      // recording, and a gap in the row reads as the drawing failing.
      final high = (peaks[i] * (middle - 1)).clamp(0.8, middle);
      brush
        ..color = (i + 0.5) / peaks.length <= upTo ? played : toCome
        ..strokeWidth = width;
      canvas.drawLine(
        Offset(x, middle - high),
        Offset(x, middle + high),
        brush,
      );
    }
  }

  @override
  bool shouldRepaint(_Waveform old) =>
      old.upTo != upTo ||
      old.peaks != peaks ||
      old.played != played ||
      old.toCome != toCome;
}
