# L1-3 · MDU 可测量性与跨进程可观测性（Yitian 710 / Neoverse-N2）

> 维护者：WFY（GitHub [@kaishuipaoxianyu](https://github.com/kaishuipaoxianyu)） · 仓库总览见 [`../README.md`](../README.md)
> 状态：✅ **定案（2026-11-19）** —— MDU 预测状态在本机**可测**，且**可跨进程观测**（~74 kbps 隐蔽信道）。

本目录是 `yt710-l1-bhb` 仓库的 **L1-3 子项目**：在倚天 710（N2）上验证 **MDU（Memory Disambiguation Unit，内存消歧单元）**
预测状态能否测量（Q-A，同进程）、能否跨进程观测（Q-B）。对标 ARMeD(TCAD'25) / Leaky MDU(DAC'23)。

## 文件

| 文件 | 说明 |
|---|---|
| [`L1-3_MDU_结论卡.md`](L1-3_MDU_结论卡.md) | 结论卡（定案）：判决 / 三条边界 / 证据链 / 限制 / 五次自撤 / 复跑清单 / 论文对账 |
| [`L1-3_MDU_实验日志.md`](L1-3_MDU_实验日志.md) | 证据卷（220 KB）：25 台装置逐台源码内嵌 + 逐次数据记录（勿删，追加式） |

## 未随仓附带（在服务器 `~/mdu_l13/`）

- `src/`：25 个 `.c` 装置（结论卡 §6 TC 列表；**日志中已逐台内嵌全文**，可据此重建）
- `papers/`：`ARMeD_TCAD2025.pdf`、`LeakyMDU_DAC2023.pdf`（版权原件，不入库）

## 一句话结论

在这颗 N2 上，MDU「预测 load 是否能绕过更老 store」的状态**可测**（约 30–70 cycle/事件），
且这个状态能被**另一个进程**读到 → 跨进程隐蔽信道可建立（**~74 kbps**，错误率个位数百分比）。
共享的是按 **load PC** 索引的微架构表项（S1v：同 PC 生效、160 B 外异 PC 不生效）。详见结论卡。

> 平台口径与 L1-1 一致：删-fence / `cntvct`(20 ns/tick) / `taskset -c 3` / 无 SMT。
> 环境见 [`../docs/environment.md`](../docs/environment.md)、操作红线见 [`../docs/服务器使用说明.md`](../docs/服务器使用说明.md)。
> ⚠️ 仅用于授权的安全研究，限本机自测；结论绑这颗 N2 核 + 这批二进制，跨核/跨型号未测。
