#!/usr/bin/env python3
# analyze_calib_thr.py —— calib THR 稳健性（THR=4/5/6 × H 的 metric + argmax）
import csv
from collections import defaultdict
d=defaultdict(dict)
for r in csv.DictReader(open('calib_thr_results.csv')):
    try: T=int(r['THR']); H=int(r['H']); v=float(r['metric'])
    except: continue
    d[T][H]=v
THRS=sorted(d); HS=sorted({h for T in d for h in d[T]})
print("       " + "".join(f"{h:>7}" for h in HS) + "   argmax")
for T in THRS:
    row=d[T]; best=max((h for h in HS if h in row), key=lambda h:row[h])
    print(f"THR={T} " + "".join(f"{row.get(h,float('nan')):>7.2f}" for h in HS) + f"   H={best}")
