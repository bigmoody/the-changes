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

def onset_of(samples, onset_fraction=0.02, preroll=0.002):
    """Where the hit starts: the first sample worth hearing, less a hair."""
    peak = max(abs(x) for x in samples) or 1.0
    start = next((i for i, x in enumerate(samples) if abs(x) >= peak * onset_fraction), 0)
    return max(0, start - int(preroll * SR))

def trim(samples, seconds, fade, onset_fraction=0.02, preroll=0.002):
    start = onset_of(samples, onset_fraction, preroll)
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

# How long to keep, by register. The recordings run 13 to 16 seconds and
# were all cut at 3, which is a rule about the clock rather than about the
# piano: a low C is still only 27 dB down at 3 seconds and audibly going,
# while an A above middle C is at 37 and finished. Cutting them all at the
# same moment took most of the bass register's tail away and nothing from
# the treble's.
#
# These lengths instead land every note around 36 dB down before the fade
# starts, so each one is let go at the point it has actually died rather
# than at the point the shortest of them had. The fade is a fifth of the
# length in each case.
#
# What this buys is the thing a 3-second cut could not give at any tempo
# under about 110: a chord held for a whole bar of a ballad used to run
# out halfway through and fade while it was still being held.
PIANO_SECONDS = {48: 8.0, 51: 8.0, 54: 6.5, 57: 6.5, 60: 5.0, 63: 5.0,
                 66: 3.5, 69: 3.5, 72: 3.5}
piano = []
for name in sorted(os.listdir(f"{RAW}/piano") if want("piano") else []):
    m = re.match(r"([A-G]#?)(\d)v(\d+)\.flac", name)
    midi = (int(m[2]) + 1) * 12 + PIANO_NAMES[m[1]]
    secs = PIANO_SECONDS[midi]
    piano.append((f"{RAW}/piano/{name}", f"{OUT}/piano/piano_{midi}_v{layers[m[3]]}.wav",
                  secs, secs / 5))
process("piano", piano)

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
# Trimmed to the same lengths as the stick kit's matching drum, except the
# snare.
#
# This drum is not damped, and a brush stroke on an undamped head leaves the
# snare wires buzzing: measured against its own peak, the ring is still only
# 17 to 19 dB down at 0.2s on the library's worst takes, where the stick
# kit's snare is 25 dB down. At the stick snare's length the fade starts at
# 0.5s and never reaches it, so the ring played at full level and the kit
# sounded resonant rather than brushed. Shorter, with a fade long enough to
# cover 0.2s onwards: 3 dB off the ring at 0.2s and 13 dB at 0.3s, against
# 0.8 dB at 0.15s, which is still the stroke itself.
BRUSH_TRIM = {
    "ride": (1.8, 0.5), "hihat_pedal": (0.5, 0.15), "hihat_closed": (0.4, 0.12),
    "hihat_open": (0.6, 0.2), "kick": (0.7, 0.2), "cross_stick": (0.4, 0.12),
    "snare": (0.35, 0.22), "tom_high": (0.9, 0.3), "tom_low": (0.9, 0.3),
    "cowbell": (0.5, 0.15),
}
# A gel pad on the brush snare's head.
#
# This drum is tuned high and barely damped, and it sings. Measuring one
# stroke in slices, the mode at 318 Hz stands 22.6 dB above the energy
# either side of it at the attack, 26.6 dB by 0.08s and still 25.8 dB at
# 0.15s: as the broadband stroke dies away the drum is left sounding a
# pitch. That is what an undamped head does and it is what a gel pad on
# the head is for.
#
# Which makes this a question of decay and not of balance. Two earlier
# attempts at it went wrong by treating it as balance: EQ enough to flatten
# the mode costs 43 dB of narrow cuts, 21 of them on the fundamental, and
# mixing in the library's room recording smooths the mode but lengthens
# the tail, which is the opposite of damping. Shortening the recordings
# does nothing either, the taps at 140 bpm being shorter than the trim
# already: 0.35s down to 0.20s moved the rendered level by 0.03 dB.
#
# So this does what the pad does. Each mode's own content is taken out
# progressively: none at the attack, so the stroke keeps the character it
# was played with, and nearly all of it [BRUSH_GEL_TAU] later, so the head
# stops ringing on. Subtracting a band-pass is a notch, so at full gate
# the mode is gone and nothing else is touched.
BRUSH_GEL_MODES = (318, 449, 566)
BRUSH_GEL_Q = 2.5
BRUSH_GEL_TAU = 0.012

def bandpass(samples, f0, q):
    """Just the content around [f0], at full level there."""
    w0 = 2 * math.pi * f0 / SR
    al = math.sin(w0) / (2 * q)
    c = math.cos(w0)
    a0 = 1 + al
    b0, b2 = al / a0, -al / a0
    a1, a2 = -2 * c / a0, (1 - al) / a0
    out = array.array("f", [0.0]) * len(samples)
    x1 = x2 = y1 = y2 = 0.0
    for i, x in enumerate(samples):
        y = b0 * x + b2 * x2 - a1 * y1 - a2 * y2
        out[i] = y
        x2, x1 = x1, x
        y2, y1 = y1, y
    return out

