"""MEGA PACK: mais cabeças, chapéus, armas (tropas), torres e objetos (construções)
e ícones (feitiços). Entram no atlas pelo exportar.py."""
from kit import Canvas, C, SHINE
from pecas import new, fin, _cabeca_base, _olhos, PUPIL, EYE_W

FIRE = (255, 200, 80, 255)
FIRE2 = (255, 120, 60, 255)
ICE = (190, 235, 255, 255)
ICE2 = (120, 190, 240, 255)
TOX = (150, 220, 70, 255)
TOX2 = (90, 160, 40, 255)
PURP = (190, 120, 240, 255)
GOLD = (250, 210, 80, 255)
GOLD2 = (200, 150, 40, 255)
BONE = (240, 235, 215, 255)
BONE2 = (200, 190, 165, 255)
DARK = (50, 50, 60, 255)
RED = (220, 60, 50, 255)
NONE = (0, 0, 0, 0)


def _disc(cv, cx, cy, r, col):
    for y in range(int(cy - r), int(cy + r) + 1):
        for x in range(int(cx - r), int(cx + r) + 1):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                cv.put(x, y, col)


def _tri(cv, cx, top, h, half, col, col2=None):
    """triângulo de ponta pra cima"""
    for i in range(h):
        w = int(half * (i + 1) / h)
        for x in range(cx - w, cx + w + 1):
            cv.put(x, top + i, col2 if (col2 and x > cx) else col)


# ================================================================ CABEÇAS
def cab_robo():
    cv = new()
    cv.blob_rect(13, 7, 22, 19, "M", 2)
    cv.rect(14, 8, 20, 1, C("M", 0)); cv.rect(16, 12, 16, 6, DARK)
    cv.rect(18, 13, 4, 4, ICE); cv.rect(26, 13, 4, 4, ICE); cv.put(19, 14, SHINE); cv.put(27, 14, SHINE)
    for x in range(18, 31, 3):
        cv.rect(x, 21, 2, 2, C("M", 2))
    cv.rect(23, 2, 2, 5, C("M", 1)); _disc(cv, 24, 2, 1.6, RED)
    cv.rect(11, 13, 2, 6, C("M", 2)); cv.rect(35, 13, 2, 6, C("M", 2))
    return fin(cv)


def cab_caveira():
    cv = new()
    cv.ellipse(24, 14, 11, 9.5, "P", shade=False)
    for y in range(4, 24):
        for x in range(12, 37):
            if cv.get(x, y)[3]:
                cv.put(x, y, BONE if x < 28 else BONE2)
    cv.rect(18, 22, 12, 5, BONE2)
    for x in (19, 22, 25, 28):
        cv.rect(x, 24, 1, 3, DARK)
    cv.rect(17, 12, 5, 5, DARK); cv.rect(26, 12, 5, 5, DARK); cv.put(19, 14, RED); cv.put(28, 14, RED)
    cv.rect(23, 18, 2, 3, DARK)
    return fin(cv)


def cab_abobora():
    cv = _cabeca_base("A", 12, 10, 17)
    for x in (17, 24, 31):
        cv.rect(x, 9, 1, 16, C("A", 2))
    cv.rect(23, 4, 3, 4, TOX2); cv.put(26, 4, TOX2)
    for side in (-1, 1):
        _tri(cv, 24 + side * 5, 12, 4, 3, FIRE)
    cv.rect(18, 21, 13, 2, FIRE); cv.rect(20, 23, 3, 1, FIRE); cv.rect(26, 23, 3, 1, FIRE); cv.put(22, 21, C("A", 2)); cv.put(27, 21, C("A", 2))
    return fin(cv)


def cab_alien():
    cv = new()
    cv.ellipse(24, 13, 12, 9, "S")
    cv.ellipse(24, 21, 6, 6, "S")
    for side in (-1, 1):
        cx = 24 + side * 6
        cv.ellipse(cx, 14, 4, 5, "M", shade=False)
        for y in range(8, 21):
            for x in range(cx - 5, cx + 6):
                if cv.get(x, y)[3] and (x - cx) ** 2 / 16.0 + (y - 14) ** 2 / 25.0 <= 1.0:
                    cv.put(x, y, DARK)
        cv.put(cx - 1, 12, SHINE)
    cv.rect(23, 24, 3, 1, C("S", 2))
    return fin(cv)


