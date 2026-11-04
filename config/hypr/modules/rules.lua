-- Window and layer rules

-- Common floating dialogs (anchored classes)
hl.window_rule({
    name = "float-nm",
    match = { class = "^(nm-connection-editor)$" },
    float = true,
    center = true,
})

hl.window_rule({
    name = "float-blueman",
    match = { class = "^(blueman-manager)$" },
    float = true,
    center = true,
})

hl.window_rule({
    name = "float-preferences",
    match = { title = "^(Preferences)$" },
    float = true,
    center = true,
})

-- Web apps float centered
hl.window_rule({
    name = "float-webapps",
    match = { class = "^webapp-.*" },
    float = true,
    center = true,
    size = "1000 700",
})

-- Inhibit idle while any window is fullscreen
hl.window_rule({
    name = "idleinhibit-fullscreen",
    match = { fullscreen = true },
    idle_inhibit = "fullscreen",
})

-- Tag browsers
hl.window_rule({
    match = {
        class = "^([cC]hrom(e|ium)|[bB]rave-browser|Microsoft-edge|Vivaldi-stable|helium-browser)$",
    },
    tag = "+chromium-based-browser",
})

hl.window_rule({
    match = {
        class = "^([fF]irefox|zen.*|librewolf)$",
    },
    tag = "+firefox-based-browser",
})

-- Subtle opacity for Chromium-based browsers
hl.window_rule({
    match = {
        tag = ".*chromium-based-browser.*",
    },
    opacity = "1.0 override 0.97 override",
})

-- Let Zen Browser manage internal alpha/transparency directly via CSS
hl.window_rule({
    match = {
        class = "^(zen.*)$",
    },
    opacity = "1.0 override 1.0 override",
})

-- Disallow transparency and blur on media players and video apps
hl.window_rule({
    match = {
        class = "^(zoom|vlc|mpv|org.kde.kdenlive|com.obsproject.Studio|com.github.PintaProject.Pinta|imv|org.gnome.NautilusPreviewer)$",
    },
    opacity = "1.0 override 1.0 override",
    no_blur = true,
})

-- Blur behind the Synapse frame (Config → Appearance → Background blur).
-- Enabled from backgroundBlur in shell_prefs.json, so it survives a reload;
-- the shell flips it live with `hyprctl eval "SynapseFrameBlur:set_enabled(...)"`
-- (services/AppearanceService.qml). ignore_alpha keeps the transparent hole
-- and the anti-aliased edges unblurred.
local function synapse_frame_blur()
    local dir = os.getenv("SYNAPSE_CONFIG_DIR") or (os.getenv("HOME") .. "/.config/Synapse")
    local f = io.open(dir .. "/src/user_data/shell_prefs.json", "r")
    if not f then return false end
    local text = f:read("*a")
    f:close()
    return text:match('"backgroundBlur"%s*:%s*true') ~= nil
end

SynapseFrameBlur = hl.layer_rule({
    name         = "synapse-frame-blur",
    match        = { namespace = "^synapse-frame$" },
    blur         = true,
    ignore_alpha = 0.2,
    enabled      = synapse_frame_blur(),
})
