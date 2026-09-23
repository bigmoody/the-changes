// Holding the band to one comping figure.
//
// Learn lets you pick a figure and hear it over two bars of a ii-V. This
// is the same choice while a tune is playing: one figure, every bar, over
// real changes at your own tempo, which is the only way to find out what
// a figure actually does to a chorus.
//
// The band's own way of comping is to choose bar by bar, and that stays
// the default. What is tested here is that asking for one figure really
// does get that figure and nothing else, and that turning it off gives
// the band back.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/guitar_comping.dart';
import 'package:play_along/audio/piano_comping.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/comping.dart';
import 'package:play_along/library/library_store.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/settings/progression_store.dart';

final dm7 = Chord.parse('Dm7');
final g7 = Chord.parse('G7');

/// Where the comper puts the chord in each of [bars] bars, given a figure.
///
/// A new chord every bar, alternating, because that is the case a figure
/// is about. The first bar is dropped from what comes back where it is
/// asked for, since nothing can push against the start of a tune.
List<List<double>> barsOf(
  CompFigure? figure, {
  int bars = 8,
  int seed = 3,
  double swing = 0.66,
}) {
  final comper = Comper(math.Random(seed));
  return [
    for (var bar = 0; bar < bars; bar++)
      [
        for (final hit in comper.comp(
          bar.isEven ? dm7 : g7,
          4,
          Feel.swing,
          next: bar.isEven ? g7 : dm7,
          figure: figure,
          swing: swing,
        ))
          hit.beat,
      ],
  ];
}

