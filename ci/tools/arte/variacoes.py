"""Variações: muito mais PROJÉTEIS (16x16, apontando pra DIREITA) e mais peças de
corpo (pernas, corpo, braços, costas) pra montar tropa no Criador.
Entram no atlas pelo exportar.py, junto com as outras."""
from kit import Canvas, C, SHINE
from pecas import new, fin, CXM

FIRE = (255, 200, 80, 255)
FIRE2 = (255, 120, 60, 255)
ICE = (190, 235, 255, 255)
ICE2 = (120, 190, 240, 255)
TOX = (150, 220, 70, 255)
TOX2 = (90, 160, 40, 255)
PURP = (190, 120, 240, 255)
PURP2 = (120, 70, 190, 255)
GOLD = (250, 210, 80, 255)
GOLD2 = (200, 150, 40, 255)
BONE = (240, 235, 215, 255)
BONE2 = (200, 190, 165, 255)
DARK = (50, 50, 60, 255)
DARK2 = (90, 90, 105, 255)


def _p():
    return Canvas(16, 16)


# ------------------------------------------------------------ projéteis
def proj_bola_canhao():
    cv = _p(); cv.ellipse(8, 8, 4.5, 4.5, "M", shade=False)
    for y in range(3, 13):
        for x in range(3, 13):
            if cv.get(x, y)[3]:
                cv.put(x, y, DARK if x + y > 15 else DARK2)
    cv.put(6, 6, SHINE); cv.put(7, 5, (200, 200, 215, 255)); return fin(cv)


def proj_foguetinho():
    cv = _p(); cv.rect(4, 6, 7, 4, C("P", 1)); cv.rect(4, 6, 7, 1, C("P", 0))
    cv.rect(11, 6, 2, 4, C("A", 1)); cv.rect(13, 7, 1, 2, C("A", 1))
    cv.rect(3, 4, 2, 2, C("A", 2)); cv.rect(3, 10, 2, 2, C("A", 2))
    cv.rect(7, 7, 2, 2, ICE2)
    cv.rect(1, 7, 2, 2, FIRE); cv.put(0, 8, FIRE2); return fin(cv)


def proj_bombinha():
    cv = _p(); cv.ellipse(7, 9, 4.5, 4.5, "M", shade=False)
    for y in range(4, 14):
        for x in range(2, 12):
            if cv.get(x, y)[3]:
                cv.put(x, y, DARK if x + y > 16 else DARK2)
    cv.put(5, 7, SHINE); cv.rect(9, 4, 2, 2, C("W", 1)); cv.put(11, 3, C("W", 0)); cv.put(12, 2, FIRE); cv.put(13, 1, FIRE2)
    return fin(cv)


def proj_shuriken():
    cv = _p()
    cv.rect(7, 2, 2, 12, C("M", 1)); cv.rect(2, 7, 12, 2, C("M", 1))
    cv.rect(5, 5, 6, 6, C("M", 0)); cv.rect(7, 7, 2, 2, DARK)
    for x, y in ((4, 3), (12, 4), (11, 12), (3, 11)):
        cv.put(x, y, C("M", 2))
    return fin(cv)


def proj_lanca_longa():
    cv = _p(); cv.rect(1, 7, 11, 2, C("W", 1)); cv.rect(1, 7, 11, 1, C("W", 0))
    cv.rect(11, 6, 2, 4, C("M", 0)); cv.rect(13, 7, 2, 2, C("M", 0)); cv.put(15, 7, SHINE)
    cv.rect(9, 6, 1, 4, C("A", 1)); return fin(cv)


def proj_garfo_triplo():
    cv = _p(); cv.rect(1, 7, 9, 2, C("W", 1))
    cv.rect(9, 4, 2, 8, C("M", 1))
    for y in (4, 7, 11):
        cv.rect(11, y, 3, 1 if y != 7 else 2, C("M", 0))
    cv.put(14, 4, SHINE); cv.put(14, 11, SHINE); cv.put(14, 7, SHINE); return fin(cv)


