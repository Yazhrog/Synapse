hl.config({
    input = {
        kb_layout          = "gb",
        kb_variant         = "",
        kb_options         = "",
        numlock_by_default = true,
        repeat_rate        = 25,
        repeat_delay       = 600,
        follow_mouse       = 1,
        sensitivity        = 0.0,
        accel_profile      = "adaptive",
        scroll_factor      = 1.0,
        natural_scroll     = false,
        focus_on_close     = 0,
        mouse_refocus      = true,

        touchpad = {
            natural_scroll          = false,
            clickfinger_behavior    = false,
            tap_and_drag            = true,
            disable_while_typing    = true,
            drag_lock               = false,
            scroll_factor           = 1.0,
            middle_button_emulation = false,
        },
    },

    dwindle = {
        preserve_split = true,
        force_split    = 0,
        smart_split    = false,
        smart_resizing = true,
    },

    master = {
        new_status  = "master",
        mfact       = 0.55,
        orientation = "left",
        new_on_top  = false,
    },

    scrolling = {
        fullscreen_on_one_column = true,
        column_width = 0.7,
        direction = "right",
        focus_fit_method = 0,
    },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
        animate_manual_resizes  = false,
        mouse_move_enables_dpms = true,
        key_press_enables_dpms  = true,
    },
})
