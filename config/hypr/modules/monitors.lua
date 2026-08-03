-- Monitor configuration
-- Run `hyprctl monitors` to get the names of your connected displays,
-- then update the output names and modes below.
--
-- Format: hl.monitor({ output = "NAME", mode = "WxH@Hz", position = "XxY", scale = 1 })
-- Position is pixel offset from top-left. Set scale = 1 for 1:1, 2 for HiDPI.
--
-- Examples:
--   hl.monitor({ output = "DP-1",     mode = "2560x1440@144.0", position = "0x0",    scale = 1 })
--   hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60.0",  position = "2560x0", scale = 1 })
--   hl.monitor({ output = "eDP-1",    mode = "1920x1080@60.0",  position = "0x0",    scale = 1 })

-- TODO: Replace these with your actual monitor names and resolutions
hl.monitor({ output = "", mode = "1920x1080@60.0", position = "0x0",    scale = 1 })
