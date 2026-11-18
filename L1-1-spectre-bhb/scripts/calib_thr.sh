#!/bin/bash
# calib_thr.sh —— calib THR=4/5/6 × H 稳健性网格（碰撞概率度量）
#   需先编好 ./calib（见 README 构建段）
set -u
THRS="4 5 6"
HS="192 208 224 240 256 272 288 304"
CORE=3
OUT=calib_thr_results.csv
echo "THR,H,metric" > "$OUT"
for T in $THRS; do
  for H in $HS; do
    taskset -c $CORE ./calib --history $H --in-place 1 --hit-num 100 --rounds 300 --iters 100 --thr $T --out /tmp/ct_${T}_${H}.csv 2>/dev/null
    cm=$(awk -F, 'NR>1&&$4=="MAIN"{n++;s+=$6} END{if(n>0)printf "%.3f",s/n; else print "NA"}' /tmp/ct_${T}_${H}.csv)
    echo "$T,$H,$cm" >> "$OUT"
  done
done
echo "DONE -> $OUT"
