#!/usr/bin/env bash
# Offscreen smoke and contract tests of the Quickshell config: loads each test
# file below against a throwaway HOME / SYNAPSE_CONFIG_DIR and fails on any
# QML error, on a FAIL line, or when the file's done line is missing.
# Usage: config/quickshell/tests/smoke.sh
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/home" "$tmp/run"
chmod 700 "$tmp/run"

# run <qml file> [done line]: loads it as shell.qml in a fresh copy of src/,
# fails on any QML error or FAIL line, or without the done line (SMOKE OK).
run() {
    local name="$1" done_line="${2:-SMOKE OK}" dir="$tmp/$(basename "$1" .qml)"
    mkdir -p "$dir/qs" "$dir/cfg/src/user_data"
    cp -r "$here/src" "$dir/qs/src"
    cp "$here/tests/$name" "$dir/qs/shell.qml"
    # Only the scene runner gets the scene list: next to shell.qml it is
    # scanned, and its imports would hide the folder-scanning trap that
    # smoke-imports.qml exists to catch.
    [[ "$name" == smoke-registries.qml ]] && cp "$here"/tests/lib/*.qml "$dir/qs/"

    local log="$dir/log.txt"
    env -i PATH="$PATH" HOME="$tmp/home" XDG_RUNTIME_DIR="$tmp/run" LANG=C.UTF-8 \
        QT_QPA_PLATFORM=offscreen SYNAPSE_CONFIG_DIR="$dir/cfg" \
        timeout 60 quickshell -p "$dir/qs" >"$log" 2>&1 || true

    sed 's/\x1b\[[0-9;]*m//g' "$log" > "$log.clean"
    local errors
    errors="$(grep -E 'TypeError|ReferenceError|SyntaxError|is not defined|is not a type|Failed to load configuration|caused by|Cannot assign|Unable to assign|FAIL ' "$log.clean" || true)"

    if [[ -n "$errors" ]] || ! grep -q "$done_line" "$log.clean"; then
        echo "Smoke test failed ($name):"
        echo "${errors:-(no $done_line line)}"
        return 1
    fi
    echo "Smoke test passed ($name)"
}

# smoke.qml: the singletons and shared components. smoke-imports.qml: the
# popups through the Dynamic Surface's own imports (catches unscanned folders).
run smoke.qml
run smoke-imports.qml
# smoke-registries.qml: every scene of lib/SceneList.qml (each popup content,
# page, tab and bar part) loads on its own.
run smoke-registries.qml
# contracts.qml: keybind-defaults.json and the IPC targets agree.
run contracts.qml "CONTRACTS OK"
# core.qml: behaviour of the core toolkit (Exec, ExecQueue, JsonStore, Lease).
run core.qml "CORE OK"
# lifecycle.qml: popup lifecycle (SurfaceState, PopupLifecycle) and Dialogs.
run lifecycle.qml "LIFECYCLE OK"
