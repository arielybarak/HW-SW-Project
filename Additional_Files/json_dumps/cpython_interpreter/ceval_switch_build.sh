#!/usr/bin/env bash
set -euo pipefail
umask 022

# ---- Config (override via env) ----
PYVER="${PYVER:-3.10.12}"
PREFIX="${PREFIX:-/root/python-custom}"
SRC_DIR="${SRC_DIR:-/root/Python-$PYVER}"
TARBALL="${TARBALL:-/root/Python-$PYVER.tgz}"
PATCH_CEVAL="${PATCH_CEVAL:-/root/ceval.c}"   # your modified Python/ceval.c
VENV="${VENV:-/root/venv_after}"
BENCH_DIR="${BENCH_DIR:-/root}"
J_NAME="${J_NAME:-j}"
JOBS="${JOBS:-$(nproc)}"
RECREATE_VENV="${RECREATE_VENV:-0}"
PYPERFORMANCE_VERSION="${PYPERFORMANCE_VERSION:-}"
PYPERF_VERSION="${PYPERF_VERSION:-}"

echo "==> Deps (minimal; avoid Tk/X chain)"
apt-get update -y
apt-get install -y --no-install-recommends \
  build-essential wget \
  libssl-dev zlib1g-dev libreadline-dev libncurses-dev \
  libffi-dev libsqlite3-dev libbz2-dev liblzma-dev uuid-dev
apt --fix-broken install -y || true

echo "==> Fetch CPython $PYVER (reuse if present)"
if [[ ! -f "$TARBALL" ]]; then
  wget -q -O "$TARBALL" "https://www.python.org/ftp/python/$PYVER/Python-$PYVER.tgz"
fi
if [[ ! -d "$SRC_DIR" ]]; then
  tar xf "$TARBALL" -C "$(dirname "$SRC_DIR")"
fi

echo "==> Patch Python/ceval.c (if provided)"
if [[ -f "$PATCH_CEVAL" ]]; then
  cp -f "$PATCH_CEVAL" "$SRC_DIR/Python/ceval.c"
  echo "Patched from: $PATCH_CEVAL"
else
  echo "WARNING: $PATCH_CEVAL not found; building upstream ceval.c"
fi

echo "==> Configure (FAST: no PGO/LTO)"
cd "$SRC_DIR"
if [[ ! -f Makefile ]]; then
  ./configure --prefix="$PREFIX"
fi

echo "==> Build (incremental) & install"
make -j"$JOBS"
make install

echo "==> Sanity: interpreter path; quick exec smoke (hits ceval)"
"$PREFIX/bin/python3" -V
"$PREFIX/bin/python3" - <<'PY'
# simple exec loop to ensure interpreter runs fine
s = 0
for i in range(10_000):
    s += (i & 7)
print("ceval smoke OK:", s)
PY

echo "==> Venv bound to custom interpreter"
if [[ "$RECREATE_VENV" = "1" && -d "$VENV" ]]; then
  rm -rf "$VENV"
fi
if [[ ! -d "$VENV" ]]; then
  "$PREFIX/bin/python3" -m venv "$VENV"
fi
# shellcheck disable=SC1090
source "$VENV/bin/activate"
python -m pip install -U pip wheel

# Pin tool versions if requested
if [[ -n "$PYPERFORMANCE_VERSION" ]]; then
  python -m pip install "pyperformance==$PYPERFORMANCE_VERSION"
else
  python -m pip install -U pyperformance
fi
if [[ -n "$PYPERF_VERSION" ]]; then
  python -m pip install "pyperf==$PYPERF_VERSION"
else
  python -m pip install -U pyperf
fi

echo "==> Run AFTER pass"
cd "$BENCH_DIR"

echo "==> DONE (ceval.c fast path)."
