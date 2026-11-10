# 需要打的两个补丁 + 一个改造文件（打在 `vusec/bhi-spectre-bhb @ ae_final` 上）

> 对称于你的 calib 包。`snippet.S`、三个 gadget、JIT、训练/触发时序**一行未改**。
> 被测推测路径是上游真身，我方只做了最小移植 + 测量脚手架。

---

## 补丁 1：`common/helper.h` —— 计时源（与你的 calib 包一致）

**位置**：`rdtscp()` 的 `#elif ARCH == ARMV8` 分支。

```diff
 #elif ARCH == ARMV8
     uint64_t result;
-    fence();
-    asm volatile("mrs %0, pmccntr_el0" : "=r" (result));
-    fence();
+    __asm__ __volatile__("isb\n\tmrs %0, cntvct_el0" : "=r" (result));
     return result;
```

原因同你：`perf_event_paranoid` 下 EL0 读 `pmccntr_el0` 会 SIGILL；删 `fence()` 后口径为
cached≈2 / flushed≈9，`THR=4`。**两人必须同口径，否则数据不可比。** 若你已为 calib 打过，这里无需再动。

---

## 补丁 2：`common/targets.h` —— 目标块 + THR 的 ifndef 保护

**位置**：`#elif defined CUSTOM_UARCH`（或 `#else/#error`）之前。

```c
#elif defined YITIAN_710
#define ARCH            (ARMV8)
#ifndef THR
#define THR             (4)
#endif
#define STRIDE          (4096)
#define PHYS_OFFSET     (0x80000000LL)
#define PAGE_OFFSET     (0xffffff8000000000ULL)
```

- **`THR` 必须用 `#ifndef` 包起来**，这样命令行 `-DTHR=4/5/6` 才能覆盖、不冲突（THR 稳健性检验用）。
- 默认值取 4，与 calib 口径一致。
- 本包直接附了改好的 `targets.h`，`cp` 覆盖即可，无需手改。

---

## 改造文件：`src/main.c`（改造版上游 harness）

**这是我方真正的仪器**，由上游 `re/arm/bhb_brute_force/src/main.c` 最小改造而来。改动 4 类：

| # | 改动 | 原因 |
|---|---|---|
| 1 | 计时 `pmccntr_el0` → `cntvct_el0`（经 helper.h） | PMU 不可读 |
| 2 | 删 `syscall(442)` | 去定制内核依赖 |
| 3 | 链长 `HISTORY_SIZE` 常量 → 运行时环境变量 `HIST`；`MAX_HISTORY` 放宽到 **1024** | 扫描自变量；支持 H>256 |
| 4 | 新增测量脚手架：ruler 自检 + 搜到碰撞即原地复跑 2000× 的 **CTRL/MAIN/POS/SELF** 四模式，落 `raw.csv` | 过闸、排假阳性、测量链路自检 |

**运行接口**（环境变量）：

```
HIST=<链长>  SHARE=1  TRAIN=128  ITER=50   taskset -c 3 ./main_thr4.o
```

**四闸含义**：

| 标签 | 含义 | 期望 |
|---|---|---|
| `[POS]` | 强制间接分支真跳 hit_gadget（不 flush fr_buf） | ≈100% → 测量链路有效 |
| `[CTRL]` | 误训练到安全目标 ftable[0] | ≈0% → 噪声底 |
| `[SELF]` | 同链自撞正对照（gate-2） | 高（≥30）→ 可过闸 |
| `[MAIN]` | 训练 hit_gadget、测 ret 链是否误跳 | 响应变量 |

过闸判据：`SELF≥30 && CTRL≤2 && POS≥99`；`MAIN%` = 2000 次复跑中 `load_time<THR` 的比例。

> 本包直接附了改好的 `main.c`，`cp` 覆盖即可。构建见 `build_and_smoke.sh`。
