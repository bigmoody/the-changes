"""Makes the Beat This! model the app follows a broadcast with, in Core ML.

Beat This! (Foscarin, Schlueter and Widmer, ISMIR 2024) is MIT licensed,
code and weights: https://github.com/CPJKU/beat_this. This takes its
"final0" checkpoint, downloaded by the beat_this package on first use, and
writes it as a Core ML model for exactly the window the app runs it on
(BeatTracker.swift): 1000 spectrogram frames, padded by 6 on each side.
Weights in 32-bit floats, about 78 MB, to ios/Models/, which git ignores.
In 16-bit floats (half the size) it was not safe: on a Mac's processor it
gave the same answer for every frame, and on an iPad's graphics chip it
heard three times the barlines a Mac did in the same twenty seconds.
Debug builds compile it into the app if it is there.

Needs Python 3.11 with beat_this, torch 2.2, soundfile, soxr and
coremltools 7.2. With a WAV, it also checks the Core ML model against
PyTorch on the first twenty seconds of it.

Usage: python -I tool/beat_this/convert.py [check.wav]
"""
import os
import sys

import coremltools as ct
import numpy as np
import torch
from beat_this.inference import load_model

FRAMES, BORDER = 1000, 6
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "ios", "Models", "BeatThis.mlpackage")

model = load_model("final0", "cpu")

# Core ML cannot read the rotary embedding's outer product written as an
# einsum, and the embedding's cache makes each trace differ from the
# last: both are replaced for the export, which leaves the sums the same.
import rotary_embedding_torch.rotary_embedding_torch as rotary  # noqa: E402

_einsum = rotary.einsum


def _outer(equation, *tensors):
    if equation.replace(" ", "") == "...,f->...f":
        return tensors[0][..., None] * tensors[1]
    return _einsum(equation, *tensors)


rotary.einsum = _outer
for module in model.modules():
    if isinstance(module, rotary.RotaryEmbedding):
        module.cache_if_possible = False


class Pair(torch.nn.Module):
    """The model with its two answers as a pair, which Core ML can name."""

    def __init__(self, inner):
        super().__init__()
        self.inner = inner

    def forward(self, spect):
        out = self.inner(spect)
        return out["beat"], out["downbeat"]


pair = Pair(model).eval()
example = torch.zeros(1, FRAMES + 2 * BORDER, 128)
traced = torch.jit.trace(pair, example)
converted = ct.convert(
    traced,
    inputs=[ct.TensorType(name="spect", shape=example.shape)],
    outputs=[ct.TensorType(name="beat"), ct.TensorType(name="downbeat")],
    convert_to="mlprogram",
    compute_precision=ct.precision.FLOAT32,
    minimum_deployment_target=ct.target.iOS15,
)
converted.short_description = "Beat This! final0 (MIT, CPJKU/beat_this): beats and downbeats, 50 frames a second."
os.makedirs(os.path.dirname(OUT), exist_ok=True)
converted.save(OUT)
print("Wrote", os.path.normpath(OUT))

if len(sys.argv) > 1:
    import soundfile as sf
    import soxr
    from beat_this.preprocessing import LogMelSpect

    x, sr = sf.read(sys.argv[1], dtype="float32")
    if x.ndim > 1:
        x = x.mean(axis=1)
    x = soxr.resample(x, sr, 22050).astype(np.float32)[: 20 * 22050]
    spect = LogMelSpect()(torch.tensor(x))[:FRAMES]
    padded = torch.nn.functional.pad(spect, (0, 0, BORDER, BORDER))[None]
    with torch.no_grad():
        want = pair(padded)
    got = converted.predict({"spect": padded.numpy()})
    for name, w in zip(("beat", "downbeat"), want):
        same = ((got[name] > 0) == (w.numpy() > 0)).mean()
        print(f"{name}: frames on the same side of even odds as PyTorch: {same:.4f}")
