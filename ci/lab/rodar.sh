#!/bin/bash
# LABORATÓRIO DA BATALHA -- roda a batalha de verdade aqui (sem celular) e mede.
#
#   GODOT=/caminho/godot ci/lab/rodar.sh cena  nome 'PLANO_JSON' segundos [video]
#   GODOT=/caminho/godot ci/lab/rodar.sh lote  nome N            (N partidas bot x bot justas)
#   GODOT=/caminho/godot ci/lab/rodar.sh solo  nome              (cada carta sozinha contra uma torre)
#   GODOT=/caminho/godot ci/lab/rodar.sh duelos nome             (toda tropa x toda tropa; grava o que a carta mostra)
#
# PLANO_JSON = [[t, "P"|"E", "Nome da carta", x, y], ...]  (x,y a partir do meio do campo; y>0 = lado do jogador)
# Regras antigas pra comparar:  REGRAS_OFF=torres,visual,peso  na frente do comando.
# Ajuste fino sem recompilar:   REGRAS_TUNE="hp=1.3,dmg=2.0,range=80,basic=50"
# Antes da primeira vez (ou depois de criar um arquivo com class_name): $GODOT --headless --import
set -e
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-godot}"
OUT="${LAB_OUT:-/tmp/lab}"
mkdir -p "$OUT"
cd "$REPO"
modo=$1; nome=$2

case "$modo" in
  cena)
    export LAB_PLAN="$3" LAB_END="${4:-30}" HOME="$OUT/home_$nome"
    rm -rf "$HOME"
    if [ -n "$5" ]; then
      # tela do Moto G75 (20:9). override.cfg é apagado no fim (está no .gitignore)
      printf '[display]\n\nwindow/size/viewport_height=1600\n' > override.cfg
      trap 'rm -f "$REPO/override.cfg"' EXIT
      timeout 600 xvfb-run -a -s "-screen 0 720x1600x24" "$GODOT" --rendering-driver opengl3 --resolution 720x1600 \
        --write-movie "$OUT/$nome.avi" --fixed-fps 30 res://ci/lab/lab.tscn 2>&1 | grep -E "^LAB|SCRIPT ERROR|at: res" | head -3000 > "$OUT/$nome.log"
    else
      timeout 600 "$GODOT" --headless --fixed-fps 60 res://ci/lab/lab.tscn 2>&1 | grep -E "^LAB|SCRIPT ERROR|at: res" | head -3000 > "$OUT/$nome.log"
    fi
    grep -E "LABFIM|SCRIPT ERROR" "$OUT/$nome.log" || true
    ;;
  lote)
    n=${3:-20}
    um() {
      i=$1
      LAB_PLAN='[]' LAB_END=330 LAB_FAIR=1 LAB_QUIET=1 LAB_SEED=$i HOME="$OUT/home_${nome}_$i" \
        timeout 900 "$GODOT" --headless --fixed-fps 30 res://ci/lab/lab.tscn 2>&1 | grep -E "^LABFIM|SCRIPT ERROR|at: res" | head -40 > "$OUT/${nome}_$i.log"
      rm -rf "$OUT/home_${nome}_$i"
    }
    export -f um; export GODOT OUT nome
    seq 1 "$n" | xargs -P 2 -I{} bash -c 'um {}'
    python3 "$REPO/ci/lab/resumo.py" "$OUT" "$nome"
    ;;
  solo)
    GODOT="$GODOT" python3 "$REPO/ci/lab/solo.py" "$OUT" "$nome"
    ;;
  duelos)
    # toda tropa contra toda tropa, 1 contra 1, dos dois lados do campo.
    # No fim grava Scripts/duelos_medidos.gd (o que o jogo mostra na carta).
    rm -rf "$OUT/home_d$nome"*
    HOME="$OUT/home_d$nome" LAB_DUMP="$OUT/cards_$nome.json" timeout 120 "$GODOT" --headless res://ci/lab/dump.tscn > /dev/null 2>&1
    python3 - "$OUT" "$nome" <<'PY'
import json, itertools, sys
out, nome = sys.argv[1], sys.argv[2]
u = [x["nome"] for x in json.load(open(f"{out}/cards_{nome}.json")) if not x.get("spell") and not x.get("ficha") and not x.get("safra") and "hp" in x and x["unit_type"] != 2 and x["target_type"] != 3]
p = [list(q) for q in itertools.combinations(u, 2)]
json.dump(p, open(f"{out}/dA.json", "w")); json.dump([[b, a] for a, b in p], open(f"{out}/dB.json", "w"))
PY
    for k in A B; do
      ( HOME="$OUT/home_d$nome$k" LAB_QUIET=1 LAB_END=99999 LAB_DUELOS="$OUT/d$k.json" LAB_DUELOS_OUT="$OUT/d${k}_${nome}_out.json" \
        timeout 900 "$GODOT" --headless --fixed-fps 30 res://ci/lab/lab.tscn 2>&1 | grep -E "SCRIPT ERROR" | sort | uniq -c | head -3 ) &
    done
    wait
    rm -rf "$OUT/home_d$nome"*
    python3 "$REPO/ci/lab/duelos.py" "$OUT" "_$nome"
    [ -f "$OUT/solo_$nome.json" ] || echo "(sem solo_$nome.json: rode antes 'rodar.sh solo $nome' pra carta mostrar também o dano em torre)"
    python3 "$REPO/ci/lab/medidas.py" "$OUT" "_$nome"
    ;;
  *)
    sed -n 2,13p "$0"
    ;;
esac