def cab_dragao():
    cv = _cabeca_base("P", 11, 9, 16)
    cv.ellipse(24, 22, 8, 5, "P")
    for side in (-1, 1):
        cv.rect(24 + side * 9 - 1, 3, 3, 6, BONE); cv.put(24 + side * 10, 2, BONE)
        cv.rect(24 + side * 3 - 1, 22, 2, 2, DARK)
    for x in (20, 24, 28):
        cv.rect(x, 5, 2, 3, C("A", 1))
    _olhos(cv, 13, 5, 3, bravo=True)
    cv.rect(19, 26, 2, 2, SHINE); cv.rect(28, 26, 2, 2, SHINE)
    return fin(cv)


def cab_urso():
    cv = _cabeca_base("W", 11.5, 10, 17)
    for side in (-1, 1):
        _disc(cv, 24 + side * 10, 8, 3.5, C("W", 1)); _disc(cv, 24 + side * 10, 8, 1.6, C("K", 1))
    cv.ellipse(24, 21, 6, 4.5, "K")
    cv.rect(22, 19, 4, 2, DARK); cv.rect(23, 21, 2, 3, DARK)
    _olhos(cv, 13, 5, 3)
    return fin(cv)


def cab_coelho():
    cv = _cabeca_base("P", 10.5, 9, 19)
    for side in (-1, 1):
        cv.blob_rect(24 + side * 6 - 2, 0, 5, 13, "P", 2); cv.rect(24 + side * 6 - 1, 2, 2, 9, C("K", 0))
    cv.rect(23, 21, 3, 2, C("A", 1)); cv.rect(22, 24, 2, 3, SHINE); cv.rect(25, 24, 2, 3, SHINE)
    _olhos(cv, 16, 5, 3)
    return fin(cv)


def cab_palhaco():
    cv = _cabeca_base("K", 11, 10, 17)
    for side in (-1, 1):
        _disc(cv, 24 + side * 12, 12, 4.5, C("A", 1)); _disc(cv, 24 + side * 13, 9, 3, C("A", 0))
    _disc(cv, 24, 19, 2.6, RED); cv.put(23, 18, SHINE)
    cv.rect(18, 23, 13, 2, RED); cv.rect(20, 24, 9, 1, SHINE)
    _olhos(cv, 13, 5, 3)
    for side in (-1, 1):
        cv.rect(24 + side * 5 - 1, 10, 3, 1, C("S", 1))
    return fin(cv)


def cab_ninja():
    cv = _cabeca_base("M", 11, 10, 17)
    for y in range(7, 28):
        for x in range(12, 37):
            if cv.get(x, y)[3]:
                cv.put(x, y, DARK if x < 29 else (35, 35, 45, 255))
    cv.rect(15, 13, 19, 5, C("K", 1)); cv.rect(15, 13, 19, 1, C("K", 0))
    cv.rect(18, 14, 3, 3, EYE_W); cv.rect(27, 14, 3, 3, EYE_W); cv.put(19, 15, PUPIL); cv.put(28, 15, PUPIL)
    cv.rect(34, 10, 6, 2, C("A", 1)); cv.rect(37, 12, 4, 2, C("A", 2))
    return fin(cv)


def cab_pinguim():
    cv = _cabeca_base("M", 11, 10, 17)
    for y in range(7, 28):
        for x in range(12, 37):
            if cv.get(x, y)[3]:
                cv.put(x, y, DARK)
    cv.ellipse(24, 19, 8, 7, "P", shade=False)
    for y in range(11, 27):
        for x in range(15, 34):
            if (x - 24) ** 2 / 64.0 + (y - 19) ** 2 / 49.0 <= 1.0:
                cv.put(x, y, SHINE)
    cv.rect(22, 19, 5, 3, FIRE); cv.rect(23, 22, 3, 1, FIRE2)
    _olhos(cv, 14, 4, 3)
    return fin(cv)


