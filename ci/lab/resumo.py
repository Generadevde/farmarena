"""Resume um lote de partidas do laboratório (ci/lab/rodar.sh lote)."""
import glob, re, statistics as st, sys

out, pres = sys.argv[1], sys.argv[2:]
for pre in pres:
    rows = []
    for f in sorted(glob.glob(f"{out}/{pre}_*.log")):
        for line in open(f):
            m = re.match(r"LABFIM (\S+) dur=([\d.]+) vidaP=([\d.]+) vidaE=([\d.]+) quedas=(\[.*?\]) viradas=(\d+)", line)
            if m:
                rows.append((float(m.group(2)), float(m.group(3)), float(m.group(4)), int(m.group(6))))
            elif "SCRIPT" in line:
                print("ERRO", line.strip()[:160])
    if not rows:
        print(pre, "sem dados")
        continue
    d = [r[0] for r in rows]
    win = [max(r[1], r[2]) for r in rows]
    print(f"{pre}: {len(rows)} partidas")
    print(f"  duração: mediana {st.median(d):.0f}s | acabaram antes de 60s: {sum(x < 60 for x in d)} | antes de 120s: {sum(x < 120 for x in d)} | foram até o fim do tempo: {sum(x >= 299 for x in d)}")
    print(f"  nocautes: {sum(min(r[1], r[2]) <= 0.001 for r in rows)} | vencedor sem um arranhão (>=95%): {sum(x >= 0.95 for x in win)} | os dois lados feridos (<85%): {sum(max(r[1], r[2]) < 0.85 for r in rows)}")
    print(f"  viradas por partida: {st.mean([r[3] for r in rows]):.2f}")
