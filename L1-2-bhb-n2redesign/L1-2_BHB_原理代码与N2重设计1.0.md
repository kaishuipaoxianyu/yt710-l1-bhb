# L1-2 Spectre-BHB：工作原理、vusec 代码剖析、与 N2 重设计

> 本文严格对齐三条要求：
> **① BHB 的工作原理 + Spectre 对 BHB 的攻击原理；② vusec/bhi-spectre-bhb 的代码结构、哪些是需要按 N2 调整的参数；③ 据此重做源码获取与实验重设计。**
> 源码已获取：`git clone https://github.com/vusec/bhi-spectre-bhb`（VUSec 原始仓库，含论文/Intel/ARM 安全公告链接）。

---

# 第一部分 · 要看懂的内容①：原理

## 1. 先回顾：间接分支与"预测目标"

分两种分支：
- **直接分支** `b label` / `if(...)`：目标写死在指令里。Spectre-**v1** 玩的是这个（条件分支的方向预测）。
- **间接分支** `br x0`（目标在寄存器里，运行时才知道）：如 C++ 虚函数、函数指针、`switch` 跳表、内核 syscall 分发。CPU 为了不等 `x0` 算出来，会**预测这个间接分支要跳到哪个地址**，先抢跑过去。Spectre-**v2 / BHB** 玩的是这个。

预测"间接分支跳哪"的部件，用两样东西做索引：**① 这条间接分支自己的地址；② 最近走过的一串分支的历史**。

## 2. BHB 是什么

**BHB（Branch History Buffer，分支历史缓冲区）**：CPU 内部记录**最近 N 条分支**走向/地址的一个滚动哈希。每执行一条分支，就把它的信息揉进这个哈希。预测间接分支时，CPU 用 `(间接分支地址, BHB哈希)` 一起去查预测表。

**核心性质（攻击的根）**：
> 两段**不同的代码**，只要它们到达某条间接分支前**走过的分支序列产生相同的 BHB 哈希**，就会**索引到预测表里同一项**——于是一段代码对该间接分支的训练，会**影响另一段**。这叫 **BHB 碰撞**。

直觉类比（给程序员）：预测表是个**哈希表**，key = `hash(间接分支地址, 最近若干分支的历史)`。你只要构造出**相同 hash 的 key**，就能读/写到别人那一格——经典哈希碰撞，只不过发生在 CPU 的分支预测器里。

## 3. Spectre 对 BHB 的利用（BHI = Branch History Injection）

### 3.1 为什么 BHB 能绕过 eIBRS（跨特权版，vusec 的主攻击）

Intel/ARM 后来加了硬件缓解 **eIBRS / CSV2**：**按特权级隔离**预测表，让用户态训练的"目标"不能直接用到内核态的间接分支上。听起来堵死了 Spectre-v2。

**但 BHB（分支历史）在进入内核时往往没被清掉。** 于是攻击者（用户态）精心走一串分支，把 BHB 哈希**注入**成某个值；随后进入内核，内核的某条间接分支用"内核地址 + 这个被污染的 BHB 哈希"去查表——落到攻击者早先在**同一历史**下训练过的那一项 → 内核间接分支**推测性地跳到攻击者选的 gadget** → 泄露内核数据。

> 一句话：**eIBRS 隔离了"目标表"，却没隔离"用来索引表的历史"。BHI 通过控制历史，让隔离形同虚设。** 这就是 CVE-2022-0001（Intel）/ Spectre-BHB（ARM）。

### 3.2 同特权 in-place 版（我们在 N2 上真正要做的）

跨特权版要改内核（见第二部分），云上做不了。vusec 的 `bhb_brute_force` 给了一个**纯用户态、同特权**的验证版，这才是 N2 的落点：

> 在**同一个进程**里构造两条分支链 A、B，它们最后都落到**同一条间接分支**（in-place）。用链 A 把这条间接分支训练成跳向"命中 gadget"（它会去读 `fr_buf`）。然后走链 B（历史不同）触发同一条间接分支——**如果 B 的 BHB 哈希和 A 碰撞**，这条间接分支会**推测性地跳向命中 gadget** → `fr_buf` 被缓存 → Flush+Reload 测到。

