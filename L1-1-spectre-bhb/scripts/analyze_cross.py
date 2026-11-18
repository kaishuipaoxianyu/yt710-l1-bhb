#!/usr/bin/env python3
# analyze_cross.py —— 合并 calib / main 两套结果，归一化比较峰位
# 用法: python3 analyze_cross.py   （读 cross_results.csv）
#   合并:  cat cross_calib.csv > cross_results.csv
#          tail -n +2 cross_main.csv >> cross_results.csv
import csv, statistics
from collections import defaultdict
calib=defaultdict(list); main=defaultdict(list)
for r in csv.DictReader(open('cross_results.csv')):
    try: H=int(r['H']); v=float(r['metric'])
    except: continue
    (calib if r['tool']=='calib' else main)[H].append(v)
def med(x): return statistics.median(x) if x else float('nan')
Hs=sorted(set(list(calib)+list(main)))
cm={H:med(calib[H]) for H in Hs}; mm={H:med(main[H]) for H in Hs}
cmax=max(v for v in cm.values() if v==v); mmax=max(v for v in mm.values() if v==v)
print(f"{'H':>5}{'calib':>9}{'calibN':>8}{'main%':>8}{'mainN':>8}")
for H in Hs:
    print(f"{H:>5}{cm[H]:>9.2f}{cm[H]/cmax:>8.2f}{mm[H]:>8.1f}{mm[H]/mmax:>8.2f}")
ca=max((H for H in Hs if cm[H]==cm[H]), key=lambda H:cm[H])
ma=max((H for H in Hs if mm[H]==mm[H]), key=lambda H:mm[H])
print(f"\ncalib(碰撞概率) 峰 H={ca}")
print(f"main (复跑产率) 峰 H={ma}")
