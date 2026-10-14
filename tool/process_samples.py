"""Turns the downloaded sample libraries into small, app-ready WAV files.

For each file: decode with ffmpeg to mono 44.1 kHz, trim the silence before
the hit (so notes land on the beat), cut to a set length with a fade-out,
then write 16-bit WAV. One gain per instrument keeps natural loudness
differences between notes and velocity layers.
"""
import array, math, os, re, subprocess, sys, wave

RAW = sys.argv[1]
OUT = sys.argv[2]
# Optional group names, to redo one instrument without downloading the
# rest of the libraries again: `process_samples.py raw out guitar`.
ONLY = set(sys.argv[3:])
SR = 44100

def want(group):
    return not ONLY or group in ONLY

def decode(path, cents=0):
    # A tuning correction (from the library's own mapping) is applied by
    # resampling: playing the recording slightly faster raises its pitch.
    ratio = 2 ** (cents / 1200)
    filters = ["-af", f"asetrate={int(SR * ratio)},aresample={SR}"] if cents else []
    pcm = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(SR), *filters,
         "-f", "f32le", "-"], check=True, capture_output=True).stdout
    a = array.array("f"); a.frombytes(pcm); return a

def trim(samples, seconds, fade, onset_fraction=0.02, preroll=0.002):
    peak = max(abs(x) for x in samples) or 1.0
    start = next((i for i, x in enumerate(samples) if abs(x) >= peak * onset_fraction), 0)
    start = max(0, start - int(preroll * SR))
    out = samples[start:start + int(seconds * SR)]
    n = len(out); f = int(fade * SR)
    for i in range(max(0, n - f), n):
        out[i] *= (n - i) / f
    return out

def write(path, samples, gain):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    ints = array.array("h", (max(-32768, min(32767, int(x * gain * 32767))) for x in samples))
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(ints.tobytes())

def process(group, jobs, seconds=None, fade=None, headroom=0.89, gain=None):
    """jobs: (raw path, output path) or (raw, output, seconds, fade).

    Normalises the whole group together, unless [gain] is given (used when
    adding files later, to match the level of an earlier run)."""
    if not jobs:
        print(f"{group}: nothing to do")
        return
    decoded = []
    for job in jobs:
        src, out = job[0], job[1]
        secs, fd = (job[2], job[3]) if len(job) == 4 else (seconds, fade)
        decoded.append((out, trim(decode(src, TUNING.get(os.path.basename(src), 0)), secs, fd)))
    peak = max(max(abs(x) for x in s) for _, s in decoded)
    scale = gain if gain is not None else headroom / peak
    for out, s in decoded:
        write(out, s, scale)
    print(f"{group}: {len(decoded)} files, group peak {peak:.3f}, gain {scale:.3f}")

# Per-sample tuning corrections in cents, copied from sneakybass_pluck_map.sfz.
TUNING = {
    **{f"sneakybass_{n}_pluck_rr{rr}.wav": c
       for n, c in [("db2", 6), ("d2", 6), ("eb2", 33), ("e2", 55), ("c3", 12), ("d3", 10)]
       for rr in (1, 2)},
}

NAMES = {"c":0,"db":1,"d":2,"eb":3,"e":4,"f":5,"gb":6,"g":7,"ab":8,"a":9,"bb":10,"b":11}

# The kit level from the first run, so drums added later match it.
DRUM_GAIN = 0.89 / 0.161

# Bass: library names are written an octave above sounding pitch.
bass = []
for name in sorted(os.listdir(f"{RAW}/bass") if want("bass") else []):
    m = re.match(r"sneakybass_([a-g]b?)(\d)_pluck_rr(\d)\.wav", name)
    written = (int(m[2]) + 1) * 12 + NAMES[m[1]]
    bass.append((f"{RAW}/bass/{name}", f"{OUT}/bass/bass_{written - 12}_rr{m[3]}.wav"))
process("bass", bass, seconds=2.2, fade=0.35)

