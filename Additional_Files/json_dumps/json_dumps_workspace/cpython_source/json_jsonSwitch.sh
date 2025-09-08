#!/usr/bin/env bash
set -euo pipefail

PYVER="${PYVER:-3.10.12}"
SRC_DIR="${SRC_DIR:-/root/Python-$PYVER}"
PREFIX="${PREFIX:-/root/python-custom}"
PATCH_JSON="${PATCH_JSON:-/root/_json.c}"   # your modified file
JOBS="${JOBS:-$(nproc)}"

echo "==> Ensure patched _json.c is in tree"
[[ -f "$PATCH_JSON" ]] || { echo "Missing: $PATCH_JSON"; exit 1; }
cp -f "$PATCH_JSON" "$SRC_DIR/Modules/_json.c"

echo "==> Clean configure and rebuild (fast: no PGO/LTO)"
cd "$SRC_DIR"
make distclean >/dev/null 2>&1 || true
./configure --prefix="$PREFIX"
make -j"$JOBS"
make install

echo "==> Verify shared-module _json"
if "$PREFIX/bin/python3" - <<'PY'
import _json, sys
print("OK shared:", getattr(_json, "__file__", "built-in?"), file=sys.stderr)
PY
then
  exit 0
fi

echo "==> Shared-module _json missing. Building as built-in (static) fallback."
echo "_json _json.c" > "$SRC_DIR/Modules/Setup.local"

make distclean >/dev/null 2>&1 || true
./configure --prefix="$PREFIX"
make -j"$JOBS"
make install

echo "==> Verify built-in _json"
"$PREFIX/bin/python3" - <<'PY'
import _json
# Built-ins usually lack __file__
print("OK built-in" if not hasattr(_json, "__file__") else f"OK: {_json.__file__}")
PY






