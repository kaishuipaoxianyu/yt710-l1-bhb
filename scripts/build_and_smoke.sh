#!/bin/bash
# build_and_smoke.sh —— 编 main_thr4.o + 冒烟自检（3 分钟）
# 用法: cd ~/710_l1/bhi-spectre-bhb/re/arm/bhb_brute_force && ./build_and_smoke.sh

set -eu

echo "=== (1) 环境自检 ==="
grep -A4 "defined YITIAN_710" ../../../common/targets.h | grep -q THR || {
    echo "!! targets.h 缺 YITIAN_710/THR，先打补丁 2"; exit 1; }
grep -q "ifndef THR" ../../../common/targets.h && echo "targets.h: THR ifndef 保护 OK" || {
    echo "!! targets.h 的 THR 没加 ifndef 保护，-DTHR 会冲突，先改"; exit 1; }
grep -q cntvct ../../../common/helper.h && echo "helper.h: cntvct OK" || {
    echo "!! helper.h 未改 cntvct，先打补丁 1"; exit 1; }
grep -q 'getenv' src/main.c && echo "main.c: 运行时参数 OK" || {
    echo "!! main.c 版本不对（缺运行时 HIST）"; exit 1; }

echo
echo "=== (2) 编译 main_thr4.o（THR=4）==="
gcc -c src/snippet.S -o snippet.o -I../../../common -DYITIAN_710
gcc -D_GNU_SOURCE -DIN_PLACE=1 -DTHR=4 src/main.c -o main_thr4.o snippet.o \
    -pie -O1 -I../../../common -DYITIAN_710 -pthread
echo "built main_thr4.o"

echo
echo "=== (3) 冒烟：H=224，期望 MAIN 28~42% 且四闸齐 ==="
out=$(HIST=224 SHARE=1 TRAIN=128 ITER=50 timeout 90 taskset -c 3 ./main_thr4.o 2>/dev/null)
echo "$out" | grep -E '\[SELF\]|\[MAIN\]|\[CTRL\]|\[POS\]'
m=$(echo "$out" | grep -oP '\[MAIN\][^(]*\(\K[0-9.]+')
echo "$out" | grep -q '\[SELF\]' || { echo "❌ 无 [SELF]：main.c 版本不对"; exit 1; }
awk -v v="${m:-0}" 'BEGIN{
    if (v>=28 && v<=42) print "✅ 通过（MAIN="v"），可跑网格"
    else if (v>=15 && v<28) print "🟡 偏低（MAIN="v"）：检查 THR / 机器干扰 / ruler"
    else print "❌ MAIN="v" 不在范围，先别跑网格"
}'
