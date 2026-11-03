#!/usr/bin/env bash
# Offscreen smoke test of the Quickshell config: loads tests/smoke.qml against a
# throwaway HOME / SYNAPSE_CONFIG_DIR and fails on any QML error.
# Usage: config/quickshell/tests/smoke.sh
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/qs" "$tmp/home" "$tmp/run" "$tmp/cfg/src/user_data"
chmod 700 "$tmp/run"
cp -r "$here/src" "$tmp/qs/src"
cp "$here/tests/smoke.qml" "$tmp/qs/shell.qml"

log="$tmp/log.txt"
env -i PATH="$PATH" HOME="$tmp/home" XDG_RUNTIME_DIR="$tmp/run" LANG=C.UTF-8 \
    QT_QPA_PLATFORM=offscreen SYNAPSE_CONFIG_DIR="$tmp/cfg" \
    timeout 30 quickshell -p "$tmp/qs" >"$log" 2>&1 || true

sed 's/\x1b\[[0-9;]*m//g' "$log" > "$log.clean"
errors="$(grep -E 'TypeError|ReferenceError|SyntaxError|is not defined|is not a type|Failed to load configuration|caused by|Cannot assign|Unable to assign' "$log.clean" || true)"

if [[ -n "$errors" ]] || ! grep -q 'SMOKE OK' "$log.clean"; then
    echo "Smoke test failed:"
    echo "${errors:-(no SMOKE OK line)}"
    exit 1
fi
echo "Smoke test passed"
