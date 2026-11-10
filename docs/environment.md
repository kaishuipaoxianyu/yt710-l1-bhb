# 目标机环境 + THR 稳健性

> 来源：对话版 §7。标【需导出】处为对话未流经的原件，权威值以服务器 `export_from_server.sh` 产出的 `env/` 为准。

## 1. 环境实测值（完整 `lscpu` 原文【需导出】）

```
CPU:                 ARM Neoverse-N2（倚天 710），aarch64，1 thread/core（无 SMT）
机器:                阿里云 ECS 8.137.179.142，主机名 lab-g8y，4 vCPU / 16 GiB / 40 GiB SSD
OS:                  Ubuntu 26.04
kernel (uname -r):   7.0.0-42-generic         # 完整 uname -a 需导出
governor:            performance（四核锁定 ~3.0 GHz）
计时:                cntvct_el0；cntfrq_el0 = 50 MHz → 1 tick = 20 ns（≈55 cycle @3GHz）
perf_event_paranoid: 4    （EL0 读 pmccntr_el0 → SIGILL，故改用 cntvct）
perf_user_access:    0
spectre_v2:          Mitigation: CSV2, BHB     （异常边界清 BHB，堵跨特权；不影响同进程 EL0 mistraining）
spectre_v1:          Mitigation: __user pointer sanitization
dc civac (clflush):  EL0 可执行
mmap RWX:            可用（JIT 需要）
```

## 2. THR 4/5/6 稳健性

**概念先纠正**：ruler 的 `cached/flushed` 是**实测时间**，不随 THR 变；THR 只是在双峰之间画的判别线。不是"每档一套 ruler"，而是**同一把尺子**（cached≈2 / flushed≈9），把阈值画在 4 / 5 / 6。

实测 ruler：
```
口径（含 fence，main 主用）：cached ≈ 2.04–2.08，flushed ≈ 9.0–9.4    → 谷在 ~5
口径（删 fence，ZYW calib）：cached ≈ 1.3–1.8， flushed ≈ 8.1–8.3    → 谷在 ~4
```
> 单档精确 ruler：THR=5(main sweep) cached 2.05/2.08、flushed 9.43/9.36；THR=4(calib) cached 2.04、flushed 9.01。THR=6 的单独 ruler 数值未单独记录【如需精确值请重跑或从 sweep_thr 日志导出】。

**四闸随 THR**（main；以下为 MAIN 中位，CTRL 全程≈0、POS≈100、SELF 随 H 单调下滑；逐档精确值见 `sweep_thr_results.csv`）：

| THR \ H | 128 | 176 | 208 | 224 | 240 | 272 | 320 | argmax |
|---|---|---|---|---|---|---|---|---|
| THR=4 | 22.3 | 34.9 | 38.6 | 38.2 | 40.2 | 30.6 | 10.9 | H=240 |
| THR=5 | 22.0 | 33.4 | 40.0 | 38.9 | 38.2 | 31.1 | 10.9 | H=208 |
| THR=6 | 21.6 | 33.3 | 37.9 | 41.7 | 39.9 | 30.6 | 10.8 | H=224 |

**为什么以 THR=5 为基线、另两档起什么作用：**
- **THR=5 是基线**：主用(含 fence)口径下 ruler 双峰 cached≈2 / flushed≈9，谷底中点≈5，落在双峰间隔正中，最不易判错。`targets.h` 的 `YITIAN_710` 默认即 THR=5。
- **THR=4/6 的作用**：稳健性检验。证明"HISTORY_SIZE 最优峰位"不随阈值在谷内移动（三档峰都在 208–240），排除"峰是计时阈值造出来的假象"。
- **THR=4 另一用途**：与 ZYW 删-fence 口径/calib 默认对齐，仅用于双仪器对跑（两边必须同阈值才可比）。**阈值不可跨 fence 口径比较**。

## 3. 其余基线值依据（一句话）
- **TRAIN=128**：分支预测器误训练需多次迭代饱和；训练 1 次（v1.0 的 bug）打不偏、MAIN 塌到 ~0.1%；128 确保饱和（修复后 MAIN 立即显著 >0）。
- **ITER=50**：搜索轮每点迭代数（够快找到碰撞即原地复跑 2000×）。
- **SHARE=1**：in-place 复用训练链**末 1 条**地址（纯历史效应的最小设定）。
- **STRIDE=4096**：单线探测用页大小即可；256 线恢复才需 4160(=65×64，躲自驱逐+跨页躲预取，见 L1-1R)。
