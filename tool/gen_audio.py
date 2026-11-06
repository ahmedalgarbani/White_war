"""Procedurally synthesises every sound effect and the music loop used by White War.

Run:  python3 tool/gen_audio.py   (needs numpy; ffmpeg for the .ogg music)
All audio is original and generated from scratch, so there are no licensing concerns.
"""
import os
import subprocess
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio')
rng = np.random.default_rng(7)


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def env(n, attack=0.005, release=None, curve=6.0):
    """Fast attack + exponential decay envelope of length n samples."""
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    dur = n / SR
    d = np.exp(-curve * t / dur)
    if release:
        r = np.clip((dur - t) / release, 0, 1)
        d = d * r
    return a * d


def lowpass(x, cutoff):
    # simple one-pole low pass
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def save(name, x, gain=0.9):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) or 1.0
    x = x / peak * gain
    data = (x * 32767).astype(np.int16)
    path = os.path.join(OUT, name)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    return path


def bell(freq, dur, ratio=3.5, index=2.0, decay=5.0):
    t = t_axis(dur)
    mod = np.sin(2 * np.pi * freq * ratio * t) * index * np.exp(-decay * 1.5 * t)
    return np.sin(2 * np.pi * freq * t + mod) * np.exp(-decay * t)


def note_freq(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


# ---------------------------------------------------------------- effects
def gen_throw():
    n = int(SR * 0.2)
    noise = rng.standard_normal(n)
    sweep = np.linspace(600, 2600, n)
    t = np.arange(n) / SR
    tone = np.sin(2 * np.pi * np.cumsum(sweep) / SR) * 0.15
    x = highpass(lowpass(noise, 2500), 500) + tone
    e = np.sin(np.pi * np.clip(t / 0.2, 0, 1)) ** 2
    save('throw.wav', x * e, 0.55)


def gen_hit():
    t = t_axis(0.22)
    thump = np.sin(2 * np.pi * (180 - 300 * t) * t) * np.exp(-25 * t)
    splash = lowpass(rng.standard_normal(len(t)), 3500) * np.exp(-14 * t)
    save('hit.wav', thump * 0.9 + splash * 0.6, 0.75)


def gen_pop():
    t = t_axis(0.08)
    f = 520 + 900 * t / 0.08
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(t), 0.002, curve=5)
    save('pop.wav', x, 0.5)


def gen_coin():
    a = bell(1318.5, 0.12, ratio=2.0, index=1.0, decay=18)
    b = bell(1975.5, 0.3, ratio=2.0, index=1.2, decay=9)
    x = np.zeros(int(SR * 0.36))
    x[:len(a)] += a
    off = int(SR * 0.06)
    x[off:off + len(b)] += b
    save('coin.wav', x, 0.55)


def gen_unlock():
    notes = [72, 76, 79, 84, 88]
    x = np.zeros(int(SR * 1.1))
    for i, m in enumerate(notes):
        b = bell(note_freq(m), 0.6, ratio=2.0, index=1.4, decay=5)
        off = int(SR * 0.075 * i)
        x[off:off + len(b)] += b * (0.7 + 0.08 * i)
    sparkle = highpass(rng.standard_normal(len(x)), 6000) * np.exp(-4 * t_axis(1.1)) * 0.15
    save('unlock.wav', x + sparkle, 0.8)


def gen_alarm():
    t = t_axis(1.3)
    vib = 1 + 0.012 * np.sin(2 * np.pi * 5.5 * t)
    f = 196 * vib
    ph = 2 * np.pi * np.cumsum(f) / SR
    saw = sum(np.sin(k * ph) / k for k in range(1, 9))
    horn = lowpass(saw, 1400)
    e = np.clip(t / 0.12, 0, 1) * np.clip((1.3 - t) / 0.35, 0, 1)
    save('alarm.wav', horn * e, 0.75)


def gen_howl():
    t = t_axis(1.4)
    contour = 380 + 330 * np.sin(np.pi * np.clip(t / 1.1, 0, 1)) ** 0.7
    contour *= 1 + 0.02 * np.sin(2 * np.pi * 6 * t)
    ph = 2 * np.pi * np.cumsum(contour) / SR
    x = np.sin(ph) + 0.35 * np.sin(2 * ph) + 0.12 * np.sin(3 * ph)
    breath = lowpass(rng.standard_normal(len(t)), 1800) * 0.08
    e = np.clip(t / 0.25, 0, 1) * np.clip((1.4 - t) / 0.4, 0, 1)
    save('howl.wav', (x + breath) * e, 0.6)


