#!/bin/bash
# run_grid.sh —— main_thr4.o 网格扫描（8 点 × MR 次 ≈ 15 分钟）
# 用法: cd ~/710_l1/bhi-spectre-bhb/re/arm/bhb_brute_force && ./run_grid.sh
# 产物: cross_main.csv（H,tool,metric）—— 与 calib 的 cross_calib.csv 对齐
# 前置: 已 build_and_smoke 通过，main_thr4.o 就绪

set -u
HS="${HS:-192 208 224 240 256 272 288 304}"
MR="${MR:-80}"
CORE="${CORE:-3}"
OUT="cross_main.csv"

# 自检：main_thr4.o 必须输出 [SELF]，否则大声退出（避免静默空 CSV）
probe=$(HIST=224 SHARE=1 TRAIN=128 ITER=50 timeout 90 taskset -c "$CORE" ./main_thr4.o 2>/dev/null)
echo "$probe" | grep -q '\[SELF\]' || { echo "ABORT: main_thr4.o 无 [SELF]，换本包 main.c 重编"; exit 1; }
echo "self-check OK, sweeping..."

echo "H,tool,metric" > "$OUT"
for H in $HS; do
  for rep in $(seq 1 "$MR"); do
    o=$(HIST=$H SHARE=1 TRAIN=128 ITER=50 timeout 60 taskset -c "$CORE" ./main_thr4.o 2>/dev/null)
    s=$(echo "$o"|grep -oP '\[SELF\][^=]*=\s*\K[0-9.]+'); s=${s:-NA}
    m=$(echo "$o"|grep -oP '\[MAIN\][^(]*\(\K[0-9.]+');  m=${m:-NA}
    c=$(echo "$o"|grep -oP '\[CTRL\][^(]*\(\K[0-9.]+');  c=${c:-NA}
    p=$(echo "$o"|grep -oP '\[POS\][^(]*\(\K[0-9.]+');   p=${p:-NA}
    if [[ "$s" != NA && "$m" != NA && "$c" != NA && "$p" != NA ]]; then
      awk "BEGIN{exit !($s>=30 && $c<=2 && $p>=99)}" && echo "$H,main,$m" >> "$OUT"
    fi
  done
  echo "=== main H=$H done ==="
done
echo "DONE main -> $OUT"
