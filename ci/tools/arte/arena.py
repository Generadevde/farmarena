"""Gera o cenário da arena 2.0 (144x240 px, usado ampliado 4x = 576x960 no jogo).
Simétrico de cima pra baixo: metade de baixo = jogador, de cima = bot.
As medidas batem com Scripts/arena_builder.gd (lá em unidades de mundo = px*4).
"""
from PIL import Image
import random, math, sys

PW, PH = 144, 240
CX, CY = PW // 2, PH // 2
RIVER_HALF = 5          # rio: linhas CY-5 .. CY+4  (mundo ±20)
BRIDGE_X = 37.5         # pontes em CX±37.5 (mundo ±150)
BRIDGE_HALF = 7         # largura 14px (mundo 56)
CENTER_BRIDGE_HALF = 4  # ponte do meio, mais estreita: 8px (mundo 32)
TOWER_DX = 33.75        # torres em CX±33.75 (mundo ±135)
TOWER_DY = 95           # torres em CY±95 (mundo ±380)

G1 = (118, 176, 72)   # grama clara
G2 = (104, 160, 62)   # grama escura (faixa de corte)
G3 = (86, 138, 52)    # sombra/borda
DIRT = [(196, 156, 104), (178, 138, 88), (160, 120, 74)]
WATER = [(92, 170, 220), (70, 148, 204), (52, 120, 182)]
FOAM = (196, 232, 246)
WOOD = [(176, 122, 72), (142, 94, 52), (104, 66, 36)]
OUT = (42, 26, 34)


