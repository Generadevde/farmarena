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
