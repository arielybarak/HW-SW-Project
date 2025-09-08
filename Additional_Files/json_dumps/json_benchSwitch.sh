#! NOTICE
# Create/update "after_benchmark.py" before use


# Paths
BASE=/usr/local/lib/python3.10/dist-packages/pyperformance/data-files/benchmarks
DEST="$BASE/bm_json_dumps/run_benchmark.py"

# 1) Backup original
cp -v "$DEST" "$DEST.bak"

# 2) Replace with your version
cp -v /root/after_benchmark.py "$DEST"

# 3) Clear bytecode (optional but safe)
find "$BASE/bm_json_dumps" -name '*.pyc' -delete
rm -rf "$BASE/bm_json_dumps/__pycache__"

# 4) Sanity check
python3 -m pyperformance list | grep -i json_dumps || echo "json_dumps not found"


#* To restore original backup bench
# BASE=/usr/local/lib/python3.10/dist-packages/pyperformance/data-files/benchmarks/bm_json_dumps
# cp -v "$BASE/run_benchmark.py.bak" "$BASE/run_benchmark.py"
# find "$BASE" -name '*.pyc' -delete; rm -rf "$BASE/__pycache__"


#* for after_venv version:
    #* activate using:
        #  either activate:
            # source /root/venv_after/bin/activate && /root/bench_switch
        # # or without activating:
            # PY_BIN=/root/venv_after/bin/python /root/bench_switch


# save as /root/patch_json_dumps_in_after.sh
#!/usr/bin/env bash
set -euo pipefail
PY_BIN="${PY_BIN:-/root/venv_after/bin/python}"      # venv interpreter
AFTER_FILE="${AFTER_FILE:-/root/after_benchmark.py}" # your file

# Locate the bench dir inside THIS interpreter's site-packages
BASE="$($PY_BIN - <<'PY'
import pyperformance, pathlib
print((pathlib.Path(pyperformance.__file__).resolve().parent / 'data-files' / 'benchmarks').as_posix())
PY
)"
DEST="$BASE/bm_json_dumps/run_benchmark.py"

echo "Patching: $DEST (interp: $($PY_BIN -c 'import sys;print(sys.executable)'))"
cp -v "$DEST" "$DEST.bak"
cp -v "$AFTER_FILE" "$DEST"
find "$BASE/bm_json_dumps" -name '*.pyc' -delete
rm -rf "$BASE/bm_json_dumps/__pycache__"

# Sanity: list bench from THIS interpreter
$PY_BIN -m pyperformance list | grep -i json_dumps || echo "json_dumps not found in this interpreter"