# ================================================================ CHAPÉUS
def chap_coroa():
    cv = new()
    cv.rect(16, 5, 17, 5, GOLD); cv.rect(16, 9, 17, 1, GOLD2)
    for x in (16, 20, 24, 28, 32):
        cv.rect(x, 1 if x in (16, 24, 32) else 3, 1 if x != 24 else 2, 4, GOLD)
    cv.put(24, 0, RED); cv.rect(19, 7, 2, 2, RED); cv.rect(28, 7, 2, 2, ICE2); cv.rect(23, 6, 3, 3, PURP)
    return fin(cv)


def chap_cartola():
    cv = new()
    cv.ellipse(24, 9, 13, 2, "M", shade=False)
    for y in range(6, 12):
        for x in range(10, 39):
            if cv.get(x, y)[3]:
                cv.put(x, y, DARK)
    cv.rect(17, 0, 15, 9, DARK); cv.rect(17, 0, 2, 9, (80, 80, 95, 255)); cv.rect(17, 6, 15, 2, C("A", 1))
    return fin(cv)


def chap_bruxa():
    cv = new()
    cv.ellipse(24, 9, 14, 2.2, "S")
    _tri(cv, 24, 0, 9, 8, C("S", 1), C("S", 2))
    cv.rect(17, 7, 15, 2, C("A", 1)); cv.rect(23, 7, 3, 2, GOLD)
    cv.put(27, 0, C("S", 1)); cv.put(28, 1, C("S", 1))
    return fin(cv)


def chap_viking():
    cv = new()
    cv.blob_rect(15, 3, 19, 8, "M", 4); cv.rect(15, 8, 19, 2, C("M", 2))
    cv.rect(23, 3, 3, 7, C("M", 0))
    for side in (-1, 1):
        x = 24 + side * 10
        cv.rect(x - 1, 4, 3, 4, BONE); cv.rect(x + side - 1, 1, 3, 4, BONE); cv.put(x + side * 2, 0, BONE2)
    return fin(cv)


def chap_gorro():
    cv = new()
    cv.blob_rect(15, 2, 19, 8, "A", 4)
    cv.rect(14, 8, 21, 3, SHINE); cv.rect(14, 10, 21, 1, (215, 220, 230, 255))
    _disc(cv, 24, 1, 2.2, SHINE)
    for x in range(17, 33, 4):
        cv.rect(x, 4, 2, 2, C("A", 0))
    return fin(cv)


def chap_chef():
    cv = new()
    for cx, cy, r in ((19, 4, 4.5), (24, 3, 5), (29, 4, 4.5)):
        _disc(cv, cx, cy, r, SHINE)
    cv.rect(17, 5, 15, 5, SHINE); cv.rect(17, 9, 15, 1, (205, 210, 220, 255)); cv.rect(21, 5, 1, 4, (215, 220, 230, 255)); cv.rect(27, 5, 1, 4, (215, 220, 230, 255))
    return fin(cv)


# ================================================================ ARMAS (na mão direita, coluna x~38)
def arma_espada():
    cv = Canvas()
    cv.rect(37, 4, 4, 24, C("M", 0)); cv.rect(39, 4, 2, 24, C("M", 1)); cv.put(38, 3, C("M", 0)); cv.put(39, 2, SHINE)
    cv.rect(33, 28, 12, 2, GOLD); cv.rect(37, 30, 4, 7, C("W", 1)); _disc(cv, 39, 38, 2, GOLD2)
    return fin(cv)


def arma_arco():
    cv = Canvas()
    for i in range(36):
        y = 5 + i
        x = 40 + int(round(4.5 * (1.0 - ((i - 17.5) / 17.5) ** 2)))
        cv.put(x, y, C("W", 1)); cv.put(x - 1, y, C("W", 0))
    cv.rect(39, 5, 1, 36, BONE)
    cv.rect(32, 22, 12, 1, C("W", 2)); cv.rect(30, 21, 3, 3, C("M", 0)); cv.rect(43, 21, 2, 3, C("A", 1))
    return fin(cv)


