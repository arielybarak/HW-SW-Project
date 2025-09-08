#! NOTICE
# Create/update "after_benchmark.py" before use


# Paths
BASE=/usr/local/lib/python3.10/dist-packages/pyperformance/data-files/benchmarks
DEST="$BASE/bm_crypto_pyaes/run_benchmark.py"

# 1) Backup original
cp -v "$DEST" "$DEST.bak"

# 2) Replace with your version
cp -v /root/after_benchmark.py "$DEST"

# 3) Clear bytecode (optional but safe)
find "$BASE/bm_crypto_pyaes" -name '*.pyc' -delete
rm -rf "$BASE/bm_crypto_pyaes/__pycache__"

# 4) Sanity check
python3 -m pyperformance list | grep -i crypto_pyaes || echo "crypto_pyaes not found"


#* To restore original backup bench
# BASE=/usr/local/lib/python3.10/dist-packages/pyperformance/data-files/benchmarks/bm_crypto_pyaes
# cp -v "$BASE/run_benchmark.py.bak" "$BASE/run_benchmark.py"
# find "$BASE" -name '*.pyc' -delete; rm -rf "$BASE/__pycache__"
