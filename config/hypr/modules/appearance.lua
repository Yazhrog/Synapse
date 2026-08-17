local ok, colors = pcall(dofile, os.getenv("HOME") .. "/.config/hypr/modules/colors.lua")
if not ok then
    colors = {
        primary   = "cba6f7",
        secondary = "62a0ea",
        outline   = "9a9996",
        shadow    = "5e5c64",
    }
end

local function rgba(hex, a) return "rgba(" .. hex .. (a or "ff") .. ")" end

hl.config({
    general = {
        gaps_in          = 2,
        gaps_out         = 12,
        border_size      = 3,
        col = {
            active_border   = {colors = {rgba(colors.primary)}},
        },
        resize_on_border = true,
        allow_tearing    = true,
        layout           = "dwindle",
    },

    decoration = {
        rounding         = 12,
        active_opacity   = 0.9,
        inactive_opacity = 0.9,
        dim_inactive     = false,
        dim_strength     = 0.25,

        shadow = {
            enabled      = true,
            range        = 5,
            render_power = 3,
            color        = 0x33000000,
        },

        blur = {
            enabled     = true,
            size        = 3,
            passes      = 3,
            new_optimizations = true,
            ignore_opacity = true,
            xray        = true,
            vibrancy    = 0.9,
        },
    },

    xwayland = {
        force_zero_scaling = true,
    },
})
