-- Autostart — runs once when Hyprland starts

hl.on("hyprland.start", function()
    -- Wayland environment and portals
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("systemctl --user start xdg-desktop-portal xdg-desktop-portal-hyprland")

    -- Polkit authentication agent (hyprpolkitagent, ships with Hyprland ecosystem)
    hl.exec_cmd("systemctl --user start hyprpolkitagent")

    -- Hyprland plugins (must run after portals)
    hl.exec_cmd("hyprpm reload -n")
    hl.exec_cmd("hyprctl plugin load " .. os.getenv("HOME") .. "/.config/hypr/plugin/hyprselect/hyprselect.so")

    -- GTK theme
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/gtk.sh")

    -- Synapse visual layer
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("hypridle -c " .. os.getenv("HOME") .. "/.local/src/Synapse/config/quickshell/src/config/hypridle.conf")
    hl.exec_cmd("quickshell -c " .. os.getenv("HOME") .. "/.local/src/Synapse/config/quickshell")

    -- Clipboard history (text + images)
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)