def proj_machadinha():
    cv = _p(); cv.line(3, 12, 10, 5, C("W", 1)); cv.line(4, 12, 11, 5, C("W", 2))
    cv.rect(9, 2, 4, 5, C("M", 1)); cv.rect(12, 3, 2, 4, C("M", 0)); cv.put(14, 4, SHINE); cv.put(14, 5, C("M", 0))
    return fin(cv)


def proj_bumerangue():
    cv = _p()
    cv.line(3, 12, 8, 5, C("W", 0)); cv.line(4, 13, 9, 6, C("W", 1))
    cv.line(8, 5, 13, 9, C("W", 0)); cv.line(9, 6, 13, 10, C("W", 1))
    cv.rect(3, 12, 2, 2, C("A", 1)); cv.rect(12, 9, 2, 2, C("A", 1)); return fin(cv)


def proj_osso():
    cv = _p(); cv.rect(4, 7, 8, 2, BONE)
    for x, y in ((2, 5), (2, 9), (12, 5), (12, 9)):
        cv.rect(x, y, 2, 2, BONE)
    cv.rect(4, 8, 8, 1, BONE2); return fin(cv)


def proj_sardinha():
    cv = _p(); cv.ellipse(9, 8, 4.5, 3, "S")
    cv.rect(2, 6, 2, 5, C("S", 1)); cv.rect(4, 7, 2, 3, C("S", 1))
    cv.put(11, 7, (255, 255, 255, 255)); cv.put(12, 7, (20, 20, 30, 255)); cv.put(8, 9, C("S", 2)); return fin(cv)


def proj_estrelinha():
    cv = _p()
    cv.rect(7, 2, 2, 12, GOLD); cv.rect(2, 7, 12, 2, GOLD); cv.rect(5, 5, 6, 6, GOLD)
    cv.rect(6, 6, 3, 3, (255, 245, 180, 255)); cv.put(4, 4, GOLD2); cv.put(11, 4, GOLD2); cv.put(4, 11, GOLD2); cv.put(11, 11, GOLD2)
    return fin(cv)


def proj_coracao():
    cv = _p()
    cv.rect(3, 4, 4, 4, C("A", 1)); cv.rect(9, 4, 4, 4, C("A", 1)); cv.rect(4, 6, 8, 4, C("A", 1))
    cv.rect(5, 10, 6, 1, C("A", 1)); cv.rect(6, 11, 4, 1, C("A", 2)); cv.rect(7, 12, 2, 1, C("A", 2))
    cv.put(4, 5, SHINE); cv.put(5, 5, C("A", 0)); return fin(cv)


def proj_cranio():
    cv = _p(); cv.ellipse(8, 7, 4.5, 4, "M", shade=False)
    for y in range(2, 12):
        for x in range(3, 13):
            if cv.get(x, y)[3]:
                cv.put(x, y, BONE)
    cv.rect(6, 11, 5, 2, BONE2); cv.rect(6, 6, 2, 2, DARK); cv.rect(9, 6, 2, 2, DARK); cv.put(8, 9, DARK)
    cv.put(7, 12, DARK); cv.put(9, 12, DARK); return fin(cv)


