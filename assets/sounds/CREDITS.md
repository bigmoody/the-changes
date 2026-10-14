# Instrument sample credits

The recorded instruments in The Changes come from these free libraries.
The files were trimmed and converted to mono 16-bit WAV with
`tool/process_samples.py`; the list of original files is in
`tool/sample_sources.txt`.

| Instrument | Library | Author | Licence |
|---|---|---|---|
| Upright bass | [Sneakybass](https://github.com/sfzinstruments/karoryfer.sneakybass) | Karoryfer Samples (played by Drogomir Smolken) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) – no attribution required |
| Piano | [Salamander Grand Piano V3](https://github.com/sfzinstruments/SalamanderGrandPiano) | Alexander Holm | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/) – **attribution required** (shown in the app's About screen) |
| Guitar | [Emilyguitar](https://github.com/sfzinstruments/karoryfer.emilyguitar) (flatwound strings, direct) | Karoryfer Samples (played by D. Smolken) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) – no attribution required |
| Drums | [Virtuosity Drums](https://github.com/sfzinstruments/virtuosity_drums) | Versilian Studios & Karoryfer Samples | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) – no attribution required |
| Drums, brushes | [Swirly Drums](https://github.com/sfzinstruments/karoryfer.swirly-drums) | Karoryfer Samples | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) – no attribution required |

The brush kit is normalised drum by drum to the peak of the stick kit's
matching drum rather than as one group. The grooves' velocities were
written against the stick kit's balance, which is what an overhead
microphone hears: the snare cracks and the kick, across the room, is the
quietest thing there. Matching it means changing kit changes the tone and
not the arrangement.

Changes made to the Salamander samples (as CC BY asks us to note): trimmed
to 3 seconds with a fade-out, mixed to mono, resampled to 44.1 kHz and
converted to 16-bit.

## Lettering and notation

Chord symbols and titles are lettered in Petaluma Script, and the staves
are drawn in its music-notation companion, Petaluma — both by Steinberg
Media Technologies GmbH (https://github.com/steinbergmedia/petaluma), under
the [SIL Open Font License 1.1](../fonts/OFL.txt) (reserved font name
"Petaluma"). They're bundled unmodified as `assets/fonts/PetalumaScript.otf`
and `assets/fonts/Petaluma.otf`.
