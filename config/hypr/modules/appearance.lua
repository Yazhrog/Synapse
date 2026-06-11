hl.config({
    general = {
        gaps_in          = 5,
        gaps_out         = 7,
        border_size      = 2,
        col = {
            active_border   = {colors = {"rgba(cba6f7ff)", "rgba(62a0eaff)"}, angle = 0},
            inactive_border = "rgba(9a9996ff)",
        },
        resize_on_border = true,
        allow_tearing    = true,
        layout           = "dwindle",
    },

    decoration = {
        rounding         = 2,
        active_opacity   = 0.9,
        inactive_opacity = 0.9,
        dim_inactive     = false,
        dim_strength     = 0.25,

        shadow = {
            enabled      = true,
            range        = 5,
            render_power = 3,
            color        = "rgba(5e5c64ff)",
        },

        blur = {
            enabled  = true,
            size     = 6,
            passes   = 2,
            vibrancy = 0.9,
        },
    },

    xwayland = {
        force_zero_scaling = true,
    },
})

