"""Gera o cenário da arena 2.0 (144x240 px, usado ampliado 4x = 576x960 no jogo).
Simétrico de cima pra baixo: metade de baixo = jogador, de cima = bot.
As medidas batem com Scripts/arena_builder.gd (lá em unidades de mundo = px*4).
"""
from PIL import Image
import random, math, sys

PW, PH = 144, 240
CX, CY = PW // 2, PH // 2
RIVER_HALF = 9          # rio: linhas CY-9 .. CY+8  (mundo ±36)
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

    # ---- LAYOUT "TECLADO NUMÉRICO": a base é o 5 e os módulos ficam nos outros 8 números.
    # 3 colunas (as mesmas das 3 pontes) x 3 fileiras, tudo simétrico.
    COLS = (CX - BRIDGE_X, CX, CX + BRIDGE_X)
    ROWS = (CY + 57.5, CY + 82.5, CY + 107.5)          # mundo: 230, 330, 430 a partir do rio

    def dirt(x, y, edge=False):
        c = DIRT[1] if edge else DIRT[0]
        if rnd.random() < 0.07:
            c = DIRT[2]
        mirror_set(x, y, c)

    # três caminhos RETOS: cada ponte desce direto pra sua coluna do pátio
    for col_x, half in ((COLS[0], 5), (COLS[1], 4), (COLS[2], 5)):
        for y in range(CY + RIVER_HALF, int(ROWS[0])):
            for x in range(int(col_x - half - 1), int(col_x + half + 1)):
                d = abs(x + 0.5 - col_x)
                if d <= half:
                    dirt(x, y, d >= half - 2)
                elif d <= half + 1:
                    mirror_set(x, y, G3)

    # o pátio: um quadrado de terra batida em volta da base, com borda
    yx0, yx1 = int(COLS[0] - 14), int(COLS[2] + 14)
    yy0, yy1 = int(ROWS[0] - 11), min(int(ROWS[2] + 11), PH - 2)
    for y in range(yy0 - 1, yy1 + 2):
        for x in range(yx0 - 1, yx1 + 2):
            if x < yx0 or x > yx1 or y < yy0 or y > yy1:
                mirror_set(x, y, G3)
            else:
                dirt(x, y, x - yx0 < 2 or yx1 - x < 2 or y - yy0 < 2 or yy1 - y < 2)
    # os 9 lugares: o do meio (a base) maior, os 8 em volta marcados no chão
    for ri, ry in enumerate(ROWS):
        for ci, cx_ in enumerate(COLS):
            main = ri == 1 and ci == 1
            r = 12.5 if main else 9.0
            for y in range(int(ry - r - 1), int(ry + r + 2)):
                for x in range(int(cx_ - r - 1), int(cx_ + r + 2)):
                    d = math.hypot(x + 0.5 - cx_, y + 0.5 - ry)
                    if r - 1.2 <= d <= r and y <= PH - 2:
                        mirror_set(x, y, DIRT[2])

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
