-- Environment variables for Wayland, Qt, GTK, and toolkit compatibility

hl.env("XCURSOR_SIZE",                        "24")
hl.env("HYPRCURSOR_SIZE",                     "24")
hl.env("XCURSOR_THEME",                       "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_THEME",                    "Bibata-Modern-Ice")
hl.env("QT_QPA_PLATFORM",                     "wayland")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("GDK_BACKEND",                         "wayland,x11")
hl.env("SDL_VIDEODRIVER",                     "wayland")
hl.env("CLUTTER_BACKEND",                     "wayland")
hl.env("XDG_CURRENT_DESKTOP",                 "Hyprland")
hl.env("XDG_SESSION_TYPE",                    "wayland")
hl.env("MOZ_ENABLE_WAYLAND",                  "1")
hl.env("QT_QPA_PLATFORMTHEME",                "qt6ct")

-- NVIDIA: uncomment if you have an NVIDIA GPU
-- hl.env("LIBVA_DRIVER_NAME",    "nvidia")
-- hl.env("XDG_SESSION_TYPE",     "wayland")
-- hl.env("GBM_BACKEND",          "nvidia-drm")
-- hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
-- hl.env("NVD_BACKEND",          "direct")
