// A saxophone, drawn as a fingering chart draws one.
//
// Not a stack of six holes with a thumb above it. That is a clarinet, or
// a recorder, and a saxophone player looking at one can tell in a glance
// that whoever drew it was thinking of a different instrument. A sax has
// the three palm keys in a cluster above the left hand, the front F over
// the first finger, the bis between the first and second, four keys for
// the left little finger and two for the right, and four side keys the
// right hand reaches with the side of the palm.
//
// So all of them are drawn, every time, whether the note holds them or
// not. A fingering is the whole instrument with some of it pressed, and
// a picture that leaves out the keys a note does not use is a picture of
// something else.
//
// Positions are the horn's own, in the layout every chart uses: down the
// body from the octave key to the right little finger, with the palm
// keys outboard on the left and the side keys outboard on the right.

import 'package:flutter/material.dart';

import '../music/palm_keys.dart';

/// Where a key sits and what shape it is, on a canvas of [canvasWidth] by
/// [canvasHeight].
typedef KeyPlace = ({double x, double y, double w, double h, bool round});

/// The canvas the layout below is drawn on. Everything scales from it, so
/// the same drawing serves the big labelled map and the small fingerings.
const canvasWidth = 86.0;
const canvasHeight = 236.0;

/// Where every key on the horn is.
///
/// The palm keys are a cluster rather than a column, which is how they
/// are on the instrument: E♭ topmost, D furthest out, F below them. The
/// hand rolls across that shape, and a column would make it look like
/// three steps in a line.
///
/// The octave key is drawn well clear of them, up in the corner. It is a
/// thumb key on the back of the horn and belongs nowhere near the palm
/// cluster: sat against it, it reads as a fourth palm key, which is the
/// one thing this page must not say.
const saxLayout = <SaxKey, KeyPlace>{
  SaxKey.octave: (x: 0, y: 2, w: 16, h: 9, round: true),
  SaxKey.frontF: (x: 44, y: 2, w: 12, h: 12, round: true),
  SaxKey.palmEFlat: (x: 20, y: 34, w: 13, h: 7, round: true),
  SaxKey.palmD: (x: 6, y: 45, w: 13, h: 7, round: true),
  SaxKey.palmF: (x: 20, y: 56, w: 13, h: 7, round: true),
  SaxKey.lh1: (x: 40, y: 22, w: 20, h: 20, round: true),
  SaxKey.bis: (x: 28, y: 45, w: 10, h: 10, round: true),
  SaxKey.lh2: (x: 40, y: 50, w: 20, h: 20, round: true),
  SaxKey.lh3: (x: 40, y: 78, w: 20, h: 20, round: true),
  SaxKey.lhGSharp: (x: 26, y: 102, w: 15, h: 7, round: true),
  SaxKey.lhCSharp: (x: 13, y: 104, w: 10, h: 7, round: true),
  SaxKey.lhB: (x: 13, y: 113, w: 10, h: 7, round: true),
  SaxKey.lhBFlat: (x: 13, y: 122, w: 10, h: 7, round: true),
  SaxKey.rh1: (x: 40, y: 146, w: 20, h: 20, round: true),
  SaxKey.rh2: (x: 40, y: 174, w: 20, h: 20, round: true),
  SaxKey.rh3: (x: 40, y: 202, w: 20, h: 20, round: true),
  SaxKey.sideE: (x: 64, y: 142, w: 13, h: 7, round: true),
  SaxKey.sideC: (x: 64, y: 153, w: 13, h: 7, round: true),
  SaxKey.sideBFlat: (x: 64, y: 164, w: 13, h: 7, round: true),
  SaxKey.sideFSharp: (x: 64, y: 175, w: 13, h: 7, round: true),
  SaxKey.rhEFlat: (x: 63, y: 210, w: 10, h: 7, round: true),
  SaxKey.rhC: (x: 63, y: 224, w: 10, h: 7, round: true),
};

/// Where the two hands part, which every chart marks.
const _breakAt = 136.0;

/// One saxophone, with [held] pressed.
///
/// [scale] is how much of [canvasWidth] by [canvasHeight] to draw at.
/// [idPrefix] names the drawn keys so a test can find them, since the
/// same diagram appears once per note.
class SaxDiagram extends StatelessWidget {
  const SaxDiagram({
    super.key,
    required this.held,
    required this.idPrefix,
    this.scale = 1,
  });

  final Set<SaxKey> held;
  final String idPrefix;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    // A key that is not held is still a key, and has to be clearly drawn
    // or the horn disappears and only the fingering is left, which is
    // the picture being half there.
    final faint = theme.colorScheme.onSurfaceVariant;
    return SizedBox(
      width: canvasWidth * scale,
      height: canvasHeight * scale,
      child: Stack(
        children: [
          // The break between the hands.
          Positioned(
            left: 8 * scale,
            top: _breakAt * scale,
            child: SizedBox(
              width: 62 * scale,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < 7; i++)
                    Container(
                      width: 3 * scale,
                      height: 1.2,
                      color: theme.colorScheme.outline,
                    ),
                ],
              ),
            ),
          ),
          for (final entry in saxLayout.entries)
            Positioned(
              left: entry.value.x * scale,
              top: entry.value.y * scale,
              child: Container(
                key: ValueKey('$idPrefix-${entry.key.name}'),
                width: entry.value.w * scale,
                height: entry.value.h * scale,
                decoration: BoxDecoration(
                  color: held.contains(entry.key) ? ink : Colors.transparent,
                  border: Border.all(
                    color: held.contains(entry.key) ? ink : faint,
                    width: 1.3,
                  ),
                  borderRadius: BorderRadius.circular(entry.value.h * scale),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
