import 'package:flutter/material.dart';

import '../music/tune.dart';

/// A row of chips for showing one genre at a time: All, Swing, Blues …
/// Only genres something in the list belongs to are offered.
class GenreFilter extends StatelessWidget {
  const GenreFilter({
    super.key,
    required this.available,
    required this.selected,
    required this.onChanged,
    this.mine,
    this.onMine,
  });

  /// Whether Mine is chosen, in a list that has one: My Changes, where
  /// some are the player's own and some came from somewhere else. Null
  /// leaves the chip out. Choosing it is instead of a genre, like
  /// choosing any other chip in the row.
  final bool? mine;
  final ValueChanged<bool>? onMine;

  final Set<Genre> available;

  /// The genre shown, or null for everything.
  final Genre? selected;
  final ValueChanged<Genre?> onChanged;

  /// Every genre in [tunes], for [available].
  static Set<Genre> of(Iterable<Tune> tunes) => {
    for (final tune in tunes) ...tune.genres,
  };

  @override
  Widget build(BuildContext context) {
    // In alphabetical order, after All.
    final genres = Genre.values.where(available.contains).toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    // All built at once (there are only a few), so a screen reader can reach
    // every one without scrolling first.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          for (final genre in <Genre?>[null, ...genres]) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: ValueKey('genre-filter-${genre?.name ?? 'all'}'),
                label: Text(genre?.label ?? 'All'),
                showCheckmark: false,
                selected: selected == genre && mine != true,
                // Tapping the chosen genre again goes back to All.
                onSelected: (on) {
                  onMine?.call(false);
                  onChanged(on ? genre : null);
                },
              ),
            ),
            // Straight after All: it is a different kind of question
            // from the genres, which one is yours rather than what it is.
            if (genre == null && mine != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  key: const ValueKey('genre-filter-mine'),
                  label: const Text('Mine'),
                  showCheckmark: false,
                  selected: mine!,
                  onSelected: (on) {
                    onChanged(null);
                    onMine?.call(on);
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }
}
