"""Peças "inteiras": construções, torres, ícones de feitiço e projéteis.
Mesmo esquema de cores-modelo das peças de personagem."""
from kit import *


def fin(cv):
    cv.outline()
    return cv


def _telhado(cv, x0, x1, ytop, ybase, slot="A"):
    h = ybase - ytop
    for i in range(h + 1):
        y = ytop + i
        half = (x1 - x0) / 2 * (0.25 + 0.75 * i / h)
        cx = (x0 + x1) / 2
        for x in range(int(cx - half), int(cx + half) + 1):
            t = 0 if x < cx - half * 0.3 else (1 if x < cx + half * 0.4 else 2)
            if i % 3 == 2:
                t = min(2, t + 1)
            cv.put(x, y, C(slot, t))


def _tabuas(cv, x, y, w, h, slot="W"):
    cv.blob_rect(x, y, w, h, slot, 1)
    for xx in range(x + 3, x + w - 1, 4):
        for yy in range(y + 1, y + h - 1):
            cv.put(xx, yy, C(slot, 2))


# ------------------------------------------------------------ construções
def obj_galinheiro():
    cv = Canvas()
    _tabuas(cv, 9, 22, 30, 20)
    _telhado(cv, 5, 43, 8, 22)
    cv.rect(20, 30, 8, 12, PUPIL)                 # portinha
    cv.ellipse(24, 30, 4, 3, "W", shade=False)
    cv.rect(20, 30, 8, 12, PUPIL)
    cv.rect(12, 26, 5, 5, C("K", 0))              # janela com palha
    cv.rect(31, 26, 5, 5, C("K", 0))
    cv.rect(13, 27, 3, 3, PUPIL)
    cv.rect(32, 27, 3, 3, PUPIL)
    for x in range(18, 31, 2):                    # rampinha
        cv.put(x, 43, C("W", 0))
    return fin(cv)


def obj_silo():
    cv = Canvas()
    cv.blob_rect(14, 14, 20, 30, "M", 2)
    for y in (20, 27, 34, 41):
        cv.rect(14, y, 20, 1, C("M", 2))
    cv.ellipse(24, 12, 10.5, 7, "A")
    cv.rect(23, 3, 2, 3, C("M", 0))
    cv.rect(21, 32, 6, 12, PUPIL)
    cv.rect(22, 33, 4, 11, C("W", 2))
    cv.rect(35, 16, 2, 28, C("W", 1))             # escada
    for y in range(18, 44, 4):
        cv.rect(34, y, 4, 1, C("W", 0))
    return fin(cv)


def obj_colmeia():
    cv = Canvas()
    for i, (y, half) in enumerate(((12, 6), (17, 10), (22, 13), (27, 14), (32, 14), (37, 12))):
        cv.blob_rect(24 - half, y, half * 2, 6, "P", 2)
        cv.rect(24 - half + 1, y + 5, half * 2 - 2, 1, C("P", 2))
    cv.ellipse(24, 33, 3.5, 3.5, "M", shade=False)
    for y in range(29, 38):
        for x in range(20, 29):
            if cv.get(x, y)[:3] == C("M", 1)[:3]:
                cv.put(x, y, PUPIL)
    cv.rect(22, 8, 4, 5, C("W", 1))                # galho
    cv.put(12, 20, C("P", 0)); cv.put(37, 18, C("P", 0))
    return fin(cv)


