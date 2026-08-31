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

# --- IMA ADPCM ---------------------------------------------------------------
# 8 bit samples would need 12 of the 46 block RAMs on a Tang Nano 20k. Encoding
# to 4 bit brings that down to four, at a measured deviation of 0.6% for the hum
# and 2.2% for the seek. Noise like material compresses well.

STEP = [7,8,9,10,11,12,13,14,16,17,19,21,23,25,28,31,34,37,41,45,50,55,60,66,73,80,88,97,
107,118,130,143,157,173,190,209,230,253,279,307,337,371,408,449,494,544,598,658,724,796,
876,963,1060,1166,1282,1411,1552,1707,1878,2066,2272,2499,2749,3024,3327,3660,4026,4428,
4871,5358,5894,6484,7132,7845,8630,9493,10442,11487,12635,13899,15289,16818,18500,20350,
22385,24623,27086,29794,32767]
IDX = [-1,-1,-1,-1,2,4,6,8]

def adpcm_encode(samples):
    pred = idx = 0
    out = []
    for s in samples:
        step = STEP[idx]
        diff = s - pred
        code = 0
        if diff < 0:
            code = 8
            diff = -diff
        t = step
        if diff >= t: code |= 4; diff -= t
        t >>= 1
        if diff >= t: code |= 2; diff -= t
        t >>= 1
        if diff >= t: code |= 1
        d = step >> 3
        if code & 4: d += step
        if code & 2: d += step >> 1
        if code & 1: d += step >> 2
        pred = pred - d if code & 8 else pred + d
        pred = max(-32768, min(32767, pred))
        idx = max(0, min(88, idx + IDX[code & 7]))
        out.append(code)
    return out

def write_adpcm(name, sig):
    q = np.clip(np.round(sig / np.abs(sig).max() * 120), -128, 127).astype(np.int8)
    codes = adpcm_encode(q.astype(np.int32) * 256)
    with open(os.path.join(OUT, name + ".adpcm.hex"), "w") as f:
        f.write("".join("%x\n" % c for c in codes))
    print("%-6s %5d samples  %6.1f ms  %5d bytes packed" %
          (name, len(codes), 1000 * len(codes) / SR, (len(codes) + 1) // 2))

write_adpcm("motor", loopify(resample(d[int(4.30 * sr):int(5.16 * sr)], sr, SR)))
write_adpcm("seek",  loopify(resample(d[int(16.15 * sr):int(16.55 * sr)], sr, SR)))
