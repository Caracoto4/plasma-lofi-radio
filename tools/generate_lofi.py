#!/usr/bin/env python3
"""Procedural lofi generator (pure stdlib) -> 16-bit mono WAV files.

Creates a few warm, loopable lofi loops: soft detuned chords, a mellow bass,
a gentle kick and vinyl crackle, all run through a simple low-pass filter.
"""
import math
import random
import struct
import wave
import os

SR = 44100
# lives in tools/, the loops belong to the package
_REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(_REPO, "package", "contents", "audio")


def midi_to_freq(m):
    return 440.0 * (2.0 ** ((m - 69) / 12.0))


def note_wave(freq, dur, amp, detune=0.0, harmonics=(1.0, 0.35, 0.12)):
    """Return a list of samples for a soft, slightly detuned tone."""
    n = int(dur * SR)
    out = [0.0] * n
    f = freq * (1.0 + detune)
    attack = int(0.02 * SR)
    release = int(0.35 * SR)
    for i in range(n):
        t = i / SR
        s = 0.0
        for h, ha in enumerate(harmonics, start=1):
            s += ha * math.sin(2 * math.pi * f * h * t)
        # gentle tremolo for warmth
        s *= 1.0 + 0.06 * math.sin(2 * math.pi * 4.5 * t)
        # envelope
        env = 1.0
        if i < attack:
            env = i / attack
        elif i > n - release:
            env = max(0.0, (n - i) / release)
        out[i] = s * amp * env
    return out


def kick(dur=0.28, amp=0.5):
    n = int(dur * SR)
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        f = 120.0 * math.exp(-t * 22.0) + 45.0
        env = math.exp(-t * 9.0)
        out[i] = math.sin(2 * math.pi * f * t) * env * amp
    return out


def add(buf, samples, start):
    for i, s in enumerate(samples):
        j = start + i
        if 0 <= j < len(buf):
            buf[j] += s


def lowpass(buf, cutoff):
    """One-pole low-pass filter."""
    rc = 1.0 / (2 * math.pi * cutoff)
    dt = 1.0 / SR
    a = dt / (rc + dt)
    y = 0.0
    for i in range(len(buf)):
        y += a * (buf[i] - y)
        buf[i] = y
    return buf


def vinyl_crackle(buf, amount=0.012, density=0.0009):
    for i in range(len(buf)):
        if random.random() < density:
            buf[i] += random.uniform(-1, 1) * amount
        buf[i] += random.uniform(-1, 1) * 0.0015  # hiss


def normalize(buf, peak=0.85):
    m = max(1e-9, max(abs(x) for x in buf))
    k = peak / m
    return [x * k for x in buf]


def write_wav(path, buf):
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for x in buf:
            v = int(max(-1.0, min(1.0, x)) * 32767)
            frames += struct.pack("<h", v)
        w.writeframes(bytes(frames))


def make_track(name, progression, bpm, bars=8, bass_oct=-2):
    beat = 60.0 / bpm
    bar = beat * 4
    total = int(bar * bars * SR) + SR  # +1s tail
    buf = [0.0] * total

    for b in range(bars):
        chord = progression[b % len(progression)]
        start = int(b * bar * SR)
        # chord pad
        for m in chord:
            add(buf, note_wave(midi_to_freq(m), bar * 0.98, 0.16, detune=0.0015), start)
        # bass on root
        root = chord[0] + bass_oct * 12
        add(buf, note_wave(midi_to_freq(root), bar * 0.9, 0.30,
                           harmonics=(1.0, 0.2)), start)
        # kick on beats 1 and 3
        add(buf, kick(), start)
        add(buf, kick(amp=0.35), start + int(2 * beat * SR))

    lowpass(buf, 2600)
    vinyl_crackle(buf)
    buf = normalize(buf, 0.82)
    # fade in / out for seamless-ish loop
    fi = int(0.4 * SR)
    for i in range(fi):
        buf[i] *= i / fi
        buf[-1 - i] *= i / fi
    path = os.path.join(OUT_DIR, name)
    write_wav(path, buf)
    print("wrote", path, f"{len(buf)/SR:.1f}s")


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    random.seed(7)
    # Am7 Dm7 G7 Cmaj7
    make_track("midnight_study.wav",
               [[57, 60, 64, 67], [62, 65, 69, 72],
                [55, 59, 62, 65], [60, 64, 67, 71]], bpm=70)
    # Fmaj7 Em7 Dm7 Cmaj7
    make_track("rainy_window.wav",
               [[53, 57, 60, 64], [52, 55, 59, 62],
                [50, 53, 57, 60], [48, 52, 55, 59]], bpm=64)
    # Cmaj7 Am7 Fmaj7 G7
    make_track("coffee_break.wav",
               [[60, 64, 67, 71], [57, 60, 64, 67],
                [53, 57, 60, 64], [55, 59, 62, 65]], bpm=76)


if __name__ == "__main__":
    main()
