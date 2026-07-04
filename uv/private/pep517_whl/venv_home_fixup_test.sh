#!/usr/bin/env bash
# Regression for venv_home_fixup.sh: a RELATIVE pyvenv.cfg `home` (the shape
# venv.bzl emits) must be rewritten to the ABSOLUTE interpreter bin dir — the
# property that keeps sys.base_prefix off the compile-time `/install`.
set -euo pipefail

FIXUP="$(find -L "${TEST_SRCDIR:-.}" -name venv_home_fixup.sh -type f 2>/dev/null | head -n1 || true)"
[ -n "$FIXUP" ] || { echo "FAIL: could not locate venv_home_fixup.sh in runfiles"; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Real layout: interpreter repo and sdist repo are siblings under <tool>.runfiles/,
# so the venv's relative `home`/symlink resolve as they do in a real build.
RUNFILES="$WORK/build_tool.runfiles"

mkdir -p "$RUNFILES/fake_pbs/bin" "$RUNFILES/fake_pbs/lib/python3.12"
printf '#!/bin/sh\n' >"$RUNFILES/fake_pbs/bin/python3"
chmod +x "$RUNFILES/fake_pbs/bin/python3"

# build_tool venv with a RELATIVE home, as venv.bzl writes it.
VENV="$RUNFILES/somerepo/._build_tool.venv"
mkdir -p "$VENV/bin"
ln -s "../../../fake_pbs/bin/python3" "$VENV/bin/python"
cat >"$VENV/pyvenv.cfg" <<'EOF'
home = ../../fake_pbs/bin
implementation = CPython
version_info = 3.12.0
include-system-site-packages = false
EOF

TOOL="$WORK/build_tool"
cat >"$TOOL" <<EOF
#!/bin/sh
grep '^home' "$VENV/pyvenv.cfg"
echo "TOOL_ARGS: \$*"
EOF
chmod +x "$TOOL"

OUT="$("$FIXUP" "$TOOL" alpha beta)"
echo "--- wrapper output ---"
echo "$OUT"
echo "----------------------"

home_line="$(printf '%s\n' "$OUT" | grep '^home = ' || true)"

case "$home_line" in
    "home = /"*) : ;;
    *) echo "FAIL: home is not absolute: '$home_line'"; exit 1 ;;
esac

case "$home_line" in
    *"/fake_pbs/bin") : ;;
    *) echo "FAIL: home does not point at the interpreter bin: '$home_line'"; exit 1 ;;
esac

printf '%s\n' "$OUT" | grep -q '^TOOL_ARGS: alpha beta$' ||
    { echo "FAIL: tool args not forwarded"; exit 1; }

grep -q '^implementation = CPython$' "$VENV/pyvenv.cfg" ||
    { echo "FAIL: pyvenv.cfg body was clobbered"; exit 1; }

echo "PASS"