这验证的是：**710 上，分支历史（BHB）能否驱动间接分支的误预测。** 和我们 L1-1R 的 v1 自测是同一精神（同进程、已知靶、不碰外部），只是把"触发源"从 v1 条件分支换成 **BHB 驱动的间接分支误预测**。

---

# 第二部分 · 要看懂的内容②：代码结构与 N2 参数

## 4. 仓库结构（职责）

```
common/        公共原语(跨 x64/ARM)
  targets.h       ★各 CPU 的微架构参数(要为 N2 加一项)
  helper.h        ★计时/flush/fence 原语(ARM 用 pmccntr → N2 要改)
  flush_reload.h   1-bit Flush+Reload(2 条线, 泄露 1 bit)
  evict.h / ebpf_helper.h  eviction / eBPF 辅助(x64 内核攻击用)
pocs/          端到端内核泄露 exploit(需 root/内核)
  inter_mode/     跨特权: 绕过 eIBRS 从内核泄露
  intra_mode/     同特权: 内核到内核
re/            逆向实验(验证原语 + 测 BHB 参数)
  x64/  bhi_test / bhb_brute_force / bhb_size / bhb_control
  arm/  bhi_test(★需定制内核) / bhb_brute_force(★纯用户态, N2 起点)
tools/
  fr_checker      校准 Flush+Reload 阈值 THR
  ibrs_checker    检测 IBRS/eIBRS(x64)
```

**对 N2 最相关的三块**：`common/targets.h`（参数）、`common/helper.h`（原语）、`re/arm/bhb_brute_force`（用户态 BHB 碰撞，不需改内核）。

## 5. 逐段读 `re/arm/bhb_brute_force`（核心逻辑）

```c
void jit(uint8_t *mem, uint64_t *history) {
    // 把 history 里的地址串成一条"分支链":
    // 每个 history[i] 处写一条 B 指令, 跳到 history[i+1]  → 走过一串确定的分支
    for(i<HISTORY_SIZE-1) 写 B 指令(history[i] → history[i+1]);
    // 链的最后一个位置放间接 gadget: ldr x0,[x0]; br x0  (这就是被预测的间接分支)
    memcpy(&mem[history[last]], &ind_gadget, 8);
}
```
- `hit_history`：参考链，末端间接分支经 `hit_gadget`（`ldr x1,[x1]` 读 `fr_buf`）训练——走完这条链，间接分支"学会"跳去读 `fr_buf`。
- `ret_history`：每轮新随机链（各分支地址互相间隔≥16，避免自撞）。`IN_PLACE=1` 时**强制末端间接分支与 hit 链同址**（同一条间接分支，不同历史）。
- 每轮：先走 `hit_ptr` 训练；`clflush` 掉 `fr_buf` 和跳表项；再走 `ret_ptr` 触发。若 `fr_buf` 被推测性读进缓存（`load_time < THR`）→ `hits++`。`hits > ITER/2` 即判为**这条随机历史与 hit 历史在 BHB 里碰撞了**。
- 统计"平均多少轮碰到一次"，并对比 `IN_PLACE=1`(同址) vs `0`(异址) 能否碰撞。

**间接分支 gadget**（`snippet.S`，ARM）：
```asm
ind_gadget: ldr x0,[x0]; br x0     // 间接分支(被预测的对象)
hit_gadget:  ldr x1,[x1]; ret      // 命中标记: 读 fr_buf → 留 F+R 痕迹
ret_gadget:  nop; ret              // 良性目标
```

## 6. ★ 哪些是必须为 N2 调整的参数 / 代码（本节是要求②的核心交付）

