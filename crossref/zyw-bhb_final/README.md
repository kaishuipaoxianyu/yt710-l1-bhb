# L1-1 交付包

> 交付人：ZYW　　日期：2026-11-12
> 内容：Spectre-BHB 在倚天 710（Neoverse-N2）上的复现代码、脚本、数据与报告

---

## 一、这个包是什么

在 N2 上**复现 BHB 碰撞原语**（同进程、同特权 EL0），并标定三个关键参数。
**主结果：MAIN 16.61% vs CTRL 0.065%（256 倍），CTRL 的强碰撞在 20 万轮中为 0。**

所有数据来自同一套仪器 `bhb_final.c`，2026-11-12 单次连续运行 1023 秒。

---

## 二、目录

```
L1-1_交付包/
├── README.md                     ← 本文件
├── report/
│   └── L1-1_最终报告_单一仪器版.md   ← 完整报告（五部分 23 节）
├── src/
│   ├── bhb_final.c               ← ★ 测量仪（全部数据由它产生）
│   ├── calib.c                   ← 早期配对仪（v3，保留备查）
│   ├── snippet.S                 ← 三个 gadget（上游原样，未改）
│   └── targets.h                 ← 目标宏表（含 YITIAN_710，THR=4）
├── patches/
│   └── PATCH.md                  ← 打在上游的两处补丁 + 实现陷阱
├── scripts/
│   ├── run_fg.sh                 ← 前台一键跑全部（约 17 分钟，带进度）
│   ├── run_all.sh                ← 后台版
│   └── make_figs.py              ← 画图（需 matplotlib）
└── data/
    └── report_data.md            ← 本次运行的全部原始表格（A~H 八节）
```

---

## 三、复现步骤

```bash
# ① 取上游
git clone https://github.com/vusec/bhi-spectre-bhb && cd bhi-spectre-bhb
git checkout ae_final
cd re/arm/bhb_brute_force

# ② 放入本包文件
cp /path/to/src/snippet.S   src/snippet.S
cp /path/to/src/targets.h   ../../../common/targets.h
cp /path/to/src/bhb_final.c src/bhb_final.c
cp /path/to/scripts/*.sh ./
cp /path/to/scripts/make_figs.py ./

# ③ 按 patches/PATCH.md 补丁1 手改 ../../../common/helper.h 的计时源
#    （pmccntr_el0 → isb; mrs cntvct_el0，并删掉前后两次 fence()）

# ④ 编译
gcc -c src/snippet.S -o snippet.o -I../../../common -DYITIAN_710
gcc src/bhb_final.c -o bhb_final snippet.o -pie -O1 -D_GNU_SOURCE \
    -I../../../common -DYITIAN_710

# ⑤ 冒烟（必须先过闸门）
taskset -c 3 ./bhb_final --history 256 --hit-num 5 --rounds 20 \
    --seed 1 --min-self 5 --out ~/smoke.csv

# ⑥ 一键跑全部（前台，约 17 分钟，全程有进度）
chmod +x run_fg.sh
./run_fg.sh
```

---

## 四、关键参数（本包实测）

| 参数 | 值 | 依据 |
|---|---|---|
| **`HISTORY_SIZE`** | **256** | 轻训练峰 21.49%、重训练 31.65%、两口径交集 |
| **`--train-n`** | **32** | 1→32 提升 55%，32→128 饱和 |
| **`--thr`** | **4** | dt 分布谷底 3~6 的中点；8 会假阳性 |

**前提**：计时源为 `cntvct_el0` 且 `rdtscp()` **不含 `dsb`**。
若保留 `fence()`，读数整体右移，`THR` 要改 **6**。

---

## 五、三个闸门（跑坏了会自己停）

| 闸门 | 期望 | 失败返回 |
|---|---|---|
| `[ruler]` | flushed > cached + 2 | 2 |
| `[POS]` 强制真跳 | ≥95% | 3 |
| `[SELF]` 全同链自撞 | ≥5% | 4 |

**H=32 与 H=512 会 `GATE_FAIL`**——极短/极长链时连"自己撞自己"都做不到，这是正常现象，本身就是结论。

---

## 六、没放进来的东西

| 没放 | 原因 | 在哪 |
|---|---|---|
| `r_*.csv` 逐轮原始数据 | 每个 1.5 MB × 20+，压缩包会到 40 MB+ | 实验机 `~/710_l1/bhi-spectre-bhb/re/arm/bhb_brute_force/` |
| 4000 万次主实验的 raw.csv | 8.5 MB 单文件 | 同上 |

需要原始数据请直接找 ZYW 要服务器路径。

---

## 七、相关仓库

| 仓库 | 内容 |
|---|---|
| `yzcc6/yt710-l1-bhb` | 本人复现仓库（代码 + 数据 + 报告） |
| `illustager/yt710-sca-hub` | 组内汇总仓（本仓库作为 `Spectre/yt710-l1-bhb-zyw` 子模块登记） |
| `kaishuipaoxianyu/yt710-l1-bhb` | 队友 WFY 的同原语仓库（另一套仪器，互为交叉验证） |
