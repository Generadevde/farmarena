"""MEGA PACK 2: cabeças, chapéus, armas, costas, torres, objetos e ícones novos
(o que faltava pras mecânicas do Clash: bobina elétrica, morteiro, coletor, túmulo...)."""
import math
from kit import Canvas, C, SHINE
from pecas import new, fin, _cabeca_base, _olhos, PUPIL, EYE_W, OUT, BLUSH

FIRE = (255, 200, 80, 255)
FIRE2 = (255, 120, 60, 255)
ICE = (190, 235, 255, 255)
ICE2 = (120, 190, 240, 255)
ELEC = (150, 210, 255, 255)
TOX = (150, 220, 70, 255)
TOX2 = (90, 160, 40, 255)
PURP = (190, 120, 240, 255)
PURP2 = (120, 70, 190, 255)
GOLD = (250, 210, 80, 255)
GOLD2 = (200, 150, 40, 255)
BONE = (240, 235, 215, 255)
BONE2 = (200, 190, 165, 255)
DARK = (50, 50, 60, 255)
STONE = (150, 150, 158, 255)
STONE2 = (110, 110, 120, 255)
RED = (220, 60, 50, 255)
PINK = (240, 130, 150, 255)
NONE = (0, 0, 0, 0)


def _disc(cv, cx, cy, r, col):
    for y in range(int(cy - r), int(cy + r) + 1):
        for x in range(int(cx - r), int(cx + r) + 1):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                cv.put(x, y, col)


def _tri(cv, cx, top, h, half, col, col2=None):
    for i in range(h):
        w = int(half * (i + 1) / h)
        for x in range(cx - w, cx + w + 1):
            cv.put(x, top + i, col2 if (col2 and x > cx) else col)