# Piano: Salamander names use C4 = MIDI 60. Velocity layers 5, 9, 13 → 1, 2, 3.
PIANO_NAMES = {"C":0, "D#":3, "F#":6, "A":9}
layers = {"5": 1, "9": 2, "13": 3}
piano = []
for name in sorted(os.listdir(f"{RAW}/piano") if want("piano") else []):
    m = re.match(r"([A-G]#?)(\d)v(\d+)\.flac", name)
    midi = (int(m[2]) + 1) * 12 + PIANO_NAMES[m[1]]
    piano.append((f"{RAW}/piano/{name}", f"{OUT}/piano/piano_{midi}_v{layers[m[3]]}.wav"))
process("piano", piano, seconds=3.0, fade=0.6)

def drums(prefix, pattern, seconds, fade):
    jobs = []
    if not want("drums"):
        return jobs
    for name in sorted(os.listdir(f"{RAW}/drums")):
        m = re.match(pattern, name)
        if m:
            jobs.append((f"{RAW}/drums/{name}", f"{OUT}/drums/{prefix}_" + "_".join(m.groups()) + ".wav", seconds, fade))
    return jobs

# Drums are normalised together so the kit's balance is preserved.
kit = (
    drums("ride", r"oh_ride_ride_vl(\d)_rr(\d)\.flac", 1.8, 0.5)
    + drums("hihat_pedal", r"oh_hh_pedal_vl(\d)_rr(\d)\.flac", 0.5, 0.15)
    + drums("hihat_closed", r"oh_hh_closed_vl(\d)_rr(\d)\.flac", 0.4, 0.12)
    + drums("kick", r"oh_kick_snoff_vl(\d)_rr(\d)\.flac", 0.7, 0.2)
    # Only the two middle cross-stick layers are used: the loudest crack
    # jumps 14 dB out of a bossa groove.
    + drums("cross_stick", r"oh_snare_crossstick_vl([67])\.flac", 0.4, 0.12)
    + drums("hihat_open", r"oh_hh_open_vl(\d)_rr(\d)\.flac", 0.6, 0.2)
    # Snare hits are numbered by loudness, not takes: quiet ones (4, 6, 8)
    # for jazz comping, loud ones (24, 26, 28) for a funk backbeat.
    + drums("snare", r"oh_snare_center_vl(\d+)\.flac", 0.7, 0.2)
)
process("drums", kit, gain=DRUM_GAIN)

# Calypso percussion: a cowbell and two toms. Each group is normalised on
# its own (at the kit's gain the toms clip), to peaks like the snare's and
# cross-stick's so they sit in the kit. Toms: layer 1 = velocity layers 6
# and 8, layer 2 = 11 and 13.
process("cowbell", drums("cowbell", r"Cowbell1_Normal_v([12])_rr([1-4])_Overhead\.wav", 0.5, 0.15), headroom=0.25)
toms = []
for tom, name in (("htom", "tom_high"), ("ltom", "tom_low")) if want("drums") else []:
    for layer, vls in ((1, (6, 8)), (2, (11, 13))):
        for take, vl in enumerate(vls, 1):
            toms.append((f"{RAW}/drums/oh_{tom}_center_vl{vl}.flac",
                         f"{OUT}/drums/{name}_{layer}_{take}.wav", 0.9, 0.3))
process("toms", toms, headroom=0.3)

# Guitar: Emilyguitar, an Epiphone strung with flatwounds and recorded
# direct through both pickups. Flatwounds are the jazz string and direct
# means no room microphone, which matters more than it sounds: the guitar
# this replaces was a blend of a pickup and a microphone several feet away,
# two recordings of one performance that were never going to agree.
#
# Every minor third from E2 to G♭5, the same pitches as before. Two of the
# library's four dynamics and three takes of each, so there are six
# recordings a note where there were four.
#
# One dynamic, the quietest. The library has four and two were tried, but
# once the tone is rolled off to 3 kHz they measure 0 to 7 per cent apart
# in brightness, in no consistent direction: after this much filtering a
# firmer stroke is only a louder one, and velocity already does louder.
# Carrying a second layer doubled the download to buy nothing.
#
# The tone knob comes right down (3 kHz) and the attack is eased off over
# 25 ms. Picked direct, the transient is a click before it is a note, and
# taking the point off it is most of what separates a guitar you can leave
# playing from one you switch off.
GUITAR_TONE = 3000
GUITAR_ATTACK_MS = 25

