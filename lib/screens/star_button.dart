// The star beside a tune in a list.
//
// Drawn in the pencil red the chords are written in, so a starred tune
// looks marked up by hand rather than decorated.

import 'package:flutter/material.dart';

import '../library/library_store.dart';

class StarButton extends StatelessWidget {
  const StarButton({
    super.key,
    required this.library,
    required this.tune,
    required this.title,
  });

  final LibraryStore library;
  final TuneRef tune;

  /// The tune's title, for what a screen reader reads out.
  final String title;

  @override
  Widget build(BuildContext context) {
    final on = library.isFavourite(tune);
    return IconButton(
      icon: Icon(on ? Icons.star : Icons.star_border),
      color: on ? Theme.of(context).colorScheme.tertiary : null,
      tooltip: on ? 'Unstar $title' : 'Star $title',
      onPressed: () => library.toggleFavourite(tune),
    );
  }
}
