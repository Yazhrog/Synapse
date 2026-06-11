#!/bin/bash
# Apply GTK theme on startup
# Update these values to match your preferred GTK theme, icon set, and cursor.
gsettings set org.gnome.desktop.interface gtk-theme    'catppuccin-mocha-blue-standard+default'
gsettings set org.gnome.desktop.interface icon-theme   'dreams'
gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Classic'
gsettings set org.gnome.desktop.interface font-name    'JetBrainsMono Nerd Font 12'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
