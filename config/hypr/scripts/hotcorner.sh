#!/bin/bash
# Hot corner daemon — triggers hyprexpo on the top-left corner of any monitor.
# Monitor geometry is reloaded every 60 seconds to handle hotplug events.
# Requires: hyprctl, python3, jq (or python3 json module used directly)

THRESHOLD=15        # pixels from corner edge to trigger
COOLDOWN=1.0        # seconds between triggers
POLL=0.1            # cursor poll interval in seconds
GEOMETRY_TTL=60     # seconds between monitor geometry reloads

_last_trigger=0
_last_geometry=0
declare -A _corners  # key: "monitor_N", value: "x y w h"

reload_monitors() {
    local now
    now=$(date +%s)
    if (( now - _last_geometry < GEOMETRY_TTL )); then return; fi
    _last_geometry=$now

    local json
    json=$(hyprctl monitors -j 2>/dev/null) || return

    # Parse all monitors: extract x, y, width, height for each
    local count
    count=$(echo "$json" | python3 -c "
import sys, json
monitors = json.load(sys.stdin)
for i, m in enumerate(monitors):
    x = m.get('x', 0)
    y = m.get('y', 0)
    w = m.get('width', 0)
    h = m.get('height', 0)
    print(i, x, y, w, h)
" 2>/dev/null)

    # Reset and repopulate corners array
    unset _corners
    declare -gA _corners
    while read -r idx x y w h; do
        _corners["$idx"]="$x $y $w $h"
    done <<< "$count"
}

trigger_hyprexpo() {
    local now
    now=$(date +%s%N)
    now=$(( now / 1000000 ))  # convert to milliseconds
    local last_ms=$(( $(echo "$_last_trigger" | awk '{printf "%.0f", $1 * 1000}') ))
    local cooldown_ms=$(( $(echo "$COOLDOWN" | awk '{printf "%.0f", $1 * 1000}') ))

    if (( now - last_ms >= cooldown_ms )); then
        hyprctl dispatch "hyprexpo:expo toggle" >/dev/null 2>&1
        _last_trigger=$(date +%s%N | awk '{printf "%.3f", $1/1000000000}')
        sleep "$COOLDOWN"
    fi
}

reload_monitors

while true; do
    # Periodically refresh monitor list
    reload_monitors

    # Get current cursor position
    cursor=$(hyprctl cursorpos 2>/dev/null) || { sleep "$POLL"; continue; }
    cx=$(echo "$cursor" | awk -F',' '{gsub(/ /, "", $1); print $1}')
    cy=$(echo "$cursor" | awk -F',' '{gsub(/ /, "", $2); print $2}')

    # Check top-left corner of every monitor
    for key in "${!_corners[@]}"; do
        read -r mx my mw mh <<< "${_corners[$key]}"
        tl_x=$(( mx + THRESHOLD ))
        tl_y=$(( my + THRESHOLD ))
        if (( cx <= tl_x && cy <= tl_y )); then
            trigger_hyprexpo
            break
        fi
    done

    sleep "$POLL"
done
