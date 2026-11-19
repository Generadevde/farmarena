"""Gera os 12 cenários de arena (um por faixa de troféu) em Resources/arena/arena_bg_<n>.png
    python3 ci/tools/arte/arenas.py
Todos têm exatamente o mesmo traçado (rio, 3 pontes, caminhos) -- só muda o tema.
"""
import os, random, math
from PIL import Image
import arena as A

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
DEF = dict(G1=A.G1, G2=A.G2, G3=A.G3, DIRT=A.DIRT, WATER=A.WATER, FOAM=A.FOAM, WOOD=A.WOOD)
THEMES = {
    1: dict(nome="Pasto Verde"),
    2: dict(nome="Curral Velho", G1=(198, 172, 112), G2=(184, 158, 100), G3=(150, 124, 76),
            DIRT=[(150, 110, 74), (132, 94, 60), (110, 76, 48)], decor="feno"),
    3: dict(nome="Terreiro", G1=(214, 190, 150), G2=(202, 178, 138), G3=(168, 142, 104),
            DIRT=[(176, 136, 96), (158, 118, 80), (132, 96, 64)], decor="ovo"),
    4: dict(nome="Milharal", G1=(150, 182, 70), G2=(172, 172, 62), G3=(112, 136, 48),
            DIRT=[(206, 168, 110), (186, 146, 92), (160, 122, 74)], decor="milho"),
    5: dict(nome="Brejo", G1=(72, 132, 92), G2=(62, 118, 86), G3=(44, 92, 68),
            DIRT=[(124, 108, 84), (106, 92, 70), (88, 76, 58)], WATER=[(104, 158, 116), (78, 132, 98), (56, 106, 82)], FOAM=(160, 200, 160), decor="vitoria"),
    6: dict(nome="Vila da Feira", G1=(192, 182, 162), G2=(178, 168, 150), G3=(140, 130, 116),
            DIRT=[(204, 124, 84), (184, 104, 68), (152, 84, 56)], decor="bandeirinha"),
    7: dict(nome="Praia da Maré", G1=(238, 218, 160), G2=(228, 206, 146), G3=(196, 172, 116),
            DIRT=[(250, 236, 196), (240, 222, 176), (214, 194, 148)], WATER=[(96, 208, 232), (56, 172, 214), (36, 132, 188)], FOAM=(240, 252, 255),
            WOOD=[(196, 150, 96), (164, 118, 70), (120, 84, 48)], decor="concha"),
    8: dict(nome="Mata Fechada", G1=(46, 118, 62), G2=(38, 104, 54), G3=(24, 76, 40),
            DIRT=[(104, 84, 52), (88, 70, 42), (68, 54, 32)], WATER=[(88, 150, 132), (60, 122, 108), (40, 96, 86)], FOAM=(170, 214, 190), decor="flor"),
    9: dict(nome="Noite Estranha", G1=(62, 72, 124), G2=(54, 62, 110), G3=(36, 42, 84),
            DIRT=[(112, 98, 134), (94, 82, 114), (76, 66, 96)], WATER=[(124, 240, 172), (84, 212, 152), (52, 172, 132)], FOAM=(204, 255, 224),
            WOOD=[(120, 104, 140), (94, 80, 112), (66, 56, 84)], decor="circulo"),
    10: dict(nome="Encruzilhada", G1=(92, 78, 104), G2=(82, 68, 94), G3=(58, 46, 70),
             DIRT=[(132, 96, 84), (112, 78, 68), (88, 60, 52)], WATER=[(120, 110, 160), (92, 84, 136), (68, 60, 108)], FOAM=(196, 188, 226),
             WOOD=[(96, 76, 64), (74, 58, 48), (52, 40, 34)], decor="vela"),
    11: dict(nome="Monte dos Mitos", G1=(222, 224, 232), G2=(208, 212, 222), G3=(168, 174, 190),
             DIRT=[(244, 226, 168), (232, 208, 140), (200, 172, 104)], WATER=[(140, 196, 250), (104, 164, 236), (76, 128, 208)], FOAM=(250, 252, 255),
             WOOD=[(240, 236, 226), (214, 208, 196), (170, 164, 152)], decor="louro"),
    12: dict(nome="Arena do Rodeio", G1=(216, 172, 98), G2=(206, 160, 88), G3=(170, 126, 66),
             DIRT=[(242, 212, 152), (228, 194, 132), (202, 168, 110)], WOOD=[(200, 70, 60), (236, 228, 214), (120, 40, 36)], decor="estrela"),
}


