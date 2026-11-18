#!/bin/bash
# sweep_thr.sh —— main THR=4/5/6 × H 稳健性网格
#   需先编好 main_thr4.o / main_thr5.o / main_thr6.o（见 README 构建段，-DTHR=T）
set -u
THRS="4 5 6"
HS="128 176 208 224 240 272 320"
R=120
OUT=sweep_thr_results.csv
echo "THR,H,rep,self_pct,main_pct,ctrl_pct,pos_pct,gate" > "$OUT"
for rep in $(seq 1 $R); do
  for T in $THRS; do
    for H in $HS; do
      o=$(HIST=$H SHARE=1 TRAIN=128 ITER=50 timeout 60 taskset -c 2 ./main_thr$T.o 2>/dev/null)
      self=$(echo "$o" | grep -oP '\[SELF\][^=]*=\s*\K[0-9.]+'); self=${self:-NA}
      main=$(echo "$o" | grep -oP '\[MAIN\][^(]*\(\K[0-9.]+');  main=${main:-NA}
      ctrl=$(echo "$o" | grep -oP '\[CTRL\][^(]*\(\K[0-9.]+');  ctrl=${ctrl:-NA}
      pos=$(echo  "$o" | grep -oP '\[POS\][^(]*\(\K[0-9.]+');   pos=${pos:-NA}
      gate=FAIL
      if [[ "$self" != NA && "$main" != NA && "$ctrl" != NA && "$pos" != NA ]]; then
        awk "BEGIN{exit !($self>=30 && $ctrl<=2 && $pos>=99)}" && gate=PASS
      fi
      echo "$T,$H,$rep,$self,$main,$ctrl,$pos,$gate" >> "$OUT"
    done
  done
done
echo "DONE -> $OUT"
