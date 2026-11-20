#!/usr/bin/env bash
set -euo pipefail

# Arguments: the default interpreter's files, "--", then the files with
# tkinter excluded. Each list is written relative to the interpreter root.
kept="$TEST_TMPDIR/kept"
excluded="$TEST_TMPDIR/excluded"
: >"$kept"
while [ "$1" != "--" ]; do
    echo "${1#*_windows_msvc/}" >>"$kept"
    shift
done
shift
printf '%s\n' "${@#*_windows_msvc/}" >"$excluded"

errors=0

# tkinter's files on Windows: its package, the _tkinter extension, the Tcl
# and Tk DLLs, and the Tcl/Tk script library _tkinter loads at runtime.
for path in \
    Lib/tkinter/__init__.py \
    DLLs/_tkinter.pyd \
    DLLs/tcl86t.dll \
    DLLs/tk86t.dll \
    tcl/tcl8.6/init.tcl \
    tcl/tk8.6/tk.tcl; do
    if ! grep -qxF "$path" "$kept"; then
        echo "FAIL: $path missing from the default interpreter"
        errors=$((errors + 1))
    fi
    if grep -qxF "$path" "$excluded"; then
        echo "FAIL: $path present with tkinter excluded"
        errors=$((errors + 1))
    fi
done

# Excluding tkinter leaves the rest of the standard library and DLLs.
for path in Lib/threading.py DLLs/_ssl.pyd python.exe; do
    if ! grep -qxF "$path" "$excluded"; then
        echo "FAIL: $path missing with tkinter excluded"
        errors=$((errors + 1))
    fi
done

if [ "$errors" -gt 0 ]; then
    echo "FAILED: $errors check(s) failed"
    exit 1
fi
echo "PASS: exclude_feature=tkinter removes tkinter's files from a Windows interpreter"
