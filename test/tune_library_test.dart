import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/music/loop_range.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';

void main() {
  // Loading the library parses every chart, so a typo in a chord symbol
  // fails here rather than crashing the app.
  final byTitle = {
    for (final tune in [...standards, ...practiceProgressions])
      tune.title: tune,
  };

  test('standards have the expected forms and lengths', () {
    const expected = {
      'All of Me': ('ABAC', 32),
      'Anthropology': ('AABA', 32),
      'C Jam Blues': ('', 12),
      'Chameleon': ('', 8),
      'Equinox': ('', 12),
      'Impressions': ('AABA', 32),
      "Now's the Time": ('', 12),
      'Oleo': ('AABA', 32),
      'Sandu': ('', 12),
      'Straight, No Chaser': ('', 12),
      'All the Things You Are': ('AABA', 36),
      'Autumn Leaves': ('AABC', 32),
      'Blue Bossa': ('AB', 16),
      'Cherokee': ('AABA', 64),
      'Fly Me to the Moon': ('ABAC', 32),
      'Giant Steps': ('', 16),
      'Satin Doll': ('AABA', 32),
      'So What': ('AABA', 32),
      'Solar': ('', 12),
      'Song for My Father': ('AAB', 24),
      'Stella by Starlight': ('ABCD', 32),
      'Take the "A" Train': ('AABA', 32),
      'The Girl from Ipanema': ('AABA', 40),
      'There Will Never Be Another You': ('ABAC', 32),
      'Rhythm changes in B♭': ('AABA', 32),
      // Added later: one or two from each genre, and the odd forms.
      'Just Friends': ('ABAC', 32),
      'Bye Bye Blackbird': ('ABCA', 32),
      'Summertime': ('', 16),
      'Donna Lee': ('AB', 32),
      'Confirmation': ('AABA', 32),
      'Blue Monk': ('', 12),
      'The Sidewinder': ('', 24),
      'Watermelon Man': ('', 16),
      'Speak No Evil': ('AABA', 50),
      'Inner Urge': ('AB', 24),
      'Four': ('ABAC', 32),
      'Milestones': ('AABBA', 40),
      'Footprints': ('', 12),
      'Wave': ('AABA', 44),
      'Corcovado': ('ABAC', 34),
      'St. Thomas': ('AB', 16),
      'A Night in Tunisia': ('AABA', 32),
      'Mercy, Mercy, Mercy': ('AB', 20),
    };
    for (final MapEntry(key: title, value: (form, bars)) in expected.entries) {
      final tune = byTitle[title]!;
      expect(tune.form, form, reason: title);
      expect(tune.barCount, bars, reason: title);
    }
  });

  test('sections start where the form says', () {
    final aTrain = byTitle['Take the "A" Train']!;
    expect(aTrain.sections, {0: 'A', 8: 'A', 16: 'B', 24: 'A'});
    expect(aTrain.bars[2].single.chord.display, 'D7♯11');
  });

  test('standards are sorted by title', () {
    final titles = standards.map((t) => t.title).toList();
    expect(titles, [...titles]..sort());
  });

  test('every tune renders', () {
    for (final tune in byTitle.values) {
      final backing = renderBacking(
        BackingRequest(
          tune: tune,
          loop: LoopRange.bars(tune, 0, 0),
          tempo: 200,
          countInBars: 0,
        ),
      );
      expect(backing.stems, hasLength(3), reason: tune.title);
    }
  }, tags: 'sweep', skip: 'the whole book; run it with --run-skipped');

  test('every standard appears once, the first seventy-two among them', () {
    final titles = standards.map((t) => t.title).toList();
    expect(titles.toSet(), hasLength(titles.length));
    expect(titles.length, greaterThanOrEqualTo(72));
    for (final title in ['All of Me', 'Autumn Leaves', 'Wave', "Moanin'"]) {
      expect(titles, contains(title));
    }
  });

  test('every tune spells its key the way it is written', () {
    for (final tune in standards) {
      expect(
        tune.keyLabelBy(0),
        tune.key,
        reason: 'key label changed for ${tune.title}',
      );
    }
    expect(byTitle['Equinox']!.keyLabelBy(2), 'E♭ minor');
  });

  test('tunes are in the key their composer played them in', () {
    // Monk played Straight, No Chaser in B♭; F is Miles Davis's key.
    final monk = byTitle['Straight, No Chaser']!;
    expect(monk.key, 'B♭');
    expect(monk.bars.first.single.chord.display, 'B♭7');
    expect(byTitle['Sandu']!.keyLabelBy(2), 'F');
  });

  test('each tune has the right feel', () {
    expect(byTitle['Blue Bossa']!.feel, Feel.bossa);
    expect(byTitle['The Girl from Ipanema']!.feel, Feel.bossa);
    expect(byTitle['Song for My Father']!.feel, Feel.bossa);
    expect(byTitle['Cantaloupe Island']!.feel, Feel.funk);
    expect(byTitle['Chameleon']!.feel, Feel.funk);
    expect(byTitle['Autumn Leaves']!.feel, Feel.swing);
    expect(byTitle['St. Thomas']!.feel, Feel.calypso);
    expect(byTitle['Wave']!.feel, Feel.bossa);
    expect(byTitle['Red Clay']!.feel, Feel.funk);
    expect(byTitle['Maiden Voyage']!.feel, Feel.funk);
    expect(byTitle['Donna Lee']!.feel, Feel.swing);
  });

  test('St. Thomas is Sonny Rollins\'s calypso in C', () {
    final tune = byTitle['St. Thomas']!;
    expect(tune.composer, 'Sonny Rollins');
    expect(tune.key, 'C');
    expect(tune.genres, contains(Genre.calypso));
    expect(tune.genres, isNot(contains(Genre.latin)));
    expect(tune.style.bass, BassStyle.calypso);
  });

  test('every genre has tunes to filter by', () {
    // Ballads and calypsos are few so far (only your own, and St. Thomas).
    for (final genre in Genre.values.where(
      (g) => g != Genre.ballad && g != Genre.calypso,
    )) {
      expect(
        standards.where((t) => t.genres.contains(genre)).length,
        greaterThanOrEqualTo(5),
        reason: genre.label,
      );
    }
  });

  test('Ornithology keeps to the changes of How High the Moon', () {
    // Bar 11 comes home to G major in both, as the same phrase does in
    // their last section (bar 27).
    for (final title in ['How High the Moon', 'Ornithology']) {
      final tune = byTitle[title]!;
      for (final bar in [10, 26]) {
        expect(
          tune.bars[bar].single.chord.display,
          'GΔ7',
          reason: '$title, bar ${bar + 1}',
        );
      }
    }
  });
}
