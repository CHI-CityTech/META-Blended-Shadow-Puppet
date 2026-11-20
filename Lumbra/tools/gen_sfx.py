"""Synthesizes Lumbra's placeholder sounds (mono, 16-bit, 22050 Hz). Usage: python3 gen_sfx.py <out_dir>"""
import math, random, struct, sys, wave

RATE = 22050
OUT = sys.argv[1]
random.seed(7)

def write(name, samples, peak=0.8):
    m = max(1e-9, max(abs(x) for x in samples))
    k = peak / m
    with wave.open(f"{OUT}/{name}.wav", "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, x * k)) * 32767)) for x in samples))

def env(t, attack, decay):
    a = min(1.0, t / attack) if attack > 0 else 1.0
    return a * math.exp(-t / decay)

def bell(freqs, dur, decay, attack=0.004, amps=None):
    n = int(dur * RATE); amps = amps or [1.0] * len(freqs)
    return [sum(a * math.sin(2 * math.pi * f * i / RATE) for f, a in zip(freqs, amps)) * env(i / RATE, attack, decay) for i in range(n)]

def lowpass(xs, k):
    y, out = 0.0, []
    for x in xs:
        y += k * (x - y); out.append(y)
    return out

# place: soft glassy chime
write("place", bell([880, 1320, 2640], 0.5, 0.16, amps=[1.0, 0.5, 0.15]), 0.6)
# rotate: quick rising tick
n = int(0.11 * RATE); ph = 0.0; rot = []
for i in range(n):
    t = i / RATE; f = 520 + 900 * t / 0.11; ph += 2 * math.pi * f / RATE
    rot.append(math.sin(ph) * env(t, 0.002, 0.035))
write("rotate", rot, 0.5)
# capture: noisy shatter + falling tone
n = int(0.55 * RATE); ph = 0.0; noise = lowpass([random.uniform(-1, 1) for _ in range(n)], 0.35); cap = []
for i in range(n):
    t = i / RATE; f = 520 * math.exp(-t * 4.0) + 90; ph += 2 * math.pi * f / RATE
    cap.append(0.7 * noise[i] * env(t, 0.001, 0.09) + 0.6 * math.sin(ph) * env(t, 0.003, 0.18))
write("capture", cap, 0.7)
# click: tiny UI tick
write("click", bell([1500, 3100], 0.05, 0.012, attack=0.001, amps=[1.0, 0.3]), 0.35)
# reject: low double buzz
n = int(0.22 * RATE); rej = []
for i in range(n):
    t = i / RATE; gate = 1.0 if (t % 0.11) < 0.075 else 0.0
    sq = 1.0 if math.sin(2 * math.pi * 150 * t) > 0 else -1.0
    rej.append(sq * gate * env(t % 0.11, 0.003, 0.05))
write("reject", lowpass(rej, 0.25), 0.45)
# win: rising arpeggio of chimes
win = [0.0] * int(1.6 * RATE)
for j, f in enumerate([523.25, 659.25, 783.99, 1046.5]):
    start = int(j * 0.14 * RATE); b = bell([f, f * 2, f * 3], 1.6 - j * 0.14, 0.45, amps=[1.0, 0.35, 0.1])
    for i, x in enumerate(b):
        if start + i < len(win): win[start + i] += x
write("win", win, 0.7)
# ambient: 8 s seamless drone (every frequency completes whole cycles in 8 s)
dur = 8.0; n = int(dur * RATE); amb = []
partials = [(55.0, 1.0), (82.5, 0.55), (110.0, 0.4), (165.0, 0.18), (220.125, 0.08)]
for i in range(n):
    t = i / RATE
    swell = 0.75 + 0.25 * math.sin(2 * math.pi * t / dur)
    shimmer = 0.5 + 0.5 * math.sin(2 * math.pi * 2 * t / dur + 1.3)
    x = sum(a * math.sin(2 * math.pi * f * t) for f, a in partials)
    x += 0.05 * shimmer * math.sin(2 * math.pi * 660.0 * t) * math.sin(2 * math.pi * 0.25 * t)
    amb.append(x * swell)
write("ambient", amb, 0.35)
print("ok")