| # | 位置 | 原值(Pixel6/Cortex-X1) | N2 上的问题 | 怎么改 |
|---|---|---|---|---|
| **1 计时器** | `helper.h` `rdtscp()` | `mrs pmccntr_el0`(PMU 周期计数) | N2 `perf_event_paranoid=4`，EL0 读 PMU **SIGILL** | 换 **`CNTVCT_EL0`**，或 L1-1R 的**计数线程**；阈值随之重标 |
| **2 启用 PMU 的自定义 syscall** | `main.c` `syscall(442)` | 定制内核放开 EL0 PMU | N2 **没有这个 syscall** | **删掉**；配合 #1 用免权限计时 |
| **3 Flush+Reload 阈值 THR** | `targets.h` | Pixel6=100(pmccntr 刻度) | 刻度/微架构都不同 | 用 **L1-1R 的 ruler 自标**重测（CNTVCT 下约 5）；可移植 `tools/fr_checker` 但它也用 pmccntr，要先改计时 |
| **4 STRIDE** | `targets.h` | 4096 | L1-1R 实测 N2 上 4096 会**撞组/预取**，需 4160 | 用 **4160**（独立页+独立 L1D 组）；1-bit F+R 只 2 条线，撞组弱，但预取仍防 |
| **5 HISTORY_SIZE** | `targets.h`/`main.c`(硬编码 64) | Pixel6 用 64 | **N2 的 BHB 深度未知**，是微架构相关的**关键 BHB 参数** | 需为 N2 测定：移植 x64 的 `bhb_size` 思路，或**扫 HISTORY_SIZE**（如 8→256）看碰撞率拐点 |
| **6 绑核** | `run.sh` `taskset 10` | Pixel6 大核 Cortex-X1 | N2 同构多核，无大小核 | `taskset -c 0` 或 `sched_setaffinity(core 0)`（同 L1-1R） |
| **7 编译器** | `Makefile` `$(CC_ANDROID)` | Android NDK clang | N2 是原生 Ubuntu | 换原生 `gcc`/`clang`(aarch64)，去掉 NDK/`env.sh` |
| **8 运行方式** | `run.sh` adb/fastboot | Android 设备 | N2 是 SSH 云主机 | 直接本地跑，去掉 adb |
| **9 RWX 内存 / JIT** | `main.c` `mmap(...PROT_EXEC)` + `__clear_cache` | 安卓允许 | 云 Ubuntu 可能有 **W^X/SELinux** 限制 | 先验证 `mmap PROT_READ|WRITE|EXEC` 可用；不行则改 `mprotect` 两段式或关闭相关限制 |
| **10 PHYS_OFFSET/PAGE_OFFSET** | `targets.h` | 内核地址偏移 | 仅 `pocs`(内核泄露)用，需 root/pagemap | **同特权自测用不到**，忽略 |
| **11 缓解现状(非参数, 但决定结果)** | — | — | N2 `spectre_v2 = Mitigation: CSV2, BHB`——**BHB 清除缓解已开** | 跨特权 BHI 大概率被堵；**同特权 in-place 碰撞**是否仍发生，正是要测的；得 `fail/untestable` 也是**有效结果** |

**跨特权 `re/arm/bhi_test` 为什么 N2 做不了**：它要**定制 Android 内核**（在 `invoke_syscall` 里插 `clflush` 加宽窗口 + 加自定义 `sys_bhi_hit` syscall），还要 Pixel6 + fastboot。云上 N2 的 Ubuntu 内核改不动、刷不了 → **放弃跨特权版，走同特权用户态版**。

---

# 第三部分 · 要求③：为 N2 重设计的实验（L1-2 卡）

## 7. 定位

**L1-2：同进程、同特权 in-place BHB 碰撞自测。** 验证"710 上分支历史（BHB）能否驱动间接分支的推测性误预测"。改编 `re/arm/bhb_brute_force`，**不改内核、云上可跑**，复用 L1-1R 全部成熟读出件。边界同 L1-1R：同进程、已知靶、不碰任何外部/跨租户目标。

## 8. 直接复用 L1-1R 的成熟组件（不重复造轮子）

- **计时**：CNTVCT_EL0 / 计数线程（替掉 pmccntr）；
- **读出**：STRIDE=4160（独立页+独立组）、每轮重随机、排伪影；
- **每轮 canary 校验 + NHIT_MAX**：滤 vCPU steal；
- **读出/推测质量分离**：阳性对照（架构性植入）钉读出 ~100%，`trate` 单独report BHB 误预测成功率；
- **统计**：mean/95%CI(Rule of Three)、对照塌不塌。

