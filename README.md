HW-SW-Project: JSON dumps + PyAES Performance Study

Overview
- Two workstreams: `json.dumps` (CPython encoder) and `crypto_pyaes` (pure-Python AES CTR).
- Provides stable benchmarking, perf counters (IPC/MPKI), flamegraphs, and before/after comparisons.
- See `Project.md` for the full project brief and expectations.

Quick Start (Linux)
- JSON dumps
  - `cd Additional_Files/json_dumps`
  - Baseline: `./json_perf_lt.sh`
  - After: follow this folder’s README for both flows:
    - Python-level benchmark change (switch to `after_benchmark.py` via bench switch script)
    - Optional C-level rebuild of `_json.c` via `json_jsonSwitch.sh`
  - Re-run with `./json_perf_lt.sh after`, then compare using `../../compare.sh`
- PyAES
  - `cd Additional_Files/crypto_pyaes`
  - Baseline: `./crypto_perf.sh`
  - After: follow this folder’s README (e.g., `crypto_aesSwitch.sh` and/or `crypto_benchSwitch.sh`), then `./crypto_perf.sh after`
  - Compare using `../../compare.sh`

Docs
- JSON dumps: `Additional_Files/json_dumps/README.md`
- PyAES: `Additional_Files/crypto_pyaes/README.md`
- Project overview: `Project.md`

Results (included samples)
- JSON: `Additional_Files/json_dumps/json_result`
- PyAES: `Additional_Files/crypto_pyaes/crypto_result`

Helpers
- Compare results: `Additional_Files/compare.sh` (writes `comp.txt`, optional diff flamegraph)
- Transfer artifacts (QEMU/remote): `Additional_Files/ssh_transfer.sh`

Platform Notes
- Scripts use Linux tooling (`perf`, `taskset`, FlameGraph). Use Linux/WSL/VM when running locally.

