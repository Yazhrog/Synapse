  <h1 align=center>Synapse</h1>
  
  <h3 align="center">
  A dynamic, highly modular Wayland desktop shell built with Quickshell and QML, tailored for Hyprland.
  </h3>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-0.2.0-8D748C?style=for-the-badge&logoColor=D9E0EE&labelColor=252733" alt="Version 0.2.0" />
  <br>
  <img src="https://img.shields.io/badge/hyprland-v0.55+-5E81AC?style=for-the-badge&logoColor=D9E0EE&labelColor=252733" alt="Hyprland v0.55+" />
  <img src="https://img.shields.io/badge/quickshell-framework-A1C999?style=for-the-badge&logoColor=D9E0EE&labelColor=252733" alt="Quickshell Framework" />
  <br>
</p>

---

<h2 align="center">Features</h2>

- **Modular Setup** — Unintrusive setup
- **Material You Integration** — Dynamic colors via Matugen
- **Lua-Based Config** — Hyprland v0.55+ compatible
- **System Dashboard** — Monitor CPU, RAM, battery, temps, and more
- **Kanban/Tasks** — To Do, Ongoing and Competed lists with Prioiry and Deadlines
- **App Launcher** — Dropdown App Launcher
- **Keybinds** — Set your own keybinds for each popup
- **Theming Engine** — Live wallpaper-synced color updates
- **Network Manager** — WiFi, Bluetooth, VPN integration
- **Notifications** — DBus Notifcations via libnotify
- **Audio Control** — PipeWire volume & device management
- **Screen Recorder** — Built-in recording with wf-recorder
- **Clipboard Manager** — Cliphist integration for history management
- **Highly Customizable** — QML-based UI, easily extended

> **Note:** Synapse is currently in its `v0.2.0` release. While the core architecture and theming pipeline are feature-complete, you may encounter bugs. Please report them on Discord or via GitHub Issues!

---

<h2>
  Installation
</h2>

### One line installer

```bash
curl -fsSL https://raw.githubusercontent.com/Yazhrog/Synapse/refs/heads/main/boot.sh | bash
```

### Manual installation

```bash
git clone https://github.com/Yazhrog/Synapse.git
cd Synapse
./boot.sh
```

Run this way, **the clone you just made becomes your live config** — keep it
wherever you like it. The one-line installer instead clones to
`~/.local/src/Synapse`.

The installer automatically:

- ✓ Detects your Linux distribution
- ✓ Installs all required dependencies
- ✓ Backs up every config it is about to touch, to `~/.config.backup-<timestamp>-Synapse/`
- ✓ Symlinks its configs into `~/.config`, so the repo stays the single source
- ✓ Creates configuration directories and seeds your user data
- ✓ Sets zsh as your login shell

**After installation, restart Hyprland for changes to take effect.**

### Updating

Because `~/.config` symlinks into your checkout, a pull *is* the update:

```bash
git -C <your-checkout> pull      # or use the in-shell update popup
./install/link.sh                # only needed when an update adds a new file
```

Synapse also checks for updates 30s after login and offers to pull for you.
Toggle that in **Dashboard → Config → Misc**.

> Multi-monitor setups: put your layout in `~/.config/Synapse/monitors.lua`,
> not in `config/hypr/modules/monitors.lua` — the latter is a symlink into the
> repo, and editing it will conflict on your next pull.

---

<h2>
  Requirements
</h2>

> [!IMPORTANT]
> **Matugen is required** for dynamic color generation. Synapse will not function correctly without it.

### Core Dependencies

<details open>
<summary><b>Runtime & Rendering</b></summary>

- **Hyprland** v0.55+ – Wayland compositor
- **Quickshell** – QML shell framework
- **Qt6** – Qt6 libraries and QML engine
- **qt6ct** – Qt6 theme configuration

</details>

<details open>
<summary><b>System Tools</b></summary>

- **PipeWire** – Audio server (pipewire, pipewire-pulse, wireplumber)
- **NetworkManager** – Network management
- **BlueZ** – Bluetooth stack (bluez, bluez-utils)
- **Brightnessctl** – Backlight control
- **Mpris** – Media Retrival
- **Playerctl** – Player controls
- **UPower** – Battery and power info
- **libnotify** – Desktop notifications
- **Polkit** – Privilege escalation
- **wl-clipboard** – Wayland clipboard (wl-copy/wl-paste)

</details>

<details open>
<summary><b>Theming & Wallpaper</b></summary>

- **Matugen** – Material You color generation **(REQUIRED)**
- **awww** – Wallpaper daemon (Wayland)
- **ImageMagick** – Image manipulation

