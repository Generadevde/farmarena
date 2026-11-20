"""uso: novato.py pasta prefixo [prefixo...] -> do ponto de vista do JOGADOR (lado P): quantas torres ele derruba, quantas perde, quem ganha"""
import re,sys,glob,statistics as st
d=sys.argv[1]
for pre in sys.argv[2:]:
    rows=[]
    for f in sorted(glob.glob(f"{d}/{pre}_[0-9]*.log")):
        base="";m=None
        for l in open(f):
            if l.startswith("LABBASE") and not l.startswith("LABBASE mods"): base=l.split()[1]
            mm=re.match(r"LABFIM (\S+) dur=([\d.]+) vidaP=([\d.]+) vidaE=([\d.]+) quedas=(\[.*?\])",l)
            if mm: m=mm
        if not m: continue
        raw=re.findall(r"([PE])[a-z]?@(\d+)",m.group(5))
        lost=sum(1 for s,_ in raw if s=="P")+(1 if base=="P" else 0); took=sum(1 for s,_ in raw if s=="E")+(1 if base=="E" else 0)
        hp=(float(m.group(3)),float(m.group(4)))
        win="P" if base=="E" else "E" if base=="P" else "P" if took>lost else "E" if lost>took else "P" if hp[0]>hp[1]+0.0005 else "E" if hp[1]>hp[0]+0.0005 else "="
        first=min([int(t) for s,t in raw if s=="E"],default=None)
        rows.append(dict(took=took,lost=lost,win=win,dur=float(m.group(2)),hpE=hp[1],hpP=hp[0],base=base,first=first))
    n=len(rows)
    if not n: print(pre,"sem dados"); continue
    w=sum(r["win"]=="P" for r in rows); l=sum(r["win"]=="E" for r in rows)
    print(f"{pre}: n={n} | jogador vence {w}, perde {l}, empata {n-w-l} | jogador NÃO derruba nada em {sum(r['took']==0 for r in rows)} | derruba a base em {sum(r['base']=='E' for r in rows)} | perde a base em {sum(r['base']=='P' for r in rows)}")
    print(f"   torres que o jogador derruba (média) {st.mean(r['took'] for r in rows):.2f} | que perde {st.mean(r['lost'] for r in rows):.2f} | vida que sobra no lado do bot (média) {st.mean(r['hpE'] for r in rows):.2f} | no do jogador {st.mean(r['hpP'] for r in rows):.2f}")
    fs=[r['first'] for r in rows if r['first'] is not None]
    print(f"   1ª torre do bot cai (mediana) {st.median(fs) if fs else '-'}s em {len(fs)} partidas | ninguém derruba nada: {sum(r['took']==0 and r['lost']==0 for r in rows)} | duração mediana {st.median(r['dur'] for r in rows):.0f}s | acabam antes do tempo: {sum(r['base']!='-' and r['base']!='' for r in rows)}")
