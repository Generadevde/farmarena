"""Cada carta SOZINHA contra uma torre sem defesa: quanto ela tira da torre?
Uso: GODOT=... python3 ci/lab/solo.py /tmp/lab nome   (antes: rodar ci/lab/dump.tscn pra gerar cards.json)
É o teste que mostrou o problema: nas regras antigas 40 das 48 cartas derrubavam a torre sozinhas."""
import json, os, re, subprocess, sys
from concurrent.futures import ThreadPoolExecutor

out, tag = sys.argv[1], sys.argv[2]
repo = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
godot = os.environ.get("GODOT", "godot")
cards_json = os.path.join(out, "cards.json")
if not os.path.exists(cards_json):
    env = dict(os.environ, LAB_DUMP=cards_json, HOME=os.path.join(out, "home_dump"))
    subprocess.run([godot, "--headless", "res://ci/lab/dump.tscn"], cwd=repo, env=env, capture_output=True)
cards = [c for c in json.load(open(cards_json)) if not c["spell"] and not c["ficha"] and "hp" in c]


def run(c):
    home = os.path.join(out, "home_solo_%d" % abs(hash(c["nome"])))
    env = dict(os.environ, LAB_PLAN=json.dumps([[1, "E", c["nome"], -150, -40]]), LAB_END="75", HOME=home)
    txt = subprocess.run(["timeout", "200", godot, "--headless", "--fixed-fps", "30", "res://ci/lab/lab.tscn"],
                         cwd=repo, env=env, capture_output=True, text=True).stdout
    hp0 = last = dead = None
    for line in txt.splitlines():
        m = re.match(r"LABS t=([\d.]+) torres\[(.*?)\] ?(.*)", line)
        if not m:
            continue
        t = float(m.group(1))
        mine = [int(x[2:]) for x in m.group(2).split() if x.startswith("TP")]
        if not mine:
            continue
        hp0 = hp0 if hp0 is not None else mine[0]
        last = mine[0] if len(mine) == 2 else 0
        if t > 3 and dead is None and not [u for u in m.group(3).split(" | ") if u.startswith("E")]:
            dead = t
    subprocess.run(["rm", "-rf", home])
    return c, hp0, last, dead


with ThreadPoolExecutor(2) as ex:
    res = [r for r in ex.map(run, cards) if r[1]]
res.sort(key=lambda r: (r[1] - r[2]) / r[1])
kills = sum(1 for r in res if r[2] == 0)
for c, hp0, last, dead in res:
    frac = (hp0 - last) / hp0
    print(f"{c['nome']:24s} custo {c['custo']:3d}  tira {frac * 100:5.1f}% da torre   morre aos {dead if dead else '>75'} s")
print(f"\n{tag}: {kills} de {len(res)} cartas derrubam a torre sozinhas")
