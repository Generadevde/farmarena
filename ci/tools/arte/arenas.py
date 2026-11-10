"""Gera os 7 cenários de arena (um por faixa de troféu) em Resources/arena/arena_bg_<n>.png
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
    3: dict(nome="Milharal", G1=(150, 182, 70), G2=(172, 172, 62), G3=(112, 136, 48),
            DIRT=[(206, 168, 110), (186, 146, 92), (160, 122, 74)], decor="milho"),
    4: dict(nome="Brejo", G1=(72, 132, 92), G2=(62, 118, 86), G3=(44, 92, 68),
            DIRT=[(124, 108, 84), (106, 92, 70), (88, 76, 58)], WATER=[(104, 158, 116), (78, 132, 98), (56, 106, 82)], FOAM=(160, 200, 160), decor="vitoria"),
    5: dict(nome="Vila da Feira", G1=(192, 182, 162), G2=(178, 168, 150), G3=(140, 130, 116),
            DIRT=[(204, 124, 84), (184, 104, 68), (152, 84, 56)], decor="bandeirinha"),
    6: dict(nome="Noite Estranha", G1=(62, 72, 124), G2=(54, 62, 110), G3=(36, 42, 84),
            DIRT=[(112, 98, 134), (94, 82, 114), (76, 66, 96)], WATER=[(124, 240, 172), (84, 212, 152), (52, 172, 132)], FOAM=(204, 255, 224),
            WOOD=[(120, 104, 140), (94, 80, 112), (66, 56, 84)], decor="circulo"),
    7: dict(nome="Arena do Rodeio", G1=(216, 172, 98), G2=(206, 160, 88), G3=(170, 126, 66),
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
sheet = Image.new("RGB", (A.PW * 7 + 6 * 4, A.PH), (20, 20, 20))
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
