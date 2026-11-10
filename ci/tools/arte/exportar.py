"""Gera o atlas de peças do jogo + o índice em GDScript.
    python3 ci/tools/arte/exportar.py   (rodar da raiz do projeto)
"""
import os, sys
from PIL import Image
import pecas, objetos

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
COLS = 16
cats = {}
for src in (pecas.PECAS, objetos.OBJETOS):
    for c, d in src.items():
        cats.setdefault(c, {}).update(d)
cells = [(c, n) for c in cats for n in cats[c]]
rows = (len(cells) + COLS - 1) // COLS
atlas = Image.new("RGBA", (COLS * 48, rows * 48), (0, 0, 0, 0))
index = {}
for i, (c, n) in enumerate(cells):
    atlas.paste(cats[c][n]().img, ((i % COLS) * 48, (i // COLS) * 48))
    index.setdefault(c, {})[n] = i
os.makedirs(os.path.join(ROOT, "Resources", "pecas"), exist_ok=True)
atlas.save(os.path.join(ROOT, "Resources", "pecas", "pecas.png"))
with open(os.path.join(ROOT, "Scripts", "pecas_index.gd"), "w") as f:
    f.write("extends RefCounted\nclass_name PecasIndex\n## GERADO por ci/tools/arte/exportar.py -- não editar na mão\n\n")
    f.write("const COLS = %d\nconst CELL = 48\n" % COLS)
    f.write("const ORDEM = %s\n" % str(pecas.ORDEM).replace("'", '"'))
    f.write("const PECAS = {\n")
    for c, d in index.items():
        f.write('\t"%s": {%s},\n' % (c, ", ".join('"%s": %d' % (n, i) for n, i in d.items())))
    f.write("}\n")
print("atlas", atlas.size, len(cells), "peças")
