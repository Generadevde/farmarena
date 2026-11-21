"""Silhuetas de MULHER (cabeças com cabelo, corpos de vestido/saia, pernas) e mais
BICHOS (cabeças e corpos de quatro patas). Entram no atlas pelo exportar.py."""
from kit import Canvas, C, SHINE
from pecas import new, fin, _cabeca_base, _olhos, PUPIL, EYE_W, OUT, BLUSH

DARK = (50, 50, 60, 255)
BONE = (240, 235, 215, 255)
GOLD = (250, 210, 80, 255)
RED = (220, 60, 50, 255)
PINK = (240, 130, 150, 255)


def _disc(cv, cx, cy, r, col):
    for y in range(int(cy - r), int(cy + r) + 1):
        for x in range(int(cx - r), int(cx + r) + 1):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                cv.put(x, y, col)


def _rosto(cv, cilios=True, boca=PINK):
    """rosto feminino: olhos com cílio, bochecha e boca pintada"""
    _olhos(cv, 14, 5, 3)
    if cilios:
        for side in (-1, 1):
            cv.put(24 + side * 7, 13, OUT); cv.put(24 + side * 6, 12, OUT)
    cv.put(17, 20, BLUSH); cv.put(30, 20, BLUSH)
    cv.rect(22, 23, 4, 1, boca); cv.put(23, 24, boca); cv.put(24, 24, boca)


def _franja(cv, slot="S"):
    for x in range(14, 35):
        for y in range(6, 12):
            if cv.get(x, y)[3] and y < 10 + (0 if 20 < x < 28 else 2):
                cv.put(x, y, C(slot, 1 if x < 28 else 2))


# ================================================================ MULHERES: cabeças
def cab_mulher():
    """cabelo comprido solto, caindo dos dois lados"""
    cv = new()
    cv.blob_rect(11, 8, 26, 24, "S", 6)                  # cabelo atrás
    cv.ellipse(24, 17, 10, 9.5, "K")
    _franja(cv)
    cv.rect(11, 12, 3, 18, C("S", 1)); cv.rect(34, 12, 3, 18, C("S", 2))
    _rosto(cv)
    return fin(cv)


def cab_mulher_rabo():
    """rabo de cavalo alto, balançando de lado"""
    cv = new()
    cv.blob_rect(33, 5, 6, 8, "S", 3); cv.rect(36, 12, 4, 12, C("S", 1)); cv.rect(37, 24, 3, 4, C("S", 2))
    cv.ellipse(24, 17, 10, 9.5, "K")
    _franja(cv)
    cv.rect(32, 8, 2, 3, C("A", 1))                      # elástico
    _rosto(cv)
    return fin(cv)


def cab_mulher_coque():
    cv = new()
    _disc(cv, 24, 4, 4.5, C("S", 1)); _disc(cv, 23, 3, 2, C("S", 0))
    cv.ellipse(24, 17, 10, 9.5, "K")
    _franja(cv)
    cv.rect(21, 8, 6, 1, C("A", 1))
    _rosto(cv)
    for side in (-1, 1):                                 # brinco
        cv.put(24 + side * 10, 21, GOLD); cv.put(24 + side * 10, 22, GOLD)
    return fin(cv)


def cab_mulher_trancas():
    cv = new()
    cv.ellipse(24, 17, 10, 9.5, "K")
    _franja(cv)
    for side in (-1, 1):
        x = 24 + side * 12
        for i in range(8):
            cv.rect(x - 1 + (i % 2), 13 + i * 2, 3, 2, C("S", 1 if i % 2 else 2))
        cv.rect(x - 1, 29, 3, 2, C("A", 1))
    _rosto(cv)
    return fin(cv)


def cab_mulher_cacheada():
    cv = new()
    for cx, cy, r in ((14, 12, 5), (34, 12, 5), (18, 6, 5), (30, 6, 5), (24, 4, 5), (12, 19, 4), (36, 19, 4), (14, 25, 3.5), (34, 25, 3.5)):
        _disc(cv, cx, cy, r, C("S", 1 if cx < 26 else 2))
    cv.ellipse(24, 18, 9, 8.5, "K")
    for x in range(16, 33):
        for y in range(8, 12):
            if cv.get(x, y)[3]:
                cv.put(x, y, C("S", 1))
    _rosto(cv)
    return fin(cv)