def gen_poof():
    t = t_axis(0.35)
    n = lowpass(rng.standard_normal(len(t)), 2200)
    x = n * np.exp(-11 * t) + bell(880, 0.35, 1.5, 0.6, 12) * 0.25
    save('poof.wav', x, 0.6)


def gen_snowball():
    t = t_axis(0.12)
    x = lowpass(rng.standard_normal(len(t)), 1500) * np.exp(-30 * t)
    x += np.sin(2 * np.pi * 140 * t) * np.exp(-40 * t)
    save('snowball.wav', x, 0.6)


def gen_victory():
    seq = [(67, 0.0), (72, 0.14), (76, 0.28), (79, 0.42), (84, 0.62)]
    x = np.zeros(int(SR * 1.8))
    for m, start in seq:
        dur = 1.1 if m == 84 else 0.4
        b = bell(note_freq(m), dur, 2.0, 1.6, 3.2 if m == 84 else 6)
        b2 = bell(note_freq(m - 12), dur, 1.0, 0.4, 4)
        off = int(SR * start)
        x[off:off + len(b)] += b + 0.35 * b2
    save('victory.wav', x, 0.8)


# ------------------------------------------------------------------ music
def gen_music():
    bpm = 92
    beat = 60 / bpm
    bars = 8
    total = int(SR * beat * 4 * bars)
    buf = np.zeros(total)

    def add(sig, start_s):
        i0 = int(start_s * SR) % total
        n = len(sig)
        end = i0 + n
        if end <= total:
            buf[i0:end] += sig
        else:
            k = total - i0
            buf[i0:] += sig[:k]
            rest = sig[k:]
            while len(rest) > 0:
                m = min(len(rest), total)
                buf[:m] += rest[:m]
                rest = rest[m:]

    # D major: I - vi - IV - V twice
    chords = [[50, 54, 57], [47, 50, 54], [43, 47, 50], [45, 49, 52]] * 2
    for bar, ch in enumerate(chords):
        start = bar * 4 * beat
        dur = 4 * beat + 0.6
        t = t_axis(dur)
        pad = np.zeros(len(t))
        for m in ch:
            f = note_freq(m + 12)
            pad += np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * 2 * f * t + 0.4)
        pe = np.clip(t / 0.5, 0, 1) * np.clip((dur - t) / 0.7, 0, 1)
        add(pad * pe * 0.06, start)
        # bass on beats 1 and 3
        for b in (0, 2):
            bt = t_axis(beat * 1.8)
            bass = np.sin(2 * np.pi * note_freq(ch[0] - 12) * bt) * np.exp(-2.2 * bt)
            add(bass * 0.32, start + b * beat)

    # bell melody (pentatonic), eighth-note grid; None = rest
    D, E, Fs, A, B = 74, 76, 78, 81, 83
    melody = [
        D, None, Fs, A, B, None, A, Fs,
        B - 12, None, D, Fs, E, None, D, None,
        B - 12, None, D, E, Fs, None, E, D,
        A - 12, None, B - 12, D, E, None, None, None,
        A, None, B, A, Fs, None, E, Fs,
        D, None, E, Fs, A, None, Fs, E,
        D, None, B - 12, D, E, None, Fs, E,
        D, None, None, A - 12, D, None, None, None,
    ]
    for i, m in enumerate(melody):
        if m is None:
            continue
        b = bell(note_freq(m), 1.2, ratio=3.5, index=1.6, decay=3.8)
        add(b * 0.2, i * beat / 2)
        # soft echo
        add(b * 0.06, i * beat / 2 + beat * 0.75)

    # sleigh-bell shaker on offbeats
    for i in range(bars * 8):
        if i % 2 == 1:
            n = highpass(rng.standard_normal(int(SR * 0.09)), 6500)
            add(n * env(len(n), 0.002, curve=9) * 0.05, i * beat / 2)

    wav = save('music_src.wav', buf, 0.7)
    ogg = os.path.join(OUT, 'music.ogg')
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', wav, '-c:a', 'libvorbis', '-q:a', '3', ogg], check=True)
    os.remove(wav)


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for g in (gen_throw, gen_hit, gen_pop, gen_coin, gen_unlock, gen_alarm, gen_howl, gen_poof,
              gen_snowball, gen_victory, gen_music):
        g()
    print('audio generated in', os.path.abspath(OUT))
