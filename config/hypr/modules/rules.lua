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