## 9. 源码获取与改造清单

```bash
# 在 N2 上:
git clone https://github.com/vusec/bhi-spectre-bhb.git
cd bhi-spectre-bhb/re/arm/bhb_brute_force
# 要改的文件:
#  ../../../common/helper.h   : rdtscp() 的 pmccntr → CNTVCT_EL0(或计数线程)
#  ../../../common/targets.h  : 新增 #elif defined YITIAN_N2 { ARCH=ARMV8; THR=<标定>; STRIDE=4160; HISTORY_SIZE=<扫出来> }
#  src/main.c                 : 删 syscall(442); HISTORY_SIZE 改为可从 targets.h 取; 绑核 core0
#  Makefile                   : CC_ANDROID → gcc; -D YITIAN_N2
```

## 10. 分阶段步骤（每阶段一个判据，像 L1-1R 那样先立读出再谈信号）

1. **读出自检**（移植 L1-1R 的 ruler + 阳性对照）：架构性植入标记线，F+R 恢复 ~100%。读出不干净就先修，别碰 BHB。
2. **RWX/JIT 可用性**：确认 `mmap(PROT_EXEC)` + `__clear_cache` 在 N2 Ubuntu 能跑（云上常见坑）。
3. **定 HISTORY_SIZE**：扫 8→256，看 in-place 碰撞率随历史长度的拐点 → N2 的 BHB 有效深度。
4. **in-place 碰撞主实验**：`IN_PLACE=1`，统计平均碰撞轮数 + 碰撞时的 `trate`。
5. **对照**（钉因果，照 L1-1R）：
   - C-nohist：历史随机但**不构造碰撞** → 应无误预测（证明是历史驱动）；
   - C-outofplace：`IN_PLACE=0`（异址）→ 预期无碰撞（ARM 文献结论，验证 N2 是否一致）；
   - C-barrier：在间接分支前下 `CSDB`/推测屏障 → 应塌。
6. **统计收尾** + 四件套（env/raw/summary/README，`summary` 带 `history_size`、碰撞率、trate、对照）。

## 11. 成功标准与预期（三态）

- **success**：in-place 碰撞率显著 > 随机基线，且 trate 随历史控制度上升；读出阳性对照全程 ~100%。→ 710 上 BHB 误预测原语**存在**。
- **fail / untestable**：若 `CSV2, BHB` 缓解把同特权 in-place 碰撞也堵死（碰撞率 ≈ 噪声、各对照无差）→ 记 `untestable`，**引用 `/sys/.../spectre_v2` 原文**说明缓解已开。**这同样是有价值的结论**：证明 710 的固件级 BHB 缓解对同特权也有效。
- **失败模式**：`E003` 计时（PMU 封死，已用 CNTVCT 规避）；RWX 被拒（W^X）；`E004` 信号淹没。

## 12. 边界与风险

- **同进程、同特权自测**，泄露本进程已知靶，**不碰任何外部/跨租户目标**；跨特权内核泄露版（`pocs`、`bhi_test`）**不做**。
- RWX+JIT 在云实例可能触发 W^X/SELinux，属环境限制而非攻击；
- `CSV2, BHB` 已开，结果可能是"缓解有效"——如实记录即可。

---

## 附：一句话给 YDL
> L1-2 改编 vusec/bhi-spectre-bhb 的**用户态 in-place BHB 碰撞**实验（跨特权内核版因需定制内核、云上做不了而放弃）。N2 要调的参数集中在 `targets.h`（新增 N2 目标：THR/STRIDE=4160/HISTORY_SIZE）和 `helper.h`（pmccntr→CNTVCT，删自定义 syscall），并复用 L1-1R 的读出修复与对照/统计框架。注意 N2 `spectre_v2=CSV2,BHB` 缓解已开，得到"同特权也被缓解"的 untestable 也是有效结果。
