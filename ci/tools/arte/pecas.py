"""Biblioteca de PEÇAS 48x48 do Farm Arena 2.0.

Todas as peças são desenhadas no MESMO molde (mesmos pontos de encaixe),
cada uma numa camada 48x48 com contorno próprio, em cores-modelo. Montar um
personagem = empilhar camadas nessa ordem:
    costas -> pernas -> corpo -> braços -> cabeça -> chapéu -> arma
O jogo (creator/sprite_forge.gd) empilha e recolore do mesmo jeito.

Molde (personagem de frente, cabeção):
    pés em y=44 · corpo centrado em (24,33) · cabeça centrada em (24,17)
    mão direita (de quem olha) em (37,33) · topo da cabeça em y=7
"""
from kit import *

CXM = 24          # centro x
FEET_Y = 44
BODY = (24, 33)
HEAD = (24, 17)
HAND_R = (37, 33)
HAND_L = (10, 33)


def new():
    return Canvas()


def fin(cv, mirror=False):
    if mirror:
        cv.mirror_left_to_right()
    cv.outline()
    return cv


# ================================================================ PERNAS
def pernas_casco():
    cv = new()
    for x in (17, 27):
        cv.blob_rect(x, 39, 5, 4, "P", 1)
        cv.rect(x, 43, 5, 2, C("M", 2))        # casco escuro
        cv.rect(x, 43, 2, 1, C("M", 1))
    return fin(cv)


def pernas_bota():
    cv = new()
    for x in (17, 27):
        cv.blob_rect(x, 38, 5, 4, "A", 1)      # calça
        cv.rect(x - 1, 42, 7, 3, C("W", 1))    # bota
        cv.rect(x - 1, 42, 3, 1, C("W", 0))
        cv.rect(x - 1, 44, 7, 1, C("W", 2))
    return fin(cv)


def pernas_ave():
    cv = new()
    for x in (19, 28):
        cv.rect(x, 39, 2, 4, C("K", 1))
        cv.rect(x - 2, 43, 6, 2, C("K", 1))
        cv.rect(x - 2, 43, 6, 1, C("K", 0))
        cv.put(x + 1, 40, C("K", 2))
    return fin(cv)


def pernas_patinha():
    """patas curtas e gordinhas (porco, capivara, sapo)"""
    cv = new()
    for x in (16, 27):
        cv.blob_rect(x, 40, 6, 5, "P", 2)
        cv.rect(x, 44, 6, 1, C("P", 2))
    return fin(cv)


