#!/usr/bin/env bash
# crypto_pyaes: timing + IPC/MPKI + DWARF record (aggregated) + flamegraph (+diff) + annotate
#* RUN AS ./<name>.sh  OR  ./<name>.sh after

set -u
export PAGER=cat PERF_PAGER=cat PYTHONHASHSEED=0

# Suffix for AFTER runs (outputs stay the same names as before, just with _after)
SUFFIX=""
if [ "${1:-}" = "after" ]; then
  SUFFIX="_after"
fi

# Clean old outputs for this run
rm -f perf.data "flamegraph${SUFFIX}.svg" "out${SUFFIX}.folded" "out${SUFFIX}.folded.tmp" \
      "timing${SUFFIX}.txt" "perf_stat${SUFFIX}.csv" "perf_stat_summary${SUFFIX}.txt" \
      "perf_report${SUFFIX}.txt" "report_light${SUFFIX}.txt" "annotate${SUFFIX}.txt"

BENCH=crypto_pyaes
CMD="taskset -c 0 python3 -m pyperformance run --bench ${BENCH}"
FREQ=${FREQ:-200}           # perf sampling Hz (DWARF)
FG_RUNS=${FG_RUNS:-3}       # how many perf record passes to aggregate for the flamegraph
WARMUP_ITERS=${WARMUP_ITERS:-1}   # how many lightweight warmup executions (imports + a few dumps) outside perf capture

# Warm-up helper for crypto_pyaes (pure Python AES operations) to reduce import noise.
warmup_python() {
  python3 - <<'PY'
try:
  import pyaes
except ImportError:
  # ensure dependency (lightweight) if missing
  import sys, subprocess
  subprocess.run([sys.executable, '-m', 'pip', 'install', '-q', 'pyaes'], check=False)
  import pyaes
key = b'0'*16
plaintext = b'A'*1024
for _ in range(500):
  aes = pyaes.AESModeOfOperationCTR(key)
  aes.encrypt(plaintext)
PY
}

# Deps
python3 -m pip show pyperf >/dev/null 2>&1 || python3 -m pip install -U pyperf
python3 -m pip show pyperformance >/dev/null 2>&1 || python3 -m pip install -U pyperformance
[ -d Flamegraph ] || git clone https://github.com/brendangregg/Flamegraph >/dev/null 2>&1 || true

# System tune (stabilize), then restore a high perf sampling cap for profiling
python3 -m pyperf system tune || true
SR=${SR:-100000}; OLD_SR="$(cat /proc/sys/kernel/perf_event_max_sample_rate 2>/dev/null || echo "")"
echo "$SR" > /proc/sys/kernel/perf_event_max_sample_rate 2>/dev/null || true
modprobe msr 2>/dev/null || true   # optional, lets tune manage turbo if available

# 0) One-time warmups (single-process) to populate OS caches & import modules
if [ "${NO_WARMUP:-0}" -eq 0 ]; then
  echo "== Warmup (${WARMUP_ITERS}x) ==" | tee "timing${SUFFIX}.txt"
  for i in $(seq 1 "$WARMUP_ITERS"); do warmup_python >/dev/null 2>&1; done
fi

# 1) Baseline timing (pyperformance harness; includes its own internal warmups per run)
$CMD | tee -a "timing${SUFFIX}.txt" >/dev/null

# 2) perf stat (IPC/MPKI) — clean CSV + derived rows
# 2) perf stat (single run after warmup). If you want raw steady-state only, set RAW_JSON=1 to bypass pyperformance.
if [ "${RAW_JSON:-0}" -eq 1 ]; then
  # Raw steady-state runner (single process) for pure AES workload
  python3 - <<'PY' > /dev/null 2>&1
import time
try:
    import pyaes
except ImportError:
    import sys, subprocess
    subprocess.run([sys.executable, '-m', 'pip', 'install', '-q', 'pyaes'], check=False)
    import pyaes
key = b'0'*16
plaintext = b'A'*1024
def run(n=60000):
    aes = pyaes.AESModeOfOperationCTR(key)
    for _ in range(n):
        aes.encrypt(plaintext)
run()
PY
  PERF_STAT_CMD='python3 - <<"PY"\nimport pyaes\nkey=b"0"*16\npt=b"A"*1024\nfor _ in range(60000): pyaes.AESModeOfOperationCTR(key).encrypt(pt)\nPY'
else
  PERF_STAT_CMD="$CMD"
