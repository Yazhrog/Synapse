-- Plugin configuration
-- Plugins are loaded by hyprpm (see autostart.lua: hyprpm reload -n).
--
-- Required plugins (install via hyprpm):
--   hyprpm add https://github.com/gfhdhytghd/hymission
--   hyprpm enable hymission

hl.on("config.reloaded", function()
    hl.config({
        plugin = {
            hymission = {},
        },
    })
end)