def decorate(img, kind, seed):
    px = img.load()
    rnd = random.Random(seed)
    W, H, CY = A.PW, A.PH, A.CY
    grass = lambda x, y: px[x, y] in (A.G1, A.G2)

    def mset(x, y, c):
        for yy in (y, H - 1 - y):
            if 2 <= x < W - 2 and 2 <= yy < H - 2:
                px[x, yy] = c

    def free(x, y, r):
        return all(2 <= x + dx < W - 2 and 2 <= y + dy < H - 2 and grass(x + dx, y + dy) for dx in range(-r, r + 1) for dy in range(-r, r + 1))

    tries = 0
    placed = 0
    while placed < 14 and tries < 600:
        tries += 1
        x = rnd.randrange(6, W - 6)
        y = rnd.randrange(CY + 10, H - 8)
        if not free(x, y, 3):
            continue
        placed += 1
        if kind == "feno":
            for dx in range(-2, 3):
                for dy in range(-1, 2):
                    mset(x + dx, y + dy, (232, 200, 96) if dy < 1 else (196, 160, 70))
            mset(x, y, (170, 60, 50))
        elif kind == "milho":
            for k in range(5):
                mset(x, y - k + 2, (86, 146, 48) if k < 4 else (244, 204, 72))
            mset(x + 1, y, (112, 172, 62)); mset(x - 1, y + 1, (112, 172, 62))
        elif kind == "vitoria":
            for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1)):
                mset(x + dx, y + dy, (96, 170, 110))
            mset(x, y, (250, 180, 200))
        elif kind == "bandeirinha":
            c = rnd.choice([(230, 70, 70), (70, 130, 230), (250, 210, 70), (90, 190, 110)])
            mset(x, y - 1, (90, 70, 60)); mset(x, y, (90, 70, 60)); mset(x + 1, y - 1, c); mset(x + 2, y - 1, c); mset(x + 1, y, c)
        elif kind == "circulo":
            for a in range(0, 360, 30):
                mset(int(x + math.cos(math.radians(a)) * 3), int(y + math.sin(math.radians(a)) * 3), (150, 250, 190))
            mset(x, y, (230, 255, 240))
        elif kind == "ovo":
            for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1), (0, -1)):
                mset(x + dx, y + dy, (252, 248, 236))
            mset(x + 3, y + 1, (236, 96, 60)); mset(x - 2, y, (250, 220, 90))
        elif kind == "concha":
            for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, -1), (1, -1), (-1, -1)):
                mset(x + dx, y + dy, (252, 196, 190))
            mset(x, y + 1, (232, 150, 150)); mset(x + 3, y, (96, 190, 180))
        elif kind == "flor":
            for dx, dy in ((0, -1), (1, 0), (-1, 0), (0, 1)):
                mset(x + dx, y + dy, rnd.choice([(250, 96, 150), (250, 210, 70), (170, 110, 240)]))
            mset(x, y, (252, 250, 220)); mset(x + 2, y + 2, (28, 92, 44)); mset(x - 2, y + 1, (28, 92, 44))
        elif kind == "vela":
            mset(x, y, (236, 230, 214)); mset(x, y + 1, (236, 230, 214)); mset(x, y - 1, (255, 190, 70)); mset(x, y - 2, (255, 236, 150))
            mset(x + 2, y + 1, (40, 30, 48)); mset(x - 2, y + 1, (40, 30, 48))
        elif kind == "louro":
            for k in range(-2, 3):
                mset(x + k, y + abs(k) - 1, (212, 176, 60))
            mset(x, y - 2, (250, 236, 150)); mset(x, y + 2, (150, 156, 172))
        elif kind == "estrela":
            for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
                mset(x + dx, y + dy, (250, 236, 200))
            mset(x, y, (200, 70, 60))
    if kind == "circulo":      # estrelinhas no chão da noite
        for _ in range(60):
            x = rnd.randrange(3, W - 3); y = rnd.randrange(CY + 8, H - 3)
            if grass(x, y):
                mset(x, y, (220, 225, 255))


os.makedirs(os.path.join(ROOT, "Resources", "arena"), exist_ok=True)
sheet = Image.new("RGB", (A.PW * 12 + 11 * 4, A.PH), (20, 20, 20))
for n, th in THEMES.items():
    for k, v in DEF.items():
        setattr(A, k, th.get(k, v))
    img = A.build(seed=7 + n)
    if th.get("decor"):
        decorate(img, th["decor"], 100 + n)
    img.save(os.path.join(ROOT, "Resources", "arena", "arena_bg_%d.png" % n))
    sheet.paste(img, ((n - 1) * (A.PW + 4), 0))
sheet = sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST)
sheet.save("/tmp/arenas.png")
print("ok")
