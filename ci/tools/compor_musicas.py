"""Compositor procedural de músicas "da roça" em estilo chiptune pro Farm Arena.
Gera faixas originais em loop (sanfona de onda quadrada com vibrato, baixo
triangular, zabumba, triângulo e chocalho). Saída: WAV -> OGG (ffmpeg)."""
import numpy as np, subprocess, sys, os

SR = 44100
NOTE = {n: i for i, n in enumerate(["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"])}


def freq(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def env(n, a=0.01, d=0.08, s=0.6, r=0.06):
    t = np.arange(n) / SR
    e = np.ones(n) * s
    an, dn, rn = int(a * SR), int(d * SR), int(r * SR)
    an = max(an, 1)
    e[:an] = np.linspace(0, 1, an)
    if an + dn < n:
        e[an:an + dn] = np.linspace(1, s, dn)
    if rn < n:
        e[-rn:] *= np.linspace(1, 0, rn)
    return e


def osc(kind, f, n, vib=0.0, duty=0.5, phase_noise=0.0):
    t = np.arange(n) / SR
    fm = f * (1 + vib * np.sin(2 * np.pi * 5.5 * t) * np.clip(t * 3, 0, 1))
    ph = np.cumsum(fm) / SR
    if kind == "square":
        return np.where((ph % 1) < duty, 1.0, -1.0)
    if kind == "saw":
        return 2 * (ph % 1) - 1
    if kind == "tri":
        return 2 * np.abs(2 * (ph % 1) - 1) - 1
    return np.sin(2 * np.pi * ph)


def accordion(f, n):
    # "sanfona": duas quadradas levemente desafinadas + serra baixinha
    a = osc("square", f, n, vib=0.006, duty=0.35) + osc("square", f * 1.004, n, vib=0.006, duty=0.5)
    a = a * 0.5 + 0.25 * osc("saw", f * 2, n, vib=0.006)
    return a * env(n, 0.02, 0.1, 0.75, 0.05)


def lead_pluck(f, n):  # viola caipira / "cavaquinho"
    a = osc("square", f, n, duty=0.25) * 0.6 + osc("tri", f * 2, n) * 0.4
    return a * env(n, 0.003, 0.15, 0.25, 0.05)


def bass(f, n):
    return osc("tri", f, n) * env(n, 0.005, 0.1, 0.7, 0.04)


rng = np.random.default_rng(0)


def kick(n):  # zabumba
    t = np.arange(n) / SR
    f = 110 * np.exp(-t * 18) + 45
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9)


def snare(n):
    t = np.arange(n) / SR
    return (rng.uniform(-1, 1, n) * 0.7 + np.sin(2 * np.pi * 190 * t) * 0.3) * np.exp(-t * 22)


def triangle_bell(n):  # triângulo do forró
    t = np.arange(n) / SR
    return (np.sin(2 * np.pi * 2600 * t) + 0.5 * np.sin(2 * np.pi * 4100 * t)) * np.exp(-t * 14) * 0.35


def shaker(n):
    t = np.arange(n) / SR
    return rng.uniform(-1, 1, n) * np.exp(-t * 60) * 0.25


def add(buf, start, sig, gain):
    end = min(len(buf), start + len(sig))
    if start < len(buf):
        buf[start:end] += sig[:end - start] * gain


def scale_notes(root, minor):
    steps = [0, 2, 3, 5, 7, 8, 10] if minor else [0, 2, 4, 5, 7, 9, 11]
    return [root + s for s in steps]