def pernas_fantasma():
    """sem pernas: rabinho ondulado flutuando"""
    cv = new()
    for i, x in enumerate(range(15, 34)):
        h = 3 + (1 if (x // 3) % 2 == 0 else -1)
        cv.rect(x, 39, 1, h, C("P", 1 if x < 28 else 2))
    return fin(cv)


def pernas_rodas():
    """rodinhas (trator, carrinho de mão) -- absurdo, mas roça"""
    cv = new()
    for x in (17, 31):
        cv.ellipse(x, 42, 4.5, 4.5, "M")
        cv.put(x, 42, C("M", 0))
        cv.put(x - 1, 42, C("M", 0))
    cv.rect(18, 41, 13, 2, C("W", 2))
    return fin(cv)


def pernas_inseto():
    cv = new()
    for side in (-1, 1):
        for i, dy in enumerate((0, 3)):
            x0 = CXM + side * 7
            cv.line(x0, 37 + dy, x0 + side * 5, 41 + dy, C("M", 2))
            cv.put(x0 + side * 6, 42 + dy, C("M", 2))
    return fin(cv)


# ================================================================ CORPOS
def corpo_redondo():
    cv = new()
    cv.ellipse(24, 33, 9.5, 8.5, "P")
    cv.ellipse(24, 35, 5.5, 5, "K")            # barriga clara
    return fin(cv)


def corpo_macacao():
    """camisa xadrez + macacão jeans (o caipira clássico)"""
    cv = new()
    cv.ellipse(24, 33, 9, 8.5, "S")            # camisa
    for y in range(25, 42):                     # xadrez
        for x in range(15, 34):
            if cv.get(x, y)[3] and (x + y) % 4 == 0:
                cv.put(x, y, C("S", 2))
    cv.blob_rect(18, 31, 13, 10, "A", 2)        # macacão
    cv.rect(18, 26, 2, 6, C("A", 1))            # alças
    cv.rect(29, 26, 2, 6, C("A", 1))
    cv.put(19, 31, C("K", 0))                   # botões
    cv.put(29, 31, C("K", 0))
    cv.rect(22, 34, 5, 3, C("A", 2))            # bolso
    return fin(cv)


def corpo_penas():
    cv = new()
    cv.ellipse(24, 33, 9, 9, "P")
    cv.ellipse(24, 36, 6, 5, "P", shade=False)
    for x, y in ((20, 34), (24, 36), (28, 34), (22, 38), (26, 38)):   # peninhas
        cv.put(x, y, C("P", 2))
        cv.put(x + 1, y + 1, C("P", 2))
    return fin(cv)


def corpo_la():
    """corpo fofo de lã (ovelha) -- bolotas"""
    cv = new()
    for cx, cy, r in ((24, 33, 8), (17, 31, 4.5), (31, 31, 4.5), (18, 37, 4.5), (30, 37, 4.5), (24, 27, 4.5), (24, 39, 4.5)):
        cv.ellipse(cx, cy, r, r, "S")
    return fin(cv)


def corpo_listrado():
    """abelha / vespa"""
    cv = new()
    cv.ellipse(24, 33, 8.5, 8.5, "P")
    for y in (29, 30, 34, 35, 39):
        for x in range(14, 35):
            if cv.get(x, y)[3]:
                cv.put(x, y, C("M", 2))
    return fin(cv)


def corpo_armadura():
    """armadura de lata/balde amassado"""
    cv = new()
    cv.blob_rect(15, 25, 19, 16, "M", 3)
    cv.rect(15, 31, 19, 1, C("M", 2))
    cv.rect(15, 36, 19, 1, C("M", 2))
    for x in (17, 31):
        cv.put(x, 28, C("M", 2))
        cv.put(x, 39, C("M", 2))
    cv.rect(18, 27, 3, 2, C("M", 0))
    return fin(cv)


def corpo_poncho():
    cv = new()
    cv.ellipse(24, 33, 9, 8.5, "P")
    for y in range(25, 38):
        half = 4 + (y - 25)
        for x in range(24 - half, 24 + half + 1):
            if 12 <= x <= 36:
                cv.put(x, y, C("A", 1 if x < 28 else 2))
    for x in range(12, 37, 3):
        cv.put(x, 37, C("K", 0))
        cv.put(x, 38, C("K", 1))
    cv.rect(13, 31, 23, 1, C("K", 1))
    return fin(cv)


def corpo_saco():
    """corpo de espantalho: saco de estopa com palha saindo"""
    cv = new()
    cv.blob_rect(16, 25, 17, 16, "K", 3)
    for x, y in ((18, 28), (22, 30), (27, 27), (30, 33), (20, 36), (26, 38)):
        cv.put(x, y, C("K", 2))
    cv.rect(21, 31, 3, 3, C("A", 1))            # remendo
    cv.put(22, 32, C("A", 2))
    for x in (14, 15, 33, 34):                   # palha nos lados
        cv.put(x, 30, C("K", 0))
        cv.put(x, 36, C("K", 0))
    return fin(cv)


# ================================================================ BRAÇOS
def bracos_patas():
    cv = new()
    for x in (11, 33):
        cv.blob_rect(x, 29, 5, 8, "P", 2)
    return fin(cv)


def bracos_humanos():
    cv = new()
    for x in (11, 33):
        cv.blob_rect(x, 28, 5, 6, "S", 2)       # manga
        cv.blob_rect(x, 33, 5, 4, "K", 2)       # mão
    return fin(cv)


def bracos_asas():
    cv = new()
    for side in (-1, 1):
        cx = CXM + side * 12
        cv.ellipse(cx, 32, 4.5, 6.5, "P")
        for dy in (2, 5):
            cv.put(cx - side, 30 + dy, C("P", 2))
            cv.put(cx, 31 + dy, C("P", 2))
    return fin(cv)


def bracos_asas_inseto():
    """asas transparentes (abelha, mosquito) -- ficam nas COSTAS"""
    cv = new()
    for side in (-1, 1):
        cx = CXM + side * 13
        cv.ellipse(cx, 27, 5.5, 7, "M", shade=False)
        for y in range(20, 35):
            for x in range(cx - 6, cx + 7):
                if cv.get(x, y)[3]:
                    cv.put(x, y, (220, 240, 250, 255) if (x + y) % 3 else (180, 215, 235, 255))
    return fin(cv)


# ================================================================ CABEÇAS
def _cabeca_base(slot="P", rx=11, ry=10, cy=17):
    cv = new()
    cv.ellipse(24, cy, rx, ry, slot)
    return cv


def _olhos(cv, y=15, dx=5, size=3, bravo=False, sono=False):
    for side in (-1, 1):
        x = 24 + side * dx - (size // 2)
        if sono:
            cv.rect(x, y + 1, size, 1, PUPIL)
            continue
        eye(cv, x, y, size)
        if bravo:
            for i in range(size + 1):
                cv.put(x + (i if side == -1 else size - 1 - i) - (1 if side == -1 else -1) + (0), y - 1 - (0 if i < 2 else 1) + (1 if (i >= 2) else 0), OUT)


def cab_vaca():
    cv = _cabeca_base()
    for side in (-1, 1):                           # orelhas de lado
        cv.ellipse(24 + side * 12, 13, 3.5, 2.5, "P")
        cv.put(24 + side * 12, 13, C("K", 1))
        cv.rect(24 + side * 7 - 1, 5, 2, 4, C("M", 0))   # chifrinhos
        cv.put(24 + side * 8 - (1 if side < 0 else 0), 4, C("M", 0))
    cv.ellipse(24, 22, 7.5, 5, "K")                  # focinho
    cv.rect(20, 22, 2, 2, C("K", 2))
    cv.rect(26, 22, 2, 2, C("K", 2))
    for x, y, w, h in ((14, 9, 5, 4), (29, 8, 4, 3), (31, 15, 3, 4)):   # manchas
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                if cv.get(xx, yy)[3] and cv.get(xx, yy)[:3] in [c[:3] for c in (C("P", 0), C("P", 1), C("P", 2))]:
                    cv.put(xx, yy, C("S", 1))
    _olhos(cv, 13, 5, 3)
    return fin(cv)


def cab_boi():
    cv = _cabeca_base(ry=10.5)
    for side in (-1, 1):                           # chifrão
        bx = 24 + side * 9
        cv.rect(bx - 1, 8, 3, 3, C("M", 1))
        cv.rect(bx + side * 2 - 1, 5, 3, 4, C("M", 0))
        cv.rect(bx + side * 3 - 1, 2, 2, 4, C("M", 0))
        cv.put(bx + side * 3, 1, C("M", 0))
    cv.ellipse(24, 22, 8, 5, "K")
    cv.rect(20, 22, 2, 2, C("K", 2))
    cv.rect(26, 22, 2, 2, C("K", 2))
    cv.rect(22, 25, 4, 1, C("M", 0))               # argola no nariz
    cv.put(22, 26, C("M", 0))
    cv.put(25, 26, C("M", 0))
    cv.rect(23, 27, 2, 1, C("M", 1))
    _olhos(cv, 13, 5, 3, bravo=True)
    cv.rect(17, 11, 4, 1, OUT)                      # sobrancelha brava
    cv.rect(27, 11, 4, 1, OUT)
    cv.put(20, 12, OUT)
    cv.put(27, 12, OUT)
    return fin(cv)


def cab_porco():
    cv = _cabeca_base()
    for side in (-1, 1):                            # orelha caída triangular
        for i in range(5):
            cv.rect(24 + side * (7 + i) - (0 if side > 0 else 0), 6 + i, 1 if i == 4 else 2, 2, C("P", 2 if i > 1 else 1))
    cv.ellipse(24, 21, 5.5, 4, "K")                 # focinho
    cv.rect(21, 20, 2, 3, C("K", 2))
    cv.rect(25, 20, 2, 3, C("K", 2))
    _olhos(cv, 13, 5, 3)
    cv.put(16, 19, BLUSH)
    cv.put(31, 19, BLUSH)
    return fin(cv)


def cab_galinha():
    cv = _cabeca_base(rx=9.5, ry=9.5)
    for x, h in ((21, 3), (24, 5), (27, 3)):          # crista
        cv.rect(x - 1, 8 - h - 1, 3, h + 1, C("A", 1))
        cv.put(x - 1, 8 - h - 1, C("A", 0))
    cv.rect(22, 19, 4, 2, C("K", 1))                 # bico
    cv.rect(23, 21, 2, 1, C("K", 2))
    cv.rect(22, 19, 2, 1, C("K", 0))
    cv.rect(23, 22, 2, 3, C("A", 1))                 # barbela
    _olhos(cv, 14, 5, 3)
    return fin(cv)


def cab_pato():
    cv = _cabeca_base(rx=9.5, ry=9.5)
    cv.blob_rect(18, 19, 12, 4, "K", 2)              # bico largo
    cv.put(21, 20, C("K", 2))
    cv.put(26, 20, C("K", 2))
    cv.rect(22, 5, 1, 3, C("P", 0))                  # topete
    cv.rect(24, 4, 1, 4, C("P", 0))
    _olhos(cv, 13, 5, 3)
    return fin(cv)


def cab_ovelha():
    cv = new()
    for cx, cy, r in ((24, 12, 9), (15, 13, 4.5), (33, 13, 4.5), (18, 8, 4.5), (30, 8, 4.5), (24, 6, 4.5)):
        cv.ellipse(cx, cy, r, r, "S")               # lã
    cv.ellipse(24, 19, 7, 7, "K")                    # carinha
    for side in (-1, 1):
        cv.ellipse(24 + side * 10, 18, 3, 2, "K")    # orelhas
    cv.rect(23, 22, 2, 1, C("K", 2))
    cv.put(22, 23, C("K", 2))
    cv.put(25, 23, C("K", 2))
    _olhos(cv, 16, 4, 2)
    return fin(cv)


def cab_bode():
    cv = _cabeca_base(rx=9.5, ry=10)
    for side in (-1, 1):                             # chifres pra trás
        bx = 24 + side * 6
        cv.rect(bx - 1, 4, 2, 5, C("M", 1))
        cv.rect(bx + side * 2 - 1, 2, 2, 4, C("M", 0))
        cv.put(bx + side * 4 - (1 if side < 0 else 0), 3, C("M", 0))
        cv.ellipse(24 + side * 11, 14, 3, 2, "P")
    cv.ellipse(24, 21, 5.5, 4, "K")
    cv.rect(23, 21, 2, 1, C("K", 2))
    cv.rect(23, 26, 2, 4, C("S", 0))                 # barbicha
    cv.put(24, 30, C("S", 1))
    for side in (-1, 1):                             # olho de bode (pupila deitada)
        x = 24 + side * 5 - 1
        cv.rect(x, 13, 3, 3, (250, 220, 90, 255))
        cv.rect(x, 14, 3, 1, PUPIL)
    return fin(cv)


def cab_cavalo():
    cv = new()
    cv.ellipse(24, 14, 9, 9, "P")
    cv.blob_rect(18, 16, 13, 11, "P", 3)             # focinho comprido
    cv.blob_rect(18, 22, 13, 5, "K", 2)
    cv.rect(20, 24, 2, 2, C("K", 2))
    cv.rect(27, 24, 2, 2, C("K", 2))
    for side in (-1, 1):                             # orelhas em pé
        cv.rect(24 + side * 7 - 1, 3, 3, 5, C("P", 1))
        cv.put(24 + side * 7, 2, C("P", 1))
    for y in range(4, 16):                           # crina
        cv.rect(23, y, 3, 1, C("S", 1 if y % 2 else 2))
    _olhos(cv, 12, 6, 3)
    return fin(cv)


def cab_sapo():
    cv = _cabeca_base(rx=11.5, ry=8.5, cy=19)
    for side in (-1, 1):                             # olhões em cima
        cv.ellipse(24 + side * 6, 10, 4.5, 4.5, "P")
        eye(cv, 24 + side * 6 - 1, 8, 3)
    cv.rect(16, 22, 17, 1, C("P", 2))                # bocão
    cv.put(15, 21, C("P", 2))
    cv.put(33, 21, C("P", 2))
    cv.ellipse(24, 25, 6, 2, "K", shade=False)
    return fin(cv)


def cab_capivara():
    cv = new()
    cv.blob_rect(14, 8, 21, 19, "P", 5)              # cabeça quadradona
    for side in (-1, 1):
        cv.rect(24 + side * 8 - 1, 6, 3, 3, C("P", 2))   # orelhinha
    cv.blob_rect(18, 18, 13, 8, "K", 3)              # focinho
    cv.rect(22, 19, 5, 2, C("K", 2))                 # nariz
    cv.rect(24, 21, 1, 3, C("K", 2))
    _olhos(cv, 13, 6, 3, sono=True)                  # olhar de quem não liga
    return fin(cv)


def cab_gato():
    cv = _cabeca_base(rx=10.5, ry=9)
    for side in (-1, 1):                             # orelhas pontudas
        for i in range(5):
            w = 1 + i
            x0 = 24 + side * 8 - (w // 2)
            cv.rect(x0, 3 + i, w + 1, 1, C("P", 1 if side < 0 else 2))
        cv.put(24 + side * 8, 6, C("K", 1))
        cv.put(24 + side * 8, 7, C("K", 1))
    cv.put(24, 19, C("K", 2))                        # nariz
    cv.put(23, 20, OUT)
    cv.put(25, 20, OUT)
    for side in (-1, 1):                             # bigodes
        cv.rect(24 + side * 9 - (2 if side < 0 else 0), 19, 3, 1, EYE_W)
    for side in (-1, 1):
        x = 24 + side * 5 - 1
        cv.rect(x, 13, 3, 3, (160, 220, 90, 255))
        cv.rect(x + 1, 13, 1, 3, PUPIL)
    return fin(cv)


def cab_coruja():
    cv = _cabeca_base(rx=10.5, ry=10)
    for side in (-1, 1):
        cv.rect(24 + side * 8 - 1, 4, 3, 4, C("P", 2))   # tufos
        cv.ellipse(24 + side * 5, 15, 4.5, 4.5, "K")     # disco dos olhos
        eye(cv, 24 + side * 5 - 1, 14, 3)
    cv.rect(23, 18, 2, 3, C("M", 0))                     # bico
    return fin(cv)


def cab_abelha():
    cv = _cabeca_base(rx=9.5, ry=9)
    for side in (-1, 1):                              # antenas
        cv.line(24 + side * 3, 8, 24 + side * 6, 3, OUT)
        cv.rect(24 + side * 6 - 1, 2, 2, 2, C("M", 2))
        cv.ellipse(24 + side * 5, 15, 3.5, 4, "M", shade=False)   # olhão
        cv.put(24 + side * 5 - 1, 13, SHINE)
    cv.rect(22, 21, 5, 1, OUT)                         # sorrisinho
    return fin(cv)


def cab_humano():
    cv = _cabeca_base(slot="K", rx=10, ry=9.5)
    for x in range(14, 35):                            # cabelo
        for y in range(6, 12):
            if cv.get(x, y)[3] and y < 10 + (1 if 18 < x < 30 else 2):
                cv.put(x, y, C("S", 1 if x < 28 else 2))
    cv.rect(23, 19, 2, 2, C("K", 2))                   # nariz
    cv.rect(21, 23, 6, 1, OUT)                          # boca
    cv.put(17, 20, BLUSH)
    cv.put(30, 20, BLUSH)
    _olhos(cv, 14, 5, 3)
    return fin(cv)


def cab_velho():
    cv = _cabeca_base(slot="K", rx=10, ry=9.5)
    for y in range(19, 28):                             # barbona branca
        half = max(1, 9 - (y - 19))
        cv.rect(24 - half, y, half * 2 + 1, 1, EYE_W)
    cv.rect(18, 20, 13, 2, (225, 225, 220, 255))        # bigode
    cv.rect(23, 18, 2, 2, C("K", 2))
    cv.rect(18, 12, 4, 1, EYE_W)                        # sobrancelhas
    cv.rect(27, 12, 4, 1, EYE_W)
    _olhos(cv, 14, 5, 2)
    return fin(cv)


def cab_espantalho():
    cv = _cabeca_base(slot="K", rx=10, ry=9.5)
    for side in (-1, 1):                                 # olhos de botão
        cv.rect(24 + side * 5 - 1, 13, 3, 3, PUPIL)
        cv.put(24 + side * 5, 14, C("K", 0))
    cv.rect(23, 18, 2, 2, C("A", 1))                     # nariz de pano
    for x in range(18, 31):                              # boca costurada
        cv.put(x, 22, OUT)
        if x % 3 == 0:
            cv.put(x, 21, OUT)
            cv.put(x, 23, OUT)
    for x in (13, 14, 34, 35):                           # palha
        cv.put(x, 18, C("K", 0))
        cv.put(x, 21, C("K", 0))
    return fin(cv)


def cab_abobora():
    cv = _cabeca_base(slot="P", rx=11.5, ry=9.5, cy=18)
    for x in (17, 21, 27, 31):                           # gomos
        for y in range(10, 27):
            if cv.get(x, y)[3]:
                cv.put(x, y, C("P", 2))
    cv.rect(23, 6, 3, 4, C("W", 2))                      # cabinho
    cv.put(26, 6, C("S", 1))
    cv.put(27, 5, C("S", 1))
    for side in (-1, 1):                                 # olhos triangulares
        for i in range(3):
            cv.rect(24 + side * 5 - i, 15 + i - 2, 1 + i * 2, 1, (255, 230, 120, 255))
    for x in range(18, 31):                              # boca serrilhada
        cv.put(x, 22 + (x % 2), (255, 230, 120, 255))
        cv.put(x, 23, (255, 230, 120, 255))
    return fin(cv)


def cab_milho():
    cv = new()
    cv.blob_rect(17, 4, 15, 23, "P", 5)                  # espiga
    for y in range(6, 26, 3):
        for x in range(18, 31, 3):
            cv.put(x, y, C("P", 2))
            cv.put(x + 1, y + 1, C("P", 0))
    for side in (-1, 1):                                 # palha aberta
        for i in range(8):
            cv.rect(24 + side * (8 + i // 3) - 1, 16 + i, 3, 1, C("S", 1 if i % 2 else 0))
    _olhos(cv, 13, 4, 3)
    cv.rect(22, 20, 5, 1, OUT)
    return fin(cv)


def cab_et():
    """ET abdutor de vaca -- a parte absurda"""
    cv = new()
    cv.ellipse(24, 14, 11.5, 9, "P")
    cv.ellipse(24, 22, 5.5, 5, "P")
    for side in (-1, 1):                                 # olhão preto amendoado
        for i in range(4):
            cv.rect(24 + side * (3 + i) - 1, 13 + i // 2, 3, 3, PUPIL)
        cv.put(24 + side * 4, 13, SHINE)
    cv.rect(23, 24, 3, 1, OUT)
    cv.line(24, 5, 24, 2, OUT)                           # antena
    cv.rect(23, 0, 3, 2, C("A", 0))
    return fin(cv)


def cab_balde():
    """robô/cavaleiro de balde na cabeça"""
    cv = new()
    cv.blob_rect(14, 6, 21, 20, "M", 2)
    cv.rect(13, 24, 23, 2, C("M", 2))                    # borda do balde
    cv.rect(16, 13, 17, 5, PUPIL)                        # visor
    cv.rect(18, 14, 3, 3, (255, 220, 90, 255))           # olhos acesos
    cv.rect(27, 14, 3, 3, (255, 220, 90, 255))
    cv.rect(16, 8, 4, 2, C("M", 0))
    for x in (15, 33):
        cv.put(x, 21, C("M", 2))
    return fin(cv)


def cab_cebola():
    cv = _cabeca_base(slot="P", rx=10.5, ry=9.5, cy=18)
    for i in range(6):                                    # ponta
        cv.rect(24 - (2 - i // 2), 9 - i, 5 - (i // 2) * 2 if i < 4 else 1, 1, C("P", 0 if i < 3 else 1))
    for x in (19, 29):
        for y in range(11, 26):
            if cv.get(x, y)[3]:
                cv.put(x, y, C("P", 2))
    cv.rect(22, 3, 1, 3, C("S", 1))                       # brotinho
    cv.rect(25, 2, 1, 4, C("S", 0))
    _olhos(cv, 15, 5, 3)
    cv.put(19, 19, (120, 190, 240, 255))                  # lágrima (cebola faz chorar)
    cv.put(19, 20, (120, 190, 240, 255))
    cv.rect(22, 22, 5, 1, OUT)
    return fin(cv)


# ================================================================ CHAPÉUS
def chap_palha():
    cv = new()
    cv.ellipse(24, 8, 14.5, 3, "K")                       # aba
    cv.blob_rect(17, 1, 15, 7, "K", 3)                    # copa
    cv.rect(17, 6, 15, 1, C("A", 1))                      # fita
    for x in range(11, 38, 3):
        cv.put(x, 9, C("K", 2))
    return fin(cv)


def chap_cowboy():
    cv = new()
    cv.ellipse(24, 8, 15, 2.5, "W")
    for side in (-1, 1):                                  # aba virada
        cv.rect(24 + side * 13 - 1, 5, 3, 3, C("W", 1))
    cv.blob_rect(17, 0, 15, 8, "W", 3)
    cv.rect(22, 0, 5, 2, C("W", 2))                        # amassado
    cv.rect(17, 6, 15, 1, C("A", 1))
    cv.rect(23, 6, 3, 1, C("M", 0))                        # fivela
    return fin(cv)


def chap_balde():
    cv = new()
    cv.blob_rect(15, 0, 19, 10, "M", 2)
    cv.rect(14, 9, 21, 2, C("M", 2))
    cv.rect(17, 2, 3, 2, C("M", 0))
    cv.line(14, 5, 10, 9, C("M", 2))                       # alça solta
    return fin(cv)


def chap_bandana():
    cv = new()
    for y in range(6, 11):
        for x in range(13, 36):
            cv.put(x, y, C("A", 1 if x < 28 else 2))
    for x in range(14, 35, 4):                             # bolinhas
        cv.put(x, 8, EYE_W)
    cv.rect(34, 9, 5, 2, C("A", 1))                        # nó
    cv.rect(36, 11, 3, 3, C("A", 2))
    return fin(cv)


def chap_coroa():
    cv = new()
    cv.rect(16, 5, 17, 4, C("K", 1))
    for x in (16, 20, 24, 28, 32):
        cv.rect(x, 2, 1, 3, C("K", 0))
        cv.put(x, 1, C("K", 0))
    cv.rect(16, 5, 17, 1, C("K", 0))
    cv.put(20, 7, C("A", 0))
    cv.put(24, 7, C("S", 0))
    cv.put(28, 7, C("A", 0))
    return fin(cv)


def chap_cozinheiro():
    cv = new()
    for cx in (19, 24, 29):
        cv.ellipse(cx, 3, 4, 3.5, "M", shade=False)
    for y in range(0, 10):
        for x in range(14, 35):
            if cv.get(x, y)[3]:
                cv.put(x, y, EYE_W if x < 29 else (215, 215, 220, 255))
    cv.rect(17, 5, 15, 4, EYE_W)
    cv.rect(17, 8, 15, 1, (200, 200, 205, 255))
    return fin(cv)


def chap_flor():
    cv = new()
    for dx, dy in ((0, -2), (2, 0), (0, 2), (-2, 0)):
        cv.rect(30 + dx, 6 + dy, 2, 2, C("A", 0))
    cv.rect(30, 6, 2, 2, C("K", 0))
    cv.put(29, 9, C("S", 1))
    return fin(cv)


def chap_penacho():
    """capacete de panela com penacho"""
    cv = new()
    cv.ellipse(24, 7, 11, 5, "M")
    cv.rect(13, 8, 23, 2, C("M", 2))
    for i in range(6):
        cv.rect(23 + (i % 2), 0 + i // 2, 3, 2, C("A", 0 if i < 3 else 1))
    return fin(cv)


# ================================================================ ARMAS (mão direita)
def arma_forcado():
    cv = new()
    cv.rect(38, 16, 2, 28, C("W", 1))
    cv.rect(38, 16, 1, 28, C("W", 0))
    cv.rect(34, 12, 10, 2, C("M", 1))
    for x in (34, 38, 42):
        cv.rect(x, 4, 2, 9, C("M", 0))
        cv.put(x, 3, C("M", 0))
    return fin(cv)


def arma_machado():
    cv = new()
    cv.rect(38, 12, 2, 32, C("W", 1))
    cv.rect(38, 12, 1, 32, C("W", 0))
    cv.blob_rect(39, 8, 8, 10, "M", 3)
    cv.rect(45, 9, 2, 8, C("M", 0))                        # fio
    cv.rect(35, 10, 4, 5, C("M", 2))
    return fin(cv)


def arma_marreta():
    cv = new()
    cv.rect(38, 14, 2, 30, C("W", 1))
    cv.rect(38, 14, 1, 30, C("W", 0))
    cv.blob_rect(32, 5, 14, 10, "M", 2)
    cv.rect(33, 6, 4, 2, C("M", 0))
    cv.rect(32, 9, 14, 1, C("M", 2))
    return fin(cv)


def arma_foice():
    cv = new()
    cv.rect(38, 10, 2, 34, C("W", 1))
    cv.rect(38, 10, 1, 34, C("W", 0))
    pts = [(38, 9), (36, 6), (33, 4), (29, 3), (26, 4), (24, 6)]
    for i, (x, y) in enumerate(pts):
        cv.rect(x, y, 4, 2, C("M", 0 if i % 2 == 0 else 1))
    cv.put(23, 8, C("M", 0))
    return fin(cv)


def arma_enxada():
    cv = new()
    cv.rect(38, 8, 2, 36, C("W", 1))
    cv.rect(38, 8, 1, 36, C("W", 0))
    cv.blob_rect(40, 6, 6, 8, "M", 2)
    cv.rect(40, 12, 6, 2, C("M", 0))
    return fin(cv)


def arma_frigideira():
    cv = new()
    cv.rect(38, 22, 2, 16, C("W", 2))
    cv.ellipse(39, 14, 6.5, 6.5, "M")
    cv.ellipse(39, 14, 4, 4, "M", shade=False)
    cv.put(37, 12, C("M", 0))
    cv.put(38, 11, C("M", 0))
    return fin(cv)


def arma_porrete():
    cv = new()
    cv.rect(38, 24, 2, 16, C("W", 1))
    cv.blob_rect(36, 8, 6, 17, "W", 3)
    for x, y in ((35, 12), (42, 15), (35, 19), (42, 10)):   # pregos
        cv.put(x, y, C("M", 0))
    return fin(cv)


def arma_estilingue():
    cv = new()
    cv.rect(38, 26, 2, 14, C("W", 1))
    cv.line(38, 26, 35, 18, C("W", 1))
    cv.line(39, 26, 42, 18, C("W", 1))
    cv.rect(34, 16, 2, 3, C("W", 0))
    cv.rect(42, 16, 2, 3, C("W", 0))
    cv.line(35, 17, 39, 21, C("A", 1))                       # borracha
    cv.line(43, 17, 39, 21, C("A", 1))
    cv.rect(38, 20, 3, 3, C("M", 2))                         # pedra
    return fin(cv)


def arma_viola():
    """viola caipira (suporte/cura por música)"""
    cv = new()
    cv.ellipse(39, 34, 5.5, 6, "W")
    cv.ellipse(39, 27, 4, 4, "W")
    cv.ellipse(39, 32, 2, 2, "W", shade=False)
    cv.put(39, 32, PUPIL)
    cv.put(38, 32, PUPIL)
    cv.rect(38, 10, 2, 14, C("W", 2))                         # braço
    cv.rect(37, 7, 4, 4, C("W", 1))
    for y in range(11, 38, 2):
        cv.put(39, y, EYE_W)
    return fin(cv)


def arma_motosserra():
    """absurdo de roça"""
    cv = new()
    cv.blob_rect(34, 26, 10, 8, "A", 2)
    cv.rect(36, 24, 6, 2, C("M", 2))
    cv.blob_rect(37, 6, 5, 21, "M", 2)
    for y in range(7, 26, 2):
        cv.put(36, y, C("M", 2))
        cv.put(42, y + 1, C("M", 2))
    cv.put(36, 28, C("K", 0))
    return fin(cv)


def arma_lampiao():
    cv = new()
    cv.rect(38, 14, 2, 26, C("W", 1))
    cv.line(39, 14, 43, 12, C("W", 1))
    cv.rect(43, 12, 1, 3, C("M", 2))
    cv.blob_rect(41, 15, 6, 8, "M", 2)
    cv.rect(42, 17, 4, 4, (255, 220, 110, 255))
    cv.put(43, 18, (255, 250, 200, 255))
    return fin(cv)


def arma_escudo_tampa():
    """tampa de panela como escudo -- vai na mão ESQUERDA"""
    cv = new()
    cv.ellipse(10, 33, 6.5, 7, "M")
    cv.ellipse(10, 33, 2, 2, "W", shade=False)
    cv.put(8, 30, C("M", 0))
    cv.put(9, 29, C("M", 0))
    return fin(cv)


# ================================================================ COSTAS
def costas_rabo_galo():
    cv = new()
    for i, (dx, col) in enumerate(((0, 0), (3, 1), (6, 2))):
        cv.line(14 - dx, 36, 6 - dx // 2, 22 + i * 2, C("A", col))
        cv.line(15 - dx, 36, 7 - dx // 2, 22 + i * 2, C("A", col))
    return fin(cv)


def costas_capa():
    cv = new()
    for y in range(24, 43):
        half = 8 + (y - 24) // 3
        for x in range(24 - half, 24 + half + 1):
            cv.put(x, y, C("A", 1 if x < 27 else 2))
    return fin(cv)


def costas_mochila_foguete():
    """jetpack de botijão de gás -- absurdo"""
    cv = new()
    for x in (9, 34):
        cv.blob_rect(x, 26, 6, 12, "M", 3)
        cv.rect(x + 1, 38, 4, 2, C("M", 2))
        cv.rect(x + 2, 40, 2, 3, (255, 170, 60, 255))
        cv.put(x + 2, 43, (255, 230, 120, 255))
    return fin(cv)


PECAS = {
    "pernas": {"casco": pernas_casco, "bota": pernas_bota, "ave": pernas_ave, "patinha": pernas_patinha,
               "fantasma": pernas_fantasma, "rodas": pernas_rodas, "inseto": pernas_inseto},
    "corpo": {"redondo": corpo_redondo, "macacao": corpo_macacao, "penas": corpo_penas, "la": corpo_la,
              "listrado": corpo_listrado, "armadura": corpo_armadura, "poncho": corpo_poncho, "saco": corpo_saco},
    "bracos": {"patas": bracos_patas, "humanos": bracos_humanos, "asas": bracos_asas},
    "cabeca": {"vaca": cab_vaca, "boi": cab_boi, "porco": cab_porco, "galinha": cab_galinha, "pato": cab_pato,
               "ovelha": cab_ovelha, "bode": cab_bode, "cavalo": cab_cavalo, "sapo": cab_sapo,
               "capivara": cab_capivara, "gato": cab_gato, "coruja": cab_coruja, "abelha": cab_abelha,
               "humano": cab_humano, "velho": cab_velho, "espantalho": cab_espantalho, "abobora": cab_abobora,
               "milho": cab_milho, "et": cab_et, "balde": cab_balde, "cebola": cab_cebola},
    "chapeu": {"palha": chap_palha, "cowboy": chap_cowboy, "balde": chap_balde, "bandana": chap_bandana,
               "coroa": chap_coroa, "cozinheiro": chap_cozinheiro, "flor": chap_flor, "penacho": chap_penacho},
    "arma": {"forcado": arma_forcado, "machado": arma_machado, "marreta": arma_marreta, "foice": arma_foice,
             "enxada": arma_enxada, "frigideira": arma_frigideira, "porrete": arma_porrete,
             "estilingue": arma_estilingue, "viola": arma_viola, "motosserra": arma_motosserra,
             "lampiao": arma_lampiao, "escudo": arma_escudo_tampa},
    "costas": {"rabo_galo": costas_rabo_galo, "capa": costas_capa, "foguete": costas_mochila_foguete,
               "asas_inseto": bracos_asas_inseto},
}
ORDEM = ["costas", "pernas", "corpo", "bracos", "cabeca", "chapeu", "arma"]


def montar(receita, paleta):
    """receita = {categoria: nome}; devolve Image 48x48 já recolorida"""
    cv = Canvas()
    for cat in ORDEM:
        nome = receita.get(cat)
        if not nome:
            continue
        peca = PECAS[cat][nome]()
        cv.paste(peca)
    return recolor(cv.img, paleta)


# ================================================================ PEÇAS NOVAS (lote 2)
def cab_cachorro():
    """vira-lata caramelo"""
    cv = _cabeca_base(rx=10, ry=9.5)
    for side in (-1, 1):                              # orelhas caídas
        cv.blob_rect(24 + side * 11 - 2, 8, 5, 11, "S", 2)
    cv.ellipse(24, 21, 6, 4.5, "K")                   # focinho
    cv.rect(22, 19, 4, 3, PUPIL)                      # nariz
    cv.rect(23, 24, 3, 3, C("A", 0))                  # língua
    cv.ellipse(19, 13, 4, 3.5, "S", shade=False)      # mancha no olho
    _olhos(cv, 13, 5, 3)
    return fin(cv)


def cab_burro():
    cv = new()
    cv.ellipse(24, 14, 8.5, 9, "P")
    cv.blob_rect(18, 16, 13, 12, "P", 3)
    cv.blob_rect(18, 22, 13, 6, "K", 2)
    cv.rect(20, 24, 2, 2, PUPIL); cv.rect(27, 24, 2, 2, PUPIL)
    for side in (-1, 1):                              # orelhonas
        cv.blob_rect(24 + side * 8 - 2, 0, 4, 11, "P", 2)
        cv.rect(24 + side * 8 - 1, 2, 2, 7, C("K", 1))
    cv.rect(21, 26, 7, 1, EYE_W)                      # dentão
    _olhos(cv, 12, 5, 3, sono=True)
    return fin(cv)


def cab_tatu():
    cv = _cabeca_base(slot="M", rx=10.5, ry=9)
    for y in (11, 15):                                # placas
        for x in range(14, 35):
            if cv.get(x, y)[3]:
                cv.put(x, y, C("M", 2))
    cv.blob_rect(19, 17, 11, 9, "K", 3)               # focinho comprido
    cv.rect(23, 24, 3, 2, PUPIL)
    for side in (-1, 1):
        cv.blob_rect(24 + side * 8 - 1, 3, 3, 6, "K", 1)
    _olhos(cv, 13, 6, 2)
    return fin(cv)


def cab_jacare():
    cv = new()
    cv.blob_rect(13, 9, 23, 11, "P", 3)
    cv.blob_rect(15, 17, 19, 11, "P", 3)              # bocarra
    cv.rect(15, 23, 19, 1, PUPIL)
    for x in range(16, 34, 3):                        # dentes
        cv.put(x, 22, EYE_W); cv.put(x + 1, 24, EYE_W)
    cv.rect(18, 18, 2, 2, C("P", 2)); cv.rect(29, 18, 2, 2, C("P", 2))
    for side in (-1, 1):                              # olhos saltados
        cv.ellipse(24 + side * 7, 9, 4, 4, "P")
        cx = 24 + side * 7
        cv.rect(cx - 1, 7, 3, 3, (250, 220, 90, 255)); cv.rect(cx, 7, 1, 3, PUPIL)
    for x in (17, 21, 26, 30):
        cv.put(x, 12, C("P", 2))
    return fin(cv)


def cab_urubu():
    cv = _cabeca_base(slot="K", rx=8.5, ry=8.5, cy=15)   # cabeça pelada
    cv.blob_rect(21, 18, 7, 8, "M", 2)                   # bicão curvo
    cv.rect(22, 25, 4, 2, C("M", 2))
    for x in range(13, 36):                              # gola de penas
        cv.rect(x, 24 + (x % 2), 1, 4, C("P", 1 if x < 28 else 2))
    cv.put(20, 9, C("K", 2)); cv.put(27, 8, C("K", 2))
    _olhos(cv, 13, 4, 2, bravo=False)
    cv.rect(18, 11, 4, 1, OUT); cv.rect(26, 11, 4, 1, OUT)
    return fin(cv)


def cab_tomate():
    cv = _cabeca_base(slot="A", rx=11, ry=10, cy=18)
    for dx in (-5, -2, 1, 4):                            # folhinhas
        cv.rect(24 + dx, 6, 2, 3, C("S", 1))
    cv.rect(20, 8, 9, 2, C("S", 0))
    cv.rect(23, 3, 2, 4, C("S", 2))
    cv.rect(15, 13, 3, 4, SHINE)
    _olhos(cv, 15, 5, 3, bravo=False)
    cv.rect(18, 13, 4, 1, OUT); cv.rect(27, 13, 4, 1, OUT)
    cv.rect(21, 23, 7, 1, OUT); cv.put(20, 22, OUT); cv.put(28, 22, OUT)
    return fin(cv)


def cab_cacto():
    cv = new()
    cv.blob_rect(16, 4, 17, 23, "S", 6)
    for x in (20, 24, 28):
        for y in range(6, 26):
            if cv.get(x, y)[3]:
                cv.put(x, y, C("S", 2))
    for x, y in ((15, 9), (33, 12), (15, 18), (33, 21), (22, 3), (27, 3)):   # espinhos
        cv.put(x, y, EYE_W)
    cv.rect(26, 1, 4, 3, C("A", 0)); cv.put(27, 2, C("K", 0))               # florzinha
    _olhos(cv, 13, 4, 3)
    cv.rect(22, 20, 5, 1, OUT)
    return fin(cv)


def cab_caveira():
    """caveira de boi (assombração do pasto)"""
    cv = new()
    cv.ellipse(24, 13, 9.5, 8.5, "M")
    cv.blob_rect(19, 16, 11, 12, "M", 2)
    for side in (-1, 1):
        bx = 24 + side * 9
        cv.rect(bx - 1, 8, 3, 3, C("M", 1))
        cv.rect(bx + side * 2 - 1, 5, 3, 4, C("M", 0))
        cv.rect(bx + side * 4 - 1, 2, 2, 4, C("M", 0))
        cv.ellipse(24 + side * 4.5, 13, 3, 3.5, "W", shade=False)
        for y in range(9, 18):
            for x in range(24 + side * 5 - 4, 24 + side * 5 + 4):
                if cv.get(x, y)[:3] == C("W", 1)[:3]:
                    cv.put(x, y, PUPIL)
        cv.put(24 + side * 4, 13, (255, 90, 60, 255))    # brasa no olho
    cv.rect(22, 22, 2, 3, PUPIL); cv.rect(25, 22, 2, 3, PUPIL)
    for x in range(20, 29, 2):
        cv.put(x, 27, PUPIL)
    return fin(cv)


def corpo_colete():
    """gibão de couro do vaqueiro"""
    cv = new()
    cv.ellipse(24, 33, 9, 8.5, "S")
    cv.blob_rect(15, 26, 7, 15, "W", 2)
    cv.blob_rect(27, 26, 7, 15, "W", 2)
    for y in range(28, 40, 3):
        cv.put(21, y, C("K", 0)); cv.put(27, y, C("K", 0))
    cv.rect(16, 36, 17, 2, C("W", 2))                    # cinto
    cv.rect(23, 36, 3, 2, C("M", 0))
    return fin(cv)


def corpo_terno():
    """terno de domingo (prefeito, coronel)"""
    cv = new()
    cv.ellipse(24, 33, 9, 8.5, "A")
    for i in range(8):                                   # lapela
        cv.rect(24 - 4 + i // 2, 25 + i, 1, 1, C("A", 2)); cv.rect(24 + 4 - i // 2, 25 + i, 1, 1, C("A", 2))
    cv.rect(23, 25, 3, 8, EYE_W)                          # camisa
    cv.rect(24, 26, 1, 7, C("P", 1))                      # gravata
    cv.put(24, 36, C("K", 0)); cv.put(24, 39, C("K", 0))
    return fin(cv)


def chap_bone():
    cv = new()
    cv.ellipse(24, 7, 10.5, 5, "A")
    cv.rect(13, 8, 22, 2, C("A", 2))
    cv.blob_rect(26, 8, 14, 3, "A", 1)                    # aba pro lado
    cv.rect(22, 4, 5, 3, EYE_W)
    return fin(cv)


def chap_cartola():
    cv = new()
    cv.blob_rect(17, 0, 15, 9, "M", 1)
    for y in range(0, 9):
        for x in range(17, 32):
            if cv.get(x, y)[3]:
                cv.put(x, y, (40, 36, 48, 255) if x < 28 else (26, 22, 32, 255))
    cv.rect(17, 6, 15, 2, C("A", 1))
    cv.rect(12, 9, 25, 2, (40, 36, 48, 255))
    return fin(cv)


def chap_chifres():
    """capacete de chifre (viking do sertão)"""
    cv = new()
    cv.ellipse(24, 8, 10.5, 4.5, "M")
    cv.rect(14, 9, 21, 2, C("M", 2))
    for side in (-1, 1):
        bx = 24 + side * 11
        cv.rect(bx - 1, 5, 3, 4, EYE_W)
        cv.rect(bx + side * 2 - 1, 2, 3, 4, EYE_W)
        cv.rect(bx + side * 3 - 1, 0, 2, 3, (220, 215, 200, 255))
    return fin(cv)


def chap_melancia():
    """capacete de casca de melancia"""
    cv = new()
    cv.ellipse(24, 8, 11.5, 6, "S")
    for x in (17, 22, 27, 32):
        for y in range(2, 13):
            if cv.get(x, y)[3]:
                cv.put(x, y, C("S", 2))
    cv.rect(13, 10, 23, 2, C("A", 0))
    return fin(cv)


def arma_vara():
    """vara de pescar"""
    cv = new()
    cv.line(38, 44, 40, 8, C("W", 1)); cv.line(39, 44, 41, 8, C("W", 0))
    cv.line(41, 8, 45, 4, C("W", 1))
    cv.line(45, 4, 45, 18, EYE_W)
    cv.rect(44, 18, 3, 2, C("M", 0)); cv.put(44, 20, C("M", 0)); cv.put(45, 21, C("M", 0))
    cv.rect(44, 12, 3, 3, C("A", 1))                      # boia
    return fin(cv)


def arma_berrante():
    cv = new()
    pts = [(37, 38), (38, 33), (39, 28), (41, 23), (43, 19), (44, 15)]
    for i, (x, y) in enumerate(pts):
        r = 1.5 + i * 0.7
        cv.ellipse(x, y, r, r, "K")
    cv.ellipse(44, 12, 5.5, 3, "M")
    cv.ellipse(44, 12, 3.5, 1.5, "W", shade=False)
    cv.rect(36, 39, 3, 3, C("M", 0))
    return fin(cv)


def arma_garrafa():
    """garrafa de pinga (arremesso)"""
    cv = new()
    cv.blob_rect(35, 22, 8, 16, "S", 2)
    cv.rect(37, 14, 4, 8, C("S", 1))
    cv.rect(37, 12, 4, 3, C("W", 1))                       # rolha
    cv.rect(36, 27, 6, 6, EYE_W)
    cv.rect(38, 29, 2, 2, C("A", 1))
    cv.rect(36, 23, 1, 4, SHINE)
    return fin(cv)


def arma_rastelo():
    cv = new()
    cv.rect(38, 14, 2, 30, C("W", 1)); cv.rect(38, 14, 1, 30, C("W", 0))
    cv.rect(31, 10, 16, 3, C("M", 1))
    for x in range(31, 47, 3):
        cv.rect(x, 4, 2, 7, C("M", 0))
    return fin(cv)


def arma_espingarda():
    """espingarda de rolha"""
    cv = new()
    cv.blob_rect(36, 26, 6, 12, "W", 2)                    # coronha
    cv.rect(37, 6, 3, 21, C("M", 1)); cv.rect(37, 6, 1, 21, C("M", 0))
    cv.rect(36, 22, 5, 3, C("M", 2))
    cv.rect(37, 2, 3, 4, C("W", 0))                        # rolha
    cv.line(40, 4, 44, 10, EYE_W)                          # barbante
    return fin(cv)


def arma_regador():
    cv = new()
    cv.blob_rect(33, 24, 11, 12, "M", 2)
    cv.line(44, 27, 47, 20, C("M", 1)); cv.line(44, 28, 47, 21, C("M", 2))
    cv.rect(45, 17, 3, 4, C("M", 0))
    cv.rect(35, 20, 7, 2, C("M", 2)); cv.put(35, 22, C("M", 2)); cv.put(41, 22, C("M", 2))
    for x, y in ((46, 14), (44, 12), (47, 11)):
        cv.put(x, y, (120, 190, 240, 255))
    return fin(cv)


def costas_cesto():
    """cesto de colheita nas costas"""
    cv = new()
    cv.blob_rect(6, 24, 10, 14, "K", 2)
    for y in range(26, 37, 3):
        cv.rect(6, y, 10, 1, C("K", 2))
    for cx, col in ((8, "A"), (12, "S"), (10, "A")):
        cv.ellipse(cx, 22 if cx != 10 else 20, 2.5, 2.5, col)
    return fin(cv)


def costas_asas_morcego():
    cv = new()
    for side in (-1, 1):
        for i in range(12):
            x = 24 + side * (10 + i)
            top = 22 - i // 2 + (i // 4)
            h = 12 - abs(i - 6) + (2 if i % 4 == 0 else 0)
            cv.rect(x, top, 1, h, C("M", 2 if i % 4 == 0 else 1))
    return fin(cv)


PECAS["cabeca"].update({"cachorro": cab_cachorro, "burro": cab_burro, "tatu": cab_tatu, "jacare": cab_jacare, "urubu": cab_urubu,
                        "tomate": cab_tomate, "cacto": cab_cacto, "caveira": cab_caveira})
PECAS["corpo"].update({"colete": corpo_colete, "terno": corpo_terno})
PECAS["chapeu"].update({"bone": chap_bone, "cartola": chap_cartola, "chifres": chap_chifres, "melancia": chap_melancia})
PECAS["arma"].update({"vara": arma_vara, "berrante": arma_berrante, "garrafa": arma_garrafa, "rastelo": arma_rastelo,
                      "espingarda": arma_espingarda, "regador": arma_regador})
PECAS["costas"].update({"cesto": costas_cesto, "morcego": costas_asas_morcego})


# ================================================================ POSTURAS (lote 3)
# Nem todo bicho fica em pé feito gente. Estas peças são o CORPO INTEIRO
# (pernas + tronco + rabo) em outra postura; a cabeça é a mesma peça de
# sempre, só encaixada em outro lugar (QUATRO_CABECA = deslocamento dx,dy).
# Receita: {"quatro": "casco", "cabeca": "vaca"}  (sem pernas/corpo/bracos)
def quatro_casco():
    """vaca, cavalo, bode, jegue: de lado, quatro pernas com casco, rabo com tufo"""
    cv = new()
    for x in (16, 30):                               # pernas de trás (mais escuras)
        cv.rect(x, 37, 3, 6, C("P", 2))
        cv.rect(x, 43, 3, 2, C("M", 2))
    cv.line(7, 27, 5, 31, C("P", 2))                  # rabo
    cv.line(5, 31, 5, 34, C("P", 2))
    cv.rect(4, 35, 3, 3, C("S", 1))
    cv.ellipse(20, 31, 13, 8, "P")                    # tronco
    cv.ellipse(20, 35, 8, 3.2, "K")                   # barriga clara
    for x in (10, 25):                               # pernas da frente
        cv.blob_rect(x, 36, 5, 7, "P", 1)
        cv.rect(x, 43, 5, 2, C("M", 2))
        cv.rect(x, 43, 2, 1, C("M", 1))
    return fin(cv)


def quatro_pata():
    """cachorro, capivara, porco, gato: de lado, perna curta e patinha"""
    cv = new()
    for x in (16, 29):
        cv.rect(x, 39, 3, 5, C("P", 2))
    cv.ellipse(6, 28, 2.5, 3.5, "P")                  # rabinho pra cima
    cv.ellipse(20, 33, 12.5, 7.5, "P")
    cv.ellipse(20, 37, 8, 3, "K")
    for x in (10, 25):
        cv.blob_rect(x, 39, 5, 6, "P", 2)
        cv.rect(x, 44, 5, 1, C("P", 2))
    return fin(cv)


def quatro_rasteiro():
    """jacaré, tatu: baixinho e comprido, rabo grosso, placas nas costas"""
    cv = new()
    for i, (x, w) in enumerate(((1, 4), (4, 5), (8, 6))):   # rabo afinando
        cv.rect(x, 39 - i, w, 3 + i, C("P", 2 if i == 0 else 1))
    for x in (12, 27):                               # patas de trás
        cv.rect(x, 41, 4, 4, C("P", 2))
    cv.ellipse(21, 37, 13, 6, "P")
    cv.ellipse(21, 40, 9, 2.5, "K")
    for x in (10, 14, 18, 22, 26):                   # placas / escamas
        cv.rect(x, 30, 3, 2, C("S", 1))
        cv.put(x + 1, 29, C("S", 0))
    for x in (9, 24):                                # patas da frente
        cv.blob_rect(x, 41, 5, 4, "P", 1)
    return fin(cv)


def quatro_sapo():
    """sapo: agachado de frente, coxas grandes dos lados"""
    cv = new()
    for side in (-1, 1):
        cv.ellipse(24 + side * 13, 39, 6, 5, "P")     # coxa dobrada
        cv.rect(24 + side * 13 - 4, 43, 8, 2, C("K", 1))   # pezão
        cv.rect(24 + side * 13 - 4, 43, 8, 1, C("K", 0))
    cv.ellipse(24, 36, 11, 8, "P")
    cv.ellipse(24, 39, 7, 4.5, "K")
    for side in (-1, 1):                             # mãozinhas na frente
        cv.rect(24 + side * 6 - 2, 42, 4, 3, C("P", 2))
    return fin(cv)


def quatro_malhado():
    """vaca: o mesmo corpo de casco, com manchas"""
    cv = quatro_casco()
    body = [c[:3] for c in (C("P", 0), C("P", 1), C("P", 2))]
    for x, y, w, h in ((9, 25, 6, 5), (17, 28, 5, 4), (13, 33, 4, 3), (24, 24, 4, 3)):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                if (xx, yy) in ((x, y), (x + w - 1, y + h - 1), (x + w - 1, y), (x, y + h - 1)):
                    continue                           # cantos arredondados
                if cv.get(xx, yy)[3] and cv.get(xx, yy)[:3] in body:
                    cv.put(xx, yy, C("S", 1))
    return cv


def quatro_casca():
    """tatu: casco em cúpula com faixas, perninha curta, rabo fino"""
    cv = new()
    cv.line(3, 41, 8, 39, C("K", 2))                  # rabo fino
    cv.line(3, 42, 8, 40, C("K", 2))
    for x in (13, 27):
        cv.rect(x, 41, 4, 4, C("K", 2))
    cv.ellipse(21, 35, 13, 8.5, "M")                  # casco
    for x in (12, 16, 20, 24, 28):                   # faixas
        for y in range(28, 43):
            if cv.get(x, y)[3]:
                cv.put(x, y, C("M", 2))
    cv.rect(9, 42, 25, 2, C("K", 1))                  # barriga aparecendo embaixo
    for x in (9, 24):
        cv.blob_rect(x, 41, 5, 4, "K", 1)
    return fin(cv)


# ---- corpo próprio por bicho (19/11): cavalo e bezerro usavam o MESMO corpo
# e continuavam parecidos. Agora cada um tem a sua silhueta.
def _quad(cx, cy, rx, ry, leg_h, back_x, front_x, leg_w=4, hoof=True, far_dx=5):
    """tronco deitado + 4 pernas. Devolve o canvas SEM contorno (pra enfeitar antes)."""
    cv = new()
    top = FEET_Y + 1 - leg_h
    for x in (back_x + far_dx, front_x + far_dx):     # pernas de trás (escuras)
        cv.rect(x, top, leg_w - 1, leg_h - (2 if hoof else 0), C("P", 2))
        if hoof:
            cv.rect(x, FEET_Y - 1, leg_w - 1, 2, C("M", 2))
    cv.ellipse(cx, cy, rx, ry, "P")
    return cv, top


def _front_legs(cv, top, leg_h, back_x, front_x, leg_w=4, hoof=True):
    for x in (back_x, front_x):
        cv.blob_rect(x, top, leg_w, leg_h - (2 if hoof else 0), "P", 1)
        if hoof:
            cv.rect(x, FEET_Y - 1, leg_w, 2, C("M", 2))
            cv.rect(x, FEET_Y - 1, 2, 1, C("M", 1))


def quatro_cavalo():
    """alto e esguio: perna comprida, pescoço erguido, crina e rabo longo"""
    cv, top = _quad(19, 28, 12, 6, 12, 8, 23, far_dx=4)
    for i in range(9):                               # rabo comprido caindo
        cv.rect(4 - (1 if i > 5 else 0), 25 + i, 3, 1, C("S", 1 if i % 3 else 0))
    cv.rect(5, 24, 3, 2, C("S", 1))
    for i in range(7):                               # pescoço subindo pra cabeça
        cv.rect(24 + i // 2, 24 - i, 7, 1, C("P", 1 if i < 5 else 0))
    for i in range(8):                               # crina
        cv.rect(23 + i // 2, 23 - i, 2, 1, C("S", 1))
    cv.ellipse(19, 31, 7, 2.5, "K")
    _front_legs(cv, top, 12, 8, 23)
    return fin(cv)


def quatro_bezerro():
    """pequeno e atarracado: corpo curto, perninha grossa, meia branca"""
    cv, top = _quad(21, 34, 9.5, 6.5, 7, 13, 23, leg_w=5, far_dx=4)
    cv.rect(10, 30, 2, 5, C("P", 2))                  # rabinho
    cv.rect(10, 35, 2, 2, C("S", 0))
    cv.ellipse(20, 37, 6, 2.5, "S")                   # barriga branca
    _front_legs(cv, top, 7, 13, 23, leg_w=5)
    for x in (13, 23):                               # meias brancas
        cv.rect(x, FEET_Y - 4, 5, 2, C("S", 0))
    return fin(cv)


def quatro_vaca():
    """parruda: tronco grande, úbere, perna curta e grossa, malhada"""
    cv, top = _quad(19, 30, 14, 9, 8, 8, 24, leg_w=5, far_dx=5)
    cv.line(5, 25, 3, 30, C("P", 2))                  # rabo
    cv.line(3, 30, 3, 35, C("P", 2))
    cv.rect(2, 36, 3, 3, C("S", 1))
    cv.ellipse(15, 39, 4, 2.5, "K")                   # úbere
    cv.put(13, 41, C("K", 2)); cv.put(16, 41, C("K", 2))
    body = [c[:3] for c in (C("P", 0), C("P", 1), C("P", 2))]
    for x, y, w, h in ((7, 24, 7, 6), (17, 27, 6, 5), (11, 33, 5, 3), (24, 22, 5, 4), (22, 34, 4, 3)):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                if (xx, yy) in ((x, y), (x + w - 1, y + h - 1), (x + w - 1, y), (x, y + h - 1)):
                    continue
                if cv.get(xx, yy)[3] and cv.get(xx, yy)[:3] in body:
                    cv.put(xx, yy, C("S", 1))
    _front_legs(cv, top, 8, 8, 24, leg_w=5)
    return fin(cv)


def quatro_bode():
    """compacto e peludo: franja na barriga, rabinho em pé, perna fina"""
    cv, top = _quad(21, 32, 10.5, 6.5, 9, 13, 24, leg_w=3, far_dx=4)
    cv.rect(9, 25, 3, 4, C("P", 0))                   # rabo em pé
    cv.put(10, 24, C("P", 0))
    for x in range(13, 30, 2):                       # franja de pelo
        cv.rect(x, 37, 1, 3, C("S", 1))
        cv.rect(x + 1, 37, 1, 2, C("S", 0))
    _front_legs(cv, top, 9, 13, 24, leg_w=3)
    return fin(cv)


def quatro_jegue():
    """jegue: lombo reto com listra escura, rabo fino de tufo, perna média"""
    cv, top = _quad(19, 31, 12.5, 7, 9, 9, 23, far_dx=4)
    cv.line(6, 27, 4, 33, C("P", 2))
    cv.rect(3, 34, 3, 4, C("W", 2))
    cv.rect(9, 24, 19, 2, C("W", 2))                  # listra do lombo
    cv.rect(15, 26, 2, 6, C("W", 2))                  # a "cruz" do jegue
    cv.ellipse(19, 35, 7.5, 2.8, "K")
    _front_legs(cv, top, 9, 9, 23)
    return fin(cv)


def quatro_cachorro():
    """vira-lata: magro, barriga encolhida, rabo fino enrolado pra cima"""
    cv, top = _quad(20, 33, 11, 5.5, 9, 10, 24, leg_w=3, hoof=False, far_dx=3)
    for (x, y) in ((8, 29), (7, 28), (6, 27), (6, 26), (6, 25), (7, 24), (8, 24), (9, 25)):   # rabo em gancho
        cv.put(x, y, C("P", 1)); cv.put(x + 1, y, C("P", 2))
    cv.ellipse(23, 36, 4, 2, "K")                     # peito claro
    for x in (15, 16, 17, 18):                       # barriga encolhida (some um pedaço)
        cv.put(x, 38, (0, 0, 0, 0))
    _front_legs(cv, top, 9, 10, 24, leg_w=3, hoof=False)
    for x in (10, 24):
        cv.rect(x, FEET_Y - 1, 4, 2, C("K", 1))       # patinha clara
    return fin(cv)


def quatro_capivara():
    """capivara: barril sem rabo, traseiro alto, perninha curtíssima"""
    cv, top = _quad(19, 33, 13, 8.5, 5, 9, 24, leg_w=5, hoof=False, far_dx=5)
    cv.ellipse(11, 31, 6, 7.5, "P")                   # traseiro redondão
    cv.ellipse(20, 38, 8, 2.5, "K")
    _front_legs(cv, top, 5, 9, 24, leg_w=5, hoof=False)
    for x in (9, 24):
        cv.rect(x, FEET_Y, 5, 1, C("P", 2))
    return fin(cv)


def quatro_porco():
    """porco: bola gorda, rabinho enrolado, casquinho"""
    cv, top = _quad(20, 32, 12.5, 9.5, 5, 10, 24, leg_w=4, far_dx=5)
    for (x, y) in ((6, 28), (5, 27), (5, 26), (6, 25), (7, 26)):      # rabo saca-rolha
        cv.put(x, y, C("K", 2))
    cv.ellipse(20, 38, 8, 3, "K")
    _front_legs(cv, top, 5, 10, 24, leg_w=4)
    return fin(cv)


def quatro_gato():
    """gato: esguio, costas arqueadas, rabo comprido em S"""
    cv, top = _quad(21, 33, 10, 5, 9, 12, 24, leg_w=3, hoof=False, far_dx=3)
    cv.ellipse(18, 29, 6, 3, "P")                     # costas arqueadas
    for (x, y) in ((10, 31), (8, 30), (6, 28), (5, 25), (5, 22), (6, 20), (8, 19), (9, 20)):   # rabo em S
        cv.rect(x, y, 2, 3, C("P", 1))
    cv.rect(8, 19, 3, 2, C("S", 1))                   # ponta do rabo
    _front_legs(cv, top, 9, 12, 24, leg_w=3, hoof=False)
    return fin(cv)


# ---- BICHARADA NOVA (19/11): tipos bem separados, como cavaleiro x goblin no Clash
FIRE_O = (240, 96, 32, 255)     # fogo: cores fixas (não mudam com a paleta)
FIRE_M = (250, 170, 40, 255)
FIRE_I = (255, 236, 130, 255)


def _flame(cv, cx, base_y, h, w):
    """labareda: três línguas, laranja por fora e amarela por dentro"""
    for i in range(h):
        t = i / max(h - 1, 1)
        half = int(round(w * (1.0 - t) ** 0.8))
        wob = (1 if (i // 2) % 2 == 0 else -1) if i > 1 else 0
        for x in range(cx - half + wob, cx + half + 1 + wob):
            d = abs(x - cx - wob) / max(half, 1)
            cv.put(x, base_y - i, FIRE_I if d < 0.35 and t < 0.6 else (FIRE_M if d < 0.7 else FIRE_O))


def quatro_formiga():
    """saúva: três gomos, seis perninhas, antenas. Corpo inteiro (não leva cabeça)."""
    cv = new()
    for x0, x1 in ((16, 12), (20, 19), (24, 27), (17, 15), (21, 22), (25, 30)):    # pernas
        cv.line(x0, 38, x1, 44, C("M", 2))
    cv.ellipse(12, 34, 7, 6, "P")                     # traseiro
    cv.ellipse(22, 36, 4.5, 3.5, "P")                 # meio
    cv.ellipse(32, 32, 6.5, 6, "P")                   # cabeça
    cv.line(34, 27, 38, 21, C("M", 2)); cv.put(39, 21, C("M", 2))    # antenas
    cv.line(31, 27, 33, 20, C("M", 2)); cv.put(34, 20, C("M", 2))
    cv.rect(37, 34, 3, 2, C("M", 2))                  # ferrão da boca
    cv.rect(38, 36, 3, 1, C("M", 2))
    cv.rect(33, 30, 3, 3, EYE_W); cv.rect(34, 30, 2, 2, PUPIL)
    cv.rect(9, 31, 3, 1, C("P", 0))                   # brilho
    return fin(cv)


def quatro_montado():
    """vaqueiro a cavalo: o cavalo de lado e o corpo do cavaleiro; a cabeça do
    cavaleiro é a peça de cabeça normal (encaixada em cima). Lança apontada."""
    cv = new()
    for x in (13, 27):                               # pernas de trás do cavalo
        cv.rect(x, 36, 3, 7, C("P", 2))
        cv.rect(x, 43, 3, 2, C("M", 2))
    for i in range(8):                               # rabo
        cv.rect(2, 30 + i, 3, 1, C("W", 2))
    cv.ellipse(18, 32, 13, 6.5, "P")                  # tronco do cavalo
    for i in range(6):                               # pescoço
        cv.rect(27 + i // 2, 30 - i, 7, 1, C("P", 1))
    cv.blob_rect(33, 21, 12, 8, "P", 2)               # cabeça do cavalo (de lado)
    cv.blob_rect(40, 26, 7, 6, "K", 2)                # focinho
    cv.put(45, 29, PUPIL)
    cv.rect(37, 23, 2, 2, EYE_W); cv.put(38, 24, PUPIL)
    cv.rect(33, 18, 2, 4, C("P", 2))                  # orelha
    for i in range(7):                               # crina
        cv.rect(29 + i // 2, 28 - i, 2, 1, C("W", 2))
    for x in (8, 23):                                # pernas da frente
        cv.blob_rect(x, 36, 4, 7, "P", 1)
        cv.rect(x, 43, 4, 2, C("M", 2))
    cv.blob_rect(13, 24, 9, 6, "A", 2)                # sela / manta
    cv.blob_rect(12, 17, 10, 9, "S", 2)               # tronco do cavaleiro
    cv.blob_rect(14, 28, 4, 8, "A", 1)                # perna do cavaleiro
    cv.rect(13, 35, 6, 2, C("W", 2))                  # bota
    cv.blob_rect(20, 20, 6, 4, "K", 1)                # mão segurando a lança
    cv.line(10, 30, 45, 12, C("W", 1))                # lança
    cv.line(10, 31, 45, 13, C("W", 2))
    cv.rect(44, 9, 3, 4, C("M", 0)); cv.put(46, 8, C("M", 0))
    return fin(cv)


def pernas_saci():
    """uma perna só"""
    cv = new()
    cv.blob_rect(21, 38, 6, 5, "K", 1)
    cv.rect(20, 43, 9, 2, C("K", 2))
    cv.rect(20, 43, 4, 1, C("K", 1))
    return fin(cv)


def corpo_saci():
    """sem camisa, de calção vermelho"""
    cv = new()
    cv.ellipse(24, 32, 8.5, 7.5, "K")
    cv.blob_rect(16, 34, 17, 6, "A", 2)               # calção
    cv.rect(16, 34, 17, 1, C("A", 0))
    return fin(cv)


def cab_saci():
    cv = _cabeca_base(slot="K", rx=10, ry=9.5)
    cv.rect(18, 21, 12, 3, EYE_W)                      # sorrisão
    cv.rect(18, 24, 12, 1, OUT)
    for x in (21, 24, 27):
        cv.put(x, 22, OUT)
    cv.rect(29, 22, 8, 2, C("W", 1))                   # cachimbo
    cv.rect(35, 19, 3, 4, C("W", 2))
    cv.put(36, 17, (220, 220, 220, 200)); cv.put(37, 15, (220, 220, 220, 150))   # fumacinha
    _olhos(cv, 13, 5, 3)
    cv.rect(17, 11, 4, 1, OUT); cv.rect(27, 11, 4, 1, OUT)     # sobrancelha de moleque
    return fin(cv)


def chap_gorro():
    """carapuça vermelha do saci, caída pro lado"""
    cv = new()
    cv.ellipse(24, 8, 10.5, 5, "A")
    for i in range(8):
        cv.rect(29 + i, 3 + i, 5 - i // 3, 2, C("A", 1 if i < 5 else 2))
    cv.ellipse(38, 12, 2.5, 2.5, "A")
    cv.rect(13, 10, 22, 2, C("A", 2))
    return fin(cv)


def quatro_mapinguari():
    """gigante peludo da mata: um olho só e a boca na barriga. Corpo inteiro."""
    cv = new()
    for x in (14, 28):                               # pés
        cv.blob_rect(x, 40, 7, 5, "P", 2)
        for k in range(3):
            cv.put(x + 1 + k * 2, 44, C("M", 0))
    for side in (-1, 1):                             # braços compridos com garra
        ax = 24 + side * 16
        cv.blob_rect(ax - 3, 18, 6, 20, "P", 2)
        for k in (-2, 0, 2):
            cv.rect(ax + k, 38, 1, 3, C("M", 0))
    cv.ellipse(24, 25, 14, 17, "P")                   # corpão
    for (x, y) in ((13, 14), (17, 9), (31, 9), (35, 15), (11, 26), (36, 27), (15, 36), (33, 36), (20, 12), (28, 20), (18, 22)):
        cv.rect(x, y, 1, 3, C("P", 2))                # tufos de pelo
        cv.put(x + 1, y + 1, C("P", 0))
    cv.ellipse(24, 12, 5, 4.5, "K")                   # olhão
    cv.rect(22, 10, 5, 5, EYE_W); cv.rect(23, 11, 3, 3, PUPIL); cv.put(23, 11, SHINE)
    cv.rect(18, 7, 12, 1, OUT)                        # sobrancelha brava
    cv.blob_rect(14, 26, 21, 10, "A", 3)              # bocarra na barriga
    cv.rect(16, 28, 17, 6, (60, 16, 24, 255))
    for x in range(16, 33, 3):                        # dentes
        cv.rect(x, 28, 2, 2, EYE_W); cv.rect(x + 1, 32, 2, 2, EYE_W)
    return fin(cv)


def cab_chama():
    """a mula não tem cabeça: no lugar, fogo"""
    cv = new()
    _flame(cv, 23, 27, 22, 8)
    _flame(cv, 17, 26, 13, 4)
    _flame(cv, 29, 26, 15, 4)
    return fin(cv)


def quatro_cobra():
    """boitatá: cobrona de fogo, corpo em onda, cabeça erguida. Corpo inteiro."""
    cv = new()
    pts = [(3, 41), (7, 38), (11, 36), (15, 38), (19, 41), (23, 40), (27, 36), (30, 31), (32, 26), (34, 21)]
    for i, (x, y) in enumerate(pts):                  # corpo em gomos
        r = 3.2 + min(i, 5) * 0.35
        cv.ellipse(x, y, r, r, "P")
    for i, (x, y) in enumerate(pts[1:-1]):            # losangos nas costas
        if i % 2 == 0:
            cv.put(x, y - 1, C("S", 1)); cv.put(x - 1, y, C("S", 1)); cv.put(x + 1, y, C("S", 1))
    for (x, y) in ((9, 33), (17, 35), (25, 33)):      # fogo nas costas
        _flame(cv, x, y, 6, 2)
    cv.ellipse(37, 17, 7, 5.5, "P")                   # cabeça
    cv.ellipse(38, 20, 5, 2.5, "K")                   # papo claro
    cv.rect(36, 13, 3, 3, FIRE_I); cv.rect(37, 13, 1, 3, PUPIL)       # olho de brasa
    cv.rect(44, 18, 3, 1, FIRE_O); cv.put(47, 17, FIRE_O); cv.put(47, 19, FIRE_O)   # língua
    return fin(cv)


def cab_onca():
    cv = cab_gato()
    fur = [c[:3] for c in (C("P", 0), C("P", 1), C("P", 2))]
    for (x, y) in ((17, 9), (22, 7), (27, 8), (31, 10), (15, 15), (33, 16), (19, 21), (29, 22), (24, 11)):
        if cv.get(x, y)[3] and cv.get(x, y)[:3] in fur:
            cv.put(x, y, C("S", 1))
            if cv.get(x + 1, y)[3] and cv.get(x + 1, y)[:3] in fur:
                cv.put(x + 1, y, C("S", 1))
    return cv


def quatro_onca():
    """onça-pintada: gatão forte, de pintas"""
    cv, top = _quad(20, 32, 12, 6.5, 9, 10, 24, leg_w=4, hoof=False, far_dx=4)
    for (x, y) in ((8, 30), (6, 29), (4, 27), (3, 24), (4, 21), (6, 20)):         # rabo grosso
        cv.rect(x, y, 3, 3, C("P", 1))
    cv.rect(6, 19, 3, 2, C("S", 1))
    cv.ellipse(20, 36, 7, 2.3, "K")
    _front_legs(cv, top, 9, 10, 24, leg_w=4, hoof=False)
    fur = [c[:3] for c in (C("P", 0), C("P", 1), C("P", 2))]
    for (x, y) in ((10, 28), (14, 30), (18, 27), (22, 30), (26, 28), (12, 33), (20, 33), (28, 32), (16, 35), (11, 39), (25, 39), (5, 25)):
        if cv.get(x, y)[3] and cv.get(x, y)[:3] in fur:
            cv.put(x, y, C("S", 1))
            if cv.get(x + 1, y)[3] and cv.get(x + 1, y)[:3] in fur:
                cv.put(x + 1, y, C("S", 1))
    return fin(cv)


# ---- TEMAS NOVOS (19/11): mar, ET e mitologia -- o jogo não é só roça
def quatro_caranguejo():
    """caranguejo gigante: largo, de frente, pinças pra cima. Corpo inteiro."""
    cv = new()
    for side in (-1, 1):
        for k in range(3):                           # perninhas de lado
            x0 = 24 + side * (9 + k * 2)
            cv.line(x0, 36 + k, x0 + side * 6, 42 + k // 2, C("P", 2))
        ax = 24 + side * 15                          # braço da pinça
        cv.line(24 + side * 10, 30, ax, 22, C("P", 2))
        cv.line(24 + side * 10, 31, ax, 23, C("P", 1))
        cv.ellipse(ax, 16, 6, 7, "P")                # pinça
        cv.rect(ax - 1, 9, 2, 8, (0, 0, 0, 0))       # abertura da pinça
        cv.put(ax, 16, C("P", 2))
    cv.ellipse(24, 33, 13, 8.5, "P")                 # casco
    cv.ellipse(24, 37, 9, 3.5, "K")
    for side in (-1, 1):                             # olhos no talo
        ex = 24 + side * 5
        cv.rect(ex, 21, 1, 5, C("P", 2))
        cv.rect(ex - 1, 18, 3, 3, EYE_W); cv.put(ex, 19, PUPIL)
    cv.rect(20, 34, 8, 1, OUT)                       # boca
    for (x, y) in ((14, 29), (33, 29), (18, 27), (29, 27), (24, 28)):
        cv.put(x, y, C("P", 0))
    return fin(cv)


def quatro_polvo():
    """polvo: cabeção e tentáculos enrolados. Corpo inteiro."""
    cv = new()
    for i, (x, sgn) in enumerate(((10, -1), (15, -1), (21, -1), (27, 1), (33, 1), (38, 1))):   # tentáculos
        for k in range(10):
            xx = x + int(round(2.2 * sgn * (1 if (k // 3) % 2 == 0 else -1) * (k / 9.0)))
            cv.rect(xx, 33 + k, 3, 1, C("P", 1 if i % 2 == 0 else 2))
        cv.rect(x + sgn * 2, 43, 3, 2, C("K", 1))    # ponta com ventosa
    cv.ellipse(24, 22, 13, 13, "P")                  # cabeça
    cv.ellipse(18, 14, 4, 3, "K", shade=False)       # brilho
    for side in (-1, 1):
        ex = 24 + side * 6
        cv.rect(ex - 2, 22, 4, 5, EYE_W); cv.rect(ex - 1, 24, 2, 3, PUPIL)
    cv.rect(22, 30, 5, 2, C("P", 2))                 # boquinha
    for (x, y) in ((14, 26), (34, 25), (24, 12), (30, 15)):
        cv.put(x, y, C("K", 1))
    return fin(cv)


def quatro_aguaviva():
    """água-viva: sino translúcido e fios pendurados. Corpo inteiro."""
    cv = new()
    for i, x in enumerate((14, 18, 22, 26, 30, 34)):  # fios
        for k in range(14 + (i % 2) * 3):
            cv.put(x + (1 if (k // 3) % 2 == 0 else 0), 26 + k, C("K" if i % 2 else "P", 1))
    cv.ellipse(24, 18, 13, 10, "P")                  # sino
    cv.rect(11, 22, 27, 6, (0, 0, 0, 0))
    for x in range(11, 38):                          # barra ondulada
        cv.rect(x, 22, 1, 2 + (1 if (x // 3) % 2 == 0 else 0), C("P", 2))
    cv.ellipse(19, 13, 5, 3, "K", shade=False)       # brilho
    for side in (-1, 1):
        ex = 24 + side * 5
        cv.rect(ex - 1, 16, 3, 3, EYE_W); cv.put(ex, 17, PUPIL)
    cv.rect(11, 9, 2, 2, FIRE_I); cv.rect(36, 12, 2, 2, FIRE_I)      # faísca de choque
    return fin(cv)


def quatro_tripe():
    """tripé invasor: três pernas finas, cúpula de vidro e olho de raio. Corpo inteiro."""
    cv = new()
    for (x0, x1) in ((20, 8), (24, 24), (28, 40)):   # pernas
        cv.line(x0, 22, x1, 43, C("M", 2))
        cv.line(x0 + 1, 22, x1 + 1, 43, C("M", 1))
        cv.rect(x1 - 2, 43, 6, 2, C("M", 2))
    cv.ellipse(24, 17, 13, 6, "M")                   # disco
    cv.ellipse(24, 11, 8, 7, "S")                    # cúpula
    cv.ellipse(21, 8, 3, 2, "K", shade=False)
    cv.rect(13, 17, 22, 2, C("M", 2))
    for x in (15, 20, 25, 30):                       # luzinhas
        cv.rect(x, 18, 2, 1, FIRE_M)
    cv.ellipse(24, 23, 3, 2.5, "A")                  # canhão de raio embaixo
    cv.put(24, 24, FIRE_I)
    return fin(cv)


def quatro_dragao():
    """dragãozinho: asa aberta, barrigão, focinho soltando fumaça. Corpo inteiro."""
    cv = new()
    for i in range(12):                              # asa de trás
        cv.rect(6 + i, 8 + abs(6 - i), 2, 12 - abs(6 - i) // 2, C("S", 2))
    for i in range(7):                               # rabo
        cv.rect(3 + i, 36 - i // 2, 3, 3, C("P", 2))
    cv.rect(1, 37, 3, 2, C("A", 1)); cv.put(0, 36, C("A", 1))
    cv.ellipse(20, 30, 11, 9, "P")                   # corpo
    cv.ellipse(21, 33, 6.5, 5.5, "K")                # barriga
    for y in (30, 33, 36):
        cv.rect(17, y, 8, 1, C("K", 2))
    for x in (15, 23):                               # patinhas
        cv.blob_rect(x, 38, 5, 6, "P", 2)
    for i in range(6):                               # pescoço
        cv.rect(26 + i, 24 - i, 6, 3, C("P", 1))
    cv.blob_rect(30, 11, 14, 10, "P", 3)             # cabeça
    cv.blob_rect(38, 15, 8, 6, "P", 2)               # focinho
    cv.rect(33, 13, 3, 3, FIRE_I); cv.rect(34, 13, 1, 3, PUPIL)
    cv.put(44, 16, PUPIL)
    for x in (31, 35):                               # chifrinhos
        cv.rect(x, 7, 2, 4, C("M", 0))
    _flame(cv, 46, 21, 4, 1)
    for i in range(10):                              # asa da frente
        cv.rect(10 + i, 12 + abs(5 - i), 2, 9 - abs(5 - i) // 2, C("S", 1))
    cv.rect(10, 12, 11, 1, C("S", 0))
    return fin(cv)


def quatro_cerbero():
    """cérbero: cachorrão de três cabeças. Corpo inteiro."""
    cv, top = _quad(17, 33, 12, 7, 9, 7, 21, leg_w=4, hoof=False, far_dx=4)
    for i in range(6):                               # rabo de ponta de flecha
        cv.put(4 - i // 2, 30 - i, C("P", 2)); cv.put(5 - i // 2, 30 - i, C("P", 1))
    cv.rect(0, 22, 4, 3, C("A", 1))
    _front_legs(cv, top, 9, 7, 21, leg_w=4, hoof=False)
    cv.rect(18, 26, 14, 3, C("A", 1))                # coleira de espinhos
    for x in (19, 23, 27):
        cv.put(x, 25, C("M", 0))
    for (hx, hy) in ((27, 14), (38, 20), (30, 30)):  # três cabeças
        cv.ellipse(hx, hy, 6.5, 5.5, "P")
        cv.blob_rect(hx + 3, hy, 7, 5, "P", 2)       # focinho
        cv.rect(hx + 4, hy + 3, 5, 1, EYE_W)         # dentes
        cv.put(hx + 9, hy + 1, PUPIL)
        cv.rect(hx - 1, hy - 3, 3, 2, FIRE_M); cv.put(hx, hy - 2, PUPIL)      # olho bravo
        cv.rect(hx - 5, hy - 6, 3, 4, C("P", 2))     # orelha
    return fin(cv)


def cab_tubarao():
    cv = new()
    cv.ellipse(24, 17, 11, 10, "P")
    for i in range(7):                               # barbatana em cima
        cv.rect(22 + i // 2, 2 + i, 6 - i // 2, 1, C("P", 2 if i > 2 else 1))
    cv.ellipse(24, 21, 9, 6, "K")                    # papo branco
    cv.rect(16, 21, 16, 4, (60, 16, 24, 255))        # bocão
    for x in range(16, 32, 3):                       # dentes serrilhados
        cv.rect(x, 21, 2, 1, EYE_W); cv.put(x, 22, EYE_W)
        cv.rect(x + 1, 24, 2, 1, EYE_W)
    for side in (-1, 1):
        ex = 24 + side * 7
        cv.rect(ex - 1, 12, 3, 3, EYE_W); cv.rect(ex, 13, 2, 2, PUPIL)
        for k in range(3):                           # guelras
            cv.put(24 + side * 10, 17 + k * 2, C("P", 2))
    cv.rect(17, 10, 4, 1, OUT); cv.rect(27, 10, 4, 1, OUT)
    return fin(cv)


def cab_medusa():
    cv = _cabeca_base(slot="K", rx=9.5, ry=9)
    for (x, y, dx) in ((12, 9, -1), (15, 5, -1), (20, 3, 0), (26, 3, 0), (31, 5, 1), (34, 9, 1), (10, 15, -1), (36, 15, 1)):   # cobras
        for k in range(5):
            cv.rect(x + dx * (k // 2) + (1 if k % 2 else 0), y - k + 2, 2, 1, C("P", 1 if k < 3 else 0))
        hx = x + dx * 2
        cv.rect(hx, y - 4, 3, 2, C("P", 0)); cv.put(hx + 1, y - 4, FIRE_O)
    for side in (-1, 1):                             # olhar de pedra
        ex = 24 + side * 5
        cv.rect(ex - 1, 14, 3, 3, FIRE_I); cv.rect(ex, 14, 1, 3, PUPIL)
    cv.rect(17, 12, 4, 1, OUT); cv.rect(27, 12, 4, 1, OUT)
    cv.rect(21, 22, 6, 1, OUT); cv.put(20, 21, OUT); cv.put(27, 21, OUT)
    return fin(cv)


def cab_peixe():
    """peixe-palhaço: cara redonda, listras e boquinha aberta"""
    cv = _cabeca_base(rx=11, ry=10)
    fur = [c[:3] for c in (C("P", 0), C("P", 1), C("P", 2))]
    for x0 in (15, 30):                              # listras brancas
        for y in range(7, 28):
            for x in range(x0, x0 + 3):
                if cv.get(x, y)[3] and cv.get(x, y)[:3] in fur:
                    cv.put(x, y, EYE_W)
    for i in range(5):                               # barbatana de cima
        cv.rect(21 + i, 4 + abs(2 - i), 2, 3, C("P", 2))
    cv.ellipse(24, 22, 3, 2.5, "K")                  # boca
    cv.rect(23, 22, 3, 1, OUT)
    _olhos(cv, 13, 6, 3)
    return fin(cv)


def cab_polvo():
    """cabeça de polvo: bolota lisa com tentaculozinhos no queixo"""
    cv = _cabeca_base(rx=11, ry=10, cy=15)
    for x in (15, 19, 23, 27, 31):
        cv.rect(x, 24, 2, 4, C("P", 2))
        cv.put(x, 28, C("K", 1))
    cv.ellipse(19, 9, 4, 2.5, "K", shade=False)
    for side in (-1, 1):
        ex = 24 + side * 5
        cv.rect(ex - 1, 14, 3, 4, EYE_W); cv.rect(ex, 15, 2, 3, PUPIL)
    return fin(cv)


# ---- CABEÇAS dos temas novos (19/11): pro criador de cartas ter com o que variar
def cab_siri():
    cv = _cabeca_base(rx=12, ry=8, cy=19)
    for side in (-1, 1):                             # olhos no talo e pontas do casco
        ex = 24 + side * 5
        cv.rect(ex, 6, 1, 6, C("P", 2))
        cv.rect(ex - 1, 3, 3, 3, EYE_W); cv.put(ex, 4, PUPIL)
        cv.rect(24 + side * 12 - (1 if side > 0 else 0), 17, 2, 2, C("P", 0))
    cv.rect(19, 22, 10, 1, OUT)
    for x in (16, 20, 24, 28, 32):
        cv.put(x, 14, C("P", 0))
    return fin(cv)


def cab_baleia():
    cv = _cabeca_base(rx=12, ry=10)
    cv.ellipse(24, 22, 10, 5, "K")                   # barrigão claro
    for x in range(16, 33, 2):
        cv.rect(x, 20, 1, 6, C("K", 2))
    cv.rect(23, 3, 2, 4, (150, 220, 250, 255))       # esguicho
    cv.rect(20, 1, 2, 3, (150, 220, 250, 255)); cv.rect(26, 1, 2, 3, (150, 220, 250, 255))
    _olhos(cv, 13, 8, 2)
    return fin(cv)


def cab_cavalo_marinho():
    cv = _cabeca_base(rx=8, ry=9, cy=15)
    cv.blob_rect(19, 18, 10, 9, "P", 3)              # focinho comprido pra baixo
    cv.rect(22, 26, 4, 2, C("P", 2))
    for i in range(5):                               # crista
        cv.rect(22 + i, 3 + (i % 2), 2, 3, C("A", 1))
    for side in (-1, 1):                             # barbatana de orelha
        cv.rect(24 + side * 9 - 1, 13, 3, 4, C("A", 1))
    _olhos(cv, 12, 4, 3)
    return fin(cv)


def cab_tartaruga():
    cv = _cabeca_base(slot="K", rx=10, ry=9, cy=18)
    cv.rect(18, 23, 12, 1, OUT)                      # boca reta de velha sábia
    cv.put(17, 22, OUT); cv.put(30, 22, OUT)
    for (x, y) in ((16, 12), (31, 12), (24, 10)):
        cv.put(x, y, C("K", 2))
    _olhos(cv, 15, 5, 3, sono=True)
    return fin(cv)


def cab_macaco():
    cv = _cabeca_base(rx=10, ry=9.5)
    for side in (-1, 1):                             # orelhonas
        cv.ellipse(24 + side * 11, 17, 3.5, 4, "P")
        cv.ellipse(24 + side * 11, 17, 2, 2.5, "K")
    cv.ellipse(24, 20, 7.5, 6, "K")                  # cara clara
    cv.ellipse(24, 13, 6.5, 4, "K")
    cv.rect(22, 20, 1, 1, OUT); cv.rect(25, 20, 1, 1, OUT)
    cv.rect(20, 23, 8, 1, OUT)
    _olhos(cv, 12, 4, 3)
    return fin(cv)


def cab_arara():
    cv = _cabeca_base(rx=10, ry=10)
    cv.ellipse(24, 16, 8, 6, "K", shade=False)       # máscara branca
    cv.blob_rect(20, 17, 8, 9, "A", 3)               # bicão curvo
    cv.rect(22, 24, 4, 3, C("A", 2))
    cv.rect(23, 20, 2, 1, OUT)
    for i in range(4):                               # penacho
        cv.rect(21 + i * 2, 3 + (i % 2), 2, 4, C("S", 1))
    _olhos(cv, 12, 6, 3)
    return fin(cv)


def cab_tamandua():
    cv = _cabeca_base(rx=9, ry=8, cy=13)
    cv.blob_rect(20, 15, 8, 14, "P", 3)              # focinhão comprido
    cv.rect(22, 28, 4, 1, PUPIL)
    cv.rect(21, 17, 6, 2, C("S", 1))                 # faixa escura
    for side in (-1, 1):
        cv.rect(24 + side * 8 - 1, 5, 3, 4, C("P", 2))
    _olhos(cv, 11, 5, 2)
    return fin(cv)


def cab_preguica():
    cv = _cabeca_base(rx=11, ry=10)
    cv.ellipse(24, 18, 8, 7, "K")                    # cara clara
    for side in (-1, 1):                             # olheira caída
        ex = 24 + side * 5
        cv.rect(ex - 2, 15, 5, 3, C("S", 1))
        cv.rect(ex - 1, 16, 3, 1, PUPIL)
    cv.rect(23, 20, 3, 2, PUPIL)                     # nariz
    for x in range(20, 29):                          # sorriso tranquilo
        cv.put(x, 23 + (1 if 22 <= x <= 26 else 0), OUT)
    return fin(cv)


def cab_cobra():
    cv = new()
    cv.ellipse(24, 16, 10, 9, "P")
    cv.ellipse(24, 21, 7, 4, "K")
    for (x, y) in ((18, 9), (24, 7), (30, 9), (21, 12), (27, 12)):   # losangos
        cv.put(x, y, C("S", 1)); cv.put(x + 1, y, C("S", 1))
    for side in (-1, 1):
        ex = 24 + side * 5
        cv.rect(ex - 1, 13, 3, 3, FIRE_I); cv.rect(ex, 13, 1, 3, PUPIL)
    cv.rect(23, 25, 2, 4, (220, 60, 80, 255))        # língua bifurcada
    cv.put(22, 29, (220, 60, 80, 255)); cv.put(25, 29, (220, 60, 80, 255))
    return fin(cv)


def cab_ciclope():
    cv = _cabeca_base(slot="K", rx=11, ry=10)
    cv.rect(20, 11, 8, 7, EYE_W)                     # olhão único
    cv.rect(22, 13, 4, 4, PUPIL); cv.put(22, 13, SHINE)
    cv.rect(17, 8, 14, 2, OUT)                       # sobrancelhão
    cv.rect(19, 22, 10, 2, (60, 16, 24, 255))
    for x in (20, 24, 27):
        cv.put(x, 22, EYE_W)
    cv.rect(23, 3, 3, 4, C("M", 0))                  # chifrinho
    return fin(cv)


def cab_elmo():
    """guerreiro de elmo grego: crista vermelha, fenda nos olhos"""
    cv = _cabeca_base(slot="M", rx=10.5, ry=10)
    cv.rect(22, 12, 4, 14, (40, 30, 36, 255))        # fenda do nariz
    cv.rect(15, 13, 18, 3, (40, 30, 36, 255))        # fenda dos olhos
    for side in (-1, 1):
        cv.rect(24 + side * 5 - 1, 14, 2, 1, EYE_W)
    for i in range(11):                              # crista
        cv.rect(18 + i, 2 + abs(5 - i) // 3, 2, 5, C("A", 1 if i % 2 else 0))
    return fin(cv)


def cab_lobisomem():
    cv = _cabeca_base(rx=10, ry=9.5)
    for side in (-1, 1):                             # orelha pontuda
        for i in range(6):
            cv.rect(24 + side * 8 - (1 if side > 0 else 0), 2 + i, 1 + i // 2, 1, C("P", 2))
    cv.blob_rect(19, 17, 10, 9, "S", 3)              # focinho
    cv.rect(22, 17, 4, 2, PUPIL)
    cv.rect(20, 23, 8, 1, (60, 16, 24, 255))
    for x in (20, 23, 26):                           # presas
        cv.rect(x, 23, 1, 2, EYE_W)
    for side in (-1, 1):
        ex = 24 + side * 5
        cv.rect(ex - 1, 12, 3, 2, FIRE_M); cv.put(ex, 12, PUPIL)
    cv.rect(17, 10, 5, 1, OUT); cv.rect(26, 10, 5, 1, OUT)
    return fin(cv)


def cab_curupira():
    cv = _cabeca_base(slot="K", rx=10, ry=9.5)
    _flame(cv, 24, 11, 10, 9)                         # cabelo de fogo
    _flame(cv, 17, 11, 6, 3); _flame(cv, 31, 11, 7, 3)
    cv.rect(20, 22, 8, 1, OUT); cv.put(19, 21, OUT); cv.put(28, 21, OUT)
    cv.put(17, 20, BLUSH); cv.put(30, 20, BLUSH)
    _olhos(cv, 14, 5, 3)
    return fin(cv)


def cab_marciano():
    cv = _cabeca_base(rx=11, ry=9, cy=16)
    for ex in (17, 24, 31):                          # três olhos
        cv.rect(ex - 1, 12, 3, 4, EYE_W); cv.rect(ex, 13, 1, 2, PUPIL)
    for side in (-1, 1):                             # antenas de bolinha
        cv.line(24 + side * 6, 8, 24 + side * 9, 2, C("P", 2))
        cv.rect(24 + side * 9 - 1, 0, 3, 3, C("A", 0))
    cv.rect(21, 21, 6, 1, OUT)
    return fin(cv)


PECAS["quatro"] = {"casco": quatro_casco, "malhado": quatro_malhado, "pata": quatro_pata, "rasteiro": quatro_rasteiro,
                   "casca": quatro_casca, "sapo": quatro_sapo,
                   "cavalo": quatro_cavalo, "bezerro": quatro_bezerro, "vaca": quatro_vaca, "bode": quatro_bode,
                   "jegue": quatro_jegue, "cachorro": quatro_cachorro, "capivara": quatro_capivara,
                   "porco": quatro_porco, "gato": quatro_gato,
                   "formiga": quatro_formiga, "montado": quatro_montado, "mapinguari": quatro_mapinguari,
                   "cobra": quatro_cobra, "onca": quatro_onca,
                   "caranguejo": quatro_caranguejo, "polvo": quatro_polvo, "aguaviva": quatro_aguaviva,
                   "tripe": quatro_tripe, "dragao": quatro_dragao, "cerbero": quatro_cerbero}
PECAS["pernas"]["saci"] = pernas_saci
PECAS["corpo"]["saci"] = corpo_saci
PECAS["cabeca"].update({"saci": cab_saci, "chama": cab_chama, "onca": cab_onca, "tubarao": cab_tubarao, "medusa": cab_medusa,
                        "peixe": cab_peixe, "polvo": cab_polvo, "siri": cab_siri, "baleia": cab_baleia,
                        "cavalo_marinho": cab_cavalo_marinho, "tartaruga": cab_tartaruga, "macaco": cab_macaco, "arara": cab_arara,
                        "tamandua": cab_tamandua, "preguica": cab_preguica, "cobra": cab_cobra, "ciclope": cab_ciclope,
                        "elmo": cab_elmo, "lobisomem": cab_lobisomem, "curupira": cab_curupira, "marciano": cab_marciano})
PECAS["chapeu"]["gorro"] = chap_gorro
# onde a cabeça (e o chapéu) encaixam em cada postura
QUATRO_CABECA = {"casco": (10, 6), "malhado": (10, 6), "pata": (10, 8), "rasteiro": (11, 12), "casca": (11, 11), "sapo": (0, 9),
                 "cavalo": (12, 0), "bezerro": (9, 10), "vaca": (11, 5), "bode": (10, 7), "jegue": (10, 5),
                 "cachorro": (11, 8), "capivara": (10, 8), "porco": (10, 7), "gato": (11, 9),
                 "montado": (-7, -4), "onca": (11, 8)}
# carga nas costas (cesto do jegue): vai em cima do lombo, atrás da cabeça
QUATRO_COSTAS = {"casco": (8, -6), "malhado": (8, -6), "pata": (8, -4), "jegue": (8, -7), "cavalo": (6, -10), "vaca": (7, -8)}


def montar(receita, paleta):
    """receita = {categoria: nome}; devolve Image 48x48 já recolorida"""
    cv = Canvas()
    q = receita.get("quatro")
    if q:
        cv.paste(PECAS["quatro"][q]())
        if receita.get("costas") and q in QUATRO_COSTAS:
            cv.paste(PECAS["costas"][receita["costas"]](), *QUATRO_COSTAS[q])
        dx, dy = QUATRO_CABECA.get(q, (0, 0))
        for cat in ("cabeca", "chapeu"):
            if receita.get(cat):
                cv.paste(PECAS[cat][receita[cat]](), dx, dy)
        return recolor(cv.img, paleta)
    for cat in ORDEM:
        nome = receita.get(cat)
        if not nome:
            continue
        cv.paste(PECAS[cat][nome]())
    return recolor(cv.img, paleta)
