#!/bin/bash
# make_env.sh —— 归档目标机环境到 env.json + env_raw.txt
cat > env.json <<EOF
{
  "uarch": "YITIAN_710 / Neoverse-N2",
  "kernel": "$(uname -r)",
  "governor": "$(cat /sys/devices/system/cpu/cpu3/cpufreq/scaling_governor 2>/dev/null)",
  "spectre_v2": "$(cat /sys/devices/system/cpu/vulnerabilities/spectre_v2 2>/dev/null)",
  "perf_event_paranoid": "$(cat /proc/sys/kernel/perf_event_paranoid 2>/dev/null)",
  "timer": "cntvct_el0", "core": 3, "thr": 4
}
EOF
lscpu > env_raw.txt 2>/dev/null
uname -a >> env_raw.txt; cat /proc/cmdline >> env_raw.txt
