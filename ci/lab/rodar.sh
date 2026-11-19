#!/bin/bash
# LABORATÓRIO DA BATALHA -- roda a batalha de verdade aqui (sem celular) e mede.
#
#   GODOT=/caminho/godot ci/lab/rodar.sh cena  nome 'PLANO_JSON' segundos [video]
#   GODOT=/caminho/godot ci/lab/rodar.sh lote  nome N            (N partidas bot x bot justas)
#   GODOT=/caminho/godot ci/lab/rodar.sh solo  nome              (cada carta sozinha contra uma torre)
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
  *)
    sed -n 2,12p "$0"
    ;;
esac
