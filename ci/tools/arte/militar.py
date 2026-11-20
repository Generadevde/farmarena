"""Peças de GUERRA E MÁQUINA (versão 116): veículos, defesas, ícones, capacetes e armas,
no clima dos jogos de estratégia dos anos 2000 (tanque, bobina elétrica, torre de
prisma, radar, dirigível). Desenhos próprios, no mesmo esquema de cores-modelo."""
from kit import *

GLASS = (170, 220, 240, 255)
GLOW = (190, 240, 255, 255)
FIRE = (255, 200, 80, 255)


def fin(cv):
    cv.outline()
    return cv


def _esteira(cv, x, y, w, h=7):
    cv.blob_rect(x, y, w, h, "M", 3)
    for xx in range(x + 3, x + w - 2, 5):
        cv.rect(xx, y + 2, 3, 3, C("M", 2))
        cv.put(xx + 1, y + 3, C("M", 0))


def _roda(cv, cx, cy, r=5):
    cv.ellipse(cx, cy, r, r, "M")
    cv.ellipse(cx, cy, r * 0.45, r * 0.45, "K", shade=False)


# ------------------------------------------------------------ veículos (objeto)
def obj_tanque():
    cv = Canvas()
    _esteira(cv, 5, 33, 38, 9)
    cv.blob_rect(8, 24, 32, 11, "A", 2)
    cv.blob_rect(15, 14, 18, 11, "A", 3)
    cv.rect(17, 16, 5, 3, C("A", 0))
    cv.rect(31, 17, 15, 4, C("M", 1)); cv.rect(31, 17, 15, 1, C("M", 0))
    cv.rect(44, 16, 3, 6, C("M", 2))
    cv.rect(22, 11, 4, 3, C("M", 1))
    cv.rect(10, 27, 6, 2, C("K", 0))
    return fin(cv)


def obj_tanque_duplo():
    cv = Canvas()
    _esteira(cv, 3, 34, 42, 10)
    cv.blob_rect(5, 23, 38, 13, "A", 2)
    cv.blob_rect(12, 11, 22, 13, "A", 3)
    for y in (13, 19):
        cv.rect(32, y, 15, 3, C("M", 1)); cv.rect(32, y, 15, 1, C("M", 0)); cv.rect(45, y - 1, 2, 5, C("M", 2))
    cv.rect(14, 13, 6, 3, C("A", 0))
    cv.rect(20, 7, 3, 5, C("M", 1)); cv.put(21, 6, (255, 80, 80, 255))
    cv.rect(8, 27, 8, 2, C("K", 0)); cv.rect(8, 31, 8, 1, C("A", 2))
    return fin(cv)


def obj_jipe():
    cv = Canvas()
    cv.blob_rect(6, 24, 36, 10, "A", 2)
    cv.blob_rect(16, 15, 16, 10, "A", 2)
    cv.rect(18, 17, 12, 6, GLASS); cv.rect(18, 17, 4, 2, SHINE)
    cv.rect(30, 12, 2, 6, C("M", 1)); cv.rect(30, 11, 10, 2, C("M", 1)); cv.rect(39, 10, 2, 4, C("M", 2))
    cv.rect(39, 27, 3, 3, (255, 240, 150, 255))
    _roda(cv, 14, 36, 6); _roda(cv, 34, 36, 6)
    return fin(cv)