fi

perf stat --no-big-num -x, -o "perf_stat${SUFFIX}.csv" \
  -e cycles:u,instructions:u,cache-references:u,cache-misses:u \
  -- bash -lc "$PERF_STAT_CMD" || true

awk -F, '
  $3=="cycles:u"       { c=$1 }
  $3=="instructions:u" { i=$1 }
  $3=="cache-misses:u" { cm=$1 }
  END{
    if ((c+0)>0 && (i+0)>0) {
      ipc = i/c; mpki = 1000*cm/i
      printf("%.6f,,derived:IPC,,\n",  ipc)  >> "perf_stat'"${SUFFIX}"'.csv"
      printf("%.6f,,derived:MPKI,,\n", mpki) >> "perf_stat'"${SUFFIX}"'.csv"
      printf("IPC=%.3f  MPKI=%.2f\n", ipc, mpki) > "perf_stat_summary'"${SUFFIX}"'.txt"
    } else {
      print "IPC/MPKI unavailable" > "perf_stat_summary'"${SUFFIX}"'.txt"
    }
  }' "perf_stat${SUFFIX}.csv"
cat "perf_stat_summary${SUFFIX}.txt" >> "timing${SUFFIX}.txt"

# 3) Aggregate perf record → combined folded stacks (more stable flamegraph)
: > "out${SUFFIX}.folded"   # aggregated folded output
for i in $(seq 1 "$FG_RUNS"); do
  rm -f perf.data
  if [ "${RAW_JSON:-0}" -eq 1 ]; then
    # Single-process tight loop (steady-state AES encrypt)
    perf record -e cycles:u --call-graph dwarf,8192 -F "$FREQ" --mmap-pages 128 -- \
      python3 - <<'PY' || true
import pyaes
key=b'0'*16
pt=b'A'*1024
for _ in range(120000):
    pyaes.AESModeOfOperationCTR(key).encrypt(pt)
PY
  else
    perf record -e cycles:u --call-graph dwarf,8192 -F "$FREQ" --mmap-pages 128 -- bash -lc "$CMD" || true
  fi
  # Prefer Python-only collapse; fallback to all if empty
  perf script --comm python --comm python3 | ./Flamegraph/stackcollapse-perf.pl > "out${SUFFIX}.folded.tmp" 2>/dev/null || true
  if [ ! -s "out${SUFFIX}.folded.tmp" ]; then
    perf script | ./Flamegraph/stackcollapse-perf.pl > "out${SUFFIX}.folded.tmp" 2>/dev/null || true
  fi
  cat "out${SUFFIX}.folded.tmp" >> "out${SUFFIX}.folded"
done
rm -f "out${SUFFIX}.folded.tmp"

# 4) Flamegraph (from aggregated folded)
./Flamegraph/flamegraph.pl --title "crypto_pyaes • cycles:u (DWARF @ ${FREQ}Hz, ${FG_RUNS}x agg)" \
  "out${SUFFIX}.folded" > "flamegraph${SUFFIX}.svg" 2>/dev/null || true

# 5) Lightweight symbol summary (faster than full report)
if [ -f perf.data ]; then
  perf report --stdio -n --no-children -g none 2>/dev/null | head -200 > "report_light${SUFFIX}.txt" || true
fi

# 6) Full annotate report with disassembly for top symbols
if [ -f perf.data ]; then
  perf annotate --stdio 2>/dev/null | head -500 > "annotate${SUFFIX}.txt" || true
fi

# 7) Optional diff flamegraph if both BEFORE and AFTER folded exist
if [ -s "out.folded" ] && [ -s "out_after.folded" ]; then
  ./Flamegraph/difffolded.pl out.folded out_after.folded \
    | ./Flamegraph/flamegraph.pl --title "AFTER − BEFORE (green=faster, red=slower)" --negate \
    > flamegraph_diff.svg 2>/dev/null || true
fi

# Restore original kernel perf sampling cap (neatness)
[ -n "$OLD_SR" ] && echo "$OLD_SR" > /proc/sys/kernel/perf_event_max_sample_rate 2>/dev/null || true

echo "Done: timing${SUFFIX}.txt perf_stat${SUFFIX}.csv  |  perf_stat_summary${SUFFIX}.txt out${SUFFIX}.folded  ->  flamegraph${SUFFIX}.svg report_light${SUFFIX}.txt annotate${SUFFIX}.txt flamegraph_diff.svg"