def build(seed=7):
    rnd = random.Random(seed)
    img = Image.new("RGB", (PW, PH), G1)
    px = img.load()

    # grama em faixas largas alternadas (cara de campo aparado)
    for y in range(PH):
        for x in range(PW):
            band = ((x // 12) + (y // 12)) % 2
            c = G1 if band == 0 else G2
            if rnd.random() < 0.06:
                c = tuple(max(0, v - 10) for v in c)
            px[x, y] = c

    def mirror_set(x, y, c):
        if 0 <= x < PW and 0 <= y < PH:
            px[x, y] = c
        my = PH - 1 - y
        if 0 <= x < PW and 0 <= my < PH:
            px[x, my] = c

    # caminhos de terra: da torre até a ponte, dos dois lados (espelhado)
    for side_x in (-1, 1):
        bx = CX + side_x * BRIDGE_X
        tx = CX + side_x * TOWER_DX
        for y in range(CY + RIVER_HALF, int(CY + TOWER_DY) + 12):
            t = (y - (CY + RIVER_HALF)) / (TOWER_DY + 12 - RIVER_HALF)
            x_center = bx + (tx - bx) * t
            half = 5
            for x in range(int(x_center - half - 1), int(x_center + half + 2)):
                d = abs(x + 0.5 - x_center)
                if d <= half:
                    c = DIRT[0] if d < half - 2 else DIRT[1]
                    if rnd.random() < 0.08:
                        c = DIRT[2]
                    mirror_set(x, y, c)
                elif d <= half + 1:
                    mirror_set(x, y, G3)

    # caminho do meio: sai da ponte central, desce e se divide em "Y" até
    # os caminhos das duas torres
    fork_y = CY + 30
    for y in range(CY + RIVER_HALF, fork_y + 1):
        for x in range(CX - 4, CX + 4):
            c = DIRT[0] if abs(x + 0.5 - CX) < 2.5 else DIRT[1]
            mirror_set(x, y, c)
        mirror_set(CX - 5, y, G3)
        mirror_set(CX + 4, y, G3)
    for side_x in (-1, 1):
        target_x = CX + side_x * (BRIDGE_X + (TOWER_DX - BRIDGE_X) * 0.55)
        target_y = CY + RIVER_HALF + int((TOWER_DY + 12 - RIVER_HALF) * 0.55)
        steps = 60
        for i in range(steps + 1):
            t = i / steps
            x_c = CX + (target_x - CX) * t
            y_c = fork_y + (target_y - fork_y) * t
            for dx in range(-3, 4):
                for dy in range(-1, 2):
                    c = DIRT[0] if abs(dx) < 2 else DIRT[1]
                    if rnd.random() < 0.05:
                        c = DIRT[2]
                    mirror_set(int(x_c) + dx, int(y_c) + dy, c)

    # base de terra embaixo de cada torre (círculo batido)
    for side_x in (-1, 1):
        tx = CX + side_x * TOWER_DX
        ty = CY + TOWER_DY
        for y in range(int(ty - 12), int(ty + 13)):
            for x in range(int(tx - 12), int(tx + 13)):
                d = math.hypot(x + 0.5 - tx, y + 0.5 - ty)
                if d <= 10.5:
                    c = DIRT[0] if d < 8 else DIRT[1]
                    if rnd.random() < 0.06:
                        c = DIRT[2]
                    mirror_set(x, y, c)
                elif d <= 11.5:
                    mirror_set(x, y, G3)

    # rio no meio (com espuma nas margens e brilho)
    for y in range(CY - RIVER_HALF - 1, CY + RIVER_HALF + 1):
        for x in range(PW):
            edge = y in (CY - RIVER_HALF - 1, CY + RIVER_HALF)
            if edge:
                px[x, y] = (70, 112, 46)  # margem
                continue
            wave = math.sin(x * 0.45 + y * 1.3)
            c = WATER[1]
            if wave > 0.75:
                c = WATER[0]
            elif wave < -0.7:
                c = WATER[2]
            if y in (CY - RIVER_HALF, CY + RIVER_HALF - 1) and rnd.random() < 0.35:
                c = FOAM
            px[x, y] = c

    # pontes de madeira (tábuas na vertical, corrimão nas bordas)
    for side_x in (-1, 1):
        bx = CX + side_x * BRIDGE_X
        for y in range(CY - RIVER_HALF - 2, CY + RIVER_HALF + 2):
            for x in range(int(bx - BRIDGE_HALF), int(bx + BRIDGE_HALF)):
                rel = x - int(bx - BRIDGE_HALF)
                if rel in (0, 2 * BRIDGE_HALF - 1):
                    c = OUT
                elif rel in (1, 2 * BRIDGE_HALF - 2):
                    c = WOOD[2]
                else:
                    c = WOOD[0] if (y % 3) else WOOD[1]
                    if rel % 4 == 0 and y % 3 == 1:
                        c = WOOD[2]  # pregos
                px[x, y] = c

    # ponte do meio (estreita, de corda e tábua)
    for y in range(CY - RIVER_HALF - 2, CY + RIVER_HALF + 2):
        for x in range(CX - CENTER_BRIDGE_HALF, CX + CENTER_BRIDGE_HALF):
            rel = x - (CX - CENTER_BRIDGE_HALF)
            if rel in (0, 2 * CENTER_BRIDGE_HALF - 1):
                c = OUT
            elif y % 2 == 0:
                c = WOOD[0]
            else:
                c = WOOD[2] if rel in (1, 2 * CENTER_BRIDGE_HALF - 2) else WOOD[1]
            px[x, y] = c

    # cerca em volta do campo (só nas laterais e pontas, sem atrapalhar)
    for y in range(PH):
        for x in (0, 1, PW - 2, PW - 1):
            px[x, y] = WOOD[1] if (y % 6) else WOOD[2]
        if y % 6 == 0:
            for x in (2, PW - 3):
                px[x, y] = WOOD[2]
    for x in range(PW):
        for y in (0, 1, PH - 2, PH - 1):
            px[x, y] = WOOD[1] if (x % 6) else WOOD[2]

    # plantações nos cantos (milho/repolho), espelhadas
    def crop(x0, y0, kind):
        for i in range(4):
            for j in range(3):
                x = x0 + i * 4
                y = y0 + j * 5
                if kind == "milho":
                    for k in range(4):
                        mirror_set(x, y - k, (90, 150, 50) if k < 3 else (240, 200, 70))
                    mirror_set(x + 1, y - 2, (110, 170, 60))
                else:
                    for dx, dy in ((0, 0), (1, 0), (0, -1), (1, -1)):
                        mirror_set(x + dx, y + dy, (130, 190, 90))
                    mirror_set(x, y - 1, (170, 220, 120))
                mirror_set(x, y + 1, DIRT[2])

    crop(6, PH - 30, "milho")
    crop(PW - 22, PH - 30, "repolho")
    crop(6, CY + 22, "repolho")
    crop(PW - 22, CY + 22, "milho")

    # florzinhas e pedrinhas espalhadas (espelhadas pra manter a simetria)
    for _ in range(70):
        x = rnd.randrange(4, PW - 4)
        y = rnd.randrange(CY + RIVER_HALF + 3, PH - 4)
        if px[x, y] in (G1, G2) or abs(px[x, y][0] - G1[0]) < 20:
            mirror_set(x, y, rnd.choice([(250, 220, 80), (250, 150, 180), (245, 245, 235), (150, 150, 150)]))
    return img


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "arena_bg.png"
    img = build()
    img.save(out)
    img.resize((PW * 3, PH * 3), Image.NEAREST).save(out.replace(".png", "_preview.png"))
