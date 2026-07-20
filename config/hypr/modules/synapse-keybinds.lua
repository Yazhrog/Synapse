-- Synapse dynamic keybinds
--
-- ~/.config/Synapse/SynapseKeybinds.lua is generated and rewritten by
-- Quickshell (KeybindService.qml) from keybinds.json + the app's built-in
-- defaults. It does not exist until Quickshell has started at least once,
-- so this dofile is wrapped in pcall — a fresh install with Hyprland
-- started before Quickshell just has no Synapse keybinds bound yet.
pcall(dofile, os.getenv("HOME") .. "/.config/Synapse/SynapseKeybinds.lua")
