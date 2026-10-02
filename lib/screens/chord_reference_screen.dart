import 'package:flutter/material.dart';

import '../music/chord.dart';
import '../music/what_its_doing.dart';
import 'note_ink.dart';

/// A searchable index of chord symbols: what Δ, ø, °, − and friends mean.
class ChordReferenceScreen extends StatefulWidget {
  const ChordReferenceScreen({super.key});

  @override
  State<ChordReferenceScreen> createState() => _ChordReferenceScreenState();
}

class _ChordReferenceScreenState extends State<ChordReferenceScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final matches = chordQualities.where((quality) {
      if (query.isEmpty) return true;
      final written = quality.symbols
          .map(prettyQuality)
          .join(' ')
          .toLowerCase();
      return quality.name.toLowerCase().contains(query) ||
          written.contains(query) ||
          quality.symbols.join(' ').toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Chord Symbols')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search, e.g. "ø" or "minor"',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: matches.isEmpty
                ? const Center(child: Text('No matching chord symbols'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: matches.length,
                    itemBuilder: (context, index) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: ChordQualityDetails(
                          chord: Chord.parse(
                            'C${matches[index].symbols.first}',
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Name, alternative spellings, formula, notes and a plain-English
/// explanation for one chord. Used by the reference and the practice screen.
class ChordQualityDetails extends StatelessWidget {
  const ChordQualityDetails({super.key, required this.chord});

  final Chord chord;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quality = chord.quality;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(quality.name, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final symbol in quality.symbols)
              Chip(
                label: Text(
                  chord.displayWith(symbol),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: 12),
        _LabelledRow(
          label: 'Formula',
          value: quality.formula.map(prettyDegree).join('  '),
        ),
        _LabelledRow(label: 'Chord Tones', notes: chord.noteNames),
        if (chord.extensionNotes.isNotEmpty)
          _LabelledRow(
            label: 'Extensions',
            value: chord.extensionNotes
                .map((e) => '${e.note} (${e.degree})')
                .join('  '),
          ),
        const SizedBox(height: 8),
        Text(quality.description, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

class _LabelledRow extends StatelessWidget {
  const _LabelledRow({required this.label, this.value, this.notes})
    : assert(value != null || notes != null, 'a row needs something in it');

  final String label;
  final String? value;

  /// Note names instead of a line of text, so each one can be written in
  /// the colour its reader sees it in.
  final List<String>? notes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: notes == null
                ? Text(value!, style: theme.textTheme.titleMedium)
                : NoteNames(notes!, style: theme.textTheme.titleMedium),
          ),
        ],
      ),
    );
  }
}

/// Slides up the details for [chord] from the bottom of the screen.
///
/// [doing] is what this chord is doing in the tune it was tapped in, when
/// it was tapped on a chart rather than looked up in the reference. The
/// reference has no tune around it, so there is nothing to say there.
void showChordDetails(
  BuildContext context,
  Chord chord, {
  ChordMeaning? doing,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ChordQualityDetails(chord: chord),
              if (doing != null) ...[
                const SizedBox(height: 20),
                _WhatItIsDoing(doing: doing),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

/// What this chord is doing here, under the chord's own details.
///
/// Under rather than above: what the chord *is* comes first, because that
/// is the question somebody who tapped a chord symbol is most often
/// asking. What it is for is the part they did not know to ask.
class _WhatItIsDoing extends StatelessWidget {
  const _WhatItIsDoing({required this.doing});

  final ChordMeaning doing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            doing.short,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.tertiary,
            ),
          ),
          const SizedBox(height: 6),
          Text(doing.long, style: theme.textTheme.bodyMedium),
          if (doing.learn case final page?) ...[
            const SizedBox(height: 10),
            Text(
              'There is more about this in Learn, under $page.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
