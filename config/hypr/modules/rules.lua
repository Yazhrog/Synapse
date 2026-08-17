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

hl.window_rule({
    name   = "float-flameshot",
    match  = { class = "flameshot" },
    float  = true,
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
