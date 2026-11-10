"""Efeitos sonoros do Farm Arena, sintetizados (estilo 8 bits). Saída: Sounds/sfx/*.wav
    python3 ci/tools/gerar_sons.py
"""
import numpy as np, wave, os
SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "Sounds", "sfx")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


def t(d):
    return np.arange(int(d * SR)) / SR


def sweep(f0, f1, d, kind="sq", curve=1.0):
    x = t(d)
    f = f0 + (f1 - f0) * (x / d) ** curve
    ph = 2 * np.pi * np.cumsum(f) / SR
    if kind == "sq":
        return np.sign(np.sin(ph))
    if kind == "tri":
        return 2 / np.pi * np.arcsin(np.sin(ph))
    return np.sin(ph)


def noise(d, lp=1.0):
    n = rng.uniform(-1, 1, int(d * SR))
    if lp < 1.0:
        out = np.zeros_like(n)
        acc = 0.0
        for i, v in enumerate(n):
            acc += lp * (v - acc)
            out[i] = acc
        n = out / max(1e-6, np.abs(out).max())
    return n


def decay(x, k=6.0, attack=0.004):
    n = len(x)
    e = np.exp(-k * np.arange(n) / n)
    a = max(1, int(attack * SR))
    e[:a] *= np.linspace(0, 1, a)
    return x * e


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def seq(*parts):
    return np.concatenate(parts)


def notes(freqs, d, kind="sq", k=4.0):
    return seq(*[decay(sweep(f, f, d, kind), k) for f in freqs])


def save(name, x, vol=0.7):
    x = x / max(1e-6, np.abs(x).max()) * vol
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


save("golpe", decay(mix(noise(0.09, 0.5) * 0.9, sweep(220, 90, 0.09, "tri")), 7), 0.6)
save("golpe2", decay(mix(noise(0.08, 0.7) * 0.8, sweep(300, 120, 0.08, "sq") * 0.4), 8), 0.55)
save("tiro", decay(sweep(900, 300, 0.09, "sq", 0.6), 5), 0.4)
save("explosao", decay(mix(noise(0.45, 0.18), sweep(120, 35, 0.45, "tri") * 0.9), 5), 0.9)
save("raio", decay(mix(noise(0.3, 0.9) * 0.6, sweep(1800, 200, 0.3, "sq", 0.4) * 0.6), 5), 0.75)
save("cura", notes([523, 659, 784, 1047], 0.08, "tri", 3), 0.55)
save("gelo", decay(mix(sweep(2200, 1400, 0.35, "sin"), sweep(3300, 2000, 0.35, "sin") * 0.5, noise(0.35) * 0.15), 4), 0.5)
save("furia", decay(sweep(180, 520, 0.3, "sq", 1.5), 2.5), 0.5)
save("lama", decay(mix(noise(0.3, 0.08), sweep(160, 70, 0.3, "sin")), 4), 0.7)
save("morte", decay(sweep(420, 110, 0.16, "tri", 0.7), 4), 0.45)
save("nasce", decay(sweep(260, 620, 0.1, "tri"), 4), 0.4)
save("torre_dano", decay(mix(noise(0.14, 0.25), sweep(150, 70, 0.14, "sq") * 0.5), 6), 0.7)
save("torre_cai", seq(decay(mix(noise(0.5, 0.15), sweep(160, 30, 0.5, "tri")), 3), decay(mix(noise(0.6, 0.08), sweep(90, 25, 0.6, "tri")), 4)), 0.95)
save("clique", decay(sweep(700, 500, 0.04, "sq"), 6), 0.3)
save("moeda", notes([1319, 1760], 0.07, "sq", 3), 0.4)
save("bau", seq(decay(noise(0.12, 0.3), 5), notes([392, 523, 659, 784, 1047], 0.07, "sq", 2.5)), 0.6)
save("carta", notes([659, 880, 1175], 0.06, "tri", 3), 0.5)
save("nivel", notes([523, 523, 659, 784, 1047, 1319], 0.09, "sq", 2.5), 0.6)
save("vitoria", seq(notes([523, 659, 784], 0.12, "sq", 2.5), decay(mix(sweep(1047, 1047, 0.5, "sq"), sweep(784, 784, 0.5, "tri"), sweep(1319, 1319, 0.5, "tri") * 0.6), 2.5)), 0.65)
save("derrota", notes([392, 349, 311, 233], 0.2, "tri", 2.0), 0.6)
save("erro", notes([180, 140], 0.09, "sq", 3), 0.4)
save("vaca", decay(mix(sweep(170, 130, 0.5, "sq", 0.5) * 0.7, sweep(340, 250, 0.5, "tri", 0.5)), 1.8, 0.08), 0.6)
print(sorted(os.listdir(OUT)))
