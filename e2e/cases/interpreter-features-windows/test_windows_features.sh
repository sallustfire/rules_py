#!/usr/bin/env bash
set -euo pipefail

# Checks the Windows interpreter files in this test's runfiles. $1 is "kept"
# for the default build or "excluded" for one with exclude_feature=tkinter.
MODE="$1"
ROOT="${TEST_SRCDIR}/rules_py++python_interpreters+python_3_13_x86_64_pc_windows_msvc"

errors=0

expect() {
    local want="$1" path="$2"
    if [ -e "$ROOT/$path" ]; then
        local have=present
    else
        local have=absent
    fi
    if [ "$have" != "$want" ]; then
        echo "FAIL: $path is $have, want $want"
        errors=$((errors + 1))
    fi
}

# tkinter's files on Windows: its package, the _tkinter extension, the Tcl
# and Tk DLLs, and the Tcl and Tk libraries under tcl/ that Tk() loads.
TKINTER=(
    Lib/tkinter/__init__.py
    DLLs/_tkinter.pyd
    DLLs/tcl86t.dll
    DLLs/tk86t.dll
    tcl/dde1.4/tcldde14.dll
    tcl/reg1.3/tclreg13.dll
    tcl/tcl8.6/init.tcl
    tcl/tk8.6/tk.tcl
)

case "$MODE" in
kept)
    for path in "${TKINTER[@]}"; do
        expect present "$path"
    done
    # Debug symbols and Tcl's build files are not runtime files.
    for path in DLLs/_tkinter.pdb tcl/tcl86t.lib tcl/tclConfig.sh; do
        expect absent "$path"
    done
    ;;
excluded)
    for path in "${TKINTER[@]}"; do
        expect absent "$path"
    done
    for path in Lib/os.py DLLs/_ssl.pyd python.exe; do
        expect present "$path"
    done
    ;;
*)
    echo "usage: $0 kept|excluded"
    exit 2
    ;;
esac

if [ "$errors" -gt 0 ]; then
    echo "FAILED: $errors check(s) failed"
    exit 1
fi
echo "PASS: Windows interpreter files with tkinter $MODE"