def gel(samples, onset, modes, q, tau):
    """Damps [modes] from [onset] on, over [tau] seconds.

    One mode at a time, each taken out of what the one before it left.
    Not from the original: at these widths the bands overlap, and three
    band-passes of the same signal subtracted together put each other's
    skirts back where the others had just taken a mode out. Measured on
    one stroke, that fills the notch in from 17.2 dB deep to 1.4.
    """
    out = array.array("f", samples)
    gate = [
        0.0 if i < onset else 1 - math.exp(-((i - onset) / SR) / tau)
        for i in range(len(samples))
    ]
    for f0 in modes:
        band = bandpass(out, f0, q)
        for i in range(len(out)):
            out[i] -= band[i] * gate[i]
    return out

if want("brushes"):
    by_drum = {}
    ungelled = []
    for name in sorted(os.listdir(f"{RAW}/brushes")):
        m = re.match(r"(.+)_(\d)_(\d)\.wav", name)
        secs, fd = BRUSH_TRIM[m[1]]
        raw = decode(f"{RAW}/brushes/{name}")
        hit = trim(raw, secs, fd)
        if m[1] == "snare":
            ungelled.append(hit)
            hit = trim(
                gel(raw, onset_of(raw), BRUSH_GEL_MODES, BRUSH_GEL_Q, BRUSH_GEL_TAU),
                secs, fd)
        by_drum.setdefault(m[1], []).append((f"{OUT}/drums_brushes/{name}", hit))
    for drum, files in sorted(by_drum.items()):
        peak = max(max(abs(x) for x in s) for _, s in files)
        scale = BRUSH_PEAKS[drum] / peak
        for out, samples in files:
            write(out, samples, scale)
        note = ""
        if drum == "snare" and ungelled:
            # What the gel costs in energy at this peak, which is what the
            # band has to put back: see _brushGelMakeUp in backing_synth.
            was = max(max(abs(x) for x in s) for s in ungelled) or 1.0
            e0 = sum(sum((x / was) ** 2 for x in s) for s in ungelled)
            e1 = sum(sum((x * scale / BRUSH_PEAKS[drum]) ** 2 for x in s)
                     for _, s in files)
            note = f", gel costs {10 * math.log10(e0 / e1):.2f} dB of energy"
        print(f"brushes {drum}: {len(files)} files, peak {peak:.4f}, "
              f"gain {scale:.2f}{note}")

# The brush swirl: the left hand's circle on the snare head, which is what
# makes a brush groove sound played rather than tapped.
#
# The library records stirring as long continuous takes, 6 to 13 seconds,
# meant for a sampler to loop at whatever speed the circle wants. Checked
# for a circle period and there is none worth speaking of: autocorrelation
# over the envelope decays from the shortest lag out, so the recordings are
# even washes. That means slices can be cut from them and shaped here
# rather than fighting dynamics already in the take.
#
# Each slice is one full circle, which is two beats, and it is shaped the
# way the circle is played: the backward half long and quiet, the forward
# half building into the downbeat. It runs 20 per cent past its circle and
# decays, so consecutive circles overlap and the join is a crossfade and
# not an edge. The band stretches the whole thing to the tempo, so two
# lengths are enough to keep that stretch near 1.
SWIRL_PEAK = 0.25
SWIRL_OVERLAP = 1.2
if want("swirl"):
    srcs = ["stir_2_1", "stir_3_1", "stir_3_2"]
    swirl = []
    for layer, unit in enumerate([0.75, 1.5], 1):   # two beats at 160 and 80
        for take, src in enumerate(srcs, 1):
            a = decode(f"{RAW}/brushes_stir/{src}.wav")
            n = int(unit * SWIRL_OVERLAP * SR)
            # Taken from a different place in each recording, so three takes
            # of one circle are not three copies of one. Kept clear of both
            # ends: the recordings are 6 to 13 seconds and a slice that
            # runs off the end is a circle that stops half way round.
            start = min(int(SR * (1.0 + take * 1.7 + layer * 0.9)), len(a) - n)
            s = array.array("f", a[start:start + n])
            assert len(s) == n, f"{src} is too short for a {unit}s circle"
            circle = int(unit * SR)
            for i in range(len(s)):
                if i < circle:
                    s[i] *= 0.45 + 0.55 * (i / circle) ** 1.6
                else:
                    x = (i - circle) / (len(s) - circle)
                    s[i] *= 0.5 * (1 + math.cos(math.pi * x))
            fade = int(0.008 * SR)
            for i in range(fade):
                s[i] *= i / fade
            swirl.append((f"{OUT}/drums_brushes/swirl_{layer}_{take}.wav", s))
    peak = max(max(abs(x) for x in s) for _, s in swirl)
    for out, s in swirl:
        write(out, s, SWIRL_PEAK / peak)
    print(f"swirl: {len(swirl)} files, peak {peak:.4f}, gain {SWIRL_PEAK / peak:.2f}")

