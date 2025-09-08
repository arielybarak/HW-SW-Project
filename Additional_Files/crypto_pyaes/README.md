PyAES (CTR) — Benchmarking and Profiling

Purpose
- Measure and analyze the pure‑Python AES CTR benchmark (`bm_crypto_pyaes`).
- Compare baseline vs “after” variants (bench rework and optional library swap).

Contents
- `../../script_crypto_pyaes.sh`: end‑to‑end pipeline (timing, perf stat, aggregated flamegraph, annotate, optional diff).
- `crypto_benchSwitch.sh`: patch pyperformance’s `bm_crypto_pyaes/run_benchmark.py` to use `crypto_pyaes_workspace/after_benchmark.py`.
- `crypto_aesSwitch.sh`: replace installed `pyaes/aes.py` with `crypto_pyaes_workspace/pyaes/aes_after.py` in the active venv.
- `crypto_pyaes_workspace/…`: baseline and after variants for the benchmark and library.
- `crypto_result/`: captured outputs (timing, perf_stat, flamegraph, annotate excerpts).


Run: Baseline
- From your directory: `./crypto_perf.sh`
- Outputs (current dir): `timing.txt`, `perf_stat.csv`, `report_light.txt`, `annotate.txt`, `flamegraph.svg`, folded stacks.

Run: After (Python‑level benchmark change)
1) Copy `aes_after.py` into your directory - expected path `/root/aes_after.py`
2) Run the script `crypto_aesSwitch.sh`
3) Run the perf script using the flag "after" `./crypto_perf.sh after`
- Outputs (current dir): `timing_after.txt`, `perf_stat_after.csv`, `report_light_after.txt`, `annotate_after.txt`, `flamegraph_after.svg`, folded stacks.
4) Compare by running `./compare.sh` from Additional_Files
- output comp.txt
5) If executed on QEMU, download results to your local from ssh browser: run `./ssh_transfer.sh`

Results
- This repo includes a sample capture in `crypto_result/` (timing, perf_stat, flamegraph, annotate, diffs).

Notes
- Scripts assume Linux tooling and may require root/admin for `perf` and MSR tuning. Prefer running inside a Linux VM/WSL or a remote Linux host.

