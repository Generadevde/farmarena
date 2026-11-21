"""Gera o atlas de peças do jogo + o índice em GDScript.
    python3 ci/tools/arte/exportar.py   (rodar da raiz do projeto)
"""
import os, sys
from PIL import Image
import pecas, objetos, militar, temas, variacoes, megapack, silhuetas

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
COLS = 16
cats = {}
for src in (pecas.PECAS, objetos.OBJETOS, militar.MILITAR, temas.NOVAS, variacoes.VARIACOES, megapack.MEGA, silhuetas.SILHUETAS):
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
    # posturas: onde a cabeça/chapéu encaixam quando o corpo é uma peça "quatro"
    f.write("const QUATRO_CABECA = {%s}\n" % ", ".join('"%s": Vector2i(%d, %d)' % (k, v[0], v[1]) for k, v in list(pecas.QUATRO_CABECA.items()) + list(silhuetas.QUATRO_CABECA_EXTRA.items())))
    f.write("const QUATRO_COSTAS = {%s}\n" % ", ".join('"%s": Vector2i(%d, %d)' % (k, v[0], v[1]) for k, v in pecas.QUATRO_COSTAS.items()))
    # tema de cada peça (o Criador filtra por tema); a que não aparece em nenhum é "Fazenda"
    f.write("const TEMAS = {\n")
    for t, names in temas.TEMAS.items():
        names = list(names) + [x for x in variacoes.TEMAS_EXTRA.get(t, []) if x not in names]
        names = names + [x for x in megapack.TEMAS_MEGA.get(t, []) if x not in names]
        f.write('\t"%s": [%s],\n' % (t, ", ".join('"%s"' % x for x in names)))
    f.write("}\n")
print("atlas", atlas.size, len(cells), "peças")