def obj_lanca_missil():
    cv = Canvas()
    _esteira(cv, 5, 35, 38, 8)
    cv.blob_rect(7, 27, 34, 9, "A", 2)
    cv.blob_rect(8, 21, 12, 7, "A", 2); cv.rect(10, 23, 7, 3, GLASS)
    for i, x in enumerate((20, 26, 32)):                 # três tubos inclinados
        for k in range(14):
            cv.rect(x + k // 2, 24 - k, 4, 1, C("M", 1 if k % 4 else 2))
        cv.rect(x + 6, 9, 4, 3, C("P", 0)); cv.put(x + 8, 8, C("P", 1))
    return fin(cv)


def obj_artilharia():
    cv = Canvas()
    _roda(cv, 12, 36, 7); _roda(cv, 30, 36, 7)
    cv.blob_rect(8, 28, 28, 6, "W", 2)
    for k in range(22):                                    # cano comprido subindo
        cv.rect(16 + k, 26 - k // 2, 3, 4, C("M", 1)); cv.put(16 + k, 26 - k // 2, C("M", 0))
    cv.rect(37, 13, 4, 6, C("M", 2))
    cv.blob_rect(12, 22, 10, 8, "A", 2)
    cv.line(4, 44, 10, 34, C("W", 2))
    return fin(cv)


def obj_helicoptero():
    cv = Canvas()
    cv.rect(4, 8, 40, 2, C("M", 0)); cv.rect(4, 9, 40, 1, C("M", 2))
    cv.rect(23, 9, 2, 5, C("M", 1))
    cv.ellipse(20, 22, 13, 9, "A")
    cv.ellipse(15, 21, 6, 5, "M", shade=False)
    cv.rect(11, 18, 8, 6, GLASS); cv.rect(11, 18, 3, 2, SHINE)
    cv.rect(30, 20, 14, 4, C("A", 1)); cv.rect(30, 20, 14, 1, C("A", 0))
    cv.rect(42, 14, 3, 10, C("A", 2)); cv.rect(40, 13, 7, 2, C("M", 1))
    cv.rect(12, 33, 18, 2, C("M", 1)); cv.rect(15, 30, 2, 4, C("M", 2)); cv.rect(25, 30, 2, 4, C("M", 2))
    cv.rect(22, 26, 8, 3, C("M", 2))
    return fin(cv)


def obj_dirigivel():
    cv = Canvas()
    cv.ellipse(24, 16, 21, 11, "A")
    for x in (10, 18, 30, 38):
        cv.line(x, 8, x, 24, C("A", 2))
    cv.rect(2, 12, 4, 8, C("P", 1)); cv.rect(1, 10, 3, 3, C("P", 0)); cv.rect(1, 19, 3, 3, C("P", 2))
    cv.blob_rect(16, 28, 16, 7, "M", 2)
    for x in (18, 22, 26):
        cv.rect(x, 30, 2, 2, GLASS)
    cv.line(18, 26, 18, 28, C("M", 2)); cv.line(29, 26, 29, 28, C("M", 2))
    cv.rect(22, 36, 4, 5, PUPIL); cv.rect(23, 41, 2, 2, C("P", 0))      # bomba pendurada
    return fin(cv)


def obj_andador():
    """máquina de duas pernas"""
    cv = Canvas()
    cv.blob_rect(12, 8, 24, 16, "A", 4)
    cv.rect(16, 12, 16, 5, GLASS); cv.rect(16, 12, 5, 2, SHINE)
    cv.rect(34, 14, 12, 4, C("M", 1)); cv.rect(44, 13, 3, 6, C("M", 2))
    cv.rect(4, 15, 9, 3, C("M", 1)); cv.rect(2, 13, 3, 7, C("M", 2))
    for x in (15, 30):
        cv.rect(x, 24, 4, 9, C("M", 1)); cv.rect(x - 2, 32, 4, 9, C("M", 2)); cv.blob_rect(x - 5, 40, 11, 5, "M", 2)
    cv.rect(21, 20, 6, 3, C("K", 0))
    return fin(cv)


def obj_submarino():
    cv = Canvas()
    cv.ellipse(24, 28, 21, 9, "A")
    cv.blob_rect(18, 12, 12, 10, "A", 2)
    cv.rect(23, 4, 2, 9, C("M", 1)); cv.rect(23, 4, 6, 2, C("M", 1))
    for x in (12, 20, 28, 36):
        cv.ellipse(x, 28, 2.5, 2.5, "K", shade=False); cv.put(x - 1, 27, SHINE)
    cv.rect(44, 24, 3, 9, C("M", 2))
    cv.rect(3, 36, 42, 1, GLOW)
    return fin(cv)


def obj_caminhao():
    cv = Canvas()
    cv.blob_rect(4, 14, 26, 20, "S", 2)
    for x in (10, 17, 24):
        cv.line(x, 15, x, 33, C("S", 2))
    cv.blob_rect(30, 20, 13, 14, "A", 2)
    cv.rect(33, 22, 8, 6, GLASS); cv.rect(33, 22, 3, 2, SHINE)
    cv.rect(41, 30, 3, 3, (255, 240, 150, 255))
    _roda(cv, 12, 37, 6); _roda(cv, 24, 37, 6); _roda(cv, 37, 37, 6)
    return fin(cv)


# ------------------------------------------------------------ defesas e prédios (torre)
def torre_bobina():
    """bobina elétrica"""
    cv = Canvas()
    cv.blob_rect(10, 36, 28, 9, "M", 2)
    cv.rect(21, 12, 6, 25, C("M", 1)); cv.rect(21, 12, 2, 25, C("M", 0))
    for i, y in enumerate((30, 24, 18)):
        w = 22 - i * 5
        cv.ellipse(24, y, w / 2, 2.5, "A")
    cv.ellipse(24, 8, 6, 6, "K")
    cv.put(22, 6, SHINE); cv.put(23, 5, SHINE)
    for (x0, y0), (x1, y1) in (((30, 6), (36, 2)), ((36, 2), (39, 7)), ((18, 6), (12, 3)), ((12, 3), (9, 9))):
        cv.line(x0, y0, x1, y1, GLOW)
    return fin(cv)


def torre_prisma():
    cv = Canvas()
    cv.blob_rect(12, 36, 24, 9, "M", 2)
    cv.rect(16, 22, 3, 15, C("M", 1)); cv.rect(29, 22, 3, 15, C("M", 1))
    cv.rect(22, 26, 4, 11, C("M", 2))
    for i in range(12):                                    # cristal: losango
        half = i if i < 6 else 11 - i
        y = 4 + i * 1.6
        for x in range(24 - half - 1, 24 + half + 2):
            cv.put(x, int(y), C("S", 0 if x < 23 else (1 if x < 26 else 2)))
            cv.put(x, int(y) + 1, C("S", 0 if x < 23 else (1 if x < 26 else 2)))
    cv.put(22, 9, SHINE); cv.put(21, 10, SHINE)
    cv.line(34, 10, 44, 4, GLOW); cv.line(35, 11, 45, 5, SHINE)
    return fin(cv)


def torre_bunker():
    cv = Canvas()
    cv.ellipse(24, 30, 20, 13, "M")
    cv.rect(4, 31, 40, 14, C("M", 1)); cv.rect(4, 31, 40, 2, C("M", 0)); cv.rect(4, 42, 40, 3, C("M", 2))
    cv.rect(12, 28, 24, 5, PUPIL)
    cv.rect(20, 29, 16, 2, C("A", 1)); cv.rect(34, 29, 6, 2, C("M", 2))
    for x in (8, 16, 30, 38):
        cv.blob_rect(x - 2, 38, 7, 5, "K", 2)
    return fin(cv)


def torre_radar():
    cv = Canvas()
    cv.blob_rect(8, 30, 32, 15, "A", 2)
    cv.rect(12, 34, 6, 6, GLASS); cv.rect(22, 34, 6, 11, C("W", 2)); cv.rect(31, 34, 6, 6, GLASS)
    cv.rect(23, 18, 3, 13, C("M", 1))
    for i in range(14):                                    # prato inclinado
        y = 4 + i
        x0 = 14 + i // 2
        cv.rect(x0, y, 20 - i, 1, C("M", 0 if i < 5 else (1 if i < 10 else 2)))
    cv.line(24, 10, 34, 3, C("M", 2)); cv.ellipse(35, 3, 2, 2, "P", shade=False)
    for r in (4, 7):
        cv.put(38 + r, 3, GLOW); cv.put(37 + r, 1, GLOW); cv.put(37 + r, 5, GLOW)
    return fin(cv)


def torre_usina():
    cv = Canvas()
    cv.blob_rect(6, 26, 36, 19, "A", 2)
    for x in (12, 26):
        for i in range(18):
            w = 10 - (2 if 5 < i < 13 else 0)
            cv.rect(x + (10 - w) // 2, 8 + i, w, 1, C("M", 0 if i % 6 == 0 else 1))
        cv.ellipse(x + 5, 5, 6, 3.5, "M", shade=False)
    cv.rect(10, 32, 28, 3, C("K", 0))
    for x in range(10, 38, 6):
        cv.rect(x, 32, 3, 3, PUPIL)
    cv.rect(20, 37, 8, 8, C("W", 2))
    cv.line(22, 39, 25, 41, FIRE); cv.line(25, 41, 22, 43, FIRE)
    return fin(cv)


def torre_refinaria():
    cv = Canvas()
    cv.blob_rect(4, 30, 22, 15, "A", 2)
    cv.ellipse(34, 30, 10, 14, "M")
    cv.rect(24, 30, 20, 15, C("M", 1)); cv.rect(24, 30, 3, 15, C("M", 0)); cv.rect(40, 30, 4, 15, C("M", 2))
    cv.rect(26, 34, 16, 2, C("K", 1)); cv.rect(26, 40, 16, 2, C("K", 1))
    cv.rect(8, 12, 5, 19, C("M", 1)); cv.rect(8, 12, 2, 19, C("M", 0))
    cv.ellipse(10, 8, 4, 4, "P", shade=False); cv.ellipse(11, 5, 2, 2, "K", shade=False)
    cv.rect(13, 22, 14, 3, C("M", 2))
    cv.rect(8, 36, 6, 9, C("W", 2)); cv.rect(17, 34, 5, 5, GLASS)
    return fin(cv)


def torre_quartel():
    cv = Canvas()
    cv.blob_rect(5, 22, 38, 23, "S", 2)
    for i in range(8):
        cv.rect(3 + i, 22 - i, 42 - i * 2, 1, C("S", 0 if i < 3 else 2))
    cv.rect(19, 30, 10, 15, C("W", 2)); cv.rect(23, 30, 1, 15, PUPIL)
    cv.rect(9, 28, 6, 5, GLASS); cv.rect(33, 28, 6, 5, GLASS)
    cv.rect(23, 2, 1, 13, C("M", 1))
    cv.rect(24, 3, 10, 6, C("P", 1)); cv.rect(24, 3, 10, 2, C("P", 0))
    cv.rect(27, 5, 3, 2, C("K", 0))
    return fin(cv)


def torre_canhao_grande():
    cv = Canvas()
    cv.blob_rect(8, 34, 32, 11, "M", 2)
    for x in range(11, 38, 6):
        cv.rect(x, 37, 2, 2, C("M", 2))
    cv.ellipse(22, 26, 12, 10, "A")
    for k in range(20):
        cv.rect(26 + k, 20 - k // 2, 3, 5, C("M", 1)); cv.put(26 + k, 20 - k // 2, C("M", 0))
    cv.rect(44, 8, 3, 8, C("M", 2))
    cv.rect(15, 21, 6, 3, C("A", 0))
    return fin(cv)


# ------------------------------------------------------------ ícones de feitiço
def ico_missil():
    cv = Canvas()
    for k in range(24):
        cv.rect(12 + k, 30 - k, 6, 6, C("M", 0 if k % 8 < 3 else 1))
    cv.rect(36, 5, 7, 7, C("P", 1)); cv.rect(40, 3, 5, 5, C("P", 0)); cv.put(45, 2, C("P", 0))
    cv.rect(8, 30, 6, 6, C("P", 2)); cv.rect(15, 36, 5, 5, C("P", 2))
    for i in range(7):
        cv.rect(3 + i, 38 + i // 2, 4, 3, FIRE if i > 2 else (255, 120, 60, 255))
    return fin(cv)


def ico_bomba():
    cv = Canvas()
    cv.ellipse(22, 28, 14, 14, "M")
    cv.put(16, 21, SHINE); cv.put(17, 20, SHINE); cv.put(15, 22, SHINE)
    cv.rect(28, 11, 6, 6, C("M", 2))
    cv.line(33, 11, 38, 6, C("W", 1)); cv.line(38, 6, 41, 8, C("W", 1))
    cv.ellipse(42, 7, 3, 3, "K", shade=False); cv.put(42, 3, FIRE); cv.put(45, 6, FIRE); cv.put(44, 10, FIRE)
    return fin(cv)


def ico_paraquedas():
    cv = Canvas()
    cv.ellipse(24, 16, 19, 13, "S")
    cv.rect(4, 17, 40, 14, (0, 0, 0, 0))
    for x in (11, 24, 37):
        cv.line(x, 6, x, 16, C("S", 2))
    for x in (6, 15, 24, 33, 42):
        cv.line(x, 17, 24, 36, EYE_W)
    cv.blob_rect(19, 35, 10, 9, "W", 1)
    cv.rect(19, 39, 10, 1, C("W", 2)); cv.rect(23, 35, 2, 9, C("W", 2))
    return fin(cv)


def ico_mira():
    cv = Canvas()
    for r in (17, 16):
        for a in range(360):
            import math
            cv.put(int(24 + r * math.cos(math.radians(a))), int(24 + r * math.sin(math.radians(a))), C("P", 1))
    for r in (9,):
        for a in range(360):
            import math
            cv.put(int(24 + r * math.cos(math.radians(a))), int(24 + r * math.sin(math.radians(a))), C("P", 0))
    cv.rect(23, 2, 2, 14, C("P", 1)); cv.rect(23, 32, 2, 14, C("P", 1))
    cv.rect(2, 23, 14, 2, C("P", 1)); cv.rect(32, 23, 14, 2, C("P", 1))
    cv.ellipse(24, 24, 2.5, 2.5, "K", shade=False)
    return fin(cv)


def ico_engrenagem():
    cv = Canvas()
    import math
    for a in range(0, 360, 45):
        x = 24 + 17 * math.cos(math.radians(a)); y = 24 + 17 * math.sin(math.radians(a))
        cv.rect(int(x) - 3, int(y) - 3, 7, 7, C("M", 1))
    cv.ellipse(24, 24, 15, 15, "M")
    cv.ellipse(24, 24, 6, 6, "W", shade=False)
    cv.ellipse(24, 24, 3, 3, "K", shade=False)
    return fin(cv)


def ico_estrela():
    cv = Canvas()
    import math
    pts = []
    for i in range(10):
        r = 20 if i % 2 == 0 else 8
        a = math.radians(-90 + i * 36)
        pts.append((24 + r * math.cos(a), 25 + r * math.sin(a)))
    for y in range(48):
        for x in range(48):
            inside = False
            j = len(pts) - 1
            for i in range(len(pts)):
                xi, yi = pts[i]; xj, yj = pts[j]
                if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
                    inside = not inside
                j = i
            if inside:
                cv.put(x, y, C("K", 0 if x + y < 44 else (1 if x + y < 54 else 2)))
    cv.put(20, 17, SHINE); cv.put(21, 16, SHINE)
    return fin(cv)


def ico_onda():
    """pulso de radar / choque"""
    cv = Canvas()
    import math
    for r, tone in ((20, 2), (14, 1), (8, 0)):
        for a in range(-70, 71):
            for d in (0, 1):
                cv.put(int(8 + (r + d) * math.cos(math.radians(a))), int(24 + (r + d) * math.sin(math.radians(a))), C("S", tone))
    cv.ellipse(8, 24, 4, 4, "K", shade=False)
    for x in (34, 38, 42):
        cv.put(x, 24, GLOW)
    return fin(cv)


def ico_relogio():
    cv = Canvas()
    cv.ellipse(24, 27, 17, 17, "M")
    cv.ellipse(24, 27, 13, 13, "K", shade=False)
    cv.rect(21, 4, 6, 5, C("M", 1)); cv.rect(19, 2, 10, 3, C("M", 2))
    cv.line(24, 27, 24, 17, PUPIL); cv.line(24, 27, 31, 30, PUPIL); cv.line(25, 27, 25, 17, PUPIL)
    for a in (0, 90, 180, 270):
        import math
        cv.rect(int(24 + 11 * math.cos(math.radians(a))) - 1, int(27 + 11 * math.sin(math.radians(a))) - 1, 2, 2, PUPIL)
    return fin(cv)


# ------------------------------------------------------------ capacetes e armas (encaixam no personagem)
def chap_capacete():
    cv = Canvas()
    cv.ellipse(24, 8, 12, 7, "S")
    cv.rect(11, 8, 26, 3, C("S", 2))
    cv.rect(11, 10, 26, 1, PUPIL)
    cv.rect(22, 3, 4, 3, C("K", 0))
    return fin(cv)


def chap_boina():
    cv = Canvas()
    cv.ellipse(22, 6, 13, 5, "P")
    cv.rect(13, 9, 20, 2, C("P", 2))
    cv.ellipse(31, 5, 2, 2, "K", shade=False)
    cv.rect(9, 3, 2, 3, C("P", 1))
    return fin(cv)


def chap_quepe():
    cv = Canvas()
    cv.blob_rect(14, 1, 20, 7, "A", 2)
    cv.rect(13, 7, 22, 2, C("K", 1))
    cv.blob_rect(18, 9, 16, 3, "M", 1)
    cv.rect(22, 3, 4, 3, C("K", 0))
    return fin(cv)


def arma_fuzil():
    cv = Canvas()
    cv.blob_rect(35, 28, 7, 9, "W", 2)
    cv.rect(37, 8, 3, 21, C("M", 1)); cv.rect(37, 8, 1, 21, C("M", 0))
    cv.rect(36, 20, 6, 4, C("M", 2)); cv.rect(41, 22, 3, 6, C("M", 2))
    cv.rect(38, 4, 1, 4, C("M", 0))
    return fin(cv)


def arma_bazuca():
    cv = Canvas()
    cv.rect(34, 6, 7, 30, C("S", 1)); cv.rect(34, 6, 2, 30, C("S", 0)); cv.rect(39, 6, 2, 30, C("S", 2))
    cv.rect(33, 4, 9, 3, C("M", 2)); cv.rect(33, 34, 9, 3, C("M", 2))
    cv.rect(41, 20, 4, 7, C("W", 1))
    cv.rect(36, 1, 3, 3, C("P", 0))
    return fin(cv)


def arma_lanca_chamas():
    cv = Canvas()
    cv.blob_rect(34, 24, 9, 14, "P", 3)
    cv.rect(37, 10, 3, 15, C("M", 1)); cv.rect(37, 10, 1, 15, C("M", 0))
    cv.rect(36, 8, 5, 3, C("M", 2))
    cv.ellipse(38, 5, 3, 3.5, "K", shade=False); cv.put(38, 1, FIRE); cv.put(37, 3, (255, 120, 60, 255))
    return fin(cv)


# ------------------------------------------------------------ projéteis (16x16, apontando pra direita)
def proj_missil():
    cv = Canvas(16, 16)
    cv.rect(4, 6, 8, 4, C("M", 1)); cv.rect(4, 6, 8, 1, C("M", 0))
    cv.rect(12, 7, 2, 2, C("P", 1)); cv.put(14, 7, C("P", 0)); cv.put(14, 8, C("P", 0))
    cv.rect(3, 4, 2, 2, C("P", 2)); cv.rect(3, 10, 2, 2, C("P", 2))
    cv.put(2, 7, FIRE); cv.put(1, 8, FIRE); cv.put(2, 8, (255, 120, 60, 255))
    return fin(cv)


def proj_bala():
    cv = Canvas(16, 16)
    cv.rect(5, 7, 6, 2, C("K", 1)); cv.rect(11, 7, 2, 2, C("K", 0)); cv.rect(3, 7, 2, 2, C("M", 2))
    return fin(cv)


def proj_laser():
    cv = Canvas(16, 16)
    cv.rect(1, 7, 14, 2, C("S", 0)); cv.rect(2, 6, 12, 1, C("S", 1)); cv.rect(2, 9, 12, 1, C("S", 1))
    cv.rect(13, 7, 2, 2, SHINE)
    return fin(cv)


MILITAR = {
    "objeto": {"tanque": obj_tanque, "tanque_duplo": obj_tanque_duplo, "jipe": obj_jipe, "lanca_missil": obj_lanca_missil,
               "artilharia": obj_artilharia, "helicoptero": obj_helicoptero, "dirigivel": obj_dirigivel, "andador": obj_andador,
               "submarino": obj_submarino, "caminhao": obj_caminhao},
    "torre": {"bobina": torre_bobina, "prisma": torre_prisma, "bunker": torre_bunker, "radar": torre_radar, "usina": torre_usina,
              "refinaria": torre_refinaria, "quartel": torre_quartel, "canhao_grande": torre_canhao_grande},
    "icone": {"missil": ico_missil, "bomba": ico_bomba, "paraquedas": ico_paraquedas, "mira": ico_mira, "engrenagem": ico_engrenagem,
              "estrela": ico_estrela, "onda": ico_onda, "relogio": ico_relogio},
    "chapeu": {"capacete": chap_capacete, "boina": chap_boina, "quepe": chap_quepe},
    "arma": {"fuzil": arma_fuzil, "bazuca": arma_bazuca, "lanca_chamas": arma_lanca_chamas},
    "proj": {"missil": proj_missil, "bala": proj_bala, "laser": proj_laser},
}
