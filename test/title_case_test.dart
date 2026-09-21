// Title Case, everywhere rather than on one screen.
//
// The rule was already written down, in the reading music test, and it
// only ever checked that one file. So the rest of the app drifted: by
// the time anybody looked, fourteen headings had a capitalised "The" or
// "Of" in the middle of them and one screen had renamed itself.
//
// The rule: every word takes a capital except a short joining word in
// the middle of the title. First and last words always take one, because
// "Start On" is a heading and "Start on" is half a sentence.
//
// This reads the source rather than the running app because headings
// live in a dozen screens, and a test that had to open all of them would
// be slower and would still miss the ones behind a tab.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The words that stay lowercase in the middle of a title.
///
/// Three letters or fewer, which is where the app already drew the line:
/// it has always written "Trade With the Drums", so a four-letter
/// preposition keeps its capital and a three-letter one does not. An
/// arbitrary place to draw it, but a line somebody has already drawn is
/// worth more than a better one nobody is using.
const joins = {
  'a',
  'an',
  'and',
  'as',
  'at',
  'but',
  'by',
  'for',
  'in',
  'nor',
  'of',
  'on',
  'or',
  'the',
  'to',
};

/// Titles that look like they break the rule and do not.
///
/// Each is here for a reason, and the reason is the point: a blanket
/// rule applied without looking would make all four of them wrong.
const allowed = {
  // A mnemonic, where the "And" is the A of F C G D A E B.
  'Father Charles Goes Down And Ends Battle',
  // The letters of the treble clef spaces.
  'F A C E',
  // That A is the section of the form, not an article.
  'The A Section',
  'Hear the A Section',
  // In and out are particles here, not prepositions: a band plays the
  // head in and comes back out.
  'Head In & Out',
};

/// Where a user-visible title is written.
final _patterns = [
  RegExp(r"SectionHeader\('([^']*)'\)"),
  RegExp(r"AppBar\(title: const Text\('([^']*)'\)"),
  RegExp(r"heading\('([^']*)'\)"),
  RegExp(r"_Heading\('([^']*)'\)"),
  RegExp(r"title: '([^']*)',"),
  RegExp(r"title: const Text\('([^']*)'\)"),
  RegExp(r"label: const Text\('([^']*)'\)"),
  RegExp(r"label: Text\('([^']*)'\)"),
  RegExp(r"name: '([^']*)',"),
];

/// Whether [title] reads as a title rather than a sentence.
///
/// Prose is not in Title Case and should not be dragged into it, so
/// anything that ends in a full stop, carries an interpolation, or is
/// mostly lowercase is left alone.
bool looksLikeATitle(String title) {
  final words = title.split(' ');
  if (words.length < 2 || words.length > 8) return false;
  if (title.contains(r'$') || title.endsWith('.') || title.endsWith(':')) {
    return false;
  }
  final capitals = words.where(
    (w) => w.isNotEmpty && w[0] == w[0].toUpperCase(),
  );
  return capitals.length >= words.length - 2;
}

void main() {
  test('every title in the app is in Title Case', () {
    final wrong = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      // The library is tune data: song titles are spelled how they are
      // spelled, and none of this applies to them.
      if (file.path.contains('standards') ||
          file.path.contains('tune_library')) {
        continue;
      }
      final text = file.readAsStringSync();
      for (final pattern in _patterns) {
        for (final match in pattern.allMatches(text)) {
          final title = match.group(1)!;
          if (allowed.contains(title) || !looksLikeATitle(title)) continue;
          final words = title.split(' ');
          for (final (i, word) in words.indexed) {
            if (word.isEmpty) continue;
            final first = i == 0;
            final last = i == words.length - 1;
            final joining = joins.contains(word.toLowerCase());
            final capital = word[0] == word[0].toUpperCase();
            if (!first && !last && joining && capital) {
              wrong.add('"$title": "$word" should be lowercase');
            } else if ((first || last) && joining && !capital) {
              wrong.add('"$title": "$word" should be capitalised');
            }
          }
        }
      }
    }
    expect(wrong, isEmpty, reason: wrong.join('\n'));
  });

  test('the rule itself is what the app was already using', () {
    // Not a new convention invented for this test: these are titles the
    // app had before anybody swept anything.
    for (final title in ['Trade With the Drums', 'Lay Out on the Solos']) {
      final words = title.split(' ');
      for (final (i, word) in words.indexed) {
        if (i == 0 || i == words.length - 1) continue;
        if (joins.contains(word.toLowerCase())) {
          expect(word, word.toLowerCase(), reason: title);
        }
      }
    }
  });

  test('a title that is really a sentence is left alone', () {
    expect(looksLikeATitle('The band plays from the top.'), isFalse);
    expect(looksLikeATitle('Hear It in Fourths'), isTrue);
    expect(
      looksLikeATitle('Swing'),
      isFalse,
      reason: 'one word, nothing to get wrong',
    );
  });
}
