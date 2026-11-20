"""uso: duplo.py pasta prefixoDuplo prefixoBase  -> lado P com dois iguais x o mesmo lado P com dois diferentes (mesmas sementes)"""
import re,sys,glob,collections
d,pa,pb=sys.argv[1:4]
TIPO={"Celeiro Velho":"tiro","Castelo de Feno":"tiro","Antena do ET":"tiro","Moinho de Vento":"recurso","Tanque de Leite":"recurso","Armazém de Sacas":"recurso",
 "Caixa d'Água":"cura/aura","Capela do Sino":"cura/aura","Colmeia Gigante":"cura/aura","Forte de Toras":"só vida","Guarita do Caramelo":"solta tropa","Curral de Engorda":"solta tropa","Estábulo Ligeiro":"velocidade"}
def read(f):
    base="";mods="";win=None;dur=0
    for l in open(f):
        if l.startswith("LABBASE mods"): mods=l.strip()
        elif l.startswith("LABBASE"): base=l.split()[1] if len(l.split())>1 else ""
        m=re.match(r"LABFIM (\S+) dur=([\d.]+) vidaP=([\d.]+) vidaE=([\d.]+) quedas=(\[.*?\])",l)
        if m:
            dur=float(m.group(2)); hp=(float(m.group(3)),float(m.group(4)))
            raw=re.findall(r"([PE])([gl]?)@(\d+)",m.group(5)); p=sum(1 for s,_,_ in raw if s=="P"); e=sum(1 for s,_,_ in raw if s=="E")
            if base in("P","E"): win="E" if base=="P" else "P"
            elif p!=e: win="E" if p>e else "P"
            elif abs(hp[0]-hp[1])>0.0005: win="P" if hp[0]>hp[1] else "E"
            else: win="="
    first=re.search(r"P=\[\"?([^@\"]+)@",mods); return win,(first.group(1) if first else "?"),mods,dur
tot=collections.Counter(); by=collections.defaultdict(collections.Counter); bym=collections.defaultdict(collections.Counter); n=0
for fa in sorted(glob.glob(f"{d}/{pa}_[0-9]*.log")):
    i=re.search(r"_(\d+)\.log$",fa).group(1); fb=f"{d}/{pb}_{i}.log"
    try: wa,ma,_,_=read(fa); wb,mb,_,_=read(fb)
    except FileNotFoundError: continue
    if wa is None or wb is None: continue
    n+=1; t=TIPO.get(ma,"safra/outro")
    for k,w in (("duplo",wa),("misto",wb)):
        tot[(k,w)]+=1; by[t][(k,w)]+=1; bym[ma][(k,w)]+=1
def line(name,c):
    g=lambda k:"%2d v %2d d %d e"%(c[(k,"P")],c[(k,"E")],c[(k,"=")])
    return "%-22s DUPLO %s | MISTO %s"%(name,g("duplo"),g("misto"))
print("pares:",n); print(line("TOTAL (lado P)",tot))
for t in sorted(by): print(line("  "+t,by[t]))
print("-- por módulo");
for m in sorted(bym): print(line("  "+m,bym[m]))