def arma_varinha():
    cv = Canvas()
    cv.rect(38, 14, 2, 28, C("W", 1)); cv.rect(38, 14, 1, 28, C("W", 0))
    cv.rect(38, 3, 2, 12, GOLD); cv.rect(33, 8, 12, 2, GOLD); cv.rect(35, 5, 8, 8, GOLD); cv.rect(37, 7, 4, 4, SHINE)
    for x, y in ((33, 3), (44, 4), (32, 14), (45, 13)):
        cv.put(x, y, SHINE)
    return fin(cv)


def arma_escudo():
    cv = Canvas()
    for i in range(18):
        w = 8 if i < 9 else int(8 * (18 - i) / 9.0)
        cv.rect(39 - w, 16 + i, w * 2, 1, C("A", 1 if i < 12 else 2))
    cv.rect(31, 16, 16, 2, C("M", 0)); cv.rect(38, 18, 2, 14, C("M", 0)); cv.rect(33, 23, 12, 2, C("M", 0))
    return fin(cv)


def arma_clava():
    cv = Canvas()
    cv.rect(38, 22, 3, 20, C("W", 1)); cv.rect(38, 22, 1, 20, C("W", 0))
    cv.blob_rect(34, 5, 11, 18, "W", 4)
    for x, y in ((33, 9), (45, 12), (33, 17), (45, 19), (39, 4)):
        cv.rect(x, y, 2, 2, BONE)
    return fin(cv)


def arma_frigideira():
    cv = Canvas()
    cv.rect(38, 22, 3, 20, DARK); cv.rect(38, 38, 3, 4, C("W", 1))
    _disc(cv, 39, 13, 8, DARK); _disc(cv, 39, 13, 6, (95, 95, 110, 255)); _disc(cv, 37, 12, 2.2, SHINE); _disc(cv, 37, 12, 1.0, FIRE)
    return fin(cv)


def arma_guitarra():
    cv = Canvas()
    cv.rect(38, 4, 3, 22, C("W", 1)); cv.rect(36, 2, 7, 4, C("W", 2))
    _disc(cv, 39, 31, 7, C("A", 1)); _disc(cv, 39, 23, 4.5, C("A", 1)); _disc(cv, 39, 31, 2.2, DARK)
    cv.rect(39, 6, 1, 30, BONE)
    return fin(cv)


def arma_picareta():
    cv = Canvas()
    cv.rect(38, 8, 3, 34, C("W", 1)); cv.rect(38, 8, 1, 34, C("W", 0))
    for i in range(9):
        cv.rect(39 - i - 1, 6 + i // 2, 2, 3, C("M", 0)); cv.rect(40 + i, 6 + i // 2, 2, 3, C("M", 1))
    return fin(cv)


# ================================================================ TORRES (48x48, base embaixo)
def torre_castelo():
    cv = Canvas()
    cv.blob_rect(8, 20, 32, 25, "M", 1)
    for x in range(8, 40, 6):
        cv.rect(x, 15, 4, 6, C("M", 1)); cv.rect(x, 15, 4, 1, C("M", 0))
    for y in range(24, 44, 5):
        for x in range(10 + (y % 2) * 3, 38, 8):
            cv.rect(x, y, 5, 1, C("M", 2))
    cv.rect(20, 32, 8, 13, C("W", 2)); cv.rect(21, 31, 6, 1, C("W", 2)); cv.rect(23, 33, 1, 12, C("W", 1))
    cv.rect(13, 25, 3, 5, DARK); cv.rect(32, 25, 3, 5, DARK)
    cv.rect(23, 3, 1, 12, C("W", 1)); cv.rect(24, 3, 8, 5, C("A", 1)); cv.rect(24, 3, 8, 1, C("A", 0))
    return fin(cv)


def torre_mago():
    cv = Canvas()
    cv.blob_rect(16, 20, 16, 25, "S", 2)
    _tri(cv, 24, 2, 18, 12, C("P", 1), C("P", 2))
    cv.rect(21, 26, 6, 7, DARK); cv.rect(22, 27, 4, 5, FIRE); cv.rect(21, 37, 6, 8, C("W", 2))
    for x, y in ((18, 10), (29, 13), (24, 6)):
        cv.put(x, y, GOLD)
    _disc(cv, 24, 1, 1.6, GOLD)
    return fin(cv)


def torre_vulcao():
    cv = Canvas()
    for i in range(30):
        w = 5 + int(i * 0.6)
        cv.rect(24 - w, 15 + i, w * 2, 1, C("W", 1 if i % 5 else 2))
    cv.rect(19, 13, 10, 3, FIRE2); cv.rect(21, 11, 6, 2, FIRE)
    for x, h in ((20, 9), (24, 14), (28, 7)):
        cv.rect(x, 16, 2, h, FIRE2); cv.put(x, 16 + h, FIRE)
    for x, y in ((18, 6), (24, 3), (30, 7), (22, 8)):
        cv.put(x, y, FIRE); cv.put(x, y - 1, FIRE2)
    return fin(cv)


def torre_arvore():
    cv = Canvas()
    cv.rect(20, 24, 8, 21, C("W", 1)); cv.rect(20, 24, 2, 21, C("W", 0)); cv.rect(26, 24, 2, 21, C("W", 2))
    for cx, cy, r in ((16, 16, 8), (31, 15, 9), (24, 9, 9), (24, 19, 9)):
        _disc(cv, cx, cy, r, TOX2)
    for cx, cy, r in ((15, 14, 5), (30, 12, 6), (23, 7, 6)):
        _disc(cv, cx, cy, r, TOX)
    cv.rect(21, 33, 6, 8, DARK); cv.rect(22, 34, 4, 6, FIRE)
    cv.rect(14, 28, 6, 2, C("W", 2)); cv.rect(28, 30, 6, 2, C("W", 2))
    return fin(cv)


def torre_iglu():
    cv = Canvas()
    cv.ellipse(24, 44, 19, 22, "P", shade=False)
    for y in range(20, 45):
        for x in range(4, 44):
            if cv.get(x, y)[3]:
                cv.put(x, y, SHINE if (x + y) < 62 else ICE)
    cv.rect(0, 45, 48, 3, NONE)
    for y in range(26, 44, 6):
        cv.rect(6, y, 36, 1, ICE2)
    for y in range(22, 44, 12):
        for x in range(10, 40, 8):
            cv.rect(x, y, 1, 6, ICE2)
    cv.rect(19, 33, 10, 12, DARK); cv.rect(20, 32, 8, 1, DARK)
    return fin(cv)


def torre_circo():
    cv = Canvas()
    for i in range(16):
        w = 2 + int(i * 1.1)
        for x in range(24 - w, 24 + w + 1):
            cv.put(x, 6 + i, C("A", 1) if ((x - 24 + 40) // 4) % 2 == 0 else SHINE)
    for x in range(6, 42):
        cv.rect(x, 22, 1, 23, C("A", 1) if (x // 4) % 2 == 0 else SHINE)
    cv.rect(6, 22, 36, 2, GOLD); cv.rect(20, 31, 8, 14, DARK)
    cv.rect(23, 0, 1, 7, C("W", 1)); cv.rect(24, 0, 6, 4, GOLD)
    return fin(cv)


# ================================================================ OBJETOS (48x48)
def obj_catapulta():
    cv = Canvas()
    cv.rect(6, 36, 36, 4, C("W", 1)); cv.rect(6, 36, 36, 1, C("W", 0))
    for cx in (12, 36):
        _disc(cv, cx, 41, 4.5, C("W", 2)); _disc(cv, cx, 41, 1.6, C("M", 1))
    cv.rect(20, 22, 4, 15, C("W", 1)); cv.line(10, 36, 22, 24, C("W", 2)); cv.line(34, 36, 24, 24, C("W", 2))
    cv.line(8, 14, 34, 30, C("W", 0)); cv.line(8, 15, 34, 31, C("W", 1))
    _disc(cv, 8, 12, 4.5, C("M", 1)); cv.put(7, 10, SHINE)
    return fin(cv)


def obj_canhao_grande():
    cv = Canvas()
    for cx in (15, 33):
        _disc(cv, cx, 38, 7, C("W", 1)); _disc(cv, cx, 38, 5, C("W", 2)); _disc(cv, cx, 38, 1.8, C("M", 0))
    cv.blob_rect(6, 20, 32, 12, "M", 4); cv.rect(8, 21, 28, 2, C("M", 0)); cv.rect(36, 18, 5, 16, C("M", 2))
    cv.rect(41, 23, 3, 6, DARK); cv.rect(4, 14, 2, 8, C("W", 1)); cv.put(4, 12, FIRE); cv.put(5, 11, FIRE2)
    return fin(cv)


def obj_barril():
    cv = Canvas()
    cv.blob_rect(12, 10, 24, 34, "W", 5)
    for y in (16, 27, 38):
        cv.rect(11, y, 26, 2, C("M", 1)); cv.rect(11, y, 26, 1, C("M", 0))
    for x in (18, 24, 30):
        cv.rect(x, 11, 1, 32, C("W", 2))
    cv.rect(22, 22, 5, 4, DARK); cv.rect(23, 23, 3, 2, FIRE2)
    return fin(cv)


def obj_bau():
    cv = Canvas()
    cv.blob_rect(8, 24, 32, 20, "W", 2); cv.blob_rect(8, 12, 32, 14, "W", 5)
    cv.rect(8, 24, 32, 2, GOLD2)
    for x in (8, 38):
        cv.rect(x, 12, 2, 32, GOLD)
    cv.rect(21, 22, 6, 8, GOLD); cv.rect(23, 25, 2, 3, DARK); cv.rect(10, 13, 28, 1, C("W", 0))
    for x, y in ((14, 9), (20, 7), (27, 8), (33, 10)):
        _disc(cv, x, y, 1.8, GOLD)
    return fin(cv)


def obj_fogueira():
    cv = Canvas()
    cv.line(8, 42, 38, 34, C("W", 1)); cv.line(8, 43, 38, 35, C("W", 2)); cv.line(40, 42, 10, 34, C("W", 1)); cv.line(40, 43, 10, 35, C("W", 2))
    for cx, top, h, half, col in ((24, 6, 30, 11, FIRE2), (24, 14, 22, 7, FIRE), (24, 22, 14, 4, SHINE)):
        _tri(cv, cx, top, h, half, col)
    for x, y in ((14, 14), (33, 10), (28, 4), (17, 6)):
        cv.put(x, y, FIRE)
    for x in (10, 16, 22, 28, 34):
        _disc(cv, x + 2, 44, 2.4, C("M", 1))
    return fin(cv)


def obj_totem():
    cv = Canvas()
    for i, slot in enumerate(("A", "S", "P")):
        y = 6 + i * 13
        cv.blob_rect(14, y, 20, 13, slot, 2)
        cv.rect(17, y + 3, 4, 3, EYE_W); cv.rect(27, y + 3, 4, 3, EYE_W); cv.put(19, y + 4, PUPIL); cv.put(28, y + 4, PUPIL)
        cv.rect(19, y + 8, 10, 2, DARK)
        for x in (20, 23, 26):
            cv.put(x, y + 8, BONE)
    for side in (-1, 1):
        cv.rect(24 + side * 14 - 2, 8, 5, 3, C("A", 2)); cv.rect(24 + side * 17 - 1, 5, 3, 4, C("A", 1))
    cv.rect(12, 44, 24, 2, C("W", 2))
    return fin(cv)


# ================================================================ ÍCONES (feitiços)
def ico_chama():
    cv = Canvas()
    for top, h, half, col in ((4, 40, 14, FIRE2), (16, 28, 9, FIRE), (28, 16, 5, SHINE)):
        _tri(cv, 24, top, h, half, col)
    cv.rect(8, 42, 33, 3, NONE)
    _disc(cv, 24, 36, 13, FIRE2); _disc(cv, 24, 38, 9, FIRE); _disc(cv, 24, 40, 5, SHINE)
    _tri(cv, 24, 4, 26, 11, FIRE2); _tri(cv, 22, 16, 16, 6, FIRE)
    return fin(cv)


def ico_floco():
    cv = Canvas()
    for dx, dy in ((1, 0), (0, 1), (1, 1), (1, -1)):
        for i in range(-18, 19):
            x, y = 24 + dx * i, 24 + dy * i
            if dx and dy:
                x, y = 24 + int(dx * i * 0.72), 24 + int(dy * i * 0.72)
            cv.rect(x, y, 2, 2, ICE if abs(i) < 12 else ICE2)
    for d in (-12, 12):
        for s in (-1, 1):
            cv.rect(24 + d + s * 3, 24 - 3 * (1 if d > 0 else -1) * 0 + s * 3, 2, 2, SHINE); cv.rect(24 + s * 3, 24 + d + s * 0, 2, 2, SHINE)
    _disc(cv, 25, 25, 3, SHINE)
    return fin(cv)


def ico_escudo():
    cv = Canvas()
    for i in range(38):
        w = 17 if i < 16 else int(17 * (38 - i) / 22.0)
        for x in range(24 - w, 24 + w + 1):
            cv.put(x, 5 + i, C("S", 0) if x < 24 else C("S", 2))
    for i in range(30):
        w = 12 if i < 12 else int(12 * (30 - i) / 18.0)
        for x in range(24 - w, 24 + w + 1):
            cv.put(x, 9 + i, C("S", 1))
    cv.rect(22, 12, 4, 22, GOLD); cv.rect(15, 19, 18, 4, GOLD)
    return fin(cv)


def ico_caveira_veneno():
    cv = Canvas()
    _disc(cv, 24, 20, 15, TOX2); _disc(cv, 24, 19, 13, TOX)
    cv.rect(15, 30, 18, 10, TOX)
    for x in (17, 22, 27, 31):
        cv.rect(x, 35, 2, 6, TOX2)
    cv.rect(14, 15, 7, 8, DARK); cv.rect(27, 15, 7, 8, DARK); cv.rect(22, 25, 4, 5, DARK)
    for x, y in ((6, 8), (41, 12), (9, 38), (40, 36)):
        _disc(cv, x, y, 2.5, TOX)
    return fin(cv)


def ico_espadas():
    cv = Canvas()
    for i in range(34):
        cv.rect(7 + i, 7 + i, 3, 3, C("M", 0)); cv.rect(38 - i, 7 + i, 3, 3, C("M", 1))
    for cx, sx in ((38, 1), (9, -1)):
        cv.line(cx - 6 * sx - 4, 36, cx - 6 * sx + 4, 28, GOLD); cv.line(cx - 6 * sx - 4, 37, cx - 6 * sx + 4, 29, GOLD2)
        _disc(cv, cx + sx * 2, 42, 2.5, GOLD)
    return fin(cv)


def ico_gota():
    cv = Canvas()
    _tri(cv, 24, 4, 24, 12, ICE2)
    _disc(cv, 24, 31, 13, ICE2); _disc(cv, 22, 30, 9, ICE); _disc(cv, 19, 26, 3, SHINE)
    return fin(cv)


def ico_sol():
    cv = Canvas()
    for a in range(8):
        import math
        dx, dy = math.cos(a * math.pi / 4), math.sin(a * math.pi / 4)
        for i in range(14, 22):
            cv.rect(int(24 + dx * i) - 1, int(24 + dy * i) - 1, 3, 3, FIRE)
    _disc(cv, 24, 24, 12, GOLD2); _disc(cv, 24, 24, 10, GOLD); _disc(cv, 21, 21, 3, SHINE)
    return fin(cv)


def ico_lua():
    cv = Canvas()
    _disc(cv, 24, 24, 17, ICE)
    for y in range(4, 44):
        for x in range(4, 46):
            if (x - 31) ** 2 + (y - 19) ** 2 <= 15 * 15:
                cv.put(x, y, NONE)
    for x, y in ((36, 10), (40, 26), (33, 36), (42, 16)):
        cv.rect(x, y, 2, 2, GOLD)
    return fin(cv)


def ico_cogumelo():
    cv = Canvas()
    cv.blob_rect(18, 24, 12, 20, "K", 4); cv.rect(18, 24, 12, 3, C("K", 2))
    cv.ellipse(24, 18, 18, 12, "A")
    cv.rect(4, 22, 40, 10, NONE)
    cv.blob_rect(18, 22, 12, 22, "K", 4)
    cv.rect(6, 20, 36, 3, C("A", 2))
    for x, y, r in ((15, 13, 3), (27, 10, 3.5), (35, 16, 2.5), (22, 17, 2)):
        _disc(cv, x, y, r, SHINE)
    return fin(cv)


def ico_nota():
    cv = Canvas()
    cv.rect(18, 8, 3, 28, DARK); cv.rect(34, 5, 3, 28, DARK)
    for i in range(6):
        cv.rect(18, 5 + i, 19, 1, DARK)
    _disc(cv, 15, 37, 6, DARK); _disc(cv, 31, 34, 6, DARK); cv.put(13, 35, SHINE); cv.put(29, 32, SHINE)
    return fin(cv)


MEGA = {
    "cabeca": {"robo_lata": cab_robo, "caveira_osso": cab_caveira, "abobora_careta": cab_abobora, "alienigena": cab_alien, "dragao_cabeca": cab_dragao,
               "urso": cab_urso, "coelho": cab_coelho, "palhaco": cab_palhaco, "ninja": cab_ninja, "pinguim": cab_pinguim},
    "chapeu": {"coroa_real": chap_coroa, "cartola_alta": chap_cartola, "bruxa": chap_bruxa, "viking": chap_viking, "gorro_pompom": chap_gorro, "chef": chap_chef},
    "arma": {"espada": arma_espada, "arco": arma_arco, "varinha": arma_varinha, "escudo_mao": arma_escudo, "clava": arma_clava,
             "frigideira_ovo": arma_frigideira, "guitarra": arma_guitarra, "picareta": arma_picareta},
    "torre": {"castelo_pedra": torre_castelo, "torre_mago": torre_mago, "vulcao": torre_vulcao, "casa_arvore": torre_arvore, "iglu": torre_iglu,
              "circo": torre_circo},
    "objeto": {"catapulta": obj_catapulta, "canhao_rodas": obj_canhao_grande, "barril_polvora": obj_barril, "bau": obj_bau, "fogueira": obj_fogueira,
               "totem": obj_totem},
    "icone": {"chama_icone": ico_chama, "floco_grande": ico_floco, "escudo_brasao": ico_escudo, "caveira_veneno": ico_caveira_veneno, "espadas": ico_espadas,
              "gota_agua": ico_gota, "sol": ico_sol, "lua": ico_lua, "cogumelo_pintado": ico_cogumelo, "nota_dupla": ico_nota},
}

TEMAS_MEGA = {
    "Comida": ["chef", "frigideira_ovo", "cogumelo_pintado", "barril_polvora", "abobora_careta"],
    "Guerra": ["espada", "arco", "escudo_mao", "clava", "catapulta", "canhao_rodas", "castelo_pedra", "espadas", "escudo_brasao", "viking", "ninja"],
    "ET e máquina": ["robo_lata", "alienigena", "lua", "sol"],
    "Oceano": ["pinguim", "iglu", "gota_agua", "floco_grande", "gorro_pompom"],
    "Mitologia": ["dragao_cabeca", "caveira_osso", "varinha", "bruxa", "coroa_real", "torre_mago", "vulcao", "totem", "caveira_veneno", "chama_icone", "fogueira", "bau"],
}
