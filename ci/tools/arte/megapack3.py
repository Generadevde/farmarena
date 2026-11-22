"""MEGA PACK 3: peças pra TODAS as partes -- braços, pernas, corpos, costas, chapéus, armas,
torres/defesas, objetos de defesa e projéteis. Mesmo jeito das outras: cores por slot
(P S A K M W) pra pintar com a paleta da carta; cores fixas só no que tem cor própria."""
import math
from kit import Canvas, C, SHINE
from pecas import new, fin, CXM
from megapack2 import _disc, _tri, FIRE, FIRE2, ICE, ICE2, GOLD, GOLD2, BONE, BONE2, DARK, STONE, STONE2, RED, PINK, TOX, PURP, PURP2, ELEC

LEAF = (110, 180, 70, 255)
LEAF2 = (70, 130, 50, 255)
WATER = (110, 180, 240, 255)
WHITE = (245, 245, 240, 255)


def _p():
    return Canvas()


# ================================================================ BRAÇOS
def bracos_robo():
    cv = new()
    for x in (10, 33):
        cv.rect(x + 1, 27, 4, 7, C("M", 1)); cv.rect(x + 1, 27, 1, 7, C("M", 0))
        cv.rect(x, 33, 6, 4, C("M", 2)); cv.put(x + 2, 35, DARK)
    return fin(cv)


def bracos_garras():
    cv = new()
    for x, s in ((11, -1), (33, 1)):
        cv.blob_rect(x, 28, 5, 6, "P", 2)
        for k in range(3):
            cv.rect(x + k * 2, 34, 1, 3, BONE)
    return fin(cv)


def bracos_tentaculos():
    cv = new()
    for side in (-1, 1):
        for i in range(12):
            x = int(CXM + side * (10 + i * 0.4) + math.sin(i * 0.9) * 2)
            cv.rect(x, 26 + i, 3, 2, C("P", 1 if i % 3 else 2))
        cv.put(CXM + side * 14, 31, C("A", 0))
    return fin(cv)


def bracos_musculosos():
    cv = new()
    for x in (8, 33):
        cv.ellipse(x + 3.5, 30, 4.5, 4.5, "K")
        cv.blob_rect(x + 1, 33, 6, 5, "K", 2)
    return fin(cv)


def bracos_ombreiras():
    cv = new()
    for x in (10, 33):
        cv.ellipse(x + 3, 27, 5, 3, "M")
        cv.blob_rect(x + 1, 29, 4, 6, "S", 1)
        cv.blob_rect(x + 1, 34, 4, 3, "M", 1)
    return fin(cv)


def bracos_magrelos():
    cv = new()
    for x in (13, 33):
        cv.rect(x, 28, 2, 8, C("K", 1)); cv.rect(x - 1, 35, 4, 2, C("K", 0))
    return fin(cv)


def bracos_luvas_boxe():
    cv = new()
    for x in (10, 33):
        cv.rect(x + 1, 28, 3, 4, C("K", 1))
        cv.ellipse(x + 2.5, 34, 3.5, 3, "A"); cv.put(x + 1, 33, SHINE)
    return fin(cv)


def bracos_gancho():
    cv = new()
    cv.blob_rect(11, 28, 5, 6, "S", 2); cv.blob_rect(11, 33, 5, 4, "K", 2)
    cv.blob_rect(33, 28, 5, 6, "S", 2)
    cv.rect(35, 34, 1, 3, C("M", 0)); cv.rect(35, 37, 3, 1, C("M", 0)); cv.put(38, 36, C("M", 0))
    return fin(cv)


