#!/usr/bin/env python3
# analyze_thr.py —— main THR 稳健性（THR=4/5/6 × H 的 MAIN 中位 + argmax）
import csv, statistics
from collections import defaultdict
d=defaultdict(list)
for r in csv.DictReader(open('sweep_thr_results.csv')):
    try: T=int(r['THR']); H=int(r['H'])
    except: continue
    if r['gate']=='PASS':
        try: d[(T,H)].append(float(r['main_pct']))
        except: pass
def med(x): return statistics.median(x) if x else float('nan')
THRS=sorted({t for t,_ in d}); HS=sorted({h for _,h in d})
print("        " + "".join(f"{h:>7}" for h in HS) + "   argmax")
for T in THRS:
    m={h:med(d[(T,h)]) for h in HS}
    valid=[h for h in HS if m[h]==m[h]]
    best=max(valid, key=lambda h:m[h]) if valid else None
    print(f"THR={T} " + "".join(f"{m[h]:>7.1f}" for h in HS) + f"   H={best}")
