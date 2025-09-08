#!/usr/bin/env bash
# Compare BEFORE (no suffix) vs AFTER (_after)
# Writes summary to comp.txt (speedup + % improvement + IPC/MPKI). Optional diff flamegraph.

set -u
cd /root

OUT="comp.txt"
: > "$OUT"
exec >"$OUT" 2>&1

# BEFORE (no suffix)
BEF_TIME="timing.txt"
BEF_SUM="perf_stat_summary.txt"
BEF_FOLDED="out.folded"

# AFTER (with _after suffix)
AFT_TIME="timing_after.txt"
AFT_SUM="perf_stat_summary_after.txt"
AFT_FOLDED="out_after.folded"

# --- helpers ---
get_mean_ms() {
  # Extract first pure number on the "Mean +- std dev" line (e.g., 20.6)
  awk '
    /Mean[[:space:]]+\+\-[[:space:]]+std[[:space:]]+dev/ {
      for (i=1; i<=NF; i++) if ($i ~ /^[0-9.]+$/) { print $i; exit }
    }
  ' "$1"
}

get_ipc()  { grep -m1 'IPC='  "$1" 2>/dev/null | sed -E 's/.*IPC=([0-9.]+).*/\1/'; }
get_mpki() { grep -m1 'MPKI=' "$1" 2>/dev/null | sed -E 's/.*MPKI=([0-9.]+).*/\1/'; }

# --- presence check ---
missing=0
for f in "$BEF_TIME" "$AFT_TIME" "$BEF_SUM" "$AFT_SUM"; do
  if [[ ! -s "$f" ]]; then
    echo "Missing required file: $f"
    missing=1
  fi
done
if [[ $missing -eq 1 ]]; then
  echo "Abort: run the unified script once without args (BEFORE) and once with 'after' (AFTER)."
  exit 1
fi

# --- read metrics ---
bef_ms=$(get_mean_ms "$BEF_TIME")
aft_ms=$(get_mean_ms "$AFT_TIME")
bef_ipc=$(get_ipc "$BEF_SUM");     aft_ipc=$(get_ipc "$AFT_SUM")
bef_mpki=$(get_mpki "$BEF_SUM");   aft_mpki=$(get_mpki "$AFT_SUM")

# --- compute deltas ---
speedup="NA"; improve="NA"
if [[ -n "${bef_ms:-}" && -n "${aft_ms:-}" ]]; then
  speedup=$(awk -v b="$bef_ms" -v a="$aft_ms" 'BEGIN{ if (a>0) printf("%.3f", b/a); else print "NA" }')
  improve=$(awk -v b="$bef_ms" -v a="$aft_ms" 'BEGIN{ if (b>0) printf("%.1f", (1 - a/b)*100); else print "NA" }')
fi

echo "=== BEFORE vs AFTER (json_dumps) ==="
printf "Time (mean ms):   BEFORE %-8s  AFTER %-8s  | Speedup: x%s  Improvement: %s%%\n" \
  "${bef_ms:-NA}" "${aft_ms:-NA}" "$speedup" "$improve"
printf "IPC:              BEFORE %-8s  AFTER %-8s\n" "${bef_ipc:-NA}" "${aft_ipc:-NA}"
printf "MPKI:             BEFORE %-8s  AFTER %-8s\n" "${bef_mpki:-NA}" "${aft_mpki:-NA}"

# --- optional diff flamegraph if folded stacks exist (from perf script collapse) ---
if [[ -s "$BEF_FOLDED" && -s "$AFT_FOLDED" ]]; then
  [ -d Flamegraph ] || git clone https://github.com/brendangregg/Flamegraph >/dev/null 2>&1 || true
  ./Flamegraph/difffolded.pl "$BEF_FOLDED" "$AFT_FOLDED" \
    | ./Flamegraph/flamegraph.pl --title "AFTER − BEFORE (green=faster, red=slower)" --negate \
    > flamegraph_diff.svg 2>/dev/null || true
  echo "Created: flamegraph_diff.svg"
else
  echo "Skip diff flamegraph (missing $BEF_FOLDED or $AFT_FOLDED)."
fi

echo "Wrote summary to $OUT"
