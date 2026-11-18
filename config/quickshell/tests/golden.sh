#!/usr/bin/env bash
# Golden-image check: proves a refactor changes nothing on screen.
#
# Captures every scene of tests/lib/SceneList.qml offscreen (Qt's software
# renderer) for two trees and compares the images pixel by pixel. Both
# captures run on the same machine with the same fonts and renderer, so any
# difference comes from the code.
#
# Usage:
#   tests/golden.sh capture <quickshell-dir> <out-dir>
#       <quickshell-dir> is a checkout's config/quickshell (with its own
#       tests/smoke-registries.qml and tests/lib/).
#   tests/golden.sh compare <base-dir> <head-dir>
#       Exit 1 if a scene differs or disappeared. Diff images go to
#       <head-dir>/diff/.
#   tests/golden.sh diff [<base-ref>]
#       Captures <base-ref> (default: the merge-base with origin/dev) and the
#       working tree, then compares them. Images stay in $GOLDEN_WORK (default:
#       a temp dir it prints). Skips (exit 0) when <base-ref> has no scenes yet.
#
# Determinism: no network/system tools on PATH (only bash and sh, so every
# service shows its "unavailable" state), no D-Bus, no Pipewire, no Hyprland,
# empty user data, a fixed locale. Scenes showing the time or date ("clock")
# are only compared when libfaketime is installed (pacman -S libfaketime):
# both captures then run at 2026-01-01 12:00.
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
faketime_lib=""
for f in /usr/lib/faketime/libfaketime.so.1 /usr/lib/x86_64-linux-gnu/faketime/libfaketime.so.1; do
    [[ -f "$f" ]] && { faketime_lib="$f"; break; }
done

capture() {
    local tree out tmp qs_bin
    tree="$(cd "$1" && pwd)"; out="$2"
    [[ -f "$tree/tests/smoke-registries.qml" ]] || { echo "golden: no scenes in $tree (tests/smoke-registries.qml missing)"; return 2; }
    mkdir -p "$out"; out="$(cd "$out" && pwd)"
    qs_bin="$(command -v quickshell)"
    # A fixed path: some views show paths under HOME (e.g. the repo path in
    # Config → Misc), so a random temp dir would differ between captures.
    tmp="${TMPDIR:-/tmp}/synapse-golden"
    rm -rf "$tmp"
    trap 'rm -rf "$tmp"' RETURN

    mkdir -p "$tmp/qs" "$tmp/cfg/src/user_data" "$tmp/home" "$tmp/run" "$tmp/bin"
    chmod 700 "$tmp/run"
    cp -r "$tree/src" "$tmp/qs/src"
    cp "$tree/tests/smoke-registries.qml" "$tmp/qs/shell.qml"
    cp "$tree"/tests/lib/*.qml "$tmp/qs/"
    ln -s "$(command -v bash)" "$tmp/bin/bash"
    ln -s "$(command -v sh)"   "$tmp/bin/sh"

    local -a env_args=(
        PATH="$tmp/bin" HOME="$tmp/home" XDG_RUNTIME_DIR="$tmp/run" LANG=C.UTF-8 TZ=UTC
        QT_QPA_PLATFORM=offscreen SYNAPSE_CONFIG_DIR="$tmp/cfg" SYNAPSE_GOLDEN_OUT="$out"
        DBUS_SYSTEM_BUS_ADDRESS=unix:path=/nonexistent
    )
    if [[ -n "$faketime_lib" ]]; then
        env_args+=(LD_PRELOAD="$faketime_lib" FAKETIME="@2026-01-01 12:00:00" FAKETIME_DONT_FAKE_MONOTONIC=1)
        echo yes > "$out/.faketime"
    else
        echo no > "$out/.faketime"
    fi

    env -i "${env_args[@]}" "$(command -v timeout)" 180 "$qs_bin" -p "$tmp/qs" > "$out/.log" 2>&1 || true
    sed -i 's/\x1b\[[0-9;]*m//g' "$out/.log"
    if ! grep -q 'SMOKE OK' "$out/.log"; then
        echo "golden: capture of $tree did not finish; last lines of $out/.log:"
        tail -n 40 "$out/.log" | sed 's/^/    /'
        return 1
    fi
    echo "golden: captured $(ls "$out"/*.png | wc -l) scenes from $tree"
}

compare() {
    local base="$1" head="$2" fail=0 skipped=0 same=0 clock_ok=1
    [[ "$(cat "$base/.faketime" 2>/dev/null)" == yes && "$(cat "$head/.faketime" 2>/dev/null)" == yes ]] || clock_ok=0
    mkdir -p "$head/diff"
    for img in "$base"/*.png; do
        local name; name="$(basename "$img" .png)"
        if [[ ! -f "$head/$name.png" ]]; then
            echo "  MISSING  $name (in base, not in head)"; fail=1; continue
        fi
        if [[ $clock_ok == 0 ]] && grep -q "^ DEBUG qml: GOLDEN $name clock$" "$head/.log"; then
            echo "  SKIPPED  $name (shows the time; install libfaketime to compare it)"; skipped=$((skipped + 1)); continue
        fi
        local ae
        ae="$(magick compare -metric AE -fuzz 1% "$img" "$head/$name.png" "$head/diff/$name.png" 2>&1 >/dev/null || true)"
        ae="${ae%% *}"
        if [[ "$ae" == "0" ]]; then
            same=$((same + 1)); rm -f "$head/diff/$name.png"
        else
            echo "  CHANGED  $name ($ae)"; fail=1
        fi
    done
    for img in "$head"/*.png; do
        [[ -f "$base/$(basename "$img")" ]] || echo "  NEW      $(basename "$img" .png)"
    done
    echo "golden: $same identical, $skipped skipped$([[ $fail == 1 ]] && echo ", differences above (diff images in $head/diff/)")"
    return $fail
}

case "${1:-}" in
    capture) capture "$2" "$3" ;;
    compare) compare "$2" "$3" ;;
    diff)
        ref="${2:-$(git -C "$here" merge-base HEAD origin/dev)}"
        work="${GOLDEN_WORK:-$(mktemp -d)}"
        mkdir -p "$work"
        git -C "$here" worktree add -q --detach "$work/base" "$ref"
        trap 'git -C "$here" worktree remove --force "$work/base"' EXIT
        if [[ ! -f "$work/base/config/quickshell/tests/smoke-registries.qml" ]]; then
            echo "golden: $ref has no scenes yet, nothing to compare against"
            exit 0
        fi
        capture "$work/base/config/quickshell" "$work/base-img"
        capture "$here" "$work/head-img"
        echo "golden: images in $work"
        compare "$work/base-img" "$work/head-img"
        ;;
    *) sed -n '2,25p' "$0"; exit 2 ;;
esac
