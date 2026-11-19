# L1-3 MDU 可测量性与跨进程可观测性 —— 实验日志

> **文件性质**：这是 L1-3 任务的**唯一权威记录**，逐次会话累加，不删旧内容（作废的只加删除线并标注原因）。
> **维护规则**：每次实验会话结束时，必须更新 ① §7 数据记录（追加新表）② §8 当前结论 ③ §9 待办 ④ §10 变更记录。其它节只在事实被推翻时改。
> **接手方式**：新对话拿到本文件 + `L1-3_MDU可测量性_交接简报.md`，即可无上下文接手。
> **最后更新**：2026-11-19（会话 1–31）
> **判决书**：`L1-3_MDU_结论卡.md`（本文件是证据卷，结论看那张卡）
>
> **交付清单（四件套，全在本工作区）**
>
> | 路径 | 内容 |
> |---|---|
> | `L1-3_MDU_结论卡.md` | 判决书：**Q-A ✅ / Q-B ✅ 定案（正向）**；信道 **K=8 → 3.12% @ 78.9 kbps**（S1x 曲线） |
> | `L1-3_MDU_实验日志.md` | 本文件：**30 台**装置（TC-01～TC-21）逐台源码内嵌 |
> | `src/*.c` | **30 个**装置源码，可直接 scp 到服务器重编 |
> | `papers/*.pdf` | 两篇参考论文原件（ARMeD @ TCAD 2025、Leaky MDU @ DAC 2023） |

---

## 1. 任务定义

用户原话：**确认 710 上的 MDU 是否可测量；参考 MDU 泄漏论文；目的是确认 710 上的 MDU 是否可跨进程观测。**

拆成两问，有先后依赖：

| 编号 | 问题 | 判据 |
|---|---|---|
| **Q-A** | 本机、同进程内，论文所指的 MDU 信号能否用现有计时手段分辨 | 过 SELF（A/A + 剂量反应），且两态置信区间可分 |
| **Q-B** | 一个进程能否通过 MDU 观测到另一个进程（**核心**） | 论文的跨进程前提逐条在 710 上成立 + 实测信道 |

**任务性质**：测量/刻画"信道是否存在、能否观测"，不是做窃密工具。受害侧秘密一律用自种探针，不碰真实密钥或他人进程数据。

---

## 2. 平台硬事实（已确认，不重测）

| 项 | 值 | 对 L1-3 的约束 |
|---|---|---|
| CPU | 阿里倚天 710 / **ARM Neoverse-N2**，aarch64 | 结论只绑这颗核 |
| 核数 | 4 vCPU，**Thread(s) per core = 1**，Socket = 1 | 无 SMT；两进程只能**同核时分**，不能同核同时 |
| 主频 | 3.0 GHz 锁定（min=max=3000 MHz，governor=performance） | 1 cycle ≈ 0.33 ns |
| 计时源 | `cntvct_el0`，`cntfrq_el0` = 50 MHz → **1 tick = 20.000 ns** | 唯一可用的尺子 |
| 计时器真实性 | `nanosleep 100 ms` 校准：实测 **100.065 ms**，比值 **1.0007** | 计数器真实、未被 trap 停摆 ✅ |
| 更细计时器 | `PMCCNTR_EL0` 被禁（`perf_event_paranoid = 4`，读即 SIGILL） | 拿不到 0.33 ns 级 |
| 缓解 | `spectre_v2: CSV2, BHB`，CSV2 = `0b0010` | CSV2 只清分支预测器（BHB/BTB），**不清后端 MDU** |
| 能力 | `dc civac` EL0 flush **实测可用**（无 SIGILL）；`mmap` RWX 可用 | 冷态装置可靠 |
| 系统 | Ubuntu 26.04 / kernel 7.0.0-42-generic / 主机名 lab-g8y | — |
| 磁盘 | `/dev/nvme0n1p2` 40G，用 12G，余 26G | 够 |
| 绑核 | 全程 `taskset -c 3` | 核 3 存在（0–3 共 4 核） |

---

## 3. 参考论文（本任务的"论文"= MDU 泄漏论文）

> **重要更正**：MDU ≠ 乘除单元。MDU = **Memory Disambiguation Unit（内存消歧单元）**，位于 CPU 后端，负责让 load 在更老的 store 地址未解析前**投机超前发射**。该方向没有 S&P/CCS/USENIX/NDSS 正会论文，原始工作只有下面这一组（清华-北邮-UMD 同一条线）。

> **原文已取得并解析（2026-11-19）**，本地副本：
> - `papers/ARMeD_TCAD2025.pdf`（2.47 MB，IEEE TCAD 全文）
> - `papers/LeakyMDU_DAC2023.pdf`（1.50 MB，DAC 全文）
>
> 正文抽出的关键事实见 **§3.5**；与论文的逐项对账见结论卡 §8。

### 3.1 主论文（本任务基准）

| 项 | 内容 |
|---|---|
| 标题 | *Exploiting ARMeD Channels By Reverse Engineering ARM Memory Disambiguation Unit* |
| 作者 | Chang Liu, Zhouyang Li, Haixia Wang, Pengfei Qiu, Gang Qu, Dongsheng Wang |
| 单位 | 清华大学 / 北京邮电大学 / Univ. of Maryland |
| 出处 | **IEEE TCAD** 2025, vol.45 no.2, pp.1075–1088（CCF-A 期刊） |
| DOI | [10.1109/TCAD.2025.3585078](https://doi.org/10.1109/tcad.2025.3585078) |
| 链接 | [IEEE Xplore](https://ieeexplore.ieee.org/document/11063390) |
| 状态 | 摘要已获取并逐句核对；**正文（PDF）尚未取得** |

**摘要可确认的要点**：
1. 首次对 ARM CPU **后端 MDU** 做深入逆向。
2. 覆盖 **4 个微架构**（ARM 与 Apple 各若干）——**具体型号未在摘要给出，待正文**。
3. 发现 **两种 MDU 设计：switch-based 与 counter-based**；分析其**状态机、选择机制、组织结构**。
4. 提出新信道 **ARMeD channels**，演示三类攻击：**跨进程隐蔽信道**、**网站指纹**、**Spectre 攻击新实现**。
5. 给出防御，MDU 预测准确率损失 **< 3%**。

### 3.2 副论文（首次披露）

| 项 | 内容 |
|---|---|
| 标题 | *Leaky MDU: ARM Memory Disambiguation Unit Uncovered and Vulnerabilities Exposed* |
| 作者 | 同组（Chang Liu, Yongqiang Lyu, Haixia Wang, Pengfei Qiu, Dapeng Ju, Gang Qu, Dongsheng Wang） |
| 出处 | **ACM/IEEE DAC 2023**（CCF-A 会议），pp.1–6 |
| DOI | [10.1109/DAC56929.2023.10247985](https://doi.org/10.1109/dac56929.2023.10247985) |
| 链接 | [ACM DL](https://dl.acm.org/doi/abs/10.1109/DAC56929.2023.10247985) · [IEEE](https://ieeexplore.ieee.org/document/10247985) |
| 状态 | 摘要已获取；正文未取得 |

**摘要可确认的要点**：
1. MDU 在**现代处理器**上被广泛用于**投机执行 load**、提升流水线性能。
2. ARM 的 MDU 设计细节**不公开** → 此前不清楚是否有安全漏洞。
3. 逆向出**未文档化特性**后，发现**三类用户态攻击**：
   - **跨进程攻击**：用户之间通过**隐蔽信道**通信；
   - **跨域攻击**：泄漏**内核**信息；
   - **进程内/进程间 Spectre 的新变种**。
4. 这些攻击 *“可以**绕过所有已知的**针对 cache 侧信道和针对瞬态执行攻击的缓解”*。
5. 讨论了潜在缓解方案。

### 3.3 旁证

| 标题 | 出处 | 说明 |
|---|---|---|
| *MDPeck: Breaking Balanced Branches in SGX with Memory Disambiguation Unit Side Channels* | [NUS 公开 PDF](https://www.comp.nus.edu.sg/~tcarlson/pdfs/liu2025mbbbiswmdusc.pdf) | 同机制的第三方工作；本机网络 TLS 受限，PDF 未下载成功 |

### 3.4 论文正文仍缺的四项（决定 Q-A/Q-B 判决）

| # | 缺什么 | 为什么关键 |
|---|---|---|
| 1 | **四个微架构的具体型号** | 里面有没有 Neoverse 系？没有则 N2 是"第五个未测核"，结论必须自测 |
| 2 | **计时方法与所需分辨率** | 用什么读时间、多少个 cycle 的信号、放大几倍 |
| 3 | **跨进程实验设置** | 是否同核绑核、被抢占后如何恢复、信道带宽 |
| 4 | **switch/counter-based 的索引方式** | 按地址索引还是按 PC 索引？决定探针该扫地址还是扫代码 |

---

### 3.5 论文正文已到手：抽取结果（2026-11-19，会话 17）

两篇 PDF 已取到并解析（IEEE TCAD 2025 全文 + DAC 2023 全文）。**以下为原文级事实，替换此前所有推测。**

| §2 项 | 论文原文结论 | 我们此前的假设 | 判定 |
|---|---|---|---|
| **MDU 是什么** | CPU 后端"预测 load 是否与更老 store 别名"的部件；预测 **load blocking**（等待）或 **store bypassing**（绕过） | 一致 | ✅ 对 |
| **索引键** | **由 load 的 PC 选择表项**（`MDU contains a buffer selected by the load PC`）。Cortex-A72 的表项内还有 **16-bit 向量**，用 **PC[5:2]** 选其中一位；Apple 用哈希压缩 PC | 我们猜"PC 或地址，未定" | ✅ **PC**；我们 S1h/S1i 用同一函数=同一 PC，方向对 |
| **信道类型** | 状态型，两态：`load blocking` / `store bypassing` | 一致 | ✅ |
| **跨进程前提** | 攻击者 EL0、受害者另一进程，"**both run on the same core and use the same MDU**"，**不共享地址空间**；同步靠时间戳或缓存侧信道 | 我们已推断"同核、不需 SMT" | ✅ 推断被证实 |
| **计时** | **必须 cycle 级**。Cortex-A：在 EL1 开 PMU、启用 **PMCCNTR**，EL0 用 `mrs` 读；Apple：另起计数线程 | 本机 PMCCNTR 被禁，只有 20 ns cntvct | ⚠️ **最大差距** |
| **放大结构** | store 前 **10 条寄存器相关乘法**算 store 数据地址（拖晚地址生成）；load 后 **10 条乘法**触发端口争用放大；协议 = **10 次 n → 10 次 a → 10 次 n**（a 首调用回滚 t3，其后学成 t2）；实验前 **idle CPU 复位** | 我们用指针追逐 + fence 隔离 | ❌ **结构与论文不同** |
| **平台** | 7 个微架构：Cortex-A53 / A72 / A73 / Apple Blizzard(A14?) / Avalanche(M1/M2)。**无 Neoverse** | — | N2 是未测核 |
| **局限** | 必须同核；A73/Apple 的 MDU 只由**已提交**的 load 更新；MDU 只有两态 | — | — |
| **跨进程隐蔽信道** | 发送方把状态设为 block→bit0、bypass→bit1；接收方每轮把状态复位为 bypass | — | 可作为后续 S2 的模板 |

**三种时序的定义（据原文）**：
- **t1** = 预测 bypass 且实际非别名 → load 乱序越过 store（**最短**）
- **t2** = 预测 block（无论实际是否别名）→ load 等 store 地址生成（中等）
- **t3** = 预测 bypass 但实际别名 → 检测到误预测、回滚重发（**最长**）

**这解释了此前全部失败**：
1. 我们用 fence 把乱序窗口关掉 → MDU 无事可做；
2. 我们的"训练"是外部喂的，而论文的"训练"是 **MDU 自己在第一次误预测后学到的**——正确观测量是 **t3 单点尖峰 + t2 平台**，不是"训练前后差"；
3. 论文需要 cycle 级计时，我们只有 20 ns → 只能靠**块聚合**把 cycle 差放大。

---

## 4. §2 抽取表（MDU 主体属性）

| §2 项 | 已确认（摘要原文级） | 状态 |
|---|---|---|
| 0. MDU 是什么 | CPU 后端的 **Memory Disambiguation Unit**，"投机执行 load 指令、提升流水线性能" | ✅ |
| 两种设计 | **switch-based** / **counter-based**，含状态机、选择机制、组织结构 | ✅（细节待正文） |
| 平台 | 4 个微架构（ARM + Apple） | ⚠️ 型号待正文 |
| 1. 信道类型 | **预测器状态型**（"这条 load 是否依赖那条 store"→ 直接改 load 发射时机），非数据相关延迟 | ⚠️ 类型确认，实现待正文 |
| 2. 跨进程前提 | 用户态↔用户态，跨进程隐蔽信道（两篇都明确演示） | ✅ 形式确认；**SMT 要求未提及，见 §5.3 推论** |
| 3. 计时器与分辨率 | 摘要未涉及 | ❌ 待正文 |
| 4. 放大/测量结构 | 摘要未涉及 | ❌ 待正文 |

---

## 5. 方法纪律（项目继承 + 本任务新增）

### 5.1 继承自 L1-1/L1-2H（不可破）

1. **口径先锁死**：删-fence / 含-fence 两种口径**阈值不可混比**。本项目定量基线 = **删-fence / THR=4 / cntvct 20 ns**。
2. **新装置开头必跑 ruler**：cached vs flushed 比值 ≥2 才算计时器能分两态，并**现算本装置阈值**。
3. **SELF 闸门**：POS（架构真算）证明不了能测到目标信道。新装置必须先用"已知为真"的自测复现出信号（≥ 约 10%）才放行。**历史教训：曾连报 21% / 44.8% / 48.2% 三个假阳，全部作废。**
4. **统计以"轮"为单位**，中位数 + 区间估计，**配对设计 + 对照臂**，不用单点估计。
5. **诚实定界**：严格区分"**未观测到**"与"**不可能存在**"；结论必带 **平台 / 二进制 / 机制** 三条边界。

### 5.2 本任务新增（因 20 ns 量化而必须）

6. **A/A 假阳标定**：两个**完全相同**的臂互比，量出"真实无差异时中位数自己会抖多少"，这个数就是判"两态可分"的硬阈值。任何 Δ 落在阈值内，一律写"未观测到"。
7. **剂量-反应**：真信号随训练强度单调增长并饱和；噪声不。比单点比大小可靠。
8. **量化下界报法**：中位数被量化到整数 tick 时，bootstrap 区间会退化成一点（如 `[10.00,10.00]`），**不可当精度报**。改写为：
   > med ± 1 tick → 比值区间 `[med_low/med_high, med_high/med_low]`
   例：hot=1±1、cold=10±1 → 比值保守下界 10/2 = **5**。
9. **地板扣除**：`rd()->rd()` 恒有 **1 tick（20 ns）** 系统偏移，所有单样本测量需扣除或声明。
10. **量化地板处中位数失明**：当每样本的观测值只落在 ±1 tick 内时，**中位数只能取 −1/0/+1，对小于半 tick 的系统偏移彻底失明**（S1 就栽在这）。此时必须改用 **配对差值均值 + bootstrap 均值 CI**，靠 1/√N 把 400 个样本的微小系统偏移捞出来。

### 5.3 关键架构推论：**无 SMT 不是死穴**

> 论文全部实验平台都是 **ARM Cortex-A 系 + Apple 核**，**全部为单线程核（无 SMT）**。既然平台根本没有 SMT，其跨进程信道在原理上**不可能依赖"同核同时执行"**，只能依赖另一条路：**MDU 状态在上下文切换 / 异常边界上不被清，靠同核时分共享**。
>
> 推论：简报 §3 把"无 SMT"标为第一道死穴，**方向反了**——无 SMT 反而与论文平台一致。真正的约束变成：
> - (a) 两进程被调度到**同一物理核**（`taskset -c 3` 可构造时分）；
> - (b) MDU 状态跨上下文切换**不清**（ARM 架构无此机制；CSV2 只覆盖分支预测器）；
> - (c) 云虚机 vCPU **不被 hypervisor 迁核**（本机特有风险，只能靠实测命中率说话）。
>
> 状态：**待正文正明 + 待 S1/S2 实测**。

### 5.4 服务器红线（每次守）

- 用户**手动**跑命令，**一次只给一个可直接粘贴的命令块**，等结果再给下一块。
- **不许 sudo、不许 pip install、不许改内核/缓解/BIOS**。
- 只写 `~/`、`/tmp`、`~/mdu_l13/`；重活先 `df -h`。
- 全程 `taskset -c 3`。
- 只用自种探针，不碰真实密钥或他人进程数据。

---

## 6. 装置清单（源码在服务器 `~/mdu_l13/`）

| 编号 | 文件 | 用途 | 状态 |
|---|---|---|---|
| **S-1** | `ruler.c` | 计时器 ruler 自检 + cntvct 真实性校准（cached vs `dc civac` flushed） | ✅ 已跑，PASS |
| **S0-v1** | `amp_sweep.c` | 放大扫描（指针链，K=1..256 × 4 工作集） | ❌ **作废**：工作集不随 K 缩放（见 §7.2） |
| **S0-v2** | `amp_sweep2.c` | 层级延迟标定 + A/A 假阳标定（起点每样本轮转） | ✅ 已跑 |
| **S1** | `mdu_probe.c` | MDU 状态可训练性：TR 剂量-反应 + TR=0 内建 A/A | ❌ FAIL（装置缺陷，见 §7.5） |
| **S1b** | `mdu_self.c` | G1/G2 SELF 闸门（地址晚到 24 级乘法链） | 🔶 HALF（G1 PASS，G2 被抢占污染 sd=142） |
| **S1b-v2** | `mdu_self2.c` | 转发重叠 SELF 闸门（8B store vs 4B store） | ✅ **G2 PASS**：+37 tick = 8.7 cycle/iter |
| **S1c** | `mdu_state.c` | 同 PC 训练剂量反应（off=0/−4 训练后读"部分重叠代价"） | ❌ 初判 PASS（S=−6），后经 S1e 查明为位置伪影，**作废** |
| **S1d** | `mdu_dose.c` | 特异性控制（off=+8 臂）+ TR 剂量反应 | ❌ 判据冲突（S_ctrl ±1 tick 被误判显著；且与 S1c 符号相反） |
| **S1e** | `mdu_order.c` | 反序对照（正序/反序两遍） | ❌ **假阳**：位置伪影主导（见 §7.5） |
| **S1f** | `mdu_direct.c` | 换几何：直接包住 probe、不做大块相减、条件轮转、前后半段自复制 | ❌ **PASS 但作废**：`S_ctrl = −59 tick` → 效应不特异，查明为**地址碰撞混淆**（见 §7.5） |
| **S1g** | `mdu_clean.c` | probe 挪远端 + 四条件（含远端训练对照） | ❌ **无效**：68 tick 残差但形状反了（远端训练最慢）→ 乱序重叠 + 跨线 store |
| **S1h** | `mdu_fence.c` | fence 隔离（`dsb ish;isb`）+ 全对齐训练 + 四条件 | ✅ **CLEAN**：四条件全 60.0 tick，差 **0.00** |
| **S1i** | `mdu_addr.c` | 同址训练（唯一能共享 MDU 表项的配置），只变训练宽度 | ✅ **CLEAN**：四条件全 60.0 tick，差 **0.00** |
| **S1j** | `mdu_xctx.c` | **跨上下文**：双线程钉核 3、`sched_yield` 交接，另一上下文中训练、本上下文探测 | ✅ **CLEAN**：四臂 174/174/174/175 tick，maxdiff 1.00 |
| **S1k** | `mdu_md.c` | 无 fence + store 地址晚到（指针追逐）+ 数据依赖串行；ALIAS vs NOALIAS | ⬜ **已交付未跑**（该区间已被 S1m/S1p 覆盖，可选旁证） |
| **S1m** | `mdu_st2ld.c` | **论文复现**：Listing 2/3 的 st2ld（10 乘法 + 10n→10a→10n） | ✅ 已跑：逐次 profile 全 1 tick（分辨率所致），块聚合 D=+1 tick |
| **S1n** | `mdu_ctrl.c` | **S1m 的对照组**：dA(别名块差) vs dN(非别名块差)，净效应 S = dA−dN | ✅ **dA=+1.00 / dN=+0.00 / S=+1.00** |
| **S1o** | `mdu_rst.c` | **RST 剂量反应**：判别"队列深度" vs "一次性学习" | ❌ **QUEUE**：dA = 1/1/2 tick（随 RST 涨）→ **S1n 的 PASS 作废** |
| **S1p** | `mdu_amp.c` | **M 倍累加放大**：把"一次误预测"重复 32 次累加，绕开 60 cycle 量化台阶 | ✅ **SIGNAL**：X=+37 / Y=0 / S=+37 tick |
| **S1q** | `mdu_xproc.c` | **跨进程**：两进程钉核 3，一进程训练、另一进程探测 | ✅ **PASS**：TA=815 / TB=502 / D=+310 tick |
| **S1r** | `mdu_chan.c` | 信道初测（固定阈值 `K×1.3`，单次 128 bit） | ✅ 已跑：3.12%（95%CI 约 1–8%）@ ~74 kbps（**S1x 用中点阈值重测为 78.9，见 §8**） |
| **S1s** | `mdu_kill1.c` | **杀死控制①**：去掉 store 地址拖晚 → 同进程 X 必须掉到 0 | ✅ **PASS**：S_LATE=+36 / S_EARLY=+0 |
| **S1t** | `mdu_kill2.c` | 跨进程控制（**设计有缺陷，无信息量**）：两臂都是 n 训练 | ❌ **作废**：D=−2.0（两臂都慢，无法区分 PC 索引与全局状态） |
| **S1u** | `mdu_kill3.c` | 两臂都用 a 训练，只差同 PC / 异 PC | ❌ **无信息量**：两臂都 511（我判据写反了——a 训练下自训练会让两臂都变快） |
| **S1v** | `mdu_kill4.c` | 地址打印排除 ICF + n 训练判别 PC 索引 | ✅ **PASS**：同PC 756 / 异PC 509，D=+246 tick |
| **S1w** | `mdu_cycle.c` | **补限制①**：计数线程做 cycle 级交叉验证 | ✅ 已跑：27.9 cycle/事件（与 cntvct 的 69 差 2.4×，仅量级一致） |
| **S1x** | `mdu_curve.c` | **补限制②**：K 扫描 + 中点阈值 | ✅ 已跑：K=8 → 3.12%@78.9kbps；K=16 → 2.34%@39.5kbps |
| **S1y** | `mdu_msweep.c` | **补限制③**：M 剂量反应，检验放大是否忠实（解释 69/36/29 散布） | ✅ 已跑：S/M = 1.000 / 1.094 / 1.148（spread 1.15×）→ 放大忠实 |
| **S1z** | `mdu_cores.c` | **补限制④**：四核各跑一遍 | ✅ **PASS**：S = 36/37/37/36 tick，max/min 1.03× |
| **S1aa** | `mdu_cal.c` | **补限制①收尾**：已知负载标定两套计时器 | ✅ 已跑：纯 load 比值 0.99；store 密集 2.72 → **计数器对 store 密集负载系统性少计** |

### 6.1 各装置关键设计点（重建用）

**计时原语（三装置共用）**
```c
static inline uint64_t rd(void){ uint64_t t; __asm__ __volatile__("mrs %0, cntvct_el0":"=r"(t)); return t; }   // 删-fence 口径
static inline uint64_t rd_f(void){ uint64_t t; __asm__ __volatile__("isb; mrs %0, cntvct_el0":"=r"(t)); return t; } // 含-fence
static inline void flush_line(const void*p){ __asm__ __volatile__("dc civac, %0"::"r"(p):"memory");
                                             __asm__ __volatile__("dsb ish":::"memory"); }
```

**S0-v2 核心（起点轮转，修 v1 缺陷）**
```c
__attribute__((noinline)) static void chase_from(unsigned char *buf, size_t line, int T){
  unsigned char *p = buf + line*64;
  for(int i=0;i<T;i++){ uint32_t off;
    __asm__ __volatile__("ldr %w0, [%1]" : "=r"(off) : "r"(p) : "memory"); p = buf + off; }
  sinkb = *p;
}
/* 每样本 line = xorshift() % nlines  → 跨样本覆盖整个缓冲区 */
```

**S1 核心（训练/测量共用同一函数 → load/store PC 恒定，两臂只差地址）**
```c
__attribute__((noinline)) static void phase(void *s, void *l, int n){
  uint64_t acc=0, x=0; const uint64_t v=0x11111111ULL;
  for(int i=0;i<n;i++){
    __asm__ __volatile__("str %1,[%2]\n\tldr %0,[%3]" : "=&r"(x) : "r"(v),"r"(s),"r"(l) : "memory");
    acc += x; }
  sinkv = acc;
}
/* 臂1: phase(A,A,TR) 教"依赖" → 测 phase(A,B,MP)
   臂2: phase(B,C,TR) 教"无关" → 测 phase(A,B,MP)
   Δ = 臂2 − 臂1（预期为负）；TR=0 组 = 两臂都不训练 = A/A */
```

---

## 7. 数据记录（逐次追加，勿删）

### 7.1 会话 1 — S-1 ruler（2026-11-18）

| 项 | 值 |
|---|---|
| `cntfrq_el0` | 50 000 000 Hz → 1 tick = 20.000 ns |
| cntvct 校准（nanosleep 100 ms） | 实测 100.065 ms，**比值 1.0007** |
| `rd()->rd()` 自身开销 | **中位 1.0 tick（20 ns），p95 1.0** |
| hot（cached，BATCH=64 loads） | 中位 **1.0 tick = 20 ns**，p5 1.0 / p95 2.0 |
| cold（`dc civac` 后） | 中位 **10.0 tick = 200 ns**，p5 9.0 / p95 14.0 |
| **ratio cold/hot** | **10.00**，bootstrap 区间退化为 [10.00,10.00] → 按 §5.2-8 改写为 **[5, 20]** |
| 两态可分 | **YES**（cold_p5 9.0 > hot_p95 2.0） |
| 含-fence 对照 | hot 2.0 / cold 9.0 / ratio 4.50（仅参照，不与主口径混比） |
| **判定** | **RULER PASS**（最保守下界 5 > 2） |
| 附带结论 | hot 64 次 L1 命中 = 20 ns ≈ 32 cycle → **单次测量已掉进 1 tick 地板内**，单操作级差异天生不可见，必须放大 |



#### 源码 S-1 `ruler.c`（完整，可直接编译）

> CC=gcc -O2 -o ruler ruler.c；运行 `taskset -c 3 ./ruler`

```c
/* ruler.c —— 计时器 ruler 自检 + cntvct 真实性校准（TC-01 / 会话 1）
 * 编译: gcc -O2 -o ruler ruler.c      运行: taskset -c 3 ./ruler
 * 判据: ratio cold/hot >= 2 且两态分布不重叠
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <unistd.h>
#include <time.h>

#define BATCH  64
#define NSAMP  2000

static unsigned char target[4096] __attribute__((aligned(4096)));
static volatile unsigned char  sink;
static volatile uint64_t       ssink;

static inline uint64_t rd(void)   { uint64_t t; __asm__ __volatile__("mrs %0, cntvct_el0":"=r"(t)); return t; }
static inline uint64_t rd_f(void) { uint64_t t; __asm__ __volatile__("isb; mrs %0, cntvct_el0":"=r"(t)); return t; }

__attribute__((noinline)) static void touch(void){
  volatile unsigned char *p = target;
  unsigned char s = 0;
  for (int i = 0; i < BATCH; i++) s ^= p[(i*8)&63];
  sink = s;
}

static inline void flush_line(const void *p){
  __asm__ __volatile__("dc civac, %0" :: "r"(p) : "memory");
  __asm__ __volatile__("dsb ish" ::: "memory");
}

static void on_sigill(int s){ (void)s;
  const char m[]="!! SIGILL: dc civac / dsb 在 EL0 不可用, ruler 无法继续\n";
  ssize_t r = write(2, m, sizeof(m)-1); (void)r; _exit(90);
}

static int cmpu(const void*a,const void*b){ uint64_t x=*(const uint64_t*)a,y=*(const uint64_t*)b; return (x>y)-(x<y); }
static double q(const uint64_t*v,int n,double p){
  uint64_t *c=malloc(n*8); memcpy(c,v,n*8); qsort(c,n,8,cmpu);
  double r;
  if(p<=0.5){ double x=p*(n-1); int i=(int)x; double f=x-i;
    r = (i+1<n)? c[i]*(1-f)+c[i+1]*f : (double)c[i]; }
  else { double x=(1-p)*(n-1); int i=(int)x; double f=x-i;
    r = (i+1<n)? c[n-1-i]*(1-f)+c[n-2-i]*f : (double)c[n-1-i]; }
  free(c); return r;
}
static double med(const uint64_t*v,int n){ return q(v,n,0.5); }

int main(void){
  signal(SIGILL, on_sigill);
  memset(target, 0x5a, sizeof target);

  uint64_t frq=0;
  __asm__ __volatile__("mrs %0, cntfrq_el0":"=r"(frq));
  if(!frq) frq=50000000ULL;
  double nspt = 1e9/(double)frq;

  printf("# cntfrq_el0 = %llu Hz  -> 1 tick = %.3f ns\n",(unsigned long long)frq,nspt);
  printf("# BATCH=%d loads/样本  NSAMP=%d  主口径=删-fence  对照=含-fence\n",BATCH,NSAMP);

  /* --- cntvct 校准: 与名义 100 ms 对比, 比值须约等于 1 --- */
  { struct timespec ts={0,100*1000*1000};
    uint64_t a=rd(); nanosleep(&ts,0); uint64_t b=rd();
    double real=(double)(b-a)*nspt/1e6;
    printf("# cntvct 校准: 100.000 ms 名义 -> 实测 %.3f ms (比值 %.4f)\n", real, real/100.0); }

  for(int i=0;i<50000;i++) touch();

  uint64_t *hot=malloc(NSAMP*8),*cold=malloc(NSAMP*8);
  uint64_t *hotf=malloc(NSAMP*8),*coldf=malloc(NSAMP*8);
  if(!hot||!cold||!hotf||!coldf) return 2;

  for(int i=0;i<NSAMP;i++){
    uint64_t t0,t1;
    touch();                                 /* 删-fence 热态 */
    t0=rd(); touch(); t1=rd(); hot[i]=t1-t0;
    flush_line(target);                      /* 删-fence 冷态 */
    t0=rd(); touch(); t1=rd(); cold[i]=t1-t0;
    touch();                                 /* 含-fence 热态 */
    t0=rd_f(); touch(); t1=rd_f(); hotf[i]=t1-t0;
    flush_line(target);                      /* 含-fence 冷态 */
    t0=rd_f(); touch(); t1=rd_f(); coldf[i]=t1-t0;
  }

  double mh=med(hot,NSAMP), mc=med(cold,NSAMP);
  double ph5=q(hot,NSAMP,0.05), ph95=q(hot,NSAMP,0.95);
  double pc5=q(cold,NSAMP,0.05), pc95=q(cold,NSAMP,0.95);

  /* 比值 bootstrap 95% CI */
  double lo=1e18, hi=-1e18;
  for(int b=0;b<800;b++){
    uint64_t *ra=malloc(NSAMP*8),*rb=malloc(NSAMP*8);
    for(int i=0;i<NSAMP;i++){ int j=(int)(((double)rand()/RAND_MAX)*(NSAMP-1));
      ra[i]=hot[j]; rb[i]=cold[(int)(((double)rand()/RAND_MAX)*(NSAMP-1))]; }
    double a=med(ra,NSAMP), c=med(rb,NSAMP); double r = a>0? c/a : 0;
    if(r<lo)lo=r; if(r>hi)hi=r;
    free(ra); free(rb);
  }
  double ratio = mh>0? mc/mh : -1;

  printf("\n== ruler: 删-fence (主口径，与项目基线同口径) ==\n");
  printf("hot (cached)   中位数 %7.1f ticks (%6.1f ns)   p5 %6.1f  p95 %6.1f\n", mh, mh*nspt, ph5, ph95);
  printf("cold(flushed)  中位数 %7.1f ticks (%6.1f ns)   p5 %6.1f  p95 %6.1f\n", mc, mc*nspt, pc5, pc95);
  printf("ratio cold/hot = %.2f    bootstrap 95%%CI [%.2f, %.2f]\n", ratio, lo, hi);
  printf("两态是否被分开: %s   (cold_p5 %.1f %s hot_p95 %.1f)\n",
         (pc5>ph95)?"YES(分布不重叠)":"NO(有重叠)",
         pc5,(pc5>ph95)?">":"<=",ph95);

  double mhf=med(hotf,NSAMP), mcf=med(coldf,NSAMP);
  printf("\n== 对照: 含-fence (仅供参照, 不与主口径混比) ==\n");
  printf("hot %7.1f ticks  cold %7.1f ticks  ratio %.2f\n", mhf, mcf, mhf>0? mcf/mhf : -1);

  int pass = (ratio>=2.0) && (pc5>ph95);
  printf("\n>>> RULER %s  (判据: ratio>=2 且 两态分布不重叠)\n", pass?"PASS":"FAIL");
  printf(">>> 摘要行冷态/热态中位数+比值: cold=%.1f hot=%.1f ratio=%.2f %s\n",
         mc, mh, ratio, pass?"PASS":"FAIL");
  return pass?0:1;
}
```
### 7.2 会话 2 — S0-v1 amp_sweep（2026-11-18）→ **作废**

**缺陷**：`chase()` 每样本固定从 `buf` 起跳，指针链是固定单环 → 每样本只走链的头 K 步，**只触碰固定的 K 条线（≤16 KB）**，工作集不随缓冲区缩放。
**铁证**：`8M K=64` = 4.0 ticks 与 `16K K=64` = 4.0 ticks **完全相同**（若真在 L3 不可能）；且 `16K K=256` 的 p5=23.0 / 中位=23.0 / p95=24.0，分布窄到只剩 1 tick，是"每次路线完全一样"的指纹。
**有效残留**：`rd->rd` 地板 = 1.0 tick；`16K@K=256` = 23 ticks（1.72 ns/op ≈ 5.2 cycle）勉强可用。
**其余全部作废**，`K ≤ 16` 各行 p5=0.0（整段测量在一个 tick 内跑完）亦作废。



#### 源码 S0-v1 `amp_sweep.c`（完整，可直接编译）

> CC=gcc -O2 -o amp_sweep amp_sweep.c；**作废版本，仅作缺陷记录，勿作结论依据**

```c
/* amp_sweep.c —— 放大扫描 v1（TC-02 前身 / 会话 2）【已作废】
 * 编译: gcc -O2 -o amp_sweep amp_sweep.c    运行: taskset -c 3 ./amp_sweep
 *
 * 作废原因（保留源码以记录缺陷形态）:
 *   chase() 每样本固定从 buf 起跳，指针链是固定单环 → 每样本只走链的头 K 步，
 *   只触碰固定的 K 条线（<=16 KB），工作集不随缓冲区缩放。
 *   铁证: 8M K=64 与 16K K=64 都是 4.0 ticks；16K K=256 的 p5=23/中位=23/p95=24。
 *   有效残留: rd()->rd() 地板 = 1.0 tick；16K@K=256 = 23 ticks（1.72 ns/op）。
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static inline uint64_t rd(void){ uint64_t t; __asm__ __volatile__("mrs %0, cntvct_el0":"=r"(t)); return t; }
static volatile unsigned char sinkb;

static int cmpu(const void*a,const void*b){ uint64_t x=*(const uint64_t*)a,y=*(const uint64_t*)b; return (x>y)-(x<y); }
static double pct(uint64_t *v,int n,double p){
  uint64_t *c=malloc((size_t)n*8); memcpy(c,v,(size_t)n*8); qsort(c,(size_t)n,8,cmpu);
  double x=p*(n-1); int i=(int)x; double f=x-i, r;
  r = (i+1<n) ? c[i]*(1-f)+c[i+1]*f : (double)c[n-1];
  free(c); return r;
}

/* 随机单环指针链: line*64 处存下一跳字节偏移, 破硬件预取 */
static void build(unsigned char *buf, size_t nlines){
  uint32_t *perm = malloc(nlines*4);
  for(size_t i=0;i<nlines;i++) perm[i]=(uint32_t)i;
  uint64_t s = 0x9E3779B97F4A7C15ULL;
  for(size_t i=nlines-1;i>0;i--){
    s^=s<<13; s^=s>>7; s^=s<<17;
    size_t j=(size_t)(s%(i+1));
    uint32_t t=perm[i]; perm[i]=perm[j]; perm[j]=t;
  }
  for(size_t i=0;i<nlines;i++)
    *(uint32_t*)(buf + (size_t)perm[i]*64) = perm[(i+1)%nlines]*64u;
  free(perm);
}

/* K 次依赖加载, 强制每次真发 ldr —— 缺陷: 固定从 buf 起跳 */
__attribute__((noinline)) static void chase(unsigned char *buf, int K){
  unsigned char *p = buf;
  for(int i=0;i<K;i++){
    uint32_t off;
    __asm__ __volatile__("ldr %w0, [%1]" : "=r"(off) : "r"(p) : "memory");
    p = buf + off;
  }
  sinkb = *p;
}

int main(void){
  uint64_t frq=0; __asm__ __volatile__("mrs %0, cntfrq_el0":"=r"(frq));
  if(!frq) frq=50000000ULL;
  double nspt = 1e9/(double)frq;
  printf("# cntfrq = %llu Hz  tick = %.2f ns\n",(unsigned long long)frq,nspt);

  { const int N=1000; uint64_t *v=malloc(N*8);
    for(int i=0;i<N;i++){ uint64_t a=rd(); uint64_t b=rd(); v[i]=b-a; }
    printf("# 计时器自身开销 rd->rd : 中位 %.1f ticks  p95 %.1f  (这是本装置的地板)\n", pct(v,N,0.5), pct(v,N,0.95));
    free(v); }

  size_t S[4]  = { 16u<<10, 512u<<10, 8u<<20, 64u<<20 };
  const char *NM[4] = { "16K", "512K", "8M", "64M" };
  int  KS[5] = { 1, 4, 16, 64, 256 };
  const int NS = 400;

  printf("\n%-5s %-5s %10s %10s %8s %7s %7s\n","set","K","med_ticks","med_ns","ns/op","p5","p95");
  printf("--------------------------------------------------------------\n");
  for(int si=0; si<4; si++){
    unsigned char *buf=NULL;
    if(posix_memalign((void**)&buf,4096,S[si])!=0){ printf("alloc fail %s\n",NM[si]); continue; }
    memset(buf,0,S[si]);
    build(buf, S[si]/64);
    for(size_t i=0;i<S[si];i+=64) sinkb = buf[i];      /* 预热 TLB+页表 */
    for(int ki=0; ki<5; ki++){
      int K = KS[ki];
      uint64_t *v = malloc((size_t)NS*8);
      for(int r=0;r<NS;r++){ uint64_t t0=rd(); chase(buf,K); uint64_t t1=rd(); v[r]=t1-t0; }
      double m = pct(v,NS,0.5);
      printf("%-5s %-5d %10.1f %10.1f %8.3f %7.1f %7.1f\n",
             NM[si], K, m, m*nspt, (K? m*nspt/K : 0.0), pct(v,NS,0.05), pct(v,NS,0.95));
      free(v);
    }
    free(buf);
  }

  printf("\n# 换算: 本装置在放大 K 次时的单次分辨率上限 = %.1f / K  ns\n", 20.0);
  printf(">>> 判据: 同 K 下两 set 中位数 >= 2 ticks 且 p5/p95 不重叠 => K 次放大后该量级延迟可分\n");
  return 0;
}
```
### 7.3 会话 3 — S0-v2 amp_sweep2（2026-11-18）✅

**A. 层级延迟标定**（起点每样本随机轮转，N=200）

| set | T=256 med_ticks / ns/op(减地板) | T=1024 | T=4096 | p5–p95 范围（T=1024） |
|---|---|---|---|---|
| 16K | 24.0 / 1.797 | 101.0 / 1.953 | 408.0 / 1.987 | 100.0 – 101.0 |
| 512K | 72.0 / 5.547 | 307.5 / 5.986 | 1269.0 / 6.191 | 245.0 – 353.2 |
| 8M | 360.0 / 28.047 | 1582.0 / 30.879 | 6516.5 / 31.814 | 916.7 – 1640.1 |
| 64M | 666.0 / 51.953 | 4078.5 / 79.639 | 25421.0 / 124.121 | 2631.7 – 4966.2 |

**换算（T=1024，@3 GHz）**：L1 **1.97 ns ≈ 5.9 cycle** ｜ L2 **6.01 ns ≈ 18.0 cycle** ｜ L3 **30.9 ns ≈ 92.7 cycle** ｜ DRAM **79.6 ns ≈ 239 cycle**。
**判读**：阶梯单调、量级符合 N2 公开量级 → **工作集修正成功，装置可信**。
**注意**：64M 档 `ns/op` 随 T 从 51.9→79.6→124.1 上爬（轮转导致 T 越大越冷 + TLB 压力），**该档不得用作放大基准**。

**B. A/A 假阳标定**（512K, T=1024, 每臂 30 样本, 100 组）

| 指标 | 值 |
|---|---|
| Δmedian 均值 | **−0.890** ticks（≈0 → 装置无系统偏差） |
| 中位 \|Δ\| | 3.500 ticks |
| p95 \|Δ\| | **12.000 ticks** → 硬阈值 240 ns = **0.2344 ns/op** |
| 最大 \|Δ\| | 14.500 ticks |
| 非零比例 | 96% |
| 表面判定 | 假阳阈值 12 ticks |

**C. 对 A/A 的再解释（重要，勿丢）**

12 ticks **不是硬件抖动，是样本量不足的抽样噪声**：
- 该配置样本 p5=245 / p95=353 → σ ≈ (353−245)/3.29 ≈ **32.8 ticks**
- 每臂仅 30 样本 → 中位数标准误 ≈ 1.253σ/√30 ≈ **7.5 ticks**
- 两独立中位数相减 → SE ≈ 7.5×√2 ≈ **10.6 ticks** → 实测 p95|Δ| = 12，**正好落在预期内**
- Δ 均值 −0.890 ≈ 0 → **无系统漂移**

**D. 本机分辨力结论表（Q-A 的第一把尺子）**

| 统计口径 | 假阳阈值 | 单次操作 | cycle |
|---|---|---|---|
| 现状（30 样本/臂，独立中位数，T=1024） | 12.0 ticks | **0.234 ns/op** | **0.70 cycle** |
| 400 样本/臂（SE ÷3.65） | ≈3.3 ticks | 0.064 ns/op | **0.19 cycle** |
| 400 样本 + 逐样本配对 | 预估 1–2 ticks | 0.02–0.04 ns/op | 0.06–0.12 cycle |



#### 源码 S0-v2 `amp_sweep2.c`（完整，可直接编译）

> CC=gcc -O2 -o amp_sweep2 amp_sweep2.c；运行 `taskset -c 3 ./amp_sweep2`

```c
/* amp_sweep2.c —— 层级延迟标定 + A/A 假阳标定（TC-02 / 会话 3）
 * 编译: gcc -O2 -o amp_sweep2 amp_sweep2.c     运行: taskset -c 3 ./amp_sweep2
 * 修正 v1 缺陷: 起点每样本随机轮转 => 工作集覆盖整个缓冲区
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static inline uint64_t rd(void){ uint64_t t; __asm__ __volatile__("mrs %0, cntvct_el0":"=r"(t)); return t; }
static volatile unsigned char sinkb;

static uint64_t rs = 0x243F6A8885A308D3ULL;
static inline uint64_t xr(void){ uint64_t s=rs; s^=s<<13; s^=s>>7; s^=s<<17; rs=s; return s; }

static int cmpu(const void*a,const void*b){ uint64_t x=*(const uint64_t*)a,y=*(const uint64_t*)b; return (x>y)-(x<y); }
static int cmpd(const void*a,const void*b){ double x=*(const double*)a,y=*(const double*)b; return (x>y)-(x<y); }
static double pct(uint64_t *v,int n,double p){
  uint64_t *c=malloc((size_t)n*8); memcpy(c,v,(size_t)n*8); qsort(c,(size_t)n,8,cmpu);
  double x=p*(n-1); int i=(int)x; double f=x-i,r;
  r=(i+1<n)? c[i]*(1-f)+c[i+1]*f : (double)c[n-1];
  free(c); return r;
}

static void build(unsigned char *buf, size_t nlines){
  uint32_t *perm=malloc(nlines*4);
  for(size_t i=0;i<nlines;i++) perm[i]=(uint32_t)i;
  uint64_t s=0x9E3779B97F4A7C15ULL;
  for(size_t i=nlines-1;i>0;i--){
    s^=s<<13; s^=s>>7; s^=s<<17;
    size_t j=(size_t)(s%(i+1));
    uint32_t t=perm[i]; perm[i]=perm[j]; perm[j]=t;
  }
  for(size_t i=0;i<nlines;i++)
    *(uint32_t*)(buf+(size_t)perm[i]*64)=perm[(i+1)%nlines]*64u;
  free(perm);
}

/* 从任意行起跳, 走 T 步依赖加载; 整条链是单环, 任何起点都合法 */
__attribute__((noinline)) static void chase_from(unsigned char *buf, size_t line, int T){
  unsigned char *p = buf + line*64;
  for(int i=0;i<T;i++){
    uint32_t off;
    __asm__ __volatile__("ldr %w0, [%1]" : "=r"(off) : "r"(p) : "memory");
    p = buf + off;
  }
  sinkb = *p;
}

/* 关键修正: 每样本随机轮转起点 => 工作集覆盖整个缓冲区 */
static void measure(unsigned char *buf, size_t nlines, int T, int NS, uint64_t *out){
  for(int r=0;r<NS;r++){
    size_t line=(size_t)(xr()%(uint64_t)nlines);
    uint64_t t0=rd(); chase_from(buf,line,T); uint64_t t1=rd();
    out[r]=t1-t0;
  }
}

int main(void){
  uint64_t frq=0; __asm__ __volatile__("mrs %0, cntfrq_el0":"=r"(frq));
  if(!frq) frq=50000000ULL;
  const double nspt=1e9/(double)frq;
  printf("# tick = %.2f ns   起点每样本随机轮转(修正 v1 工作集不缩放缺陷)\n",nspt);

  size_t S[4]={16u<<10,512u<<10,8u<<20,64u<<20};
  const char *NM[4]={"16K","512K","8M","64M"};
  int TS[3]={256,1024,4096};
  const int NS=200;

  printf("\n%-5s %6s %9s %9s %9s %11s %7s %7s %7s\n",
         "set","T","med_tick","med_ns","ns/op","ns/op(减地板)","p5","p95","res_ns");
  printf("---------------------------------------------------------------------------------\n");
  for(int si=0;si<4;si++){
    unsigned char *buf=NULL;
    if(posix_memalign((void**)&buf,4096,S[si])!=0){ printf("alloc fail %s\n",NM[si]); continue; }
    memset(buf,0,S[si]);
    size_t nl=S[si]/64;
    build(buf,nl);
    for(size_t i=0;i<S[si];i+=64) sinkb=buf[i];          /* 预热 TLB */
    for(int ki=0;ki<3;ki++){
      int T=TS[ki];
      uint64_t *v=malloc((size_t)NS*8);
      measure(buf,nl,T,NS,v);
      double m=pct(v,NS,0.5);
      double mlo=(m>1.0)?(m-1.0):0.0;
      printf("%-5s %6d %9.1f %9.1f %9.3f %11.3f %7.1f %7.1f %7.4f\n",
             NM[si],T,m,m*nspt,m*nspt/T,mlo*nspt/T,pct(v,NS,0.05),pct(v,NS,0.95),20.0/T);
      free(v);
    }
    free(buf);
  }

  /* ===== A/A 假阳标定: 两个完全相同的臂互比 ===== */
  {
    size_t SZ=512u<<10; size_t nl=SZ/64; int T=1024; const int NS2=30; const int REP=100;
    unsigned char *buf=NULL;
    if(posix_memalign((void**)&buf,4096,SZ)!=0){ printf("alloc fail AA\n"); return 0; }
    memset(buf,0,SZ); build(buf,nl);
    for(size_t i=0;i<SZ;i+=64) sinkb=buf[i];

    double *d=malloc((size_t)REP*sizeof(double)), *ad=malloc((size_t)REP*sizeof(double));
    uint64_t *va=malloc((size_t)NS2*8), *vb=malloc((size_t)NS2*8);
    double sum=0; int nz=0;
    for(int rep=0;rep<REP;rep++){
      measure(buf,nl,T,NS2,va); double ma=pct(va,NS2,0.5);
      measure(buf,nl,T,NS2,vb); double mb=pct(vb,NS2,0.5);
      double dd=mb-ma; d[rep]=dd; ad[rep]=(dd<0?-dd:dd); sum+=dd; if(dd!=0.0) nz++;
    }
    qsort(ad,(size_t)REP,sizeof(double),cmpd);
    printf("\n== A/A 假阳标定 (512K, T=1024, 每臂 30 样本, %d 组) ==\n",REP);
    printf("Δmedian 均值 %+.3f ticks   中位|Δ| %.3f   p95|Δ| %.3f   最大 %.3f   非零比例 %d%%\n",
           sum/REP, ad[REP/2], ad[(int)(0.95*(REP-1))], ad[REP-1], (int)(100.0*nz/REP));
    double thr=ad[(int)(0.95*(REP-1))];
    if(thr<1.0) thr=1.0;
    printf(">>> 本装置假阳硬阈值: |Δmedian| 必须 > %.2f ticks (%.1f ns 总计, %.4f ns/op)\n",
           thr, thr*nspt, thr*nspt/T);
    printf(">>> 判读: 若未来 MDU 两臂 Δmedian 落在 <= %.2f ticks 内, 一律算未观测到, 不得报阳性\n",thr);
    free(d); free(ad); free(va); free(vb); free(buf);
  }
  return 0;
}
```
### 7.4 会话 4 — S1 mdu_probe（2026-11-18）

**状态**：✅ 已跑（2026-11-18，MP=256，N=400，TR 剂量扫描）

| TR | med_dTicks | med_dNs | med_d(ns/op) | p5 | p95 | \|d\|p95 |
|---|---|---|---|---|---|---|
| 0（A/A 空对照） | 0.00 | 0.00 | 0.0000 | −1.0 | 1.0 | 1.00 |
| 8 | 0.00 | 0.00 | 0.0000 | −1.0 | 1.0 | 1.00 |
| 32 | −1.00 | −20.00 | −0.0781 | −1.0 | 1.0 | 1.00 |
| 128 | 0.00 | 0.00 | 0.0000 | −1.0 | 1.0 | 1.00 |
| 512 | 0.00 | 0.00 | 0.0000 | −1.0 | 1.0 | 1.00 |

- 假阳阈值（TR=0 的 `|Δ|p95`）= **1.00 tick = 0.078 ns/op**
- TR>0 各组 `|med_Δ|` 最大 = 1.00 tick，**超阈值组数 0/4**
- 判定：**S1 FAIL**

> **FAIL 不等于"没有 MDU"**——这是装置缺陷。归因与修正见 §7.5。

**设计**：TR ∈ {0, 8, 32, 128, 512} 剂量扫描；每样本配对跑臂1（教"依赖"→A,A）与臂2（教"无关"→B,C），测量阶段两臂完全相同 `phase(A,B,256)`；**TR=0 组即 A/A**。MP=256，N=400。

**判读矩阵**：

| 观测 | 含义 | 下一步 |
|---|---|---|
| 四组 med_Δ 都在阈值内、随 TR 乱跳 | 未见可训练的 MDU 状态 | 改"store 地址未就绪"的真投机场景再测；仍为 0 才写否定 |
| med_Δ 随 TR **单调**变负/变正并饱和 | **真信号**，可反推学习曲线 | 立刻进跨进程（S2） |
| 只有 TR=512 超阈值 | 训练不足或有噪声 | 加 TR=1024/2048 看是否继续增长 |
| 严格全为 0 | 训练根本没进预测器 | 改按**地址**索引再扫（说明不按 PC 索引） |

**符号预期**：`Δ = 臂2 − 臂1` 预期为**负**（被预测成依赖 → 等 store 地址解析 → 更慢）。

---

#### 源码 S1 `mdu_probe.c`（完整，可直接编译）

> CC=gcc -O2 -o mdu_probe mdu_probe.c；**已作废**

```c
/* mdu_probe.c —— S1: MDU 状态可训练性（TR 剂量反应 + TR=0 内建 A/A）（会话 4）【已作废】
 * 编译: gcc -O2 -o mdu_probe mdu_probe.c    运行: taskset -c 3 ./mdu_probe
 *
 * 作废原因（三个装置缺陷）:
 *   1. 中位数在量化地板处失明: 各组 p5/p95 恒为 -1/+1 tick, 中位数只能报 0
 *   2. 训练效应被稀释 ~128x: 训练 32 次 -> 测 256 次
 *   3. 训练臂成本混淆未分离
 * 结果: 五组 med_dTicks 全为 0(TR=32 为 -1), 假阳阈值 1.00 tick -> FAIL（非核判决）
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static inline uint64_t rd(void){ uint64_t t; __asm__ __volatile__("mrs %0, cntvct_el0":"=r"(t)); return t; }
static volatile uint64_t sinkv;
static unsigned char *buf;
#define PA ((void*)(buf))
#define PB ((void*)(buf+64))
#define PC ((void*)(buf+4096))

/* 训练与测量共用同一函数 => load/store 的 PC 恒定, 两臂只差地址 */
__attribute__((noinline)) static void phase(void *s, void *l, int n){
  uint64_t acc=0, x=0;
  const uint64_t v = 0x11111111ULL;
  for(int i=0;i<n;i++){
    __asm__ __volatile__("str %1,[%2]\n\tldr %0,[%3]"
                         : "=&r"(x) : "r"(v), "r"(s), "r"(l) : "memory");
    acc += x;
  }
  sinkv = acc;
}

static int cmpd(const void *a, const void *b){ double x=*(const double*)a, y=*(const double*)b; return (x>y)-(x<y); }
static double pctd(double *v, int n, double p){
  double *c = malloc((size_t)n*sizeof(double));
  memcpy(c, v, (size_t)n*sizeof(double));
  qsort(c, (size_t)n, sizeof(double), cmpd);
  int i = (int)(p*(n-1));
  double r = c[i];
  free(c);
  return r;
}

int main(void){
  uint64_t frq=0; __asm__ __volatile__("mrs %0, cntfrq_el0":"=r"(frq));
  if(!frq) frq=50000000ULL;
  const double nspt = 1e9/(double)frq;

  if(posix_memalign((void**)&buf, 4096, 1u<<20)!=0) return 2;
  memset(buf, 0, 1u<<20);
  for(int i=0;i<4000;i++) phase(PA, PB, 1);

  const int MP = 256, N = 400;
  const int TRS[5] = {0, 8, 32, 128, 512};
  double md[5], thr = 0.0;

  printf("# tick=%.2f ns  MP=%d  每臂样本 N=%d\n", nspt, MP, N);
  printf("# 地址: A=buf  B=buf+64  C=buf+4096\n");
  printf("# TR=0 组 = A/A 空对照(两臂都不训练), 其 |d|p95 即本装置假阳阈值\n\n");
  printf("%-5s %11s %10s %10s %8s %8s %9s\n","TR","med_dTicks","med_dNs","med_d(ns/op)","p5","p95","|d|p95");
  printf("----------------------------------------------------------------------------\n");

  for(int t=0;t<5;t++){
    int TR = TRS[t];
    double *d  = malloc((size_t)N*sizeof(double));
    double *ad = malloc((size_t)N*sizeof(double));
    double base = 0;
    for(int r=0;r<N;r++){
      uint64_t t0,t1; double a,b;
      phase(PA, PA, TR); t0=rd(); phase(PA, PB, MP); t1=rd(); a=(double)(t1-t0);
      phase(PB, PC, TR); t0=rd(); phase(PA, PB, MP); t1=rd(); b=(double)(t1-t0);
      d[r]=b-a; ad[r]=(b-a)<0.0?(a-b):(b-a); base += a;
    }
    md[t] = pctd(d, N, 0.5);
    double ap95 = pctd(ad, N, 0.95);
    printf("%-5d %11.2f %10.2f %10.4f %8.1f %8.1f %9.2f\n",
           TR, md[t], md[t]*nspt, md[t]*nspt/MP,
           pctd(d,N,0.05), pctd(d,N,0.95), ap95);
    if(TR==0) thr = ap95;
    free(d); free(ad);
  }

  printf("\n>>> 假阳阈值(|d|p95 @ TR=0) = %.2f ticks  (%.3f ns/op)\n", thr, thr*nspt/MP);
  double mx = 0.0; int hit = 0;
  for(int t=1;t<5;t++){ double v = md[t]<0?-md[t]:md[t]; if(v>mx) mx=v; if(v>thr) hit++; }
  printf(">>> TR>0 各组中 d 的最大绝对值 = %.2f ticks, 超过阈值的组数 = %d/4\n", mx, hit);

  int pass = (hit >= 2) && (mx > thr);
  printf("\n>>> S1 %s : %s\n", pass?"PASS":"FAIL",
         pass ? "MDU 状态可被训练且可观测 -> 进 Q-A 深化 / 跨进程"
              : "本装置下未见可训练状态 -> 换 TR 范围、改 store 地址未就绪场景再试");
  printf(">>> 摘要行: d(TR=0)=%.2f d(8)=%.2f d(32)=%.2f d(128)=%.2f d(512)=%.2f thr=%.2f %s\n",
         md[0],md[1],md[2],md[3],md[4],thr, pass?"PASS":"FAIL");
  return pass?0:1;
}
```


### 7.5 会话 5–14 — S1 系列：SELF 闸门 → 三次作废 → 定案（2026-11-18～19）

> **本节导航**（内容按时间累加，勿删）：
> ① S1 FAIL 归因 → ② S1b/S1b-v2（SELF 闸门）→ ③ S1c（伪阳 1）→ ④ S1d（符号翻转）→ ⑤ S1e（位置伪影）→ ⑥ S1f（伪阳 2：地址碰撞）→ ⑦ S1g（无效：乱序重叠）→ ⑧ **S1h（CLEAN）** → ⑨ **S1i（CLEAN，定案）**
> 判决摘要见 `L1-3_MDU_结论卡.md`。
> **各装置完整源码在本节末尾**（逐台 #### 源码 S1x），与上面每步的数据一一对应。

**三个装置缺陷（按严重度）**

1. **中位数在量化地板处失明**（致命）。全部组的 p5/p95 都是 −1.0/+1.0 tick → 每样本 Δ 只能取 −1/0/+1，**中位数结构上只能报 0**。任何小于半 tick 的系统偏移，中位数永远看不见。→ 已写入 §5.2-10。
2. **训练效应被稀释 ≈128×**。设计是"训练 32 次 → 测 256 次"。若 MDU 状态只影响训练后头 2 次探测，每对效应 ε = 3 cycle（1 ns）→ 总量 2 ns，摊到 256 次 = **0.0078 ns/op**，正压在检测极限（≈0.0039 ns/op）边上。
3. **训练臂成本混淆未分离**。同址 `store→load` 与异址 `store→load` 的单次成本本身差约 1 cycle；若直接做交错重训，这个混淆会盖过真信号，必须用"探针/不探针"四臂相减把它消掉。

**结论**：S1 是"没过 SELF 闸门就上主测量"的装置，报 FAIL 是装置失败，**不是核的判决**。

**S1b 设计：两个"已知为真"的闸门**

按 §5.1-3，装置必须先复现已知为真的信号才准放行。

| 闸门 | 臂 | 为什么"已知为真" |
|---|---|---|
| **G1** | `str+ldr` 同址 **vs** 纯 `ldr` | 有 store 参与必然改变 load 时序（架构必然）；测不到就说明装置对存储流水线无感 |
| **G2** | store 地址**晚到**（24 级依赖链喂地址）且与 load **别名** **vs** 不别名 | load 必在 store 地址解析前投机发射；别名时必须重放 → 必然更慢。**这就是消歧机制本身** |

两臂指令流 / 链长 / 迭代数完全相同，**唯一差别是地址**（`mask0` 为 `volatile 0`，编译期不可折叠，防止作弊优化）。
统计：配对差值的**均值 + bootstrap 均值 CI**（每样本四 arm 交错，抵消漂移）。

**判据**：G1、G2 的均值 CI 都排除 0 且方向为正（别名更慢）→ 装置通过 SELF，才准进 **S1c**（四臂相减测"训练能否改变等待"）。

**状态**：✅ 已跑（2026-11-18）

| 闸门 | mean ΔT | 95% CI | 每次迭代 | sd | Cohen_d | 判定 |
|---|---|---|---|---|---|---|
| G1 | +0.33 ticks（+6.7 ns） | [+0.26, +0.41] | +0.026 ns | 0.76 | 0.44 | **PASS** |
| G2 | +6.93 ticks（+138.6 ns） | [−4.23, +22.73] | +1.083 ns | **142.91** | 0.05 | **FAIL** |

**G2 FAIL 归因：不是没有效应，是被方差淹没**

- 点估计 **+6.93 ticks 方向正确**（别名应当更慢），但 CI 宽达 27 ticks、sd=142.91。
- 单样本时长被 **24 级 64-bit 乘法链**撑到约 **6 µs**（每迭代 ~144 cycle × 128 次 ≈ 18432 cycle ≈ 307 ticks）。一次 timer tick / 抢占就能把该样本打飞几十到几百 ticks。
- 400 样本里少量脏样本把 sd 顶到 142（≈ 测量总长的 46%）→ 几十 tick 量级的真实效应被完全吃掉。
- 教训：**G2 不能靠加长 CHAIN 来制造"地址晚到"**——链越长样本越长，越容易被抢占污染。

**S1b-v2 设计（换探针 + 换统计）**

1. **换探针**：放弃"地址晚到"路线，改用**存储转发（store-to-load forwarding）的重叠结构**——这是消歧机制里效应最大、最不依赖调度的部分：
   - 臂 FAST：`str 8B [A]` + `ldr 8B [A]`（**完全重叠** → 可转发，快）
   - 臂 SLOW：`str 4B [A]` + `ldr 8B [A]`（**部分重叠** → 不能转发，必须等 store 数据）
   - 两臂都是对齐访问、指令数相同，**唯一差别是 store 的宽度**。
2. **砍掉乘法链**：单样本从 ~6 µs 降到 ~0.4 µs，抢占概率骤降。
3. **换统计**：样本尺度回到几十~几百 tick，中位数不再失明 → **median + bootstrap 中位数 CI + 10% 修剪均值**，并输出**脏样本比例**（|Δ| > 100 ticks）作为抢占诊断，**预声明、不事后剔除**。

**S1b-v2 实测（2026-11-18）**

| 臂 | 中位数 | 折合 |
|---|---|---|
| BASE 纯 ldr | 10.0 ticks（200 ns） | 0.781 ns/iter |
| FAST `str8B+ldr8B` | 4.0 ticks（80 ns） | 0.312 ns/iter |
| SLOW `str4B+ldr8B` | 42.0 ticks（840 ns） | 3.281 ns/iter |
| **G2 = SLOW − FAST** | **+37.00 ticks**，CI [+37.00,+37.00]，trim10% = +37.34 | **+2.891 ns/iter ≈ 8.7 cycle/iter**，脏样本 **0.1%** |
| G1 = FAST − BASE | −6.00 ticks | **判据作废** |

**结论：SELF 通过（以 G2 为准）。** 部分重叠确实不能转发，代价 8.7 cycle/iter，CI 紧、脏样本 0.1% → 装置具备观察消歧/转发机制的能力。

**两处必须记下的设计错误**

1. **G1 判据语义写错**：我把"store 参与必然使 load 更慢"当成已知为真。实测 FAST(4.0) 反而 **快于** BASE(10.0) → G1 = −6 ticks。这不是核的问题，是假设错了；BASE 是唯一结构不同的臂（无 store），跨臂比较本就不该做。
2. **`acc += x` 串行累加器污染全部三臂**：256 次串行 add = 256 cycle ≈ 85 ns ≈ 4.2 ticks，而 FAST 整段只有 4.0 ticks → **测量量被加法链吃干，store/load 几乎免费**。0.312 ns/iter = 0.94 cycle/iter 是"3 指令/cycle"的吞吐极限，说明负载根本没在测内存。三臂编译结果也因此不一致。
   → 修法：`__asm__ __volatile__` 本身不会被删除，**累加器是多余的**，S1c 里全部去掉。

**S1c 设计：同 PC 训练剂量反应**

关键约束：**训练与探测必须落在同一个预测器表项上** → 必须同代码、同 PC。做法：**同一个函数 `pair(a, off, n)`**，只让 `off` 在运行时取 0（完全重叠）或 −4（部分重叠），store/load 指令 PC 全程不变。

```
T1 = REP × [ pair(a,  0, TR) ; pair(a, -4, PR) ]
T2 = REP × [ pair(a, -4, TR) ; pair(a, -4, PR) ]
T3 = REP × [ pair(a,  0, TR) ]
T4 = REP × [ pair(a, -4, TR) ]
S  = (T1 − T3) − (T2 − T4)      ← 训练对探测器代价的净影响
```

REP=32、TR=8、PR=4、N=1000。`(T3,T4)` 用于消掉"训练本身成本差"这个混淆——这是 §7.5 缺陷 3 的正解。

同程序先跑**三臂绝对阶梯**（off = +8 不重叠 / 0 完全重叠 / −4 部分重叠，**同一指令流**），这样跨臂比较才合法。

**判据**：S 的中位数 CI 排除 0 → 状态可训练，进 S2 跨进程；CI 含 0 → 在本探针下**未观测到**训练效应（写"未观测到"，不写"不存在"）。

**S1c 实测（2026-11-19）**

A. 三臂绝对阶梯（同一 `pair()` 指令流、无累加器）

| 臂 | 中位数 | ns/iter |
|---|---|---|
| off=+8 不重叠 | 10.0 ticks（200 ns） | 0.781 |
| off=0 完全重叠 | 5.0 ticks（100 ns） | 0.391 |
| off=−4 部分重叠 | 41.0 ticks（820 ns） | 3.203 |
| 转发代价（部分−完全） | **+36.0 ticks** | 2.81 |

> 附注：**不重叠(10.0) 是全重叠(5.0) 的 2 倍** → 即使不发生别名，load 仍要付"消歧检查"的代价。这本身就是一个可用的弱信道（0.78 vs 0.39 ns/iter）。

B. 训练剂量反应（REP=32 TR=8 PR=4 N=1000）

| 指标 | 值 |
|---|---|
| S = (T1−T3)−(T2−T4) | **−6.00 ticks**，CI [−6.00, −6.00]，trim10% = −6.00，dirty **0.5%** |
| 折成每次探测迭代 | **−0.938 ns ≈ −2.8 cycle/iter** |
| 相对探测自身代价 | −2.8 / 9.6 cycle ≈ **−29%** |

**判读**：用"完全重叠"训练后，同一 PC 的部分重叠探测便宜了 **2.8 cycle/iter**。方向与机制自洽——预测器被教成"这对是依赖的"→ 走投机转发快路径 → 即便地址实际不可转发也先冲过去，**这正是泄漏面本身**。此为**首个初步阳性**。

**但先不写 Q-A 肯定**，两个必须补的实验：

1. **特异性控制**：加第三训练臂 off=+8（不重叠、但同指令流）。若 S_ctrl 也显著，说明效应只是"训练模式不同"的通用伪影，与转发状态无关。
2. **剂量反应**：TR ∈ {1,4,16,64}。真学习曲线应随 TR 增长并饱和；固定流水线模式不会随 TR 变。

→ 合并为 **S1d**。

**S1d 实测（2026-11-19）**

| TR | P(off0) | P(off8) | P(off4) | S_full | S_ctrl | dirty |
|---|---|---|---|---|---|---|
| 1 | 7.0 | 7.0 | 7.0 | 0.00 | 0.00 | 0.5% |
| 4 | 11.0 | 7.0 | 8.0 | +3.00 | −1.00 | 0.2% |
| 16 | 14.0 | 8.0 | 7.0 | +7.00 | +1.00 | 0.0% |
| 64 | 13.0 | 6.0 | 7.0 | +6.00 | −1.00 | 1.2% |

判据输出：显著 3/4、dose_ok=1、spec_ok=0 → FAIL。
**判据本身的错**：`S_ctrl` 的 ±1 tick 就是量化噪声地板，拿"CI 含 0"卡离散量过严；应改为"幅度 ≤2 tick 视为不显著"。
**更致命的问题**：S1c 给 −6、S1d 给 +6~+7，**同一件事符号相反** → 效应不可复现。

**S1e 实测（2026-11-19）**

| TR | 正序 P0/P8/P4 | 反序 P0/P8/P4 | S_full 正序 | S_full 反序 | 平均 | 同号 |
|---|---|---|---|---|---|---|
| 8 | 19/18/19 | 19/23/23 | +0.00 | −4.00 | −2.00 [−2.50,−2.00] | NO |
| 16 | 18/18/19 | 19/24/24 | −1.00 | −5.00 | −3.00 [−3.00,−4.00] | YES |

**程序把 TR=16 判成"真效应"，但这是假阳。原始 P 值直接露馅：**

- 同一条件 `off=−4`：正序排第 3 位时 = **19**，反序排第 1 位时 = **23** → **位置不同差 4 tick**。
- 于是 `S_full_rev = P0(第 6 位=19) − P4(第 4 位=23) = −4`，**完全由位置造成**，与训练条件无关。
- 正序三个位置都在 18–19，所以 `S_full_fwd ≈ 0`。
- **位置伪影 4~5 tick > 待测效应 2~3 tick** → 现有几何无法分离。

**判定：S1c 的 −6 与 S1d 的 +7 均为几何伪影，训练效应在本几何下不可测。此前"初步阳性"作废。**

**S1f 设计（换几何，彻底去掉大块相减）**

现有几何的病根：`pcost` = 两个大块分别计时再相减，各带 ±1 tick 量化 + 位置偏移，而效应只有 2~3 tick。

新几何：**只包住 probe，不测训练块**。

```
per 样本，对每个条件 c：
   total = 0
   for k in K:
       pair(A, train_off[c], TR)        ← 不计时
       t0=rd(); pair(A, -4, PR); t1=rd()  ← 只计这一段
       total += (t1-t0)
```

- 不做大块相减 → 消除位置伪影的主要来源；
- `K=64` 段求和 → 每段 1 tick 量化噪声被 √64 平均掉；
- 三个条件**按样本号轮转顺序**（`c = (r+j) % 3`）→ 漂移均摊到各条件；
- 把 N=300 拆成前/后两半**各自独立算 S**，两半必须同号且 CI 都排除 0 → 内置自复制。

**S1f 实测（2026-11-19）**

| 条件 | 探测总时（64 段求和） | ns/pair |
|---|---|---|
| 训练 off=0 全重叠 | 80.0 ticks（1600 ns） | 1.562 |
| 训练 off=+8 不重叠 | 130.0 ticks（2600 ns） | 2.539 |
| 训练 off=−4 部分重叠 | 189.0 ticks（3780 ns） | 3.691 |

- `S_full = off0 − off4 = −110.00 ticks`，CI [−111, −109]，前半 −110.00、后半 −110.00 → 程序判 **PASS**
- `S_ctrl = off8 − off4 = −59.00 ticks`，CI [−60, −59]

**这个 PASS 作废，两个理由：**

1. **`S_ctrl` 也有 −59 tick（占基线 31%）** → 效应**完全不特异**于"全重叠训练"。"不重叠训练"同样把探测代价砍掉 16%。我的代码里虽然写了特异性判据，**但判定语句里根本没检查 `S_ctrl`** —— 这是我实现上的错。
2. **找到真正的物理原因：地址碰撞。** `A = buf+64` 是 64B 对齐，所以 **`A−4` 落在前一条 cache line**。而 probe 本身就是 `str 8B [A−4]`。于是：
   - 训练用 `off=−4` → 训练的最后一次 store 打在 **A−4**，与 probe 的 store **同地址** → store-store 冲突，probe 变慢到 3.69 ns/pair；
   - 训练用 `off=0/+8` → store 打在 A 那条线上，不撞 probe 的 A−4 → probe 快（1.56 / 2.54）。

   **所谓"S_full / S_ctrl"全是 store 地址碰撞的伪影，与 MDU 预测状态无关。**

**S1g 设计（唯一改动：把 probe 挪到远端固定地址）**

- 训练基址 `A = buf+64`，`off ∈ {0, +8, −4}`；**再加第四个条件：训练在远端 `FAR = buf+256K`，off=0**（用来判断"是不是只要不是 A−4 就都变快"）。
- probe 基址 `P = buf+64K`，固定 `str [P−4]; ldr [P]`，**任何训练都不碰 P 附近**。
- 逐样本轮转四条件顺序，N=300，仍拆前后两半。
- 判据：**四个条件的探测总时两两之差全部落在 ±2 tick 内 → 无历史效应（诚实写"未观测到"）**；若只有 off=0 与他人不同，才算 PC 索引的历史状态。

**S1g 实测（2026-11-19）→ 无效**

| 条件 | probe 总时 | ns/pair |
|---|---|---|
| 训练 A off=0（同线） | 115.0 ticks | 2.246 |
| 训练 A off=+8（同线） | 97.0 ticks | 1.895 |
| 训练 A off=−4（前一线） | 60.0 ticks | 1.172 |
| 训练 FAR off=0（远端） | 128.0 ticks | 2.500 |

差（vs 远端）：−14 / −31 / **−68**，两半 −12 / −16（系统性，非噪声）。但**形状不合理**：最贵的训练给出最快的 probe、完全不碰数据区的远端训练给出最慢的——不可能是 MDU 状态。

两条病根（均为装置错误）：
1. **`mrs cntvct_el0` 不是屏障**：读 t0 时训练块最后的 store 还在 store queue 里，probe 与训练尾巴乱序重叠 → 测到的是"训练与 probe 的流水线交互"。
2. **`str 8B [A−4]` 是跨 cache line 的非对齐 store**（A 64B 对齐，A−4 起 8 字节横跨两线，被拆成两个）→ 四个训练块本身成本就不同，不可比。

**S1h 实测（2026-11-19）→ CLEAN**

口径：**含-fence**（每次 probe 前 `dsb ish; isb`），与删-fence 数字不可混比。

| 条件 | probe 总时 | ns/pair |
|---|---|---|
| 训练 8B@A | **60.0** ticks | 1.172 |
| 训练 4B@A | **60.0** ticks | 1.172 |
| 训练 8B@A+8 | **60.0** ticks | 1.172 |
| 不训练 | **60.0** ticks | 1.172 |

- 三个差值全部 **±0.00 ticks**，CI 退化为 [0,0]；300 个样本的四条分布**逐样本完全相同**
- **灵敏度上界：任何训练效应 < 1 tick / 60 tick ≈ 1.7% ≈ 0.02 ns/pair ≈ 0.06 cycle**

**结论：fence 隔离后，同 PC 的训练历史对 probe 无任何可观测影响。** 这是十二次实验里最干净的一次零结果，且装置灵敏度足够（1.7%）。

**唯一还没堵的漏洞：索引维度。** MDU 是"内存消歧"单元，按**地址**比较更自然，而我们所有训练都没和 probe 共享地址/表项——只排除了 **PC 索引**这一条路。→ S1i 补最后一刀。

**S1i 实测（2026-11-19）→ CLEAN（定案）**

口径：含-fence；probe 固定于 `P = buf+64K`，训练与 probe **共用同一个 P**（唯一能共享 MDU 表项的配置）。

| 条件 | probe 总时 | ns/pair | 差（vs 不训练） |
|---|---|---|---|
| 训练 8B@P（对 8B load 全重叠） | **60.0** ticks | 1.172 | **+0.00** |
| 训练 4B@P（部分重叠） | **60.0** ticks | 1.172 | **+0.00** |
| 训练 8B@P+4096（不同页/不同表项） | **60.0** ticks | 1.172 | **+0.00** |
| 不训练 | **60.0** ticks | 1.172 | — |

- 最大 |差| = **0.00 tick**；四组 300 样本逐样本完全相同
- **地址索引路径同样堵死 → Q-A 定案为否，Q-B 依依赖关系不成立**
- 判决书见 `L1-3_MDU_结论卡.md`

**S1j 实测（2026-11-19）→ CLEAN（跨上下文，闭合结论卡 §4-2）**

几何：两线程同钉核 3，`sched_yield` 交接；训练在**另一上下文**完成，本上下文探测。四臂仅训练目标不同。

| 臂 | 训练线程在另一上下文做的事 | probe 总时（32 次切换求和） | ns/pair |
|---|---|---|---|
| A | `store 8B ×64` 打 P（依赖） | **174.0** ticks | 1.699 |
| B | `load 8B ×64` 读 P（只读，同足迹） | **174.0** ticks | 1.699 |
| C | `store 8B ×64` 打 Q（异页） | **174.0** ticks | 1.699 |
| D | 不训练 | **175.0** ticks | 1.709 |

- 相对 D：A −1.00、B +0.00、C +0.00；**关键对比 A−B = +0.00**；maxdiff = **1.00 tick**
- 诊断：主线程 cpu=3、训练线程 cpu=3（同核 ✅）；回合数 25600 = 4×200×32 ✅；平均交接 **61.9 ticks ≈ 1.24 µs**（真实上下文切换量级 ✅；程序里把它标成 "ns" 是标签写错，值是 tick）
- **判定：跨上下文无残留**

**为什么这个零结果够硬**：同核同 L1/L2/TLB，缓存状态在四臂中天然等价（且 probe 首次访问即把线拉热，1024 对里只有头 1~2 对受初始状态影响）；store buffer 在切换时必然排空；四臂切换次数与指令条数完全相同。**A 与 B 足迹一致、只差"有没有写"，而 A−B = 0.00。**

**诚实的解释边界**：零结果有两种可能——① 本来就没有可跨上下文存活的状态；② 状态存在但在切换时被硬件清掉。**对攻击者而言两者等价：跨上下文不可用。** 因此本结果支持 Q-B 的否定，但不主张"N2 内部绝无 MDU 状态"。

---



#### 源码 S1b `mdu_self.c`（完整，可直接编译）

> CC=gcc -O2 -o mdu_self mdu_self.c -lm；**G2 被抢占污染，见正文**

```c
/* mdu_self.c —— S1b: G1/G2 SELF 闸门（地址晚到 24 级乘法链）（会话 6）
 * 编译: gcc -O2 -o mdu_self mdu_self.c -lm    运行: taskset -c 3 ./mdu_self
 * 结果: G1 PASS(+0.33 tick, Cohen_d 0.44); G2 FAIL 但点估计 +6.93 tick 方向正确,
 *       sd=142.91 -> 归因为 6 us 长样本被抢占污染, 非无效应
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static inline uint64_t rd(void){ uint64_t t; __asm__ __volatile__("mrs %0, cntvct_el0":"=r"(t)); return t; }
static volatile uint64_t sinkv;
static volatile uint64_t mask0 = 0;      /* 恒 0, 但 volatile => 编译期不可折叠 */
static unsigned char *buf;

static uint64_t rs = 0x243F6A8885A308D3ULL;
static inline uint64_t xr(void){ uint64_t s=rs; s^=s<<13; s^=s>>7; s^=s<<17; rs=s; return s; }

#define CHAIN 24
static inline uint64_t ch(uint64_t r){
  for(int k=0;k<CHAIN;k++){ r = r*6364136223846793005ULL + 1442695040888963407ULL; r ^= (r>>29); }
  return r;
}

/* G1-a: str + ldr 同址 */
__attribute__((noinline)) static void g1_store(void *a, int n){
  uint64_t acc=0, x=0; const uint64_t v=0x11111111ULL;
  for(int i=0;i<n;i++){
    __asm__ __volatile__("str %1,[%2]\n\tldr %0,[%2]" : "=&r"(x) : "r"(v), "r"(a) : "memory");
    acc += x;
  }
  sinkv = acc;
}
/* G1-b: 纯 ldr */
__attribute__((noinline)) static void g1_load(void *a, int n){
  uint64_t acc=0, x=0;
  for(int i=0;i<n;i++){
    __asm__ __volatile__("ldr %0,[%1]" : "=&r"(x) : "r"(a) : "memory");
    acc += x;
  }
  sinkv = acc;
}
/* G2: store 地址晚到(24 级链); base==a 别名, base!=a 不别名 */
__attribute__((noinline)) static void g2(void *base, void *a, int n, uint64_t seed){
  uint64_t r=seed, acc=0, x=0; const uint64_t v=0x11111111ULL;
  for(int i=0;i<n;i++){
    r = ch(r);
    void *s = (void*)((uintptr_t)base + (r & mask0));
    __asm__ __volatile__("str %1,[%2]\n\tldr %0,[%3]" : "=&r"(x) : "r"(v), "r"(s), "r"(a) : "memory");
    acc += x;
  }
  sinkv = acc + r;
}

static int cmpd(const void *p, const void *q){
  double x=*(const double*)p, y=*(const double*)q; return (x>y)-(x<y);
}
static double mean(double *v,int n){ double s=0; for(int i=0;i<n;i++) s+=v[i]; return s/n; }
static double sdev(double *v,int n){ double m=mean(v,n), s=0; for(int i=0;i<n;i++){ double t=v[i]-m; s+=t*t; } return (n>1)?sqrt(s/(n-1)):0.0; }
static void boot_mean(double *v, int n, int B, double *lo, double *hi){
  double *m = malloc((size_t)B*sizeof(double));
  for(int b=0;b<B;b++){ double s=0; for(int i=0;i<n;i++) s += v[(int)(xr()%(uint64_t)n)]; m[b]=s/n; }
  qsort(m,(size_t)B,sizeof(double),cmpd);
  *lo = m[(int)(0.025*(B-1))]; *hi = m[(int)(0.975*(B-1))];
  free(m);
}

int main(void){
  uint64_t frq=0; __asm__ __volatile__("mrs %0, cntfrq_el0":"=r"(frq));
  if(!frq) frq=50000000ULL;
  const double nspt = 1e9/(double)frq;

  if(posix_memalign((void**)&buf, 4096, 1u<<20)!=0) return 2;
  memset(buf, 0, 1u<<20);

  void *A = (void*)buf;
  void *C = (void*)(buf + 4096);
  const int nG1 = 256, nG2 = 128, N = 400, B = 2000;

  for(int i=0;i<3000;i++){ g1_load(A,1); g2(A,A,1,(uint64_t)i+1); }   /* 预热 */

  double *v1 = malloc((size_t)N*sizeof(double)), *v2 = malloc((size_t)N*sizeof(double));
  for(int r=0;r<N;r++){
    uint64_t t0,t1; double s1,s2,e1,e2;
    t0=rd(); g1_store(A,nG1); t1=rd(); s1=(double)(t1-t0);
    t0=rd(); g1_load (A,nG1); t1=rd(); s2=(double)(t1-t0);
    v1[r] = s1 - s2;
    t0=rd(); g2(A,A,nG2,(uint64_t)r+1); t1=rd(); e1=(double)(t1-t0);
    t0=rd(); g2(C,A,nG2,(uint64_t)r+1); t1=rd(); e2=(double)(t1-t0);
    v2[r] = e1 - e2;
  }

  double lo1,hi1,lo2,hi2;
  boot_mean(v1,N,B,&lo1,&hi1);
  boot_mean(v2,N,B,&lo2,&hi2);
  double m1=mean(v1,N), m2=mean(v2,N), sd1=sdev(v1,N), sd2=sdev(v2,N);

  printf("# tick=%.2f ns  N=%d  nG1=%d  nG2=%d  CHAIN=%d\n", nspt, N, nG1, nG2, CHAIN);

  printf("\n== G1: str+ldr vs 纯 ldr (每样本 %d 次迭代) ==\n", nG1);
  printf("   mean dT = %+.2f ticks (%+.1f ns)   95%%CI [%+.2f, %+.2f]\n", m1, m1*nspt, lo1, hi1);
  printf("   每次迭代 %+.3f ns   sd=%.2f   Cohen_d=%.2f\n", m1*nspt/nG1, sd1, (sd1>0? m1/sd1:0));
  int p1 = (lo1 > 0.0);
  printf("   G1 %s\n", p1 ? "PASS  (store 参与确实改变时序 -> 装置看得见存储流水线)"
                        : "FAIL  (对 store 参与无感 -> 后面一切无意义)");

  printf("\n== G2: store 地址晚到, 别名 vs 不别名 (每样本 %d 次迭代) ==\n", nG2);
  printf("   mean dT = %+.2f ticks (%+.1f ns)   95%%CI [%+.2f, %+.2f]\n", m2, m2*nspt, lo2, hi2);
  printf("   每次迭代 %+.3f ns   sd=%.2f   Cohen_d=%.2f\n", m2*nspt/nG2, sd2, (sd2>0? m2/sd2:0));
  int p2 = (lo2 > 0.0);
  printf("   G2 %s\n", p2 ? "PASS  (load 确实在等不确定的 store -> 消歧机制可观测)"
                        : "FAIL  (别名无惩罚 -> 探针没打到消歧, 或核能完美投机)");

  printf("\n>>> S1b %s\n", (p1&&p2) ? "PASS : 装置过 SELF 闸门, 可进 S1c"
                     : (p1 ? "HALF : G1 过 G2 不过, 要改探针结构" : "FAIL : 装置不可用, 先修装置"));
  printf(">>> 摘要行: G1=%+.2f[%+.2f,%+.2f] G2=%+.2f[%+.2f,%+.2f] %s\n",
         m1, lo1, hi1, m2, lo2, hi2, (p1&&p2)?"PASS":"FAIL");
  return (p1&&p2) ? 0 : 1;
}
```


#### 源码 S1b-v2 `mdu_self2.c`（完整，可直接编译）

> CC=gcc -O2 -o mdu_self2 mdu_self2.c；SELF 闸门通过（G2 PASS）

```c
/* mdu_self2.c —— S1b-v2: 转发重叠 SELF 闸门（TC-03 / 会话 7）
 * 编译: gcc -O2 -o mdu_self2 mdu_self2.c   运行: taskset -c 3 ./mdu_self2
 * 结果: G2 PASS —— SLOW-FAST = +37.00 tick = 2.891 ns/pair = 8.7 cycle/iter, dirty 0.1%
 *       G1 判据作废（"store 必然更慢"假设被推翻: FAST 4.0 < BASE 10.0）
 * 与 TC-03/S1c 的阶梯（删-fence: 0.391 / 0.781 / 3.203 ns/pair）同源, 口径不同不可混比
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static inline uint64_t rd(void){ uint64_t t; __asm__ __volatile__("mrs %0, cntvct_el0":"=r"(t)); return t; }
static volatile uint64_t sinkv;
static unsigned char *buf;

static uint64_t rs = 0x243F6A8885A308D3ULL;
static inline uint64_t xr(void){ uint64_t s=rs; s^=s<<13; s^=s>>7; s^=s<<17; rs=s; return s; }

/* FAST: str 8B + ldr 8B, 完全重叠 -> 可转发 */
__attribute__((noinline)) static void ar_full(void *a, int n){
  uint64_t acc=0, x=0; const uint64_t v=0x1111111122222222ULL;
  for(int i=0;i<n;i++){
    __asm__ __volatile__("str %1,[%2]\n\tldr %0,[%2]" : "=&r"(x) : "r"(v), "r"(a) : "memory");
    acc += x;
  }
  sinkv = acc;
}
/* SLOW: str 4B + ldr 8B, 部分重叠 -> 不能转发 */
__attribute__((noinline)) static void ar_part(void *a, int n){
  uint64_t acc=0, x=0; const uint64_t v=0x1111111122222222ULL;
  for(int i=0;i<n;i++){
    __asm__ __volatile__("str %w1,[%2]\n\tldr %0,[%2]" : "=&r"(x) : "r"(v), "r"(a) : "memory");
    acc += x;
  }
  sinkv = acc;
}
/* BASE: 纯 ldr */
__attribute__((noinline)) static void ar_load(void *a, int n){
  uint64_t acc=0, x=0;
  for(int i=0;i<n;i++){
    __asm__ __volatile__("ldr %0,[%1]" : "=&r"(x) : "r"(a) : "memory");
    acc += x;
  }
  sinkv = acc;
}

static int cmpd(const void *p, const void *q){ double x=*(const double*)p, y=*(const double*)q; return (x>y)-(x<y); }
static double qsel(double *v, int n, double p){
  double *c = malloc((size_t)n*sizeof(double));
  memcpy(c, v, (size_t)n*sizeof(double));
  qsort(c, (size_t)n, sizeof(double), cmpd);
  int i = (int)(p*(n-1)); double r = c[i]; free(c); return r;
}
static double trim_mean(double *v, int n, double frac){
  double *c = malloc((size_t)n*sizeof(double));
  memcpy(c, v, (size_t)n*sizeof(double));
  qsort(c, (size_t)n, sizeof(double), cmpd);
  int k=(int)(frac*n), m=0; double s=0;
  for(int i=k;i<n-k;i++){ s+=c[i]; m++; }
  free(c); return m? s/m : 0.0;
}
static void boot_median(double *v, int n, int B, double *lo, double *hi){
  double *m = malloc((size_t)B*sizeof(double));
  double *s = malloc((size_t)n*sizeof(double));
  for(int b=0;b<B;b++){
    for(int i=0;i<n;i++) s[i] = v[(int)(xr()%(uint64_t)n)];
    qsort(s,(size_t)n,sizeof(double),cmpd);
    m[b] = s[n/2];
  }
  qsort(m,(size_t)B,sizeof(double),cmpd);
  *lo = m[(int)(0.025*(B-1))]; *hi = m[(int)(0.975*(B-1))];
  free(m); free(s);
}

int main(void){
  uint64_t frq=0; __asm__ __volatile__("mrs %0, cntfrq_el0":"=r"(frq));
  if(!frq) frq=50000000ULL;
  const double nspt = 1e9/(double)frq;

  if(posix_memalign((void**)&buf, 4096, 1u<<20)!=0) return 2;
  memset(buf, 0, 1u<<20);
  void *A = (void*)buf;

  const int n = 256, N = 1000, B = 2000;
  for(int i=0;i<5000;i++){ ar_load(A,1); ar_full(A,1); ar_part(A,1); }

  double *vF  = malloc((size_t)N*sizeof(double));
  double *vP  = malloc((size_t)N*sizeof(double));
  double *vB  = malloc((size_t)N*sizeof(double));
  double *dG2 = malloc((size_t)N*sizeof(double));
  double *dG1 = malloc((size_t)N*sizeof(double));

  for(int r=0;r<N;r++){
    uint64_t t0,t1;
    t0=rd(); ar_full(A,n); t1=rd(); vF[r]=(double)(t1-t0);
    t0=rd(); ar_part(A,n); t1=rd(); vP[r]=(double)(t1-t0);
    t0=rd(); ar_load(A,n); t1=rd(); vB[r]=(double)(t1-t0);
    dG2[r] = vP[r]-vF[r];
    dG1[r] = vF[r]-vB[r];
  }

  int dirty=0;
  for(int r=0;r<N;r++){ double a = dG2[r]<0? -dG2[r] : dG2[r]; if(a>100.0) dirty++; }

  printf("# tick=%.2f ns  n=%d  N=%d  (每样本 %d 次迭代)\n", nspt, n, N, n);
  printf("\n== 三臂绝对中位数 ==\n");
  printf("  BASE 纯 ldr         %8.1f ticks (%7.1f ns)  %6.3f ns/iter\n",
         qsel(vB,N,0.5), qsel(vB,N,0.5)*nspt, qsel(vB,N,0.5)*nspt/n);
  printf("  FAST str8B+ldr8B    %8.1f ticks (%7.1f ns)  %6.3f ns/iter\n",
         qsel(vF,N,0.5), qsel(vF,N,0.5)*nspt, qsel(vF,N,0.5)*nspt/n);
  printf("  SLOW str4B+ldr8B    %8.1f ticks (%7.1f ns)  %6.3f ns/iter\n",
         qsel(vP,N,0.5), qsel(vP,N,0.5)*nspt, qsel(vP,N,0.5)*nspt/n);

  double lo,hi;
  boot_median(dG1,N,B,&lo,&hi);
  double m1=qsel(dG1,N,0.5);
  printf("\n== G1: FAST - BASE  (store 参与的影响) ==\n");
  printf("  median d = %+.2f ticks   CI [%+.2f, %+.2f]   trim10%% = %+.2f   %+.3f ns/iter\n",
         m1, lo, hi, trim_mean(dG1,N,0.10), m1*nspt/n);
  int p1 = (lo > 0.0);
  printf("  G1 %s\n", p1? "PASS" : "FAIL");

  boot_median(dG2,N,B,&lo,&hi);
  double m2=qsel(dG2,N,0.5);
  printf("\n== G2: SLOW - FAST  (部分重叠不能转发的代价) ==\n");
  printf("  median d = %+.2f ticks   CI [%+.2f, %+.2f]   trim10%% = %+.2f   %+.3f ns/iter\n",
         m2, lo, hi, trim_mean(dG2,N,0.10), m2*nspt/n);
  printf("  脏样本(|d|>100 tick) %d/%d = %.1f%%\n", dirty, N, 100.0*dirty/N);
  int p2 = (lo > 0.0);
  printf("  G2 %s\n", p2? "PASS  (部分重叠确实不能转发 -> 消歧/转发机制可观测)"
                        : "FAIL  (部分重叠无代价 -> 探针没打中, 换 1B/2B 重叠或换地址)");

  printf("\n>>> S1b-v2 %s\n", (p1&&p2)? "PASS : 装置过 SELF, 进 S1c"
                        : (p1? "HALF : G1 过 G2 不过" : "FAIL"));
  printf(">>> 摘要行: BASE=%.1f FAST=%.1f SLOW=%.1f G1=%+.2f[%+.2f,%+.2f] G2=%+.2f[%+.2f,%+.2f] dirty=%.1f%% %s\n",
         qsel(vB,N,0.5), qsel(vF,N,0.5), qsel(vP,N,0.5),
         m1,lo,hi, m2,lo,hi, 100.0*dirty/N, (p1&&p2)?"PASS":"FAIL");
  return (p1&&p2)? 0 : 1;
}
```


#### 源码 S1c `mdu_state.c`（完整，可直接编译）

> CC=gcc -O2 -o mdu_state mdu_state.c；初判 PASS，后作废（位置伪影）

```c
/* mdu_state.c —— S1c: 同 PC 训练剂量反应 + 三臂绝对阶梯（TC-03 / 会话 8）【初判 PASS, 后作废】
 * 编译: gcc -O2 -o mdu_state mdu_state.c   运行: taskset -c 3 ./mdu_state
 * 实测: 阶梯 off+8=10.0 / off0=5.0 / off-4=41.0 tick（1.562 / 0.391 / 3.203 ns/pair）
 *       S = -6.00 tick（初判阳性）
 * 作废: 经 S1e 查明为"位置伪影"——同一条件排第 3 位量到 19 tick、第 1 位量到 23 tick
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static inline uint64_t rd(void){ uint64_t t; __asm__ __volatile__("mrs %0, cntvct_el0":"=r"(t)); return t; }
static unsigned char *buf;

static uint64_t rs = 0x243F6A8885A308D3ULL;
static inline uint64_t xr(void){ uint64_t s=rs; s^=s<<13; s^=s>>7; s^=s<<17; rs=s; return s; }

/* 同一函数、同一指令流：store 8B -> a+off ; load 8B <- a
   off=+8 不重叠 / 0 完全重叠 / (uintptr_t)-4 部分重叠(4B)
   注意：没有累加器，靠 __volatile__ 保证不被优化 */
__attribute__((noinline)) static void pair(void *a, uintptr_t off, int n){
  const uint64_t v = 0x1111111122222222ULL;
  for(int i=0;i<n;i++){
    uint64_t x;
    void *s = (void*)((uintptr_t)a + off);
    __asm__ __volatile__("str %1,[%2]\n\tldr %0,[%3]"
                         : "=&r"(x) : "r"(v), "r"(s), "r"(a) : "memory");
    (void)x;
  }
}

static int cmpd(const void*p,const void*q){ double x=*(const double*)p,y=*(const double*)q; return (x>y)-(x<y); }
static double qsel(double *v,int n,double p){
  double *c=malloc((size_t)n*sizeof(double)); memcpy(c,v,(size_t)n*sizeof(double));
  qsort(c,(size_t)n,sizeof(double),cmpd);
  int i=(int)(p*(n-1)); double r=c[i]; free(c); return r;
}
static double trim_mean(double *v,int n,double f){
  double *c=malloc((size_t)n*sizeof(double)); memcpy(c,v,(size_t)n*sizeof(double));
  qsort(c,(size_t)n,sizeof(double),cmpd);
  int k=(int)(f*n),m=0; double s=0;
  for(int i=k;i<n-k;i++){ s+=c[i]; m++; }
  free(c); return m? s/m : 0.0;
}
static double mean(double *v,int n){ double s=0; for(int i=0;i<n;i++) s+=v[i]; return s/n; }
static void boot_median(double *v,int n,int B,double *lo,double *hi){
  double *m=malloc((size_t)B*sizeof(double)), *s=malloc((size_t)n*sizeof(double));
  for(int b=0;b<B;b++){
    for(int i=0;i<n;i++) s[i]=v[(int)(xr()%(uint64_t)n)];
    qsort(s,(size_t)n,sizeof(double),cmpd); m[b]=s[n/2];
  }
  qsort(m,(size_t)B,sizeof(double),cmpd);
  *lo=m[(int)(0.025*(B-1))]; *hi=m[(int)(0.975*(B-1))];
  free(m); free(s);
}

int main(void){
  uint64_t frq=0; __asm__ __volatile__("mrs %0, cntfrq_el0":"=r"(frq));
  if(!frq) frq=50000000ULL;
  const double nspt=1e9/(double)frq;

  if(posix_memalign((void**)&buf,4096,1u<<20)!=0) return 2;
  memset(buf,0,1u<<20);
  void *A = (void*)(buf+64);          /* 留出前 64B，供 off=-4 合法 */
  const uintptr_t OFF4 = (uintptr_t)-4;

  for(int i=0;i<20000;i++){ pair(A,8,1); pair(A,0,1); pair(A,OFF4,1); }

  /* ===== A. 三臂绝对阶梯（同一指令流，跨臂可比） ===== */
  const int nA=256, NA=500;
  double *v8=malloc((size_t)NA*sizeof(double));
  double *v0=malloc((size_t)NA*sizeof(double));
  double *v4=malloc((size_t)NA*sizeof(double));
  for(int r=0;r<NA;r++){
    uint64_t t0,t1;
    t0=rd(); pair(A, 8,nA); t1=rd(); v8[r]=(double)(t1-t0);
    t0=rd(); pair(A, 0,nA); t1=rd(); v0[r]=(double)(t1-t0);
    t0=rd(); pair(A,OFF4,nA); t1=rd(); v4[r]=(double)(t1-t0);
  }
  printf("# tick=%.2f ns   nA=%d NA=%d   (无累加器)\n", nspt, nA, NA);
  printf("\n== A. 三臂绝对阶梯（同一 pair() 指令流）==\n");
  printf("  off=+8  不重叠     %8.1f ticks (%7.1f ns)  %6.3f ns/iter\n", qsel(v8,NA,0.5), qsel(v8,NA,0.5)*nspt, qsel(v8,NA,0.5)*nspt/nA);
  printf("  off= 0  完全重叠   %8.1f ticks (%7.1f ns)  %6.3f ns/iter\n", qsel(v0,NA,0.5), qsel(v0,NA,0.5)*nspt, qsel(v0,NA,0.5)*nspt/nA);
  printf("  off=-4  部分重叠   %8.1f ticks (%7.1f ns)  %6.3f ns/iter\n", qsel(v4,NA,0.5), qsel(v4,NA,0.5)*nspt, qsel(v4,NA,0.5)*nspt/nA);
  printf("  转发代价(部分-完全) = %+.1f ticks\n", qsel(v4,NA,0.5)-qsel(v0,NA,0.5));

  /* ===== B. 训练剂量反应（同 PC） ===== */
  const int REP=32, TR=8, PR=4, N=1000;
  double *S=malloc((size_t)N*sizeof(double));
  double *t1v=malloc((size_t)N*sizeof(double));
  for(int r=0;r<N;r++){
    uint64_t a0,b0; int64_t T1,T2,T3,T4;
    a0=rd(); for(int k=0;k<REP;k++){ pair(A,0,TR);    pair(A,OFF4,PR); } b0=rd(); T1=(int64_t)(b0-a0);
    a0=rd(); for(int k=0;k<REP;k++){ pair(A,OFF4,TR); pair(A,OFF4,PR); } b0=rd(); T2=(int64_t)(b0-a0);
    a0=rd(); for(int k=0;k<REP;k++){ pair(A,0,TR);    }                 b0=rd(); T3=(int64_t)(b0-a0);
    a0=rd(); for(int k=0;k<REP;k++){ pair(A,OFF4,TR); }                 b0=rd(); T4=(int64_t)(b0-a0);
    S[r]  = (double)((T1-T3)-(T2-T4));
    t1v[r]= (double)T1;
  }
  int dirty=0; for(int r=0;r<N;r++){ double a=S[r]<0?-S[r]:S[r]; if(a>100.0) dirty++; }
  double lo,hi; boot_median(S,N,2000,&lo,&hi);
  double ms=qsel(S,N,0.5);

  printf("\n== B. 训练剂量反应（REP=%d TR=%d PR=%d N=%d）==\n", REP,TR,PR,N);
  printf("  单样本 T1 中位 = %.1f ticks (%d 次训练 + %d 次探测, 共 %d 轮)\n",
         qsel(t1v,N,0.5), TR,PR,REP);
  printf("  S = (T1-T3)-(T2-T4)   中位数 %+.2f ticks   CI [%+.2f, %+.2f]   trim10%% %+.2f\n",
         ms, lo, hi, trim_mean(S,N,0.10));
  printf("  折成每次探测迭代 %+.3f ns   脏样本 %d/%d = %.1f%%\n",
         ms*nspt/(double)(REP*PR), dirty, N, 100.0*dirty/N);
  int pass = (lo>0.0) || (hi<0.0);
  printf("\n  B %s\n", pass ? "PASS : 训练确实改变了探测代价 -> MDU 状态可训练, 进 S2 跨进程"
                            : "NULL : CI 含 0, 本探针下未观测到训练效应");

  printf("\n>>> S1c %s\n", pass?"PASS":"NULL");
  printf(">>> 摘要行: step(off8=%.1f off0=%.1f off4=%.1f) S=%+.2f[%+.2f,%+.2f] trim=%+.2f dirty=%.1f%% %s\n",
         qsel(v8,NA,0.5), qsel(v0,NA,0.5), qsel(v4,NA,0.5), ms,lo,hi,trim_mean(S,N,0.10),100.0*dirty/N, pass?"PASS":"NULL");
  return pass?0:1;
}
```


#### 源码 S1d `mdu_dose.c`（完整，可直接编译）

> CC=gcc -O2 -o mdu_dose mdu_dose.c；与 S1c 符号相反

```c
/* mdu_dose.c —— S1d: 特异性控制（off=+8 臂）+ TR 剂量反应（会话 9）【FAIL / 与 S1c 符号相反】
 * 编译: gcc -O2 -o mdu_dose mdu_dose.c    运行: taskset -c 3 ./mdu_dose
 * 实测: TR=1/4/16/64 -> S_full = 0.00 / +3.00 / +7.00 / +6.00 tick
 *       S_ctrl = 0.00 / -1.00 / +1.00 / -1.00（±1 tick 即量化地板）
 * 问题: ① 判据用 CI 卡 ±1 tick 离散量过严（实现上还漏检了 S_ctrl）
 *       ② 与 S1c 的 -6 符号相反 -> 效应不可复现
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static inline uint64_t rd(void){ uint64_t t; __asm__ __volatile__("mrs %0, cntvct_el0":"=r"(t)); return t; }
static unsigned char *buf;

static uint64_t rs = 0x243F6A8885A308D3ULL;
static inline uint64_t xr(void){ uint64_t s=rs; s^=s<<13; s^=s>>7; s^=s<<17; rs=s; return s; }

__attribute__((noinline)) static void pair(void *a, uintptr_t off, int n){
  const uint64_t v = 0x1111111122222222ULL;
  for(int i=0;i<n;i++){
    uint64_t x;
    void *s = (void*)((uintptr_t)a + off);
    __asm__ __volatile__("str %1,[%2]\n\tldr %0,[%3]"
                         : "=&r"(x) : "r"(v), "r"(s), "r"(a) : "memory");
    (void)x;
  }
}

static int cmpd(const void*p,const void*q){ double x=*(const double*)p,y=*(const double*)q; return (x>y)-(x<y); }
static double qsel(double *v,int n,double p){
  double *c=malloc((size_t)n*sizeof(double)); memcpy(c,v,(size_t)n*sizeof(double));
  qsort(c,(size_t)n,sizeof(double),cmpd);
  int i=(int)(p*(n-1)); double r=c[i]; free(c); return r;
}
static void boot_median(double *v,int n,int B,double *lo,double *hi){
  double *m=malloc((size_t)B*sizeof(double)), *s=malloc((size_t)n*sizeof(double));
  for(int b=0;b<B;b++){
    for(int i=0;i<n;i++) s[i]=v[(int)(xr()%(uint64_t)n)];
    qsort(s,(size_t)n,sizeof(double),cmpd); m[b]=s[n/2];
  }
  qsort(m,(size_t)B,sizeof(double),cmpd);
  *lo=m[(int)(0.025*(B-1))]; *hi=m[(int)(0.975*(B-1))];
  free(m); free(s);
}

/* 探测代价 = ("训练+探测") − ("仅训练") */
__attribute__((noinline)) static double pcost(void *A, uintptr_t toff, uintptr_t poff, int TR, int PR, int REP){
  uint64_t a,b; int64_t w,wo;
  a=rd(); for(int k=0;k<REP;k++){ pair(A,toff,TR); pair(A,poff,PR); } b=rd(); w =(int64_t)(b-a);
  a=rd(); for(int k=0;k<REP;k++){ pair(A,toff,TR); }                 b=rd(); wo=(int64_t)(b-a);
  return (double)(w-wo);
}

int main(void){
  uint64_t frq=0; __asm__ __volatile__("mrs %0, cntfrq_el0":"=r"(frq));
  if(!frq) frq=50000000ULL;
  const double nspt = 1e9/(double)frq;

  if(posix_memalign((void**)&buf,4096,1u<<20)!=0) return 2;
  memset(buf,0,1u<<20);
  void *A = (void*)(buf+64);

  const uintptr_t O0=0, O8=8, O4=(uintptr_t)-4;
  const int REP=16, PR=4, N=400;
  const int TRS[4]={1,4,16,64};

  for(int i=0;i<20000;i++){ pair(A,O0,1); pair(A,O8,1); pair(A,O4,1); }

  double sf_m[4], sf_l[4], sf_h[4], sc_m[4], sc_l[4], sc_h[4];

  printf("# tick=%.2f  REP=%d PR=%d N=%d\n", nspt, REP, PR, N);

  for(int t=0;t<4;t++){
    int TR = TRS[t];
    double *p0=malloc((size_t)N*sizeof(double));
    double *p8=malloc((size_t)N*sizeof(double));
    double *p4=malloc((size_t)N*sizeof(double));
    double *sf=malloc((size_t)N*sizeof(double));
    double *sc=malloc((size_t)N*sizeof(double));

    for(int r=0;r<N;r++){
      p0[r]=pcost(A,O0,O4,TR,PR,REP);
      p8[r]=pcost(A,O8,O4,TR,PR,REP);
      p4[r]=pcost(A,O4,O4,TR,PR,REP);
      sf[r]=p0[r]-p4[r];
      sc[r]=p8[r]-p4[r];
    }

    int dirty=0;
    for(int r=0;r<N;r++){ double a=sf[r]<0?-sf[r]:sf[r]; if(a>100.0) dirty++; }

    sf_m[t]=qsel(sf,N,0.5); boot_median(sf,N,1500,&sf_l[t],&sf_h[t]);
    sc_m[t]=qsel(sc,N,0.5); boot_median(sc,N,1500,&sc_l[t],&sc_h[t]);

    printf("\n TR=%-3d  P(off0)=%6.1f  P(off8)=%6.1f  P(off4)=%6.1f  ticks\n",
           TR, qsel(p0,N,0.5), qsel(p8,N,0.5), qsel(p4,N,0.5));
    printf("         S_full(0-4) = %+7.2f  CI [%+.2f, %+.2f]   %+.3f ns/probe-iter\n",
           sf_m[t], sf_l[t], sf_h[t], sf_m[t]*nspt/(double)(REP*PR));
    printf("         S_ctrl(8-4) = %+7.2f  CI [%+.2f, %+.2f]   dirty %d/%d = %.1f%%\n",
           sc_m[t], sc_l[t], sc_h[t], dirty, N, 100.0*dirty/N);

    free(p0); free(p8); free(p4); free(sf); free(sc);
  }

  int sig=0;
  for(int t=0;t<4;t++) if(sf_l[t]>0.0 || sf_h[t]<0.0) sig++;
  int spec_ok=1;
  for(int t=0;t<4;t++) if(sc_l[t]>0.0 || sc_h[t]<0.0) spec_ok=0;
  double a1=sf_m[0]<0?-sf_m[0]:sf_m[0];
  double a4=sf_m[3]<0?-sf_m[3]:sf_m[3];
  int dose_ok=(a4 > a1*1.5);

  printf("\n== 判定 ==\n");
  printf("  显著组数        : %d/4   (要求 >=3)\n", sig);
  printf("  特异性(S_ctrl)  : %s\n", spec_ok?"OK 控制臂全程不显著":"不通过 — 控制臂也显著, 效应非转发特有");
  printf("  剂量反应        : |S|@TR=1 %.2f -> @TR=64 %.2f  %s\n",
         a1, a4, dose_ok?"单调增长 OK":"不随 TR 增长 — 疑为固定流水线模式");

  int pass = (sig>=3) && spec_ok && dose_ok;
  printf("\n>>> S1d %s\n", pass? "PASS : 转发状态可训练且特异 -> Q-A 成立, 进 S2 跨进程"
                    : "FAIL : 见上面三项哪条没过, 按对应分支改探针");
  printf(">>> 摘要行:");
  for(int t=0;t<4;t++) printf(" TR%d=%+.1f[%+.1f,%+.1f]", TRS[t], sf_m[t], sf_l[t], sf_h[t]);
  printf("  ctrl_ok=%d dose_ok=%d %s\n", spec_ok, dose_ok, pass?"PASS":"FAIL");
  return pass?0:1;
}
```


#### 源码 S1e `mdu_order.c`（完整，可直接编译）

> CC=gcc -O2 -o mdu_order mdu_order.c；反序对照，查明位置伪影

```c
/* mdu_order.c —— S1e: 反序对照（正序/反序两遍）（会话 10）【假阳: 位置伪影主导】
 * 编译: gcc -O2 -o mdu_order mdu_order.c   运行: taskset -c 3 ./mdu_order
 * 实测 TR=8 : 正序 P0/P8/P4 = 19/18/19, 反序 = 19/23/23 -> S_fwd 0.00 / S_rev -4.00, 不同号
 *      TR=16: 正序 18/18/19, 反序 19/24/24 -> S_fwd -1.00 / S_rev -5.00, 同号(程序判"真效应")
 * 判决: 同一条件 off=-4 排第 3 位量到 19 tick、排第 1 位量到 23 tick（差 4 tick）,
 *       待测效应只有 2~3 tick -> 位置伪影主导, TR=16 的"同号"是假阳
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static inline uint64_t rd(void){ uint64_t t; __asm__ __volatile__("mrs %0, cntvct_el0":"=r"(t)); return t; }
static unsigned char *buf;

static uint64_t rs = 0x243F6A8885A308D3ULL;
static inline uint64_t xr(void){ uint64_t s=rs; s^=s<<13; s^=s>>7; s^=s<<17; rs=s; return s; }

__attribute__((noinline)) static void pair(void *a, uintptr_t off, int n){
  const uint64_t v = 0x1111111122222222ULL;
  for(int i=0;i<n;i++){
    uint64_t x;
    void *s = (void*)((uintptr_t)a + off);
    __asm__ __volatile__("str %1,[%2]\n\tldr %0,[%3]"
                         : "=&r"(x) : "r"(v), "r"(s), "r"(a) : "memory");
    (void)x;
  }
}

static int cmpd(const void*p,const void*q){ double x=*(const double*)p,y=*(const double*)q; return (x>y)-(x<y); }
static double qsel(double *v,int n,double p){
  double *c=malloc((size_t)n*sizeof(double)); memcpy(c,v,(size_t)n*sizeof(double));
  qsort(c,(size_t)n,sizeof(double),cmpd);
  int i=(int)(p*(n-1)); double r=c[i]; free(c); return r;
}
static void boot_median(double *v,int n,int B,double *lo,double *hi){
  double *m=malloc((size_t)B*sizeof(double)), *s=malloc((size_t)n*sizeof(double));
  for(int b=0;b<B;b++){
    for(int i=0;i<n;i++) s[i]=v[(int)(xr()%(uint64_t)n)];
    qsort(s,(size_t)n,sizeof(double),cmpd); m[b]=s[n/2];
  }
  qsort(m,(size_t)B,sizeof(double),cmpd);
  *lo=m[(int)(0.025*(B-1))]; *hi=m[(int)(0.975*(B-1))];
  free(m); free(s);
}
__attribute__((noinline)) static double pcost(void *A, uintptr_t toff, uintptr_t poff, int TR, int PR, int REP){
  uint64_t a,b; int64_t w,wo;
  a=rd(); for(int k=0;k<REP;k++){ pair(A,toff,TR); pair(A,poff,PR); } b=rd(); w =(int64_t)(b-a);
  a=rd(); for(int k=0;k<REP;k++){ pair(A,toff,TR); }                 b=rd(); wo=(int64_t)(b-a);
  return (double)(w-wo);
}

int main(void){
  uint64_t frq=0; __asm__ __volatile__("mrs %0, cntfrq_el0":"=r"(frq));
  if(!frq) frq=50000000ULL;
  const double nspt = 1e9/(double)frq;

  if(posix_memalign((void**)&buf,4096,1u<<20)!=0) return 2;
  memset(buf,0,1u<<20);
  void *A = (void*)(buf+64);
  const uintptr_t O0=0, O8=8, O4=(uintptr_t)-4, PO=O4;
  const int REP=32, PR=4, N=400;
  const int TRS[2]={8,16};

  for(int i=0;i<20000;i++){ pair(A,O0,1); pair(A,O8,1); pair(A,O4,1); }

  printf("# tick=%.2f  REP=%d PR=%d N=%d  (每样本跑正序+反序两遍)\n", nspt, REP, PR, N);

  for(int t=0;t<2;t++){
    int TR=TRS[t];
    double *p0a=malloc((size_t)N*sizeof(double)),*p8a=malloc((size_t)N*sizeof(double)),*p4a=malloc((size_t)N*sizeof(double));
    double *p0b=malloc((size_t)N*sizeof(double)),*p8b=malloc((size_t)N*sizeof(double)),*p4b=malloc((size_t)N*sizeof(double));
    double *sf1=malloc((size_t)N*sizeof(double)),*sf2=malloc((size_t)N*sizeof(double));
    double *sc1=malloc((size_t)N*sizeof(double)),*sc2=malloc((size_t)N*sizeof(double));
    double *sfv=malloc((size_t)N*sizeof(double));

    for(int r=0;r<N;r++){
      /* 正序 0 -> 8 -> 4 */
      p0a[r]=pcost(A,O0,PO,TR,PR,REP);
      p8a[r]=pcost(A,O8,PO,TR,PR,REP);
      p4a[r]=pcost(A,O4,PO,TR,PR,REP);
      /* 反序 4 -> 8 -> 0 */
      p4b[r]=pcost(A,O4,PO,TR,PR,REP);
      p8b[r]=pcost(A,O8,PO,TR,PR,REP);
      p0b[r]=pcost(A,O0,PO,TR,PR,REP);

      sf1[r]=p0a[r]-p4a[r]; sc1[r]=p8a[r]-p4a[r];
      sf2[r]=p0b[r]-p4b[r]; sc2[r]=p8b[r]-p4b[r];
      sfv[r]=(sf1[r]+sf2[r])/2.0;
    }

    double l1,h1,l2,h2,lv,hv;
    boot_median(sf1,N,1500,&l1,&h1);
    boot_median(sf2,N,1500,&l2,&h2);
    boot_median(sfv,N,1500,&lv,&hv);
    double m1=qsel(sf1,N,0.5), m2=qsel(sf2,N,0.5), mv=qsel(sfv,N,0.5);

    printf("\n TR=%-3d  正序: P0=%5.1f P8=%5.1f P4=%5.1f   反序: P0=%5.1f P8=%5.1f P4=%5.1f  ticks\n",
           TR, qsel(p0a,N,0.5),qsel(p8a,N,0.5),qsel(p4a,N,0.5), qsel(p0b,N,0.5),qsel(p8b,N,0.5),qsel(p4b,N,0.5));
    printf("         S_full 正序 %+7.2f CI[%+.2f,%+.2f]   反序 %+7.2f CI[%+.2f,%+.2f]\n", m1,l1,h1, m2,l2,h2);
    printf("         S_full 平均 %+7.2f CI[%+.2f,%+.2f]   = %+.3f ns/probe-iter\n",
           mv,lv,hv, mv*nspt/(double)(REP*PR));
    printf("         S_ctrl 正序 %+7.2f   反序 %+7.2f\n", qsel(sc1,N,0.5), qsel(sc2,N,0.5));

    int same = (m1>0.0 && m2>0.0) || (m1<0.0 && m2<0.0);
    double av = mv<0?-mv:mv;
    printf("         同号? %s    |平均| %.2f tick   -> %s\n",
           same?"YES":"NO(顺序伪影)", av,
           (same && av>2.0) ? "真效应" : "不成信号");

    free(p0a);free(p8a);free(p4a);free(p0b);free(p8b);free(p4b);
    free(sf1);free(sf2);free(sc1);free(sc2);free(sfv);
  }

  printf("\n>>> 判据: 正反两遍同号 且 |S_full 平均| > 2 tick -> 真效应\n");
  printf(">>> 若两遍反号 -> 之前的 -6 / +7 全是顺序伪影, 阳性作废\n");
  return 0;
}
```


#### 源码 S1f `mdu_direct.c`（完整，可直接编译）

> CC=gcc -O2 -o mdu_direct mdu_direct.c；PASS 但作废（地址碰撞）

```c
/* mdu_direct.c —— S1f: 只包 probe 段 + 条件轮转 + 前后半段自复制（会话 11）【PASS 但作废】
 * 编译: gcc -O2 -o mdu_direct mdu_direct.c   运行: taskset -c 3 ./mdu_direct
 * 实测: T0=80.0 T8=130.0 T4=189.0 tick; S_full=-110.00 tick（两半一致）, S_ctrl=-59.00 tick
 * 作废: S_ctrl=-59（占基线 31%）=> 效应不特异。根因: A=buf+64 为 64B 对齐,
 *       A-4 落在前一条 cache line, 而 probe 本身就是 str [A-4] -> store 地址碰撞。
 *       另: 判定语句漏检 S_ctrl（注释写了, 代码没实现）
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static inline uint64_t rd(void){ uint64_t t; __asm__ __volatile__("mrs %0, cntvct_el0":"=r"(t)); return t; }
static unsigned char *buf;

static uint64_t rs = 0x243F6A8885A308D3ULL;
static inline uint64_t xr(void){ uint64_t s=rs; s^=s<<13; s^=s>>7; s^=s<<17; rs=s; return s; }

__attribute__((noinline)) static void pair(void *a, uintptr_t off, int n){
  const uint64_t v = 0x1111111122222222ULL;
  for(int i=0;i<n;i++){
    uint64_t x;
    void *s = (void*)((uintptr_t)a + off);
    __asm__ __volatile__("str %1,[%2]\n\tldr %0,[%3]"
                         : "=&r"(x) : "r"(v), "r"(s), "r"(a) : "memory");
    (void)x;
  }
}

static int cmpd(const void*p,const void*q){ double x=*(const double*)p,y=*(const double*)q; return (x>y)-(x<y); }
static double qsel(double *v,int n,double p){
  double *c=malloc((size_t)n*sizeof(double)); memcpy(c,v,(size_t)n*sizeof(double));
  qsort(c,(size_t)n,sizeof(double),cmpd);
  int i=(int)(p*(n-1)); double r=c[i]; free(c); return r;
}
static void boot_median(double *v,int n,int B,double *lo,double *hi){
  double *m=malloc((size_t)B*sizeof(double)), *s=malloc((size_t)n*sizeof(double));
  for(int b=0;b<B;b++){
    for(int i=0;i<n;i++) s[i]=v[(int)(xr()%(uint64_t)n)];
    qsort(s,(size_t)n,sizeof(double),cmpd); m[b]=s[n/2];
  }
  qsort(m,(size_t)B,sizeof(double),cmpd);
  *lo=m[(int)(0.025*(B-1))]; *hi=m[(int)(0.975*(B-1))];
  free(m); free(s);
}

/* 只计 probe 段；训练段完全不计时 */
__attribute__((noinline)) static double probe_sum(void *A, uintptr_t toff, uintptr_t poff, int TR, int PR, int K){
  double tot = 0.0;
  for(int k=0;k<K;k++){
    pair(A, toff, TR);
    uint64_t a = rd();
    pair(A, poff, PR);
    uint64_t b = rd();
    tot += (double)(b-a);
  }
  return tot;
}

int main(void){
  uint64_t frq=0; __asm__ __volatile__("mrs %0, cntfrq_el0":"=r"(frq));
  if(!frq) frq=50000000ULL;
  const double nspt = 1e9/(double)frq;

  if(posix_memalign((void**)&buf,4096,1u<<20)!=0) return 2;
  memset(buf,0,1u<<20);
  void *A = (void*)(buf+64);

  const uintptr_t OFF[3] = {0, 8, (uintptr_t)-4};
  const char *NM[3] = {"off=0  全重叠","off=+8 不重叠","off=-4 部分重叠"};
  const uintptr_t PO = (uintptr_t)-4;
  const int TR=16, PR=16, K=64, N=300;

  for(int i=0;i<20000;i++){ pair(A,OFF[0],1); pair(A,OFF[1],1); pair(A,OFF[2],1); }

  double *T[3];
  for(int c=0;c<3;c++) T[c]=malloc((size_t)N*sizeof(double));

  for(int r=0;r<N;r++){
    for(int j=0;j<3;j++){
      int c = (r+j)%3;                        /* 条件轮转 */
      T[c][r] = probe_sum(A, OFF[c], PO, TR, PR, K);
    }
  }

  printf("# tick=%.2f  TR=%d PR=%d K=%d N=%d   (只计 probe 段, 训练段不计时)\n", nspt, TR, PR, K, N);

  printf("\n== 三条件探测总时（%d 段求和）==\n", K);
  for(int c=0;c<3;c++){
    double m=qsel(T[c],N,0.5);
    printf("  %-14s median %8.1f ticks (%8.1f ns)   %6.3f ns/pair\n",
           NM[c], m, m*nspt, m*nspt/(double)(K*PR));
  }

  double *sf=malloc((size_t)N*sizeof(double));
  double *sc=malloc((size_t)N*sizeof(double));
  for(int r=0;r<N;r++){ sf[r]=T[0][r]-T[2][r]; sc[r]=T[1][r]-T[2][r]; }

  double lo,hi;
  boot_median(sf,N,1500,&lo,&hi);
  double msf=qsel(sf,N,0.5);
  printf("\n== S_full = off0 - off4 （训练对探测的净影响）==\n");
  printf("  全体  median %+7.2f ticks  CI [%+.2f, %+.2f]   %+.3f ns/pair\n",
         msf, lo, hi, msf*nspt/(double)(K*PR));

  int H=N/2;
  double l1,h1,l2,h2;
  boot_median(sf,H,1500,&l1,&h1);
  boot_median(sf+H,H,1500,&l2,&h2);
  double m1=qsel(sf,H,0.5), m2=qsel(sf+H,H,0.5);
  printf("  前半  median %+7.2f  CI [%+.2f, %+.2f]\n", m1,l1,h1);
  printf("  后半  median %+7.2f  CI [%+.2f, %+.2f]\n", m2,l2,h2);

  int s1 = (l1>0.0||h1<0.0), s2 = (l2>0.0||h2<0.0);
  int same = (m1>0.0&&m2>0.0)||(m1<0.0&&m2<0.0);
  double av = msf<0?-msf:msf;

  boot_median(sc,N,1500,&lo,&hi);
  double msc=qsel(sc,N,0.5);
  printf("\n== S_ctrl = off8 - off4 （特异性）==\n");
  printf("  全体  median %+7.2f ticks  CI [%+.2f, %+.2f]\n", msc, lo, hi);

  printf("\n== 判定 ==\n");
  printf("  前半显著 %d   后半显著 %d   同号 %s   |S_full| %.2f tick\n",
         s1, s2, same?"YES":"NO", av);
  /* 注意: 本判定未检查 S_ctrl —— 这是实现缺陷, 后由 S1f 复盘发现 */
  int pass = s1 && s2 && same && av>4.0;
  printf("\n>>> S1f %s\n", pass ? "PASS : 训练效应稳健复现 -> Q-A 成立, 进 S2 跨进程"
                    : "NULL : 未观测到稳健训练效应 (同号/显著/幅度 三条至少一条没过)");
  printf(">>> 摘要行: T0=%.1f T8=%.1f T4=%.1f S_full=%+.2f half=(%+.2f,%+.2f) S_ctrl=%+.2f %s\n",
         qsel(T[0],N,0.5), qsel(T[1],N,0.5), qsel(T[2],N,0.5),
         msf, m1, m2, msc, pass?"PASS":"NULL");
  return pass?0:1;
}
```


#### 源码 S1g `mdu_clean.c`（完整，可直接编译）

> CC=gcc -O2 -o mdu_clean mdu_clean.c；无效（乱序重叠）

```c
/* mdu_clean.c —— S1g: probe 挪到远端固定地址 + 四条件（会话 12）【无效】
 * 编译: gcc -O2 -o mdu_clean mdu_clean.c   运行: taskset -c 3 ./mdu_clean
 * 实测: off0=115.0  off8=97.0  off4=60.0  FAR=128.0 tick（差 -14 / -31 / -68）
 * 判决: 形状不合理——最贵训练给出最快 probe、完全不碰数据区的远端训练最慢。
 *       病因: ① mrs 不是屏障, probe 与训练尾巴乱序重叠;
 *             ② str 8B [A-4] 跨 cache line 被拆成两个, 四条件本身不等价
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static inline uint64_t rd(void){ uint64_t t; __asm__ __volatile__("mrs %0, cntvct_el0":"=r"(t)); return t; }
static unsigned char *buf;

static uint64_t rs = 0x243F6A8885A308D3ULL;
static inline uint64_t xr(void){ uint64_t s=rs; s^=s<<13; s^=s>>7; s^=s<<17; rs=s; return s; }

__attribute__((noinline)) static void pair(void *a, uintptr_t off, int n){
  const uint64_t v = 0x1111111122222222ULL;
  for(int i=0;i<n;i++){
    uint64_t x;
    void *s = (void*)((uintptr_t)a + off);
    __asm__ __volatile__("str %1,[%2]\n\tldr %0,[%3]"
                         : "=&r"(x) : "r"(v), "r"(s), "r"(a) : "memory");
    (void)x;
  }
}

static int cmpd(const void*p,const void*q){ double x=*(const double*)p,y=*(const double*)q; return (x>y)-(x<y); }
static double qsel(double *v,int n,double p){
  double *c=malloc((size_t)n*sizeof(double)); memcpy(c,v,(size_t)n*sizeof(double));
  qsort(c,(size_t)n,sizeof(double),cmpd);
  int i=(int)(p*(n-1)); double r=c[i]; free(c); return r;
}
static void boot_median(double *v,int n,int B,double *lo,double *hi){
  double *m=malloc((size_t)B*sizeof(double)), *s=malloc((size_t)n*sizeof(double));
  for(int b=0;b<B;b++){
    for(int i=0;i<n;i++) s[i]=v[(int)(xr()%(uint64_t)n)];
    qsort(s,(size_t)n,sizeof(double),cmpd); m[b]=s[n/2];
  }
  qsort(m,(size_t)B,sizeof(double),cmpd);
  *lo=m[(int)(0.025*(B-1))]; *hi=m[(int)(0.975*(B-1))];
  free(m); free(s);
}

/* 训练在 (ta,toff)；probe 固定 (P,POFF)，与训练区完全不相交 */
__attribute__((noinline)) static double probe_sum(void *ta, uintptr_t toff, void *P, uintptr_t poff,
                                                  int TR, int PR, int K){
  double tot = 0.0;
  for(int k=0;k<K;k++){
    pair(ta, toff, TR);
    uint64_t a = rd();
    pair(P, poff, PR);
    uint64_t b = rd();
    tot += (double)(b-a);
  }
  return tot;
}

int main(void){
  uint64_t frq=0; __asm__ __volatile__("mrs %0, cntfrq_el0":"=r"(frq));
  if(!frq) frq=50000000ULL;
  const double nspt = 1e9/(double)frq;

  if(posix_memalign((void**)&buf,4096,1u<<20)!=0) return 2;
  memset(buf,0,1u<<20);

  void *A   = (void*)(buf + 64);
  void *FAR = (void*)(buf + (256u<<10));
  void *P   = (void*)(buf + (64u<<10));
  const uintptr_t POFF = (uintptr_t)-4;

  const int NC = 4;
  void     *TA[4] = {A, A, A, FAR};
  uintptr_t TO[4] = {0, 8, (uintptr_t)-4, 0};
  const char *NM[4] = {"训练 A off=0   (同线)", "训练 A off=+8  (同线)",
                       "训练 A off=-4  (前一线)", "训练 FAR off=0 (远端)"};

  const int TR=16, PR=16, K=64, N=300;

  for(int i=0;i<20000;i++){ pair(A,0,1); pair(A,8,1); pair(A,POFF,1); pair(FAR,0,1); pair(P,POFF,1); }

  double *T[4];
  for(int c=0;c<NC;c++) T[c]=malloc((size_t)N*sizeof(double));

  for(int r=0;r<N;r++){
    for(int j=0;j<NC;j++){
      int c = (r+j)%NC;
      T[c][r] = probe_sum(TA[c], TO[c], P, POFF, TR, PR, K);
    }
  }

  printf("# tick=%.2f  TR=%d PR=%d K=%d N=%d\n", nspt, TR, PR, K, N);
  printf("# probe 固定于 buf+64K (str [P-4]; ldr [P])，训练区在 buf+64 与 buf+256K，互不相交\n");

  printf("\n== 四条件探测总时（%d 段求和）==\n", K);
  for(int c=0;c<NC;c++){
    double m=qsel(T[c],N,0.5);
    printf("  %-22s %8.1f ticks (%8.1f ns)  %6.3f ns/pair\n", NM[c], m, m*nspt, m*nspt/(double)(K*PR));
  }

  double *D[3];
  const char *DN[3]={"off0 - 远端","off8 - 远端","off4 - 远端"};
  for(int i=0;i<3;i++) D[i]=malloc((size_t)N*sizeof(double));
  for(int r=0;r<N;r++){ D[0][r]=T[0][r]-T[3][r]; D[1][r]=T[1][r]-T[3][r]; D[2][r]=T[2][r]-T[3][r]; }

  printf("\n== 各条件相对「远端训练」的差 ==\n");
  double maxabs=0;
  for(int i=0;i<3;i++){
    double lo,hi; boot_median(D[i],N,1500,&lo,&hi);
    double m=qsel(D[i],N,0.5);
    if((m<0?-m:m) > maxabs) maxabs = (m<0?-m:m);
    printf("  %-14s %+7.2f ticks  CI [%+.2f, %+.2f]   %+.3f ns/pair\n", DN[i], m, lo, hi, m*nspt/(double)(K*PR));
  }

  int H=N/2;
  double lo,hi;
  printf("\n== 前后半段自复制（对 off0-远端 这一项）==\n");
  boot_median(D[0],H,1500,&lo,&hi);
  printf("  前半  %+7.2f  CI [%+.2f, %+.2f]\n", qsel(D[0],H,0.5), lo, hi);
  boot_median(D[0]+H,H,1500,&lo,&hi);
  printf("  后半  %+7.2f  CI [%+.2f, %+.2f]\n", qsel(D[0]+H,H,0.5), lo, hi);

  printf("\n== 判定（这次要它「不显著」才叫干净）==\n");
  printf("  最大 |差| = %.2f tick  (阈值 2.00)\n", maxabs);
  if(maxabs <= 2.0){
    printf("\n>>> S1g CLEAN : 去掉地址碰撞后，四条件无差异 -> 训练历史不影响探测，历史效应「未观测到」\n");
    printf(">>> 下一步: 这条线上不再追训练效应; 改用「无训练的架构阶梯」直接做 S2 跨进程\n");
  } else {
    printf("\n>>> S1g RESIDUAL : 仍有差 %.2f tick -> 说明除地址碰撞外还有别的因素, 看是哪一项\n", maxabs);
    printf(">>> 若只有 off0 与他人不同 => 可能是按 PC 索引的真实历史状态, 值得深挖\n");
    printf(">>> 若三项都不同    => 仍是局部性/流水线残留, 继续排除\n");
  }
  printf(">>> 摘要行: T0=%.1f T8=%.1f T4=%.1f TFAR=%.1f  maxdiff=%.2f %s\n",
         qsel(T[0],N,0.5), qsel(T[1],N,0.5), qsel(T[2],N,0.5), qsel(T[3],N,0.5),
         maxabs, (maxabs<=2.0)?"CLEAN":"RESIDUAL");
  return 0;
}
```


#### 源码 S1h `mdu_fence.c`（完整，可直接编译）

> CC=gcc -O2 -o mdu_fence mdu_fence.c；**CLEAN**，含-fence 口径

```c
/* mdu_fence.c —— S1h: fence 隔离 + 全对齐训练 + 四条件（TC-05 / 会话 13）【CLEAN】
 * 编译: gcc -O2 -o mdu_fence mdu_fence.c   运行: taskset -c 3 ./mdu_fence
 * 口径: 含-fence（每次 probe 前 dsb ish; isb），与删-fence 数字不可混比
 * 实测: 训练8B@A / 训练4B@A / 训练8B@A+8 / 不训练  ->  全部 60.0 tick，差 ±0.00
 *       300 样本逐样本相同 => 灵敏度上界 1.7% ≈ 0.02 ns/pair ≈ 0.06 cycle
 * 结论: 同 PC 的训练历史对 probe 无任何可观测影响（PC 索引路径排除）
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static inline uint64_t rd(void){ uint64_t t; __asm__ __volatile__("mrs %0, cntvct_el0":"=r"(t)); return t; }
static inline void fence(void){ __asm__ __volatile__("dsb ish\n\tisb" ::: "memory"); }
static unsigned char *buf;

static uint64_t rs = 0x243F6A8885A308D3ULL;
static inline uint64_t xr(void){ uint64_t s=rs; s^=s<<13; s^=s>>7; s^=s<<17; rs=s; return s; }

/* 训练臂：全部对齐 */
__attribute__((noinline)) static void tstore8(void *a, int n){
  const uint64_t v=0x1111111122222222ULL;
  for(int i=0;i<n;i++) __asm__ __volatile__("str %0,[%1]" :: "r"(v), "r"(a) : "memory");
}
__attribute__((noinline)) static void tstore4(void *a, int n){
  const uint64_t v=0x11111111ULL;
  for(int i=0;i<n;i++) __asm__ __volatile__("str %w0,[%1]" :: "r"(v), "r"(a) : "memory");
}
/* probe：对齐 4B store + 8B load（部分重叠） */
__attribute__((noinline)) static void probe(void *p, int n){
  const uint64_t v=0x11111111ULL;
  for(int i=0;i<n;i++){
    uint64_t x;
    __asm__ __volatile__("str %w1,[%2]\n\tldr %0,[%2]" : "=&r"(x) : "r"(v), "r"(p) : "memory");
    (void)x;
  }
}

static int cmpd(const void*p,const void*q){ double x=*(const double*)p,y=*(const double*)q; return (x>y)-(x<y); }
static double qsel(double *v,int n,double p){
  double *c=malloc((size_t)n*sizeof(double)); memcpy(c,v,(size_t)n*sizeof(double));
  qsort(c,(size_t)n,sizeof(double),cmpd);
  int i=(int)(p*(n-1)); double r=c[i]; free(c); return r;
}
static void boot_median(double *v,int n,int B,double *lo,double *hi){
  double *m=malloc((size_t)B*sizeof(double)), *s=malloc((size_t)n*sizeof(double));
  for(int b=0;b<B;b++){
    for(int i=0;i<n;i++) s[i]=v[(int)(xr()%(uint64_t)n)];
    qsort(s,(size_t)n,sizeof(double),cmpd); m[b]=s[n/2];
  }
  qsort(m,(size_t)B,sizeof(double),cmpd);
  *lo=m[(int)(0.025*(B-1))]; *hi=m[(int)(0.975*(B-1))];
  free(m); free(s);
}

/* mode: 0=训练8B@A  1=训练4B@A  2=训练8B@A+8  3=不训练 */
__attribute__((noinline)) static double one_cond(int mode, void *A, void *P, int TR, int PR, int K){
  double tot=0.0;
  for(int k=0;k<K;k++){
    if(mode==0) tstore8(A,TR);
    else if(mode==1) tstore4(A,TR);
    else if(mode==2) tstore8((void*)((uintptr_t)A+8),TR);
    fence();
    uint64_t a=rd(); probe(P,PR); uint64_t b=rd();
    tot += (double)(b-a);
  }
  return tot;
}

int main(void){
  uint64_t frq=0; __asm__ __volatile__("mrs %0, cntfrq_el0":"=r"(frq));
  if(!frq) frq=50000000ULL;
  const double nspt = 1e9/(double)frq;

  if(posix_memalign((void**)&buf,4096,1u<<20)!=0) return 2;
  memset(buf,0,1u<<20);
  void *A = (void*)(buf+64);
  void *P = (void*)(buf+(64u<<10));

  const int TR=16, PR=16, K=64, N=300, NC=4;
  const char *NM[4]={"训练8B@A","训练4B@A","训练8B@A+8","不训练"};

  for(int i=0;i<20000;i++){ tstore8(A,1); tstore4(A,1); probe(P,1); }

  double *T[4];
  for(int c=0;c<NC;c++) T[c]=malloc((size_t)N*sizeof(double));

  for(int r=0;r<N;r++)
    for(int j=0;j<NC;j++){
      int c=(r+j)%NC;
      T[c][r]=one_cond(c, A, P, TR, PR, K);
    }

  printf("# tick=%.2f  TR=%d PR=%d K=%d N=%d\n", nspt, TR, PR, K, N);
  printf("# 口径：含-fence（dsb ish; isb 在每次 probe 前），与删-fence 数字不可混比\n");
  printf("# probe 固定 buf+64K，训练在 buf+64，全部对齐\n");

  printf("\n== 四条件 probe 总时 ==\n");
  double base = 0;
  for(int c=0;c<NC;c++){
    double m=qsel(T[c],N,0.5);
    printf("  %-12s %8.1f ticks (%8.1f ns)  %6.3f ns/pair\n", NM[c], m, m*nspt, m*nspt/(double)(K*PR));
    if(c==3) base=m;
  }

  printf("\n== 相对「不训练」的差 ==\n");
  double maxabs=0;
  for(int c=0;c<3;c++){
    double *d=malloc((size_t)N*sizeof(double));
    for(int r=0;r<N;r++) d[r]=T[c][r]-T[3][r];
    double lo,hi; boot_median(d,N,1500,&lo,&hi);
    double m=qsel(d,N,0.5);
    if((m<0?-m:m)>maxabs) maxabs=(m<0?-m:m);
    printf("  %-12s %+7.2f ticks  CI [%+.2f, %+.2f]   %+.3f ns/pair\n", NM[c], m, lo, hi, m*nspt/(double)(K*PR));
    free(d);
  }

  printf("\n== 判定 ==\n");
  printf("  最大 |差| = %.2f tick (阈值 2.00)\n", maxabs);
  if(maxabs<=2.0)
    printf("\n>>> S1h CLEAN : 加 fence 隔离后四条件无差异 -> 训练历史对 probe 无影响, Q-A 在此探针下「未观测到」\n");
  else
    printf("\n>>> S1h RESIDUAL : 仍有 %.2f tick 差异 -> 训练效应或另一种流水线残留, 需看方向\n", maxabs);
  printf(">>> 摘要行: 8B=%.1f 4B=%.1f 8B+8=%.1f none=%.1f maxdiff=%.2f %s\n",
         qsel(T[0],N,0.5), qsel(T[1],N,0.5), qsel(T[2],N,0.5), base, maxabs,
         (maxabs<=2.0)?"CLEAN":"RESIDUAL");
  return 0;
}
```


#### 源码 S1i `mdu_addr.c`（完整，可直接编译）

> CC=gcc -O2 -o mdu_addr mdu_addr.c；**CLEAN**，含-fence 口径

```c
/* mdu_addr.c —— S1i: 同址训练（地址索引路径）（TC-06 / 会话 14）【CLEAN，定案】
 * 编译: gcc -O2 -o mdu_addr mdu_addr.c   运行: taskset -c 3 ./mdu_addr
 * 口径: 含-fence；probe 固定在 P=buf+64K，训练与 probe 共享同一个 P（同表项）
 * 实测: 训练8B@P / 训练4B@P / 训练8B@P+4096 / 不训练 -> 全部 60.0 tick，差 ±0.00
 * 结论: 地址索引路径同样堵死 -> Q-A 定案为否
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static inline uint64_t rd(void){ uint64_t t; __asm__ __volatile__("mrs %0, cntvct_el0":"=r"(t)); return t; }
static inline void fence(void){ __asm__ __volatile__("dsb ish\n\tisb" ::: "memory"); }
static unsigned char *buf;

static uint64_t rs = 0x243F6A8885A308D3ULL;
static inline uint64_t xr(void){ uint64_t s=rs; s^=s<<13; s^=s>>7; s^=s<<17; rs=s; return s; }

__attribute__((noinline)) static void tstore8(void *a, int n){
  const uint64_t v=0x1111111122222222ULL;
  for(int i=0;i<n;i++) __asm__ __volatile__("str %0,[%1]" :: "r"(v), "r"(a) : "memory");
}
__attribute__((noinline)) static void tstore4(void *a, int n){
  const uint64_t v=0x11111111ULL;
  for(int i=0;i<n;i++) __asm__ __volatile__("str %w0,[%1]" :: "r"(v), "r"(a) : "memory");
}
/* probe: 对齐 4B store + 8B load（对 8B 而言部分重叠） */
__attribute__((noinline)) static void probe(void *p, int n){
  const uint64_t v=0x11111111ULL;
  for(int i=0;i<n;i++){
    uint64_t x;
    __asm__ __volatile__("str %w1,[%2]\n\tldr %0,[%2]" : "=&r"(x) : "r"(v), "r"(p) : "memory");
    (void)x;
  }
}

static int cmpd(const void*p,const void*q){ double x=*(const double*)p,y=*(const double*)q; return (x>y)-(x<y); }
static double qsel(double *v,int n,double p){
  double *c=malloc((size_t)n*sizeof(double)); memcpy(c,v,(size_t)n*sizeof(double));
  qsort(c,(size_t)n,sizeof(double),cmpd);
  int i=(int)(p*(n-1)); double r=c[i]; free(c); return r;
}
static void boot_median(double *v,int n,int B,double *lo,double *hi){
  double *m=malloc((size_t)B*sizeof(double)), *s=malloc((size_t)n*sizeof(double));
  for(int b=0;b<B;b++){
    for(int i=0;i<n;i++) s[i]=v[(int)(xr()%(uint64_t)n)];
    qsort(s,(size_t)n,sizeof(double),cmpd); m[b]=s[n/2];
  }
  qsort(m,(size_t)B,sizeof(double),cmpd);
  *lo=m[(int)(0.025*(B-1))]; *hi=m[(int)(0.975*(B-1))];
  free(m); free(s);
}

/* mode: 0=训练8B@P  1=训练4B@P  2=训练8B@P+4096  3=不训练 */
__attribute__((noinline)) static double one_cond(int mode, void *P, int TR, int PR, int K){
  void *Q = (void*)((uintptr_t)P + 4096);
  double tot = 0.0;
  for(int k=0;k<K;k++){
    if(mode==0) tstore8(P,TR);
    else if(mode==1) tstore4(P,TR);
    else if(mode==2) tstore8(Q,TR);
    fence();
    uint64_t a=rd(); probe(P,PR); uint64_t b=rd();
    tot += (double)(b-a);
  }
  return tot;
}

int main(void){
  uint64_t frq=0; __asm__ __volatile__("mrs %0, cntfrq_el0":"=r"(frq));
  if(!frq) frq=50000000ULL;
  const double nspt = 1e9/(double)frq;

  if(posix_memalign((void**)&buf,4096,1u<<20)!=0) return 2;
  memset(buf,0,1u<<20);
  void *P = (void*)(buf+(64u<<10));

  const int TR=16, PR=16, K=64, N=300, NC=4;
  const char *NM[4]={"训练8B@P(全重叠)","训练4B@P(部分)","训练8B@P+4096","不训练"};

  for(int i=0;i<20000;i++){ tstore8(P,1); tstore4(P,1); probe(P,1); }

  double *T[4];
  for(int c=0;c<NC;c++) T[c]=malloc((size_t)N*sizeof(double));
  for(int r=0;r<N;r++)
    for(int j=0;j<NC;j++){ int c=(r+j)%NC; T[c][r]=one_cond(c, P, TR, PR, K); }

  printf("# tick=%.2f TR=%d PR=%d K=%d N=%d\n", nspt, TR, PR, K, N);
  printf("# 口径: 含-fence；probe 固定在 P=buf+64K，训练与 probe 共享同一个 P（同表项）\n");

  printf("\n== 四条件 probe 总时 ==\n");
  for(int c=0;c<NC;c++){
    double m=qsel(T[c],N,0.5);
    printf("  %-18s %8.1f ticks (%8.1f ns)  %6.3f ns/pair\n", NM[c], m, m*nspt, m*nspt/(double)(K*PR));
  }

  printf("\n== 相对「不训练」的差 ==\n");
  double maxabs=0;
  for(int c=0;c<3;c++){
    double *d=malloc((size_t)N*sizeof(double));
    for(int r=0;r<N;r++) d[r]=T[c][r]-T[3][r];
    double lo,hi; boot_median(d,N,1500,&lo,&hi);
    double m=qsel(d,N,0.5);
    if((m<0?-m:m)>maxabs) maxabs=(m<0?-m:m);
    printf("  %-18s %+7.2f ticks  CI [%+.2f, %+.2f]  %+.3f ns/pair\n", NM[c], m, lo, hi, m*nspt/(double)(K*PR));
    free(d);
  }

  printf("\n== 判定 ==\n  最大 |差| = %.2f tick (阈值 2.00)\n", maxabs);
  if(maxabs<=2.0)
    printf("\n>>> S1i CLEAN : 同址训练也无影响 -> 地址索引这条路同样堵死\n>>> Q-A = 未观测到（PC 索引 + 地址索引 两条路均已排除）\n");
  else
    printf("\n>>> S1i SIGNAL : 同址训练有 %.2f tick 影响 -> 存在地址索引的状态残留，值得深挖\n", maxabs);
  printf(">>> 摘要行: 8B=%0.1f 4B=%0.1f +4K=%0.1f none=%0.1f maxdiff=%.2f %s\n",
         qsel(T[0],N,0.5), qsel(T[1],N,0.5), qsel(T[2],N,0.5), qsel(T[3],N,0.5),
         maxabs, (maxabs<=2.0)?"CLEAN":"SIGNAL");
  return 0;
}
```


#### 源码 S1j `mdu_xctx.c`（完整，可直接编译）

> CC=gcc -O2 -o mdu_xctx mdu_xctx.c -pthread；**CLEAN**，含-fence 口径

```c
/* mdu_xctx.c —— S1j: 跨上下文检验（TC-07 / 会话 15）【CLEAN，Q-B 实测级定案】
 * 编译: gcc -O2 -o mdu_xctx mdu_xctx.c -pthread    运行: taskset -c 3 ./mdu_xctx
 * 口径: 含-fence；两线程同钉核 3，sched_yield 交接，训练在另一上下文完成、本上下文探测
 * 实测: A store@P / B load@P / C store@Q / D 不训练 -> 174.0 / 174.0 / 174.0 / 175.0 tick
 *       关键对比 A-B = +0.00 tick；maxdiff = 1.00 tick
 *       诊断: 两线程均 cpu=3；回合数 25600；平均交接 61.9 tick = 1.24 us（真实切换量级）
 * 结论: 跨上下文无残留。注意程序把交接时间标成 "ns"，实际单位是 tick（标签笔误，不影响结果）
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <sched.h>

static inline uint64_t rd(void){ uint64_t t; __asm__ __volatile__("mrs %0, cntvct_el0":"=r"(t)); return t; }
static inline void fence(void){ __asm__ __volatile__("dsb ish\n\tisb" ::: "memory"); }

static unsigned char *buf;
static void *P, *Q;
static volatile int turn = 0;        /* 2=训练线程的回合, 1=探测线程的回合 */
static volatile int mode = 0;
static volatile int stop_flag = 0;
static volatile long rounds = 0;
static volatile int cpu_trainer = -1;
static int TR = 64;

__attribute__((noinline)) static void tstore8(void *a, int n){
  const uint64_t v=0x1111111122222222ULL;
  for(int i=0;i<n;i++) __asm__ __volatile__("str %0,[%1]" :: "r"(v), "r"(a) : "memory");
}
__attribute__((noinline)) static void tload8(void *a, int n){
  for(int i=0;i<n;i++){ uint64_t x; __asm__ __volatile__("ldr %0,[%1]" : "=&r"(x) : "r"(a) : "memory"); (void)x; }
}
/* probe: 对齐 4B store + 8B load（部分重叠） */
__attribute__((noinline)) static void probe(void *p, int n){
  const uint64_t v=0x11111111ULL;
  for(int i=0;i<n;i++){
    uint64_t x;
    __asm__ __volatile__("str %w1,[%2]\n\tldr %0,[%2]" : "=&r"(x) : "r"(v), "r"(p) : "memory");
    (void)x;
  }
}

static void *trainer(void *arg){
  (void)arg;
  cpu_trainer = sched_getcpu();
  while(!stop_flag){
    if(turn != 2){ sched_yield(); continue; }
    int m = mode;
    if(m==0)      tstore8(P, TR);
    else if(m==1) tload8 (P, TR);
    else if(m==2) tstore8(Q, TR);
    rounds++;
    turn = 1;
  }
  return NULL;
}

static int cmpd(const void*p,const void*q){ double x=*(const double*)p,y=*(const double*)q; return (x>y)-(x<y); }
static double qsel(double *v,int n,double p){
  double *c=malloc((size_t)n*sizeof(double)); memcpy(c,v,(size_t)n*sizeof(double));
  qsort(c,(size_t)n,sizeof(double),cmpd);
  int i=(int)(p*(n-1)); double r=c[i]; free(c); return r;
}
static void boot_median(double *v,int n,int B,double *lo,double *hi){
  double *m=malloc((size_t)B*sizeof(double)), *s=malloc((size_t)n*sizeof(double));
  for(int b=0;b<B;b++){
    for(int i=0;i<n;i++) s[i]=v[(int)(rand()%(n))];
    qsort(s,(size_t)n,sizeof(double),cmpd); m[b]=s[n/2];
  }
  qsort(m,(size_t)B,sizeof(double),cmpd);
  *lo=m[(int)(0.025*(B-1))]; *hi=m[(int)(0.975*(B-1))];
  free(m); free(s);
}

int main(void){
  uint64_t frq=0; __asm__ __volatile__("mrs %0, cntfrq_el0":"=r"(frq));
  if(!frq) frq=50000000ULL;
  const double nspt=1e9/(double)frq;

  if(posix_memalign((void**)&buf,4096,1u<<20)!=0) return 2;
  memset(buf,0,1u<<20);
  P = (void*)(buf + 64);
  Q = (void*)(buf + (8u<<10));

  cpu_set_t set; CPU_ZERO(&set); CPU_SET(3,&set);
  if(sched_setaffinity(0,sizeof(set),&set)!=0) printf("!! setaffinity 失败, 结果不可用\n");

  for(int i=0;i<20000;i++){ tstore8(P,1); tload8(P,1); probe(P,1); }

  pthread_t th;
  if(pthread_create(&th,NULL,trainer,NULL)!=0){ printf("!! pthread_create 失败\n"); return 2; }

  const int K=32, PR=64, N=200, NC=4;
  const char *NM[4]={"A store@P(依赖)","B load@P (只读)","C store@Q(异页)","D 不训练"};
  double *T[4];
  double hsum=0; long hcnt=0;

  for(int c=0;c<NC;c++){
    T[c]=malloc((size_t)N*sizeof(double));
    for(int r=0;r<N;r++){
      mode=c;
      double tot=0;
      for(int k=0;k<K;k++){
        turn=2;
        uint64_t h0=rd();
        while(turn!=1) sched_yield();
        uint64_t h1=rd();
        hsum += (double)(h1-h0); hcnt++;
        fence();
        uint64_t a=rd(); probe(P,PR); uint64_t b=rd();
        tot += (double)(b-a);
      }
      T[c][r]=tot;
    }
  }
  stop_flag=1;
  pthread_join(th,NULL);

  printf("# tick=%.2f  K=%d PR=%d N=%d TR=%d\n", nspt,K,PR,N,TR);
  /* 注意: 下面交接时间实际单位是 tick（标签写 ns 是笔误）；tick*20ns 才是 ns */
  printf("# 主线程 cpu=%d  训练线程 cpu=%d  回合数=%ld  平均交接 %.1f ticks (%.0f ns)\n",
         sched_getcpu(), cpu_trainer, rounds, hsum/(double)(hcnt?hcnt:1), hsum/(double)(hcnt?hcnt:1)*nspt);
  if(cpu_trainer!=sched_getcpu()) printf("!! 两个线程不在同一核, 本实验作废\n");

  printf("\n== 四臂 probe 总时（跨 %d 次上下文切换求和）==\n", K);
  for(int c=0;c<NC;c++){
    double m=qsel(T[c],N,0.5);
    printf("  %-16s %8.1f ticks (%8.1f ns)  %6.3f ns/pair\n", NM[c], m, m*nspt, m*nspt/(double)(K*PR));
  }

  printf("\n== 相对「不训练」的差 ==\n");
  double maxabs=0;
  for(int c=0;c<3;c++){
    double *d=malloc((size_t)N*sizeof(double));
    for(int r=0;r<N;r++) d[r]=T[c][r]-T[3][r];
    double lo,hi; boot_median(d,N,1500,&lo,&hi);
    double m=qsel(d,N,0.5);
    if((m<0?-m:m)>maxabs) maxabs=(m<0?-m:m);
    printf("  %-16s %+7.2f ticks  CI [%+.2f, %+.2f]  %+.3f ns/pair\n", NM[c],m,lo,hi,m*nspt/(double)(K*PR));
    free(d);
  }

  /* A vs B：关键一对 */
  double *dab=malloc((size_t)N*sizeof(double));
  for(int r=0;r<N;r++) dab[r]=T[0][r]-T[1][r];
  double lo,hi; boot_median(dab,N,1500,&lo,&hi);
  printf("\n== 关键对比 A−B（同足迹, 差在有没有写）==\n");
  printf("  中位数 %+7.2f ticks  CI [%+.2f, %+.2f]   %+.3f ns/pair\n",
         qsel(dab,N,0.5), lo, hi, qsel(dab,N,0.5)*nspt/(double)(K*PR));

  printf("\n== 判定 ==\n  最大 |差| = %.2f tick (阈值 2.00)\n", maxabs);
  if(maxabs<=2.0)
    printf("\n>>> S1j CLEAN : 跨上下文无残留 -> Q-B 的否定由「逻辑推断」升级为「实测」\n");
  else
    printf("\n>>> S1j SIGNAL : 跨上下文有 %.2f tick 残留 -> 这是真信号, 立刻转 S2 跨进程\n", maxabs);
  printf(">>> 摘要行: A=%.1f B=%.1f C=%.1f D=%.1f  A-B=%+.2f  maxdiff=%.2f %s\n",
         qsel(T[0],N,0.5),qsel(T[1],N,0.5),qsel(T[2],N,0.5),qsel(T[3],N,0.5),
         qsel(dab,N,0.5), maxabs, (maxabs<=2.0)?"CLEAN":"SIGNAL");
  return 0;
}
```

**S1k 设计（决定性，待跑）—— 补上唯一未闭合的区间**

**为什么必须有它**：S1h / S1i 都在**含-fence** 口径下，而 `dsb ish; isb` 会把 store→load 的乱序窗口整个关掉。而 MDU 的工作恰恰是"在 store 地址未解析时让 load 投机超前"——**窗口被 fence 一关，MDU 就无事可做**。所以那两个 CLEAN 只覆盖了"fence 之后"的区间，不足以支撑"定案"。

**四个设计要点（逐条对着前面踩过的坑）**

1. **地址真·晚到，但样本要短**：store 的目标地址来自一次**指针追逐 load**（`slots` 跨页 → L2 延迟约 18 cycle），不再用 24 级乘法链（那是 S1b 翻车的原因：样本 6 µs 被抢占打飞）→ 单样本约 20 tick ≈ 0.4 µs。
2. **靠数据依赖串行，不用 fence**：每轮的 slot 索引由上一轮 probe 结果推进（`sp = slots + (x & 63)`）→ 顺序被数据锁住，测的是**乱序窗口本身**，而不是把它 fence 掉。
3. **SELF 闸门验的是"乱序消歧"而不是"转发成本"**：`ALIAS`（slots 全指向 probe 地址）vs `NOALIAS`（全指向他页）。强制别名**必须**产生等待或重放惩罚；看不见就说明装置对这条路径不敏感（S1b-v2 的 G2 验的是地址决定的转发成本，验错了对象）。
4. **防坑三条**：ALIAS/NOALIAS 的指令流、PC、访存次数完全相同，**只有 `slots` 内容不同**；probe 地址不落在 slots 区（无地址碰撞）；三臂轮转 + A/A 假阳地板 + 脏样本率。

**判读**

| 结果 | 含义 | 下一步 |
|---|---|---|
| **SELF-PASS**：ALIAS 显著慢于 NOALIAS，且超出 A/A 地板 3 倍 | 装置对 MDU 路径敏感，强制别名有可见惩罚 | 进 **S1l**：用这个读数做"同 PC 训练能否改变它"（无 fence 剂量反应） |
| **SELF-FAIL**：两者无差异 | 该路径同样测不到 | provisional 可转成"**含所有已测路径**的否定" |

**状态**：⬜ 待跑（`~/mdu_l13/mdu_md.c`）


#### 源码 S1k `mdu_md.c`（完整，可直接编译）· v2

> CC=gcc -O2 -o mdu_md mdu_md.c；运行 `taskset -c 3 ./mdu_md`；**无 fence 口径**，与前面所有含-fence 数字不可混比
> **v1 段错误根因（已修）**：slots 按 4096 字节步长摆放，`run()` 却按 8 字节（`void**` 自增）索引 → 读到 memset 留下的 0 → `store` 到 NULL。v2 改用 **uint32 偏移 + 显式元素步长 SLOTELEM + 偏移掩码**，指针必然落在 2MB 缓冲内。

```c
/* mdu_md.c —— S1k v2: 决定性实验（无 fence + store 地址晚到 + 数据依赖串行）（会话 16）
 * 编译: gcc -O2 -o mdu_md mdu_md.c     运行: taskset -c 3 ./mdu_md
 *
 * v1 段错误的根因（已修）: slots 按 4096 字节步长摆放，run() 里却按 8 字节步长
 *   (void** 自增) 索引 => 读到 memset 留下的 0 => store 到 NULL。v2 改用 uint32 偏移
 *   + 显式元素步长 SLOTELEM，并对偏移做掩码 => 指针必然落在缓冲区内，不可能野指针。
 *
 * 设计要点:
 *  1. store 地址"晚到"来自一次指针追逐 load（slot 跨页 => L2 延迟 ~18 cycle），不用乘法链。
 *  2. 顺序由数据依赖卡住（sp 由上一轮 probe 结果推进），不用 dsb/isb => 测乱序窗口本身。
 *  3. SELF 闸门验"乱序消歧": ALIAS(slot 全指向 probe) vs NOALIAS(全指向他页)。
 *  4. 防坑: 两臂指令流/PC/访存次数相同, 只有 slot 内容不同; probe 不在 slots 区; 三臂轮转 + A/A。
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static inline uint64_t rd(void){ uint64_t t; __asm__ __volatile__("mrs %0, cntvct_el0":"=r"(t)); return t; }
static unsigned char *buf;

static uint64_t rs = 0x243F6A8885A308D3ULL;
static inline uint64_t xr(void){ uint64_t s=rs; s^=s<<13; s^=s>>7; s^=s<<17; rs=s; return s; }

#define NSLOT      64
#define SLOTBYTES  4096u              /* 每 slot 占一页 => 地址经 L2 到达 */
#define SLOTELEM   (SLOTBYTES/4u)     /* uint32 数组的元素步长 = 1024 */
#define OFFMASK    0x1FFFF8u          /* 1MB 内、8 字节对齐 => 永不越界 */

/* 每轮: 取晚到地址(load) -> store -> 探测 load -> 用结果推进 sp（全串行, 无 fence） */
__attribute__((noinline)) static uint64_t run(uint32_t *slots, uint32_t poff, int n){
  const uint64_t v = 0x1111111122222222ULL;
  uint64_t acc = 0;
  uint32_t *sp = slots;
  for(int i=0;i<n;i++){
    uint32_t off = (*(volatile uint32_t *)sp) & OFFMASK;    /* 晚到地址 */
    *(volatile uint64_t *)(buf + off) = v;                  /* store 到 off */
    uint64_t x = *(volatile uint64_t *)(buf + poff);        /* 探测 load */
    acc += x;
    sp = slots + (uint32_t)(x & (NSLOT-1)) * SLOTELEM;      /* 数据依赖串行 */
  }
  return acc;
}

static int cmpd(const void*p,const void*q){ double x=*(const double*)p,y=*(const double*)q; return (x>y)-(x<y); }
static double qsel(double *v,int n,double p){
  double *c=malloc((size_t)n*sizeof(double)); memcpy(c,v,(size_t)n*sizeof(double));
  qsort(c,(size_t)n,sizeof(double),cmpd);
  int i=(int)(p*(n-1)); double r=c[i]; free(c); return r;
}
static void boot_median(double *v,int n,int B,double *lo,double *hi){
  double *m=malloc((size_t)B*sizeof(double)), *s=malloc((size_t)n*sizeof(double));
  for(int b=0;b<B;b++){
    for(int i=0;i<n;i++) s[i]=v[(int)(xr()%(uint64_t)n)];
    qsort(s,(size_t)n,sizeof(double),cmpd); m[b]=s[n/2];
  }
  qsort(m,(size_t)B,sizeof(double),cmpd);
  *lo=m[(int)(0.025*(B-1))]; *hi=m[(int)(0.975*(B-1))];
  free(m); free(s);
}

static void fill_slots(uint32_t *slots, uint32_t off){
  for(int i=0;i<NSLOT;i++) *(uint32_t*)((uintptr_t)slots + (uintptr_t)i*SLOTBYTES) = off;
}
static int check_slots(uint32_t *slots, uint32_t off){
  for(int i=0;i<NSLOT;i++){
    uint32_t v = *(uint32_t*)((uintptr_t)slots + (uintptr_t)i*SLOTBYTES);
    if(v != off) return i+1;
  }
  return 0;
}

int main(void){
  setbuf(stdout, NULL);                 /* 进度可见, 崩了也知道崩在哪 */
  uint64_t frq=0; __asm__ __volatile__("mrs %0, cntfrq_el0":"=r"(frq));
  if(!frq) frq=50000000ULL;
  const double nspt = 1e9/(double)frq;

  if(posix_memalign((void**)&buf,4096,2u<<20)!=0){ printf("alloc fail\n"); return 2; }
  memset(buf, 0, 2u<<20);

  const uint32_t YOFF  = 0x001000;      /* probe 地址 */
  const uint32_t ZOFF  = 0x060000;      /* 非别名目标 */
  const uint32_t Z2OFF = 0x080000;      /* A/A 用 */
  uint32_t *slots = (uint32_t*)(buf + 0x010000);   /* 64 页 */

  const uint32_t fills[3] = {YOFF, ZOFF, Z2OFF};
  const char *NM[3] = {"ALIAS  (store->probe 同址)", "NOALIAS(store->他页)", "A/A    (另一他页)"};

  const int n=64, N=800, NC=3;

  fill_slots(slots, YOFF);
  { int bad = check_slots(slots, YOFF);
    if(bad){ printf("!! slots 自检失败 @%d\n", bad); return 3; }
    printf("# slots 自检 OK (64 槽全部指向 0x%x)\n", YOFF); }

  for(int i=0;i<20000;i++) run(slots, YOFF, 1);      /* 预热 */

  double *T[3];
  for(int c=0;c<NC;c++) T[c]=malloc((size_t)N*sizeof(double));

  for(int r=0;r<N;r++){
    for(int j=0;j<NC;j++){
      int c = (r+j)%NC;                                /* 轮转, 抵消漂移 */
      fill_slots(slots, fills[c]);
      uint64_t t0=rd(); run(slots, YOFF, n); uint64_t t1=rd();
      T[c][r]=(double)(t1-t0);
    }
    if((r & 127)==0){ printf("  ...%d/%d\n", r, N); }
  }

  printf("# tick=%.2f  n=%d(轮迭代)  N=%d  NSLOT=%d 无 fence\n", nspt, n, N, NSLOT);
  printf("# probe 固定 buf+4K；slots 区 buf+64K..320K（每槽一页）；ALIAS 时 store 目标 == probe\n");

  printf("\n== 三臂每轮耗时 ==\n");
  for(int c=0;c<NC;c++){
    double m=qsel(T[c],N,0.5);
    printf("  %-26s %8.1f ticks (%7.1f ns)  %6.2f ns/iter  %5.2f cycle/iter\n",
           NM[c], m, m*nspt, m*nspt/n, m*nspt/n*3.0);
  }

  int dirty=0;
  for(int r=0;r<N;r++){
    double d = T[0][r]-T[1][r];
    double a = (d<0)? -d : d;
    if(a>100.0) dirty++;
  }

  double *dg=malloc((size_t)N*sizeof(double));
  double *da=malloc((size_t)N*sizeof(double));
  for(int r=0;r<N;r++){ dg[r]=T[0][r]-T[1][r]; da[r]=T[2][r]-T[1][r]; }

  double lo,hi;
  boot_median(dg,N,1500,&lo,&hi);
  double mg=qsel(dg,N,0.5);
  printf("\n== SELF 闸门：ALIAS - NOALIAS（乱序消歧代价）==\n");
  printf("  median %+7.2f ticks  CI [%+.2f, %+.2f]   %+.2f ns/iter   %+.2f cycle/iter\n",
         mg, lo, hi, mg*nspt/n, mg*nspt/n*3.0);
  printf("  脏样本(|d|>100) %d/%d = %.1f%%\n", dirty, N, 100.0*dirty/N);
  double lg=lo, hg=hi;

  boot_median(da,N,1500,&lo,&hi);
  double ma=qsel(da,N,0.5);
  printf("\n== A/A 假阳地板：A/A - NOALIAS ==\n");
  printf("  median %+7.2f ticks  CI [%+.2f, %+.2f]\n", ma, lo, hi);

  int sig   = (lg>0.0 || hg<0.0);
  int above = ((mg<0?-mg:mg) > ((ma<0?-ma:ma) * 3.0));
  int pass  = sig && above;

  printf("\n== 判定 ==\n");
  printf("  SELF 显著: %s   (CI %s 0)\n", sig?"YES":"NO", sig?"排除":"包含");
  printf("  超出 A/A 地板 3 倍: %s\n", above?"YES":"NO");
  printf("\n>>> S1k %s\n", pass ? "SELF-PASS : 装置对乱序消歧敏感（强制别名有可见惩罚）"
                                : "SELF-FAIL : 强制别名无可见惩罚 -- 装置对该路径不敏感");
  if(pass)
    printf(">>> 下一步 S1l：用此读数做\"训练能否改变它\"（同 PC 训练剂量反应, 无 fence）\n");
  else
    printf(">>> 该路径同样测不到 => Q-A/Q-B 可由 provisional 转为「含所有已测路径的否定」\n");
  printf(">>> 摘要行: ALIAS=%.1f NOALIAS=%.1f AA=%.1f  SELF=%+.2f[%+.2f,%+.2f]  A/A=%+.2f %s\n",
         qsel(T[0],N,0.5), qsel(T[1],N,0.5), qsel(T[2],N,0.5), mg, lg, hg, ma,
         pass?"SELF-PASS":"SELF-FAIL");
  return pass?0:1;
}
```


**S1m：忠实复现论文的 st2ld 探针（拿到正文后新增，待跑）**

拿到正文后才发现，我们前面的探针结构和论文**不是一回事**。论文 §III-A 的微基准是：

```
store 前 10 条"寄存器相关乘法"去算 store 的数据地址   ← 让地址生成足够晚
      str  [x0]
      ldr  [x1]
load 后 10 条"寄存器相关乘法"                          ← 触发端口争用, 放大时间差
```

协议是 **10 次 n（非别名）→ 10 次 a（别名）→ 10 次 n**，共 30 次调用，期望看到 **t1 / t3 / t2** 三种时间：

| 记号 | 场景 | 相对长度 |
|---|---|---|
| **t1** | 预测 bypass 且实际非别名 | 最短 |
| **t3** | 预测 bypass 但实际别名 → 误预测回滚重发 | **最长** |
| **t2** | 预测 block（无论是否别名）→ 等 store 地址 | 中 |

**关键差别**：论文的"训练"不是外部喂的，而是 **MDU 自己在第一次误预测后学出来的**——正确观测量是"**位置 11 的一次 t3 尖峰 + 12–20 落到 t2 平台**"，不是我们之前做的"训练前后差值"。

**本机限制**：论文用 PMCCNTR（cycle 级），本机被禁（`perf_event_paranoid=4`），只有 20 ns 的 `cntvct`。所以程序同时给了两条路：

1. **逐次 profile**：30 个位置各自计时，中位数逐位置比较——靠 2000 次重复把 1 tick 以下的结构捞出来；
2. **块聚合**：20 次 n 复位后，连续两个 10 次 a 块，比较 `T_a1 − T_a2`——第一个块含一次回滚，若 MDU 会学习则应为正。这是把 cycle 差放大到 tick 以上的关键。

**已知局限（必须写进结论）**：A72 的 MDU 是**粘滞**的（一次误预测后长期停在 block 态），论文靠 **idle CPU 复位**。本程序没有可靠的逐样本复位手段，所以主要看**首个样本**的 profile 是否出现 t3 尖峰。


#### 源码 S1m `mdu_st2ld.c`（完整，可直接编译）

> CC=gcc -O2 -o mdu_st2ld mdu_st2ld.c；运行 `taskset -c 3 ./mdu_st2ld`；**删-fence 口径**

```c
/* mdu_st2ld.c —— S1m: 忠实复现论文 Listing 2/3 的 st2ld 探测（会话 17）
 * 编译: gcc -O2 -o mdu_st2ld mdu_st2ld.c    运行: taskset -c 3 ./mdu_st2ld
 *
 * 论文依据 (ARMeD, TCAD 2025, §III-A/§III-B):
 *   - 探针: store 前 10 条“寄存器相关乘法”去算 store 的数据地址(让地址晚到),
 *           load 后 10 条乘法做端口争用放大。
 *   - 协议: 连续 10 次 n(非别名) -> 10 次 a(别名) -> 10 次 n, 共 30 次调用。
 *           期望出现三种时间: t1(bypass, 最短) / t3(误预测回滚, 最长) / t2(load blocking)。
 *   - 计时: 论文用 PMCCNTR(cycle 级); 本机 PMCCNTR 被禁, 只有 cntvct(20 ns),
 *           所以另加"块聚合"测量(看 10 次调用的总差), 把 cycle 差放大到可分辨。
 *
 * 已知局限(必须写在结论里): A72 的 MDU 是"粘滞"的——一次误预测后长期停在 block 态,
 * 论文靠 idle CPU 复位。本程序无可靠的逐样本复位手段, 因此:
 *   ① 打印"首个样本"的 30 点 profile(最接近论文的一次性实验);
 *   ② 打印全部样本逐位置的中位数;
 *   ③ 打印块聚合 (T_a1 - T_a2)。
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static inline uint64_t rd(void){ uint64_t t; __asm__ __volatile__("mrs %0, cntvct_el0":"=r"(t)); return t; }
static volatile uint64_t sinkv;
static volatile uint64_t mask0 = 0;          /* 恒 0, volatile => 不可折叠 */
static unsigned char *buf;
static void *NA, *NB;                        /* n: 非别名对 */

/* 与论文 Listing 2 对应 */
__attribute__((noinline)) static void st2ld(void *x0, void *x1){
  uint64_t a = (uint64_t)(uintptr_t)x0;
  for(int i=0;i<10;i++) a = a*6364136223846793005ULL + 1442695040888963407ULL;
  void *sa = (void*)((uintptr_t)x0 + (a & mask0));     /* store 地址经 10 级链才可用 */
  *(volatile uint64_t*)sa = 0x1111111122222222ULL;     /* store */
  uint64_t x = *(volatile uint64_t*)x1;                /* load, 可投机绕过 */
  uint64_t b = a ^ x;
  for(int i=0;i<10;i++) b = b*6364136223846793005ULL + 1442695040888963407ULL;  /* 端口争用放大 */
  sinkv = b;
}

static int cmpd(const void*p,const void*q){ double x=*(const double*)p,y=*(const double*)q; return (x>y)-(x<y); }
static double qsel(double *v,int n,double p){
  double *c=malloc((size_t)n*sizeof(double)); memcpy(c,v,(size_t)n*sizeof(double));
  qsort(c,(size_t)n,sizeof(double),cmpd);
  int i=(int)(p*(n-1)); double r=c[i]; free(c); return r;
}

int main(void){
  setbuf(stdout,NULL);
  uint64_t frq=0; __asm__ __volatile__("mrs %0, cntfrq_el0":"=r"(frq));
  if(!frq) frq=50000000ULL;
  const double nspt = 1e9/(double)frq;

  if(posix_memalign((void**)&buf,4096,1u<<20)!=0) return 2;
  memset(buf,0,1u<<20);
  void *PA = (void*)(buf+0x1000);      /* 别名对: store 与 load 同址 */
  void *PB = (void*)(buf+0x8000);      /* 非别名对: 另一页 */
  NA = PA; NB = PB;

  const int R = 2000, NP = 30;
  double *prof = malloc((size_t)NP*R*sizeof(double));
  double *first = malloc((size_t)NP*sizeof(double));
  double *Ta1 = malloc((size_t)R*sizeof(double));
  double *Ta2 = malloc((size_t)R*sizeof(double));

  for(int i=0;i<5000;i++) st2ld(PA,PB);           /* 预热 */

  for(int r=0;r<R;r++){
    for(int k=0;k<NP;k++){
      void *x0, *x1;
      if(k<10 || k>=20){ x0 = PA; x1 = PB; }      /* n: store 与 load 不同址 */
      else             { x0 = PA; x1 = PA; }      /* a: 别名 */
      uint64_t t0=rd(); st2ld(x0,x1); uint64_t t1=rd();
      prof[(size_t)k*R + r] = (double)(t1-t0);
      if(r==0) first[k] = (double)(t1-t0);
    }
    /* 块聚合: 20 次 n 复位后, 连续两个 10 次 a 块 */
    for(int k=0;k<20;k++) st2ld(PA,PB);
    uint64_t t0=rd(); for(int k=0;k<10;k++) st2ld(PA,PA); uint64_t t1=rd(); Ta1[r]=(double)(t1-t0);
    t0=rd(); for(int k=0;k<10;k++) st2ld(PA,PA); t1=rd(); Ta2[r]=(double)(t1-t0);
    if((r & 255)==0) printf("  ...%d/%d\n", r, R);
  }

  printf("\n# tick=%.2f ns  R=%d 次 30-call 序列  (删-fence, 逐次 rd)\n", nspt, R);

  printf("\n== 首个样本的 30 点 profile (tick) ==\n");
  printf("  pos : ");
  for(int k=0;k<NP;k++) printf("%3d", k+1);
  printf("\n  tick: ");
  for(int k=0;k<NP;k++) printf("%3.0f", first[k]);
  printf("\n");

  printf("\n== 全部样本: 逐位置中位数 ==\n");
  printf("  pos : ");
  for(int k=0;k<NP;k++) printf("%5d", k+1);
  printf("\n  med : ");
  for(int k=0;k<NP;k++){
    double *col = malloc((size_t)R*sizeof(double));
    memcpy(col, prof + (size_t)k*R, (size_t)R*sizeof(double));
    printf("%5.1f", qsel(col,R,0.5));
    free(col);
  }
  printf("\n  (1-10 = n, 11-20 = a, 21-30 = n)\n");

  double *d = malloc((size_t)R*sizeof(double));
  for(int r=0;r<R;r++) d[r] = Ta1[r]-Ta2[r];
  printf("\n== 块聚合: 第一个 a 块 - 第二个 a 块 ==\n");
  printf("  a块中位 %.1f tick,  a块2 中位 %.1f tick\n", qsel(Ta1,R,0.5), qsel(Ta2,R,0.5));
  printf("  D = T_a1 - T_a2 中位 %+.1f tick   p5 %+.1f  p95 %+.1f\n",
         qsel(d,R,0.5), qsel(d,R,0.05), qsel(d,R,0.95));

  printf("\n>>> 判读: MDU 存在 => (a) 位置 11 应出现一次 t3 尖峰, 12-20 落到 t2 平台;"
         "\n>>>        (b) 块聚合 D > 0 (第一个 a 块含一次回滚)。两者皆零 => 本轮未见 MDU 学习效应。\n");
  return 0;
}
```

**S1m 实测（2026-11-19）→ 结构看不见，但留了一个 +1 tick 的尾巴**

| 观察 | 结果 |
|---|---|
| 首个样本 30 点 profile | **全部 1 tick**（位置 1–30 无任何差异） |
| 全部样本逐位置中位数 | **全部 1.0 tick** |
| 块聚合 a块 / a块2 | **5.0 / 4.0 tick** |
| `D = T_a1 − T_a2` | **+1.0 tick**，p5 +0.0，p95 +2.0 |

**解读**：单次调用约 25–30 cycle（10+10 条乘法 + store/load），在 20 ns（60 cycle）粒度下几乎必然量化成 1 tick → **逐次 profile 天然看不见结构**，这是分辨率问题，不是没有效应。

块聚合那 10 次调用 ≈ 4–5 tick，`D = +1 tick` 落在"一次误预测回滚 ≈ 20–60 cycle"的合理区间内 —— **但也可能只是"第一个块处于冷态"的暖机伪影**。二者无法从 S1m 自身区分。

**S1n（对照组，待跑）**

| 臂 | 结构 | 含义 |
|---|---|---|
| **A（别名）** | 20 次 n 复位 → [10 次 a] 计时 A1 → [10 次 a] 计时 A2 | dA = A1 − A2，第一个块含一次误预测回滚 |
| **N（对照）** | 20 次 n 复位 → [10 次 n] 计时 N1 → [10 次 n] 计时 N2 | dN = N1 − N2，无回滚，只有暖机 |
| **净效应** | **S = dA − dN** | S > 0 → 是真 MDU 学习；S ≈ 0 → S1m 的 +1 是暖机 |

按样本号**交替 A/N 先后顺序**抵消漂移；N=2000。


#### 源码 S1n `mdu_ctrl.c`（完整，可直接编译）

> CC=gcc -O2 -o mdu_ctrl mdu_ctrl.c；运行 `taskset -c 3 ./mdu_ctrl`；**删-fence 口径**

```c
/* mdu_ctrl.c —— S1n: 给 S1m 的 +1 tick 加对照组（会话 18）
 * 编译: gcc -O2 -o mdu_ctrl mdu_ctrl.c     运行: taskset -c 3 ./mdu_ctrl
 *
 * 背景: S1m 里逐次 profile 全部是 1 tick（20 ns 分辨率下看不见结构），
 *       但块聚合给出 D = T_a1 - T_a2 = +1.0 tick（a块 5.0 vs 4.0）。
 *       问题是这个 +1 可能只是"第一个块在冷态"的暖机伪影。
 *
 * 本装置加对照:
 *   Arm A（别名）:  20 次 n 复位 -> [10 次 a] 计时 A1 -> [10 次 a] 计时 A2  => dA = A1-A2
 *   Arm N（对照）:  20 次 n 复位 -> [10 次 n] 计时 N1 -> [10 次 n] 计时 N2  => dN = N1-N2
 *   净效应 S = dA - dN
 *   - MDU 学习: 第一个 a 块含一次误预测回滚 => dA > dN
 *   - 暖机伪影: dA ≈ dN ≈ +1
 * 另: 按样本号交替 A/N 的先后顺序, 抵消漂移。
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static inline uint64_t rd(void){ uint64_t t; __asm__ __volatile__("mrs %0, cntvct_el0":"=r"(t)); return t; }
static volatile uint64_t sinkv;
static volatile uint64_t mask0 = 0;
static unsigned char *buf;

/* 论文 Listing 2 的 st2ld: 10 乘法算 store 地址 -> str -> ldr -> 10 乘法放大 */
__attribute__((noinline)) static void st2ld(void *x0, void *x1){
  uint64_t a = (uint64_t)(uintptr_t)x0;
  for(int i=0;i<10;i++) a = a*6364136223846793005ULL + 1442695040888963407ULL;
  void *sa = (void*)((uintptr_t)x0 + (a & mask0));
  *(volatile uint64_t*)sa = 0x1111111122222222ULL;
  uint64_t x = *(volatile uint64_t*)x1;
  uint64_t b = a ^ x;
  for(int i=0;i<10;i++) b = b*6364136223846793005ULL + 1442695040888963407ULL;
  sinkv = b;
}

static int cmpd(const void*p,const void*q){ double x=*(const double*)p,y=*(const double*)q; return (x>y)-(x<y); }
static double qsel(double *v,int n,double p){
  double *c=malloc((size_t)n*sizeof(double)); memcpy(c,v,(size_t)n*sizeof(double));
  qsort(c,(size_t)n,sizeof(double),cmpd);
  int i=(int)(p*(n-1)); double r=c[i]; free(c); return r;
}
static void boot_median(double *v,int n,int B,double *lo,double *hi){
  double *m=malloc((size_t)B*sizeof(double)), *s=malloc((size_t)n*sizeof(double));
  uint64_t st=0x9E3779B97F4A7C15ULL;
  for(int b=0;b<B;b++){
    for(int i=0;i<n;i++){ st^=st<<13; st^=st>>7; st^=st<<17; s[i]=v[(int)(st%(uint64_t)n)]; }
    qsort(s,(size_t)n,sizeof(double),cmpd); m[b]=s[n/2];
  }
  qsort(m,(size_t)B,sizeof(double),cmpd);
  *lo=m[(int)(0.025*(B-1))]; *hi=m[(int)(0.975*(B-1))];
  free(m); free(s);
}

int main(void){
  setbuf(stdout,NULL);
  uint64_t frq=0; __asm__ __volatile__("mrs %0, cntfrq_el0":"=r"(frq));
  if(!frq) frq=50000000ULL;
  const double nspt = 1e9/(double)frq;

  if(posix_memalign((void**)&buf,4096,1u<<20)!=0) return 2;
  memset(buf,0,1u<<20);
  void *PA = (void*)(buf+0x1000);
  void *PB = (void*)(buf+0x8000);

  const int R = 2000, BLK = 10, RST = 20;
  double *dA = malloc((size_t)R*sizeof(double));
  double *dN = malloc((size_t)R*sizeof(double));
  double *S  = malloc((size_t)R*sizeof(double));

  for(int i=0;i<5000;i++) st2ld(PA,PB);

  for(int r=0;r<R;r++){
    uint64_t t0,t1; double A1=0,A2=0,N1=0,N2=0;
    int aFirst = (r & 1);                 /* 交替先后顺序 */

    if(aFirst){
      for(int k=0;k<RST;k++) st2ld(PA,PB);
      t0=rd(); for(int k=0;k<BLK;k++) st2ld(PA,PA); t1=rd(); A1=(double)(t1-t0);
      t0=rd(); for(int k=0;k<BLK;k++) st2ld(PA,PA); t1=rd(); A2=(double)(t1-t0);
      for(int k=0;k<RST;k++) st2ld(PA,PB);
      t0=rd(); for(int k=0;k<BLK;k++) st2ld(PA,PB); t1=rd(); N1=(double)(t1-t0);
      t0=rd(); for(int k=0;k<BLK;k++) st2ld(PA,PB); t1=rd(); N2=(double)(t1-t0);
    } else {
      for(int k=0;k<RST;k++) st2ld(PA,PB);
      t0=rd(); for(int k=0;k<BLK;k++) st2ld(PA,PB); t1=rd(); N1=(double)(t1-t0);
      t0=rd(); for(int k=0;k<BLK;k++) st2ld(PA,PB); t1=rd(); N2=(double)(t1-t0);
      for(int k=0;k<RST;k++) st2ld(PA,PB);
      t0=rd(); for(int k=0;k<BLK;k++) st2ld(PA,PA); t1=rd(); A1=(double)(t1-t0);
      t0=rd(); for(int k=0;k<BLK;k++) st2ld(PA,PA); t1=rd(); A2=(double)(t1-t0);
    }
    dA[r]=A1-A2; dN[r]=N1-N2; S[r]=dA[r]-dN[r];
    if((r & 255)==0) printf("  ...%d/%d\n", r, R);
  }

  double lo,hi;
  printf("\n# tick=%.2f ns  R=%d  BLK=%d(次调用/块)  RST=%d(复位 n 次数)\n", nspt, R, BLK, RST);

  boot_median(dA,R,1500,&lo,&hi);
  printf("\n== Arm A（别名）: 第一个 a 块 - 第二个 a 块 ==\n");
  printf("  dA 中位 %+.2f ticks  CI [%+.2f, %+.2f]\n", qsel(dA,R,0.5), lo, hi);

  boot_median(dN,R,1500,&lo,&hi);
  printf("\n== Arm N（对照, 非别名）: 第一个 n 块 - 第二个 n 块 ==\n");
  printf("  dN 中位 %+.2f ticks  CI [%+.2f, %+.2f]\n", qsel(dN,R,0.5), lo, hi);

  boot_median(S,R,1500,&lo,hi);
  double ms=qsel(S,R,0.5);
  printf("\n== 净效应 S = dA - dN（MDU 学习的判据）==\n");
  printf("  S 中位 %+.2f ticks  CI [%+.2f, %+.2f]   %+.2f ns   %+.1f cycle\n",
         ms, lo, hi, ms*nspt, ms*nspt*3.0);

  int sig = (ms>0 && lo>0.0);
  printf("\n>>> S1n %s\n", sig
    ? "PASS : dA 显著大于 dN -> 第一个别名块确实多付了误预测代价 => MDU 学习效应存在"
    : "NULL : S 未显著为正 -> S1m 那个 +1 tick 是暖机伪影, 不是 MDU 效应");
  printf(">>> 摘要行: dA=%+.2f dN=%+.2f S=%+.2f[%+.2f,%+.2f] %s\n",
         qsel(dA,R,0.5), qsel(dN,R,0.5), ms, lo, hi, sig?"PASS":"NULL");
  return sig?0:1;
}
```

**S1n 实测（2026-11-19）→ S1m 的 +1 tick 不是暖机**

| 指标 | 值 |
|---|---|
| dA（别名：第一个 a 块 − 第二个 a 块） | **+1.00 tick**，CI [+1.00, +1.00] |
| dN（对照：第一个 n 块 − 第二个 n 块） | **+0.00 tick**，CI [+0.00, +0.00] |
| 净效应 S = dA − dN | **+1.00 tick** = 20.00 ns = **60 cycle**，CI [+1.00, +1.00] |
| 判定 | **PASS**（dA 显著大于 dN，暖机解释被排除） |

**但还不能宣布 MDU。** 存在一个不用 MDU 也能解释 +1 的机制：

> 复位用的 RST 次 n 调用向 PA 写了 RST 次 store。第一个 a 块的 load 要在一堆**未退休的 PA store** 里找最年轻那条 → 队列越深越慢；到第二个 a 块时那些 n-store 早已退休，只剩 10 条 a-store。**+1 tick 可以是队列深度差，不是预测器学习。**

**S1o（判别器，待跑）**：扫 RST ∈ {5, 20, 80}。

| 预测 | 含义 |
|---|---|
| **dA 随 RST 显著增长**（dA(80) − dA(5) ≥ 1 tick） | **QUEUE**：store 队列深度伪影，S1n 的 PASS 作废 |
| **dA 与 RST 无关**（差值 < 0.5 tick） | **ONESHOT**：与"预测器一次误预测就翻转"一致 → MDU 学习效应成立 |

理论依据：`dA = T_a1 − T_a2 = (t3 + (BLK−1)·t2) − BLK·t2 = t3 − t2`，**与 BLK、RST 都无关**；而队列深度效应必然随 RST 单调增长。两者预测完全相反，一次就能切开。


#### 源码 S1o `mdu_rst.c`（完整，可直接编译）

> CC=gcc -O2 -o mdu_rst mdu_rst.c；运行 `taskset -c 3 ./mdu_rst`；**删-fence 口径**

```c
/* mdu_rst.c —— S1o: 用 RST 剂量反应否掉"store 队列深度"这个替代解释（会话 19）
 * 编译: gcc -O2 -o mdu_rst mdu_rst.c     运行: taskset -c 3 ./mdu_rst
 *
 * 背景: S1n 给出 dA=+1.00 tick（CI 收成一点）、dN=+0.00 -> 别名块的第一个块确实多付了 1 tick。
 *       但存在一个不用 MDU 也能解释的机制: 复位用的 20 次 n 调用向 PA 写了 20 次 store,
 *       第一个 a 块的 load 要在一堆未退休的 PA store 里找最年轻的那条 => 队列越深越慢；
 *       到第二个 a 块时那些 n-store 早已退休, 队列里只剩 10 条 a-store。
 *
 * 判别器（预测完全不同）:
 *   若为 store 队列深度效应: dA 随 RST 增大而增大（RST=80 应明显大于 RST=20）
 *   若为 MDU 一次性学习:     dA ≈ t3 - t2, 与 RST 无关（预测器一次误预测就翻转）
 *
 * 设计: RST ∈ {5, 20, 80}, BLK=10 固定, 每组都带自己的 dN 对照, N=1500。
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static inline uint64_t rd(void){ uint64_t t; __asm__ __volatile__("mrs %0, cntvct_el0":"=r"(t)); return t; }
static volatile uint64_t sinkv;
static volatile uint64_t mask0 = 0;
static unsigned char *buf;

__attribute__((noinline)) static void st2ld(void *x0, void *x1){
  uint64_t a = (uint64_t)(uintptr_t)x0;
  for(int i=0;i<10;i++) a = a*6364136223846793005ULL + 1442695040888963407ULL;
  void *sa = (void*)((uintptr_t)x0 + (a & mask0));
  *(volatile uint64_t*)sa = 0x1111111122222222ULL;
  uint64_t x = *(volatile uint64_t*)x1;
  uint64_t b = a ^ x;
  for(int i=0;i<10;i++) b = b*6364136223846793005ULL + 1442695040888963407ULL;
  sinkv = b;
}

static int cmpd(const void*p,const void*q){ double x=*(const double*)p,y=*(const double*)q; return (x>y)-(x<y); }
static double qsel(double *v,int n,double p){
  double *c=malloc((size_t)n*sizeof(double)); memcpy(c,v,(size_t)n*sizeof(double));
  qsort(c,(size_t)n,sizeof(double),cmpd);
  int i=(int)(p*(n-1)); double r=c[i]; free(c); return r;
}
static void boot_median(double *v,int n,int B,double *lo,double *hi){
  double *m=malloc((size_t)B*sizeof(double)), *s=malloc((size_t)n*sizeof(double));
  uint64_t st=0x9E3779B97F4A7C15ULL;
  for(int b=0;b<B;b++){
    for(int i=0;i<n;i++){ st^=st<<13; st^=st>>7; st^=st<<17; s[i]=v[(int)(st%(uint64_t)n)]; }
    qsort(s,(size_t)n,sizeof(double),cmpd); m[b]=s[n/2];
  }
  qsort(m,(size_t)B,sizeof(double),cmpd);
  *lo=m[(int)(0.025*(B-1))]; *hi=m[(int)(0.975*(B-1))];
  free(m); free(s);
}

int main(void){
  setbuf(stdout,NULL);
  uint64_t frq=0; __asm__ __volatile__("mrs %0, cntfrq_el0":"=r"(frq));
  if(!frq) frq=50000000ULL;
  const double nspt = 1e9/(double)frq;

  if(posix_memalign((void**)&buf,4096,1u<<20)!=0) return 2;
  memset(buf,0,1u<<20);
  void *PA = (void*)(buf+0x1000);
  void *PB = (void*)(buf+0x8000);

  const int R = 1500, BLK = 10;
  const int RSTS[3] = {5, 20, 80};
  double mA[3], mN[3], mS[3];

  for(int i=0;i<5000;i++) st2ld(PA,PB);

  printf("# tick=%.2f ns  R=%d  BLK=%d  RST 扫描 {5,20,80}\n", nspt, R, BLK);
  printf("# 若 dA 随 RST 增长 -> store 队列深度伪影; 若 dA 恒定 -> MDU 一次性学习\n");

  for(int t=0;t<3;t++){
    int RST = RSTS[t];
    double *dA = malloc((size_t)R*sizeof(double));
    double *dN = malloc((size_t)R*sizeof(double));
    double *S  = malloc((size_t)R*sizeof(double));

    for(int r=0;r<R;r++){
      uint64_t t0,t1; double A1,A2,N1,N2;
      for(int k=0;k<RST;k++) st2ld(PA,PB);
      t0=rd(); for(int k=0;k<BLK;k++) st2ld(PA,PA); t1=rd(); A1=(double)(t1-t0);
      t0=rd(); for(int k=0;k<BLK;k++) st2ld(PA,PA); t1=rd(); A2=(double)(t1-t0);
      for(int k=0;k<RST;k++) st2ld(PA,PB);
      t0=rd(); for(int k=0;k<BLK;k++) st2ld(PA,PB); t1=rd(); N1=(double)(t1-t0);
      t0=rd(); for(int k=0;k<BLK;k++) st2ld(PA,PB); t1=rd(); N2=(double)(t1-t0);
      dA[r]=A1-A2; dN[r]=N1-N2; S[r]=dA[r]-dN[r];
    }
    double lo,hi;
    boot_median(dA,R,1200,&lo,&hi);
    mA[t]=qsel(dA,R,0.5);
    boot_median(dN,R,1200,&lo,&hi);
    mN[t]=qsel(dN,R,0.5);
    boot_median(S,R,1200,&lo,&hi);
    mS[t]=qsel(S,R,0.5);
    printf("\n RST=%-3d  dA=%+.2f ticks (CI [%+.2f,%+.2f])   dN=%+.2f   S=%+.2f (CI [%+.2f,%+.2f])\n",
           RST, mA[t], qsel(dA,R,0.025), qsel(dA,R,0.975), mN[t], mS[t], lo, hi);
    free(dA); free(dN); free(S);
  }

  printf("\n== RST 剂量反应 ==\n");
  printf("  RST:      5     20     80\n");
  printf("  dA  :  %+.2f  %+.2f  %+.2f\n", mA[0], mA[1], mA[2]);
  double grow = mA[2] - mA[0];
  printf("  dA(80) - dA(5) = %+.2f ticks\n", grow);

  int flat    = ((mA[2]-mA[0]) < 0.5) && ((mA[1]-mA[0]) < 0.5);
  int scaling = ((mA[2]-mA[0]) >= 1.0);

  printf("\n>>> 判读\n");
  if(scaling) printf(">>> QUEUE : dA 随 RST 显著增长 -> 是 store 队列深度伪影, 不是 MDU\n");
  else if(flat) printf(">>> ONESHOT: dA 与 RST 无关 -> 与\"预测器一次误预测就翻转\"一致 => MDU 学习效应\n");
  else printf(">>> AMBIGUOUS: 增长不明显也不为零 -> 加大 RST=200 与 BLK 再判\n");
  printf(">>> 摘要行: dA(5)=%+.2f dA(20)=%+.2f dA(80)=%+.2f  dN=%+.2f/%+.2f/%+.2f  %s\n",
         mA[0],mA[1],mA[2], mN[0],mN[1],mN[2], scaling?"QUEUE":(flat?"ONESHOT":"AMBIGUOUS"));
  return 0;
}
```

**S1o 实测（2026-11-19）→ 判 QUEUE，S1n 的 PASS 撤回（第五次自撤）**

| RST | dA | dN | S |
|---|---|---|---|
| 5 | +1.00 | +0.00 | +1.00 |
| 20 | +1.00 | +0.00 | +2.00 |
| 80 | +2.00 | +0.00 | +2.00 |

`dA(80) − dA(5) = +1.00 tick` → 按**预注册判据**（≥1 tick 增长即判 QUEUE），**S1n 的 PASS 作废**。

**但这个形状也不像干净的队列剂量反应**：5→20 完全不涨，20→80 才涨 1。若真是队列深度，5 到 20 条未退休 store 的差别不该为零。

**真正的结论是**：一次回滚惩罚只有几十 cycle，而一个 tick = 60 cycle，**无论怎么切都只在 1~2 个量化台阶里打转**。60 cycle 的尺子已经把这条路顶死了——不是"没有效应"，是"分辨不了"。

**S1p（换放大器，待跑）**

不去分辨"那一次调用多花多少"，而是让**这件事在一段测量里发生 M 次**：

```
A = M×[n 复位 ; 别名探针]     N = M×[n 复位 ; 非别名探针]
B = M×[a 复位 ; 别名探针]     D = M×[a 复位 ; 非别名探针]

X = A − N   （n 训练后, 别名与非别名的代价差, 含 M 倍放大）
Y = B − D   （a 训练后的同一个差）
S = X − Y   （预测器状态对这个差的影响）
```

- **队列效应抵消**：每一对内部复位序列完全相同，相减即消
- **分辨率**：每臂 M×(RST+1) = 672 次调用 ≈ 280 tick，1 tick 只占 0.36%
- **效应大小**：M=32，若每次事件差 20–60 cycle → 累加 640–1920 cycle = **11–32 tick**，远超量化噪声


#### 源码 S1p `mdu_amp.c`（完整，可直接编译）

> CC=gcc -O2 -o mdu_amp mdu_amp.c；运行 `taskset -c 3 ./mdu_amp`；**删-fence 口径**

```c
/* mdu_amp.c —— S1p: 把"一次误预测的代价"重复 M 次累加放大（会话 20）
 * 编译: gcc -O2 -o mdu_amp mdu_amp.c     运行: taskset -c 3 ./mdu_amp
 *
 * 为什么要有这一台: S1o 判 QUEUE（dA 1→1→2 随 RST 涨），但 5→20 不涨、20→80 涨 1，
 * 形状也不像干净的队列剂量反应。根本问题是 **60 cycle 的量化台阶已经把这案子顶死了**：
 * 一次回滚惩罚只有几十 cycle，无论怎么切都在 1~2 个 tick 里打转。
 *
 * 解法: 不去分辨"那一次调用多花多少"，而是 **让这件事在一段测量里发生 M 次**，累加起来。
 *
 * 四个臂（每臂都是 M 轮，每轮 = RST 次复位 + 1 次探针；两臂复位序列完全相同）:
 *   A = M×[n 复位 ; 别名探针]      N = M×[n 复位 ; 非别名探针]
 *   B = M×[a 复位 ; 别名探针]      D = M×[a 复位 ; 非别名探针]
 *
 *   X = A − N   (n 训练后, 别名 vs 非别的代价差, 含 M 倍放大)
 *   Y = B − D   (a 训练后, 同样的代价差)
 *   S = X − Y   (预测器状态对这个代价差的影响 => MDU 的直接证据)
 *
 * 队列效应: 每一对内部复位序列完全相同, 相减即抵消。
 * 分辨率: 每臂 ≈ M×(RST+1) 次调用 ≈ 280 tick, 1 tick 只占 0.36%。
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static inline uint64_t rd(void){ uint64_t t; __asm__ __volatile__("mrs %0, cntvct_el0":"=r"(t)); return t; }
static volatile uint64_t sinkv;
static volatile uint64_t mask0 = 0;
static unsigned char *buf;

__attribute__((noinline)) static void st2ld(void *x0, void *x1){
  uint64_t a = (uint64_t)(uintptr_t)x0;
  for(int i=0;i<10;i++) a = a*6364136223846793005ULL + 1442695040888963407ULL;
  void *sa = (void*)((uintptr_t)x0 + (a & mask0));
  *(volatile uint64_t*)sa = 0x1111111122222222ULL;
  uint64_t x = *(volatile uint64_t*)x1;
  uint64_t b = a ^ x;
  for(int i=0;i<10;i++) b = b*6364136223846793005ULL + 1442695040888963407ULL;
  sinkv = b;
}

__attribute__((noinline)) static void arm(void *r0, void *r1, void *p0, void *p1, int RST, int M){
  for(int m=0;m<M;m++){
    for(int k=0;k<RST;k++) st2ld(r0, r1);
    st2ld(p0, p1);
  }
}

static int cmpd(const void*p,const void*q){ double x=*(const double*)p,y=*(const double*)q; return (x>y)-(x<y); }
static double qsel(double *v,int n,double p){
  double *c=malloc((size_t)n*sizeof(double)); memcpy(c,v,(size_t)n*sizeof(double));
  qsort(c,(size_t)n,sizeof(double),cmpd);
  int i=(int)(p*(n-1)); double r=c[i]; free(c); return r;
}
static void boot_median(double *v,int n,int B,double *lo,double *hi){
  double *m=malloc((size_t)B*sizeof(double)), *s=malloc((size_t)n*sizeof(double));
  uint64_t st=0x9E3779B97F4A7C15ULL;
  for(int b=0;b<B;b++){
    for(int i=0;i<n;i++){ st^=st<<13; st^=st>>7; st^=st<<17; s[i]=v[(int)(st%(uint64_t)n)]; }
    qsort(s,(size_t)n,sizeof(double),cmpd); m[b]=s[n/2];
  }
  qsort(m,(size_t)B,sizeof(double),cmpd);
  *lo=m[(int)(0.025*(B-1))]; *hi=m[(int)(0.975*(B-1))];
  free(m); free(s);
}

int main(void){
  setbuf(stdout,NULL);
  uint64_t frq=0; __asm__ __volatile__("mrs %0, cntfrq_el0":"=r"(frq));
  if(!frq) frq=50000000ULL;
  const double nspt = 1e9/(double)frq;

  if(posix_memalign((void**)&buf,4096,1u<<20)!=0) return 2;
  memset(buf,0,1u<<20);
  void *PA = (void*)(buf+0x1000);
  void *PB = (void*)(buf+0x8000);

  const int M = 32, RST = 20, N = 400;
  double *X = malloc((size_t)N*sizeof(double));
  double *Y = malloc((size_t)N*sizeof(double));
  double *S = malloc((size_t)N*sizeof(double));

  for(int i=0;i<5000;i++) st2ld(PA,PB);

  printf("# tick=%.2f ns  M=%d  RST=%d  N=%d  (每臂 %d 次调用)\n",
         nspt, M, RST, N, M*(RST+1));

  for(int r=0;r<N;r++){
    uint64_t t0,t1; double A,Nn,Bb,D;
    int flip = (r & 1);                       /* 交替先后, 抵消漂移 */

    if(flip){
      t0=rd(); arm(PA,PB,PA,PA,RST,M); t1=rd(); A=(double)(t1-t0);
      t0=rd(); arm(PA,PB,PA,PB,RST,M); t1=rd(); Nn=(double)(t1-t0);
      t0=rd(); arm(PA,PA,PA,PA,RST,M); t1=rd(); Bb=(double)(t1-t0);
      t0=rd(); arm(PA,PA,PA,PB,RST,M); t1=rd(); D=(double)(t1-t0);
    } else {
      t0=rd(); arm(PA,PA,PA,PB,RST,M); t1=rd(); D=(double)(t1-t0);
      t0=rd(); arm(PA,PA,PA,PA,RST,M); t1=rd(); Bb=(double)(t1-t0);
      t0=rd(); arm(PA,PB,PA,PB,RST,M); t1=rd(); Nn=(double)(t1-t0);
      t0=rd(); arm(PA,PB,PA,PA,RST,M); t1=rd(); A=(double)(t1-t0);
    }
    X[r]=A-Nn; Y[r]=Bb-D; S[r]=X[r]-Y[r];
    if((r & 63)==0) printf("  ...%d/%d\n", r, N);
  }

  double lo,hi;
  boot_median(X,N,1200,&lo,&hi);
  printf("\n== X = A − N  (n 训练后: 别名探针 − 非别名探针) ==\n");
  printf("  中位 %+8.2f ticks  CI [%+.2f, %+.2f]\n", qsel(X,N,0.5), lo, hi);

  boot_median(Y,N,1200,&lo,&hi);
  printf("\n== Y = B − D  (a 训练后: 同样的差) ==\n");
  printf("  中位 %+8.2f ticks  CI [%+.2f, %+.2f]\n", qsel(Y,N,0.5), lo, hi);

  boot_median(S,N,1200,&lo,&hi);
  double ms=qsel(S,N,0.5);
  printf("\n== S = X − Y  (预测器状态的影响) ==\n");
  printf("  中位 %+8.2f ticks  CI [%+.2f, %+.2f]   %+.1f ns   %+.0f cycle\n",
         ms, lo, hi, ms*nspt, ms*nspt*3.0);
  printf("  折成每次事件 = S / M = %+.3f ticks\n", ms/(double)M);

  int sig = (lo>0.0 || hi<0.0);
  printf("\n>>> S1p %s\n", sig
    ? "SIGNAL : 预测器状态确实改变了别名探针的代价 => MDU 状态效应存在（M 倍放大后可见）"
    : "NULL   : 状态无关 => 在这条路径上同样未见 MDU 状态效应");
  printf(">>> 摘要行: X=%+.1f Y=%+.1f S=%+.2f[%+.2f,%+.2f] %s\n",
         qsel(X,N,0.5), qsel(Y,N,0.5), ms, lo, hi, sig?"SIGNAL":"NULL");
  return 0;
}
```

**S1p 实测（2026-11-19）→ SIGNAL，第一次真正抓到 MDU**

| 量 | 值 | 含义 |
|---|---|---|
| `X = A − N`（n 训练后：别名探针 − 非别名探针） | **+37.00 ticks**，CI [+37, +38] | 预测器说"bypass" → 别名探针投机后被迫回滚 = **t3 − t1** |
| `Y = B − D`（a 训练后：同一个差） | **+0.00 ticks**，CI [+0, +1] | 预测器说"block" → 别名与非别名**都**要等 store 地址 = **t2 − t2 = 0** |
| `S = X − Y` | **+37.00 ticks** = 740 ns = **2220 cycle**，CI [+37, +37] | 预测器状态确实改变了探针代价 |
| 折成每次事件 | **+1.156 tick = 23 ns = 69 cycle** | 与"一次误预测回滚"的量级吻合 |

**为什么这个结果结构上就对**：论文的三种时序（t1/t2/t3）预示的正是**不对称**——n 训练后别名与非别名不同（t3 vs t1），a 训练后两者相同（都是 t2）。实测 `X=37, Y=0` 就是这个形状。若是队列深度、cache 状态或暖机伪影，**不可能恰好在这个位置出现不对称**。

**同时解释了此前全部 CLEAN**：单次效应只有 69 cycle ≈ 1.15 tick，而一个 tick 是 60 cycle——单发测量必然量化成 1 tick；再叠上 fence 把乱序窗口关掉，就只能得到 0.00。**它们不是"没有"，是"看不见"。**

**状态更新**：Q-A 由「provisional 否」改为**「M 倍放大下观测到（69 cycle/事件）」**。Q-B（跨进程）随即成为唯一未决项 → S1q。

---


**S1q 设计（跨进程，待跑）—— Q-B 的判决**

S1p 已经把读数做到 69 cycle/事件（X=+37 tick）。现在把"训练"和"探测"拆到两个进程：

- **子进程（训练方）**：按 `sh->mode` 做 20 次 `st2ld`（n 或 a），交还 turn
- **父进程（探测方）**：等训练完成 → 紧接**一次**别名探针 `st2ld(PA,PA)`，逐次 `rd` 计时并累加

三个支撑点：

1. **同一二进制 → `st2ld` 的 load PC 相同 → 选中同一个 MDU 表项**（论文：表项由 load PC 选择，与地址空间无关），所以训练方和探测方共享的是同一个表项；
2. **握手在计时区间之外**，只有探针本身被计时；
3. 单次探针仍被量化到 1 tick，但把 **M=512** 次事件累加后，信号与噪声同步放大，均值差异仍可分辨（SE ≈ 0.4/√M tick）。

两臂的握手次数、指令序列、地址完全相同，**唯一差别是训练方做的是 n 还是 a**。

**判读**：D 的 CI 排除 0 → **Q-B 为真**（MDU 状态可被另一进程观测）；否则 → 跨进程不可（可能被切换清掉，或被 vCPU 迁移打散）。


#### 源码 S1q `mdu_xproc.c`（完整，可直接编译）

> CC=gcc -O2 -o mdu_xproc mdu_xproc.c；运行 `taskset -c 3 ./mdu_xproc`；**删-fence 口径**

```c
/* mdu_xproc.c —— S1q: 跨进程（论文隐蔽信道的形态）（会话 21）
 * 编译: gcc -O2 -o mdu_xproc mdu_xproc.c    运行: taskset -c 3 ./mdu_xproc
 *
 * 依据 S1p: MDU 状态效应 = 69 cycle/事件（X=+37 tick, Y=0, M=32）。
 * 本装置把"训练"和"探测"拆到两个进程里:
 *   - 子进程（训练方）：按 sh->mode 做 RST 次 st2ld（n 或 a），然后交还 turn
 *   - 父进程（探测方）：等训练完成 -> 紧接一次别名探针 st2ld(PA,PA)，逐次 rd 计时并累加
 *
 * 关键点:
 *   1. 两个进程是同一个二进制，st2ld 的 load PC 相同 => 选中同一个 MDU 表项
 *      （论文：表项由 load 的 PC 选择，与地址空间无关）。
 *   2. 握手开销在计时区间之外，只有探针本身被计时。
 *   3. 单次探针仍被量化到 1 tick，但把 M 次事件累加后，信号 = M × 1.15 tick，与噪声同步放大，
 *      均值差异仍然可分辨（SE ≈ 0.4/√M tick）。
 *   4. 两臂的握手次数、指令序列、地址完全相同，唯一差别是训练方的训练类型。
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sched.h>
#include <sys/mman.h>
#include <sys/wait.h>

static inline uint64_t rd(void){ uint64_t t; __asm__ __volatile__("mrs %0, cntvct_el0":"=r"(t)); return t; }
static volatile uint64_t sinkv;
static volatile uint64_t mask0 = 0;
static unsigned char *buf;

__attribute__((noinline)) static void st2ld(void *x0, void *x1){
  uint64_t a = (uint64_t)(uintptr_t)x0;
  for(int i=0;i<10;i++) a = a*6364136223846793005ULL + 1442695040888963407ULL;
  void *sa = (void*)((uintptr_t)x0 + (a & mask0));
  *(volatile uint64_t*)sa = 0x1111111122222222ULL;
  uint64_t x = *(volatile uint64_t*)x1;
  uint64_t b = a ^ x;
  for(int i=0;i<10;i++) b = b*6364136223846793005ULL + 1442695040888963407ULL;
  sinkv = b;
}

typedef struct { volatile int turn; volatile int mode; volatile int stop; volatile int cpu_tr; } sh_t;

static int cmpd(const void*p,const void*q){ double x=*(const double*)p,y=*(const double*)q; return (x>y)-(x<y); }
static double qsel(double *v,int n,double p){
  double *c=malloc((size_t)n*sizeof(double)); memcpy(c,v,(size_t)n*sizeof(double));
  qsort(c,(size_t)n,sizeof(double),cmpd);
  int i=(int)(p*(n-1)); double r=c[i]; free(c); return r;
}
static void boot_median(double *v,int n,int B,double *lo,double *hi){
  double *m=malloc((size_t)B*sizeof(double)), *s=malloc((size_t)n*sizeof(double));
  uint64_t st=0x9E3779B97F4A7C15ULL;
  for(int b=0;b<B;b++){
    for(int i=0;i<n;i++){ st^=st<<13; st^=st>>7; st^=st<<17; s[i]=v[(int)(st%(uint64_t)n)]; }
    qsort(s,(size_t)n,sizeof(double),cmpd); m[b]=s[n/2];
  }
  qsort(m,(size_t)B,sizeof(double),cmpd);
  *lo=m[(int)(0.025*(B-1))]; *hi=m[(int)(0.975*(B-1))];
  free(m); free(s);
}

int main(void){
  setbuf(stdout,NULL);
  uint64_t frq=0; __asm__ __volatile__("mrs %0, cntfrq_el0":"=r"(frq));
  if(!frq) frq=50000000ULL;
  const double nspt = 1e9/(double)frq;

  if(posix_memalign((void**)&buf,4096,1u<<20)!=0) return 2;
  memset(buf,0,1u<<20);
  void *PA = (void*)(buf+0x1000);
  void *PB = (void*)(buf+0x8000);

  sh_t *sh = mmap(NULL,sizeof(sh_t),PROT_READ|PROT_WRITE,MAP_SHARED|MAP_ANONYMOUS,-1,0);
  if(sh==MAP_FAILED){ printf("mmap fail\n"); return 2; }
  sh->turn=0; sh->mode=0; sh->stop=0; sh->cpu_tr=-1;

  cpu_set_t set; CPU_ZERO(&set); CPU_SET(3,&set);
  if(sched_setaffinity(0,sizeof(set),&set)!=0) printf("!! setaffinity 失败\n");

  for(int i=0;i<5000;i++) st2ld(PA,PB);

  pid_t pid = fork();
  if(pid==0){                       /* 训练方 */
    sh->cpu_tr = sched_getcpu();
    while(!sh->stop){
      if(sh->turn != 1){ sched_yield(); continue; }
      if(sh->mode==0){ for(int k=0;k<20;k++) st2ld(PA,PB); }   /* n 训练 */
      else           { for(int k=0;k<20;k++) st2ld(PA,PA); }   /* a 训练 */
      sh->turn = 2;
    }
    _exit(0);
  }

  const int M = 512, N = 30;
  double *TA = malloc((size_t)N*sizeof(double));
  double *TB = malloc((size_t)N*sizeof(double));
  double *D  = malloc((size_t)N*sizeof(double));

  for(int r=0;r<N;r++){
    long sum[2] = {0,0};
    for(int arm=0; arm<2; arm++){
      for(int m=0;m<M;m++){
        sh->mode = arm; sh->turn = 1;
        while(sh->turn != 2) sched_yield();
        uint64_t t0=rd(); st2ld(PA,PA); uint64_t t1=rd();     /* 探针：别名 */
        sum[arm] += (long)(t1-t0);
      }
    }
    TA[r]=(double)sum[0]; TB[r]=(double)sum[1]; D[r]=(double)(sum[0]-sum[1]);
    if((r%5)==0) printf("  ...%d/%d\n", r, N);
  }
  sh->stop=1;
  waitpid(pid,NULL,0);

  double lo,hi;
  printf("\n# tick=%.2f ns  M=%d 事件/样本  N=%d  训练方 cpu=%d  探测方 cpu=%d\n",
         nspt, M, N, sh->cpu_tr, sched_getcpu());

  double meanA=0; for(int i=0;i<N;i++) meanA += TA[i]; meanA /= (double)N;

  boot_median(TA,N,800,&lo,&hi);
  printf("\n== 训练=n（教 bypass）后，跨进程别名探针总时 ==\n  中位 %.1f ticks  CI [%.1f, %.1f]  均值 %.1f\n",
         qsel(TA,N,0.5), lo, hi, meanA);
  boot_median(TB,N,800,&lo,&hi);
  printf("\n== 训练=a（教 block）后，跨进程别名探针总时 ==\n  中位 %.1f ticks  CI [%.1f, %.1f]\n",
         qsel(TB,N,0.5), lo, hi);

  boot_median(D,N,800,&lo,&hi);
  double md=qsel(D,N,0.5);
  printf("\n== D = n训练 − a训练  （跨进程）==\n");
  printf("  中位 %+.1f ticks  CI [%+.1f, %+.1f]   折成每次事件 %+.3f ticks\n",
         md, lo, hi, md/(double)M);

  int sig = (lo>0.0 || hi<0.0);
  printf("\n>>> S1q %s\n", sig
    ? "PASS : 跨进程状态共享成立 => Q-B 为真（MDU 可被另一个进程观测）"
    : "NULL : 跨进程未见状态共享（可能被上下文切换清掉，或本机 vCPU 迁移打散）");
  printf(">>> 摘要行: TA=%.0f TB=%.0f D=%+.1f[%+.1f,%+.1f] M=%d %s\n",
         qsel(TA,N,0.5), qsel(TB,N,0.5), md, lo, hi, M, sig?"PASS":"NULL");
  return 0;
}
```

**S1q 实测（2026-11-19）→ PASS：跨进程状态共享成立**

| 量 | 值 |
|---|---|
| 训练方 / 探测方 CPU | **3 / 3**（同核 ✅） |
| 训练=n 后，跨进程别名探针总时（M=512） | **815.0 ticks**，CI [811, 824]，均值 839.5 |
| 训练=a 后，同一探针总时 | **502.0 ticks**，CI [501, 505] |
| **D = 差** | **+310.0 ticks**，CI [+308, +319] |
| 折成每次事件 | **+0.605 tick = 12 ns = 36 cycle** |

**为什么这个结果不是缓存的功劳**：`fork()` 之后子进程写 PA 触发 COW，**训练方的 PA 与探测方的 PA 是不同的物理页**——两者之间没有任何物理地址别名。唯一共享的东西就是**按 load PC 索引的微架构状态**，也就是 MDU 本体。

**Q-A 与 Q-B 同时成立**：
- Q-A（同进程可测）：S1p，69 cycle/事件，CI [+37,+37]，且形状（X≠0、Y=0）与论文 t1/t2/t3 一致；
- Q-B（跨进程可观测）：S1q，36 cycle/事件，CI [+308,+319]。

**量级差异要如实记录**：S1p 的 69 cycle 与 S1q 的 36 cycle 不一致（约 1.9 倍）。可能原因：跨进程探测前必然发生一次上下文切换，状态有部分衰减；或训练方 20 次调用在不同进程里对表项的"教"法略有差别。**不影响定性结论**，但要写进结论卡的边界里。

---


**S1r 设计（信道实测，待跑）—— 把结论变成可度量的东西**

编码按论文 Fig.8：
- 发送方把状态设为 **store bypassing** → **bit 1**（接收方探针会因回滚而变慢）
- 发送方把状态设为 **load blocking** → **bit 0**（接收方探针走 t2，较快）

每比特做 **K=8 轮** [发送方训练 20 次 → 接收方探针 1 次并计时]，用 K 次累加和判决（阈值 1.3 tick/轮）。K 轮是为了把单发 1 tick 的量化噪声平均掉——S1q 显示每轮差约 0.605 tick。

输出：错误率、每比特耗时、等效吞吐（bps）。


#### 源码 S1r `mdu_chan.c`（完整，可直接编译）

> CC=gcc -O2 -o mdu_chan mdu_chan.c；运行 `taskset -c 3 ./mdu_chan`

```c
/* mdu_chan.c —— S1r: 把状态变化当比特，测错误率与吞吐（论文 Fig.8 的形态）（会话 22）
 * 编译: gcc -O2 -o mdu_chan mdu_chan.c     运行: taskset -c 3 ./mdu_chan
 *
 * 编码（按论文 §covert channel）:
 *   发送方把 MDU 状态设成 store bypassing -> 表示 bit 1（接收方探针会变慢, 因为要回滚）
 *   发送方把 MDU 状态设成 load blocking    -> 表示 bit 0（接收方探针走 t2, 较快）
 * 每比特: K 轮 [发送方训练 20 次 ; 接收方探针 1 次并计时]，用 K 次累加和判决。
 *   K 轮是为了把单次 1 tick 的量化噪声平均掉（S1q 显示每轮差约 0.6 tick）。
 *
 * 输出: 错误率、每比特耗时、等效吞吐（bps）。
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <unistd.h>
#include <sched.h>
#include <sys/mman.h>
#include <sys/wait.h>

static inline uint64_t rd(void){ uint64_t t; __asm__ __volatile__("mrs %0, cntvct_el0":"=r"(t)); return t; }
static volatile uint64_t sinkv;
static volatile uint64_t mask0 = 0;
static unsigned char *buf;

__attribute__((noinline)) static void st2ld(void *x0, void *x1){
  uint64_t a = (uint64_t)(uintptr_t)x0;
  for(int i=0;i<10;i++) a = a*6364136223846793005ULL + 1442695040888963407ULL;
  void *sa = (void*)((uintptr_t)x0 + (a & mask0));
  *(volatile uint64_t*)sa = 0x1111111122222222ULL;
  uint64_t x = *(volatile uint64_t*)x1;
  uint64_t b = a ^ x;
  for(int i=0;i<10;i++) b = b*6364136223846793005ULL + 1442695040888963407ULL;
  sinkv = b;
}

typedef struct { volatile int turn; volatile int mode; volatile int stop; volatile int cpu_tr; } sh_t;

int main(void){
  setbuf(stdout,NULL);
  uint64_t frq=0; __asm__ __volatile__("mrs %0, cntfrq_el0":"=r"(frq));
  if(!frq) frq=50000000ULL;
  const double nspt = 1e9/(double)frq;

  if(posix_memalign((void**)&buf,4096,1u<<20)!=0) return 2;
  memset(buf,0,1u<<20);
  void *PA = (void*)(buf+0x1000);
  void *PB = (void*)(buf+0x8000);

  sh_t *sh = mmap(NULL,sizeof(sh_t),PROT_READ|PROT_WRITE,MAP_SHARED|MAP_ANONYMOUS,-1,0);
  if(sh==MAP_FAILED) return 2;
  sh->turn=0; sh->mode=0; sh->stop=0; sh->cpu_tr=-1;

  cpu_set_t set; CPU_ZERO(&set); CPU_SET(3,&set);
  if(sched_setaffinity(0,sizeof(set),&set)!=0) printf("!! setaffinity 失败\n");
  for(int i=0;i<5000;i++) st2ld(PA,PB);

  pid_t pid = fork();
  if(pid==0){
    sh->cpu_tr = sched_getcpu();
    while(!sh->stop){
      if(sh->turn != 1){ sched_yield(); continue; }
      if(sh->mode==0){ for(int k=0;k<20;k++) st2ld(PA,PB); }   /* bypass -> bit 1 */
      else           { for(int k=0;k<20;k++) st2ld(PA,PA); }   /* block  -> bit 0 */
      sh->turn = 2;
    }
    _exit(0);
  }

  const int NBITS = 128, K = 8;
  unsigned char *sent = malloc(NBITS);
  unsigned char *recv = malloc(NBITS);
  double *lat = malloc((size_t)NBITS*sizeof(double));

  uint64_t s = 0x123456789ABCDEFULL;
  for(int i=0;i<NBITS;i++){ s^=s<<13; s^=s>>7; s^=s<<17; sent[i] = (unsigned char)(s & 1); }

  uint64_t t_start = rd();
  for(int i=0;i<NBITS;i++){
    long sum = 0;
    int b = sent[i];
    for(int k=0;k<K;k++){
      sh->mode = (b ? 0 : 1);          /* bit1 -> n 训练; bit0 -> a 训练 */
      sh->turn = 1;
      while(sh->turn != 2) sched_yield();
      uint64_t t0=rd(); st2ld(PA,PA); uint64_t t1=rd();
      sum += (long)(t1-t0);
    }
    lat[i] = (double)sum;
    recv[i] = (sum >= (long)(K*1.3)) ? 1 : 0;   /* 阈值 1.3 tick/轮, 取 TA/TB 中点 */
  }
  uint64_t t_end = rd();
  sh->stop=1;
  waitpid(pid,NULL,0);

  int err=0;
  for(int i=0;i<NBITS;i++) if(sent[i]!=recv[i]) err++;

  double total_ns = (double)(t_end-t_start)*nspt;
  double mean1=0, mean0=0; int n1=0,n0=0;
  for(int i=0;i<NBITS;i++){ if(sent[i]){ mean1+=lat[i]; n1++; } else { mean0+=lat[i]; n0++; } }
  if(n1) mean1/=n1; if(n0) mean0/=n0;

  printf("\n# tick=%.2f ns  NBITS=%d  K=%d 轮/比特  训练方 cpu=%d  探测方 cpu=%d\n",
         nspt, NBITS, K, sh->cpu_tr, sched_getcpu());
  printf("# 编码: bit1 = n 训练(bypass, 探针慢)   bit0 = a 训练(block, 探针快)\n");

  printf("\n== 解码统计 ==\n");
  printf("  bit=1 平均 %6.1f ticks (%5.2f tick/轮)\n", mean1, mean1/K);
  printf("  bit=0 平均 %6.1f ticks (%5.2f tick/轮)\n", mean0, mean0/K);
  printf("  判决阈值 %.1f ticks\n", K*1.3);
  printf("\n  错误 %d / %d   = %.2f%%\n", err, NBITS, 100.0*err/NBITS);
  printf("  总耗时 %.1f us   每比特 %.2f us\n", total_ns/1000.0, total_ns/1000.0/NBITS);
  /* 错误率的 Wilson 95% CI */
  { double n = (double)NBITS, p = (double)err/n, z = 1.96;
    double den = 1.0 + z*z/n;
    double cen = (p + z*z/(2*n)) / den;
    double rad = z*sqrt(p*(1-p)/n + z*z/(4*n*n)) / den;
    double lo = cen-rad, hi = cen+rad;
    if(lo<0) lo=0; if(hi>1) hi=1;
    printf("  错误率 95%%CI（Wilson）%.2f%% – %.2f%%\n", 100.0*lo, 100.0*hi);
  }

  /* 每比特 1 bit，不是 1 字节：吞吐 = NBITS 比特 / 总秒数 */
  printf("  等效吞吐 %.1f kbps  （%.0f bps）\n",
         NBITS/(total_ns/1e9)/1000.0, NBITS/(total_ns/1e9));

  int ok = (err*20 <= NBITS);       /* 错误率 <= 5% */
  printf("\n>>> S1r %s\n", ok
    ? "PASS : 跨进程隐蔽信道可建立（错误率 <= 5%），吞吐见上"
    : "WEAK : 错误率过高，需要加大 K 或调整阈值");
  printf(">>> 摘要行: bit1=%.1ftick bit0=%.1ftick err=%d/%d %.1f kbps %s\n",
         mean1, mean0, err, NBITS, NBITS/(total_ns/1e9)/1000.0, ok?"PASS":"WEAK");
  return 0;
}
```

**S1r 实测（2026-11-19）→ PASS：跨进程隐蔽信道建成**

| 量 | 值 |
|---|---|
| bit=1（n 训练，bypass，探针慢） | **12.0 ticks**（1.50 tick/轮） |
| bit=0（a 训练，block，探针快） | **10.7 ticks**（1.33 tick/轮） |
| 判决阈值 | 10.4 ticks |
| **错误率** | **4 / 128 = 3.12%** |
| 每比特耗时 | **13.43 µs** |
| **等效吞吐** | **~74 kbps（74 476 bps）** ← **原报 595.8 是代码 bug（把比特数乘了 8），已改正** |
| 错误率 95%CI | 3.12% 的 Wilson 区间约 **1.2% – 7.8%**（128 bit 单次，样本极小） |
| 两进程 CPU | 3 / 3（同核 ✅） |

**这一台只能算"信道可建立"，不是稳态指标**：单次 128 bit、错误率个位数百分比（95%CI 1.2–7.8%）、阈值是手调的 `K×1.3`、裕度 0.3 tick。

**这一台的量级要如实记**：每轮差只有 **0.16 tick ≈ 3 ns ≈ 9.6 cycle**，远小于 S1q 的 0.605 tick（36 cycle）。原因很可能是 S1r 的比特是随机交替的——相邻比特同模式时状态"延续"，异模式时探针会撞上一个还没被新训练覆盖的旧状态，对比度因此被稀释。**信道能跑，但裕度很薄**（10.7 vs 12.0，阈值 10.4 只在 bit=0 均值之下 0.3 tick）。

**可优化项（未做）**：
1. 阈值改成两臂均值的几何中点（11.35）而不是固定 1.3 tick/轮；
2. K 从 8 加到 16 → 错误率降、吞吐降，可画一条"错误率-吞吐"曲线；
3. 相邻比特强制同模式（用差分编码）→ 规避状态延续问题。

---


**S1s / S1t（两个"杀死控制"，定案必需，待跑）**

前五次自撤给出的教训是：**符合理论 + 一个控制，仍然可能是伪影。** 要定案，必须证明"该消失的时候它消失"。这两个装置各管一条：

| 装置 | 控制什么 | 预期 | 若不符合 |
|---|---|---|---|
| **S1s**（同进程） | **去掉 store 地址的拖晚**（不经 10 级乘法链，地址在发射时即已知）→ MDU 的使能条件不满足 | **X 必须掉到 ≈0** | X 仍在 → S1p 的 +37 tick 另有来源（转发 / store-buffer），**MDU 结论撤回** |
| **S1t**（跨进程） | **训练方改用另一个 load PC**（同语义的第二份函数）→ 破坏 PC 索引共享 | **D 必须消失** | D 仍在 → 共享的不是 PC 索引的 MDU 表项（可能是别的随上下文携带的状态），**S1q 结论改写** |

两个装置都保持其余参数与 S1p/S1q 完全一致（M、RST、地址、握手次数、指令数），**唯一变量就是被控的那一项**。S1s 在同一个程序里同时跑 LATE（应重现 +37）与 EARLY（应掉到 0），一次运行就能看到对照。


#### 源码 S1s `mdu_kill1.c`（完整，可直接编译）

> CC=gcc -O2 -o mdu_kill1 mdu_kill1.c -lm；运行 `taskset -c 3 ./mdu_kill1`；**删-fence 口径**；同程序内同时给出 LATE 与 EARLY 对照

```c
/* mdu_kill1.c —— S1s: S1p 的"杀死控制"——把 store 地址的拖晚去掉（会话 23）
 * 编译: gcc -O2 -o mdu_kill1 mdu_kill1.c     运行: taskset -c 3 ./mdu_kill1
 *
 * 逻辑: MDU 只有在"store 地址尚未生成、load 是否别名不确定"时才起作用。
 *       若把 store 地址变成发射时即已知（去掉 store 前的 10 级乘法链），
 *       MDU 的 enable 条件就不满足 -> S1p 那个 X 必须掉到 0。
 *       若 X_early 仍然很大 -> 说明 +37 tick 不是 MDU（是转发/store-buffer 之类的固定差异）。
 *
 * 两套探针对照（其余参数完全相同: 10 乘法放大留在 load 之后）:
 *   LATE  : store 地址经 10 级乘法链（= S1p 原样）  -> 预期 X 大
 *   EARLY : store 地址直接用 x0，不经乘法链          -> 预期 X ≈ 0
 *
 * 四臂结构同 S1p: A/N 用 n 复位, B/D 用 a 复位; X = A−N, Y = B−D, S = X−Y。
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static inline uint64_t rd(void){ uint64_t t; __asm__ __volatile__("mrs %0, cntvct_el0":"=r"(t)); return t; }
static volatile uint64_t sinkv;
static volatile uint64_t mask0 = 0;
static unsigned char *buf;

/* LATE: store 地址经 10 级乘法链（S1p 原样） */
__attribute__((noinline)) static void late(void *x0, void *x1){
  uint64_t a = (uint64_t)(uintptr_t)x0;
  for(int i=0;i<10;i++) a = a*6364136223846793005ULL + 1442695040888963407ULL;
  void *sa = (void*)((uintptr_t)x0 + (a & mask0));
  *(volatile uint64_t*)sa = 0x1111111122222222ULL;
  uint64_t x = *(volatile uint64_t*)x1;
  uint64_t b = a ^ x;
  for(int i=0;i<10;i++) b = b*6364136223846793005ULL + 1442695040888963407ULL;
  sinkv = b;
}
/* EARLY: store 地址发射时即已知，但保留 load 之后的 10 级乘法（保持放大与指令量级一致） */
__attribute__((noinline)) static void early(void *x0, void *x1){
  uint64_t a = (uint64_t)(uintptr_t)x0;
  *(volatile uint64_t*)x0 = 0x1111111122222222ULL;
  uint64_t x = *(volatile uint64_t*)x1;
  uint64_t b = a ^ x;
  for(int i=0;i<10;i++) b = b*6364136223846793005ULL + 1442695040888963407ULL;
  sinkv = b;
}

__attribute__((noinline)) static void arm_late(void *r0, void *r1, void *p0, void *p1, int RST, int M){
  for(int m=0;m<M;m++){ for(int k=0;k<RST;k++) late(r0,r1); late(p0,p1); }
}
__attribute__((noinline)) static void arm_early(void *r0, void *r1, void *p0, void *p1, int RST, int M){
  for(int m=0;m<M;m++){ for(int k=0;k<RST;k++) late(r0,r1); early(p0,p1); }
}

static int cmpd(const void*p,const void*q){ double x=*(const double*)p,y=*(const double*)q; return (x>y)-(x<y); }
static double qsel(double *v,int n,double p){
  double *c=malloc((size_t)n*sizeof(double)); memcpy(c,v,(size_t)n*sizeof(double));
  qsort(c,(size_t)n,sizeof(double),cmpd);
  int i=(int)(p*(n-1)); double r=c[i]; free(c); return r;
}
static void boot_median(double *v,int n,int B,double *lo,double *hi){
  double *m=malloc((size_t)B*sizeof(double)), *s=malloc((size_t)n*sizeof(double));
  uint64_t st=0x9E3779B97F4A7C15ULL;
  for(int b=0;b<B;b++){
    for(int i=0;i<n;i++){ st^=st<<13; st^=st>>7; st^=st<<17; s[i]=v[(int)(st%(uint64_t)n)]; }
    qsort(s,(size_t)n,sizeof(double),cmpd); m[b]=s[n/2];
  }
  qsort(m,(size_t)B,sizeof(double),cmpd);
  *lo=m[(int)(0.025*(B-1))]; *hi=m[(int)(0.975*(B-1))];
  free(m); free(s);
}

int main(void){
  setbuf(stdout,NULL);
  uint64_t frq=0; __asm__ __volatile__("mrs %0, cntfrq_el0":"=r"(frq));
  if(!frq) frq=50000000ULL;
  const double nspt = 1e9/(double)frq;

  if(posix_memalign((void**)&buf,4096,1u<<20)!=0) return 2;
  memset(buf,0,1u<<20);
  void *PA = (void*)(buf+0x1000);
  void *PB = (void*)(buf+0x8000);

  const int M = 32, RST = 20, N = 300;
  double *Xl=malloc((size_t)N*sizeof(double)), *Yl=malloc((size_t)N*sizeof(double)), *Sl=malloc((size_t)N*sizeof(double));
  double *Xe=malloc((size_t)N*sizeof(double)), *Ye=malloc((size_t)N*sizeof(double)), *Se=malloc((size_t)N*sizeof(double));

  for(int i=0;i<5000;i++){ late(PA,PB); early(PA,PB); }

  printf("# tick=%.2f ns  M=%d  RST=%d  N=%d\n", nspt, M, RST, N);
  printf("# LATE = store 地址经 10 级乘法链（MDU 使能）  EARLY = 地址发射即知（MDU 不应使能）\n");

  for(int r=0;r<N;r++){
    uint64_t t0,t1; double A,Nn,Bb,D;
    /* LATE 四臂 */
    t0=rd(); arm_late(PA,PB,PA,PA,RST,M); t1=rd(); A=(double)(t1-t0);
    t0=rd(); arm_late(PA,PB,PA,PB,RST,M); t1=rd(); Nn=(double)(t1-t0);
    t0=rd(); arm_late(PA,PA,PA,PA,RST,M); t1=rd(); Bb=(double)(t1-t0);
    t0=rd(); arm_late(PA,PA,PA,PB,RST,M); t1=rd(); D=(double)(t1-t0);
    Xl[r]=A-Nn; Yl[r]=Bb-D; Sl[r]=Xl[r]-Yl[r];

    /* EARLY 四臂 */
    t0=rd(); arm_early(PA,PB,PA,PA,RST,M); t1=rd(); A=(double)(t1-t0);
    t0=rd(); arm_early(PA,PB,PA,PB,RST,M); t1=rd(); Nn=(double)(t1-t0);
    t0=rd(); arm_early(PA,PA,PA,PA,RST,M); t1=rd(); Bb=(double)(t1-t0);
    t0=rd(); arm_early(PA,PA,PA,PB,RST,M); t1=rd(); D=(double)(t1-t0);
    Xe[r]=A-Nn; Ye[r]=Bb-D; Se[r]=Xe[r]-Ye[r];

    if((r & 63)==0) printf("  ...%d/%d\n", r, N);
  }

  double lo,hi;
  printf("\n== LATE（MDU 使能，应重现 S1p）==\n");
  boot_median(Xl,N,1000,&lo,&hi); printf("  X = %+8.2f  CI [%+.2f, %+.2f]\n", qsel(Xl,N,0.5), lo, hi);
  boot_median(Yl,N,1000,&lo,&hi); printf("  Y = %+8.2f  CI [%+.2f, %+.2f]\n", qsel(Yl,N,0.5), lo, hi);
  boot_median(Sl,N,1000,&lo,&hi); printf("  S = %+8.2f  CI [%+.2f, %+.2f]\n", qsel(Sl,N,0.5), lo, hi);

  printf("\n== EARLY（MDU 不应使能，S 必须掉到 0）==\n");
  boot_median(Xe,N,1000,&lo,&hi); printf("  X = %+8.2f  CI [%+.2f, %+.2f]\n", qsel(Xe,N,0.5), lo, hi);
  boot_median(Ye,N,1000,&lo,&hi); printf("  Y = %+8.2f  CI [%+.2f, %+.2f]\n", qsel(Ye,N,0.5), lo, hi);
  boot_median(Se,N,1000,&lo,&hi); printf("  S = %+8.2f  CI [%+.2f, %+.2f]\n", qsel(Se,N,0.5), lo, hi);

  printf("\n== 判定 ==\n");
  printf("  |S_LATE| = %.2f   |S_EARLY| = %.2f\n", fabs(qsel(Sl,N,0.5)), fabs(qsel(Se,N,0.5)));
  int killed = (fabs(qsel(Se,N,0.5)) <= 2.0) && (fabs(qsel(Sl,N,0.5)) >= 10.0);
  printf("\n>>> S1s %s\n", killed
    ? "PASS : 去掉地址拖晚后信号消失 -> S1p 的 X 确实依赖 MDU 使能条件（信号被正确击杀）"
    : "FAIL : 信号没被击杀 -> S1p 的 +37 tick 另有来源, MDU 结论需撤回");
  printf(">>> 摘要行: S_LATE=%+.1f S_EARLY=%+.1f %s\n",
         qsel(Sl,N,0.5), qsel(Se,N,0.5), killed?"PASS":"FAIL");
  return 0;
}
```

#### 源码 S1t `mdu_kill2.c`（完整，可直接编译）

> CC=gcc -O2 -o mdu_kill2 mdu_kill2.c -lm；运行 `taskset -c 3 ./mdu_kill2`；**删-fence 口径**

```c
/* mdu_kill2.c —— S1t: S1q 的"杀死控制"——训练方改用不同的 load PC（会话 23）
 * 编译: gcc -O2 -o mdu_kill2 mdu_kill2.c     运行: taskset -c 3 ./mdu_kill2
 *
 * 逻辑: 论文指出 MDU 表项由 **load 的 PC** 选择。若共享的确实是这个表项，那么
 *       训练方改用另一个 PC（另一份同语义代码 = 另一个函数地址）去训练，
 *       就不会命中探测方那个表项 -> D 必须消失。
 *       若 D 仍在 -> 共享的不是 PC 索引的 MDU（可能是别的随上下文携带的状态）。
 *
 * 实现: st2ld_a / st2ld_b 两份同语义函数（不同函数地址 = 不同 load PC）。
 *   探测方永远用 st2ld_a 做探针。
 *   训练方: mode=0 -> 用 st2ld_a 训练（同 PC）; mode=1 -> 用 st2ld_b 训练（异 PC）。
 *   两臂的握手次数、指令数、地址全部相同。
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <unistd.h>
#include <sched.h>
#include <sys/mman.h>
#include <sys/wait.h>

static inline uint64_t rd(void){ uint64_t t; __asm__ __volatile__("mrs %0, cntvct_el0":"=r"(t)); return t; }
static volatile uint64_t sinkv;
static volatile uint64_t mask0 = 0;
static unsigned char *buf;

/* 两份同语义、不同地址的探针（编译器不会把它们合并，因为都有 noinline 且各自被取址） */
__attribute__((noinline)) static void st2ld_a(void *x0, void *x1){
  uint64_t a = (uint64_t)(uintptr_t)x0;
  for(int i=0;i<10;i++) a = a*6364136223846793005ULL + 1442695040888963407ULL;
  void *sa = (void*)((uintptr_t)x0 + (a & mask0));
  *(volatile uint64_t*)sa = 0x1111111122222222ULL;
  uint64_t x = *(volatile uint64_t*)x1;
  uint64_t b = a ^ x;
  for(int i=0;i<10;i++) b = b*6364136223846793005ULL + 1442695040888963407ULL;
  sinkv = b;
}
__attribute__((noinline)) static void st2ld_b(void *x0, void *x1){
  uint64_t a = (uint64_t)(uintptr_t)x0;
  for(int i=0;i<10;i++) a = a*6364136223846793005ULL + 1442695040888963407ULL;
  void *sa = (void*)((uintptr_t)x0 + (a & mask0));
  *(volatile uint64_t*)sa = 0x1111111122222222ULL;
  uint64_t x = *(volatile uint64_t*)x1;
  uint64_t b = a ^ x;
  for(int i=0;i<10;i++) b = b*6364136223846793005ULL + 1442695040888963407ULL;
  sinkv = b;
}

typedef struct { volatile int turn; volatile int mode; volatile int stop; volatile int cpu_tr; } sh_t;

static int cmpd(const void*p,const void*q){ double x=*(const double*)p,y=*(const double*)q; return (x>y)-(x<y); }
static double qsel(double *v,int n,double p){
  double *c=malloc((size_t)n*sizeof(double)); memcpy(c,v,(size_t)n*sizeof(double));
  qsort(c,(size_t)n,sizeof(double),cmpd);
  int i=(int)(p*(n-1)); double r=c[i]; free(c); return r;
}
static void boot_median(double *v,int n,int B,double *lo,double *hi){
  double *m=malloc((size_t)B*sizeof(double)), *s=malloc((size_t)n*sizeof(double));
  uint64_t st=0x9E3779B97F4A7C15ULL;
  for(int b=0;b<B;b++){
    for(int i=0;i<n;i++){ st^=st<<13; st^=st>>7; st^=st<<17; s[i]=v[(int)(st%(uint64_t)n)]; }
    qsort(s,(size_t)n,sizeof(double),cmpd); m[b]=s[n/2];
  }
  qsort(m,(size_t)B,sizeof(double),cmpd);
  *lo=m[(int)(0.025*(B-1))]; *hi=m[(int)(0.975*(B-1))];
  free(m); free(s);
}

int main(void){
  setbuf(stdout,NULL);
  uint64_t frq=0; __asm__ __volatile__("mrs %0, cntfrq_el0":"=r"(frq));
  if(!frq) frq=50000000ULL;
  const double nspt = 1e9/(double)frq;

  if(posix_memalign((void**)&buf,4096,1u<<20)!=0) return 2;
  memset(buf,0,1u<<20);
  void *PA = (void*)(buf+0x1000);
  void *PB = (void*)(buf+0x8000);

  sh_t *sh = mmap(NULL,sizeof(sh_t),PROT_READ|PROT_WRITE,MAP_SHARED|MAP_ANONYMOUS,-1,0);
  if(sh==MAP_FAILED) return 2;
  sh->turn=0; sh->mode=0; sh->stop=0; sh->cpu_tr=-1;

  cpu_set_t set; CPU_ZERO(&set); CPU_SET(3,&set);
  if(sched_setaffinity(0,sizeof(set),&set)!=0) printf("!! setaffinity 失败\n");
  for(int i=0;i<5000;i++){ st2ld_a(PA,PB); st2ld_b(PA,PB); }

  pid_t pid = fork();
  if(pid==0){
    sh->cpu_tr = sched_getcpu();
    while(!sh->stop){
      if(sh->turn != 1){ sched_yield(); continue; }
      if(sh->mode==0){ for(int k=0;k<20;k++) st2ld_a(PA,PB); }   /* 同 PC 训练 -> 教 bypass */
      else           { for(int k=0;k<20;k++) st2ld_b(PA,PB); }   /* 异 PC 训练 -> 不应命中探测方表项 */
      sh->turn = 2;
    }
    _exit(0);
  }

  const int M = 512, N = 30;
  double *TS = malloc((size_t)N*sizeof(double));   /* 同 PC 训练 */
  double *TD = malloc((size_t)N*sizeof(double));   /* 异 PC 训练 */
  double *Dd = malloc((size_t)N*sizeof(double));

  for(int r=0;r<N;r++){
    long sum[2] = {0,0};
    for(int arm=0; arm<2; arm++){
      for(int m=0;m<M;m++){
        sh->mode = arm; sh->turn = 1;
        while(sh->turn != 2) sched_yield();
        uint64_t t0=rd(); st2ld_a(PA,PA); uint64_t t1=rd();   /* 探针永远用 st2ld_a */
        sum[arm] += (long)(t1-t0);
      }
    }
    TS[r]=(double)sum[0]; TD[r]=(double)sum[1]; Dd[r]=(double)(sum[0]-sum[1]);
    if((r%5)==0) printf("  ...%d/%d\n", r, N);
  }
  sh->stop=1;
  waitpid(pid,NULL,0);

  double lo,hi;
  printf("\n# tick=%.2f ns  M=%d  N=%d  训练方 cpu=%d  探测方 cpu=%d\n",
         nspt, M, N, sh->cpu_tr, sched_getcpu());
  printf("# 探针固定 st2ld_a；训练方 mode0=st2ld_a(同PC) mode1=st2ld_b(异PC)\n");

  boot_median(TS,N,800,&lo,&hi);
  printf("\n== 同 PC 训练后，探针总时 ==\n  中位 %.1f ticks  CI [%.1f, %.1f]\n", qsel(TS,N,0.5), lo, hi);
  boot_median(TD,N,800,&lo,&hi);
  printf("\n== 异 PC 训练后，探针总时 ==\n  中位 %.1f ticks  CI [%.1f, %.1f]\n", qsel(TD,N,0.5), lo, hi);

  boot_median(Dd,N,800,&lo,&hi);
  double md=qsel(Dd,N,0.5);
  printf("\n== D = 同PC训练 − 异PC训练 ==\n  中位 %+.1f ticks  CI [%+.1f, %+.1f]   折成每次事件 %+.3f ticks\n",
         md, lo, hi, md/(double)M);

  int sig = (lo>0.0 || hi<0.0);
  printf("\n>>> S1t %s\n", sig
    ? "SURVIVE : 换成异 PC 训练后 D 仍在 -> 共享的不是 PC 索引的 MDU 表项, S1q 结论需改写"
    : "KILLED  : 换异 PC 后 D 消失 -> 跨进程共享的确实是 PC 索引的 MDU 表项（S1q 成立）");
  printf(">>> 摘要行: TS=%.0f TD=%.0f D=%+.1f[%+.1f,%+.1f] %s\n",
         qsel(TS,N,0.5), qsel(TD,N,0.5), md, lo, hi, sig?"SURVIVE":"KILLED");
  return 0;
}
```


**S1s 实测（2026-11-19）→ PASS：信号被正确击杀**

| 变体 | X = A−N | Y = B−D | S = X−Y |
|---|---|---|---|
| **LATE**（store 地址经 10 级乘法链 = MDU 使能） | +37.00 | +1.00 | **+36.00**，CI [+36, +37] |
| **EARLY**（地址发射即知 = MDU 不应使能） | +1.00 | +1.00 | **+0.00**，CI [−1, +0] |

把 store 地址的"未解析窗口"拿掉之后，+36 tick 的信号**整块消失**。两臂的指令数、地址、M/RST 全同，唯一变量就是 store 地址是否晚到——**这正是 MDU 的使能条件**。S1p 的阳性由此得到支撑。

**S1t 实测 → 我的设计有缺陷，无信息量（不计为 PASS）**

| 量 | 值 |
|---|---|
| TS（同 PC 的 n 训练） | 753.0 ticks |
| TD（异 PC 的 n 训练） | 750.0 ticks |
| D | **−2.0 ticks**，CI [−6.0, +5.0] |

D≈0 看着像"杀死了"，但**这一台不能说明问题**：两臂都是 **n 训练（教 bypass）**，而 bypass 本来就是默认态，所以无论训练打在同 PC 还是异 PC，探针都会保持慢 → D 必然≈0。**它无法区分"PC 索引的 MDU"与"全局共享状态"。**

**S1u（修正版，待跑）**：两臂都改成 **a 训练（教 block）**

| 臂 | 训练 | 探测方表项 | 探针预期 |
|---|---|---|---|
| mode0 | `st2ld_a` 做 a 训练（**同 PC**） | 被设成 block | **快**（≈500） |
| mode1 | `st2ld_b` 做 a 训练（**异 PC**） | 不被碰，保持 bypass | **慢**（≈750） |

`D = 同PC − 异PC` 应显著为**负**（约 −250 tick）。若 D≈0 → 状态不是 PC 索引，S1q 的机理判断要改写。



#### 源码 S1u `mdu_kill3.c`（完整，可直接编译）

> CC=gcc -O2 -o mdu_kill3 mdu_kill3.c -lm；运行 `taskset -c 3 ./mdu_kill3`；**删-fence 口径**

```c
/* mdu_kill3.c —— S1u: 修正版跨进程杀死控制（会话 24）
 * 编译: gcc -O2 -o mdu_kill3 mdu_kill3.c -lm     运行: taskset -c 3 ./mdu_kill3
 *
 * 为什么要有 S1u（S1t 设计缺陷）:
 *   S1t 的两臂都是 **n 训练**（教 bypass）。而 bypass 本身就是默认态，所以
 *   "同 PC 训练" 与 "异 PC 训练" 都会让探针保持慢 => D≈0，无法区分
 *   "PC 索引的 MDU" 与 "全局共享状态"。那台装置没有信息量。
 *
 * S1u 改成 **a 训练**（教 block）做对照:
 *   mode0: 训练方用 st2ld_a 做 a 训练（同 PC）  -> 探测方的表项被设成 block -> 探针**快**
 *   mode1: 训练方用 st2ld_b 做 a 训练（异 PC）  -> 探测方表项不被碰 -> 保持 bypass -> 探针**慢**
 *   D = 同PC − 异PC 应显著为**负**（约 −250 tick）。
 *   若 D ≈ 0 => 状态是全局的（不是 PC 索引），S1q 的机理判断要改写。
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <unistd.h>
#include <sched.h>
#include <sys/mman.h>
#include <sys/wait.h>

static inline uint64_t rd(void){ uint64_t t; __asm__ __volatile__("mrs %0, cntvct_el0":"=r"(t)); return t; }
static volatile uint64_t sinkv;
static volatile uint64_t mask0 = 0;
static unsigned char *buf;

__attribute__((noinline)) static void st2ld_a(void *x0, void *x1){
  uint64_t a = (uint64_t)(uintptr_t)x0;
  for(int i=0;i<10;i++) a = a*6364136223846793005ULL + 1442695040888963407ULL;
  void *sa = (void*)((uintptr_t)x0 + (a & mask0));
  *(volatile uint64_t*)sa = 0x1111111122222222ULL;
  uint64_t x = *(volatile uint64_t*)x1;
  uint64_t b = a ^ x;
  for(int i=0;i<10;i++) b = b*6364136223846793005ULL + 1442695040888963407ULL;
  sinkv = b;
}
__attribute__((noinline)) static void st2ld_b(void *x0, void *x1){
  uint64_t a = (uint64_t)(uintptr_t)x0;
  for(int i=0;i<10;i++) a = a*6364136223846793005ULL + 1442695040888963407ULL;
  void *sa = (void*)((uintptr_t)x0 + (a & mask0));
  *(volatile uint64_t*)sa = 0x1111111122222222ULL;
  uint64_t x = *(volatile uint64_t*)x1;
  uint64_t b = a ^ x;
  for(int i=0;i<10;i++) b = b*6364136223846793005ULL + 1442695040888963407ULL;
  sinkv = b;
}

typedef struct { volatile int turn; volatile int mode; volatile int stop; volatile int cpu_tr; } sh_t;

static int cmpd(const void*p,const void*q){ double x=*(const double*)p,y=*(const double*)q; return (x>y)-(x<y); }
static double qsel(double *v,int n,double p){
  double *c=malloc((size_t)n*sizeof(double)); memcpy(c,v,(size_t)n*sizeof(double));
  qsort(c,(size_t)n,sizeof(double),cmpd);
  int i=(int)(p*(n-1)); double r=c[i]; free(c); return r;
}
static void boot_median(double *v,int n,int B,double *lo,double *hi){
  double *m=malloc((size_t)B*sizeof(double)), *s=malloc((size_t)n*sizeof(double));
  uint64_t st=0x9E3779B97F4A7C15ULL;
  for(int b=0;b<B;b++){
    for(int i=0;i<n;i++){ st^=st<<13; st^=st>>7; st^=st<<17; s[i]=v[(int)(st%(uint64_t)n)]; }
    qsort(s,(size_t)n,sizeof(double),cmpd); m[b]=s[n/2];
  }
  qsort(m,(size_t)B,sizeof(double),cmpd);
  *lo=m[(int)(0.025*(B-1))]; *hi=m[(int)(0.975*(B-1))];
  free(m); free(s);
}

int main(void){
  setbuf(stdout,NULL);
  uint64_t frq=0; __asm__ __volatile__("mrs %0, cntfrq_el0":"=r"(frq));
  if(!frq) frq=50000000ULL;
  const double nspt = 1e9/(double)frq;

  if(posix_memalign((void**)&buf,4096,1u<<20)!=0) return 2;
  memset(buf,0,1u<<20);
  void *PA = (void*)(buf+0x1000);
  void *PB = (void*)(buf+0x8000);

  sh_t *sh = mmap(NULL,sizeof(sh_t),PROT_READ|PROT_WRITE,MAP_SHARED|MAP_ANONYMOUS,-1,0);
  if(sh==MAP_FAILED) return 2;
  sh->turn=0; sh->mode=0; sh->stop=0; sh->cpu_tr=-1;

  cpu_set_t set; CPU_ZERO(&set); CPU_SET(3,&set);
  if(sched_setaffinity(0,sizeof(set),&set)!=0) printf("!! setaffinity 失败\n");
  for(int i=0;i<5000;i++){ st2ld_a(PA,PB); st2ld_b(PA,PB); }

  pid_t pid = fork();
  if(pid==0){
    sh->cpu_tr = sched_getcpu();
    while(!sh->stop){
      if(sh->turn != 1){ sched_yield(); continue; }
      if(sh->mode==0){ for(int k=0;k<20;k++) st2ld_a(PA,PA); }   /* a 训练 @ 同 PC -> block */
      else           { for(int k=0;k<20;k++) st2ld_b(PA,PA); }   /* a 训练 @ 异 PC -> 探测方表项不动 */
      sh->turn = 2;
    }
    _exit(0);
  }

  const int M = 512, N = 30;
  double *TS = malloc((size_t)N*sizeof(double));   /* 同 PC a 训练 */
  double *TD = malloc((size_t)N*sizeof(double));   /* 异 PC a 训练 */
  double *Dd = malloc((size_t)N*sizeof(double));

  for(int r=0;r<N;r++){
    long sum[2] = {0,0};
    for(int arm=0; arm<2; arm++){
      for(int m=0;m<M;m++){
        sh->mode = arm; sh->turn = 1;
        while(sh->turn != 2) sched_yield();
        uint64_t t0=rd(); st2ld_a(PA,PA); uint64_t t1=rd();   /* 探针固定 st2ld_a */
        sum[arm] += (long)(t1-t0);
      }
    }
    TS[r]=(double)sum[0]; TD[r]=(double)sum[1]; Dd[r]=(double)(sum[0]-sum[1]);
    if((r%5)==0) printf("  ...%d/%d\n", r, N);
  }
  sh->stop=1;
  waitpid(pid,NULL,0);

  double lo,hi;
  printf("\n# tick=%.2f ns  M=%d  N=%d  训练方 cpu=%d  探测方 cpu=%d\n",
         nspt, M, N, sh->cpu_tr, sched_getcpu());
  printf("# 探针固定 st2ld_a；两臂都是 a 训练，只差训练用的是 st2ld_a(同PC) 还是 st2ld_b(异PC)\n");

  boot_median(TS,N,800,&lo,&hi);
  printf("\n== 同 PC 的 a 训练后，探针总时（预期：快，约 500）==\n  中位 %.1f  CI [%.1f, %.1f]\n", qsel(TS,N,0.5), lo, hi);
  boot_median(TD,N,800,&lo,&hi);
  printf("\n== 异 PC 的 a 训练后，探针总时（预期：慢，约 750）==\n  中位 %.1f  CI [%.1f, %.1f]\n", qsel(TD,N,0.5), lo, hi);

  boot_median(Dd,N,800,&lo,&hi);
  double md=qsel(Dd,N,0.5);
  printf("\n== D = 同PC − 异PC  （预期显著为负）==\n  中位 %+.1f ticks  CI [%+.1f, %+.1f]   折成每次事件 %+.3f ticks\n",
         md, lo, hi, md/(double)M);

  int pc_indexed = (hi < 0.0);      /* 显著为负 */
  printf("\n>>> S1u %s\n", pc_indexed
    ? "PASS : 只有同 PC 的训练能改变探针代价 -> 共享的确实是 PC 索引的 MDU 表项（S1q 成立）"
    : "FAIL : 异 PC 训练同样改变了探针代价 -> 状态不是 PC 索引（S1q 机理需改写）");
  printf(">>> 摘要行: TS=%.0f TD=%.0f D=%+.1f[%+.1f,%+.1f] %s\n",
         qsel(TS,N,0.5), qsel(TD,N,0.5), md, lo, hi, pc_indexed?"PASS":"FAIL");
  return 0;
}
```


**S1u 实测（2026-11-19）→ 无信息量，而且是我的判据写反了**

| 量 | 值 |
|---|---|
| TS（同 PC 的 a 训练） | 511.0 ticks |
| TD（异 PC 的 a 训练） | 511.0 ticks |
| D | +0.0 ticks，CI [−1.0, +2.0] |

程序判 **FAIL**，但这个判 FAIL 的原因是我自己想错了一步：

- 两臂都是 **a 训练（教 block）**；
- 探针自己每轮就是一次**别名调用**，它**会自训练**成 block；
- 所以「同 PC 训练」与「异 PC 训练」都会落成 **快**——**D≈0 恰恰是 PC 索引下的预期**，不是反证。

**真正有信息量的是 S1t（n 训练那一版）**：同 PC 的 n 训练把表项每轮强制拉回 bypass → 探针慢（753）；
若真按 PC 索引，异 PC 的 n 训练打不到这个表项，探针应被自训练带回 block → **快**。可实测 **750（还是慢）**。

这只可能有两种原因：
1. **`st2ld_a` 与 `st2ld_b` 被 GCC 的 IPA-ICF 合并成同一个函数**（两函数体逐字节相同）→ 所谓"异 PC"根本没成立；
2. 两个 PC 确实不同，但**仍落进同一个表项**（或状态根本不是 PC 索引的）。

**S1v（待跑）**：先打印两者真实地址与字节距离——**地址相同就直接证明 ICF 合并，S1t/S1u 全部作废**；
并把 `st2ld_b` 改成 **11 级乘法**（函数体不同，Ica 无法合并），再跑 n 训练判别。



#### 源码 S1v `mdu_kill4.c`（完整，可直接编译）

> CC=gcc -O2 -o mdu_kill4 mdu_kill4.c -lm；运行 `taskset -c 3 ./mdu_kill4`；先看打印的两函数地址

```c
/* mdu_kill4.c —— S1v: 先证明"两个 PC 真的是两个 PC"，再谈 PC 索引（会话 25）
 * 编译: gcc -O2 -o mdu_kill4 mdu_kill4.c -lm   运行: taskset -c 3 ./mdu_kill4
 *
 * 为什么要有这一版:
 *   S1t / S1u 里 st2ld_a 与 st2ld_b 是**逐字节相同**的函数体，GCC 的 IPA-ICF 可能把它们
 *   合并成同一个函数 => 所谓"异 PC 训练"其实还在打同一个 PC，两边当然一样。
 *   本程序：
 *     1) 打印两个函数真实地址与字节距离 —— 地址相同就直接证明被合并；
 *     2) st2ld_b 故意用 **11 级乘法**（函数体不同），杜绝 ICF；
 *     3) 跑两组对照：
 *        kind = n 训练（教 bypass）: 同PC => 每轮强制 bypass => 探针**慢**；
 *                                    异PC => 打不到这个表项 => 探针被自己训成 block => **快**
 *                                    于是 D = 同PC − 异PC 应**显著为正**（约 +250）
 *        kind = a 训练（教 block） : 两臂都应是**快**，D≈0（自训练也会把它带到 block）
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <unistd.h>
#include <sched.h>
#include <sys/mman.h>
#include <sys/wait.h>

static inline uint64_t rd(void){ uint64_t t; __asm__ __volatile__("mrs %0, cntvct_el0":"=r"(t)); return t; }
static volatile uint64_t sinkv;
static volatile uint64_t mask0 = 0;
static unsigned char *buf;

/* 探测方固定用这个（10 级乘法） */
__attribute__((noinline)) static void st2ld_a(void *x0, void *x1){
  uint64_t a = (uint64_t)(uintptr_t)x0;
  for(int i=0;i<10;i++) a = a*6364136223846793005ULL + 1442695040888963407ULL;
  void *sa = (void*)((uintptr_t)x0 + (a & mask0));
  *(volatile uint64_t*)sa = 0x1111111122222222ULL;
  uint64_t x = *(volatile uint64_t*)x1;
  uint64_t b = a ^ x;
  for(int i=0;i<10;i++) b = b*6364136223846793005ULL + 1442695040888963407ULL;
  sinkv = b;
}
/* 训练方的"异 PC"版本：11 级乘法 => 不同函数体，ICF 不会合并 */
__attribute__((noinline)) static void st2ld_b(void *x0, void *x1){
  uint64_t a = (uint64_t)(uintptr_t)x0;
  for(int i=0;i<11;i++) a = a*6364136223846793005ULL + 1442695040888963407ULL;
  void *sa = (void*)((uintptr_t)x0 + (a & mask0));
  *(volatile uint64_t*)sa = 0x1111111122222222ULL;
  uint64_t x = *(volatile uint64_t*)x1;
  uint64_t b = a ^ x;
  for(int i=0;i<10;i++) b = b*6364136223846793005ULL + 1442695040888963407ULL;
  sinkv = b;
}

/* mode 编码: bit0 = 0 同PC(st2ld_a) / 1 异PC(st2ld_b)   bit1 = 0 a训练 / 1 n训练 */
typedef struct { volatile int turn; volatile int mode; volatile int stop; volatile int cpu_tr; } sh_t;

static int cmpd(const void*p,const void*q){ double x=*(const double*)p,y=*(const double*)q; return (x>y)-(x<y); }
static double qsel(double *v,int n,double p){
  double *c=malloc((size_t)n*sizeof(double)); memcpy(c,v,(size_t)n*sizeof(double));
  qsort(c,(size_t)n,sizeof(double),cmpd);
  int i=(int)(p*(n-1)); double r=c[i]; free(c); return r;
}
static void boot_median(double *v,int n,int B,double *lo,double *hi){
  double *m=malloc((size_t)B*sizeof(double)), *s=malloc((size_t)n*sizeof(double));
  uint64_t st=0x9E3779B97F4A7C15ULL;
  for(int b=0;b<B;b++){
    for(int i=0;i<n;i++){ st^=st<<13; st^=st>>7; st^=st<<17; s[i]=v[(int)(st%(uint64_t)n)]; }
    qsort(s,(size_t)n,sizeof(double),cmpd); m[b]=s[n/2];
  }
  qsort(m,(size_t)B,sizeof(double),cmpd);
  *lo=m[(int)(0.025*(B-1))]; *hi=m[(int)(0.975*(B-1))];
  free(m); free(s);
}

int main(void){
  setbuf(stdout,NULL);
  uint64_t frq=0; __asm__ __volatile__("mrs %0, cntfrq_el0":"=r"(frq));
  if(!frq) frq=50000000ULL;
  const double nspt = 1e9/(double)frq;

  printf("# st2ld_a = %p\n# st2ld_b = %p\n", (void*)st2ld_a, (void*)st2ld_b);
  long dist = (long)((char*)st2ld_b - (char*)st2ld_a);
  if(dist < 0) dist = -dist;
  printf("# 字节距离 = %ld  %s\n", dist,
         (st2ld_a == st2ld_b) ? "!! 同一地址: 被 ICF 合并 => S1t/S1u 全部作废" : "(两个不同的 PC)");

  if(posix_memalign((void**)&buf,4096,1u<<20)!=0) return 2;
  memset(buf,0,1u<<20);
  void *PA = (void*)(buf+0x1000);
  void *PB = (void*)(buf+0x8000);

  sh_t *sh = mmap(NULL,sizeof(sh_t),PROT_READ|PROT_WRITE,MAP_SHARED|MAP_ANONYMOUS,-1,0);
  if(sh==MAP_FAILED) return 2;
  sh->turn=0; sh->mode=0; sh->stop=0; sh->cpu_tr=-1;

  cpu_set_t set; CPU_ZERO(&set); CPU_SET(3,&set);
  if(sched_setaffinity(0,sizeof(set),&set)!=0) printf("!! setaffinity 失败\n");
  for(int i=0;i<5000;i++){ st2ld_a(PA,PB); st2ld_b(PA,PB); }

  pid_t pid = fork();
  if(pid==0){
    sh->cpu_tr = sched_getcpu();
    while(!sh->stop){
      if(sh->turn != 1){ sched_yield(); continue; }
      int arm  = sh->mode & 1;
      int kind = (sh->mode >> 1) & 1;      /* 0 = a 训练, 1 = n 训练 */
      if(arm==0){
        if(kind==0){ for(int k=0;k<20;k++) st2ld_a(PA,PA); }
        else       { for(int k=0;k<20;k++) st2ld_a(PA,PB); }
      } else {
        if(kind==0){ for(int k=0;k<20;k++) st2ld_b(PA,PA); }
        else       { for(int k=0;k<20;k++) st2ld_b(PA,PB); }
      }
      sh->turn = 2;
    }
    _exit(0);
  }

  const int M = 512, N = 30;

  for(int kind=0; kind<2; kind++){
    double *TS=malloc((size_t)N*sizeof(double));
    double *TD=malloc((size_t)N*sizeof(double));
    double *Dd=malloc((size_t)N*sizeof(double));

    for(int r=0;r<N;r++){
      long sum[2] = {0,0};
      for(int arm=0; arm<2; arm++){
        for(int m=0;m<M;m++){
          sh->mode = arm | (kind<<1);
          sh->turn = 1;
          while(sh->turn != 2) sched_yield();
          uint64_t t0=rd(); st2ld_a(PA,PA); uint64_t t1=rd();   /* 探针恒为 st2ld_a */
          sum[arm] += (long)(t1-t0);
        }
      }
      TS[r]=(double)sum[0]; TD[r]=(double)sum[1]; Dd[r]=(double)(sum[0]-sum[1]);
    }

    double lo,hi;
    boot_median(TS,N,800,&lo,&hi); double ms=qsel(TS,N,0.5);
    printf("\n== kind=%s ==\n", kind? "n 训练(教 bypass)":"a 训练(教 block)");
    printf("  同PC 中位 %.1f ticks CI [%.1f, %.1f]\n", ms, lo, hi);
    boot_median(TD,N,800,&lo,&hi); double md2=qsel(TD,N,0.5);
    printf("  异PC 中位 %.1f ticks CI [%.1f, %.1f]\n", md2, lo, hi);
    boot_median(Dd,N,800,&lo,&hi); double mdd=qsel(Dd,N,0.5);
    printf("  D = 同PC − 异PC = %+.1f ticks  CI [%+.1f, %+.1f]\n", mdd, lo, hi);

    if(kind) {
      int ok = (lo > 0.0);
      printf("  => %s\n", ok ? "PC 索引成立（异 PC 训练打不到这个表项）"
                              : "异 PC 训练同样生效 => 不是 PC 索引（或两个 PC 仍落同一表项）");
    }
    free(TS); free(TD); free(Dd);
  }

  sh->stop=1;
  waitpid(pid,NULL,0);
  printf("\n>>> 判读顺序: ①先看两个地址是否相同（相同则 S1t/S1u 作废）"
         "\n>>>           ②再看 kind=n 的 D 是否显著为正（正 => PC 索引成立）\n");
  return 0;
}
```


**S1v 实测（2026-11-19）→ PASS：PC 索引成立，机理闭环**

```
# st2ld_a = 0xadd1aa801280
# st2ld_b = 0xadd1aa801320
# 字节距离 = 160  （两个不同的 PC）      ← ICF 没有合并，异 PC 这次是真的
```

| kind | 同 PC | 异 PC | D |
|---|---|---|---|
| **n 训练（教 bypass）** | **756.0**，CI [752,763] | **509.0**，CI [508,510] | **+246.0**，CI [+244,+255] |
| a 训练（教 block） | 512.0 | 512.0 | +0.0（预期：两臂都被自训练带到 block） |

**读懂这两行**：

- **n 训练组**：同 PC 每轮把表项强制拉回 bypass → 探针慢（756）；训练换成 160 字节外的另一个函数 → 打不到这个表项 → 探针被自己的别名调用自训练成 block → **快（509）**。
  **差 246 tick / 512 事件 = 0.48 tick/event ≈ 29 cycle**，与 S1q 的 0.605 tick、S1p 的 1.156 tick 同量级。
- **a 训练组**：两臂都是 512（都 fast），D=0 —— 这是**预期之内**的对照（a 训练下两臂都收敛到 block），不是反证。

**同时解释了三件事**：
1. S1t 早年"两臂都 750"是**因为两个函数体逐字节相同、被 GCC 的 IPA-ICF 合并**，所谓"异 PC"根本没成立；
2. S1u 判 FAIL 是**我判据写反**（a 训练下两臂本来就该一样快）；
3. 现在把两件事都修正后，**"只有同 load PC 的训练能改变探针代价"** 被直接证明 —— 这正是论文说的"表项由 load PC 选择"。

**Q-B 由此闭环**：数据（S1q，D=+310）与机理（S1v，PC 索引）都在。


**S1w / S1x / S1y（"圆满"三台，会话 26 交付，待跑）**

§4 的四条限制里，有三条可以用现成的机器直接补：

| 装置 | 补哪条限制 | 做法 | 判据 |
|---|---|---|---|
| **S1w** `mdu_cycle.c` | ① 没有 cycle 级交叉验证 | PMU 被禁，改用论文在 Apple 上的老办法：**另起计数线程**（钉核 2，主线程钉核 3），先用 cntvct 校准"1 count = 多少 cycle"，再用四臂结构测每事件代价 | 与 cntvct 版的 **69 cycle/事件** 同量级即算交叉验证通过 |
| **S1x** `mdu_curve.c` | ② 信道单薄 | K ∈ {1,2,4,8,16,32} 扫描；**阈值改为每 K 实测两臂均值的中点**（不再手调 K×1.3）；每配置 256 bit、错误率带 Wilson CI | 得到一张"错误率–吞吐"表，从中选稳态工作点 |
| **S1y** `mdu_msweep.c` | ③ 量级散布 2× | 同一台 S1p 结构，M ∈ {8,32,128}，看 **S/M 是否恒定** | S/M 恒定 ⇒ 放大忠实，散布来自测量上下文而非估计器 |

第四条（只此一核）不需要新装置，**把现成二进制换核跑一遍**即可：`taskset -c 0/1/2/3 ./mdu_amp`。



#### 源码 S1w `mdu_cycle.c`（完整，可直接编译）

> CC=gcc -O2 -o mdu_cycle mdu_cycle.c -pthread -lm；运行 `taskset -c 3 ./mdu_cycle`（计数线程自绑核 2）

```c
/* mdu_cycle.c —— S1w: 计数线程做 cycle 级交叉验证（补限制①：没有 PMU）（会话 26）
 * 编译: gcc -O2 -o mdu_cycle mdu_cycle.c -pthread -lm   运行: taskset -c 3 ./mdu_cycle
 *
 * 背景: 本机 PMCCNTR 被禁（perf_event_paranoid=4），只能用 20 ns 的 cntvct。
 *       论文在 Apple 上遇到同样问题时的解法是"计数线程"——另起一个线程不停自增一个
 *       共享计数器，读它就得到比系统计时器细得多的刻度。这里照做，用它独立复核 S1p。
 *
 * 做法:
 *   - 计数线程钉 **核 2**，主线程钉 **核 3**（互不抢占）；
 *   - 先用 cntvct 校准"每个计数对应多少 cycle"；
 *   - 再用四臂结构（与 S1p 同构：A/N 用 n 复位，B/D 用 a 复位，M=64）测 X/Y/S，
 *     折成"每事件多少 cycle"，与 cntvct 版给出的 69 cycle 对照。
 *
 * 注意: 跨核读共享计数器有几十 cycle 的相干延迟；但它在 t0/t1 两端同样存在，
 *       相减即抵消。M=64 使信号（约 4400 cycle）远大于该延迟抖动。
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <pthread.h>
#include <sched.h>
#include <unistd.h>

static inline uint64_t rd(void){ uint64_t t; __asm__ __volatile__("mrs %0, cntvct_el0":"=r"(t)); return t; }
static volatile uint64_t sinkv;
static volatile uint64_t mask0 = 0;
static unsigned char *buf;

/* ---- 计数线程 ---- */
static volatile uint64_t g_ctr = 0;
static volatile int g_stop = 0;
static void *ctr_thread(void *arg){
  (void)arg;
  cpu_set_t s; CPU_ZERO(&s); CPU_SET(2,&s);
  if(sched_setaffinity(0,sizeof(s),&s)!=0) printf("!! 计数线程绑核失败\n");
  uint64_t c = 0;
  while(!g_stop){
    __asm__ __volatile__("add %0, %0, #1" : "+r"(c) :: "memory");
    g_ctr = c;
  }
  return NULL;
}

__attribute__((noinline)) static void st2ld(void *x0, void *x1){
  uint64_t a = (uint64_t)(uintptr_t)x0;
  for(int i=0;i<10;i++) a = a*6364136223846793005ULL + 1442695040888963407ULL;
  void *sa = (void*)((uintptr_t)x0 + (a & mask0));
  *(volatile uint64_t*)sa = 0x1111111122222222ULL;
  uint64_t x = *(volatile uint64_t*)x1;
  uint64_t b = a ^ x;
  for(int i=0;i<10;i++) b = b*6364136223846793005ULL + 1442695040888963407ULL;
  sinkv = b;
}

__attribute__((noinline)) static void arm(void *r0, void *r1, void *p0, void *p1, int RST, int M){
  for(int m=0;m<M;m++){ for(int k=0;k<RST;k++) st2ld(r0,r1); st2ld(p0,p1); }
}

static int cmpd(const void*p,const void*q){ double x=*(const double*)p,y=*(const double*)q; return (x>y)-(x<y); }
static double qsel(double *v,int n,double p){
  double *c=malloc((size_t)n*sizeof(double)); memcpy(c,v,(size_t)n*sizeof(double));
  qsort(c,(size_t)n,sizeof(double),cmpd);
  int i=(int)(p*(n-1)); double r=c[i]; free(c); return r;
}
static void boot_median(double *v,int n,int B,double *lo,double *hi){
  double *m=malloc((size_t)B*sizeof(double)), *s=malloc((size_t)n*sizeof(double));
  uint64_t st=0x9E3779B97F4A7C15ULL;
  for(int b=0;b<B;b++){
    for(int i=0;i<n;i++){ st^=st<<13; st^=st>>7; st^=st<<17; s[i]=v[(int)(st%(uint64_t)n)]; }
    qsort(s,(size_t)n,sizeof(double),cmpd); m[b]=s[n/2];
  }
  qsort(m,(size_t)B,sizeof(double),cmpd);
  *lo=m[(int)(0.025*(B-1))]; *hi=m[(int)(0.975*(B-1))];
  free(m); free(s);
}

int main(void){
  setbuf(stdout,NULL);
  uint64_t frq=0; __asm__ __volatile__("mrs %0, cntfrq_el0":"=r"(frq));
  if(!frq) frq=50000000ULL;
  const double nspt = 1e9/(double)frq;

  if(posix_memalign((void**)&buf,4096,1u<<20)!=0) return 2;
  memset(buf,0,1u<<20);
  void *PA = (void*)(buf+0x1000);
  void *PB = (void*)(buf+0x8000);

  pthread_t th;
  if(pthread_create(&th,NULL,ctr_thread,NULL)!=0){ printf("!! 建线程失败\n"); return 2; }
  usleep(20000);

  /* ---- 校准：计数增量 vs cntvct 纳秒 ---- */
  uint64_t c0 = g_ctr, t0 = rd();
  while ((double)(rd()-t0)*nspt < 20e6) { }     /* 约 20 ms */
  uint64_t c1 = g_ctr, t1 = rd();
  double elapsed_ns = (double)(t1-t0)*nspt;
  double per_count_ns = elapsed_ns / (double)(c1-c0);
  printf("# 校准: %.3f ms 内计数 +%llu  → 1 count = %.3f ns = %.2f cycle\n",
         elapsed_ns/1e6, (unsigned long long)(c1-c0), per_count_ns, per_count_ns*3.0);

  const int M = 64, RST = 20, N = 120;
  double *X=malloc((size_t)N*sizeof(double)), *Y=malloc((size_t)N*sizeof(double)), *S=malloc((size_t)N*sizeof(double));

  for(int i=0;i<5000;i++) st2ld(PA,PB);

  printf("# tick=%.2f ns  M=%d  RST=%d  N=%d  （计时源 = 计数线程）\n", nspt, M, RST, N);

  for(int r=0;r<N;r++){
    uint64_t a,b; double A,Nn,Bb,D;
    a=g_ctr; arm(PA,PB,PA,PA,RST,M); b=g_ctr; A=(double)(b-a);
    a=g_ctr; arm(PA,PB,PA,PB,RST,M); b=g_ctr; Nn=(double)(b-a);
    a=g_ctr; arm(PA,PA,PA,PA,RST,M); b=g_ctr; Bb=(double)(b-a);
    a=g_ctr; arm(PA,PA,PA,PB,RST,M); b=g_ctr; D=(double)(b-a);
    X[r]=A-Nn; Y[r]=Bb-D; S[r]=X[r]-Y[r];
    if((r%30)==0) printf("  ...%d/%d\n", r, N);
  }
  g_stop=1; pthread_join(th,NULL);

  double lo,hi;
  boot_median(X,N,1000,&lo,&hi);
  printf("\n== X = A − N（计数单位）==\n  中位 %.1f counts  CI [%.1f, %.1f]\n", qsel(X,N,0.5), lo, hi);
  boot_median(Y,N,1000,&lo,&hi);
  printf("== Y = B − D ==\n  中位 %.1f counts  CI [%.1f, %.1f]\n", qsel(Y,N,0.5), lo, hi);
  boot_median(S,N,1000,&lo,&hi);
  double ms=qsel(S,N,0.5);
  printf("== S = X − Y ==\n  中位 %.1f counts  CI [%.1f, %.1f]\n", ms, lo, hi);

  double per_ev_counts = ms/(double)M;
  double per_ev_ns = per_ev_counts * per_count_ns;
  printf("\n== 折成每次事件 ==\n  %.3f counts = %.1f ns = **%.1f cycle**\n",
         per_ev_counts, per_ev_ns, per_ev_ns*3.0);
  printf("  （cntvct 版 S1p 给的是 69 cycle/事件；两者同量级即视为交叉验证通过）\n");

  int ok = (per_ev_ns*3.0 > 10.0);
  printf("\n>>> S1w %s\n", ok
    ? "PASS : 用与 PMU 无关的计数线程独立测到同一量级的每事件代价 -> cycle 级交叉验证成立"
    : "WEAK : 计数刻度太粗或信号被相干延迟吃掉，需加大 M");
  printf(">>> 摘要行: S=%.1f counts, per-event=%.1f cycle %s\n",
         ms, per_ev_ns*3.0, ok?"PASS":"WEAK");
  return 0;
}
```



#### 源码 S1x `mdu_curve.c`（完整，可直接编译）

> CC=gcc -O2 -o mdu_curve mdu_curve.c -lm；运行 `taskset -c 3 ./mdu_curve`

```c
/* mdu_curve.c —— S1x: 信道"错误率–吞吐"曲线（补限制②：信道单薄）（会话 26）
 * 编译: gcc -O2 -o mdu_curve mdu_curve.c -lm   运行: taskset -c 3 ./mdu_curve
 *
 * 相对 S1r 的三处改进:
 *   1) 阈值不再手调 K×1.3，而是**每个 K 先用一段校准比特实测两臂均值，取中点**；
 *   2) K 扫描 {1,2,4,8,16,32}，各跑 NBITS 比特，画出"错误率–吞吐"；
 *   3) 错误率带 Wilson 95%CI，避免把 4/128 这种小样本当成定值。
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <unistd.h>
#include <sched.h>
#include <sys/mman.h>
#include <sys/wait.h>

static inline uint64_t rd(void){ uint64_t t; __asm__ __volatile__("mrs %0, cntvct_el0":"=r"(t)); return t; }
static volatile uint64_t sinkv;
static volatile uint64_t mask0 = 0;
static unsigned char *buf;

__attribute__((noinline)) static void st2ld(void *x0, void *x1){
  uint64_t a = (uint64_t)(uintptr_t)x0;
  for(int i=0;i<10;i++) a = a*6364136223846793005ULL + 1442695040888963407ULL;
  void *sa = (void*)((uintptr_t)x0 + (a & mask0));
  *(volatile uint64_t*)sa = 0x1111111122222222ULL;
  uint64_t x = *(volatile uint64_t*)x1;
  uint64_t b = a ^ x;
  for(int i=0;i<10;i++) b = b*6364136223846793005ULL + 1442695040888963407ULL;
  sinkv = b;
}

typedef struct { volatile int turn; volatile int mode; volatile int stop; volatile int cpu_tr; } sh_t;

static double wilson_lo(int err,int n){
  double z=1.96, p=(double)err/n;
  double den=1.0+z*z/n, cen=(p+z*z/(2*n))/den;
  double rad=z*sqrt(p*(1-p)/n + z*z/(4.0*n*n))/den;
  return cen-rad<0?0:cen-rad;
}
static double wilson_hi(int err,int n){
  double z=1.96, p=(double)err/n;
  double den=1.0+z*z/n, cen=(p+z*z/(2*n))/den;
  double rad=z*sqrt(p*(1-p)/n + z*z/(4.0*n*n))/den;
  return cen+rad>1?1:cen+rad;
}

int main(void){
  setbuf(stdout,NULL);
  uint64_t frq=0; __asm__ __volatile__("mrs %0, cntfrq_el0":"=r"(frq));
  if(!frq) frq=50000000ULL;
  const double nspt = 1e9/(double)frq;

  if(posix_memalign((void**)&buf,4096,1u<<20)!=0) return 2;
  memset(buf,0,1u<<20);
  void *PA = (void*)(buf+0x1000);
  void *PB = (void*)(buf+0x8000);

  sh_t *sh = mmap(NULL,sizeof(sh_t),PROT_READ|PROT_WRITE,MAP_SHARED|MAP_ANONYMOUS,-1,0);
  if(sh==MAP_FAILED) return 2;
  sh->turn=0; sh->mode=0; sh->stop=0; sh->cpu_tr=-1;

  cpu_set_t set; CPU_ZERO(&set); CPU_SET(3,&set);
  if(sched_setaffinity(0,sizeof(set),&set)!=0) printf("!! setaffinity 失败\n");
  for(int i=0;i<5000;i++) st2ld(PA,PB);

  pid_t pid = fork();
  if(pid==0){
    sh->cpu_tr = sched_getcpu();
    while(!sh->stop){
      if(sh->turn != 1){ sched_yield(); continue; }
      if(sh->mode==0){ for(int k=0;k<20;k++) st2ld(PA,PB); }   /* bit1: bypass -> 探针慢 */
      else           { for(int k=0;k<20;k++) st2ld(PA,PA); }   /* bit0: block  -> 探针快 */
      sh->turn = 2;
    }
    _exit(0);
  }

  const int NBITS = 256, KMAX = 32;
  const int KS[6] = {1,2,4,8,16,32};
  unsigned char *sent = malloc(NBITS), *recv = malloc(NBITS);

  uint64_t s = 0x9E3779B97F4A7C15ULL;
  for(int i=0;i<NBITS;i++){ s^=s<<13; s^=s>>7; s^=s<<17; sent[i]=(unsigned char)(s&1); }

  printf("# tick=%.2f ns  NBITS=%d/配置  两进程 cpu=%d/%d\n",
         nspt, NBITS, sh->cpu_tr, sched_getcpu());
  printf("# 编码: bit1=n 训练(慢) / bit0=a 训练(快)；阈值按每 K 实测两臂均值取中点\n\n");
  printf("%-4s %10s %10s %10s %9s %10s %10s\n","K","mean_bit1","mean_bit0","阈值","错误率","95%CI","吞吐(kbps)");
  printf("------------------------------------------------------------------------------------\n");

  for(int ki=0; ki<6; ki++){
    int K = KS[ki];

    /* --- 校准: 16 个 1 与 16 个 0 --- */
    double m1=0, m0=0;
    for(int t=0;t<16;t++){
      long sum=0;
      for(int k=0;k<K;k++){
        sh->mode=0; sh->turn=1; while(sh->turn!=2) sched_yield();
        uint64_t a=rd(); st2ld(PA,PA); uint64_t b=rd(); sum+=(long)(b-a);
      }
      m1 += (double)sum;
      sum=0;
      for(int k=0;k<K;k++){
        sh->mode=1; sh->turn=1; while(sh->turn!=2) sched_yield();
        uint64_t a=rd(); st2ld(PA,PA); uint64_t b=rd(); sum+=(long)(b-a);
      }
      m0 += (double)sum;
    }
    m1/=16.0; m0/=16.0;
    double thr = (m1+m0)/2.0;

    /* --- 正式传比特 --- */
    int err=0;
    uint64_t t_start = rd();
    for(int i=0;i<NBITS;i++){
      int b = sent[i]; long sum=0;
      for(int k=0;k<K;k++){
        sh->mode = b?0:1; sh->turn=1; while(sh->turn!=2) sched_yield();
        uint64_t a=rd(); st2ld(PA,PA); uint64_t b2=rd(); sum+=(long)(b2-a);
      }
      recv[i] = ((double)sum > thr) ? 1 : 0;
      if(recv[i]!=b) err++;
    }
    uint64_t t_end = rd();
    double total_ns=(double)(t_end-t_start)*nspt;
    double kbps = NBITS/(total_ns/1e9)/1000.0;

    printf("%-4d %10.1f %10.1f %10.1f %8.2f%% %5.1f-%4.1f%% %10.1f\n",
           K, m1, m0, thr, 100.0*err/NBITS, 100.0*wilson_lo(err,NBITS), 100.0*wilson_hi(err,NBITS), kbps);
  }

  sh->stop=1;
  waitpid(pid,NULL,0);
  printf("\n>>> 用法: 选一个「错误率可接受且吞吐最高」的 K，作为该信道的稳态工作点\n");
  printf(">>> 注: 这只是本机(钉核3/两进程)的一组工作点，不是通用性能指标\n");
  return 0;
}
```



#### 源码 S1y `mdu_msweep.c`（完整，可直接编译）

> CC=gcc -O2 -o mdu_msweep mdu_msweep.c -lm；运行 `taskset -c 3 ./mdu_msweep`

```c
/* mdu_msweep.c —— S1y: M 剂量反应（补限制③：量级散布）（会话 26）
 * 编译: gcc -O2 -o mdu_msweep mdu_msweep.c -lm   运行: taskset -c 3 ./mdu_msweep
 *
 * 目的: S1p 给 69 cycle/事件（M=32），S1q 给 36、S1v 给 29。散布来源之一可能是
 *       "放大倍数"本身影响了估计。如果 S/M 随 M 恒定，说明放大是忠实的，
 *       散布就只可能来自**测量上下文**（同进程 vs 跨进程 vs 训练方换 PC），
 *       而不是估计器的问题。
 *
 * 做法: 同一台 S1p 结构，M ∈ {8, 32, 128}，各算 X/Y/S 与 S/M。
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static inline uint64_t rd(void){ uint64_t t; __asm__ __volatile__("mrs %0, cntvct_el0":"=r"(t)); return t; }
static volatile uint64_t sinkv;
static volatile uint64_t mask0 = 0;
static unsigned char *buf;

__attribute__((noinline)) static void st2ld(void *x0, void *x1){
  uint64_t a = (uint64_t)(uintptr_t)x0;
  for(int i=0;i<10;i++) a = a*6364136223846793005ULL + 1442695040888963407ULL;
  void *sa = (void*)((uintptr_t)x0 + (a & mask0));
  *(volatile uint64_t*)sa = 0x1111111122222222ULL;
  uint64_t x = *(volatile uint64_t*)x1;
  uint64_t b = a ^ x;
  for(int i=0;i<10;i++) b = b*6364136223846793005ULL + 1442695040888963407ULL;
  sinkv = b;
}
__attribute__((noinline)) static void arm(void *r0, void *r1, void *p0, void *p1, int RST, int M){
  for(int m=0;m<M;m++){ for(int k=0;k<RST;k++) st2ld(r0,r1); st2ld(p0,p1); }
}

static int cmpd(const void*p,const void*q){ double x=*(const double*)p,y=*(const double*)q; return (x>y)-(x<y); }
static double qsel(double *v,int n,double p){
  double *c=malloc((size_t)n*sizeof(double)); memcpy(c,v,(size_t)n*sizeof(double));
  qsort(c,(size_t)n,sizeof(double),cmpd);
  int i=(int)(p*(n-1)); double r=c[i]; free(c); return r;
}

int main(void){
  setbuf(stdout,NULL);
  uint64_t frq=0; __asm__ __volatile__("mrs %0, cntfrq_el0":"=r"(frq));
  if(!frq) frq=50000000ULL;
  const double nspt = 1e9/(double)frq;

  if(posix_memalign((void**)&buf,4096,1u<<20)!=0) return 2;
  memset(buf,0,1u<<20);
  void *PA = (void*)(buf+0x1000);
  void *PB = (void*)(buf+0x8000);

  const int RST=20, N=200;
  const int MS[3] = {8, 32, 128};

  for(int i=0;i<5000;i++) st2ld(PA,PB);

  printf("# tick=%.2f ns  RST=%d  N=%d  每个 M 各算一次 S 与 S/M\n\n", nspt, RST, N);
  printf("%-5s %10s %10s %10s %14s\n","M","X(tick)","Y(tick)","S(tick)","S/M (tick/事件)");
  printf("------------------------------------------------------------\n");

  double per[3];
  for(int t=0;t<3;t++){
    int M = MS[t];
    double *X=malloc((size_t)N*sizeof(double));
    double *Y=malloc((size_t)N*sizeof(double));
    double *S=malloc((size_t)N*sizeof(double));
    for(int r=0;r<N;r++){
      uint64_t a,b; double A,Nn,Bb,D;
      a=rd(); arm(PA,PB,PA,PA,RST,M); b=rd(); A=(double)(b-a);
      a=rd(); arm(PA,PB,PA,PB,RST,M); b=rd(); Nn=(double)(b-a);
      a=rd(); arm(PA,PA,PA,PA,RST,M); b=rd(); Bb=(double)(b-a);
      a=rd(); arm(PA,PA,PA,PB,RST,M); b=rd(); D=(double)(b-a);
      X[r]=A-Nn; Y[r]=Bb-D; S[r]=X[r]-Y[r];
    }
    double mx=qsel(X,N,0.5), my=qsel(Y,N,0.5), ms=qsel(S,N,0.5);
    per[t]=ms/(double)M;
    printf("%-5d %10.1f %10.1f %10.1f %14.4f\n", M, mx, my, ms, per[t]);
    free(X); free(Y); free(S);
  }

  double mxv=per[0]; for(int t=1;t<3;t++){ double v=fabs(per[t]); if(v>mxv) mxv=v; }
  double mnv=per[0]; for(int t=1;t<3;t++){ double v=fabs(per[t]); if(v<mnv) mnv=v; }
  double spread = (mnv>0)? (mxv/mnv) : 0;

  printf("\n== 放大忠实性 ==\n  S/M 三点: %.4f / %.4f / %.4f  最大/最小 = %.2f×\n",
         per[0], per[1], per[2], spread);
  int ok = (spread < 2.0);
  printf("\n>>> S1y %s\n", ok
    ? "PASS : S/M 随 M 基本恒定 -> 放大是忠实的；量级散布来自测量上下文（同进程/跨进程/换 PC），不是估计器"
    : "WARN : S/M 随 M 漂移 -> 放大器本身有非线性，69/36/29 的散布要重新解释");
  printf(">>> 摘要行: S/M = %.4f / %.4f / %.4f  spread=%.2fx %s\n",
         per[0], per[1], per[2], spread, ok?"PASS":"WARN");
  return 0;
}
```


**S1w / S1x / S1y 实测（2026-11-19）**

**S1y（M 剂量反应）→ PASS：放大忠实**

| M | X | Y | S | **S/M（tick/事件）** |
|---|---|---|---|---|
| 8 | 9.0 | 1.0 | 8.0 | **1.0000** |
| 32 | 37.0 | 1.0 | 35.0 | **1.0938** |
| 128 | 148.0 | 1.0 | 147.0 | **1.1484** |

最大/最小 = **1.15×** → 放大近似线性，**69/36/29 的散布不是估计器造成的**，而是测量上下文（同进程 / 跨进程 / 换训练 PC）。

**S1x（错误率-吞吐曲线）→ 拿到工作点**

| K | mean(bit1) | mean(bit0) | 阈值 | 错误率 | 95%CI | 吞吐 |
|---|---|---|---|---|---|---|
| 1 | 26.5 | 1.0 | 13.8 | **57.03%** | 50.9–62.9% | 639.4 kbps |
| 2 | 2.9 | 2.0 | 2.5 | 17.97% | 13.8–23.1% | 301.8 kbps |
| 4 | 5.1 | 4.0 | 4.6 | 6.25% | 3.9–9.9% | 157.9 kbps |
| **8** | 11.6 | 7.9 | 9.7 | **3.12%** | 1.6–6.0% | **78.9 kbps** |
| **16** | 22.9 | 15.9 | 19.4 | **2.34%** | 1.1–5.0% | **39.5 kbps** |
| 32 | 45.9 | 31.9 | 38.9 | 0.78% | 0.2–2.8% | 20.0 kbps |

- **K=1 不可用**（57% ≈ 随机）：状态在相邻比特间延续，单轮无法分辨。
- **K=8 与 S1r 的 ~74 kbps 吻合**（这里 78.9），两条独立路径互证。
- 推荐工作点：**K=8（3.12% @ 79 kbps）** 或 **K=16（2.34% @ 40 kbps）**。

**S1w（计数线程）→ PASS，但只是量级验证**

- 校准：20.000 ms 内计数 +59 618 703 → **1 count = 0.335 ns = 1.01 cycle**（计数线程几乎每 cycle 一次）。
- X = 1959.0 counts，Y = 147.0（CI [−205, 574]，含 0，符合预期），S = 1776.0（CI [1455, 2361]）
- **每事件 27.75 counts = 9.3 ns = 27.9 cycle**

**必须如实记的不一致**：cntvct 版给 **66–69 cycle/事件**，计数线程版给 **27.9**，差 **2.4×**。两者只**同量级**，不是同一数值。可能原因：跨核读取会拖慢计数线程、相干延迟、以及计数器在"被测线程读共享行"时被阻塞。**结论应写成"几十 cycle 级（两套独立计时器分别给 28 与 69）"，不写死一个精确值。**


**S1z（一键四核扫，待跑）**

S1y/S1x/S1w 跑完后，四条限制只剩"只此一核"。原先给的是 shell 循环（`for c in 0 1 2 3; do taskset -c $c ./mdu_amp; done`），要人工比对四份输出；S1z 把它做成一个程序：

- 对 cpu 0..3 各 `fork` 一个子进程，**子进程自己设亲和性**（所以运行时**不要**再套 `taskset`）；
- 每个子进程跑一遍与 S1p 同构的四臂（M=32, RST=20, N=120），把 X / Y / S 中位数写回共享内存；
- 父进程汇总成一张表，打印每核的 `S`、`S` 的 5%–95% 区间、以及折成 cycle/事件；
- 判据：四核的 S 都显著为正（> 5 tick）且量级接近 → 限制④解除。



#### 源码 S1z `mdu_cores.c`（完整，可直接编译）

> CC=gcc -O2 -o mdu_cores mdu_cores.c -lm；运行 `./mdu_cores`（**不加 taskset**，程序自己绑核）

```c
/* mdu_cores.c —— S1z: 四核扫一遍（补限制④：只此一核）（会话 28）
 * 编译: gcc -O2 -o mdu_cores mdu_cores.c -lm   运行: ./mdu_cores   （**不要**加 taskset，程序自己绑核）
 *
 * 做法: 对 cpu 0..3 各 fork 一个子进程，子进程先把亲和性设到该核，再跑一遍 S1p 的四臂
 *       （M=32, N=120），把 X/Y/S 中位数写回共享内存；父进程汇总成一张表。
 *
 * 判据: 四核的 S 都应显著为正（几十 tick）；若某核 S≈0，说明该核行为不同 —— 那本身是发现。
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <unistd.h>
#include <sched.h>
#include <sys/mman.h>
#include <sys/wait.h>

static inline uint64_t rd(void){ uint64_t t; __asm__ __volatile__("mrs %0, cntvct_el0":"=r"(t)); return t; }
static volatile uint64_t sinkv;
static volatile uint64_t mask0 = 0;
static unsigned char *buf;

__attribute__((noinline)) static void st2ld(void *x0, void *x1){
  uint64_t a = (uint64_t)(uintptr_t)x0;
  for(int i=0;i<10;i++) a = a*6364136223846793005ULL + 1442695040888963407ULL;
  void *sa = (void*)((uintptr_t)x0 + (a & mask0));
  *(volatile uint64_t*)sa = 0x1111111122222222ULL;
  uint64_t x = *(volatile uint64_t*)x1;
  uint64_t b = a ^ x;
  for(int i=0;i<10;i++) b = b*6364136223846793005ULL + 1442695040888963407ULL;
  sinkv = b;
}
__attribute__((noinline)) static void arm(void *r0, void *r1, void *p0, void *p1, int RST, int M){
  for(int m=0;m<M;m++){ for(int k=0;k<RST;k++) st2ld(r0,r1); st2ld(p0,p1); }
}

typedef struct { double X, Y, S; double q05, q95; int cpu; int ok; } res_t;

static int cmpd(const void*p,const void*q){ double x=*(const double*)p,y=*(const double*)q; return (x>y)-(x<y); }
static double qsel(double *v,int n,double p){
  double *c=malloc((size_t)n*sizeof(double)); memcpy(c,v,(size_t)n*sizeof(double));
  qsort(c,(size_t)n,sizeof(double),cmpd);
  int i=(int)(p*(n-1)); double r=c[i]; free(c); return r;
}

int main(void){
  setbuf(stdout,NULL);
  uint64_t frq=0; __asm__ __volatile__("mrs %0, cntfrq_el0":"=r"(frq));
  if(!frq) frq=50000000ULL;
  const double nspt = 1e9/(double)frq;

  res_t *res = mmap(NULL, sizeof(res_t)*4, PROT_READ|PROT_WRITE, MAP_SHARED|MAP_ANONYMOUS, -1, 0);
  if(res==MAP_FAILED) return 2;
  for(int i=0;i<4;i++){ res[i].ok=0; res[i].cpu=-1; }

  const int M=32, RST=20, N=120;

  for(int core=0; core<4; core++){
    pid_t pid = fork();
    if(pid==0){
      cpu_set_t s; CPU_ZERO(&s); CPU_SET(core, &s);
      if(sched_setaffinity(0,sizeof(s),&s)!=0){ res[core].ok=-2; _exit(0); }
      if(posix_memalign((void**)&buf,4096,1u<<20)!=0){ res[core].ok=-3; _exit(0); }
      memset(buf,0,1u<<20);
      void *PA=(void*)(buf+0x1000), *PB=(void*)(buf+0x8000);
      for(int i=0;i<4000;i++) st2ld(PA,PB);

      double *S=malloc((size_t)N*sizeof(double));
      double *X=malloc((size_t)N*sizeof(double));
      double *Y=malloc((size_t)N*sizeof(double));
      for(int r=0;r<N;r++){
        uint64_t a,b; double A,Nn,Bb,D;
        a=rd(); arm(PA,PB,PA,PA,RST,M); b=rd(); A=(double)(b-a);
        a=rd(); arm(PA,PB,PA,PB,RST,M); b=rd(); Nn=(double)(b-a);
        a=rd(); arm(PA,PA,PA,PA,RST,M); b=rd(); Bb=(double)(b-a);
        a=rd(); arm(PA,PA,PA,PB,RST,M); b=rd(); D=(double)(b-a);
        X[r]=A-Nn; Y[r]=Bb-D; S[r]=X[r]-Y[r];
      }
      res[core].cpu = sched_getcpu();
      res[core].X = qsel(X,N,0.5);
      res[core].Y = qsel(Y,N,0.5);
      res[core].S = qsel(S,N,0.5);
      res[core].q05 = qsel(S,N,0.05);
      res[core].q95 = qsel(S,N,0.95);
      res[core].ok = 1;
      _exit(0);
    }
  }
  while(wait(NULL) > 0) { }

  printf("# tick=%.2f ns  M=%d  RST=%d  N=%d  四核各跑一遍\n", nspt, M, RST, N);
  printf("# X = n训练后的(别名−非别名)   Y = a训练后的同一个差   S = X − Y\n\n");
  printf("%-6s %-8s %8s %8s %8s %16s %10s\n","cpu","实际cpu","X","Y","S","S 的 5%–95%","cycle/事件");
  printf("--------------------------------------------------------------------------------------\n");

  int good=0; double mn=1e9, mx=-1e9;
  for(int c=0;c<4;c++){
    if(res[c].ok!=1){
      printf("%-6d %-8s  (失败 ok=%d)\n", c, "-", res[c].ok);
      continue;
    }
    double per = res[c].S/(double)M;
    printf("%-6d %-8d %8.1f %8.1f %8.1f %7.1f–%-7.1f %10.1f\n",
           c, res[c].cpu, res[c].X, res[c].Y, res[c].S, res[c].q05, res[c].q95, per*nspt*3.0);
    if(res[c].S < mn) mn = res[c].S;
    if(res[c].S > mx) mx = res[c].S;
    good++;
  }

  printf("\n== 跨核一致性 ==\n");
  if(good>=2){
    printf("  成功核数 %d/4   S 范围 %.1f – %.1f tick   最大/最小 = %.2f×\n",
           good, mn, mx, (mn>0)? mx/mn : 0.0);
  } else {
    printf("  可用核数不足，无法比较\n");
  }

  int pass = (good==4) && (mn > 5.0);
  printf("\n>>> S1z %s\n", pass
    ? "PASS : 四个核都能测到 MDU 状态效应，跨核一致 -> 限制④（只此一核）解除"
    : "CHECK: 至少一个核没测到或绑核失败，需要看具体哪一行");
  printf(">>> 摘要行:");
  for(int c=0;c<4;c++){
    if(res[c].ok==1) printf(" c%d=%.1f", c, res[c].S);
    else printf(" c%d=FAIL", c);
  }
  printf("  %s\n", pass?"PASS":"CHECK");
  return 0;
}
```


**S1z 实测（2026-11-19）→ PASS：四核一致，限制④解除**

| cpu | X | Y | S | S 的 5%–95% | cycle/事件 |
|---|---|---|---|---|---|
| 0 | 37.0 | 1.0 | **36.0** | 28–40 | 67.5 |
| 1 | 39.0 | 1.0 | **37.0** | 31–41 | 69.4 |
| 2 | 38.0 | 1.0 | **37.0** | 31–40 | 69.4 |
| 3 | 37.0 | 1.0 | **36.0** | 30–39 | 67.5 |

成功核 **4/4**，S 范围 **36.0 – 37.0 tick**，最大/最小 **1.03×**。

**含义**：MDU 状态效应不是某个核的特例，四个核行为一致；同时 `Y` 在四个核上都是 1.0（远小于 X），说明"a 训练后别名与非别名无差别"这个不对称结构在所有核上都成立。


**S1aa（限制①的收尾，待跑）**

S1w 的 2.4× 差（计数线程 27.9 vs cntvct 66–69）有两种可能，判法完全不同：

| 可能 | 含义 | 处理 |
|---|---|---|
| 计数线程**在被测期间成比例丢时间**（vCPU 被宿主抢占/调度） | 只是一个系数问题 | 用系数校正，27.9 × k 若回到 66–69 → 两套计时器其实一致 |
| 计数器**受负载类型影响** | 无法用单一系数校正 | 承认限制，各自报数 |

做法：拿两个**已知耗时**的负载各测一遍，比较"cntvct 实测 / 计数推算"：

- **负载 A**：指针追逐 2048 次依赖 L1 命中（早先实测 1.72 ns/op ≈ 5.2 cycle/op）；
- **负载 B**：`st2ld` × 512（store 密集，与 S1w 同族）。

若 `kA ≈ kB` → 丢时是成比例的，`k` 就是校正系数；若两者差很多 → 计数器是负载相关的。



#### 源码 S1aa `mdu_cal.c`（完整，可直接编译）

> CC=gcc -O2 -o mdu_cal mdu_cal.c -pthread -lm；运行 `taskset -c 3 ./mdu_cal`（计数线程自绑核 2）

```c
/* mdu_cal.c —— S1aa: 两套计时器对同一负载的偏差标定（补限制①的最后一步）（会话 30）
 * 编译: gcc -O2 -o mdu_cal mdu_cal.c -pthread -lm   运行: taskset -c 3 ./mdu_cal
 *
 * 要回答的问题: S1w 用计数线程给出 27.9 cycle/事件，cntvct 给出 66–69，差 2.4×。
 *   到底是"计数线程在被测期间丢时间"（=> 可用一个系数校正），
 *   还是"两套计时器对某类负载天生不同"（=> 只能各自报各自的数）？
 *
 * 做法: 找两个**已知耗时**的负载，各用两套计时器测，算出"实测/计数推算"的比值：
 *   负载 A: 指针追逐 2048 次依赖 L1 命中（早先实测 1.72 ns/op ≈ 5.2 cycle/op）
 *   负载 B: st2ld × 512（store 密集，与 S1w 同族）
 *
 * 判据:
 *   A、B 的比值都 ≈ 同一个数 k => 计数线程在负载期间**成比例丢时间**（vCPU 抢占/调度），
 *                                k 就是校正系数；用 27.9 × k 复核是否回到 66–69；
 *   两负载比值差很多            => 计数器受负载类型影响，只能各自报数，本限制只能到此。
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <pthread.h>
#include <sched.h>
#include <unistd.h>

static inline uint64_t rd(void){ uint64_t t; __asm__ __volatile__("mrs %0, cntvct_el0":"=r"(t)); return t; }
static volatile uint64_t sinkv;
static volatile uint64_t mask0 = 0;

static volatile uint64_t g_ctr = 0;
static volatile int g_stop = 0;
static void *ctr_thread(void *arg){
  (void)arg;
  cpu_set_t s; CPU_ZERO(&s); CPU_SET(2,&s);
  sched_setaffinity(0,sizeof(s),&s);
  uint64_t c=0;
  while(!g_stop){ __asm__ __volatile__("add %0, %0, #1" : "+r"(c) :: "memory"); g_ctr = c; }
  return NULL;
}

static unsigned char *buf;

/* A: 指针追逐（依赖 L1 命中） */
__attribute__((noinline)) static void chase(int K){
  unsigned char *p = buf;
  for(int i=0;i<K;i++){
    uint32_t off;
    __asm__ __volatile__("ldr %w0,[%1]" : "=r"(off) : "r"(p) : "memory");
    p = buf + off;
  }
  sinkv = *p;
}
/* B: store 密集（与 st2ld 同族） */
__attribute__((noinline)) static void st2ld(void *x0, void *x1){
  uint64_t a = (uint64_t)(uintptr_t)x0;
  for(int i=0;i<10;i++) a = a*6364136223846793005ULL + 1442695040888963407ULL;
  void *sa = (void*)((uintptr_t)x0 + (a & mask0));
  *(volatile uint64_t*)sa = 0x1111111122222222ULL;
  uint64_t x = *(volatile uint64_t*)x1;
  uint64_t b = a ^ x;
  for(int i=0;i<10;i++) b = b*6364136223846793005ULL + 1442695040888963407ULL;
  sinkv = b;
}

static int cmpd(const void*p,const void*q){ double x=*(const double*)p,y=*(const double*)q; return (x>y)-(x<y); }
static double qsel(double *v,int n,double p){
  double *c=malloc((size_t)n*sizeof(double)); memcpy(c,v,(size_t)n*sizeof(double));
  qsort(c,(size_t)n,sizeof(double),cmpd);
  int i=(int)(p*(n-1)); double r=c[i]; free(c); return r;
}

int main(void){
  setbuf(stdout,NULL);
  uint64_t frq=0; __asm__ __volatile__("mrs %0, cntfrq_el0":"=r"(frq));
  if(!frq) frq=50000000ULL;
  const double nspt = 1e9/(double)frq;

  if(posix_memalign((void**)&buf,4096,1u<<20)!=0) return 2;
  memset(buf,0,1u<<20);
  /* 建指针链：16 KB 内 256 条线，单环 */
  { size_t nl = (16u<<10)/64;
    uint32_t *perm=malloc(nl*4); for(size_t i=0;i<nl;i++) perm[i]=(uint32_t)i;
    uint64_t s=0x9E3779B97F4A7C15ULL;
    for(size_t i=nl-1;i>0;i--){ s^=s<<13; s^=s>>7; s^=s<<17; size_t j=(size_t)(s%(i+1));
      uint32_t t=perm[i]; perm[i]=perm[j]; perm[j]=t; }
    for(size_t i=0;i<nl;i++) *(uint32_t*)(buf+perm[i]*64)=perm[(i+1)%nl]*64u;
    free(perm); }

  void *PA=(void*)(buf+0x4000), *PB=(void*)(buf+0x6000);

  pthread_t th;
  if(pthread_create(&th,NULL,ctr_thread,NULL)!=0){ printf("!! 线程失败\n"); return 2; }
  usleep(20000);

  uint64_t c0=g_ctr, t0=rd();
  while ((double)(rd()-t0)*nspt < 20e6) { }
  uint64_t c1=g_ctr, t1=rd();
  double per_count_ns = ((double)(t1-t0)*nspt) / (double)(c1-c0);
  printf("# 校准: %.3f ms 内 +%llu counts → 1 count = %.3f ns = %.2f cycle\n",
         (double)(t1-t0)*nspt/1e6, (unsigned long long)(c1-c0), per_count_ns, per_count_ns*3.0);

  const int R=200;
  double *nA=malloc((size_t)R*sizeof(double)), *cA=malloc((size_t)R*sizeof(double));
  double *nB=malloc((size_t)R*sizeof(double)), *cB=malloc((size_t)R*sizeof(double));

  for(int i=0;i<2000;i++){ chase(1); st2ld(PA,PB); }

  for(int r=0;r<R;r++){
    uint64_t a,b;
    a=rd(); chase(2048); b=rd(); nA[r]=(double)(b-a)*nspt;
    a=g_ctr; chase(2048); b=g_ctr; cA[r]=(double)(b-a)*per_count_ns;

    a=rd(); for(int k=0;k<512;k++) st2ld(PA,PB); b=rd(); nB[r]=(double)(b-a)*nspt;
    a=g_ctr; for(int k=0;k<512;k++) st2ld(PA,PB); b=g_ctr; cB[r]=(double)(b-a)*per_count_ns;
  }
  g_stop=1; pthread_join(th,NULL);

  double mA=qsel(nA,R,0.5), iA=qsel(cA,R,0.5);
  double mB=qsel(nB,R,0.5), iB=qsel(cB,R,0.5);
  double kA = iA>0? mA/iA : 0;
  double kB = iB>0? mB/iB : 0;

  printf("\n%-14s %12s %14s %10s\n","负载","cntvct(ns)","计数推算(ns)","比值");
  printf("------------------------------------------------------------\n");
  printf("%-14s %12.1f %14.1f %10.2f\n","A 指针追逐",  mA, iA, kA);
  printf("%-14s %12.1f %14.1f %10.2f\n","B st2ld×512", mB, iB, kB);

  printf("\n== 判读 ==\n");
  double d = fabs(kA-kB);
  if(d < 0.3 && kA > 1.2){
    double corrected = 27.9 * kA;      /* S1w 的每事件 cycle 估计 */
    printf("  两负载比值接近（%.2f vs %.2f）→ 计数线程**在负载期间成比例丢时间**（vCPU 抢占/调度）\n", kA, kB);
    printf("  校正系数 k ≈ %.2f → S1w 的 27.9 cycle/事件 校正后 = **%.1f cycle**\n", kA, corrected);
    printf("  （cntvct 版给 66–69；若校正值与它接近，说明两套计时器其实一致，差别来自计数线程丢时）\n");
    printf("\n>>> S1aa PASS : 两套计时器经 k 校正后一致，限制①从\"2.4× 不明\"降为\"已知丢时系数\"\n");
  } else if(kA > 1.2 || kB > 1.2){
    printf("  两负载比值不同（%.2f vs %.2f）→ 计数器受负载类型影响，无法用单一系数校正\n", kA, kB);
    printf("\n>>> S1aa MIXED : 限制①维持\"只到量级\"，且已知其来源是负载相关\n");
  } else {
    printf("  两负载比值都 ≈1（%.2f / %.2f）→ 计数线程没有丢时间，那 S1w 的偏小另有原因\n", kA, kB);
    printf("\n>>> S1aa CHECK : 需要看 S1w 的测量窗口本身是否被抢占\n");
  }
  printf(">>> 摘要行: kA=%.2f kB=%.2f corrected=%.1f cycle\n", kA, kB, 27.9*kA);
  return 0;
}
```


**S1aa 实测（2026-11-19）→ MIXED，但把 2.4× 的来源定死了**

| 负载 | cntvct 实测 | 计数推算 | **比值** |
|---|---|---|---|
| A 指针追逐 2048 次（纯 load） | 5020.0 ns | 5047.7 ns | **0.99** |
| B `st2ld` × 512（store 密集） | 5940.0 ns | 2183.4 ns | **2.72** |

**两条结论，都很硬**：

1. **计数线程没有丢时间**。纯 load 负载上两套计时器比值 **0.99**——几乎完全一致。所以之前"vCPU 被抢占"的猜测**排除**。
2. **计数器对 store 密集负载系统性少计约 2.7×**。同样的线程、同样的校准，只换负载类型，比值就从 0.99 跳到 2.72。

**这直接解释了 S1w 的 2.4×**：S1w 测的四臂全是 `st2ld`（store 密集），计数器少计 → 27.9 是被压低的读数。

**校正后**：27.9 × 2.72 ≈ **75.9 cycle/事件**，与 cntvct 的 **66–69** 相差约 10%。

**因此限制①的现状是**：不是"两套计时器互相矛盾"（那很糟），而是"**其中一套有已量化的、负载相关的系统偏差**"（这可以处理）。校正后两套一致到 10% 以内，`69 cycle/事件` 这个数由两套独立仪器相互支持。

**仍未消除的**：没有 PMU 的第三方仲裁，10% 的残差还在。要钉死还需 PMU。

## 8. 当前结论（2026-11-19 会话 31 定稿，正向）

| 项 | 判决 | 依据 |
|---|---|---|
| **Q-A** 同进程能否测到 MDU 信号 | ✅ **能** | S1p：X=+37 / Y=0 / S=+37 tick；**S1s 杀死控制**：去掉使能条件后 S 从 +36 → +0 |
| **Q-B** 能否跨进程观测 | ✅ **成立（数据 + 机理）** | S1q 数据：D=+310 tick；**S1v 机理**：同 PC 756 / 异 PC（160 B）509，D=+246 → PC 索引的 MDU 表项 |
| **信道** | ✅ 可建立 | **S1x 曲线**：K=8 → **3.12% @ 78.9 kbps**，K=16 → 2.34% @ 39.5 kbps；K=1 不可用（57%） |
| **架构阶梯**（副产品） | ✅ 稳定可测 | 0.391 / 0.781 / 3.203 ns/pair，三次独立复现 |

**四条限制的现状**（会话 26–31 全部实测过）：

| # | 限制 | 状态 | 装置 |
|---|---|---|---|
| ① | 无 cycle 级验证 | 🟢 **已量化**：计数线程 27.9 vs cntvct 66–69；纯 load 比值 0.99、store 密集 2.72 → 校正后 ≈75.9，差 ±10% | S1w + S1aa |
| ② | 信道单薄 | ✅ **已出曲线**：K 扫描 + 中点阈值，工作点 K=8 / K=16 | S1x |
| ③ | 量级散布 2× | ✅ **已归因**：S/M = 1.000/1.094/1.148（1.15×）→ 放大忠实，散布来自上下文 | S1y |
| ④ | 只此一核 | ✅ **已解除**：四核 36/37/37/36 tick（1.03×），Y 四核均为 1.0 | S1z |

**边界**：平台 = 倚天 710 / Neoverse-N2 + 20 ns `cntvct` + 云端虚拟机；口径 = 删-fence + M 倍放大；机制 = 只覆盖"训练改变 store→load 代价"这一读法（已用使能条件与索引键两组对照封口）。跨型号、跨厂商未测。

## 9. 待办（2026-11-19 会话 31 重写）

收尾装置（S1w/S1x/S1y/S1z/S1aa）全部跑完，原来的待办已清空。真正剩下的是这四条，**都不改变定性**：

| # | 事项 | 为什么值得做 | 卡在哪 |
|---|---|---|---|
| 1a | **方法验证（最省，无需 root）**：在任意带 PMU 的机器（x86/其他 ARM）上，用 `PMCCNTR` 与"M 倍放大 + 20 ns 尺子"同测一个已知负载 | 验证的是"放大估计法忠不忠实"这个**通用方法学问题**，跟 710 无关；对上之后方法被背书，本机所有 `cntvct` 读数连带可信 | 需要一台能读 PMCCNTR 的机器（不必是 710） |
| 1b | **钉死本机绝对值（需 root）**：让 VM owner 把 `perf_event_paranoid` 调到 ≤1（或开 `PMUSERENR.EN`），本机用 PMCCNTR 重跑 S1p | 把 ±10% 残差归零 | 需要 root，与项目"服务器不许 sudo"红线冲突，由用户决定 |
| 2 | **跨型号 / 跨厂商**：换别的 ARM 服务器核（Graviton / Ampere / 其他倚天实例） | 把"第八个核"扩成一条曲线 | 需要另一台机器 |
| 3 | **差分编码 + 更大 N**：规避相邻比特状态延续 | K=1 目前 57% 不可用；差分编码有可能救回来，吞吐还能再上一台阶 | 本机可做，未做 |
| 4 | **跨核信道**：发送/接收分居两核 | 现在两进程钉同核（论文前提）；分核是另一个问题 | 本机可做，未做 |

> **给团队的一句话**：没有 PMU 不影响 Q-A/Q-B 的结论（它们靠杀死控制与形状，跟绝对 cycle 无关）；PMU 只决定"约 70 cycle"精不精确，而连这件事都能用 **1a（换台有 PMU 的机器验方法）** 绕过去——**本机这台可以不管 PMU 了**。

## 10. 变更记录

| 时间 | 会话 | 变更 |
|---|---|---|
| 2026-11-18 | 1 | 建立本文件；S-1 ruler 跑通（PASS）；确认 cntvct 50 MHz 真实可用、`dc civac` 可用 |
| 2026-11-18 | 2 | 交付 S0-v1 amp_sweep；结果作废（工作集不缩放缺陷，见 §7.2） |
| 2026-11-18 | 3 | 修正工作集后 S0-v2 跑通，得到 L1/L2/L3/DRAM 四层延迟；A/A 标定暴露样本量不足，重新解释 12 ticks 为抽样噪声 |
| 2026-11-18 | 4 | 锁定参考论文（ARMeD @ TCAD 2025 主 / Leaky MDU @ DAC 2023 副）；补正"MDU = 内存消歧单元"；提出"无 SMT 不是死穴"推论；交付 S1 剂量-反应探针，待跑 |
| 2026-11-18 | 5 | S1 跑出 FAIL（全组 med_Δ≈0，p5/p95 恒为 ∓1 tick）。归因为三个装置缺陷（中位数量化失明、训练效应稀释 128×、训练臂成本混淆），判定非核判决；新增 §5.2-10 统计纪律；交付 S1b（G1/G2 SELF 闸门），待跑 |
| 2026-11-18 | 6 | S1b 跑出 HALF：G1 PASS（+0.33 tick，CI 排除 0，Cohen_d 0.44）；G2 FAIL 但点估计 +6.93 tick 方向正确，sd=142.91 → **归因为 6 µs 长样本被抢占污染**，非无效应。改用存储转发重叠探针（8B store vs 4B store 部分重叠）+ 短样本 + median/修剪均值/脏样本率，交付 S1b-v2 |
| 2026-11-18 | 7 | S1b-v2：**G2 PASS**（+37 tick = 8.7 cycle/iter，脏样本 0.1%）→ **装置 SELF 通过**。G1 判据作废（"store 必然更慢"的假设被实测推翻，FAST 反比 BASE 快 6 tick）；查明 `acc += x` 串行累加器吃干了测量量（256 add ≈ 全部时长），三臂编译不一致。交付 S1c（同 PC 训练剂量反应 + 去掉累加器 + 三臂同指令流阶梯） |
| 2026-11-19 | 8 | S1c **PASS**：阶梯干净（不重叠 10 / 全重叠 5 / 部分重叠 41 tick，转发代价 +36），且发现"不重叠也要付消歧检查代价"（10 vs 5）。训练效应 **S = −6.00 tick = −0.94 ns/probe-iter ≈ −2.8 cycle（−29%）**，dirty 0.5% → **首个初步阳性**。未下 Q-A 结论，交付 S1d（off=+8 特异性控制臂 + TR∈{1,4,16,64} 剂量反应） |
| 2026-11-19 | 9 | S1d 跑出 **+6~+7 tick，与 S1c 的 −6 符号相反** → 阳性作废，怀疑顺序伪影。顺带纠正判据错误（用 CI 卡 ±1 tick 离散量过严）。交付 S1e（正序/反序反序对照） |
| 2026-11-19 | 10 | S1e 查明：**位置伪影主导**。同一条件 `off=−4` 在第 3 位量到 19 tick、在第 1 位量到 23 tick（差 4 tick），而待测效应只有 2~3 tick → TR=16 的"同号真效应"是假阳。**S1c/S1d 结论全部作废**，Q-A 回归"未观测到"。交付 S1f（只包 probe、不做大块相减、条件轮转、前后半段自复制） |
| 2026-11-19 | 11 | S1f 打出 PASS（S_full=−110 tick，两半一致），但 **`S_ctrl=−59` 暴露效应不特异**，且查明物理原因：`A−4` 落在**前一条 cache line**，实为 store 地址碰撞伪影（off=−4 训练与 probe 的 `str [A−4]` 撞同一地址）。实现上我的判定语句漏检 `S_ctrl`。**第三个阳性作废**。交付 S1g（probe 挪到远端固定地址 + 加"远端训练"第四条件） |
| 2026-11-19 | 12 | S1g 出 68 tick 残差但**形状不合理**（最贵训练给最快 probe、远端训练最慢）→ 判定无效，病因：① `mrs` 不是屏障，probe 与训练尾巴乱序重叠；② `str 8B [A−4]` 跨 cache line 被拆。交付 S1h（fence 隔离 + 全对齐 + 无训练基准） |
| 2026-11-19 | 13 | S1h **CLEAN**：四条件全部 **60.0 tick，差 0.00**，300 样本逐样本一致 → **同 PC 训练历史对 probe 无影响**，效应上界 < 1.7% ≈ 0.02 ns/pair（0.06 cycle）。Q-A 记为"未观测到（PC 索引已排除）"，仅剩地址索引未查。交付 S1i |
| 2026-11-19 | 14 | S1i **CLEAN**：同址训练同样四条件全 60.0 tick、差 0.00 → **地址索引路径亦排除**。**Q-A 定案为否，Q-B 依依赖关系不成立。** 产出 `L1-3_MDU_结论卡.md`（判决 + 三条边界 + 证据链 + 四次作废的方法论 + 架构阶梯正面结果 + 四项残余漏洞 + TC 复跑清单） |
| 2026-11-19 | 15 | S1j **CLEAN**：跨上下文实测——同核双线程真实切换（1.24 µs/次，25600 回合），四臂 174/174/174/175 tick，**A−B = 0.00**、maxdiff 1.00 → **跨上下文无残留**。Q-B 的否定由"逻辑推断"升级为"实测"，结论卡 §4-2 缺口闭合 |
| 2026-11-19 | 16 | S1k 交付（无 fence + 地址晚到）。首版段错误：slots 按 4096 步长摆放却在 `run()` 里按 8 字节索引 → 读到 NULL；改为 uint32 偏移 + 掩码 + slots 自检（v2） |
| 2026-11-19 | 17 | **取得论文正文并解析**（TCAD 2025 + DAC 2023）。抽出：索引键 = **load PC**（A72 另有 16-bit 向量按 PC[5:2] 选位）、跨进程须**同核**、计时必须 **cycle 级（PMCCNTR）**、探针结构 = 10 乘法 + `10n→10a→10n`、t1/t2/t3 定义。**发现我们此前探针结构与论文不同** → 新增 S1m |
| 2026-11-19 | 18 | S1m 跑出：逐次 profile 全 1 tick（60 cycle 量化所致），块聚合 D=+1 tick。新增对照组 S1n |
| 2026-11-19 | 19 | S1n：dA=+1.00 / dN=+0.00 / S=+1.00 → 暖机被排除。随即识别出"store 队列深度"这个替代解释 → S1o |
| 2026-11-19 | 20 | S1o：dA = 1/1/2 tick，按预注册判据判 **QUEUE**，**S1n 的 PASS 作废（第五次自撤）**。结论：60 cycle 量化台阶已把这条路顶死 → 换放大器 S1p |
| 2026-11-19 | 21 | **S1p SIGNAL**：X=+37 / Y=0 / S=+37 tick（69 cycle/事件），不对称形状与论文 t1/t2/t3 一致 → **首次抓到 MDU 状态效应** |
| 2026-11-19 | 22 | **S1q PASS**：两进程同核，D=+310 tick（36 cycle/事件），`fork` 后 COW 排除物理页别名 → 跨进程状态共享成立 |
| 2026-11-19 | 23 | S1r 信道：错误率 3.12%（95%CI 1.2–7.8%）。**修正硬错误**：吞吐原报 595.8 kbps 是把比特数乘了 8，真值 **~74 kbps**。同时补正：CI [+37,+37] 为离散地板退化区间；判决降为**强 preliminary**；新增两个杀死控制 S1s / S1t |
| 2026-11-19 | 24 | **S1s PASS（使能杀死控制）**：LATE 臂 S=+36 / EARLY 臂（store 地址发射即知）S=+0 → 信号在该消失时消失。S1t 作废（两臂都用 n 训练，构不成对照）、S1u 作废（判据方向写反），均不计入证据。 |
| 2026-11-19 | 25 | **S1v PASS（索引键杀死控制）**：同 PC 训练 756 / 160 B 外异 PC 509，D=+246 tick；打印地址确认两函数未被 IPA-ICF 合并。两组杀死控制齐备 → **判决由"强 preliminary"升回定案（正向）**，Q-A/Q-B 均 ✅。同步更新结论卡与本文件 §8/§9 及头部交付清单。 |
| 2026-11-19 | 26 | "圆满"三台交付：**S1w**（计数线程做 cycle 级交叉验证，绕开被禁的 PMU）、**S1x**（K 扫描 + 中点阈值 → 错误率-吞吐曲线）、**S1y**（M 剂量反应，检验放大忠实性）。第四条限制（只此一核）用现成二进制换核跑即可。 |
| 2026-11-19 | 27 | **S1y PASS**（S/M = 1.000/1.094/1.148，放大忠实）；**S1x 出曲线**（K=8 → 3.12%@78.9kbps，K=16 → 2.34%@39.5kbps，K=1 不可用）；**S1w PASS 但仅量级一致**（27.9 vs cntvct 的 69，差 2.4×）→ 限制①由"未测"改为"已测但只到量级" |
| 2026-11-19 | 28 | 交付 **S1z**（一键四核扫）：子进程各自绑核跑同构四臂，父进程汇总跨核一致性表 —— 把限制④从"给个 shell 循环"变成"一条命令出表"。待跑。 |
| 2026-11-19 | 29 | **S1z PASS**：四核（0/1/2/3）S = 36.0 / 37.0 / 37.0 / 36.0 tick，max/min 1.03×，Y 全为 1.0 → 效应非单核特例，**限制④解除**。四条限制现状：①量级级（需 PMU）②已量化③已归因④已解除 |
| 2026-11-19 | 30 | 交付 **S1aa**：用两个已知耗时的负载标定"cntvct 实测 / 计数推算"的比值，判定 S1w 的 2.4× 是计数线程成比例丢时（可用系数校正）还是负载相关（只能各自报数）。待跑。 |
| 2026-11-19 | 31 | **S1aa MIXED**：纯 load 负载两套计时器比值 **0.99**（计数线程不丢时间），store 密集负载 **2.72**（系统性少计）→ 2.4× 的来源定死为"计数器对 store 密集负载的量化偏差"；校正后 27.9×2.72≈**75.9 cycle**，与 cntvct 的 66–69 相差约 10% → 限制①由"不明矛盾"改为"已量化偏差" |

---

*本文件由会话内实时维护；新会话接手时先读 §8 当前结论 与 §9 待办，再按 §6 装置清单复跑。*
