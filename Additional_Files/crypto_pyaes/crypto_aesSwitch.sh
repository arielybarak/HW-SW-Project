# Use the same Python as pyperformance’s venv
VENV_DIR=$(ls -d /root/venv/* | tail -n1)
PY="$VENV_DIR/bin/python"

# Ensure pyaes is installed in that venv
$PY -m pip show pyaes >/dev/null 2>&1 || $PY -m pip install -q pyaes

# Locate pyaes package dir
PKG_DIR=$($PY - <<'PY'
import pyaes, os
print(os.path.dirname(pyaes.__file__))
PY
)

# Backup original and replace with your version
cp -v "$PKG_DIR/aes.py" "$PKG_DIR/aes.py.bak"
cp -v /root/aes_after.py "$PKG_DIR/aes.py"

# Clear bytecode cache
find "$PKG_DIR" -name '*.pyc' -delete
rm -rf "$PKG_DIR/__pycache__"

# Run the benchmark (AFTER)
cd /root
./crypto.sh after
