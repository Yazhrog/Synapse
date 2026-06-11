-- Plugin configuration
-- Plugins are loaded by hyprpm (see autostart.lua: hyprpm reload -n).
-- Config is applied on config.reloaded so plugins are already loaded when this runs.
--
-- Required plugins (install via hyprpm):
--   hyprpm add https://github.com/hyprwm/hyprland-plugins  (hyprexpo, borders-plus-plus, hyprbars)
--   hyprpm add https://github.com/Vortex-Basis-LLC/hyprfocus
--   hyprpm enable hyprexpo
--   hyprpm enable borders-plus-plus
--   hyprpm enable hyprbars
--   hyprpm enable hyprfocus

hl.on("config.reloaded", function()
    hl.config({
        plugin = {
            hyprexpo = {
                columns                   = 3,
                gap_size                  = 5,
                gap_size_outer            = 0,
                bg_col                    = "rgb(111111)",
                workspace_method          = "center current",
                skip_empty                = false,
                max_workspace             = 0,
                show_workspace_numbers    = false,
                workspace_number_color    = "rgb(ffffff)",
                window_icon_enable        = false,
                window_icon_position      = "bottom-right",
                window_icon_size          = 32,
                label_enable              = false,
                label_text_mode           = "id",
                label_token_map           = "",
                selection_label_enable    = false,
                selection_label_token_map = "a,s,d,f,g,q,w,e,r,t,z,x,c,v,b",
                gesture_distance          = 300,
                cancel_key                = "escape",
            },

            ["borders-plus-plus"] = {
                add_borders      = 2,
                natural_rounding = true,
                ["col.border_1"] = "rgba(cba6f7ff)",
                ["col.border_2"] = "rgba(313244ff)",
                border_size_1    = 2,
                border_size_2    = 3,
            },

            hyprfocus = {
                mode         = "slide",
                slide_height = 8,
                fade_opacity = 0.85,
            },

            hyprbars = {
                bar_height                 = 25,
                bar_color                  = "rgba(1e1e2eff)",
                ["col.text"]               = "rgba(ffffffff)",
                inactive_button_color      = "rgba(ffffff33)",
                bar_text_size              = 16,
                bar_text_font              = "JetBrainsMono Nerd Font",
                bar_text_align             = "center",
                bar_buttons_alignment      = "right",
                bar_blur                   = true,
                bar_title_enabled          = true,
                bar_part_of_window         = true,
                bar_precedence_over_border = true,
                bar_padding                = 7,
                bar_button_padding         = 10,
                icon_on_hover              = false,
            },
        },
    })

    if hl.plugin and hl.plugin.hyprbars then
        -- Close button (red)
        hl.plugin.hyprbars.add_button({
            bg_color = "rgba(f38ba8ff)",
            fg_color = "rgba(ffffffff)",
            size     = 18,
            icon     = "",
            action   = "hyprctl dispatch killactive",
        })
        -- Fullscreen button (yellow)
        hl.plugin.hyprbars.add_button({
            bg_color = "rgba(f9e2afff)",
            fg_color = "rgba(ffffffff)",
            size     = 18,
            icon     = "",
            action   = "hyprctl dispatch fullscreen 1",
        })
    end
end)