def proj_cristal():
    cv = _p()
    for i, w in enumerate((2, 4, 6, 6, 4, 2)):
        cv.rect(3 + i * 2, 8 - w // 2, 2, w, PURP if i < 3 else PURP2)
    cv.rect(5, 7, 4, 1, (235, 200, 255, 255)); cv.put(13, 8, PURP2); return fin(cv)


def proj_bolha():
    cv = _p(); cv.ellipse(8, 8, 5, 5, "S", shade=False)
    for y in range(3, 14):
        for x in range(3, 14):
            if cv.get(x, y)[3]:
                d = (x - 8) ** 2 + (y - 8) ** 2
                cv.put(x, y, ICE2 if d > 12 else ICE)
    cv.rect(5, 5, 2, 2, SHINE); cv.put(10, 11, SHINE); return fin(cv)


def proj_estaca_gelo():
    cv = _p(); cv.rect(2, 6, 5, 4, ICE2); cv.rect(7, 6, 4, 4, ICE); cv.rect(11, 7, 3, 2, ICE); cv.put(14, 7, SHINE)
    cv.rect(3, 6, 8, 1, SHINE); cv.put(1, 5, ICE2); cv.put(1, 10, ICE2); return fin(cv)


def proj_folha():
    cv = _p(); cv.ellipse(8, 8, 5, 3, "S", shade=False)
    for y in range(4, 12):
        for x in range(2, 14):
            if cv.get(x, y)[3]:
                cv.put(x, y, TOX if y < 8 else TOX2)
    cv.rect(3, 8, 10, 1, (60, 110, 30, 255)); cv.put(1, 8, C("W", 1)); cv.put(14, 8, TOX); return fin(cv)


def proj_semente():
    cv = _p(); cv.ellipse(8, 8, 3.5, 2.5, "W"); cv.put(7, 7, C("W", 0)); cv.put(11, 8, C("W", 2)); return fin(cv)


def proj_tomatada():
    cv = _p(); cv.ellipse(8, 9, 4.5, 4, "A"); cv.rect(7, 4, 3, 2, TOX2); cv.put(6, 5, TOX2); cv.put(10, 5, TOX2); cv.put(6, 7, SHINE)
    cv.put(2, 9, C("A", 1)); cv.put(1, 7, C("A", 1)); return fin(cv)


def proj_fatia_queijo():
    cv = _p()
    for i in range(9):
        h = 2 + i * 6 // 8
        cv.rect(13 - i, 8 - h // 2, 1, h, GOLD if i % 3 else (255, 230, 120, 255))
    cv.put(8, 8, GOLD2); cv.put(6, 6, GOLD2); cv.put(6, 10, GOLD2); return fin(cv)


def proj_plasma():
    cv = _p(); cv.ellipse(9, 8, 4.5, 4.5, "S", shade=False)
    for y in range(3, 13):
        for x in range(4, 14):
            if cv.get(x, y)[3]:
                d = (x - 9) ** 2 + (y - 8) ** 2
                cv.put(x, y, SHINE if d < 3 else (PURP if d < 10 else PURP2))
    cv.rect(1, 7, 3, 2, PURP2); cv.put(2, 5, PURP); cv.put(2, 10, PURP); return fin(cv)


def proj_anel():
    cv = _p(); cv.ellipse(8, 8, 5, 5, "K", shade=False)
    for y in range(3, 14):
        for x in range(3, 14):
            if cv.get(x, y)[3]:
                d = (x - 8) ** 2 + (y - 8) ** 2
                cv.put(x, y, (0, 0, 0, 0) if d < 7 else (GOLD if y < 9 else GOLD2))
    cv.put(5, 5, SHINE); return fin(cv)


def proj_teia():
    cv = _p()
    cv.rect(7, 2, 1, 12, BONE); cv.rect(2, 7, 12, 1, BONE); cv.line(3, 3, 12, 12, BONE); cv.line(12, 3, 3, 12, BONE)
    for a, b in (((5, 4), (10, 4)), ((11, 5), (11, 10)), ((10, 11), (5, 11)), ((4, 10), (4, 5))):
        cv.line(a[0], a[1], b[0], b[1], BONE2)
    return fin(cv)


def proj_veneno():
    cv = _p(); cv.ellipse(9, 8, 4, 3.5, "S", shade=False)
    for y in range(4, 12):
        for x in range(5, 14):
            if cv.get(x, y)[3]:
                cv.put(x, y, TOX if y < 9 else TOX2)
    cv.rect(3, 7, 3, 2, TOX2); cv.put(1, 8, TOX2); cv.put(10, 6, SHINE); cv.put(2, 5, TOX); cv.put(3, 11, TOX); return fin(cv)


def proj_moeda():
    cv = _p(); cv.ellipse(8, 8, 4.5, 4.5, "K", shade=False)
    for y in range(3, 13):
        for x in range(3, 13):
            if cv.get(x, y)[3]:
                cv.put(x, y, GOLD if x + y < 17 else GOLD2)
    cv.rect(7, 6, 2, 5, GOLD2); cv.put(6, 5, SHINE); return fin(cv)


def proj_dardo():
    cv = _p(); cv.rect(4, 7, 7, 2, C("M", 1)); cv.rect(11, 7, 3, 1, C("M", 0)); cv.put(14, 7, SHINE)
    cv.rect(1, 5, 3, 2, C("A", 1)); cv.rect(1, 9, 3, 2, C("A", 1)); cv.rect(2, 7, 2, 2, C("A", 2)); return fin(cv)


def proj_pena():
    cv = _p(); cv.ellipse(8, 8, 5, 2.5, "P"); cv.rect(2, 8, 12, 1, C("P", 2)); cv.put(1, 8, C("W", 1)); cv.put(0, 8, C("W", 1))
    cv.put(6, 6, C("P", 2)); cv.put(9, 10, C("P", 2)); return fin(cv)


def proj_meteoro():
    cv = _p(); cv.ellipse(10, 8, 4, 4, "W")
    cv.put(11, 9, C("W", 2)); cv.put(9, 7, C("W", 2))
    cv.rect(2, 6, 5, 1, FIRE2); cv.rect(1, 8, 6, 1, FIRE); cv.rect(3, 10, 4, 1, FIRE2); cv.rect(5, 7, 2, 3, FIRE)
    return fin(cv)


def proj_bola_neve():
    cv = _p(); cv.ellipse(8, 8, 4.5, 4.5, "P", shade=False)
    for y in range(3, 13):
        for x in range(3, 13):
            if cv.get(x, y)[3]:
                cv.put(x, y, SHINE if x + y < 17 else ICE)
    cv.put(10, 10, ICE2); cv.put(1, 8, ICE); return fin(cv)


def proj_faca():
    cv = _p(); cv.rect(2, 7, 4, 2, C("W", 1)); cv.rect(6, 6, 1, 4, C("K", 2))
    cv.rect(7, 7, 6, 2, C("M", 0)); cv.rect(7, 9, 5, 1, C("M", 1)); cv.put(13, 7, SHINE); return fin(cv)


def proj_martelinho():
    cv = _p(); cv.rect(2, 7, 8, 2, C("W", 1)); cv.rect(9, 4, 4, 8, C("M", 1)); cv.rect(9, 4, 4, 2, C("M", 0)); cv.rect(13, 5, 1, 6, C("M", 2))
    return fin(cv)


def proj_rajada():
    """três tracinhos de vento/energia"""
    cv = _p(); cv.rect(3, 4, 8, 1, C("S", 0)); cv.rect(1, 7, 13, 2, C("S", 0)); cv.rect(4, 11, 7, 1, C("S", 0))
    cv.rect(11, 7, 3, 2, SHINE); return fin(cv)


# ------------------------------------------------------------ pernas
def pernas_tenis():
    cv = new()
    for x in (17, 27):
        cv.blob_rect(x, 38, 5, 4, "K", 1)        # canela de fora
        cv.rect(x, 40, 5, 2, SHINE)               # meia
        cv.rect(x - 1, 42, 7, 3, C("A", 1))       # tênis
        cv.rect(x - 1, 44, 7, 1, SHINE)
        cv.put(x + 1, 42, SHINE)
    return fin(cv)


def pernas_pau():
    """uma bota e uma perna de pau (pirata)"""
    cv = new()
    cv.blob_rect(17, 38, 5, 4, "A", 1); cv.rect(16, 42, 7, 3, C("W", 1)); cv.rect(16, 44, 7, 1, C("W", 2))
    cv.rect(28, 38, 3, 2, C("M", 1)); cv.rect(29, 40, 2, 5, C("W", 0)); cv.put(30, 41, C("W", 2))
    return fin(cv)


def pernas_esteira():
    cv = new()
    cv.blob_rect(12, 39, 24, 6, "M", 3)
    for x in range(14, 35, 4):
        cv.rect(x, 41, 2, 2, DARK)
    cv.rect(13, 39, 22, 1, C("M", 0)); cv.rect(13, 44, 22, 1, C("M", 2))
    return fin(cv)


def pernas_tentaculos():
    cv = new()
    for i, x in enumerate((14, 19, 24, 29, 33)):
        h = 5 if i % 2 == 0 else 6
        cv.rect(x, 38, 3, h, C("P", 1)); cv.put(x + 1, 38 + h - 1, C("K", 0))
        cv.put(x + (1 if i < 2 else -1 if i > 2 else 0) + 1, 38 + h, C("P", 1))
    return fin(cv)


def pernas_mola():
    cv = new()
    for x in (18, 28):
        for i, y in enumerate(range(38, 44)):
            cv.rect(x + (0 if i % 2 else 1), y, 3, 1, C("M", 0 if i % 2 else 2))
        cv.rect(x - 1, 44, 6, 1, DARK)
    return fin(cv)


# ------------------------------------------------------------ corpo
def corpo_jaleco():
    cv = new(); cv.ellipse(24, 33, 9, 8.5, "P", shade=False)
    for y in range(24, 43):
        for x in range(14, 35):
            if cv.get(x, y)[3]:
                cv.put(x, y, SHINE if x < 28 else (225, 228, 235, 255))
    cv.rect(23, 26, 2, 15, (200, 205, 215, 255))        # abertura
    cv.rect(22, 25, 4, 4, C("S", 1))                     # gola da camisa
    cv.rect(27, 30, 4, 3, (225, 228, 235, 255)); cv.rect(28, 29, 1, 2, C("A", 1))   # bolso com caneta
    for y in (31, 35, 39):
        cv.put(21, y, C("M", 1))
    return fin(cv)


def corpo_quimono():
    cv = new(); cv.ellipse(24, 33, 9, 8.5, "S")
    cv.line(18, 26, 26, 36, C("S", 0)); cv.line(30, 26, 22, 36, C("S", 0))
    cv.rect(16, 35, 17, 2, C("A", 1)); cv.rect(16, 35, 17, 1, C("A", 0)); cv.rect(22, 36, 3, 4, C("A", 2))
    return fin(cv)


def corpo_escamas():
    cv = new(); cv.ellipse(24, 33, 9.5, 8.5, "P")
    for y in range(25, 42):
        for x in range(14, 35):
            if cv.get(x, y)[3] and (x + (y // 2) * 2) % 4 == 0 and y % 2 == 0:
                cv.put(x, y, C("P", 2)); cv.put(x + 1, y + 1, C("P", 0)) if cv.get(x + 1, y + 1)[3] else None
    cv.ellipse(24, 36, 4.5, 4.5, "K")
    return fin(cv)


def corpo_robo():
    cv = new(); cv.blob_rect(15, 25, 19, 17, "M", 2)
    cv.rect(16, 26, 17, 1, C("M", 0)); cv.rect(18, 29, 13, 6, DARK)
    cv.rect(19, 30, 3, 2, TOX); cv.rect(23, 30, 3, 2, FIRE); cv.rect(27, 30, 3, 2, C("A", 1)); cv.rect(19, 33, 11, 1, ICE2)
    for x, y in ((16, 40), (32, 40), (16, 26), (32, 26)):
        cv.put(x, y, C("M", 2))
    cv.rect(21, 37, 7, 3, C("M", 2)); cv.rect(22, 38, 5, 1, C("M", 0))
    return fin(cv)


def corpo_toga():
    cv = new(); cv.ellipse(24, 33, 9, 8.5, "K")
    for y in range(24, 43):
        for x in range(14, 35):
            if cv.get(x, y)[3] and (x - 14) + (y - 24) > 9:
                cv.put(x, y, SHINE if (x + y) % 5 else (220, 220, 230, 255))
    cv.line(15, 33, 24, 24, GOLD); cv.rect(28, 27, 2, 2, GOLD)
    return fin(cv)


def corpo_musculoso():
    cv = new(); cv.ellipse(24, 32, 10.5, 8, "K"); cv.ellipse(24, 38, 6.5, 4.5, "K")
    cv.rect(23, 27, 1, 5, C("K", 2)); cv.rect(18, 32, 12, 1, C("K", 2))
    for y in (35, 38):
        cv.rect(21, y, 6, 1, C("K", 2))
    cv.rect(23, 33, 1, 8, C("K", 2)); cv.rect(17, 40, 14, 2, C("A", 1))
    return fin(cv)


# ------------------------------------------------------------ braços
def bracos_garras():
    cv = new()
    for side, x in ((-1, 10), (1, 33)):
        cv.blob_rect(x, 28, 5, 7, "P", 2)
        for i in range(3):
            cv.rect(x + i * 2, 35, 1, 3, BONE)
    return fin(cv)


def bracos_pincas():
    cv = new()
    for x in (9, 33):
        cv.rect(x + 2, 28, 2, 5, C("M", 1)); cv.rect(x + 1, 32, 4, 2, C("M", 2))
        cv.rect(x, 34, 2, 4, C("M", 0)); cv.rect(x + 4, 34, 2, 4, C("M", 0)); cv.put(x + 1, 38, C("M", 0)); cv.put(x + 4, 38, C("M", 0))
    return fin(cv)


def bracos_luvas():
    cv = new()
    for x in (9, 33):
        cv.blob_rect(x + 1, 27, 4, 5, "K", 2)
        cv.ellipse(x + 3, 35, 3.5, 3.5, "A"); cv.rect(x + 1, 31, 5, 1, SHINE)
    return fin(cv)


def bracos_tentaculos():
    cv = new()
    for side, x in ((-1, 12), (1, 34)):
        for i in range(9):
            ox = int(round(2 * side * ((i % 4) in (1, 2))))
            cv.rect(x + ox, 28 + i, 3, 1, C("P", 1))
            if i % 2:
                cv.put(x + ox + 1, 28 + i, C("K", 0))
    return fin(cv)


# ------------------------------------------------------------ costas
def costas_asas_anjo():
    cv = new()
    for side in (-1, 1):
        for i, (dx, top, h) in enumerate(((9, 20, 14), (12, 18, 13), (15, 19, 10), (18, 22, 6))):
            x = CXM + side * dx - 1
            cv.rect(x, top, 3, h, SHINE if i % 2 == 0 else (225, 232, 245, 255))
    return fin(cv)


def costas_casco():
    cv = new(); cv.ellipse(24, 32, 12.5, 10.5, "W")
    for cx, cy in ((24, 27), (17, 32), (31, 32), (24, 37)):
        cv.rect(cx - 2, cy - 1, 4, 3, C("W", 0))
    return fin(cv)


def costas_aljava():
    cv = new(); cv.blob_rect(31, 20, 5, 12, "W", 2)
    for i, x in enumerate((32, 34)):
        cv.rect(x, 15 + i, 1, 5, C("W", 0)); cv.rect(x - 1, 14 + i, 3, 2, C("A", 1))
    cv.line(20, 26, 32, 30, C("W", 2))
    return fin(cv)


def costas_bandeira():
    cv = new(); cv.rect(36, 6, 2, 30, C("W", 1)); cv.rect(36, 6, 1, 30, C("W", 0))
    for y in range(7, 17):
        w = 9 - (1 if y % 4 == 0 else 0)
        cv.rect(38, y, w, 1, C("A", 1 if y < 13 else 2))
    cv.rect(40, 10, 4, 3, GOLD); cv.put(37, 5, GOLD)
    return fin(cv)


def costas_barbatana():
    cv = new()
    for i in range(10):
        cv.rect(22 + i // 2, 12 + i, 2 + i // 2 + i % 2, 1, C("P", 1 if i < 7 else 2))
    cv.rect(23, 14, 1, 6, C("P", 0))
    return fin(cv)


def costas_cilindro():
    """cilindro de mergulho"""
    cv = new()
    for x in (10, 33):
        cv.blob_rect(x, 24, 5, 14, "A", 2); cv.rect(x + 1, 22, 3, 2, C("M", 1)); cv.rect(x, 29, 5, 1, C("M", 0))
    cv.line(14, 23, 24, 20, DARK); cv.line(33, 23, 24, 20, DARK)
    return fin(cv)


VARIACOES = {
    "proj": {"bola_canhao": proj_bola_canhao, "foguetinho": proj_foguetinho, "bombinha": proj_bombinha, "shuriken": proj_shuriken,
             "lanca_longa": proj_lanca_longa, "garfo_triplo": proj_garfo_triplo, "machadinha": proj_machadinha,
             "bumerangue": proj_bumerangue, "osso": proj_osso, "sardinha": proj_sardinha, "estrelinha": proj_estrelinha,
             "coracaozinho": proj_coracao, "cranio": proj_cranio, "cristal": proj_cristal, "bolha": proj_bolha,
             "estaca_gelo": proj_estaca_gelo, "folha": proj_folha, "semente": proj_semente, "tomatada": proj_tomatada,
             "fatia_queijo": proj_fatia_queijo, "plasma": proj_plasma, "anel": proj_anel, "teia": proj_teia, "veneno": proj_veneno,
             "moedinha": proj_moeda, "dardo": proj_dardo, "pena": proj_pena, "meteoro": proj_meteoro, "bola_neve": proj_bola_neve,
             "faca": proj_faca, "martelinho": proj_martelinho, "rajada": proj_rajada},
    "pernas": {"tenis": pernas_tenis, "perna_de_pau": pernas_pau, "esteira": pernas_esteira, "tentaculos_pe": pernas_tentaculos,
               "mola": pernas_mola},
    "corpo": {"jaleco": corpo_jaleco, "quimono": corpo_quimono, "escamas": corpo_escamas, "robo_caixa": corpo_robo,
              "toga": corpo_toga, "musculoso": corpo_musculoso},
    "bracos": {"garras": bracos_garras, "pincas": bracos_pincas, "luvas_boxe": bracos_luvas, "tentaculos_braco": bracos_tentaculos},
    "costas": {"asas_anjo": costas_asas_anjo, "casco_tartaruga": costas_casco, "aljava": costas_aljava, "estandarte": costas_bandeira,
               "barbatana": costas_barbatana, "cilindro": costas_cilindro},
}

# tema de cada peça nova (o filtro de tema do Criador); as sem tema ficam em "Fazenda"
TEMAS_EXTRA = {
    "Comida": ["tomatada", "fatia_queijo", "semente", "sardinha"],
    "Guerra": ["bola_canhao", "foguetinho", "bombinha", "shuriken", "lanca_longa", "machadinha", "dardo", "faca", "martelinho",
               "esteira", "aljava", "estandarte", "musculoso", "luvas_boxe", "quimono"],
    "ET e máquina": ["plasma", "anel", "cristal", "rajada", "mola", "robo_caixa", "pincas", "jaleco"],
    "Oceano": ["bolha", "perna_de_pau", "tentaculos_pe", "tentaculos_braco", "barbatana", "cilindro", "casco_tartaruga", "escamas"],
    "Mitologia": ["garfo_triplo", "cranio", "osso", "estrelinha", "coracaozinho", "meteoro", "teia", "veneno", "toga", "asas_anjo", "garras"],
}
