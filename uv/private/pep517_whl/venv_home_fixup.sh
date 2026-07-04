#!/usr/bin/env bash
# Wrapper for the PEP 517 sdist build action.
#
# It rewrites the ephemeral `build_tool` venv's `pyvenv.cfg` `home` to an
# ABSOLUTE path before exec'ing the build tool ($1), then forwards the rest of
# argv unchanged.
#
# Why: `venv.bzl` writes `home` as a path relative to the venv (for OCI
# relocatability of long-lived venvs). CPython's getpath derives
# `sys.base_prefix` by searching up from `home`; several interpreters
# (rules_python's python-build-standalone, stock CPython, most system pythons)
# resolve a *relative* `home` against the process CWD rather than the venv dir,
# and when that misses they fall back to the interpreter's compile-time prefix
# — `/install` for python-build-standalone — so the interpreter aborts with
# `ModuleNotFoundError: No module named 'encodings'`. aspect_rules_py's own PBS
# anchors a relative `home` to the venv dir, so only other interpreters hit this.
#
# The build_tool venv is ephemeral (only ever materialized inside this action,
# never repacked into an OCI layer), so the relocatability constraint doesn't
# apply. Pinning `home` to the absolute interpreter bin dir here fixes
# base_prefix for every interpreter, in pure and native builds alike. Only the
# runfiles copy is touched; the on-disk output venv keeps its relative `home`.
set -eu

# Ensure the standard coreutils are reachable even when the action runs without
# a default PATH (Bazel < 9 without --incompatible_strict_action_env).
PATH="${PATH:+$PATH:}/usr/bin:/bin:/usr/local/bin"

tool="$1"
shift

rewrite_home() {
    cfg="$1"
    venv_bin="${cfg%/pyvenv.cfg}/bin/python"
    [ -e "$venv_bin" ] || return 0
    # Resolve the venv's bin/python symlink chain to the real interpreter,
    # portably (no `readlink -f`, which is unavailable on older macOS).
    target="$venv_bin"
    while [ -L "$target" ]; do
        link="$(readlink "$target")"
        case "$link" in
            /*) target="$link" ;;
            *) target="$(dirname "$target")/$link" ;;
        esac
    done
    home="$(cd "$(dirname "$target")" && pwd -P)"
    new="$(sed "s|^home = .*|home = ${home}|" "$cfg")"
    # The runfiles pyvenv.cfg is a symlink into read-only output; replace the
    # link with a real file in the (writable) runfiles venv dir.
    rm -f "$cfg"
    printf '%s\n' "$new" >"$cfg"
}

runfiles="${tool}.runfiles"
if [ -d "$runfiles" ]; then
    for cfg in "$runfiles"/*/._build_tool.venv/pyvenv.cfg; do
        [ -e "$cfg" ] || continue
        rewrite_home "$cfg"
    done
fi

# Let the tool's own launcher rediscover its runfiles via <tool>.runfiles
# rather than inheriting this wrapper action's runfiles env.
unset RUNFILES_DIR RUNFILES_MANIFEST_FILE RUNFILES_MANIFEST_ONLY 2>/dev/null || true

exec "$tool" "$@"
