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
MOD_X = 56.25           # colunas dos módulos dos lados (mundo ±225)
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
# PÁTIO: estilo do chão + 4 cores (claro, meio, escuro, detalhe) + meio-fio (claro, escuro)
YARD = "terra"
YP = [(206, 166, 112), (190, 150, 98), (146, 108, 68), (118, 160, 70)]
CURB = [(214, 200, 176), (108, 92, 76)]


def _noise(x, y, seed=0):
    h = (x * 374761393 + y * 668265263 + seed * 982451653) & 0xFFFFFFFF
    h = (h ^ (h >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


def _mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def _yard_px(style, P, lx, ly, rnd):
    L, M, D, A = P
    if style == "tijolo":            # tijolinho deitado, fiada desencontrada
        row = ly // 3
        off = 3 if row % 2 else 0
        if ly % 3 == 2 or (lx + off) % 7 == 6:
            return D
        bid = ((lx + off) // 7) * 31 + row * 17
        c = L if _noise(bid, row, 3) > 0.55 else M
        if ly % 3 == 0:
            c = _mix(c, (255, 255, 255), 0.12)
        return c
    if style == "laje":              # lajotas grandes com rejunte e uma trincazinha
        row = ly // 8
        off = 4 if row % 2 else 0
        tx, ty = (lx + off) % 8, ly % 8
        if tx == 7 or ty == 7:
            return D if _noise(lx, ly, 9) > 0.04 else A
        tid = ((lx + off) // 8) * 13 + row * 7
        c = _mix(L, M, _noise(tid, 1, 5) * 0.8)
        if tx == 0 or ty == 0:
            c = _mix(c, (255, 255, 255), 0.1)
        if _noise(tid, 2, 6) > 0.86 and tx == ty and 2 <= tx <= 4:
            c = _mix(c, D, 0.7)   # trincazinha curta, só em poucas lajotas
        return c
    if style == "pedra":             # pedra de rio (paralelepípedo torto), rejunte com musgo
        best, second, bid = 99.0, 99.0, 0
        for gx in range(lx // 5 - 1, lx // 5 + 2):
            for gy in range(ly // 4 - 1, ly // 4 + 2):
                cx = gx * 5 + 1 + _noise(gx, gy, 21) * 3
                cy = gy * 4 + 1 + _noise(gx, gy, 22) * 2
                d = ((lx - cx) ** 2 + (ly - cy) ** 2) ** 0.5
                if d < best:
                    second, best, bid = best, d, gx * 97 + gy
                elif d < second:
                    second = d
        if second - best < 0.9:
            return A if _noise(lx, ly, 23) > 0.9 else D
        c = _mix(L, M, _noise(bid, 0, 24))
        return c
    if style == "tabua":             # deque de tábua (passarela), emendas e pregos
        row = ly // 3
        seg = 10 + int(_noise(row, 0, 31) * 8)
        off = int(_noise(row, 1, 32) * seg)
        if ly % 3 == 2:
            return D
        if (lx + off) % seg == 0:
            return D
        if (lx + off) % seg == 1 and ly % 3 == 0:
            return A
        c = L if row % 2 else M
        if _noise(lx // 4, row, 33) > 0.8:
            c = _mix(c, D, 0.25)
        return c
    if style == "areia":             # areia com marquinha de vento
        w = math.sin(lx * 0.55 + ly * 1.1 + _noise(lx // 6, ly // 6, 41) * 2.0)
        c = L if w < 0.55 else M
        n = _noise(lx, ly, 42)
        if n > 0.97:
            c = A
        elif n < 0.03:
            c = D
        return c
    # terra batida: manchas suaves, pedrinha com brilho, um tufinho do tema
    n = _noise(lx // 3, ly // 3, 51)
    c = L if n > 0.6 else M
    k = _noise(lx, ly, 52)
    if k > 0.965:
        c = D
    elif k > 0.955:
        c = _mix(L, (255, 255, 255), 0.3)
    elif k < 0.012:
        c = A
    return c


def build(seed=7):
    rnd = random.Random(seed)
    img = Image.new("RGB", (PW, PH), G1)
    px = img.load()

    # grama: faixas de corte bem suaves (verticais) + manchas + tufinhos -- nada de xadrez
    for y in range(PH):
        for x in range(PW):
            stripe = (x // 8) % 2
            n = _noise(x // 3, y // 3, 11)
            c = G1 if stripe == 0 else G2
            if n > 0.78:
                c = _mix(c, G3, 0.35)
            elif n < 0.12:
                c = _mix(c, (255, 255, 230), 0.08)
            px[x, y] = c
    for _ in range(260):
        x = rnd.randrange(3, PW - 3)
        y = rnd.randrange(3, PH - 3)
        px[x, y] = _mix(px[x, y], G3, 0.6)
        if y > 0:
            px[x, y - 1] = _mix(px[x, y - 1], (255, 255, 220), 0.18)

    def mirror_set(x, y, c):
        if 0 <= x < PW and 0 <= y < PH:
            px[x, y] = c
        my = PH - 1 - y
        if 0 <= x < PW and 0 <= my < PH:
            px[x, my] = c

    # ---- LAYOUT "TECLADO NUMÉRICO": a base é o 5 e os módulos ficam nos outros 8 números.
    # 3 colunas x 3 fileiras, tudo simétrico. As colunas dos lados vão quase até a cerca
    # (mundo ±225); as pontes continuam em ±150 e o caminho desce reto delas até o pátio.
    COLS = (CX - MOD_X, CX, CX + MOD_X)
    ROWS = (CY + 47.5, CY + 80, CY + 112.5)            # mundo: 190, 320, 450 a partir do rio

    # ---- O PÁTIO: um terreno só, bem acabado, no material do tema (terra, tijolo, pedra,
    # laje, tábua, areia), com meio-fio, cantos arredondados e sombrinha na grama.
    yx0, yx1 = int(COLS[0] - 10), int(COLS[2] + 10)
    yy0, yy1 = int(ROWS[0] - 11), PH - 4
    R = 4   # raio dos cantos

    def inside(x, y, x0, y0, x1, y1, r):
        if x < x0 or x > x1 or y < y0 or y > y1:
            return False
        cx = min(max(x, x0 + r), x1 - r)
        cy = min(max(y, y0 + r), y1 - r)
        return (x - cx) ** 2 + (y - cy) ** 2 <= r * r + 0.5

    # caminhos das pontes até o pátio, no mesmo material
    paths = []
    for col_x in (CX - BRIDGE_X, CX + BRIDGE_X):
        paths.append((int(col_x - 5), CY + RIVER_HALF, int(col_x + 4), yy0 + 2))

    def floor_at(x, y):
        if inside(x, y, yx0, yy0, yx1, yy1, R):
            return True
        for (a, b, c2, d) in paths:
            if a <= x <= c2 and b <= y <= d:
                return True
        return False

    def edge_dist(x, y):
        # 0 = borda; 1 = um pixel pra dentro; 9 = longe
        for dd in range(0, 3):
            for dx, dy in ((dd + 1, 0), (-dd - 1, 0), (0, dd + 1), (0, -dd - 1)):
                if not floor_at(x + dx, y + dy) and y + dy > CY + RIVER_HALF:
                    return dd
        return 9

    for y in range(CY + RIVER_HALF, PH - 2):
        for x in range(2, PW - 2):
            if not floor_at(x, y):
                # sombrinha do meio-fio na grama em volta
                near = any(floor_at(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                if near:
                    mirror_set(x, y, _mix(px[x, y], (0, 0, 0), 0.28))
                continue
            e = edge_dist(x, y)
            if e == 0:
                c = CURB[1]
            elif e == 1:
                c = CURB[0]
            else:
                c = _yard_px(YARD, YP, x - yx0, y - yy0, rnd)
                # meio do pátio um tiquinho mais claro (cara de chão gasto onde se pisa)
                cxn = abs(x - CX) / (PW / 2.0)
                c = _mix(c, (255, 255, 240), max(0.0, 0.07 - cxn * 0.07))
            mirror_set(x, y, c)
    # (sem marcação redonda dos lugares: o pátio é liso)

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

    # (sem ponte do meio: só os dois lados atravessam o rio, igual o Clash)

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
