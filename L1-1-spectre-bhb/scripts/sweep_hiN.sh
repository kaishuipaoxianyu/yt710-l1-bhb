#!/bin/bash
# sweep_hiN.sh —— main 扫描，交错采样；sweep3/4 同骨架，改 HS / R
set -u
HS="192 200 208 216 224 232 240 248 256"   # 按需改
R=300
OUT=sweep4_results.csv
echo "H,rep,self_pct,main_pct,ctrl_pct,pos_pct,gate" > "$OUT"
for rep in $(seq 1 $R); do
  for H in $HS; do
    o=$(HIST=$H SHARE=1 TRAIN=128 ITER=50 timeout 60 taskset -c 3 ./main_thr4.o 2>/dev/null)
    self=$(echo "$o" | grep -oP '\[SELF\][^=]*=\s*\K[0-9.]+'); self=${self:-NA}
    main=$(echo "$o" | grep -oP '\[MAIN\][^(]*\(\K[0-9.]+');  main=${main:-NA}
    ctrl=$(echo "$o" | grep -oP '\[CTRL\][^(]*\(\K[0-9.]+');  ctrl=${ctrl:-NA}
    pos=$(echo  "$o" | grep -oP '\[POS\][^(]*\(\K[0-9.]+');   pos=${pos:-NA}
    gate=FAIL
    if [[ "$self" != NA && "$main" != NA && "$ctrl" != NA && "$pos" != NA ]]; then
      awk "BEGIN{exit !($self>=30 && $ctrl<=2 && $pos>=99)}" && gate=PASS
    fi
    echo "$H,$rep,$self,$main,$ctrl,$pos,$gate" >> "$OUT"
  done
done
echo "DONE -> $OUT"
