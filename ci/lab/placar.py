"""Placar de torres das partidas do `rodar.sh lote`: como cada partida acabou
(nocaute, placar, vida ou empate), os placares finais e as viradas.
    python3 ci/lab/placar.py /tmp/lab nome [outro_nome ...]
"""
import re,sys,glob,statistics as st
out_dir=sys.argv[1]
for pre in sys.argv[2:]:
    rows=[]; err=0
    for f in sorted(glob.glob(f"{out_dir}/{pre}_[0-9]*.log")):
        for l in open(f):
            m=re.match(r"LABFIM (\S+) dur=([\d.]+) vidaP=([\d.]+) vidaE=([\d.]+) quedas=(\[.*?\]) viradas=(\d+)",l)
            if m:
                falls=[(s,int(t)) for s,t in re.findall(r"([PE])@(\d+)", m.group(5))]
                hp=(float(m.group(3)), float(m.group(4)))
                # nocaute: a última torre cai no mesmo instante em que a partida acaba e não entra na lista
                if hp[0]<=0.001: falls.append(("P", int(float(m.group(2)))))
                if hp[1]<=0.001: falls.append(("E", int(float(m.group(2)))))
                rows.append(dict(dur=float(m.group(2)), hp=hp, falls=falls, vir=int(m.group(6))))
            elif "SCRIPT" in l: err+=1; print("ERRO",l.strip()[:160])
    if not rows: print(pre,"sem dados"); continue
    n=len(rows); out=dict(nocaute=0, placar=0, vida=0, empate=0); scores={}; both=0; none=0; flips=[]; first=[]; close=0
    for r in rows:
        p=sum(1 for s,_ in r["falls"] if s=="P"); e=sum(1 for s,_ in r["falls"] if s=="E")   # torres perdidas por cada lado
        key=f"{max(p,e)}x{min(p,e)}"; scores[key]=scores.get(key,0)+1
        if min(r["hp"])<=0.001: out["nocaute"]+=1
        elif p!=e: out["placar"]+=1
        elif abs(r["hp"][0]-r["hp"][1])<0.0005: out["empate"]+=1
        else: out["vida"]+=1
        if p and e: both+=1
        if not r["falls"]: none+=1
        else: first.append(min(t for _,t in r["falls"]))
        # viradas no placar: quem está na frente em torres muda de lado
        lead=0; fl=0; a=b=0
        for s,t in sorted(r["falls"], key=lambda x:x[1]):
            if s=="P": a+=1
            else: b+=1
            now=(a>b)-(a<b)
            if now!=0 and lead!=0 and now!=lead: fl+=1
            if now!=0: lead=now
        flips.append(fl)
        if abs(p-e)<=1: close+=1
    d=[r["dur"] for r in rows]
    print(f"{pre}: n={n} erros={err} | fim: {out} | placares: {dict(sorted(scores.items()))}")
    print(f"   sem torre caída: {none} | os 2 lados perderam torre: {both} | diferença de até 1 torre: {close} | viradas no placar (média): {st.mean(flips):.2f} | viradas na vida: {st.mean([r['vir'] for r in rows]):.2f}")
    print(f"   1ª torre cai (mediana): {st.median(first) if first else 0:.0f}s | duração mediana: {st.median(d):.0f}s | partidas <120s: {sum(1 for x in d if x<120)}")
