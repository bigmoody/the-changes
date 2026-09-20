import 'package:flutter/material.dart';

import '../music/chord.dart';

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
        _LabelledRow(label: 'Chord Tones', value: chord.noteNames.join('  ')),
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
  const _LabelledRow({required this.label, required this.value});

  final String label;
  final String value;

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
          Expanded(child: Text(value, style: theme.textTheme.titleMedium)),
        ],
      ),
    );
  }
}

/// Slides up the details for [chord] from the bottom of the screen.
void showChordDetails(BuildContext context, Chord chord) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: ChordQualityDetails(chord: chord),
      ),
    ),
  );
}