def cab_vovo():
    """vovó: coque branco, óculos redondo"""
    cv = new()
    _disc(cv, 24, 4, 4, (230, 232, 238, 255))
    cv.ellipse(24, 17, 10, 9.5, "K")
    for x in range(14, 35):
        for y in range(6, 11):
            if cv.get(x, y)[3]:
                cv.put(x, y, (230, 232, 238, 255) if x < 28 else (200, 204, 214, 255))
    _olhos(cv, 14, 5, 3)
    for side in (-1, 1):
        cx = 24 + side * 5
        for x, y in ((cx - 2, 13), (cx + 2, 13), (cx - 2, 17), (cx + 2, 17)):
            cv.put(x, y, GOLD)
        cv.rect(cx - 1, 12, 3, 1, GOLD); cv.rect(cx - 1, 18, 3, 1, GOLD); cv.rect(cx - 3, 14, 1, 3, GOLD); cv.rect(cx + 3, 14, 1, 3, GOLD)
    cv.rect(23, 15, 2, 1, GOLD)
    cv.rect(22, 23, 4, 1, PINK); cv.put(17, 21, BLUSH); cv.put(30, 21, BLUSH)
    return fin(cv)


# ================================================================ MULHERES: corpos e pernas
def corpo_vestido():
    """vestido que abre em saia rodada por cima das pernas"""
    cv = new()
    cv.ellipse(24, 30, 7.5, 6, "A")                      # busto/cintura
    for i in range(12):
        w = 7 + int(i * 0.75)
        cv.rect(24 - w, 32 + i, w * 2, 1, C("A", 1 if i % 4 else 2))
    cv.rect(16, 43, 17, 1, SHINE)                        # barra
    cv.rect(18, 32, 13, 1, C("S", 1))                    # faixa na cintura
    cv.rect(22, 25, 5, 2, C("K", 1))                     # decote
    return fin(cv)


def corpo_saia_blusa():
    cv = new()
    cv.ellipse(24, 30, 8, 6, "S")
    cv.rect(22, 25, 5, 2, C("K", 1)); cv.rect(20, 27, 1, 5, C("S", 2)); cv.rect(28, 27, 1, 5, C("S", 2))
    for i in range(9):
        w = 8 + int(i * 0.5)
        cv.rect(24 - w, 34 + i, w * 2, 1, C("A", 1))
        for x in range(24 - w + 2, 24 + w, 4):
            cv.put(x, 34 + i, C("A", 2))
    cv.rect(16, 34, 17, 1, C("M", 0))
    return fin(cv)


def corpo_avental():
    cv = new()
    cv.ellipse(24, 33, 9, 8.5, "S")
    cv.blob_rect(18, 28, 13, 14, "P", 2)                 # avental claro
    cv.rect(18, 28, 13, 1, SHINE); cv.rect(19, 25, 2, 4, C("P", 1)); cv.rect(28, 25, 2, 4, C("P", 1))
    cv.rect(21, 34, 7, 4, C("P", 2)); cv.rect(21, 34, 7, 1, C("P", 0))    # bolso
    for x, y in ((20, 31), (27, 31), (24, 40)):
        cv.put(x, y, C("A", 1))
    return fin(cv)


def pernas_sapatilha():
    cv = new()
    for x in (19, 27):
        cv.rect(x, 38, 3, 5, C("K", 1)); cv.rect(x, 38, 1, 5, C("K", 0))
        cv.rect(x - 1, 43, 5, 2, C("A", 1)); cv.put(x + 1, 43, SHINE)
    return fin(cv)


def pernas_bota_alta():
    cv = new()
    for x in (18, 27):
        cv.rect(x, 37, 4, 2, C("K", 1))
        cv.blob_rect(x - 1, 39, 5, 6, "W", 1); cv.rect(x - 1, 39, 5, 1, C("W", 0)); cv.rect(x + 3, 44, 2, 1, C("W", 2))
    return fin(cv)


