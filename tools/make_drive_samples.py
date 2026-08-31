#!/usr/bin/env python3
"""
Generate the floppy drive sound samples for drive_sound.v.

Source: https://commons.wikimedia.org/wiki/File:Floppy_drive_sounds.ogg
        by AlepouTheFox, CC0 (public domain dedication)

The recording is 27.6s of a real 3.5" drive. Two passages are extracted:

  motor  4.30-5.30s  the quietest steady stretch, RMS equal to the noise floor,
                     verified to contain no head movement
  seek  16.15-16.55s a continuous multi track seek

Both are low pass filtered before downsampling -- without that, the high
frequency content of a drive folds back as aliasing and sounds broken.
Each sample is normalised on its own so the 8 bit range is used fully; the
balance between them is set by the gain constants in drive_sound.v, not here.

    pip install soundfile numpy
    python tools/make_drive_samples.py
"""
import numpy as np, soundfile as sf, sys, urllib.request, os

URL = "https://upload.wikimedia.org/wikipedia/commons/d/db/Floppy_drive_sounds.ogg"
SRC = "Floppy_drive_sounds.ogg"
OUT = os.path.join(os.path.dirname(__file__), "..", "src", "misc")
SR  = 16000

def lowpass(x, fc, sr, taps=127):
    n = np.arange(taps) - (taps - 1) / 2
    h = np.sinc(2 * fc / sr * n) * np.hamming(taps)
    return np.convolve(x, h / h.sum(), mode="same")

def resample(x, sr_in, sr_out):
    x = lowpass(x, sr_out * 0.45, sr_in)
    n = int(len(x) * sr_out / sr_in)
    return np.interp(np.linspace(0, len(x) - 1, n), np.arange(len(x)), x)

def loopify(x, ms=60, sr=SR):
    xf = int(sr * ms / 1000)
    x = x.copy()
    x[:xf] = x[:xf] * np.linspace(0, 1, xf) + x[-xf:] * np.linspace(1, 0, xf)
    return x[:-xf]

def write_hex(name, sig):
    q = np.clip(np.round(sig / np.abs(sig).max() * 120), -128, 127).astype(np.int8)
    with open(os.path.join(OUT, name + ".hex"), "w") as f:
        f.write("".join("%02x\n" % (int(v) & 0xff) for v in q))
    print("%-6s %5d samples  %6.1f ms" % (name, len(q), 1000 * len(q) / SR))

if not os.path.exists(SRC):
    print("downloading", URL)
    urllib.request.urlretrieve(URL, SRC)

d, sr = sf.read(SRC)
d = d.astype(np.float64)
write_hex("motor", loopify(resample(d[int(4.30 * sr):int(5.30 * sr)], sr, SR)))
write_hex("seek",  loopify(resample(d[int(16.15 * sr):int(16.55 * sr)], sr, SR)))
