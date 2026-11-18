#!/usr/bin/env python3
# analyze_hiN.py —— 单套扫描：每档中位 + bootstrap 95% CI
#   sweep3/sweep4 同款，改输入文件名即可（sweep4_results.csv / sweep3_results.csv）
import csv, statistics, random
from collections import defaultdict
mainp=defaultdict(list); total=defaultdict(int); passn=defaultdict(int); selfall=defaultdict(list)
for r in csv.DictReader(open('sweep4_results.csv')):   # 改成 sweep3_results.csv 等
    try: H=int(r['H'])
    except: continue
    total[H]+=1
    try: selfall[H].append(float(r['self_pct']))
    except: pass
    if r['gate']=='PASS':
        passn[H]+=1
        try: mainp[H].append(float(r['main_pct']))
        except: pass
def boot(x,n=8000):
    if len(x)<3: return (float('nan'),)*2
    m=sorted(statistics.median(random.choices(x,k=len(x))) for _ in range(n))
    return m[int(.025*n)], m[int(.975*n)]
def med(x): return statistics.median(x) if x else float('nan')
print(f"{'H':>5}{'pass/N':>9}{'MAINmed':>9}{'CI_lo':>7}{'CI_hi':>7}{'SELFmed':>9}")
for H in sorted(total):
    m=med(mainp[H]); lo,hi=boot(mainp[H])
    print(f"{H:>5}{str(passn[H])+'/'+str(total[H]):>9}{m:>9.1f}{lo:>7.1f}{hi:>7.1f}{med(selfall[H]):>9.1f}")
