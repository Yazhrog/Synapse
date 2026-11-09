#!/usr/bin/env bash
# Offscreen smoke test of the Quickshell config: loads tests/smoke.qml and
# tests/smoke-imports.qml against a throwaway HOME / SYNAPSE_CONFIG_DIR and
# fails on any QML error.
# Usage: config/quickshell/tests/smoke.sh
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/home" "$tmp/run"
chmod 700 "$tmp/run"

# run <qml file>: loads it as shell.qml in a fresh copy of src/, fails on any QML error.
run() {
    local name="$1" dir="$tmp/$(basename "$1" .qml)"
    mkdir -p "$dir/qs" "$dir/cfg/src/user_data"
    cp -r "$here/src" "$dir/qs/src"
    cp "$here/tests/$name" "$dir/qs/shell.qml"

    local log="$dir/log.txt"
    env -i PATH="$PATH" HOME="$tmp/home" XDG_RUNTIME_DIR="$tmp/run" LANG=C.UTF-8 \
        QT_QPA_PLATFORM=offscreen SYNAPSE_CONFIG_DIR="$dir/cfg" \
        timeout 30 quickshell -p "$dir/qs" >"$log" 2>&1 || true

    sed 's/\x1b\[[0-9;]*m//g' "$log" > "$log.clean"
    local errors
    errors="$(grep -E 'TypeError|ReferenceError|SyntaxError|is not defined|is not a type|Failed to load configuration|caused by|Cannot assign|Unable to assign' "$log.clean" || true)"

    if [[ -n "$errors" ]] || ! grep -q 'SMOKE OK' "$log.clean"; then
        echo "Smoke test failed ($name):"
        echo "${errors:-(no SMOKE OK line)}"
        return 1
    fi
    echo "Smoke test passed ($name)"
}

# smoke.qml: the singletons and shared components. smoke-imports.qml: the
# popups through the Dynamic Surface's own imports (catches unscanned folders).
run smoke.qml
run smoke-imports.qml
