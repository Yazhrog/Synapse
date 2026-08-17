-- Plugin configuration
-- Plugins are loaded by hyprpm (see autostart.lua: hyprpm reload -n).
--
-- Required plugins (install via hyprpm):
--   hyprpm add https://github.com/yayuuu/hyprland-scroll-overview.git
--   hyprpm enable scrolloverview

hl.on("config.reloaded", function()
    hl.config({
        plugin = {
            scrolloverview = {},
        },
    })
end)
