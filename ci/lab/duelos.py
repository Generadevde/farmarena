"""Analisa os duelos carta contra carta (saída do LAB_DUELOS do ci/lab/lab.gd).
Uso: python3 ci/lab/duelos.py /tmp/lab _etiqueta
Mostra: o quanto UMA lista de força explica os duelos, quantos trios pedra-papel-tesoura existem,
quantos duelos são passeio, e a força de cada carta comparada com o preço."""
import json, sys, itertools, statistics as st
out = sys.argv[1] if len(sys.argv) > 2 else "/tmp/lab"
tag = sys.argv[-1] if len(sys.argv) > 1 else ""
cards = {x['nome']: x for x in json.load(open(f'{out}/cards{tag}.json'))}
A = json.load(open(f'{out}/dA{tag}_out.json')); B = json.load(open(f'{out}/dB{tag}_out.json'))
v = {}
def add(a, b, val):
    v.setdefault((a, b), []).append(val); v.setdefault((b, a), []).append(-val)
tms = []
for d in A + B:
    val = d['sobra'] if d['res'] == 'A' else (-d['sobra'] if d['res'] == 'B' else 0.0)
    if d['res'] != 'empate': val = (1 if val >= 0 else -1) * max(abs(val), 0.02)
    add(d['a'], d['b'], val); tms.append(d['t'])
names = sorted({a for a, b in v})
m = {k: sum(x) / len(x) for k, x in v.items()}
win = lambda a, b: 1 if m[(a, b)] > 0.02 else (-1 if m[(a, b)] < -0.02 else 0)
R = {}
for a in names:
    o = [b for b in names if b != a]
    R[a] = dict(wr=sum(1 for b in o if win(a, b) > 0) / len(o), mg=sum(m[(a, b)] for b in o) / len(o))
rank = sorted(names, key=lambda n: -R[n]['wr'])
pairs = list(itertools.combinations(names, 2))
dec = [(a, b) for a, b in pairs if win(a, b) != 0]
print(f"duelos {len(pairs)}  decididos {len(dec)}  empates {len(pairs)-len(dec)}")
# custo prevê?
dc = [(a, b) for a, b in dec if cards[a]['custo'] != cards[b]['custo']]
ok = sum(1 for a, b in dc if (win(a, b) > 0) == (cards[a]['custo'] > cards[b]['custo']))
print(f"mais cara vence: {ok}/{len(dc)} = {ok/len(dc):.0%}")
# um número só (ranking) prevê?
pos = {n: i for i, n in enumerate(rank)}
ok2 = sum(1 for a, b in dec if (win(a, b) > 0) == (pos[a] < pos[b]))
print(f"ranking único prevê: {ok2}/{len(dec)} = {ok2/len(dec):.0%}")
# vida x dano prevê?
pw = lambda n: cards[n]['hp'] * cards[n]['unit_count'] * cards[n]['damage'] / max(cards[n]['attack_speed'], .1) * cards[n]['unit_count']
ok3 = sum(1 for a, b in dec if (win(a, b) > 0) == (pw(a) > pw(b)))
print(f"vida x dano prevê: {ok3}/{len(dec)} = {ok3/len(dec):.0%}")
# ciclos pedra-papel-tesoura
cyc = 0; tri = 0
for a, b, c in itertools.combinations(names, 3):
    w = [win(a, b), win(b, c), win(c, a)]
    if 0 in w: continue
    tri += 1
    if w[0] == w[1] == w[2]: cyc += 1
print(f"trios pedra-papel-tesoura: {cyc}/{tri} = {cyc/tri:.1%}")
# quão apertado
mg = [abs(m[(a, b)]) for a, b in dec]
print(f"sobra do vencedor: mediana {st.median(mg):.2f}; apertados(<25%) {sum(1 for x in mg if x<.25)/len(mg):.0%}; passeio(>60%) {sum(1 for x in mg if x>.6)/len(mg):.0%}")
print(f"duração mediana {st.median(tms):.1f}s  p90 {sorted(tms)[int(len(tms)*.9)]:.1f}s")
# força x custo
xs = [cards[n]['custo'] for n in names]; ys = [R[n]['wr'] for n in names]
mx, my = st.mean(xs), st.mean(ys)
bta = sum((x-mx)*(y-my) for x, y in zip(xs, ys)) / sum((x-mx)**2 for x in xs); alf = my - bta*mx
RAR = ["N", "R", "E", "L", "M"]
print("\ncarta                 rar custo vence  esperado  dif   bate-quem-custa-mais / perde-pra-mais-barata")
for n in sorted(names, key=lambda n: (cards[n]['custo'], n)):
    exp = alf + bta*cards[n]['custo']
    up = [b for b in names if b != n and win(n, b) > 0 and cards[b]['custo'] > cards[n]['custo']]
    dn = [b for b in names if b != n and win(n, b) < 0 and cards[b]['custo'] < cards[n]['custo']]
    print(f"{n[:21]:21} {RAR[cards[n]['rar']]}  {cards[n]['custo']:3}  {R[n]['wr']:4.0%}   {exp:4.0%}   {R[n]['wr']-exp:+.0%}   +{len(up)} / -{len(dn)}")
json.dump({n: dict(R[n], custo=cards[n]['custo']) for n in names}, open(f'{out}/rating{tag}.json', 'w'))
json.dump({f"{a}|{b}": x for (a, b), x in m.items()}, open(f'{out}/matriz{tag}.json', 'w'))
