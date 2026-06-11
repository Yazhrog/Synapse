#!/bin/bash
# Add hyprbars window decoration buttons at runtime.
# This is called by plugins.lua via hl.plugin.hyprbars.add_button() on config reload.
# This script is kept as a manual fallback — normally not needed.
hyprctl dispatch "hyprbars:clearbuttons"
hyprctl dispatch "hyprbars:addbutton rgba(f38ba8ff) rgba(ffffffff) 18  'hyprctl dispatch killactive'"
hyprctl dispatch "hyprbars:addbutton rgba(f9e2afff) rgba(ffffffff) 18  'hyprctl dispatch fullscreen 1'"