def bracos_galhos():
    cv = new()
    for side in (-1, 1):
        x0 = CXM + side * 9
        for i in range(8):
            cv.rect(x0 + side * i, 29 - i // 2, 2, 2, C("W", 1))
        cv.rect(x0 + side * 7, 24, 3, 3, LEAF); cv.put(x0 + side * 4, 26, LEAF2)
    return fin(cv)


def bracos_ossos():
    cv = new()
    for x in (12, 34):
        cv.rect(x, 28, 2, 8, BONE); cv.rect(x - 1, 28, 4, 1, BONE2); cv.rect(x - 1, 35, 4, 2, BONE)
    return fin(cv)


# ================================================================ PERNAS
def pernas_sandalia():
    cv = new()
    for x in (17, 27):
        cv.rect(x + 1, 38, 3, 5, C("K", 1)); cv.rect(x, 43, 6, 2, C("W", 1)); cv.rect(x + 1, 41, 4, 1, C("W", 2))
    return fin(cv)


def pernas_botas_altas():
    cv = new()
    for x in (17, 27):
        cv.blob_rect(x, 36, 6, 9, "W", 2); cv.rect(x, 36, 6, 2, C("W", 0)); cv.rect(x + 1, 43, 6, 2, C("W", 2))
    return fin(cv)


def pernas_saia():
    cv = new()
    for y in range(36, 43):
        half = 8 + (y - 36) // 2
        cv.rect(CXM - half, y, half * 2, 1, C("A", 1 if y % 3 else 2))
    for x in (19, 26):
        cv.rect(x, 43, 3, 2, C("W", 1))
    return fin(cv)


def pernas_tentaculos():
    cv = new()
    for i, x in enumerate(range(15, 34, 4)):
        for k in range(8):
            cv.rect(x + int(math.sin(k * 0.8 + i) * 1.5), 37 + k, 2, 1, C("P", 1 if k % 3 else 2))
    return fin(cv)


def pernas_esteira():
    cv = new()
    cv.blob_rect(12, 38, 25, 7, "M", 3)
    for x in range(14, 36, 4):
        cv.rect(x, 39, 2, 5, DARK)
    for x in (16, 24, 32):
        _disc(cv, x, 41, 1.5, C("M", 0))
    return fin(cv)


def pernas_mola():
    cv = new()
    for x in (18, 28):
        for k in range(4):
            cv.rect(x - 1, 37 + k * 2, 4, 1, C("M", 0 if k % 2 else 1))
        cv.rect(x - 2, 44, 6, 1, C("M", 2))
    return fin(cv)


def pernas_pau():
    cv = new()
    cv.blob_rect(17, 38, 5, 4, "A", 1); cv.rect(17, 42, 6, 3, C("W", 1))
    cv.blob_rect(27, 38, 5, 3, "A", 1); cv.rect(28, 41, 2, 4, C("W", 1))
    return fin(cv)


def pernas_patins():
    cv = new()
    for x in (17, 27):
        cv.blob_rect(x, 38, 5, 5, "A", 1); cv.rect(x - 1, 43, 7, 1, C("M", 1))
        cv.put(x, 44, DARK); cv.put(x + 4, 44, DARK)
    return fin(cv)


def pernas_raizes():
    cv = new()
    cv.blob_rect(18, 37, 12, 4, "W", 2)
    for x, dx in ((16, -1), (20, 0), (25, 0), (30, 1)):
        for k in range(5):
            cv.put(x + dx * k, 41 + k // 2, C("W", 2 if k % 2 else 1))
    return fin(cv)


def pernas_nuvem():
    cv = new()
    for x, r in ((17, 4), (24, 5), (31, 4)):
        _disc(cv, x, 41, r, WHITE)
    cv.rect(14, 43, 21, 2, (210, 220, 235, 255))
    return fin(cv)


# ================================================================ CORPOS
def corpo_vestido():
    cv = new()
    cv.ellipse(24, 29, 7, 5, "A")
    for y in range(31, 42):
        half = 6 + (y - 31) // 2
        cv.rect(24 - half, y, half * 2 + 1, 1, C("A", 1 if y % 4 else 2))
    cv.rect(18, 30, 13, 1, C("P", 0))
    return fin(cv)


def corpo_terno():
    cv = new()
    cv.ellipse(24, 33, 9, 8.5, "P")
    cv.rect(22, 25, 5, 10, WHITE); cv.rect(23, 27, 3, 7, C("A", 1)); cv.put(24, 26, C("A", 0))
    cv.rect(18, 35, 2, 1, C("P", 2)); cv.rect(29, 35, 2, 1, C("P", 2))
    return fin(cv)


def corpo_colete():
    cv = new()
    cv.ellipse(24, 33, 9, 8.5, "S")
    cv.blob_rect(16, 27, 7, 13, "W", 2); cv.blob_rect(26, 27, 7, 13, "W", 2)
    for y in (30, 34, 38):
        cv.put(25, y, GOLD)
    return fin(cv)


def corpo_jaleco():
    cv = new()
    cv.ellipse(24, 33, 9, 8.5, "P")
    for y in range(25, 42):
        for x in range(15, 34):
            if cv.get(x, y)[3]:
                cv.put(x, y, WHITE if abs(x - 24) > 1 else (210, 210, 205, 255))
    cv.rect(17, 34, 4, 3, (200, 200, 195, 255)); cv.put(28, 30, C("A", 0))
    return fin(cv)


def corpo_tunica_mago():
    cv = new()
    for y in range(25, 43):
        half = 7 + (y - 25) // 3
        cv.rect(24 - half, y, half * 2 + 1, 1, C("P", 1))
    cv.rect(22, 25, 5, 18, C("P", 2))
    for y in (30, 36):
        cv.rect(16, y, 17, 1, GOLD)
    _tri(cv, 24, 32, 4, 2, GOLD)
    return fin(cv)


def corpo_couraca():
    cv = new()
    cv.ellipse(24, 33, 9, 8.5, "M")
    cv.rect(18, 27, 13, 2, GOLD); cv.rect(23, 29, 3, 10, GOLD2)
    for x in (19, 29):
        _disc(cv, x, 33, 1.2, GOLD)
    return fin(cv)


def corpo_esqueleto():
    cv = new()
    cv.rect(23, 25, 3, 16, BONE)
    for y in (27, 30, 33):
        cv.rect(17, y, 15, 1, BONE); cv.put(17, y + 1, BONE2); cv.put(31, y + 1, BONE2)
    cv.ellipse(24, 39, 6, 2.5, "P", shade=False)
    for y in range(37, 42):
        for x in range(17, 32):
            if cv.get(x, y)[3]:
                cv.put(x, y, BONE)
    return fin(cv)


def corpo_robo():
    cv = new()
    cv.blob_rect(15, 25, 19, 17, "M", 3)
    cv.rect(18, 28, 13, 7, DARK)
    for x, col in ((20, RED), (24, GOLD), (28, (90, 220, 120, 255))):
        cv.rect(x, 30, 2, 2, col)
    for x in range(18, 31, 3):
        cv.put(x, 38, C("M", 2))
    return fin(cv)


def corpo_casco():
    cv = new()
    cv.ellipse(24, 33, 10, 9, "P")
    for y in range(24, 43):
        for x in range(14, 35):
            if cv.get(x, y)[3] and ((x + y) % 7 == 0 or (x - y) % 7 == 0):
                cv.put(x, y, C("P", 2))
    cv.rect(19, 40, 11, 2, C("S", 1))
    return fin(cv)


def corpo_folhas():
    cv = new()
    cv.ellipse(24, 33, 9, 8.5, "S")
    for i in range(18):
        x = 16 + (i * 7) % 17
        y = 26 + (i * 5) % 15
        cv.rect(x, y, 3, 2, LEAF if i % 2 else LEAF2)
    return fin(cv)


def corpo_gelo():
    cv = new()
    cv.ellipse(24, 33, 9, 8.5, "P")
    for y in range(24, 43):
        for x in range(14, 35):
            if cv.get(x, y)[3]:
                cv.put(x, y, ICE if (x + y // 2) % 5 else ICE2)
    cv.rect(18, 28, 2, 4, SHINE); cv.put(27, 35, SHINE)
    return fin(cv)


def corpo_avental():
    cv = new()
    cv.ellipse(24, 33, 9, 8.5, "S")
    cv.blob_rect(18, 28, 13, 14, "P", 3); cv.rect(20, 24, 1, 5, C("P", 2)); cv.rect(28, 24, 1, 5, C("P", 2))
    cv.rect(21, 34, 7, 3, C("P", 2)); cv.rect(15, 32, 19, 1, C("P", 1))
    return fin(cv)


# ================================================================ COSTAS
def costas_aljava():
    cv = new()
    cv.blob_rect(30, 18, 6, 18, "W", 2)
    for x, c in ((30, C("A", 0)), (32, C("A", 1)), (34, C("A", 0))):
        cv.rect(x, 13, 1, 6, C("W", 0)); cv.rect(x - 1, 11, 3, 2, c)
    return fin(cv)


def costas_escudo():
    cv = new()
    _disc(cv, 24, 30, 11, C("W", 1)); _disc(cv, 24, 30, 9, C("A", 1)); _disc(cv, 24, 30, 3, C("M", 0))
    return fin(cv)


def costas_bandeira():
    cv = new()
    cv.rect(33, 6, 1, 34, C("W", 1))
    for y in range(6, 16):
        cv.rect(34, y, 9 - abs(y - 11) // 2, 1, C("A", 1 if y < 11 else 2))
    return fin(cv)


def costas_asas_anjo():
    cv = new()
    for side in (-1, 1):
        for i in range(9):
            cv.rect(CXM + side * (10 + i) - (2 if side < 0 else 0), 22 + i // 2, 3, 8 - i // 2, WHITE if i % 3 else (215, 220, 230, 255))
    return fin(cv)


def costas_asas_inseto():
    cv = new()
    for side in (-1, 1):
        cv.ellipse(CXM + side * 12, 26, 6, 8, "S", shade=False)
        for y in range(18, 35):
            for x in range(0, 48):
                if cv.get(x, y)[3] and abs(x - CXM) > 6:
                    cv.put(x, y, (200, 235, 250, 255) if (x + y) % 5 else (150, 200, 230, 255))
    return fin(cv)


def costas_tanque():
    cv = new()
    cv.blob_rect(16, 20, 16, 18, "M", 5); cv.rect(18, 22, 12, 12, WATER); cv.rect(19, 23, 2, 6, SHINE)
    cv.rect(32, 24, 6, 2, C("M", 2)); cv.rect(37, 24, 2, 6, C("M", 2))
    return fin(cv)


def costas_lenha():
    cv = new()
    for i, y in enumerate((20, 25, 30)):
        cv.blob_rect(12 + i, y, 24 - i * 2, 5, "W", 2)
        _disc(cv, 12 + i, y + 2, 2, (200, 160, 110, 255))
    cv.rect(23, 18, 2, 18, C("A", 1))
    return fin(cv)


def costas_capa_rasgada():
    cv = new()
    for y in range(24, 43):
        half = 8 + (y - 24) // 3
        for x in range(24 - half, 24 + half + 1):
            if y < 39 or (x % 4) < 2:
                cv.put(x, y, C("A", 1 if x < 27 else 2))
    return fin(cv)


def costas_espada():
    cv = new()
    for i in range(26):
        cv.rect(12 + i, 40 - i, 2, 2, C("M", 0 if i > 6 else 1))
    cv.rect(15, 33, 6, 2, GOLD)
    return fin(cv)


def costas_guarda_chuva():
    cv = new()
    cv.rect(31, 14, 1, 28, C("W", 1))
    for y in range(6, 15):
        half = (y - 5) * 1.6
        cv.rect(int(31 - half), y, int(half * 2) + 1, 1, C("A", 1 if y % 3 else 2))
    return fin(cv)


# ================================================================ CHAPÉUS
def chap_viking():
    cv = new()
    cv.ellipse(24, 7, 11, 6, "M")
    for side in (-1, 1):
        for i in range(6):
            cv.rect(24 + side * (11 + i // 2), 6 - i, 2, 2, BONE)
    cv.rect(13, 9, 23, 2, C("M", 2))
    return fin(cv)


def chap_cartola():
    cv = new()
    cv.ellipse(24, 9, 13, 2.5, "P"); cv.blob_rect(17, -2, 15, 11, "P", 1); cv.rect(17, 6, 15, 2, C("A", 1))
    return fin(cv)


def chap_boina():
    cv = new()
    cv.ellipse(23, 6, 12, 4.5, "A"); cv.put(23, 1, C("A", 0))
    return fin(cv)


def chap_pirata():
    cv = new()
    for y in range(0, 10):
        half = 15 - abs(y - 6) * 2
        cv.rect(24 - half, y, half * 2, 1, DARK)
    _disc(cv, 24, 5, 2, WHITE)
    return fin(cv)


def chap_aureola():
    cv = new()
    for a in range(0, 360, 12):
        cv.rect(int(24 + math.cos(math.radians(a)) * 9), int(2 + math.sin(math.radians(a)) * 2.5), 2, 1, GOLD)
    return fin(cv)


def chap_chifres():
    cv = new()
    for side in (-1, 1):
        for i in range(8):
            cv.rect(24 + side * (8 + i // 2), 9 - i, 2, 2, C("M", 1) if i < 6 else C("M", 0))
    return fin(cv)


def chap_tiara_flores():
    cv = new()
    for i, x in enumerate(range(13, 37, 5)):
        col = (PINK, GOLD, WHITE, (170, 120, 240, 255), PINK)[i % 5]
        _disc(cv, x, 8, 2, col); cv.put(x, 8, GOLD2)
    return fin(cv)


def chap_capacete_obra():
    cv = new()
    cv.ellipse(24, 7, 11, 6, "P", shade=False)
    for y in range(1, 13):
        for x in range(12, 37):
            if cv.get(x, y)[3]:
                cv.put(x, y, GOLD if x < 30 else GOLD2)
    cv.rect(11, 10, 27, 2, GOLD2); cv.rect(23, 1, 3, 9, (255, 230, 120, 255))
    return fin(cv)


# ================================================================ ARMAS
def arma_estilingue():
    cv = new()
    cv.rect(38, 26, 2, 12, C("W", 1)); cv.rect(35, 20, 2, 7, C("W", 1)); cv.rect(41, 20, 2, 7, C("W", 1))
    cv.rect(36, 21, 6, 1, C("A", 1))
    return fin(cv)


def arma_arco():
    cv = new()
    for i in range(24):
        x = 40 + int(math.sin(i / 23.0 * math.pi) * 5)
        cv.put(x, 12 + i, C("W", 1)); cv.put(x + 1, 12 + i, C("W", 2))
    cv.rect(40, 12, 1, 24, WHITE)
    return fin(cv)


def arma_lanca():
    cv = new()
    cv.rect(39, 8, 2, 36, C("W", 1)); _tri(cv, 40, 1, 8, 2, C("M", 0))
    cv.rect(38, 14, 4, 2, C("A", 1))
    return fin(cv)


def arma_tridente():
    cv = new()
    cv.rect(39, 12, 2, 32, C("M", 1)); cv.rect(35, 11, 10, 2, C("M", 1))
    for x in (35, 39, 43):
        cv.rect(x, 4, 2, 8, C("M", 0)); _tri(cv, x, 1, 3, 1, C("M", 0))
    return fin(cv)


def arma_varinha():
    cv = new()
    cv.rect(38, 22, 2, 16, C("W", 2)); _disc(cv, 39, 19, 3, PURP); cv.put(38, 18, SHINE)
    for x, y in ((34, 15), (43, 16), (40, 12)):
        cv.put(x, y, GOLD)
    return fin(cv)


def arma_escudo():
    cv = new()
    cv.blob_rect(33, 24, 11, 14, "M", 4); cv.blob_rect(35, 26, 7, 10, "A", 3); cv.rect(38, 27, 1, 8, C("M", 0))
    return fin(cv)


def arma_chicote():
    cv = new()
    cv.rect(37, 30, 2, 8, C("W", 2))
    for i in range(16):
        cv.put(38 + int(math.sin(i * 0.5) * 3) + i // 4, 30 - i, C("W", 1))
    return fin(cv)


def arma_guarda_chuva():
    cv = new()
    cv.rect(39, 18, 1, 22, C("W", 1)); cv.rect(37, 39, 3, 1, C("W", 1))
    for y in range(10, 18):
        half = (y - 9) * 1.2
        cv.rect(int(39 - half), y, int(half * 2) + 1, 1, C("A", 1 if y % 3 else 2))
    return fin(cv)


def arma_concha():
    cv = new()
    cv.rect(39, 14, 2, 22, C("W", 1)); cv.ellipse(40, 38, 4, 3, "M")
    return fin(cv)


def arma_sino():
    cv = new()
    cv.rect(39, 18, 2, 6, C("W", 1))
    for y in range(24, 34):
        half = 2 + (y - 24) // 2
        cv.rect(40 - half, y, half * 2, 1, GOLD if y < 32 else GOLD2)
    _disc(cv, 40, 35, 1.5, C("M", 0))
    return fin(cv)


# ================================================================ TORRES E DEFESAS
def _base_pedra(cv, y0=34):
    cv.blob_rect(8, y0, 32, 45 - y0, "M", 3)
    for y in range(y0 + 1, 45, 4):
        for x in range(9 + (y // 4 % 2) * 3, 39, 6):
            cv.rect(x, y, 1, 3, C("M", 2))


def torre_arqueiro():
    cv = Canvas()
    cv.blob_rect(14, 14, 20, 31, "W", 2)
    for y in range(16, 44, 5):
        cv.rect(14, y, 20, 1, C("W", 2))
    cv.rect(11, 10, 26, 5, C("W", 0))
    for x in range(11, 37, 5):
        cv.rect(x, 6, 3, 4, C("W", 0))
    cv.rect(21, 22, 6, 7, DARK)
    return fin(cv)


def torre_pedra():
    cv = Canvas()
    cv.blob_rect(12, 12, 24, 33, "M", 3)
    for y in range(14, 45, 4):
        for x in range(13 + (y // 4 % 2) * 3, 36, 6):
            cv.rect(x, y, 1, 3, C("M", 2))
    for x in range(10, 38, 6):
        cv.rect(x, 7, 4, 6, C("M", 1))
    cv.rect(21, 20, 6, 8, DARK); cv.rect(22, 19, 4, 1, DARK)
    return fin(cv)


def torre_cerca_espinhos():
    cv = Canvas()
    cv.rect(4, 30, 40, 3, C("W", 1)); cv.rect(4, 37, 40, 3, C("W", 1))
    for x in range(6, 44, 7):
        cv.rect(x, 24, 3, 21, C("W", 2)); _tri(cv, x + 1, 20, 4, 1, C("W", 2))
    for x in range(5, 44, 4):
        cv.put(x, 29, C("M", 0)); cv.put(x + 2, 36, C("M", 0))
    return fin(cv)


def torre_muralha_madeira():
    cv = Canvas()
    for x in range(4, 44, 5):
        cv.blob_rect(x, 16, 5, 29, "W", 2); _tri(cv, x + 2, 11, 5, 2, C("W", 1))
    cv.rect(4, 26, 40, 2, C("M", 1)); cv.rect(4, 38, 40, 2, C("M", 1))
    return fin(cv)


def torre_muralha_pedra():
    cv = Canvas()
    _base_pedra(cv, 18)
    for x in range(8, 40, 6):
        cv.rect(x, 13, 4, 6, C("M", 1))
    return fin(cv)


def torre_canhao_naval():
    cv = Canvas()
    cv.blob_rect(8, 32, 32, 12, "W", 3)
    _disc(cv, 15, 43, 4, C("W", 2)); _disc(cv, 33, 43, 4, C("W", 2))
    for i in range(14):
        cv.rect(14 + i, 28 - i // 2, 6, 6, C("M", 1 if i < 10 else 0))
    _disc(cv, 30, 22, 3, DARK)
    return fin(cv)


def torre_balista():
    cv = Canvas()
    cv.blob_rect(12, 34, 24, 10, "W", 3)
    cv.rect(23, 18, 3, 17, C("W", 1))
    for i in range(14):
        cv.put(24 - i, 20 + abs(7 - i) // 2, C("W", 0)); cv.put(24 + i, 20 + abs(7 - i) // 2, C("W", 0))
    cv.rect(23, 8, 2, 14, C("W", 2)); _tri(cv, 24, 4, 5, 2, C("M", 0))
    cv.rect(11, 24, 27, 1, WHITE)
    return fin(cv)


def torre_catapulta():
    cv = Canvas()
    cv.blob_rect(8, 34, 32, 8, "W", 2)
    _disc(cv, 13, 42, 3.5, C("W", 2)); _disc(cv, 35, 42, 3.5, C("W", 2))
    for i in range(22):
        cv.rect(14 + i, 32 - i, 2, 2, C("W", 1))
    cv.ellipse(36, 10, 5, 3, "W"); _disc(cv, 36, 8, 3, STONE)
    cv.rect(22, 24, 3, 11, C("W", 0))
    return fin(cv)


def torre_gelo():
    cv = Canvas()
    for y in range(8, 45):
        half = 4 + (y - 8) // 3
        for x in range(24 - half, 24 + half + 1):
            cv.put(x, y, ICE if (x + y) % 6 else ICE2)
    for x, y in ((17, 30), (30, 22), (22, 16)):
        cv.rect(x, y, 2, 4, SHINE)
    _tri(cv, 24, 1, 8, 3, WHITE)
    return fin(cv)


def torre_totem():
    cv = Canvas()
    for i, y in enumerate((8, 20, 32)):
        cv.blob_rect(15, y, 18, 12, "A" if i % 2 else "P", 3)
        cv.rect(19, y + 3, 3, 3, DARK); cv.rect(26, y + 3, 3, 3, DARK); cv.rect(20, y + 8, 8, 2, C("W", 2))
    for side in (-1, 1):
        cv.rect(24 + side * 12 - (3 if side < 0 else 0), 12, 4, 3, C("S", 1))
    return fin(cv)


def torre_poco():
    cv = Canvas()
    cv.ellipse(24, 36, 14, 8, "M")
    cv.ellipse(24, 33, 11, 4, "S", shade=False)
    for y in range(29, 38):
        for x in range(13, 36):
            if (x - 24) ** 2 / 121.0 + (y - 33) ** 2 / 16.0 <= 1.0:
                cv.put(x, y, WATER if y > 32 else (80, 140, 200, 255))
    for x in (11, 36):
        cv.rect(x, 10, 2, 24, C("W", 1))
    for y in range(6, 12):
        half = 16 - (11 - y)
        cv.rect(24 - half, y, half * 2, 1, C("A", 1 if y % 2 else 2))
    return fin(cv)


def torre_silo():
    cv = Canvas()
    cv.blob_rect(14, 12, 20, 33, "M", 2)
    for y in range(14, 45, 5):
        cv.rect(14, y, 20, 1, C("M", 2))
    cv.ellipse(24, 12, 10, 6, "A"); cv.rect(22, 3, 4, 4, C("A", 2))
    return fin(cv)


def torre_farol():
    cv = Canvas()
    for y in range(14, 45):
        half = 5 + (y - 14) // 5
        for x in range(24 - half, 24 + half + 1):
            cv.put(x, y, RED if (y // 5) % 2 else WHITE)
    cv.rect(18, 8, 12, 7, DARK); cv.rect(20, 9, 8, 5, GOLD); cv.rect(21, 10, 3, 2, SHINE)
    _tri(cv, 24, 2, 6, 7, RED)
    return fin(cv)


def torre_relogio():
    cv = Canvas()
    cv.blob_rect(14, 14, 20, 31, "P", 2)
    _disc(cv, 24, 20, 6, WHITE); cv.rect(24, 16, 1, 5, DARK); cv.rect(24, 20, 4, 1, DARK)
    _tri(cv, 24, 2, 12, 12, C("A", 1), C("A", 2))
    cv.rect(21, 36, 6, 9, DARK)
    return fin(cv)


def torre_moinho():
    cv = Canvas()
    for y in range(18, 45):
        half = 6 + (y - 18) // 4
        cv.rect(24 - half, y, half * 2 + 1, 1, C("P", 1 if y % 5 else 2))
    _tri(cv, 24, 10, 9, 8, C("A", 1), C("A", 2))
    for a in (45, 135, 225, 315):
        for r in range(2, 16):
            cv.rect(int(24 + math.cos(math.radians(a)) * r), int(16 + math.sin(math.radians(a)) * r), 2, 2, C("W", 1) if r % 3 else WHITE)
    _disc(cv, 24, 16, 2, C("W", 2))
    return fin(cv)


def torre_canhao_duplo():
    cv = Canvas()
    _base_pedra(cv, 30)
    cv.blob_rect(14, 20, 20, 12, "M", 4)
    for x in (16, 27):
        cv.rect(x, 9, 5, 12, C("M", 2)); cv.rect(x + 1, 9, 3, 3, DARK)
    return fin(cv)


# ================================================================ OBJETOS DE DEFESA
def obj_barricada():
    cv = Canvas()
    for i in range(3):
        cv.blob_rect(6 + i * 3, 22 + i * 7, 36 - i * 6, 6, "W", 2)
    for x in (10, 36):
        for i in range(20):
            cv.put(x + (i // 3 if x < 20 else -i // 3), 20 + i, C("W", 2))
    return fin(cv)


def obj_sacos_areia():
    cv = Canvas()
    for row, (y, n) in enumerate(((36, 4), (28, 3), (20, 2))):
        for k in range(n):
            x = 24 - n * 5 + k * 10
            cv.blob_rect(x, y, 10, 8, "P", 3); cv.rect(x + 2, y + 1, 6, 1, C("P", 0))
    return fin(cv)


def obj_cerca_arame():
    cv = Canvas()
    for x in (6, 24, 42):
        cv.rect(x - 1, 18, 2, 27, C("W", 1))
    for y in (22, 30, 38):
        for x in range(5, 44):
            cv.put(x, y + (x % 4 == 0), C("M", 1))
            if x % 6 == 0:
                cv.put(x, y - 1, C("M", 0)); cv.put(x, y + 2, C("M", 0))
    return fin(cv)


def obj_armadilha():
    cv = Canvas()
    cv.ellipse(24, 36, 15, 6, "M")
    for i, x in enumerate(range(11, 38, 4)):
        _tri(cv, x, 26 + (i % 2) * 2, 6, 1, C("M", 0))
    _disc(cv, 24, 36, 3, RED)
    return fin(cv)


def obj_cone():
    cv = Canvas()
    for y in range(14, 42):
        half = 2 + (y - 14) // 3
        cv.rect(24 - half, y, half * 2 + 1, 1, (250, 130, 40, 255) if (y // 6) % 2 == 0 else WHITE)
    cv.rect(12, 41, 25, 3, (230, 110, 30, 255))
    return fin(cv)


def obj_carroca():
    cv = Canvas()
    cv.blob_rect(8, 20, 32, 14, "W", 3)
    for x in range(10, 40, 5):
        cv.rect(x, 21, 1, 12, C("W", 2))
    for x in (14, 34):
        _disc(cv, x, 38, 6, C("W", 2)); _disc(cv, x, 38, 2, C("M", 1))
    cv.rect(39, 28, 8, 2, C("W", 1))
    return fin(cv)


def obj_espigao():
    cv = Canvas()
    cv.rect(6, 40, 36, 4, C("W", 2))
    for x in range(8, 42, 6):
        _tri(cv, x, 22, 18, 2, C("M", 1), C("M", 2))
    return fin(cv)


def obj_tonel_polvora():
    cv = Canvas()
    cv.blob_rect(12, 16, 24, 28, "W", 6)
    for y in (20, 30, 40):
        cv.rect(12, y, 24, 2, C("M", 1))
    cv.rect(18, 25, 12, 4, DARK); cv.rect(19, 26, 10, 2, RED)
    cv.rect(23, 10, 2, 7, (90, 70, 50, 255)); _disc(cv, 24, 9, 2, FIRE)
    return fin(cv)


def obj_estaca():
    cv = Canvas()
    for i, x in enumerate((12, 22, 32)):
        cv.blob_rect(x, 16 + (i % 2) * 6, 5, 29 - (i % 2) * 6, "W", 1); _tri(cv, x + 2, 10 + (i % 2) * 6, 7, 2, C("W", 0))
    cv.rect(8, 34, 32, 2, C("A", 1))
    return fin(cv)


def obj_fardo():
    cv = Canvas()
    cv.blob_rect(8, 20, 32, 24, "K", 4)
    for y in range(22, 44, 3):
        cv.rect(9, y, 30, 1, C("K", 2))
    for x in (17, 30):
        cv.rect(x, 20, 2, 24, C("A", 1))
    return fin(cv)


# ================================================================ PROJÉTEIS (16x16)
def proj_flecha_fogo():
    cv = _p(); cv.rect(2, 7, 10, 2, C("W", 1)); cv.rect(11, 5, 3, 6, FIRE2); cv.rect(13, 6, 2, 4, FIRE); cv.put(15, 7, FIRE)
    cv.rect(0, 6, 2, 4, FIRE); return fin(cv)


def proj_lanca():
    cv = _p(); cv.rect(0, 7, 12, 2, C("W", 1)); _tri(cv, 13, 5, 1, 1, C("M", 0)); cv.rect(12, 6, 3, 4, C("M", 0)); cv.put(15, 7, C("M", 0)); return fin(cv)


def proj_ovo():
    cv = _p(); cv.ellipse(8, 8, 4, 5, "P", shade=False)
    for y in range(3, 14):
        for x in range(3, 13):
            if cv.get(x, y)[3]:
                cv.put(x, y, WHITE if x < 10 else (225, 220, 205, 255))
    return fin(cv)


def proj_tomate():
    cv = _p(); _disc(cv, 8, 9, 5, RED); cv.put(6, 7, SHINE); cv.rect(7, 3, 3, 2, LEAF); return fin(cv)


def proj_garrafa():
    cv = _p(); cv.rect(3, 6, 8, 5, (90, 160, 90, 255)); cv.rect(11, 7, 3, 3, (90, 160, 90, 255)); cv.rect(14, 7, 1, 3, C("W", 1)); cv.rect(4, 7, 2, 1, SHINE)
    return fin(cv)


def proj_bigorna():
    cv = _p(); cv.rect(3, 4, 11, 4, DARK); cv.rect(6, 8, 5, 3, DARK); cv.rect(4, 11, 9, 3, DARK); cv.rect(3, 4, 11, 1, STONE); return fin(cv)


def proj_nota():
    cv = _p(); _disc(cv, 6, 11, 3, DARK); cv.rect(8, 2, 1, 9, DARK); cv.rect(8, 2, 5, 2, DARK); return fin(cv)


def proj_bola_raio():
    cv = _p(); _disc(cv, 8, 8, 5, ELEC); _disc(cv, 8, 8, 2.5, WHITE)
    for x, y in ((1, 5), (14, 11), (3, 13), (13, 2)):
        cv.put(x, y, ELEC)
    return fin(cv)


def proj_folha():
    cv = _p(); cv.ellipse(8, 8, 6, 3, "S", shade=False)
    for y in range(4, 12):
        for x in range(1, 15):
            if cv.get(x, y)[3]:
                cv.put(x, y, LEAF if y < 8 else LEAF2)
    cv.rect(2, 8, 12, 1, LEAF2); return fin(cv)


def proj_moeda():
    cv = _p(); _disc(cv, 8, 8, 5, GOLD); _disc(cv, 8, 8, 3, GOLD2); cv.put(6, 6, SHINE); return fin(cv)


MEGA3 = {
    "bracos": {"robo": bracos_robo, "garras_osso": bracos_garras, "tentaculos": bracos_tentaculos, "musculosos": bracos_musculosos,
               "ombreiras": bracos_ombreiras, "magrelos": bracos_magrelos, "luvas_boxe_grandes": bracos_luvas_boxe, "gancho": bracos_gancho,
               "galhos": bracos_galhos, "ossos": bracos_ossos},
    "pernas": {"sandalia": pernas_sandalia, "botas_altas": pernas_botas_altas, "saia": pernas_saia, "tentaculos_polvo": pernas_tentaculos,
               "esteira_tanque": pernas_esteira, "molas_metal": pernas_mola, "perna_de_pau_pirata": pernas_pau, "patins": pernas_patins,
               "raizes": pernas_raizes, "nuvem": pernas_nuvem},
    "corpo": {"vestido_rodado": corpo_vestido, "terno_gravata": corpo_terno, "colete_couro": corpo_colete, "jaleco_branco": corpo_jaleco, "tunica_mago": corpo_tunica_mago,
              "couraca_ouro": corpo_couraca, "esqueleto": corpo_esqueleto, "robo": corpo_robo, "casco_tartaruga": corpo_casco,
              "folhagem": corpo_folhas, "gelo": corpo_gelo, "avental_cozinha": corpo_avental},
    "costas": {"aljava_flechas": costas_aljava, "escudo_costas": costas_escudo, "bandeira": costas_bandeira, "asas_penas_brancas": costas_asas_anjo,
               "asas_libelula": costas_asas_inseto, "tanque_agua": costas_tanque, "lenha": costas_lenha, "capa_rasgada": costas_capa_rasgada,
               "espada_costas": costas_espada, "sombrinha": costas_guarda_chuva},
    "chapeu": {"elmo_viking": chap_viking, "cartola_fita": chap_cartola, "boina_artista": chap_boina, "pirata": chap_pirata, "aureola_ouro": chap_aureola,
               "chifres_curvos": chap_chifres, "tiara_flores": chap_tiara_flores, "capacete_obra": chap_capacete_obra},
    "arma": {"estilingue_mao": arma_estilingue, "arco_curvo": arma_arco, "lanca": arma_lanca, "tridente_mar": arma_tridente, "varinha_estrela": arma_varinha,
             "escudo_redondo": arma_escudo, "chicote": arma_chicote, "guarda_chuva": arma_guarda_chuva, "concha": arma_concha, "sino": arma_sino},
    "torre": {"torre_arqueiro": torre_arqueiro, "torre_pedra": torre_pedra, "cerca_espinhos": torre_cerca_espinhos, "muralha_madeira": torre_muralha_madeira,
              "muralha_pedra": torre_muralha_pedra, "canhao_naval": torre_canhao_naval, "balista": torre_balista, "catapulta": torre_catapulta,
              "torre_gelo": torre_gelo, "totem": torre_totem, "poco": torre_poco, "silo": torre_silo, "farol_listrado": torre_farol,
              "torre_relogio": torre_relogio, "moinho_pequeno": torre_moinho, "canhao_duplo": torre_canhao_duplo},
    "objeto": {"barricada": obj_barricada, "sacos_areia": obj_sacos_areia, "cerca_arame": obj_cerca_arame, "armadilha_dente": obj_armadilha,
               "cone": obj_cone, "carroca_madeira": obj_carroca, "espigao": obj_espigao, "tonel_polvora": obj_tonel_polvora, "estacas": obj_estaca,
               "fardo_feno": obj_fardo},
    "proj": {"flecha_fogo": proj_flecha_fogo, "lanca_voando": proj_lanca, "ovo_voando": proj_ovo, "tomate": proj_tomate, "garrafa": proj_garrafa,
             "bigorna": proj_bigorna, "nota_musical": proj_nota, "bola_raio": proj_bola_raio, "folha_voando": proj_folha, "moeda_voando": proj_moeda},
}

TEMAS_MEGA3 = {
    "Guerra": ["ombreiras", "botas_altas", "couraca_ouro", "aljava_flechas", "escudo_costas", "bandeira", "espada_costas", "elmo_viking", "capacete_obra",
               "arco_curvo", "lanca", "escudo_redondo", "torre_arqueiro", "torre_pedra", "cerca_espinhos", "muralha_madeira", "muralha_pedra", "balista",
               "catapulta", "canhao_duplo", "barricada", "sacos_areia", "cerca_arame", "espigao", "tonel_polvora", "estacas", "flecha_fogo", "lanca_voando"],
    "ET e máquina": ["robo", "esteira_tanque", "molas_metal", "patins", "jaleco_branco", "tanque_agua", "bola_raio", "cone", "torre_relogio", "farol_listrado"],
    "Mitologia": ["garras_osso", "ossos", "nuvem", "tunica_mago", "esqueleto", "asas_penas_brancas", "capa_rasgada", "aureola_ouro", "chifres_curvos", "varinha_estrela", "totem", "torre_gelo", "gelo"],
    "Oceano": ["tentaculos", "gancho", "tentaculos_polvo", "casco_tartaruga", "pirata", "tridente_mar", "canhao_naval", "farol_listrado"],
    "Comida": ["avental_cozinha", "concha", "ovo_voando", "tomate", "garrafa"],
}
