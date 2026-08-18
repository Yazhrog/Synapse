-- Window and layer rules

-- Common floating dialogs
hl.window_rule({
    name   = "float-nm",
    match  = { class = "nm-connection-editor" },
    float  = true,
    center = true,
})

hl.window_rule({
    name   = "float-blueman",
    match  = { class = "blueman-manager" },
    float  = true,
    center = true,
})

hl.window_rule({
    name   = "float-preferences",
    match  = { title = "Preferences" },
    float  = true,
    center = true,
})

-- Web apps float centered
hl.window_rule({
    name   = "float-webapps",
    match  = { class = "webapp-.*" },
    float  = true,
    center = true,
    size   = "1000 700",
})

-- Inhibit idle while any window is fullscreen (e.g. video playback)
hl.window_rule({
    name         = "idleinhibit-fullscreen",
    match        = { class = ".*" },
    idle_inhibit = "fullscreen",
})

-- Browser types
hl.window_rule({
    match = {
        class = "([cC]hrom(e|ium)|[bB]rave-browser|Microsoft-edge|Vivaldi-stable|helium-browser)",
    },
    tag = "+chromium-based-browser",
})

hl.window_rule({
    match = {
        class = "([fF]irefox|zen|zen-browser|zen-bin|librewolf)",
    },
    tag = "+firefox-based-browser",
})

-- Force chromium-based browsers into a tile to deal with --app bug
hl.window_rule({
    match = {
        tag = "chromium-based-browser",
    },
    float = false,
    opacity = "1 0.97",
})

-- Only a subtle opacity change, but not for video sites
hl.window_rule({
    match = {
        tag = "firefox-based-browser",
    },
    opacity = "1 0.97",
})

-- Some video sites should never have opacity applied to them
hl.window_rule({
    match = {
        initial_title = "((?i)(?:[a-z0-9-]+\\.)*youtube\\.com_/|app\\.zoom\\.us_/wc/home)",
    },
    opacity = "1.0 1.0",
})

-- No transparency on media windows
hl.window_rule({
    match = {
        class = "^(zoom|vlc|mpv|org.kde.kdenlive|com.obsproject.Studio|com.github.PintaProject.Pinta|imv|org.gnome.NautilusPreviewer)$",
    },
    opacity = "1 1",
})