def ease_attack(samples, ms):
    """Take the point off the pick, without touching the note under it."""
    n = int(SR * ms / 1000)
    for i in range(min(n, len(samples))):
        x = i / n
        samples[i] *= x * x * (3 - 2 * x)   # smoothstep: no corner at either end
    return samples

guitar = []
for name in sorted(os.listdir(f"{RAW}/emily") if want("guitar") else []):
    m = re.match(r"([a-g]b?)(\d)_p_rr([123])\.wav", name)
    if not m:
        continue
    midi = (int(m[2]) + 1) * 12 + NAMES[m[1]]
    pcm = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", f"{RAW}/emily/{name}", "-ac", "1",
         "-ar", str(SR), "-af", f"lowpass=f={GUITAR_TONE}", "-f", "f32le", "-"],
        check=True, capture_output=True).stdout
    a = array.array("f"); a.frombytes(pcm)
    out = f"{OUT}/guitar/guitar_{midi}_rr{m[3]}.wav"
    guitar.append((out, ease_attack(trim(a, 1.8, 0.45), GUITAR_ATTACK_MS)))
if guitar:
    peak = max(max(abs(x) for x in s) for _, s in guitar)
    for out, samples in guitar:
        write(out, samples, 0.89 / peak)
    print(f"guitar: {len(guitar)} files, group peak {peak:.3f}")

# Brushes: a second kit, from Karoryfer's Swirly Drums, where nothing is
# played with sticks. Three velocity layers a drum rather than the stick
# kit's two, because the layer is now chosen by how hard the stroke is and
# this library records up to 22 of them; three takes rather than four, to
# keep a whole second kit inside a few megabytes.
#
# Each drum is brought to the peak of the stick kit's matching drum rather
# than the group being normalised together. The patterns' velocities were
# written against the stick kit's balance, which is an overhead's balance:
# the snare cracks and the kick, heard across the room, is the quietest
# thing in the kit. Normalising the brushes as a group instead would put
# their own balance under those velocities and the kick would swamp the
# ride. This way the kit changes tone and not the arrangement.
BRUSH_PEAKS = {
    "snare": 1.0, "hihat_open": 0.9603, "ride": 0.6707, "hihat_closed": 0.4969,
    "cross_stick": 0.3289, "hihat_pedal": 0.3264, "tom_high": 0.3000,
    "cowbell": 0.2500, "tom_low": 0.1469, "kick": 0.0774,
}
# Trimmed to the same lengths as the stick kit's matching drum.
BRUSH_TRIM = {
    "ride": (1.8, 0.5), "hihat_pedal": (0.5, 0.15), "hihat_closed": (0.4, 0.12),
    "hihat_open": (0.6, 0.2), "kick": (0.7, 0.2), "cross_stick": (0.4, 0.12),
    "snare": (0.7, 0.2), "tom_high": (0.9, 0.3), "tom_low": (0.9, 0.3),
    "cowbell": (0.5, 0.15),
}
if want("brushes"):
    by_drum = {}
    for name in sorted(os.listdir(f"{RAW}/brushes")):
        m = re.match(r"(.+)_(\d)_(\d)\.wav", name)
        secs, fd = BRUSH_TRIM[m[1]]
        by_drum.setdefault(m[1], []).append(
            (f"{OUT}/drums_brushes/{name}", trim(decode(f"{RAW}/brushes/{name}"), secs, fd)))
    for drum, files in sorted(by_drum.items()):
        peak = max(max(abs(x) for x in s) for _, s in files)
        scale = BRUSH_PEAKS[drum] / peak
        for out, samples in files:
            write(out, samples, scale)
        print(f"brushes {drum}: {len(files)} files, peak {peak:.4f}, gain {scale:.2f}")
