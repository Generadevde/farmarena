"""Kit de pixel art 48x48 do Farm Arena 2.0.

Tudo é desenhado em CORES-MODELO (rampas puras), e depois recolorido pela
paleta da carta. O jogo (GDScript) usa exatamente a mesma regra, então as
peças exportadas daqui servem pro gerador do celular também.

Cores-modelo (cada rampa = claro, médio, escuro):
  P (principal)  : ff0000 / c00000 / 800000
  S (secundária) : 00ff00 / 00c000 / 008000
  A (acento)     : 0000ff / 0000c0 / 000080
  K (pele/bico)  : ffff00 / c0c000 / 808000
  M (metal/osso) : ff00ff / c000c0 / 800080
  W (madeira)    : 00ffff / 00c0c0 / 008080
Fixas: contorno, olho branco, pupila, brilho -- não mudam.
"""
from PIL import Image
import colorsys

W = H = 48
OUT = (42, 26, 34, 255)        # contorno: marrom-arroxeado escuro (mais quente que preto)
EYE_W = (250, 248, 240, 255)
PUPIL = (24, 16, 22, 255)
SHINE = (255, 255, 255, 255)
BLUSH = (255, 140, 150, 255)

RAMPS = {
    "P": [(255, 0, 0), (192, 0, 0), (128, 0, 0)],
    "S": [(0, 255, 0), (0, 192, 0), (0, 128, 0)],
    "A": [(0, 0, 255), (0, 0, 192), (0, 0, 128)],
    "K": [(255, 255, 0), (192, 192, 0), (128, 128, 0)],
    "M": [(255, 0, 255), (192, 0, 192), (128, 0, 128)],
    "W": [(0, 255, 255), (0, 192, 192), (0, 128, 128)],
}
# tom: 0 claro, 1 médio, 2 escuro
def C(slot, tone=1):
    r, g, b = RAMPS[slot][tone]
    return (r, g, b, 255)

TEMPLATE_LOOKUP = {}
for slot, ramp in RAMPS.items():
    for t, rgb in enumerate(ramp):
        TEMPLATE_LOOKUP[rgb] = (slot, t)


def ramp_from(base_hex, warm=True):
    """rampa de 3 tons a partir de uma cor média: claro puxa pro amarelo
    (luz quente), escuro puxa pro roxo/azul (sombra fria) -- pixel art clássica"""
    base_hex = base_hex.lstrip("#")
    r, g, b = [int(base_hex[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    def mk(dl, dh, ds):
        hh = (h + dh) % 1.0
        ll = max(0, min(1, l + dl))
        ss = max(0, min(1, s + ds))
        rr, gg, bb = colorsys.hls_to_rgb(hh, ll, ss)
        return (int(rr * 255), int(gg * 255), int(bb * 255))
    light = mk(0.13, -0.03 if warm else 0.0, 0.05)
    dark = mk(-0.17, 0.04, -0.05)
    return [light, (int(r * 255), int(g * 255), int(b * 255)), dark]


def recolor(img, palette):
    """troca as cores-modelo pela paleta {slot: hex}"""
    ramps = {k: ramp_from(v) for k, v in palette.items()}
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            key = TEMPLATE_LOOKUP.get((r, g, b))
            if key and key[0] in ramps:
                px[x, y] = ramps[key[0]][key[1]] + (a,)
    return out


class Canvas:
    def __init__(self, w=W, h=H):
        self.img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.px = self.img.load()
        self.w, self.h = w, h

    def put(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = c

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[x, y]
        return (0, 0, 0, 0)

    def rect(self, x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.put(xx, yy, c)

    def ellipse(self, cx, cy, rx, ry, slot, shade=True, light_dir=(-0.6, -0.8)):
        """elipse cheia com sombreado de 3 tons (luz vindo de cima-esquerda)"""
        for yy in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for xx in range(int(cx - rx) - 1, int(cx + rx) + 2):
                dx = (xx + 0.5 - cx) / rx
                dy = (yy + 0.5 - cy) / ry
                d = dx * dx + dy * dy
                if d > 1.0:
                    continue
                if not shade:
                    self.put(xx, yy, C(slot, 1))
                    continue
                lit = -(dx * light_dir[0] + dy * light_dir[1])  # >0 = virado pra luz
                rim = d > 0.72
                if lit > 0.35 and not rim:
                    t = 0
                elif lit < -0.25 or (rim and lit < 0.2):
                    t = 2
                else:
                    t = 1
                self.put(xx, yy, C(slot, t))

    def blob_rect(self, x, y, w, h, slot, round_px=2):
        """retângulo de cantos arredondados com sombra na direita/baixo"""
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                cx = min(xx - x, x + w - 1 - xx)
                cy = min(yy - y, y + h - 1 - yy)
                if cx + cy < round_px - 1 and cx < round_px and cy < round_px:
                    continue
                t = 1
                if xx >= x + w - max(2, w // 4) or yy >= y + h - 2:
                    t = 2
                elif xx <= x + max(1, w // 5) and yy <= y + h // 2:
                    t = 0
                self.put(xx, yy, C(slot, t))

    def line(self, x0, y0, x1, y1, c):
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            self.put(x0, y0, c)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def paste(self, other, ox=0, oy=0, flip=False):
        for y in range(other.h):
            for x in range(other.w):
                c = other.px[x, y]
                if c[3] == 0:
                    continue
                tx = ox + ((other.w - 1 - x) if flip else x)
                self.put(tx, oy + y, c)

    def outline(self, color=OUT, inner=True):
        """contorno de 1px por fora; se inner, escurece também onde duas
        peças de cores diferentes se encontram (separa cabeça/corpo)"""
        src = self.img.copy().load()
        for y in range(self.h):
            for x in range(self.w):
                if src[x, y][3] != 0:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < self.w and 0 <= ny < self.h and src[nx, ny][3] != 0 and src[nx, ny] != color:
                        self.px[x, y] = color
                        break

    def mirror_left_to_right(self):
        for y in range(self.h):
            for x in range(self.w // 2):
                c = self.px[x, y]
                if c[3]:
                    self.px[self.w - 1 - x, y] = c

    def save(self, path, scale=1):
        im = self.img
        if scale != 1:
            im = im.resize((self.w * scale, self.h * scale), Image.NEAREST)
        im.save(path)


def eye(cv, x, y, size=2, look=0):
    """olho estilo do jogo: branco 2x2 (ou 3x3) com pupila e brilho"""
    for yy in range(size):
        for xx in range(size):
            cv.put(x + xx, y + yy, EYE_W)
    cv.put(x + size - 1 + look - (1 if look > 0 else 0), y + size - 1, PUPIL)
    if size >= 3:
        cv.put(x + 1 + look, y + 1, PUPIL)
        cv.put(x + 1 + look, y + 2, PUPIL)
        cv.put(x, y, SHINE)
