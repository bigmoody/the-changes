import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/music/chart_layout.dart';
import 'package:play_along/music/loop_range.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/user_progression.dart';
import 'package:play_along/settings/progression_store.dart';

UserProgression _sample() => UserProgression(
  id: '1',
  title: 'Minor blues in A',
  key: 'A minor',
  tempo: 132,
  bars: [
    'Am7',
    'Dm7',
    'Am7',
    'Am7',
    'Dm7',
    'Dm7',
    'Am7',
    'Am7',
    'F7',
    'E7',
    'Am7',
    'Bø7 E7b9',
  ],
  style: const BandStyle(
    drums: Feel.bossa,
    bass: BassStyle.walking,
    piano: PianoStyle.held,
  ),
);

void main() {
  test('becomes a tune with its chords, key, tempo and band', () {
    final tune = _sample().toTune();
    expect(tune.title, 'Minor blues in A');
    expect(tune.key, 'A minor');
    expect(tune.defaultTempo, 132);
    expect(tune.barCount, 12);
    expect(tune.bars.last.map((s) => s.chord.display), ['Bø7', 'E7♭9']);
    expect(tune.bars.last.map((s) => s.beats), [2, 2]);
    expect(tune.style.drums, Feel.bossa);
    expect(tune.style.bass, BassStyle.walking);
    expect(tune.style.piano, PianoStyle.held);
    // Transposing keeps the band as it was set up.
    expect(tune.transposed(2).style, tune.style);
  });

  test('saves and loads exactly as written', () {
    final original = _sample();
    final copy = UserProgression.fromJson(original.toJson());
    expect(copy.toJson(), original.toJson());
  });

  test('says what is wrong with a bar', () {
    expect(UserProgression.problemWith('Dm7 G7'), isNull);
    expect(UserProgression.problemWith('B♭Δ7'), isNull, reason: 'symbols');
    expect(UserProgression.problemWith('  '), contains('at least one'));
    expect(UserProgression.problemWith('C D E F G'), contains('At most'));
    expect(UserProgression.problemWith('Dm7 Hm7'), contains('"Hm7"'));
  });

  test('a bar holds one chord a beat, whatever the meter', () {
    // One a beat is as many as fit: the chord after that has no beat to
    // sound on, and the band is never handed one that lasts no time.
    const chords = [
      'Dm7', 'G7', 'C6', 'A7', 'E7', 'B7', 'F6', 'Bb7', 'Eb6', //
      'Ab7', 'Db6', 'Gb7', 'B6',
    ];
    for (final meter in UserProgression.meters) {
      final beats = meter.pulses;
      String bar(int n) => chords.take(n).join(' ');
      expect(
        UserProgression.problemWith(bar(beats), meter: meter),
        isNull,
        reason: '$beats chords fit a bar of $meter',
      );
      expect(
        UserProgression.problemWith(bar(beats + 1), meter: meter),
        'At most $beats chords in a bar of ${meter.label}',
        reason: 'one too many for $meter',
      );
      // The other complaints still come first.
      expect(
        UserProgression.problemWith('   ', meter: meter),
        contains('at least one'),
      );
    }
    // Without a meter it is 4/4, as it always was.
    expect(UserProgression.problemWith('Dm7 G7 C6 A7'), isNull);
  });

  test('the bars too full for the meter are named', () {
    final tight = UserProgression(
      id: '2',
      title: 'Crowded',
      key: 'C',
      tempo: 120,
      bars: ['Dm7 G7 C6 A7', 'Dm7 G7', 'C6', 'Dm7 G7 C6'],
      style: BandStyle.of(Feel.swing),
    );
    expect(tight.crowdedBars, isEmpty, reason: 'all fit 4/4');
    expect(tight.isPlayable, isTrue);
    tight.beatsPerBar = 3;
    expect(tight.crowdedBars, [1]);
    tight.beatsPerBar = 2;
    expect(tight.crowdedBars, [1, 4]);
  });

  test('the band is never handed a chord with no beats', () {
    // Four chords written in a bar, then the time changed to 3/4: the
    // fourth has nowhere to sound, so the bar plays the three that fit
    // rather than a chord of no beats, which crashes the bassist.
    final tight = UserProgression(
      id: '3',
      title: 'Crowded',
      key: 'C',
      tempo: 120,
      bars: ['Dm7 G7 C6 A7', 'Dm7 G7', 'C6', 'A7'],
      style: BandStyle.of(Feel.swing),
      beatsPerBar: 3,
    );
    final tune = tight.toTune();
    expect(tune.bars.first.map((s) => s.chord.display), ['Dm7', 'G7', 'C6']);
    for (final bar in tune.bars) {
      for (final slot in bar) {
        expect(slot.beats, greaterThan(0), reason: slot.chord.display);
      }
    }
    expect(tune.totalBeats, 4 * 3);
    expect(
      () => renderBacking(
        BackingRequest(
          tune: tune,
          loop: LoopRange.bars(tune, 0, tune.barCount - 1),
          tempo: 120,
          countInBars: 0,
        ),
      ),
      returnsNormally,
    );
  });

  test('guesses the key the progression comes home to', () {
    // A ii–V–I is in the key of the I, not of the ii it starts on.
    expect(UserProgression.guessKey(['Dm7 G7', 'C^7']), 'C');
    // Still C with a turnaround chord after the I.
    expect(UserProgression.guessKey(['Dm7', 'G7', 'C^7', 'C^7', 'Am7']), 'C');
    expect(UserProgression.guessKey(['Eø7', 'A7b9', 'Dm6']), 'D minor');
    // Ending on a turnaround, as a blues does: the first chord is home.
    expect(UserProgression.guessKey(['F7', 'Bb7', 'F7', 'Gm7 C7']), 'F');
    // A minor vamp.
    expect(UserProgression.guessKey(['F#m7', 'B7']), 'F♯ minor');
    // Spelled unusually: found by sound.
    expect(UserProgression.guessKey(['A#m6']), 'B♭ minor');
    // A half-diminished chord isn't a minor key's home.
    expect(UserProgression.guessKey(['Eø7', 'A7']), 'E');
    expect(UserProgression.guessKey(['nonsense']), 'C');
  });

  group('the store', () {
    test('saves, updates and deletes, and survives a restart', () async {
      final storage = MemoryStorage();
      final store = await ProgressionStore.load(storage);
      expect(store.all, isEmpty);

      final progression = _sample();
      await store.save(progression);
      progression.title = 'Renamed';
      // Editing the object doesn't change what's saved until it's saved.
      expect(store.byId('1')!.title, 'Minor blues in A');
      await store.save(progression);
      expect(store.all.single.title, 'Renamed');

      // A fresh store reading the same storage sees the same thing.
      final reopened = await ProgressionStore.load(storage);
      expect(reopened.all.single.toJson(), progression.toJson());

      await reopened.delete('1');
      expect((await ProgressionStore.load(storage)).all, isEmpty);
    });

    test('lists progressions by title', () async {
      final store = ProgressionStore.inMemory();
      for (final (id, title) in [('a', 'zebra'), ('b', 'Apple'), ('c', '')]) {
        await store.save(
          UserProgression.fromJson({
            ..._sample().toJson(),
            'id': id,
            'title': title,
          }),
        );
      }
      expect(store.all.map((p) => p.displayTitle), [
        'Apple',
        'Untitled',
        'zebra',
      ]);
    });

    test('unreadable saved data starts empty rather than crashing', () async {
      final store = await ProgressionStore.load(MemoryStorage('not json'));
      expect(store.all, isEmpty);
    });
  });

  group('sections', () {
    UserProgression make() => UserProgression(
      id: 'x',
      title: 'Form',
      key: 'C',
      tempo: 120,
      bars: ['Dm7', 'G7', 'CΔ7', 'CΔ7', 'Em7', 'A7', 'Dm7', 'G7'],
      style: BandStyle.of(Feel.swing),
    );

    test('starting a B section marks the bars before it A', () {
      final p = make();
      expect(p.nextSection, 'B');
      p.setSection(4, p.nextSection);
      expect(p.sections, {0: 'A', 4: 'B'});
      expect(p.nextSection, 'C');
      // On the chart, as on a standard's.
      final tune = p.toTune();
      expect(tune.sections, {0: 'A', 4: 'B'});
      expect(tune.form, 'AB');
    });

    test('saved and loaded, and old saves without sections still load', () {
      final p = make()..setSection(4, 'B');
      final again = UserProgression.fromJson(p.toJson());
      expect(again.sections, {0: 'A', 4: 'B'});
      final old = p.toJson()..remove('sections');
      expect(UserProgression.fromJson(old).sections, isEmpty);
    });

    test('taking out a bar keeps each section starting where it should', () {
      final p = make()
        ..setSection(4, 'B')
        ..setSection(6, 'C');
      // A bar before B: B and C move back one.
      p.removeBar(1);
      expect(p.sections, {0: 'A', 3: 'B', 5: 'C'});
      // B's first bar: B starts on the bar after it instead.
      p.removeBar(3);
      expect(p.sections, {0: 'A', 3: 'B', 4: 'C'});
      // C's first bar: C moves on to the last bar…
      p.removeBar(4);
      expect(p.sections, {0: 'A', 3: 'B', 4: 'C'});
      expect(p.bars, hasLength(5));
      // …and when that goes too, with no bar after it, so does C.
      p.removeBar(4);
      expect(p.sections, {0: 'A', 3: 'B'});
    });
  });

  group('repeated sections', () {
    UserProgression make() => UserProgression(
      id: 'x',
      title: 'Form',
      key: 'C',
      tempo: 120,
      bars: ['Dm7', 'G7', 'CΔ7', 'CΔ7', 'Em7', 'A7'],
      style: BandStyle.of(Feel.swing),
    )..setSection(4, 'B');

    test('an A played twice: the band plays it twice, the chart writes it '
        'once marked ×2', () {
      final p = make()..setRepeats(0, 2);
      final tune = p.toTune();
      // A A B: 4 + 4 + 2 bars.
      expect(tune.bars, hasLength(10));
      expect(tune.form, 'AAB');
      final lines = layOutChart(tune, 4);
      expect(lines.first.section, 'A');
      expect(lines.first.repeat, 2);
      // Folded: the chart shows the A once, then the B.
      expect(lines.where((l) => l.startsSection).map((l) => l.section), [
        'A',
        'B',
      ]);
    });

    test('saved and loaded; removing the section removes its repeat', () {
      final p = make()..setRepeats(4, 3);
      final again = UserProgression.fromJson(p.toJson());
      expect(again.repeatsOf(4), 3);
      expect(again.repeatsOf(0), 1);
      again.setSection(4, null);
      expect(again.repeats, isEmpty);
      // A bar with no section can't repeat.
      again.setRepeats(2, 2);
      expect(again.repeats, isEmpty);
    });

    test('a repeat moves with its section when a bar is taken out', () {
      final p = make()..setRepeats(4, 2);
      p.removeBar(1);
      expect(p.sections, {0: 'A', 3: 'B'});
      expect(p.repeats, {3: 2});
    });
  });

  group('1st and 2nd endings', () {
    // A: two shared bars, a 1st ending back to the top, a 2nd ending home;
    // then a B.
    UserProgression make() =>
        UserProgression(
            id: 'x',
            title: 'Endings',
            key: 'C',
            tempo: 120,
            bars: ['Dm7', 'G7', 'Em7', 'A7', 'C^7', 'C^7', 'F7', 'F7'],
            style: BandStyle.of(Feel.swing),
          )
          ..setEnding(2, 1)
          ..setEnding(3, 1)
          ..setEnding(4, 2)
          ..setEnding(5, 2)
          ..setSection(6, 'B');

    test('the band plays the section twice, one ending each time', () {
      final p = make();
      expect(p.sections, {0: 'A', 6: 'B'});
      expect(p.hasEndings(0), isTrue);
      final tune = p.toTune();
      String bar(int i) => tune.bars[i].map((s) => s.chord.display).join();
      expect(
        [for (var i = 0; i < tune.barCount; i++) bar(i)],
        [
          'Dm7', 'G7', 'Em7', 'A7', // through the 1st ending
          'Dm7', 'G7', 'CΔ7', 'CΔ7', // round again to the 2nd
          'F7', 'F7', // then B
        ],
      );
      expect(tune.form, 'AAB');
    });

    test('the chart writes it once, with its endings bracketed', () {
      final lines = layOutChart(make().toTune(), 4);
      final a = lines.first;
      expect(a.section, 'A');
      expect([for (final c in a.cells) c?.ending], [null, null, 1, 1]);
      // The 2nd ending on the row under it, lined up with the 1st.
      expect([for (final c in lines[1].cells) c?.ending], [null, null, 2, 2]);
    });

    test('saved and loaded, and they move when a bar is taken out', () {
      final p = UserProgression.fromJson(make().toJson());
      expect(p.endings, {2: 1, 3: 1, 4: 2, 5: 2});
      p.removeBar(0);
      expect(p.endings, {1: 1, 2: 1, 3: 2, 4: 2});
      expect(p.sections, {0: 'A', 5: 'B'});
    });

    test('until both endings are there, every bar plays as written', () {
      final p = make()
        ..setEnding(4, null)
        ..setEnding(5, null);
      expect(p.hasEndings(0), isFalse);
      expect(p.toTune().barCount, 8);
    });
  });
}