# A tighter snare, for funk: the same drum through the close microphone
# instead of the overheads.
#
# The overhead snare is the kit's snare because the kit is an overhead's
# kit, and on a jazz backbeat that is right: what you want there is the
# drum in its room. Funk wants the drum and not the room. The close mic is
# 10 dB down by 0.1 of a second and 46 by 0.3, where the overhead is still
# ringing at 0.7, so it is trimmed much shorter and there is nothing to cut
# off.
#
# Normalised to the same peak as the overhead snare it replaces, so the
# pattern's velocity means what it meant: the tone changes and the level
# does not.
if want("snaretight"):
    tight = []
    for level in (6, 8, 10, 24, 26, 28):
        tight.append((
            f"{RAW}/drums/snaremic_snare_center_vl{level}.flac",
            f"{OUT}/drums/snare_tight_{level}.wav", 0.35, 0.12))
    decoded = [(out, trim(decode(src), secs, fd)) for src, out, secs, fd in tight]
    peak = max(max(abs(x) for x in s) for _, s in decoded)
    for out, s in decoded:
        write(out, s, 1.0 / peak)
    print(f"snare tight: {len(decoded)} files, peak {peak:.4f}, gain {1.0 / peak:.2f}")

# A close kick, for funk: the same drum through the microphone inside it.
#
# The kit's kick is the overheads' kick, which is a kick heard across a
# room, and that is right for jazz where it is feathered under everything.
# In funk it is the floor of the groove, and the overhead kick cannot be
# that at any level: its peak is 0.077 against the snare's 1.0, so at full
# velocity it is still 22 dB under the backbeat. Velocity cannot fix a
# recording that quiet.
#
# So funk gets the close microphone, normalised to a peak that sits with
# the funk snare rather than to the overheads' balance. Trimmed to 0.4 s,
# where the overhead kick is 0.7: the close mic is 27 dB down by 0.3 and
# a funk kick is a punch rather than a boom.
if want("kickclose"):
    close = []
    for layer, vl in ((1, 2), (2, 4)):
        for take in (1, 2, 3, 4):
            close.append((
                f"{RAW}/drums/kickmic_kick_snoff_vl{vl}_rr{take}.flac",
                f"{OUT}/drums/kick_close_{layer}_{take}.wav", 0.4, 0.14))
    decoded = [(out, trim(decode(src), secs, fd)) for src, out, secs, fd in close]
    peak = max(max(abs(x) for x in s) for _, s in decoded)
    for out, s in decoded:
        write(out, s, 0.55 / peak)
    print(f"kick close: {len(decoded)} files, peak {peak:.4f}, gain {0.55 / peak:.2f}")

# A quieter cross-stick, so the clave can be a click.
#
# There was one cross-stick sound in the kit, from layers 6 and 7 of the
# library's sixteen, and it was doing four jobs: the bossa clave, the
# brush bossa's, the calypso and the samba. A bossa clave is a cross-stick
# and that part was right, but at that stroke weight it is a crack rather
# than a click, and with one layer there was nothing softer to ask for.
# The samba asks for `hard` and could not have it either.
#
# Layers 1 and 2, which are 19 dB under 6 and 7: a stick laid on the rim
# rather than knocked against it. At the kit's own gain, so they sit where
# the rest of the kit sits; the levelling in DrumSamples brings the layer
# up to the loud one's peak afterwards, so what changes between the two is
# the tone and not the level.
#
# Measured before choosing, because the two things wanted pull against
# each other. The takes inside a layer are played round-robin, so they
# have to be within a couple of dB of each other or a steady click jumps
# about; the layers have to be far apart or there is no point having two.
# Peaks across the quiet end, in dBFS:
#
#   vl1 −45.0   vl2 −43.7   vl3 −38.6   vl4 −32.4   vl5 −30.4   vl6 −25.9
#
# so vl1+vl2 are 1.3 dB apart and 19 under the loud pair, vl4+vl5 are 2 dB
# apart but only 5 under it, and vl3+vl4 are 6 dB apart from each other,
# which is the version of this that went in first and made a click that
# alternated between two levels. vl1 and vl2 still have 31 dB over their
# own noise floor, which survives being brought up.
if want("crossstick"):
    process("cross stick", [
        (f"{RAW}/drums/oh_snare_crossstick_vl{level}.flac",
         f"{OUT}/drums/cross_stick_{level}.wav", 0.4, 0.12)
        for level in (1, 2)
    ], gain=DRUM_GAIN)
