"""Transforma as medições do laboratório no arquivo que o JOGO mostra na carta
(Scripts/duelos_medidos.gd): quantas tropas ela vence em duelo, o esperado pro
preço, de quem ganha, pra quem perde e quanto tira de uma torre sozinha.

Uso (depois de rodar os duelos e o solo com a mesma etiqueta):
    python3 ci/lab/medidas.py /tmp/lab _etiqueta
Rode de novo sempre que mexer nos números das cartas.
"""
import json, os, sys
out, tag = sys.argv[1], sys.argv[2]
repo = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
cards = {x["nome"]: x for x in json.load(open(f"{out}/cards{tag}.json"))}
rating = json.load(open(f"{out}/rating{tag}.json"))
m = {tuple(k.split("|")): v for k, v in json.load(open(f"{out}/matriz{tag}.json")).items()}
solo = json.load(open(f"{out}/solo{tag}.json")) if os.path.exists(f"{out}/solo{tag}.json") else {}
names = sorted(rating)
# linha "esperado pro preço": reta por mínimos quadrados custo -> % de vitórias
xs = [cards[n]["custo"] for n in names]; ys = [rating[n]["wr"] for n in names]
mx, my = sum(xs) / len(xs), sum(ys) / len(ys)
b = sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / sum((x - mx) ** 2 for x in xs); a = my - b * mx
rows = {}
for n in names:
    wins = [o for o in names if o != n and m[(n, o)] > 0.02]
    loss = [o for o in names if o != n and m[(n, o)] < -0.02]
    # o que vale mostrar: a carta MAIS FORTE de quem ela ganha e a MAIS FRACA
    # pra quem ela perde (ganhar do Jegue não diz nada; ganhar do Galo Rei diz)
    wins.sort(key=lambda o: (-rating[o]["wr"], -m[(n, o)]))
    loss.sort(key=lambda o: (rating[o]["wr"], m[(n, o)]))
    rows[n] = {"v": round(rating[n]["wr"] * 100), "e": round(max(0.0, min(1.0, a + b * cards[n]["custo"])) * 100),
               "g": wins[:3], "p": loss[:3]}
for n, f in solo.items():
    if n in cards and not cards[n].get("safra"):      # carta de safra muda de aparelho pra aparelho
        rows.setdefault(n, {})["t"] = round(f * 100)
# "k" = vida e dano com que a carta foi medida. Se o jogo encontrar outros
# números (Assembleia mexeu, carta editada), ele troca a medição por estimativa.
for n in rows:
    if n in cards and "hp" in cards[n]:
        rows[n]["k"] = [int(cards[n]["hp"]), int(cards[n]["damage"])]
with open(os.path.join(repo, "Scripts", "duelos_medidos.gd"), "w") as f:
    f.write("extends RefCounted\nclass_name DuelosMedidos\n")
    f.write("## GERADO por ci/lab/medidas.py -- não editar na mão.\n")
    f.write("## Medido no laboratório (batalha de verdade, cartas no mesmo nível):\n")
    f.write("##   v = de cada 100 tropas, quantas ela vence num duelo 1 contra 1\n")
    f.write("##   e = o normal pra uma carta desse preço\n")
    f.write("##   g / p = de quem ganha (mais caras primeiro) / pra quem perde (mais baratas primeiro)\n")
    f.write("##   t = quanto tira de uma torre se ninguém defender (%)\n")
    f.write("##   k = [vida, dano] com que foi medida (mudou? o jogo passa a estimar: Scripts/duelo_papel.gd)\n")
    f.write("const TROPAS = %d\n" % len(names))
    f.write("## reta \"normal pro preço\": fração de vitórias = LINHA_A + LINHA_B * custo\n")
    f.write("const LINHA_A = %.4f\nconst LINHA_B = %.5f\n" % (a, b))
    f.write("const DATA = {\n")
    for n in sorted(rows):
        f.write("\t%s: %s,\n" % (json.dumps(n, ensure_ascii=False), json.dumps(rows[n], ensure_ascii=False)))
    f.write("}\n\n\nstatic func of(card_name: String) -> Dictionary:\n\treturn DATA.get(card_name, {})\n")
print("gravado", len(rows), "cartas")
