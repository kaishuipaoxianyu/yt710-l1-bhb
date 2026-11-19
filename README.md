# yt710-l1-bhb · 倚天 710 侧信道原语复现（WFY）

> 维护者：WFY（GitHub [@kaishuipaoxianyu](https://github.com/kaishuipaoxianyu)） · 索引仓 submodule：[`illustager/yt710-sca-hub`](https://github.com/illustager/yt710-sca-hub)（登记为 `Spectre/yt710-l1-bhb`）
> 平台：Alibaba Yitian 710 / ARM **Neoverse-N2** / Ubuntu 26.04 / kernel 7.0.0-42 / **无 SMT** / `cntvct` 50 MHz（20 ns/tick）。

本仓库是 **WFY** 在倚天 710（N2）上的侧信道原语复现与测量工作，**按实验分目录**整理。

## 实验索引

| 实验 | 目录 | 主题 | 状态 |
|---|---|---|---|
| **L1-1** | [`L1-1-spectre-bhb/`](L1-1-spectre-bhb/) | Spectre-BHB 同进程原语（BHB 带偏间接分支 + L1D Flush+Reload） | ✅ 存在性 **success**；BHB 深度待 calib 裁决 |
| **L1-2** | [`L1-2-bhb-n2redesign/`](L1-2-bhb-n2redesign/) | BHB 原理代码与 N2 重设计 | 设计报告 |
| **L1-3** | [`L1-3-mdu/`](L1-3-mdu/) | MDU 可测量性与跨进程可观测性 | ✅ **定案**：可测（四核一致）+ 可跨进程（K=8 → 3.12% @ 78.9 kbps） |

## 其它

| 目录 / 文件 | 说明 |
|---|---|
| [`crossref/`](crossref/) | 组内成员交叉验证参考（ZYW 的 `bhb_final` 单一仪器版，**非本仓原创**） |
| [`docs/environment.md`](docs/environment.md) | 目标机环境实测 + THR 稳健性（平台共享） |
| [`docs/服务器使用说明.md`](docs/服务器使用说明.md) | ★ N2 服务器操作规范（最高优先级） |
| [`docs/progress/`](docs/progress/) | 团队进度与结论（含 **zyw·wfy** 协作） |

## 统一口径（各实验共用）

删-fence / `cntvct_el0`(20 ns/tick) / `taskset -c 3` / governor=performance；L1-1 另有 THR=4、HISTORY_SIZE=256、train 32 饱和（见各实验目录与 `docs/environment.md`）。

> ⚠️ 仅用于授权的安全研究与复现，限本机同进程/同核自测。各实验的范围与边界以其目录内的结论卡为准。
