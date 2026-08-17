-- Monitor configuration
--
-- This file is a symlink into the Synapse repo — editing it here puts your
-- personal display layout in the repo's history and makes `git pull` conflict.
-- Put your monitor setup in this file instead:
--
--     ~/.config/Synapse/monitors.lua
--
-- It is loaded last, so anything you declare there wins over the default
-- below. The installer seeds it with commented examples to start from.
--
-- Format: hl.monitor({ output = "NAME", mode = "WxH@Hz", position = "XxY", scale = 1 })
-- Run `hyprctl monitors` to see the names of your connected displays.

-- Default: every connected display at its preferred mode, laid out
-- left-to-right automatically. Correct for a single monitor and for first boot.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

-- Your overrides (see the note above).
pcall(dofile, os.getenv("HOME") .. "/.config/Synapse/monitors.lua")
