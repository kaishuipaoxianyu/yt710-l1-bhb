# data/

- `cross_aggregated.tsv` —— calib/main 双仪器对跑的**聚合值**（THR=4, core 3）。每行一个 HISTORY_SIZE，
  `calib_mean_hits`=calib 碰撞均值，`main_median_pct`=main 过闸复跑产率中位。来源：analyze 输出（非原始行）。

**原始逐 run 数据未纳入**（在服务器上），见仓库根 [`NEEDS_EXPORT.md`](../NEEDS_EXPORT.md)：
`raw.csv` / `cross_calib.csv` / `cross_main.csv` / `sweep_thr_results.csv` / `calib_thr_results.csv` /
`sweep3/4_results.csv` / `summary.json` / `summary_table.tsv`。
用 `scripts/export_from_server.sh` 一键打包回填到此目录。