def obj_poco():
    cv = Canvas()
    cv.blob_rect(11, 28, 26, 16, "M", 2)
    for y in range(30, 43, 4):
        for x in range(12 + (y % 8) // 2, 36, 6):
            cv.put(x, y, C("M", 2)); cv.put(x, y + 1, C("M", 2))
    cv.ellipse(24, 29, 11, 3, "S", shade=False)    # água
    cv.rect(12, 10, 2, 19, C("W", 1))
    cv.rect(34, 10, 2, 19, C("W", 1))
    _telhado(cv, 8, 40, 3, 11)
    cv.rect(23, 11, 2, 12, C("K", 2))              # corda
    cv.blob_rect(21, 22, 6, 6, "W", 1)              # balde
    return fin(cv)


def obj_barril():
    cv = Canvas()
    cv.ellipse(24, 30, 12, 14, "W")
    for x in (18, 24, 30):
        for y in range(17, 44):
            if cv.get(x, y)[3]:
                cv.put(x, y, C("W", 2))
    for y in (22, 37):
        for x in range(11, 38):
            if cv.get(x, y)[3]:
                cv.put(x, y, C("M", 1)); cv.put(x, y + 1, C("M", 2))
    cv.rect(21, 28, 6, 5, C("A", 1))                # rótulo
    cv.put(23, 30, EYE_W); cv.put(24, 30, EYE_W)
    return fin(cv)


def obj_espantalho_torre():
    """torre de defesa: canhão de milho num toco"""
    cv = Canvas()
    _tabuas(cv, 14, 30, 20, 14)
    cv.rect(12, 28, 24, 3, C("W", 0))
    cv.blob_rect(18, 12, 12, 18, "M", 3)             # cano
    cv.rect(17, 11, 14, 3, C("M", 2))
    cv.ellipse(24, 12, 4.5, 2, "M", shade=False)
    cv.rect(21, 11, 6, 2, PUPIL)
    cv.rect(19, 20, 10, 2, C("A", 1))
    for x, y in ((22, 7), (25, 5), (27, 8)):          # pipoca saindo
        cv.rect(x, y, 2, 2, C("K", 0))
    return fin(cv)


def obj_fornalha():
    cv = Canvas()
    cv.blob_rect(10, 18, 28, 26, "A", 3)
    for y in range(20, 43, 4):
        cv.rect(10, y, 28, 1, C("A", 2))
        for x in range(12 + (y // 4 % 2) * 3, 37, 6):
            cv.put(x, y + 1, C("A", 2)); cv.put(x, y + 2, C("A", 2))
    cv.ellipse(24, 34, 8, 7, "M", shade=False)
    for y in range(27, 42):
        for x in range(16, 33):
            if cv.get(x, y)[:3] == C("M", 1)[:3]:
                cv.put(x, y, PUPIL)
    for x, h in ((20, 4), (23, 7), (26, 5), (29, 3)):   # fogo
        cv.rect(x, 41 - h, 2, h, (255, 150, 50, 255))
        cv.put(x, 41 - h, (255, 230, 120, 255))
    cv.blob_rect(28, 6, 7, 13, "A", 1)                  # chaminé
    cv.rect(27, 5, 9, 2, C("A", 2))
    cv.ellipse(34, 2, 2.5, 2, "M", shade=False)
    return fin(cv)


def obj_tenda():
    cv = Canvas()
    for i in range(30):
        y = 12 + i
        half = 3 + i * 0.6
        for x in range(int(24 - half), int(24 + half) + 1):
            stripe = ((x - 24) // 4) % 2
            cv.put(x, y, C("A" if stripe else "S", 1 if x < 28 else 2))
    for i in range(14):
        y = 28 + i
        half = i * 0.35
        for x in range(int(24 - half), int(24 + half) + 1):
            cv.put(x, y, PUPIL)
    cv.rect(23, 5, 2, 8, C("W", 1))
    cv.rect(25, 5, 5, 3, C("A", 0))
    return fin(cv)


def obj_ninho():
    cv = Canvas()
    cv.ellipse(24, 36, 15, 7, "W")
    for x in range(10, 39, 3):
        cv.put(x, 33 + (x % 2), C("W", 0)); cv.put(x + 1, 38, C("W", 2))
    for cx in (18, 24, 30):
        cv.ellipse(cx, 30, 3.5, 4.5, "K")
    cv.ellipse(24, 31, 12, 2, "W", shade=False)
    return fin(cv)


def obj_ovni():
    cv = Canvas()
    cv.ellipse(24, 16, 8, 7, "S")
    cv.put(21, 13, SHINE); cv.put(22, 12, SHINE)
    cv.ellipse(24, 23, 19, 6, "M")
    for x in (10, 17, 24, 31, 38):
        cv.rect(x - 1, 24, 2, 2, C("A", 0))
    for i in range(14):                              # raio abdutor
        y = 30 + i
        half = 4 + i * 0.5
        for x in range(int(24 - half), int(24 + half) + 1):
            if (x + y) % 2 == 0:
                cv.put(x, y, (190, 255, 200, 255))
    return fin(cv)


def obj_trator():
    cv = Canvas()
    cv.blob_rect(8, 22, 24, 12, "A", 2)
    cv.blob_rect(20, 10, 14, 14, "A", 2)
    cv.rect(23, 13, 8, 7, (170, 220, 240, 255))
    cv.rect(23, 13, 3, 2, SHINE)
    cv.rect(9, 12, 3, 10, C("M", 2))                  # escapamento
    cv.ellipse(11, 9, 3, 2.5, "M", shade=False)
    cv.ellipse(30, 35, 9, 9, "M")
    cv.ellipse(30, 35, 4, 4, "K", shade=False)
    cv.ellipse(12, 38, 6, 6, "M")
    cv.ellipse(12, 38, 2.5, 2.5, "K", shade=False)
    cv.rect(6, 26, 3, 3, (255, 240, 150, 255))         # farol
    return fin(cv)


def obj_monte_feno():
    cv = Canvas()
    cv.ellipse(24, 32, 16, 12, "K")
    for x, y in ((14, 30), (20, 26), (28, 28), (33, 33), (18, 36), (26, 38), (22, 32), (30, 24)):
        cv.put(x, y, C("K", 2)); cv.put(x + 1, y + 1, C("K", 2)); cv.put(x + 2, y, C("K", 0))
    cv.rect(9, 31, 31, 1, C("A", 1))
    cv.rect(9, 36, 31, 1, C("A", 2))
    return fin(cv)


# ------------------------------------------------------------ torres (base do jogador)
def torre_celeiro():
    cv = Canvas()
    _tabuas(cv, 8, 20, 32, 25, "A")
    _telhado(cv, 4, 44, 3, 20, "W")
    cv.rect(18, 28, 12, 17, C("W", 2))                 # portão
    cv.line(18, 28, 29, 44, EYE_W); cv.line(29, 28, 18, 44, EYE_W)
    cv.rect(18, 28, 12, 1, EYE_W); cv.rect(18, 28, 1, 17, EYE_W); cv.rect(29, 28, 1, 17, EYE_W)
    cv.rect(21, 12, 6, 6, PUPIL)                       # janelinha do feno
    cv.rect(22, 13, 4, 4, C("K", 0))
    cv.rect(23, 0, 2, 4, C("M", 0))                    # cata-vento
    cv.rect(20, 1, 8, 1, C("M", 1))
    return fin(cv)


def torre_moinho():
    cv = Canvas()
    for i in range(30):
        y = 15 + i
        half = 7 + i * 0.2
        for x in range(int(24 - half), int(24 + half) + 1):
            cv.put(x, y, C("K", 0 if x < 21 else (1 if x < 28 else 2)))
    _telhado(cv, 14, 34, 6, 15, "A")
    cv.rect(21, 34, 6, 11, C("W", 2))
    cv.rect(22, 22, 4, 5, PUPIL)
    for dx, dy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):   # pás
        for i in range(2, 13):
            cv.put(24 + dx * i, 14 + dy * i, C("W", 1))
            cv.put(24 + dx * i + 1, 14 + dy * i, C("W", 0))
        cv.rect(24 + dx * 9 - 2, 14 + dy * 9 - 2, 5, 5, C("S", 1))
    cv.rect(23, 13, 3, 3, C("M", 0))
    return fin(cv)


def torre_caixa_dagua():
    cv = Canvas()
    for x in (13, 33):
        cv.rect(x, 24, 2, 21, C("W", 1))
    cv.line(14, 44, 33, 26, C("W", 2)); cv.line(33, 44, 14, 26, C("W", 2))
    cv.blob_rect(9, 8, 30, 18, "S", 3)
    for y in (12, 20):
        cv.rect(9, y, 30, 1, C("M", 1))
    _telhado(cv, 8, 40, 1, 8, "A")
    cv.rect(20, 14, 8, 5, EYE_W)
    return fin(cv)


def torre_castelo_feno():
    cv = Canvas()
    cv.blob_rect(8, 14, 32, 31, "K", 2)
    for y in range(18, 44, 6):
        cv.rect(8, y, 32, 1, C("K", 2))
        for x in range(10 + (y // 6 % 2) * 5, 39, 10):
            cv.rect(x, y - 5, 1, 5, C("K", 2))
    for x in (8, 17, 26, 35):                           # ameias
        cv.blob_rect(x, 8, 6, 7, "K", 1)
    cv.rect(20, 32, 8, 13, PUPIL)
    cv.rect(23, 0, 1, 9, C("W", 1))
    cv.rect(24, 1, 7, 5, C("A", 1))                     # bandeira
    cv.rect(24, 1, 7, 1, C("A", 0))
    return fin(cv)


# ------------------------------------------------------------ ícones de feitiço
def ico_raio():
    cv = Canvas()
    pts = [(28, 4), (16, 24), (24, 24), (18, 44), (34, 20), (26, 20), (32, 4)]
    for y in range(4, 45):
        xs = []
        for i in range(len(pts)):
            (x0, y0), (x1, y1) = pts[i], pts[(i + 1) % len(pts)]
            if (y0 <= y < y1) or (y1 <= y < y0):
                xs.append(x0 + (y - y0) * (x1 - x0) / (y1 - y0))
        xs.sort()
        for a, b in zip(xs[::2], xs[1::2]):
            for x in range(int(a), int(b) + 1):
                cv.put(x, y, C("K", 0 if x < (a + b) / 2 else 1))
    return fin(cv)


def ico_tornado():
    cv = Canvas()
    for i, (y, half) in enumerate(((8, 16), (13, 14), (18, 11), (23, 9), (28, 7), (33, 5), (38, 3), (42, 2))):
        off = (-2, 2, -1, 3, -2, 1, -1, 0)[i]
        cv.blob_rect(24 - half + off, y, half * 2, 5, "M", 2)
        cv.rect(24 - half + off + 2, y + 1, half, 1, C("M", 0))
    for x, y in ((6, 30), (40, 22), (9, 16), (38, 36)):
        cv.rect(x, y, 2, 2, C("W", 1))
    return fin(cv)


def ico_coracao():
    cv = Canvas()
    cv.ellipse(17, 18, 8.5, 8.5, "A")
    cv.ellipse(31, 18, 8.5, 8.5, "A")
    for i in range(18):
        y = 22 + i
        half = 15 - i * 0.85
        for x in range(int(24 - half), int(24 + half) + 1):
            cv.put(x, y, C("A", 1 if x < 28 else 2))
    cv.rect(13, 13, 3, 2, SHINE); cv.put(12, 15, SHINE)
    cv.rect(22, 16, 4, 12, EYE_W); cv.rect(18, 20, 12, 4, EYE_W)   # cruz de cura
    return fin(cv)


def ico_pimenta():
    """fúria"""
    cv = Canvas()
    pts = [(12, 41, 2), (14, 37, 3), (17, 32, 4.5), (21, 27, 5.5), (26, 22, 6), (30, 17, 5.5), (33, 14, 4.5)]
    for (x, y, r) in pts:
        cv.ellipse(x, y, r, r, "A")
    cv.rect(33, 6, 3, 7, C("S", 1)); cv.rect(35, 4, 5, 3, C("S", 0))
    cv.rect(21, 22, 2, 4, SHINE)
    for x, y, h in ((8, 14, 5), (40, 30, 6), (12, 24, 4)):
        cv.rect(x, y, 2, h, (255, 170, 60, 255))
        cv.put(x, y - 1, (255, 230, 120, 255))
    return fin(cv)


def ico_floco():
    cv = Canvas()
    col = C("S", 0)
    for dx, dy in ((1, 0), (0, 1), (1, 1), (1, -1)):
        for i in range(-17, 18):
            cv.put(24 + dx * i, 24 + dy * i, col)
            cv.put(24 + dx * i + (1 if dy else 0), 24 + dy * i + (0 if dy else 1), C("S", 1))
    for i in (9, 14):
        for sx in (-1, 1):
            cv.rect(24 + sx * i - 1, 24 - 3, 2, 7, col)
            cv.rect(24 - 3, 24 + sx * i - 1, 7, 2, col)
    cv.rect(22, 22, 5, 5, EYE_W)
    return fin(cv)


def ico_cogumelo():
    """veneno"""
    cv = Canvas()
    cv.blob_rect(19, 24, 10, 18, "K", 3)
    cv.ellipse(24, 18, 16, 11, "A")
    cv.rect(8, 22, 32, 4, C("A", 2))
    for cx, cy, r in ((16, 14, 3), (27, 11, 3.5), (34, 19, 2.5), (22, 20, 2)):
        cv.ellipse(cx, cy, r, r, "K", shade=False)
    cv.rect(21, 30, 2, 2, PUPIL); cv.rect(26, 30, 2, 2, PUPIL)
    cv.rect(22, 35, 5, 1, PUPIL)
    return fin(cv)


def ico_escudo():
    cv = Canvas()
    for i in range(36):
        y = 6 + i
        half = 15 if i < 16 else 15 - (i - 16) * 0.78
        for x in range(int(24 - half), int(24 + half) + 1):
            cv.put(x, y, C("M", 0 if x < 20 else (1 if x < 29 else 2)))
    cv.rect(22, 10, 4, 24, C("A", 1)); cv.rect(13, 16, 22, 4, C("A", 1))
    return fin(cv)


def ico_melancia():
    """bomba de melancia"""
    cv = Canvas()
    cv.ellipse(24, 28, 15, 14, "S")
    for x in (14, 20, 27, 33):
        for y in range(14, 43):
            if cv.get(x, y)[3]:
                cv.put(x, y, C("S", 2)); cv.put(x + 1, y, C("S", 2))
    cv.rect(23, 9, 2, 6, C("W", 1))                    # pavio
    cv.rect(25, 6, 2, 4, C("W", 1))
    cv.rect(26, 2, 3, 4, (255, 200, 80, 255)); cv.put(27, 1, (255, 250, 200, 255))
    return fin(cv)


def ico_ovo():
    cv = Canvas()
    cv.ellipse(24, 26, 12, 16, "K")
    cv.rect(17, 16, 3, 5, SHINE)
    pts = [(13, 28), (17, 24), (21, 29), (25, 23), (29, 28), (33, 24), (35, 27)]
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        cv.line(x0, y0, x1, y1, OUT)
    return fin(cv)


def ico_vaca_caindo():
    """meteoro de vaca"""
    cv = Canvas()
    for i in range(16):                                  # rastro de fogo
        w = 3 + i // 2
        cv.rect(38 - i - w // 2, 4 + i, w, 2, (255, 200 - i * 6, 60, 255))
    cv.ellipse(20, 30, 13, 11, "P")
    for x, y, w, h in ((12, 24, 6, 5), (22, 32, 7, 5), (26, 22, 4, 4)):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                if cv.get(xx, yy)[3]:
                    cv.put(xx, yy, C("S", 1))
    cv.ellipse(12, 37, 6, 4.5, "K")
    cv.rect(9, 37, 2, 2, C("K", 2)); cv.rect(13, 37, 2, 2, C("K", 2))
    eye(cv, 10, 30, 3); eye(cv, 17, 31, 3)
    cv.rect(30, 38, 3, 5, C("P", 2)); cv.rect(24, 40, 3, 4, C("P", 2))
    return fin(cv)


def ico_nota():
    cv = Canvas()
    cv.rect(20, 8, 3, 26, C("A", 1)); cv.rect(34, 5, 3, 26, C("A", 1))
    cv.rect(20, 5, 17, 5, C("A", 0)); cv.rect(20, 9, 17, 2, C("A", 2))
    cv.ellipse(17, 35, 6, 5, "A"); cv.ellipse(31, 32, 6, 5, "A")
    return fin(cv)


def ico_lama():
    """lentidão / poça"""
    cv = Canvas()
    cv.ellipse(24, 32, 19, 9, "W")
    cv.ellipse(15, 26, 7, 5, "W"); cv.ellipse(33, 27, 8, 5, "W")
    for cx, cy in ((16, 30), (30, 33), (24, 27)):
        cv.ellipse(cx, cy, 3, 2, "W", shade=False)
        cv.put(cx - 1, cy - 1, C("W", 0))
    cv.ellipse(24, 14, 3, 4, "W"); cv.ellipse(34, 10, 2, 3, "W")
    return fin(cv)


def ico_rede():
    """enraizar / laço"""
    cv = Canvas()
    for a in range(0, 360, 6):
        import math
        x = 24 + math.cos(math.radians(a)) * 13
        y = 20 + math.sin(math.radians(a)) * 10
        cv.rect(int(x), int(y), 2, 2, C("K", 1 if a < 180 else 2))
    cv.line(30, 29, 38, 44, C("K", 1)); cv.line(31, 29, 39, 44, C("K", 2))
    cv.rect(28, 27, 4, 4, C("K", 0))
    return fin(cv)


def ico_espelho():
    """clone"""
    cv = Canvas()
    cv.ellipse(24, 20, 12, 15, "W")
    cv.ellipse(24, 20, 9, 12, "S")
    cv.line(18, 22, 24, 12, SHINE); cv.line(22, 26, 28, 16, SHINE)
    cv.rect(22, 35, 4, 10, C("W", 1))
    return fin(cv)


def ico_moeda():
    cv = Canvas()
    cv.ellipse(24, 24, 15, 15, "K")
    cv.ellipse(24, 24, 11, 11, "K", shade=False)
    cv.rect(22, 15, 4, 18, C("K", 2)); cv.rect(19, 18, 10, 3, C("K", 2)); cv.rect(19, 27, 10, 3, C("K", 2))
    cv.rect(14, 15, 2, 5, SHINE)
    return fin(cv)


# ------------------------------------------------------------ projéteis (16x16, apontando pra DIREITA)
def _p():
    return Canvas(16, 16)


def proj_ovo():
    cv = _p(); cv.ellipse(8, 8, 5, 4, "K"); cv.put(6, 6, SHINE); return fin(cv)


def proj_milho():
    cv = _p(); cv.blob_rect(3, 5, 10, 6, "K", 2)
    for x in (5, 8, 11):
        cv.put(x, 7, C("K", 2)); cv.put(x, 9, C("K", 2))
    cv.rect(1, 6, 2, 4, C("S", 1)); return fin(cv)


def proj_pedra():
    cv = _p(); cv.ellipse(8, 8, 4.5, 4, "M"); cv.put(9, 9, C("M", 2)); return fin(cv)


def proj_flecha():
    cv = _p(); cv.rect(2, 7, 10, 2, C("W", 1)); cv.rect(11, 5, 2, 6, C("M", 0)); cv.rect(13, 6, 1, 4, C("M", 0)); cv.put(14, 7, C("M", 0)); cv.put(14, 8, C("M", 0))
    cv.rect(1, 5, 2, 2, C("A", 1)); cv.rect(1, 9, 2, 2, C("A", 1)); return fin(cv)


def proj_fogo():
    cv = _p(); cv.ellipse(9, 8, 4.5, 4, "A")
    cv.rect(2, 7, 5, 2, (255, 200, 80, 255)); cv.rect(8, 7, 3, 2, (255, 240, 170, 255)); cv.put(1, 8, (255, 230, 120, 255)); return fin(cv)


def proj_gota():
    cv = _p(); cv.ellipse(9, 8, 4, 3.5, "S"); cv.rect(3, 7, 4, 2, C("S", 1)); cv.put(2, 8, C("S", 0)); cv.put(10, 7, SHINE); return fin(cv)


def proj_nota():
    cv = _p(); cv.rect(8, 3, 2, 8, C("A", 1)); cv.rect(10, 3, 3, 2, C("A", 0)); cv.ellipse(7, 11, 3, 2.5, "A"); return fin(cv)


def proj_raio():
    cv = _p()
    for (x0, y0), (x1, y1) in (((1, 8), (5, 5)), ((5, 5), (8, 10)), ((8, 10), (11, 6)), ((11, 6), (14, 8))):
        cv.line(x0, y0, x1, y1, C("K", 0)); cv.line(x0, y0 + 1, x1, y1 + 1, C("K", 1))
    return fin(cv)


def proj_espinho():
    cv = _p(); cv.rect(3, 7, 8, 2, C("S", 1)); cv.rect(11, 7, 3, 1, C("S", 0)); cv.put(2, 6, C("S", 2)); cv.put(2, 9, C("S", 2)); return fin(cv)


def proj_bosta():
    """estrume voador -- humor de roça"""
    cv = _p(); cv.ellipse(8, 10, 5, 3, "W"); cv.ellipse(8, 7, 3.5, 2.5, "W"); cv.ellipse(8, 4, 2, 2, "W"); return fin(cv)


OBJETOS = {
    "objeto": {"galinheiro": obj_galinheiro, "silo": obj_silo, "colmeia": obj_colmeia, "poco": obj_poco,
               "barril": obj_barril, "canhao_milho": obj_espantalho_torre, "fornalha": obj_fornalha,
               "tenda": obj_tenda, "ninho": obj_ninho, "ovni": obj_ovni, "trator": obj_trator, "feno": obj_monte_feno},
    "torre": {"celeiro": torre_celeiro, "moinho": torre_moinho, "caixa_dagua": torre_caixa_dagua, "castelo_feno": torre_castelo_feno},
    "icone": {"raio": ico_raio, "tornado": ico_tornado, "coracao": ico_coracao, "pimenta": ico_pimenta,
              "floco": ico_floco, "cogumelo": ico_cogumelo, "escudo": ico_escudo, "melancia": ico_melancia,
              "ovo": ico_ovo, "vaca_caindo": ico_vaca_caindo, "nota": ico_nota, "lama": ico_lama,
              "laco": ico_rede, "espelho": ico_espelho, "moeda": ico_moeda},
    "proj": {"ovo": proj_ovo, "milho": proj_milho, "pedra": proj_pedra, "flecha": proj_flecha, "fogo": proj_fogo,
             "gota": proj_gota, "nota": proj_nota, "raio": proj_raio, "espinho": proj_espinho, "estrume": proj_bosta},
}
