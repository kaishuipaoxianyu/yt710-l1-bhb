# 还需从服务器导出的原件（对话版不编造，标【需导出】）

对话版明确:只能原样给真正流经对话 / 它亲手写 / 存在项目文档里的内容。下列原件**只在 N2 服务器上、从未粘进对话**,**未**纳入本仓库,需从服务器导出后补入。

一键导出:在服务器跑 [`scripts/export_from_server.sh`](scripts/export_from_server.sh),把生成的 `~/L1_port_YYYYMMDD.tar.gz` `scp` 回来,按下表归位。

| 文件 | 归位到 | 说明 |
|---|---|---|
| `common/helper.h`（完整） | `src/helper.h` | 只有计时补丁片段流经对话（见 `patches/PATCH.md` 补丁1 / 对话§1）。整份 `clflush`=`dc civac`、`fence`=`dsb ish`+`isb`、`maccess`、`load_time`、`clock_start` 需原文。**缺它编不过。** |
| `common/*.h` 其余头 | `src/` | 上游 `cache_utils` 之类（若有）。 |
| `Makefile`（顶层 + `re/arm/bhb_brute_force/`） | `build/` | 上游用 `CC_ANDROID`/`TARGET`；N2 原生可 `make CC_ANDROID=gcc TARGET=YITIAN_710`，或直接 gcc（见 README 构建段）。 |
| `retest_hiN.sh`、`retest_variance.sh` | `scripts/` | 上一会话产物，对话无原文。功能近似 `sweep_hiN.sh`（已提供近似骨架）。 |
| `raw.csv`（6000 行：CTRL/MAIN/POS 各 2000） | `data/` | main.o 每次运行覆写。 |
| `raw_existence_mode.csv`、`summary.json`、`summary_table.tsv` | `data/` | L1-1 四件套产物。 |
| `cross_calib.csv`（17 行）、`cross_main.csv`（641 行） | `data/` | 对跑原始行。本仓库只含聚合值 `data/cross_aggregated.tsv`。 |
| `sweep_thr_results.csv`、`calib_thr_results.csv`、`sweep3/4_results.csv` | `data/` | THR/深度扫描逐 run 原始行（analyze_*.py 的输入）。 |
| `env.json` / `env_raw.txt` / 完整 `lscpu` | `env/` | 环境关键值已在 `docs/environment.md`；完整原文需导出。 |
| `calib_L1-1H_repro_*.zip`、`main_L1-1H_repro_*.zip` | `data/` | 两个复现包（main 包已在桌面导入，calib 包待导）。 |

## 核验项（导出后做一次）
- `src/snippet.S`：对话标"上游未改、全文"，但建议 `diff` 服务器实际文件一次（命令见 `snippet.S` 头注）。
- `src/helper.h`：确认计时分支已是 `isb; mrs cntvct_el0`（补丁1）。

## 已原样齐全（无需导出）
`src/snippet.S`、`src/main.c`、`src/calib.c`、`src/targets.h`、helper.h 计时补丁(`patches/PATCH.md`)、全部 `scripts/analyze_*.py` 与 `sweep_*.sh`/`calib_thr.sh`/`make_env.sh`、`docs/reports/L1-1_结论卡_v2.2.md`、`docs/environment.md`、聚合数据 `data/cross_aggregated.tsv`。