def compose(name, root="G", minor=False, bpm=110, bars=32, seed=1, style="forro", intensity=1.0):
    r = np.random.default_rng(seed)
    beat = 60.0 / bpm
    step = beat / 4  # semicolcheia
    total_steps = bars * 16
    n_total = int(total_steps * step * SR)
    mel = np.zeros(n_total)
    harm = np.zeros(n_total)
    bas = np.zeros(n_total)
    drm = np.zeros(n_total)

    base_midi = 48 + NOTE[root]
    sc = scale_notes(base_midi, minor)
    # progressões por grau (0=I)
    progs_major = [[0, 3, 4, 0], [0, 5, 3, 4], [0, 4, 5, 3], [0, 3, 0, 4]]
    progs_minor = [[0, 5, 6, 4], [0, 3, 4, 0], [0, 6, 5, 4], [0, 5, 3, 4]]
    progs = progs_minor if minor else progs_major
    prog_a = progs[r.integers(len(progs))]
    prog_b = progs[r.integers(len(progs))]

    def chord(degree):
        idx = [degree, degree + 2, degree + 4]
        out = []
        for i in idx:
            o, d = divmod(i, 7)
            out.append(sc[d] + 12 * o)
        return out

    # motivo melódico (repetido com variação) -- dá cara de música, não de ruído
    def make_motif(length=16):
        m = []
        pos = r.integers(0, 5)
        for s in range(length):
            if r.random() < (0.55 if style == "calmo" else 0.7):
                pos = int(np.clip(pos + r.choice([-2, -1, -1, 0, 1, 1, 2, 3]), 0, 9))
                dur = r.choice([2, 2, 4, 1] if style != "calmo" else [2, 4, 4, 6])
                m.append((s, pos, dur))
        return m

    motif_a = make_motif()
    motif_b = make_motif()

    for bar in range(bars):
        section_b = (bar // 8) % 2 == 1
        prog = prog_b if section_b else prog_a
        deg = prog[bar % 4]
        ch = chord(deg)
        bar_start = bar * 16
        # harmonia: sanfona em acordes no contratempo (cara de forró/xote)
        for s in range(16):
            n_start = int((bar_start + s) * step * SR)
            if style == "calmo":
                if s in (0, 8):
                    for note in ch:
                        add(harm, n_start, accordion(freq(note + 12), int(step * 7 * SR)), 0.10)
            else:
                if s % 4 == 2 or (intensity > 1.2 and s % 2 == 1):
                    for note in ch:
                        add(harm, n_start, accordion(freq(note + 12), int(step * 1.6 * SR)), 0.09)
        # baixo: tônica e quinta (baião)
        bass_pattern = [0, 6, 8, 12] if style != "calmo" else [0, 8]
        for i, s in enumerate(bass_pattern):
            note = ch[0] - 12 if i % 2 == 0 else ch[2] - 12
            add(bas, int((bar_start + s) * step * SR), bass(freq(note), int(step * 3.5 * SR)), 0.42)
        # melodia (pula a introdução: 2 primeiros compassos)
        if bar >= 2:
            motif = motif_b if section_b else motif_a
            for (s, pos, dur) in motif:
                o, d = divmod(pos, 7)
                note = sc[d] + 12 * (o + 1)
                # puxa pra nota do acorde no tempo forte
                if s % 8 == 0:
                    note = min(ch, key=lambda c: abs((c + 12) - note)) + 12
                n = int(step * dur * SR)
                inst = lead_pluck if (bar % 8) >= 4 and style != "calmo" else accordion
                add(mel, int((bar_start + s) * step * SR), inst(freq(note), n), 0.16)
        # percussão
        for s in range(16):
            t0 = int((bar_start + s) * step * SR)
            if style == "calmo":
                if s in (0, 10):
                    add(drm, t0, kick(int(0.3 * SR)), 0.35)
                if s % 4 == 2:
                    add(drm, t0, shaker(int(0.08 * SR)), 0.6)
            else:
                if s in (0, 6, 8) or (intensity > 1.2 and s in (14,)):
                    add(drm, t0, kick(int(0.3 * SR)), 0.6)
                if s in (4, 12):
                    add(drm, t0, snare(int(0.15 * SR)), 0.28 * intensity)
                if s % 2 == 0:
                    add(drm, t0, triangle_bell(int(0.12 * SR)), 0.5 if s % 4 == 2 else 0.25)
                add(drm, t0, shaker(int(0.05 * SR)), 0.35)

    mix = mel + harm + bas + drm
    # fade curtinho nas pontas pra emendar o loop sem estalo
    f = int(0.01 * SR)
    mix[:f] *= np.linspace(0, 1, f)
    mix[-f:] *= np.linspace(1, 0, f)
    mix = np.tanh(mix * 1.1) * 0.85
    stereo = np.stack([mix, np.roll(mix, int(0.012 * SR)) * 0.96], axis=1)
    pcm = (stereo * 32767).astype(np.int16)
    wav = f"/home/claude/music/{name}.wav"
    import wave
    with wave.open(wav, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    out = sys.argv[1] + f"/{name}.ogg"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "4", out], check=True)
    os.remove(wav)
    print(name, f"{n_total / SR:.0f}s")


TRACKS = [
    # menu -- calmas, tom maior
    ("menu_cafe_na_varanda", "G", False, 84, 32, 11, "calmo", 1.0),
    ("menu_por_do_sol_no_pasto", "F", False, 78, 32, 23, "calmo", 1.0),
    ("menu_xote_da_porteira", "D", False, 100, 32, 37, "forro", 0.8),
    # batalha -- rápidas, tensas
    ("batalha_baiao_da_briga", "A", True, 132, 40, 5, "forro", 1.1),
    ("batalha_estouro_da_boiada", "E", True, 140, 40, 17, "forro", 1.2),
    ("batalha_rodeio_bravo", "D", True, 126, 40, 29, "forro", 1.1),
    # final x2 -- a mais acelerada
    ("final_x2_vaca_louca", "B", True, 156, 40, 41, "forro", 1.5),
]

if __name__ == "__main__":
    for args in TRACKS:
        compose(*args)