</details>

<details open>
<summary><b>Recording & Utilities</b></summary>

- **wf-recorder** – Screen recording (Wayland)
- **cava** – Audio visualizer
- **slurp** – Region/window selection
- **wtype** – Keyboard input emulation
- **cliphist** – Clipboard history manager

</details>

<details open>
<summary><b>Hardware Management</b></summary>

- **lm_sensors** – CPU temperature & fan monitoring
- **rfkill** – Airplane mode control
- **envycontrol** – GPU switching (NVIDIA/Intel)
- **auto-cpufreq** – CPU frequency scaling
- **nbfc-linux** – Laptop fan control

</details>

<details open>
<summary><b>Hyprland Integration</b></summary>

- **hyprlock** – Lock screen
- **hypridle** – Idle management daemon
- **sunsetr** – Blue light filter / night light
- **wayland-idle-inhibitor** – Caffeine mode (inhibits idle while active)
- **hyprshutdown** – Graceful shutdown
- **xdg-desktop-portal-hyprland** – Portal backend

</details>

<details open>
<summary><b>Fonts</b></summary>

- **ttf-jetbrains-mono-nerd** – Primary font (Nerd Font variant)
- **ttf-nerd-fonts-symbols-common** – Nerd Font icon glyphs used across the shell UI
- **ttf-cascadia-mono-nerd** – Ghostty terminal font

</details>

---

<h2>
  Roadmap
</h2>

### Current (v0.2.0)

- [x] Core shell framework
- [x] System monitoring dashboard
- [x] Keybind editor with live conflict detection
- [x] Network management (WiFi, Bluetooth, VPN)
- [x] Audio control panel
- [x] Screen recording integration
- [x] Clipboard manager
- [x] Material You color integration
- [x] Lua config generation
- [x] Professional installer (Arch/NixOS)
- [x] Auto-update mechanism
- [x] Volume/brightness on-screen display (OSD)
- [x] Low-battery warning & critical shutdown dialog
- [x] Redesigned notification toasts
- [x] Built-in screenshot tool (rishot)
- [x] GTK theming via nwg-look
- [x] Smarter update flow (package-diff aware, keybind-conflict re-checks)

### Upcoming (Post-v0.2.0)

- [ ] Scaling on Different Screen-Sizes
- [ ] Config Pages for Shell Customization
- [ ] Multi-Monitor Support
- [ ] Additional theme options
- [ ] App launcher enhancements (pinned/recent)
- [ ] Unified popup configuration layer
- [ ] Extended documentation
- [ ] Community themes
- [ ] CLI
- [ ] More Linux distribution support

---

<h2>
Known Issues
</h2>

- **Multi-Monitor Scaling:** Global scaling across mixed-resolution monitors (e.g., 4K paired with 1080p) is currently inconsistent. UI elements may appear misproportioned or poorly sized on non-1080p screens.

- **Top Bar Clipping:** Elements within the right notch may become visually clipped if the system tray is expanded and contains an excessive number of active items.

- **Shutdown Menu (Hyprshutdown) State:** Canceling a shutdown or logout action can sometimes leave the Hyprland session in an empty state with most applications unintentionally closed. It may also occasionally struggle to terminate all running apps smoothly.

---

<h2>
  Contributing
</h2>

Synapse is actively developed and welcomes contributions!

- Found a bug? → [Open an issue](https://github.com/Yazhrog/Synapse/issues)
- Have an idea? → [Start a discussion](https://github.com/Yazhrog/Synapse/discussions)
- Want to contribute? → Fork, branch, and submit a pull request

---

<h2>
  Special Thanks
</h2>

- **[Hyprland Community](https://github.com/hyprwm)** – For creating an exceptional Wayland compositor and fostering an amazing community
- **[Quickshell Contributors](https://github.com/quickshell/quickshell)** – For the powerful QML framework that powers this shell
- **[Matugen Team](https://github.com/InioX/matugen)** – For Material You color generation technology
- **[Wayland Project](https://wayland.freedesktop.org)** – For the modern display protocol foundation
- **[Celestial Shell](https://github.com/caelestia-dots/shell)** & **[AX-Shell](https://github.com/Axenide/ax-shell)** — For the inspiration
- **[NotCandy001](https://github.com/notcandy001)** — For the installer
- **All the Testers & Contributors** — For their time put into testing and suggesting fixes.

---

<h2>
  License
</h2>

This project is licensed under the MIT License – see the [LICENSE](LICENSE) file for details.
