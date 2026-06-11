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

-- Brain_Shell popup layer — enable blur
hl.layer_rule({
    name  = "quickshell-blur",
    match = { namespace = "quickshell" },
    blur  = true,
})
