JSON dumps — Benchmarking and Profiling

Purpose
- Measure and analyze `json.dumps` performance with stable methodology.
- Compare baseline vs “after” changes (Python‑level benchmark tweaks and optional C encoder rebuild).

Contents
- `json_perf_lt.sh`: end‑to‑end timing + perf stat + aggregated flamegraph + annotate.
- `json_benchSwitch.sh`: swap pyperformance’s `bm_json_dumps/run_benchmark.py` to local `json_dumps_workspace/after_benchmark.py`.
- `json_dumps_workspace/after_benchmark.py`: “after” variant (loop tightening, fewer lookups).
- `json_dumps_workspace/cpython_source/_json.c`: optional patched C encoder.
- `\json_dumps_workspace\cpython_source\json_jsonSwitch.sh`: optional json build helper
- `cpython_interpreter/ceval_switch_build.sh`: optional CPython interpreter build helper.
- `json_result/`: captured outputs (timing, perf_stat, flamegraphs, annotate excerpts).

Run: Baseline
- From current folder: `./json_perf_lt.sh`
- Outputs (current dir): `timing.txt`, `perf_stat.csv`, `report_light.txt`, `annotate.txt`, `flamegraph.svg`, folded stacks.


Run: After (Python‑level changes)
1) Copy /json_dumps_workspace/cpython_source/_json.c into your directory - expected path `/root/_json.c`
2) Run script `json_jsonSwitch.sh`
3) Activate modified venv if needed: `source /root/venv_after/bin/activate`
4) Re‑run: `./json_perf_lt.sh after`
  - Outputs (current dir): `timing_after.txt`, `perf_stat_after.csv`, `report_light_after.txt`, `annotate_after.txt`, `flamegraph_after.svg`, folded stacks.
5) Compare: use `../../compare.sh` from a directory that contains both BEFORE and AFTER outputs.
  - output comp.txt
6) If executed on QEMU, download results to your local from ssh browser: run `./ssh_transfer.sh`


Results
- This repo includes a sample capture in `json_result/` (timing, perf_stat, flamegraph, annotate, diffs).