def _zig(cv, x0, y0, x1, y1, col, amp=3):
    n = max(abs(y1 - y0), abs(x1 - x0))
    for i in range(n + 1):
        t = i / max(n, 1)
        x = int(x0 + (x1 - x0) * t + (amp if (i // 3) % 2 else -amp))
        y = int(y0 + (y1 - y0) * t)
        cv.rect(x, y, 2, 2, col)


# ================================================================ CABEÇAS
def cab_mago():
    cv = _cabeca_base("K", 10.5, 10, 17)
    cv.blob_rect(16, 20, 16, 10, "P", 4)           # barba
    for x in range(17, 31, 3):
        cv.rect(x, 27, 2, 3, C("P", 1))
    _olhos(cv, 13, 5, 3)
    cv.rect(17, 11, 5, 1, C("P", 1)); cv.rect(26, 11, 5, 1, C("P", 1))
    return fin(cv)


def cab_eletrico():
    """cabelo de raio espetado (Mago Elétrico)"""
    cv = _cabeca_base("K", 10, 11, 17)
    for i, x in enumerate(range(13, 36, 4)):
        _tri(cv, x, 0 + (i % 2) * 2, 10, 2, ELEC)
    cv.rect(14, 8, 21, 3, ELEC)
    _olhos(cv, 15, 5, 3, bravo=True)
    for side in (-1, 1):
        cv.put(24 + side * 5, 16, ELEC)
    return fin(cv)


def cab_bruxa_mae():
    cv = _cabeca_base("S", 10, 11, 17)
    for y in range(12, 28):
        for x in range(13, 36):
            if cv.get(x, y)[3]:
                cv.put(x, y, (150, 190, 120, 255) if x < 29 else (120, 160, 95, 255))   # pele verde
    cv.blob_rect(11, 6, 26, 8, "M", 3)
    cv.rect(11, 13, 3, 16, C("M", 1)); cv.rect(34, 13, 3, 16, C("M", 2))
    _olhos(cv, 15, 5, 3, bravo=True)
    cv.rect(23, 18, 2, 5, (110, 150, 90, 255)); cv.put(24, 23, (110, 150, 90, 255))   # nariz grande
    cv.rect(21, 25, 6, 1, PURP2)
    return fin(cv)


def cab_executor():
    cv = _cabeca_base("M", 11, 10, 17)
    for y in range(6, 28):
        for x in range(12, 37):
            if cv.get(x, y)[3]:
                cv.put(x, y, DARK if x < 30 else (35, 35, 45, 255))   # capuz
    cv.rect(17, 13, 5, 3, FIRE2); cv.rect(26, 13, 5, 3, FIRE2)          # olhos acesos
    cv.put(18, 14, FIRE); cv.put(27, 14, FIRE)
    cv.rect(18, 22, 13, 5, C("K", 1)); cv.rect(20, 24, 9, 1, C("K", 2))
    return fin(cv)


def cab_gigante():
    cv = _cabeca_base("K", 12, 11, 17)
    cv.rect(12, 7, 25, 4, C("W", 1))                 # cabelo curto
    for side in (-1, 1):
        cv.rect(24 + side * 6 - 2, 11, 5, 2, C("W", 2))
    _olhos(cv, 14, 6, 3)
    cv.rect(19, 23, 11, 2, C("K", 2)); cv.put(19, 22, C("K", 2)); cv.put(29, 22, C("K", 2))
    return fin(cv)


def cab_fantasma():
    cv = new()
    cv.ellipse(24, 15, 11, 11, "P", shade=False)
    for y in range(4, 30):
        for x in range(12, 37):
            if cv.get(x, y)[3]:
                cv.put(x, y, (230, 238, 250, 255) if x < 29 else (200, 210, 230, 255))
    for x in range(13, 36, 5):
        cv.rect(x, 25, 4, 3, (230, 238, 250, 255))
    cv.rect(18, 12, 4, 5, DARK); cv.rect(27, 12, 4, 5, DARK); cv.rect(22, 20, 5, 3, DARK)
    return fin(cv)


def cab_gnomo():
    cv = _cabeca_base("K", 10, 12, 17)
    _tri(cv, 24, 0, 13, 9, C("A", 1), C("A", 2))
    cv.blob_rect(15, 21, 18, 9, "P", 4)
    _disc(cv, 24, 19, 2.5, PINK)
    _olhos(cv, 15, 5, 3)
    return fin(cv)


def cab_corvo():
    cv = _cabeca_base("M", 10, 10, 17)
    for y in range(7, 28):
        for x in range(13, 36):
            if cv.get(x, y)[3]:
                cv.put(x, y, DARK if x < 29 else (35, 35, 48, 255))
    cv.rect(29, 16, 9, 3, GOLD2); cv.rect(29, 19, 6, 2, GOLD); cv.put(38, 17, GOLD2)
    cv.rect(20, 13, 3, 3, RED); cv.put(21, 14, SHINE)
    for x in (19, 23, 27):
        cv.rect(x, 4, 2, 4, DARK)
    return fin(cv)


# ================================================================ CHAPÉUS
def chap_mineiro():
    cv = new()
    cv.blob_rect(14, 3, 21, 8, "A", 4); cv.rect(12, 9, 25, 2, C("A", 2))
    _disc(cv, 24, 5, 3, SHINE); _disc(cv, 24, 5, 1.6, GOLD)
    for i in range(6):
        cv.rect(24 - i, -1 - 0, 1, 1, NONE)
    return fin(cv)


def chap_capuz():
    cv = new()
    cv.blob_rect(11, 2, 26, 12, "S", 6)
    cv.rect(11, 10, 3, 18, C("S", 1)); cv.rect(34, 10, 3, 18, C("S", 2))
    cv.rect(16, 6, 17, 2, C("S", 0))
    return fin(cv)


def chap_tiara_raio():
    cv = new()
    cv.rect(14, 8, 21, 2, GOLD)
    _zig(cv, 24, 0, 24, 8, ELEC, 2)
    cv.put(16, 7, ELEC); cv.put(32, 7, ELEC)
    return fin(cv)


def chap_turbante():
    cv = new()
    cv.blob_rect(12, 2, 25, 10, "P", 5)
    for y in (4, 7, 10):
        cv.rect(13, y, 23, 1, C("P", 2))
    _disc(cv, 24, 6, 2.5, RED); cv.put(23, 5, SHINE)
    cv.rect(23, 0, 2, 3, C("A", 1))
    return fin(cv)


def chap_cogumelo():
    cv = new()
    cv.ellipse(24, 6, 15, 7, "A")
    cv.rect(8, 7, 33, 6, NONE)
    cv.ellipse(24, 6, 15, 5, "A")
    for x, y, r in ((17, 4, 2), (27, 3, 2.4), (33, 6, 1.6), (22, 7, 1.4)):
        _disc(cv, x, y, r, SHINE)
    return fin(cv)


# ================================================================ ARMAS
def arma_machado_duplo():
    cv = Canvas()
    cv.rect(38, 4, 3, 38, C("W", 1)); cv.rect(38, 4, 1, 38, C("W", 0))
    for side in (-1, 1):
        for i in range(10):
            w = 9 - abs(i - 5)
            x0 = 39 + (2 if side > 0 else -w - 1)
            cv.rect(x0, 4 + i, w, 1, C("M", 0 if side < 0 else 1))
    cv.put(30, 8, SHINE)
    return fin(cv)


def arma_bumerangue():
    cv = Canvas()
    cv.line(32, 22, 40, 10, C("W", 0)); cv.line(33, 23, 41, 11, C("W", 1))
    cv.line(40, 10, 46, 18, C("W", 0)); cv.line(41, 11, 46, 19, C("W", 1))
    cv.rect(31, 21, 3, 3, C("A", 1)); cv.rect(44, 17, 3, 3, C("A", 1))
    return fin(cv)


def arma_bombinha_mao():
    cv = Canvas()
    _disc(cv, 39, 30, 6, DARK); _disc(cv, 37, 28, 1.6, SHINE)
    cv.rect(39, 20, 2, 5, C("W", 1)); cv.put(40, 19, FIRE); cv.put(41, 18, FIRE2)
    return fin(cv)


def arma_cajado_raio():
    cv = Canvas()
    cv.rect(38, 12, 3, 30, C("W", 1)); cv.rect(38, 12, 1, 30, C("W", 0))
    _disc(cv, 39, 8, 5, ELEC); _disc(cv, 38, 7, 2, SHINE)
    _zig(cv, 33, 2, 33, 12, ELEC, 1); _zig(cv, 45, 2, 45, 12, ELEC, 1)
    return fin(cv)


def arma_rede():
    cv = Canvas()
    cv.rect(38, 22, 2, 20, C("W", 1))
    for i in range(5):
        cv.rect(31 + i * 3, 4, 1, 18, BONE2)
        cv.rect(31, 4 + i * 4, 15, 1, BONE2)
    cv.rect(30, 3, 17, 1, C("W", 2))
    return fin(cv)


def arma_mortarete():
    """canhãozinho de ombro (morteiro portátil)"""
    cv = Canvas()
    cv.blob_rect(33, 14, 13, 8, "M", 3)
    cv.rect(44, 12, 4, 12, C("M", 2)); cv.rect(45, 14, 2, 8, DARK)
    cv.rect(36, 22, 3, 10, C("W", 1))
    return fin(cv)


# ================================================================ COSTAS
def costas_mochila():
    cv = new()
    cv.blob_rect(31, 22, 9, 14, "W", 3); cv.rect(32, 27, 7, 3, C("W", 2)); cv.rect(34, 26, 3, 1, GOLD)
    cv.line(20, 24, 32, 24, C("W", 2))
    return fin(cv)


def costas_jetpack():
    cv = new()
    for x in (30, 36):
        cv.blob_rect(x, 20, 6, 15, "M", 3); cv.rect(x + 1, 35, 4, 2, DARK)
        _tri(cv, x + 3, 37, 6, 2, FIRE)
    cv.rect(30, 24, 12, 2, C("A", 1))
    return fin(cv)


def costas_asas_morcego():
    cv = new()
    for side in (-1, 1):
        for i in range(14):
            h = 12 - abs(i - 6)
            x = 24 + side * (8 + i)
            cv.rect(x, 22 - h // 2, 1, h, DARK if i % 4 else (80, 60, 90, 255))
    return fin(cv)


def costas_raios():
    """aura elétrica nas costas"""
    cv = new()
    for side in (-1, 1):
        _zig(cv, 24 + side * 12, 10, 24 + side * 14, 38, ELEC, 2)
    return fin(cv)


# ================================================================ TORRES
def torre_bobina():
    cv = Canvas()
    cv.blob_rect(16, 34, 16, 11, "M", 3)
    for y in range(12, 34, 3):
        cv.rect(19, y, 10, 2, GOLD2 if y % 2 else GOLD)
    cv.rect(23, 6, 2, 8, STONE2)
    _disc(cv, 24, 6, 5, ELEC); _disc(cv, 23, 5, 2, SHINE)
    _zig(cv, 14, 2, 14, 14, ELEC, 1); _zig(cv, 34, 2, 34, 14, ELEC, 1)
    return fin(cv)


def torre_morteiro():
    cv = Canvas()
    cv.blob_rect(8, 32, 32, 13, "W", 4)
    for x in range(10, 40, 6):
        cv.rect(x, 33, 3, 11, C("W", 2))
    cv.blob_rect(14, 16, 20, 17, "M", 6)
    cv.rect(18, 8, 12, 10, C("M", 2)); cv.rect(19, 9, 10, 4, DARK)
    cv.rect(16, 16, 16, 2, C("M", 0))
    return fin(cv)


def torre_tumulo():
    cv = Canvas()
    cv.blob_rect(12, 10, 24, 34, "M", 10)
    for y in range(10, 44):
        for x in range(12, 36):
            if cv.get(x, y)[3]:
                cv.put(x, y, STONE if x < 30 else STONE2)
    cv.rect(22, 16, 4, 14, STONE2); cv.rect(17, 20, 14, 4, STONE2)
    cv.rect(8, 42, 32, 3, (90, 70, 50, 255))
    for x, y in ((10, 41), (37, 40)):
        cv.rect(x, y, 2, 2, TOX2)
    return fin(cv)


def torre_coletor():
    """coletor de recurso: tanque com bolha roxa"""
    cv = Canvas()
    cv.blob_rect(10, 26, 28, 19, "W", 4)
    for x in (10, 36):
        cv.rect(x, 26, 2, 19, C("W", 2))
    cv.ellipse(24, 18, 11, 11, "S", shade=False)
    for y in range(7, 30):
        for x in range(13, 36):
            if cv.get(x, y)[3]:
                d = (x - 24) ** 2 + (y - 18) ** 2
                cv.put(x, y, SHINE if d < 6 else (PURP if d < 70 else PURP2))
    cv.rect(16, 28, 16, 2, GOLD)
    return fin(cv)


def torre_inferno():
    cv = Canvas()
    for i in range(32):
        w = 6 + int(i * 0.4)
        cv.rect(24 - w, 13 + i, w * 2, 1, DARK if i % 5 else (80, 60, 60, 255))
    cv.rect(20, 7, 8, 7, (80, 60, 60, 255))
    _disc(cv, 24, 6, 4, FIRE2); _disc(cv, 24, 5, 2.2, FIRE); cv.put(23, 4, SHINE)
    for x in (13, 33):
        cv.rect(x, 26, 2, 6, FIRE2)
    return fin(cv)


def torre_cabana_goblin():
    cv = Canvas()
    for i in range(18):
        w = 3 + int(i * 1.1)
        for x in range(24 - w, 24 + w + 1):
            cv.put(x, 4 + i, C("W", 1) if (x + i) % 4 else C("W", 2))
    cv.blob_rect(9, 22, 30, 22, "S", 2)
    cv.rect(20, 32, 8, 12, DARK); cv.rect(20, 31, 8, 1, C("W", 2))
    for x in (12, 33):
        cv.rect(x, 26, 4, 4, DARK); cv.put(x + 1, 27, FIRE)
    return fin(cv)


# ================================================================ OBJETOS
def obj_espantalho():
    cv = Canvas()
    cv.rect(23, 18, 2, 27, C("W", 1)); cv.rect(10, 22, 28, 2, C("W", 1))
    cv.blob_rect(17, 22, 14, 14, "S", 3)
    _disc(cv, 24, 13, 6, (230, 200, 140, 255))
    cv.rect(17, 6, 14, 3, C("W", 2)); cv.rect(15, 8, 18, 2, C("W", 2))
    cv.rect(21, 12, 2, 2, DARK); cv.rect(26, 12, 2, 2, DARK); cv.rect(21, 16, 7, 1, DARK)
    for x in (9, 38):
        cv.rect(x, 21, 2, 4, (230, 200, 140, 255))
    return fin(cv)


def obj_caldeirao():
    cv = Canvas()
    cv.ellipse(24, 32, 15, 11, "M")
    for y in range(21, 44):
        for x in range(9, 40):
            if cv.get(x, y)[3]:
                cv.put(x, y, DARK if x < 30 else (35, 35, 45, 255))
    cv.ellipse(24, 23, 13, 3, "S", shade=False)
    for x in range(11, 38):
        for y in range(20, 27):
            if (x - 24) ** 2 / 169.0 + (y - 23) ** 2 / 9.0 <= 1.0:
                cv.put(x, y, TOX)
    for x, y, r in ((18, 17, 2.5), (27, 13, 3), (32, 18, 2)):
        _disc(cv, x, y, r, TOX)
    cv.rect(13, 42, 4, 3, FIRE2); cv.rect(31, 42, 4, 3, FIRE2); cv.rect(22, 43, 4, 2, FIRE)
    return fin(cv)


def obj_lapide():
    cv = Canvas()
    for i, x in enumerate((10, 26)):
        cv.blob_rect(x, 18 + i * 4, 12, 26 - i * 4, "M", 5)
        for y in range(18, 45):
            for xx in range(x, x + 12):
                if cv.get(xx, y)[3]:
                    cv.put(xx, y, STONE if xx < x + 8 else STONE2)
        cv.rect(x + 5, 24 + i * 4, 2, 8, STONE2); cv.rect(x + 3, 26 + i * 4, 6, 2, STONE2)
    cv.rect(6, 43, 36, 2, (90, 70, 50, 255))
    return fin(cv)


def obj_bomba_rolante():
    cv = Canvas()
    _disc(cv, 24, 28, 14, DARK); _disc(cv, 24, 28, 12, (70, 70, 85, 255)); _disc(cv, 19, 22, 3, SHINE)
    cv.rect(10, 27, 28, 2, RED)
    cv.rect(23, 12, 3, 4, C("W", 1)); cv.put(25, 11, FIRE); cv.put(26, 10, FIRE2)
    return fin(cv)


def obj_bau_tesouro_aberto():
    cv = Canvas()
    cv.blob_rect(8, 26, 32, 18, "W", 2)
    cv.blob_rect(8, 10, 32, 10, "W", 4)
    for x in (8, 38):
        cv.rect(x, 10, 2, 34, GOLD)
    for x, y in ((13, 24), (18, 22), (24, 23), (30, 22), (35, 24), (21, 25), (28, 25)):
        _disc(cv, x, y, 2.6, GOLD); cv.put(x - 1, y - 1, SHINE)
    _disc(cv, 24, 20, 2.5, RED)
    return fin(cv)


# ================================================================ ÍCONES
def ico_relampago():
    cv = Canvas()
    for i, (x0, y0, x1, y1) in enumerate(((28, 2, 16, 24), (16, 24, 30, 24), (30, 24, 18, 46))):
        for k in range(26):
            t = k / 25.0
            cv.rect(int(x0 + (x1 - x0) * t) - 2, int(y0 + (y1 - y0) * t), 5, 2, GOLD if i != 1 else FIRE)
    return fin(cv)


def ico_espiral():
    cv = Canvas()
    for k in range(180):
        a = k * 0.16
        r = 2 + k * 0.11
        cv.rect(int(24 + math.cos(a) * r), int(24 + math.sin(a) * r), 2, 2, PURP if k % 20 < 14 else PURP2)
    return fin(cv)


def ico_clone():
    cv = Canvas()
    for dx, col in ((-6, ICE2), (5, ICE)):
        _disc(cv, 22 + dx, 16, 6, col)
        cv.blob_rect(14 + dx, 23, 16, 18, "S", 5)
        for y in range(23, 42):
            for x in range(14 + dx, 31 + dx):
                if cv.get(x, y)[3]:
                    cv.put(x, y, col)
    return fin(cv)


def ico_vazio():
    cv = Canvas()
    _disc(cv, 24, 24, 18, PURP2); _disc(cv, 24, 24, 13, (40, 20, 60, 255)); _disc(cv, 24, 24, 6, DARK)
    for a in range(8):
        cv.put(int(24 + math.cos(a * 0.8) * 20), int(24 + math.sin(a * 0.8) * 20), PURP)
    return fin(cv)


def ico_terremoto():
    cv = Canvas()
    cv.rect(4, 28, 40, 14, (120, 90, 60, 255)); cv.rect(4, 28, 40, 2, (150, 115, 80, 255))
    _zig(cv, 24, 28, 24, 44, DARK, 3)
    for x, y in ((10, 20), (36, 18), (20, 14), (30, 22)):
        cv.rect(x, y, 4, 4, STONE)
    return fin(cv)


def ico_maldicao():
    cv = Canvas()
    _disc(cv, 24, 22, 15, PURP2)
    _disc(cv, 24, 21, 11, (60, 30, 80, 255))
    cv.rect(17, 17, 5, 5, TOX); cv.rect(27, 17, 5, 5, TOX)
    cv.rect(19, 28, 11, 2, TOX)
    for x in range(10, 40, 6):
        _tri(cv, x, 36, 8, 2, PURP)
    return fin(cv)


def ico_barril():
    cv = Canvas()
    cv.blob_rect(10, 12, 28, 26, "W", 8)
    for x in (16, 32):
        cv.rect(x, 12, 2, 26, C("M", 1))
    for y in (18, 25, 32):
        cv.rect(11, y, 26, 1, C("W", 2))
    for i in range(3):
        cv.rect(4 + i * 4, 40 + (i % 2), 3, 2, (150, 115, 80, 255))
    return fin(cv)


MEGA2 = {
    "cabeca": {"mago": cab_mago, "eletrico": cab_eletrico, "bruxa_mae": cab_bruxa_mae, "executor": cab_executor, "gigante": cab_gigante,
               "assombracao": cab_fantasma, "gnomo": cab_gnomo, "corvo": cab_corvo},
    "chapeu": {"mineiro": chap_mineiro, "capuz": chap_capuz, "tiara_raio": chap_tiara_raio, "turbante": chap_turbante, "chapeu_cogumelo": chap_cogumelo},
    "arma": {"machado_duplo": arma_machado_duplo, "bumerangue_mao": arma_bumerangue, "bombinha_mao": arma_bombinha_mao, "cajado_raio": arma_cajado_raio,
             "rede": arma_rede, "morteiro_ombro": arma_mortarete},
    "costas": {"mochila": costas_mochila, "jetpack": costas_jetpack, "asas_morcego": costas_asas_morcego, "aura_raios": costas_raios},
    "torre": {"bobina_tesla": torre_bobina, "morteiro": torre_morteiro, "tumulo": torre_tumulo, "coletor": torre_coletor, "torre_inferno": torre_inferno,
              "cabana_goblin": torre_cabana_goblin},
    "objeto": {"espantalho_campo": obj_espantalho, "caldeirao": obj_caldeirao, "lapides": obj_lapide, "bomba_rolante": obj_bomba_rolante, "bau_aberto": obj_bau_tesouro_aberto},
    "icone": {"relampago": ico_relampago, "espiral": ico_espiral, "clone": ico_clone, "vazio": ico_vazio, "terremoto": ico_terremoto,
              "maldicao": ico_maldicao, "barril_rolando": ico_barril},
}

TEMAS_MEGA2 = {
    "Guerra": ["executor", "gigante", "machado_duplo", "bombinha_mao", "morteiro_ombro", "mochila", "morteiro", "bomba_rolante", "barril_rolando", "terremoto"],
    "ET e máquina": ["eletrico", "tiara_raio", "cajado_raio", "jetpack", "aura_raios", "bobina_tesla", "coletor", "relampago", "clone"],
    "Mitologia": ["mago", "bruxa_mae", "assombracao", "gnomo", "corvo", "capuz", "asas_morcego", "tumulo", "torre_inferno", "caldeirao", "lapides", "espiral", "vazio", "maldicao"],
    "Comida": ["chapeu_cogumelo", "turbante"],
    "Oceano": ["rede", "bumerangue_mao"],
}
