-- Synapse keybindings
--
-- Synapse popup binds (Super+D, Super+V, Super+A, Super+M, Super+N, Super+W,
-- Super+B, Super+Escape, Alt+F9, etc.) are registered internally by Synapse
-- via Quickshell/QML — they are NOT listed here to avoid conflicts.
-- The Synapse installer will warn if any overlap is detected.

-- ── App launchers ─────────────────────────────────────────────────────────────
hl.bind("SUPER + Return", hl.dsp.exec_cmd("ghostty"))
hl.bind("SUPER + E",      hl.dsp.exec_cmd("nautilus --new-window"))
hl.bind("SUPER + B",      hl.dsp.exec_cmd("zen-browser"))

-- ── Window management ─────────────────────────────────────────────────────────
hl.bind("SUPER + W",          hl.dsp.window.close())
hl.bind("SUPER + F",          hl.dsp.window.fullscreen({mode = "fullscreen"}))
hl.bind("SUPER + M",          hl.dsp.window.fullscreen({ mode = "maximize" }))
hl.bind("SUPER + T",          hl.dsp.window.float({ action = "toggle" }))

-- ── Focus navigation ──────────────────────────────────────────────────────────
hl.bind("SUPER + left",  hl.dsp.focus({ direction = "left" }))
hl.bind("SUPER + right", hl.dsp.focus({ direction = "right" }))
hl.bind("SUPER + up",    hl.dsp.focus({ direction = "up" }))
hl.bind("SUPER + down",  hl.dsp.focus({ direction = "down" }))
hl.bind("SUPER + H",     hl.dsp.focus({ direction = "left" }))
hl.bind("SUPER + J",     hl.dsp.focus({ direction = "down" }))
hl.bind("SUPER + K",     hl.dsp.focus({ direction = "up" }))
hl.bind("SUPER + L",     hl.dsp.focus({ direction = "right" }))

-- ── Window movement ───────────────────────────────────────────────────────────
hl.bind("SUPER + SHIFT + left",  hl.dsp.window.swap({ direction = "left" }))
hl.bind("SUPER + SHIFT + right", hl.dsp.window.swap({ direction = "right" }))
hl.bind("SUPER + SHIFT + up",    hl.dsp.window.swap({ direction = "up" }))
hl.bind("SUPER + SHIFT + down",  hl.dsp.window.swap({ direction = "down" }))

-- ── Window resize ─────────────────────────────────────────────────────────────
hl.bind("SUPER + CTRL + left",  hl.dsp.exec_raw("resizeactive -100 0"), { repeating = true })
hl.bind("SUPER + CTRL + right", hl.dsp.exec_raw("resizeactive 100 0"),  { repeating = true })
hl.bind("SUPER + CTRL + up",    hl.dsp.exec_raw("resizeactive 0 -100"), { repeating = true })
hl.bind("SUPER + CTRL + down",  hl.dsp.exec_raw("resizeactive 0 100"),  { repeating = true })

-- ── Workspaces ────────────────────────────────────────────────────────────────
for i = 1, 9 do
    hl.bind("SUPER + " .. i,         hl.dsp.focus({ workspace = i }))
    hl.bind("SUPER + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end
hl.bind("SUPER + 0",         hl.dsp.focus({ workspace = 10 }))
hl.bind("SUPER + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))

-- Mouse workspace cycling
hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "e-1" }))
hl.bind("SUPER + mouse_up",   hl.dsp.focus({ workspace = "e+1" }))

-- Mouse window control
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ── Lock screen ───────────────────────────────────────────────────────────────
hl.bind("SUPER + SHIFT + L",      hl.dsp.exec_cmd("hyprlock"))

-- ── Screenshots ───────────────────────────────────────────────────────────────
-- Print         → region capture with 1s delay, save + copy
-- CTRL + Print  → region capture immediately, save + copy
-- SHIFT + Print → region capture with annotation (satty)
-- local ss_dir = os.getenv("HOME") .. "/Pictures/Screenshots"
-- hl.bind("Print", hl.dsp.exec_cmd(
--     "bash -c 'mkdir -p \"" .. ss_dir .. "\"; " ..
--     "FILE=\"" .. ss_dir .. "/screenshot_$(date +%Y-%m-%d_%H-%M-%S).png\"; " ..
--     "COORDS=$(slurp -f \"%x,%y %wx%h\"); sleep 1; " ..
--     "grim -g \"$COORDS\" \"$FILE\" && wl-copy < \"$FILE\"'"
-- ))
-- hl.bind("CTRL + Print", hl.dsp.exec_cmd(
--     "bash -c 'mkdir -p \"" .. ss_dir .. "\"; " ..
--     "FILE=\"" .. ss_dir .. "/screenshot_$(date +%Y-%m-%d_%H-%M-%S).png\"; " ..
--     "COORDS=$(slurp -f \"%x,%y %wx%h\"); " ..
--     "grim -g \"$COORDS\" \"$FILE\" && wl-copy < \"$FILE\"'"
-- ))
-- hl.bind("SHIFT + Print", hl.dsp.exec_cmd(
--     "bash -c 'mkdir -p \"" .. ss_dir .. "\"; " ..
--     "FILE=\"" .. ss_dir .. "/screenshot_$(date +%Y-%m-%d_%H-%M-%S).png\"; " ..
--     "COORDS=$(slurp -f \"%x,%y %wx%h\"); sleep 1; " ..
--     "grim -g \"$COORDS\" \"$FILE\" && satty -f \"$FILE\"'"
-- ))

-- ── Media controls (work on lock screen) ─────────────────────────────────────
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("pamixer -i 5"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("pamixer -d 5"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("pamixer -t"),   { locked = true })
hl.bind("XF86AudioPlay",        hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext",        hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev",        hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- ── Brightness controls (work on lock screen) ────────────────────────────────
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl set +5%"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })
