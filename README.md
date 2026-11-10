# Spectre-BHB 复现研究（Yitian 710 / Neoverse-N2）

> 维护者：WFY（GitHub [@kaishuipaoxianyu](https://github.com/kaishuipaoxianyu)） · 索引仓：[`illustager/yt710-sca-hub`](https://github.com/illustager/yt710-sca-hub)（本仓库作为 `Spectre/` 下的 submodule 登记）

本项目整理自 "my research" 的 Spectre-BHB 系列实验，核心是 **L1-1 / L1-1H 同进程原语基线**：
在 Yitian 710（Neoverse-N2，aarch64，EL0 同特权）上，用 BHB（Branch History Buffer）操纵本进程间接分支，
使其瞬态误跳到泄露 gadget，再用 L1D Flush+Reload 读出本进程已知靶，证明 BHB 可控瞬态执行原语的存在性。

> 范围：**同进程、同特权自测**。不涉及跨进程 / 跨特权 / VM / 租户，不改内核、不关缓解。
> 原语本体（`snippet.S` 三 gadget、JIT、训练/触发时序）**未改**，本项目只做最小移植 + 测量脚手架。

上游：[`vusec/bhi-spectre-bhb`](https://github.com/vusec/bhi-spectre-bhb) `@ ae_final`，目录 `re/arm/bhb_brute_force`。
目标机与操作红线见 [`docs/服务器使用说明.md`](docs/服务器使用说明.md)（最高优先级）。

---

## 目录结构

```
.
├── README.md                     # 本文件
├── NEEDS_EXPORT.md               # 还需从服务器导出的原件清单（helper.h/Makefile/原始 CSV 等）
├── src/
│   ├── main.c                    # 改造版 harness（产率度量）
│   ├── calib.c                   # ZYW v3 配对测量仪（碰撞概率度量，测 BHB 深度更对口）
│   ├── snippet.S                 # 三 gadget 汇编（上游未改，建议 diff 核验）
│   └── targets.h                 # 目标宏表，含 YITIAN_710 块（覆盖 common/targets.h）
│   └── (helper.h)                # 【需从服务器导出】见 NEEDS_EXPORT.md，缺它编不过
├── patches/PATCH.md              # 需打在上游的补丁 + main.c 改造说明（含 helper.h 计时补丁）
├── scripts/
│   ├── build_and_smoke.sh        # 编译 + 冒烟自检
│   ├── run_grid.sh               # 旧网格扫描 -> cross_main.csv
│   ├── sweep_hiN.sh              # main HISTORY_SIZE 扫描（交错采样）
│   ├── sweep_thr.sh             # main THR=4/5/6 × H 稳健性网格
│   ├── calib_thr.sh             # calib THR=4/5/6 × H 稳健性网格
│   ├── analyze_cross.py          # 合并 calib/main，归一化比较峰位
│   ├── analyze_hiN.py            # 单套扫描：每档中位 + bootstrap 95% CI
│   ├── analyze_thr.py            # main THR 稳健性表 + argmax
│   ├── analyze_calib_thr.py      # calib THR 稳健性表 + argmax
│   ├── make_env.sh               # 归档 env.json / env_raw.txt
│   └── export_from_server.sh     # ★ 在 N2 上一键打包所有【需导出】原件
├── data/
│   ├── cross_aggregated.tsv      # 双仪器对跑聚合值（原始逐 run 数据见 NEEDS_EXPORT.md）
│   └── README.md
└── docs/
    ├── L1-1H_repro_README.md     # 复现包随附 README
    ├── environment.md            # 目标机环境实测值 + THR 4/5/6 稳健性 + 基线依据
    ├── 服务器使用说明.md          # ★ N2 服务器操作规范（最高优先级）
    └── reports/
        ├── L1-1_结论卡_v2.2.md            # ★ 权威现行结论卡
        ├── L1-1_BHB_修复与攻击复现报告4.0.md
        ├── L1-1_源码改动报告3.0.md
        ├── L1-1H_HISTORY_SIZE测定_结论卡.md   # 服务器现行 v1.2（本仓库为导出的早期版）
        └── L1-2_BHB_原理代码与N2重设计1.0.md
```

## 依赖上游、本仓库未附的文件

`src/main.c` / `src/calib.c` 需要上游 `common/helper.h`（计时 / maccess / clflush / fence 等原语）。
**本仓库只含计时补丁片段**（`patches/PATCH.md` 补丁1：ARMv8 `pmccntr_el0 → cntvct_el0`），
**完整 `helper.h` 需从服务器导出**（见 `NEEDS_EXPORT.md`，缺它编不过）。
`snippet.S` 已附（上游未改），但建议 `diff` 服务器实际文件核验一次。

## 移植步骤（叠加到上游）

```bash
git clone https://github.com/vusec/bhi-spectre-bhb && cd bhi-spectre-bhb
git checkout ae_final

cp /path/to/this/src/main.c      re/arm/bhb_brute_force/src/main.c
cp /path/to/this/src/calib.c     re/arm/bhb_brute_force/src/calib.c
cp /path/to/this/src/snippet.S   re/arm/bhb_brute_force/src/snippet.S   # 先 diff 核验
cp /path/to/this/src/targets.h   common/targets.h
# 按 patches/PATCH.md 补丁1 手改 common/helper.h 的计时源（或用服务器已改版覆盖）
cp /path/to/this/scripts/*.sh /path/to/this/scripts/*.py  re/arm/bhb_brute_force/
```

## 构建与运行

```bash
# gadget
gcc -c src/snippet.S -o snippet.o -I common -DYITIAN_710

# main（产率）：THR 由 -DTHR 覆盖，默认 5；稳健性需分别编 main_thr4/5/6.o
gcc -D_GNU_SOURCE -DIN_PLACE=1 -DTHR=4 src/main.c -o main_thr4.o snippet.o \
    -pie -O1 -I common -DYITIAN_710 -pthread

# calib（碰撞概率）
gcc src/calib.c -o calib snippet.o -pie -O1 -I common -DYITIAN_710

# 冒烟自检（期望 MAIN 28~42%，四闸齐全）
./build_and_smoke.sh
# 单跑（H 由 HIST 给）
SHARE=1 TRAIN=128 ITER=50 taskset -c 2 ./main_thr4.o
# 扫描 + 统计
./sweep_hiN.sh  && python3 analyze_hiN.py
./sweep_thr.sh  && python3 analyze_thr.py
./calib_thr.sh  && python3 analyze_calib_thr.py
```

### 运行参数（main，环境变量）

| 变量 | 含义 | 基线值 |
|---|---|---|
| `HIST`   | BHB 链长（HISTORY_SIZE，自变量） | 深扫 {32,64,128,256,384,512} |
| `TRAIN`  | 每次触发前训练次数 | 128 |
| `ITER`   | 每轮迭代数 | 50 |
| `SHARE`  | 训练链与测试链共享的尾部位数 | 1 |
| `IN_PLACE` | 编译期：原地复用末端地址 | 1 |
| `THR`    | Flush+Reload 命中阈值（cntvct tick） | 5（`-DTHR=` 覆盖；稳健性扫 4/5/6） |
| `NOSPEC` | 1 = 关闭推测路径（负对照，SELF 应归零） | 0 |

### 四闸判据（排假阳性）

| 标签 | 含义 | 期望 |
|---|---|---|
| `[POS]`  | 强制间接分支真跳 hit_gadget | ≈100% → 测量链路有效 |
| `[CTRL]` | 误训练到安全目标 ftable[0] | ≈0% → 噪声底 |
| `[SELF]` | 同链自撞正对照（gate-2） | ≥30 → 可过闸 |
| `[MAIN]` | 训练 hit_gadget、测 ret 链是否误跳 | 响应变量 |

过闸：`SELF≥30 && CTRL≤2 && POS≥99`。

## 两套仪器的关系（深度裁决）

- **main**（`main.c`）量"过闸 MAIN 复跑产率中位"；**calib**（`calib.c`）量"随机链撞中概率随 H 变化"（测 BHB 深度更对口）。
- 结论卡 v2.2：存在性 **success（定论）**；**BHB 有效深度"未裁决"** —— main 六档 CI 重叠无峰，calib 包称峰在 256，两套未正面对跑。
  **下一步正道：在 N2 直接跑 `calib.c` 与 main 对跑裁决深度。**

## 结论摘要（详见 `docs/reports/L1-1_结论卡_v2.2.md`）

- **存在性（定论）**：CTRL=0%、POS≈100%、NOSPEC=1 → SELF 0.0%、MAIN 窗口开时显著 >0。NOSPEC 归零证明信号必经推测路径。
- **幅度**：过闸 run 命中率中位 ~30%，单 run 5%–75%（点估计偏软）。
- **深度未裁决**：待跑 calib.c 复核。
- 判定 `status=success`，`failure_mode=null`。

## 引用与许可

- 原语本体来自 [`vusec/bhi-spectre-bhb`](https://github.com/vusec/bhi-spectre-bhb) `@ ae_final`，遵循其原始许可；本仓库仅对其做 N2（Yitian 710）移植与测量脚手架，`snippet.S`/gadget/JIT/触发时序未改。
- 本仓库的移植改造、测量脚手架、扫描/分析脚本与报告为实验室内部研究产物。引用上游工作请参见其论文与仓库。

> ⚠️ 仅用于授权的安全研究与复现，限本机同进程自测。