# ================================================================ BICHOS: cabeças
def cab_raposa():
    cv = _cabeca_base("A", 10.5, 9, 17)
    for side in (-1, 1):
        for i in range(7):
            cv.rect(24 + side * 9 - 2 + (i // 3) * (1 if side < 0 else 0), 2 + i, 2 + i // 2, 1, C("A", 1))
        cv.rect(24 + side * 9 - 1, 5, 2, 3, DARK)
    cv.ellipse(24, 22, 7, 5, "P", shade=False)
    for y in range(17, 28):
        for x in range(16, 33):
            if (x - 24) ** 2 / 49.0 + (y - 22) ** 2 / 25.0 <= 1.0:
                cv.put(x, y, SHINE)
    cv.rect(23, 21, 3, 2, DARK); cv.rect(24, 23, 1, 2, DARK)
    _olhos(cv, 13, 5, 3)
    return fin(cv)


def cab_lobo():
    cv = _cabeca_base("M", 11, 9.5, 17)
    for side in (-1, 1):
        for i in range(7):
            cv.rect(24 + side * 9 - 1, 2 + i, 2 + i // 2, 1, C("M", 1))
    cv.ellipse(24, 22, 6.5, 5, "M")
    cv.rect(22, 19, 5, 2, DARK)
    cv.rect(19, 24, 11, 2, DARK)
    for x in (20, 23, 26, 28):
        cv.rect(x, 24, 1, 2, BONE)
    _olhos(cv, 12, 5, 3, bravo=True)
    for side in (-1, 1):
        cv.put(24 + side * 5, 13, GOLD)
    return fin(cv)


def cab_leao():
    cv = new()
    for a in range(12):
        import math
        _disc(cv, 24 + math.cos(a * math.pi / 6) * 11, 16 + math.sin(a * math.pi / 6) * 10, 4.5, C("W", 1 if a % 2 else 2))
    cv.ellipse(24, 17, 9, 8.5, "K")
    cv.ellipse(24, 21, 5, 3.5, "P", shade=False)
    for y in range(18, 26):
        for x in range(19, 30):
            if (x - 24) ** 2 / 25.0 + (y - 21) ** 2 / 12.0 <= 1.0:
                cv.put(x, y, BONE)
    cv.rect(23, 19, 3, 2, DARK); cv.rect(24, 21, 1, 2, DARK)
    _olhos(cv, 13, 4, 3)
    return fin(cv)


def cab_elefante():
    cv = new()
    for side in (-1, 1):                                 # orelhonas
        cv.ellipse(24 + side * 13, 15, 7, 10, "M")
        cv.ellipse(24 + side * 13, 15, 4, 7, "K")
    cv.ellipse(24, 15, 10, 10, "M")
    cv.blob_rect(21, 20, 6, 12, "M", 2)                  # tromba
    for y in (23, 26, 29):
        cv.rect(21, y, 6, 1, C("M", 2))
    cv.rect(17, 22, 3, 5, BONE); cv.rect(28, 22, 3, 5, BONE)   # presas
    _olhos(cv, 12, 5, 3)
    return fin(cv)


def cab_panda():
    cv = new()
    for side in (-1, 1):
        _disc(cv, 24 + side * 10, 7, 4, DARK)
    cv.ellipse(24, 17, 11.5, 10, "P", shade=False)
    for y in range(7, 28):
        for x in range(12, 37):
            if cv.get(x, y)[3] and (x - 24) ** 2 / 132.0 + (y - 17) ** 2 / 100.0 <= 1.0:
                cv.put(x, y, SHINE if x < 29 else (220, 224, 232, 255))
    for side in (-1, 1):
        cv.ellipse(24 + side * 5, 15, 3.5, 4, "M", shade=False)
        for y in range(11, 20):
            for x in range(24 + side * 5 - 4, 24 + side * 5 + 5):
                if (x - (24 + side * 5)) ** 2 / 12.0 + (y - 15) ** 2 / 16.0 <= 1.0:
                    cv.put(x, y, DARK)
        cv.rect(24 + side * 5 - 1, 14, 2, 2, EYE_W); cv.put(24 + side * 5, 15, PUPIL)
    cv.rect(23, 20, 3, 2, DARK); cv.rect(22, 23, 5, 1, DARK)
    return fin(cv)


def cab_rato():
    cv = new()
    for side in (-1, 1):
        _disc(cv, 24 + side * 10, 8, 5.5, C("M", 1)); _disc(cv, 24 + side * 10, 8, 3.2, PINK)
    cv.ellipse(24, 18, 9.5, 8.5, "M")
    cv.ellipse(24, 23, 4.5, 3, "M")
    _disc(cv, 24, 22, 1.6, PINK)
    for side in (-1, 1):
        cv.rect(24 + side * 6 - (2 if side < 0 else 0), 23, 3, 1, BONE); cv.rect(24 + side * 6 - (2 if side < 0 else 0), 25, 3, 1, BONE)
    cv.rect(23, 25, 2, 2, BONE)
    _olhos(cv, 15, 4, 3)
    return fin(cv)


def cab_tigre():
    cv = _cabeca_base("A", 11, 9.5, 17)
    for side in (-1, 1):
        _disc(cv, 24 + side * 9, 7, 3.5, C("A", 1)); _disc(cv, 24 + side * 9, 7, 1.6, BONE)
        for y in (12, 16, 20):
            cv.rect(24 + side * 10 - (2 if side > 0 else 0), y, 3, 1, DARK)
    for x in (21, 24, 27):
        cv.rect(x, 7, 1, 3, DARK)
    cv.ellipse(24, 22, 6, 4, "P", shade=False)
    for y in range(18, 27):
        for x in range(18, 31):
            if (x - 24) ** 2 / 36.0 + (y - 22) ** 2 / 16.0 <= 1.0:
                cv.put(x, y, BONE)
    cv.rect(23, 20, 3, 2, PINK); cv.rect(24, 22, 1, 2, DARK)
    _olhos(cv, 13, 5, 3, bravo=True)
    return fin(cv)


def cab_rinoceronte():
    cv = _cabeca_base("M", 11, 9.5, 17)
    for side in (-1, 1):
        cv.rect(24 + side * 9 - 1, 4, 3, 5, C("M", 1))
    cv.ellipse(24, 22, 8, 5, "M")
    for i in range(9):
        cv.rect(24 - (4 - i // 2) // 2, 20 - i, max(1, 4 - i // 2), 1, BONE)
    cv.rect(23, 14, 2, 3, BONE)
    cv.rect(19, 24, 2, 2, DARK); cv.rect(27, 24, 2, 2, DARK)
    _olhos(cv, 12, 6, 3)
    return fin(cv)


# ================================================================ BICHOS: corpos de quatro patas (de lado)
def quatro_elefante():
    cv = new()
    for x in (15, 30):
        cv.rect(x, 36, 5, 8, C("M", 2))
    cv.line(5, 26, 3, 33, C("M", 2)); cv.rect(2, 33, 2, 3, C("M", 1))
    cv.ellipse(20, 29, 15, 10, "M")
    for x in (9, 24):
        cv.blob_rect(x, 35, 7, 9, "M", 1); cv.rect(x, 43, 7, 2, C("K", 0))
        for t in (1, 3, 5):
            cv.put(x + t, 44, BONE)
    return fin(cv)


def quatro_raposa():
    cv = new()
    for x in (17, 29):
        cv.rect(x, 37, 2, 6, C("A", 2)); cv.rect(x, 43, 2, 2, DARK)
    cv.ellipse(6, 28, 6, 4.5, "A"); _disc(cv, 2, 27, 2.5, SHINE)        # cauda peluda de ponta branca
    cv.ellipse(20, 32, 12, 6.5, "A")
    cv.ellipse(20, 35, 7, 2.5, "P", shade=False)
    for x in (11, 25):
        cv.blob_rect(x, 36, 4, 7, "A", 1); cv.rect(x, 42, 4, 3, DARK)
    return fin(cv)


def quatro_leao():
    cv = new()
    for x in (16, 30):
        cv.rect(x, 37, 3, 6, C("K", 2)); cv.rect(x, 43, 3, 2, C("K", 2))
    cv.line(7, 28, 3, 24, C("K", 2)); cv.line(3, 24, 3, 20, C("K", 2)); _disc(cv, 3, 19, 2.2, C("W", 1))
    cv.ellipse(20, 31, 13, 7.5, "K")
    for x in (10, 25):
        cv.blob_rect(x, 36, 5, 7, "K", 1); cv.rect(x, 43, 5, 2, C("K", 2))
    for cx, cy in ((28, 27), (31, 31), (27, 33)):                        # começo da juba no peito
        _disc(cv, cx, cy, 3, C("W", 1))
    return fin(cv)


SILHUETAS = {
    "cabeca": {"mulher": cab_mulher, "mulher_rabo": cab_mulher_rabo, "mulher_coque": cab_mulher_coque, "mulher_trancas": cab_mulher_trancas,
               "mulher_cacheada": cab_mulher_cacheada, "vovo": cab_vovo,
               "raposa": cab_raposa, "lobo": cab_lobo, "leao": cab_leao, "elefante": cab_elefante, "panda": cab_panda, "rato": cab_rato,
               "tigre": cab_tigre, "rinoceronte": cab_rinoceronte},
    "corpo": {"vestido": corpo_vestido, "saia_blusa": corpo_saia_blusa, "avental": corpo_avental},
    "pernas": {"sapatilha": pernas_sapatilha, "bota_alta": pernas_bota_alta},
    "quatro": {"elefante": quatro_elefante, "raposa": quatro_raposa, "leao": quatro_leao},
}

# onde a cabeça encaixa nos corpos de quatro patas novos (dx, dy)
QUATRO_CABECA_EXTRA = {"elefante": (5, 3), "raposa": (10, 8), "leao": (11, 5)}
