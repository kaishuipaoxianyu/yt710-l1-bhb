#!/bin/bash
# export_from_server.sh —— 在 N2 服务器(8.137.179.142)上运行，把所有【需导出】原件打成一个 tarball。
#   仅读/复制自己家目录下的 ~/710_l1，不 sudo、不碰系统——符合服务器使用规范。
#   用法:  bash export_from_server.sh   然后把生成的 .tar.gz scp 回本地填进项目。
set -u

# 规范要求：动手前先看一眼磁盘（硬盘不大）
echo "=== df -h（规范：用前先看磁盘） ==="; df -h ~ /; echo

cd ~/710_l1/bhi-spectre-bhb/re/arm/bhb_brute_force || { echo "找不到工作目录，请按实际路径改 cd"; exit 1; }
OUT=~/L1_port_$(date +%Y%m%d); mkdir -p "$OUT"/{src,common,scripts,data,env,docs}

cp src/main.c src/calib.c src/snippet.S               "$OUT"/src/      2>/dev/null
cp ../../../common/helper.h ../../../common/targets.h "$OUT"/common/   2>/dev/null
cp ../../../common/*.h                                "$OUT"/common/   2>/dev/null
find . ../.. ../../.. -maxdepth 1 -name Makefile -exec cp {} "$OUT"/docs/ \; 2>/dev/null
cp *.sh *.py                                          "$OUT"/scripts/  2>/dev/null
cp *.csv *.json *.tsv                                 "$OUT"/data/     2>/dev/null
cp -r ~/710_l1/L1-1 ~/710_l1/L1-1H                    "$OUT"/docs/     2>/dev/null
find ~/710_l1 \( -name 'raw*.csv' -o -name 'summary*.json' -o -name 'summary_table.tsv' -o -name '*repro*.zip' \) -exec cp {} "$OUT"/data/ \; 2>/dev/null

lscpu > "$OUT"/env/lscpu.txt 2>/dev/null
uname -a > "$OUT"/env/uname.txt 2>/dev/null
cat /proc/cmdline > "$OUT"/env/cmdline.txt 2>/dev/null
{ for f in spectre_v1 spectre_v2; do echo "$f: $(cat /sys/devices/system/cpu/vulnerabilities/$f 2>/dev/null)"; done
  echo "governor: $(cat /sys/devices/system/cpu/cpu3/cpufreq/scaling_governor 2>/dev/null)"
  echo "perf_event_paranoid: $(cat /proc/sys/kernel/perf_event_paranoid 2>/dev/null)"
  echo "perf_user_access: $(cat /proc/sys/kernel/perf_user_access 2>/dev/null)"
} > "$OUT"/env/sys.txt 2>/dev/null

tar czf "$OUT".tar.gz -C "$(dirname "$OUT")" "$(basename "$OUT")"
echo "=== 打包完成: $OUT.tar.gz ==="
find "$OUT" -type f | sort
echo
echo "回本地：  scp <user>@8.137.179.142:$OUT.tar.gz ."
