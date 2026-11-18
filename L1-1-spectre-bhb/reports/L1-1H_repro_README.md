# main harness 复现包（给 ZYW）

> 目的：让你在**同一台机、同一个核（`-c 3`）、同一个 `THR=4`、同一个网格**上，
> 跑我方的 `main_thr4.o`（搜索+复跑+过闸），和你 `calib.c` 的结果并排比较。
>
> 这是你 `calib.c` 复现包的**对称回包**。全部改动相对 `vusec/bhi-spectre-bhb @ ae_final`：
> **2 处补丁（`helper.h` 计时、`targets.h` 目标块）+ 1 个改造版 `main.c`**。
> `snippet.S`、三个 gadget、JIT、训练/触发时序**一行未改**。

---

## 0. 这个包是什么

| 文件 | 内容 |
|---|---|
| `main.c` | 改造版上游 harness（搜到碰撞即原地复跑 2000×，落 CTRL/MAIN/POS/SELF 四闸） |
| `targets.h` | 含 `YITIAN_710` 目标块 + `THR` 的 `#ifndef` 保护（让 `-DTHR=N` 可覆盖） |
| `PATCH.md` | 两处补丁（`helper.h` 计时、`targets.h`）+ main.c 改动清单 |
| `build_and_smoke.sh` | 一键：环境自检 → 编 `main_thr4.o` → 冒烟 |
| `run_grid.sh` | 一键：8 点网格扫描 → `cross_main.csv` |

**它和你的 `calib.c` 测的不是同一个统计量**（这正是 224 vs 288 之差的根源）：

| | 你的 `calib.c` | 我方 `main_thr4.o` |
|---|---|---|
| 训练链 | 每条单独随机（`--hit-num` 条），无条件平均 | 每 run 搜一条碰撞链，复跑该链 |
| 指标 | **全体轮次 `hits` 均值**（随机链碰撞概率） | **过闸样本的命中率中位 %**（复现产率） |
| 闸门 | 无 | `SELF≥30 && CTRL≤2 && POS≥99` |
| 迭代 | `--iters 100` | `ITER=50` 搜索 + 复跑 2000× |

**所以两边数值不能直接比大小，只能比"形状"和"峰位"。** 对跑结论：产率峰 **208–224**、碰撞峰 **256–272**，
在 224–256 重叠，差异纯由度量定义。

---

## 1. 部署（3 分钟）

```bash
cd ~/710_l1/bhi-spectre-bhb/re/arm/bhb_brute_force

# 1) 放入改造版 main.c（覆盖上游）
cp /path/to/main.c src/main.c

# 2) 放入 targets.h（含 YITIAN_710 块 + THR ifndef 保护）
cp /path/to/targets.h ../../../common/targets.h

# 3) helper.h 计时补丁：若你已按 calib 包打过（cntvct、删 fence），这里无需再动
#    口径必须一致：cntvct 无 fence、ruler cached≈2 / flushed≈9、THR=4
```

## 2. 编译 + 冒烟

```bash
chmod +x build_and_smoke.sh run_grid.sh
./build_and_smoke.sh
```

**冒烟判据**（H=224, THR=4）：
- 打印出 `[SELF] / [MAIN] / [CTRL] / [POS]` 四行；
- `MAIN` 落在 **28~42%**（我这边多次约 35%）；
- `CTRL≈0`、`POS≈100%`、`SELF≈60~70%`。

## 3. 跑网格（约 15 分钟）

```bash
nohup ./run_grid.sh > wfy_main.log 2>&1 &
tail -f wfy_main.log
```
完成标志：`grep "DONE main" wfy_main.log`，产物 `cross_main.csv`（H,tool,metric）。

## 4. 合并对比（你我两份 csv 放同目录）

```bash
cat cross_calib.csv > cross_results.csv
tail -n +2 cross_main.csv >> cross_results.csv
python3 analyze_cross.py        # 归一化叠加，打印两条曲线峰位
```

---

# 我这边的基准值（供你核对，THR=4 / core 3）

| H | 192 | 208 | 224 | 240 | 256 | 272 | 288 | 304 |
|---|---|---|---|---|---|---|---|---|
| MAIN 中位% | 34.6 | **36.0** | 35.5 | 34.2 | 35.2 | 29.5 | 25.1 | 17.8 |

- 192–256 一片平台（~35%），峰名义在 208–224；过 256 下行，304 掉到 17.8。
- 另有 R=300 细扫（192–256，步长 8）：平台 208–240，各点 CI 重叠，点峰在 240（39.5）。
- THR 稳健性：THR=4/5/6 三版峰位不动（208/224/240，均在平台内）。

---

# 已知坑（我踩过的）

| # | 坑 | 症状 | 解法 |
|---|---|---|---|
| 1 | 用了错版 `main.c`（无 `[SELF]` 输出） | awk 抓不到 `[SELF]`，全被闸门过滤 → `cross_main.csv` 只有表头、**不报错** | 用本包 `main.c`；`run_grid.sh` 已加自检，无 `[SELF]` 会 ABORT |
| 2 | `targets.h` 的 `THR` 没加 `#ifndef` 保护 | `-DTHR=4` 与头文件宏冲突，编译报重定义 | 用本包 `targets.h`（已加保护） |
| 3 | `MAX_HISTORY` 太小 | `HIST>256` 报"HIST 越界" | 本包 main.c 已放宽到 1024 |
| 4 | 和 calib 同时跑、抢同一核 | 计时互相污染，数据作废 | 岔开跑；两套都 `taskset -c 3` |

---

# 期待你的结果

跑完把 `cross_main.csv` 和你的 `cross_calib.csv` 合并，看：

| 结果 | 结论 |
|---|---|
| 你复现出 main 峰在 **208–224** | ✅ 和解成立：224/288 之差纯由度量定义，非实验误差 |
| 你的 main 峰也在 **256–288** | ❌ 说明我方 harness 有系统偏移，需查 ITER/过闸语义 |
