"""Folha de conferência: todas as peças + alguns personagens montados."""
import sys
from PIL import Image
from kit import *
import pecas

PAL = {"P": "#e8e0d0", "S": "#7a5a3a", "A": "#c8483c", "K": "#f0c090", "M": "#9aa4b0", "W": "#8a5a34"}
S = 4
names = [(c, n) for c in pecas.ORDEM for n in pecas.PECAS[c]]
cols = 10
rows = (len(names) + cols - 1) // cols
sheet = Image.new("RGBA", (cols * 48 * S, rows * 48 * S), (70, 110, 60, 255))
erros = 0
for i, (c, n) in enumerate(names):
    try:
        im = recolor(pecas.PECAS[c][n]().img, PAL)
    except Exception as e:
        print("ERRO", c, n, e); erros += 1; continue
    im = im.resize((48 * S, 48 * S), Image.NEAREST)
    sheet.alpha_composite(im, ((i % cols) * 48 * S, (i // cols) * 48 * S))
sheet.save(sys.argv[1])
print("pecas", len(names), "erros", erros)