void main() {
  group('asking for one figure', () {
    test('every bar is that figure, and no other', () {
      for (final figure in CompFigure.values) {
        final want = [for (final (beat, _, _) in figure.strikes(0.66)) beat];
        final played = barsOf(figure);
        // The opening bar is the exception, and has its own test.
        for (final bar in played.skip(1)) {
          expect(
            bar,
            want,
            reason: '${figure.label} should be the same in every bar',
          );
        }
      }
    });

    test('including the one the band never plays by itself', () {
      // Four square chords. The band's own weight for it is nought, so
      // the only way to hear it under a tune is to ask.
      expect(CompFigure.everyBeat.playedByTheBand, isFalse);
      expect(barsOf(CompFigure.everyBeat)[2], [0, 1, 2, 3]);
    });

    test('it keeps going while a chord is held across bars', () {
      // The band would leave a held chord mostly alone, which is right
      // musically and useless for hearing a figure.
      final comper = Comper(math.Random(5));
      final bars = [
        for (var bar = 0; bar < 4; bar++)
          [
            for (final hit in comper.comp(
              dm7, // the same chord all the way through
              4,
              Feel.swing,
              figure: CompFigure.charleston,
              swing: 0.66,
            ))
              hit.beat,
          ],
      ];
      for (final bar in bars.skip(1)) {
        expect(bar, hasLength(2), reason: 'the Charleston, again');
        expect(bar[0], closeTo(0, 0.001));
        expect(bar[1], closeTo(1.66, 0.001));
      }
    });

    test('a bar too short for a figure is left to the comper', () {
      // Two beats is half a bar, and a figure needs four to be itself.
      final comper = Comper(math.Random(1));
      final hits = comper.comp(
        dm7,
        2,
        Feel.swing,
        figure: CompFigure.everyBeat,
        swing: 0.66,
      );
      expect(hits.length, lessThan(4));
    });
  });

  group('the push, which has nowhere to come from at the top', () {
    test('it lands on the downbeat in the opening bar', () {
      // A push is early against the bar before it. In bar one there is
      // no bar before, so it goes in the only place it can.
      expect(barsOf(CompFigure.pushed).first, [0]);
    });

    test('and is a real push everywhere after that', () {
      final after = barsOf(CompFigure.pushed).skip(1);
      for (final bar in after) {
        expect(bar.single, closeTo(-0.34, 0.001), reason: 'before the bar');
      }
    });

    test('strikesAt is what does it, and keeps the length', () {
      final pushed = strikesAt(CompFigure.pushed, 0.66, canPush: true);
      final opening = strikesAt(CompFigure.pushed, 0.66, canPush: false);
      expect(pushed.single.$1, lessThan(0));
      expect(opening.single.$1, 0);
      expect(
        opening.single.$2,
        pushed.single.$2,
        reason: 'it still rings across the bar the way a push does',
      );
    });

    test('a figure that does not push is untouched either way', () {
      for (final figure in CompFigure.values) {
        if (figure.startsEarly) continue;
        expect(
          strikesAt(figure, 0.66, canPush: false),
          figure.strikes(0.66),
          reason: figure.label,
        );
      }
    });
  });

  group('leaving it to the band', () {
    test('no figure asked for means more than one figure played', () {
      final bars = barsOf(null, bars: 24);
      final different = bars.map((bar) => bar.join(',')).toSet();
      expect(
        different.length,
        greaterThan(3),
        reason: 'the comper chooses bar by bar, as it always has',
      );
    });

    test('and it still leaves holes, which one figure never does', () {
      // A chord held across bars is where a comper shuts up, and that is
      // exactly what asking for a figure gives away.
      List<List<double>> held(CompFigure? figure) {
        final comper = Comper(math.Random(4));
        return [
          for (var bar = 0; bar < 16; bar++)
            [
              for (final hit in comper.comp(
                dm7,
                4,
                Feel.swing,
                figure: figure,
                swing: 0.66,
              ))
                hit.beat,
            ],
        ];
      }

      expect(
        held(null).where((bar) => bar.isEmpty),
        isNotEmpty,
        reason: 'the band leaves the held chord alone sometimes',
      );
      expect(held(CompFigure.charleston), everyElement(isNotEmpty));
    });
  });

  group('the guitarist gets it too', () {
    test('in swing, where it borrows the comper rhythms', () {
      final guitarist = GuitarComper(math.Random(2));
      final beats = [
        for (var bar = 0; bar < 4; bar++)
          [
            for (final hit in guitarist.comp(
              bar.isEven ? dm7 : g7,
              4,
              style: PianoStyle.swing,
              groove: Feel.swing,
              beatInBar: 0,
              bar: bar,
              next: bar.isEven ? g7 : dm7,
              figure: CompFigure.twice,
              swing: 0.66,
            ))
              hit.beat,
          ],
      ];
      for (final bar in beats.skip(1)) {
        expect(bar, hasLength(2), reason: 'Twice a Bar, on the guitar');
        expect(bar[0], closeTo(0, 0.001));
        expect(bar[1], closeTo(2.66, 0.001));
      }
    });
  });

  group('where the choice is worth offering', () {
    test('the styles that use the figures, and the ones that do not', () {
      // Held chords and the calypso strum have rhythms of their own.
      expect(figuresApply(PianoStyle.held, Comping.piano), isFalse);
      expect(figuresApply(PianoStyle.calypso, Comping.piano), isFalse);
      expect(figuresApply(PianoStyle.held, Comping.guitar), isFalse);

      // The pianist comps from these figures in swing and in straight.
      expect(figuresApply(PianoStyle.swing, Comping.piano), isTrue);
      expect(figuresApply(PianoStyle.straight, Comping.piano), isTrue);

      // The guitarist borrows them in swing only: in the Latin styles it
      // plays the bossa guitar's own two-bar figures instead.
      expect(figuresApply(PianoStyle.swing, Comping.guitar), isTrue);
      expect(figuresApply(PianoStyle.straight, Comping.guitar), isFalse);
    });
  });

  group('keeping it with the tune', () {
    test('a style carries its figure, and can be given another', () {
      const swing = BandStyle(
        drums: Feel.swing,
        bass: BassStyle.walking,
        piano: PianoStyle.swing,
      );
      expect(swing.figure, isNull);
      expect(swing.withFigure(CompFigure.held).figure, CompFigure.held);
      expect(swing.withFigure(CompFigure.held).withFigure(null).figure, isNull);
    });

    test('two styles differing only in the figure are not the same', () {
      const style = BandStyle(
        drums: Feel.swing,
        bass: BassStyle.walking,
        piano: PianoStyle.swing,
      );
      expect(style.withFigure(CompFigure.pushed), isNot(style));
      expect(
        style.withFigure(CompFigure.pushed).hashCode,
        isNot(style.hashCode),
      );
      expect(style.withFigure(null), style);
    });

    test('it is written down and read back', () async {
      final storage = MemoryStorage();
      final library = await LibraryStore.load(storage);
      final ref = TuneRef.standard('Jazz blues in F');
      library.setStyle(
        ref,
        const BandStyle(
          drums: Feel.swing,
          bass: BassStyle.walking,
          piano: PianoStyle.swing,
        ).withFigure(CompFigure.offbeat),
      );
      // setStyle writes as it goes; let it land.
      await Future<void>.delayed(Duration.zero);

      final again = await LibraryStore.load(storage);
      expect(again.styleFor(ref)?.figure, CompFigure.offbeat);
      expect(again.styleFor(ref)?.drums, Feel.swing);
    });

    test('a style saved before figures existed still reads', () async {
      // Three parts and no fourth, which is every library written until
      // now. It has to come back as a band that chooses for itself.
      final library = await LibraryStore.load(
        MemoryStorage(
          '{"styles": {"s:Jazz blues in F": ["swing", "walking", "swing"]}}',
        ),
      );
      final style = library.styleFor(TuneRef.standard('Jazz blues in F'))!;
      expect(style.drums, Feel.swing);
      expect(style.figure, isNull);
    });

    test('a figure this version does not know is not a broken tune', () {
      final styles = LibraryStore.readStyles({
        'styles': {
          's:Jazz blues in F': ['swing', 'walking', 'swing', 'moonwalk'],
        },
      });
      expect(styles.values.single.figure, isNull);
      expect(styles.values.single.piano, PianoStyle.swing);
    });

    test('a whole band feel still has no figure of its own', () {
      // Choosing a groove is not choosing a figure.
      for (final feel in Feel.values) {
        expect(BandStyle.of(feel).figure, isNull);
      }
    });
  });
}
