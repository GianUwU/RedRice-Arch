# 🔴 RedRice-Arch

A sleek, cohesive **Crimson Glass** Arch Linux rice built on top of **Hyprland**, featuring custom Waybar capsule modes, live countdown notification proxies, translucent terminal effects, and bespoke C++ Qt skinning.

![Preview](dot_config/hypr/Wallpapers/wallpaper1.png)

---

## 🌟 Highlights & Features

| Component | Tool / Tech | Highlights |
| :--- | :--- | :--- |
| **Window Manager** | **Hyprland** | Fractional scaling (1.33x), custom `hypr-zstack` plugin, floating `special:cmd` scratchpad, wallpaper switcher. |
| **Status Bar** | **Waybar** | Modular configuration with **Capsule** and **Pill** workspace styling, dynamic workspace icons, network/bluetooth/audio menus. |
| **Notifications** | **SwayNC** | Custom countdown proxy (`swaync_proxy.py`), GResource UI overlay (`notification.ui`), and `libswaync_helper.so`. |
| **Terminal** | **Kitty** | Crimson beam cursor, animated cursor trail shader, 40% background transparency. |
| **App Launcher** | **Wofi** | Crimson glass style, matching border and highlight palette. |
| **File Manager** | **Dolphin** | **Crimson Glass Edition**: Custom C++ injected palette hook (`libdolphinglass.so`), stylesheet, and `CrimsonGlass.colors`. |
| **Login Manager** | **SDDM** | Customized `sddm-astronaut-theme` with matching wallpaper, blur, and virtual keyboard support. |
| **Power / Hardware** | **Udev / Systemd** | Custom udev rules to prevent accidental wakeups from mice/touchpads during system suspend. |

---

## 📁 Repository Structure

```
RedRice-Arch/
├── install.sh                     # Automated modular installer
├── packages/
│   ├── pkglist-repo.txt           # Explicit official Arch repository packages
│   ├── pkglist-aur.txt            # AUR packages (yay/paru)
│   ├── services-system.txt        # Enabled systemd system services
│   └── services-user.txt          # Enabled systemd user services
├── dot_config/                    # Configurations mapped to ~/.config/
│   ├── hypr/                      # Hyprland configs, hyprpaper, scripts, wallpapers
│   ├── waybar/                    # Waybar themes, menus, scripts
│   ├── swaync/                    # SwayNC configs, notification countdown proxy
│   ├── kitty/                     # Terminal configs and shaders
│   ├── wofi/                      # Launcher stylesheet and settings
│   ├── dolphin/                   # Dolphin glass stylesheet and C++ source
│   ├── nvim/                      # Neovim configuration
│   ├── eww/                       # EWW widgets
│   ├── quickshell/                # Quickshell components (hyprquickshot)
│   ├── systemd/user/              # User systemd service units
│   └── kdeglobals                 # CrimsonGlass KDE color scheme
├── dot_local/                     # Mapped to ~/.local/
│   ├── bin/                       # Dolphin wrapper, suspend-wakeup scripts
│   ├── lib/                       # libdolphinglass.so
│   └── share/color-schemes/       # CrimsonGlass.colors
├── system/                        # System configurations mapped to /etc/
│   ├── sddm/                      # SDDM configs and Astronaut theme settings
│   └── udev/                      # Mouse/touchpad wakeup suppression rules
└── shell/                         # User shell configuration
    ├── .bashrc                    # Bash config, aliases, and directory autos
    ├── .bash_profile
    └── commands/                  # Quick cheatsheets and references
```

---

## 🚀 Quick Start / Installation

### 1. Clone the Repository
```bash
git clone git@github.com:GianUwU/RedRice-Arch.git ~/RedRice-Arch
cd ~/RedRice-Arch
```

### 2. Run the Installer
```bash
chmod +x install.sh
./install.sh
```

The installer will interactively prompt before each step:
1. **Install official packages** from `packages/pkglist-repo.txt`.
2. **Install AUR packages** from `packages/pkglist-aur.txt` (installs `yay` if missing).
3. **Deploy dotfiles** to `~/.config/` (dynamically updates paths to your current user home).
4. **Deploy local assets & scripts** to `~/.local/` and set proper execution permissions.
5. **Deploy shell config** (`.bashrc` and `~/Commands/`).
6. **Configure SDDM** and download the Astronaut theme.
7. **Apply udev rules** for clean laptop/desktop sleep management.
8. **Enable services** (`NetworkManager`, `bluetooth`, `sddm`, `swaync-proxy.service`).

---

## ⌨️ Useful Keybindings & Shortcuts

- **Terminal (Kitty)**: `Super + Q`
- **Scratchpad CMD (Floating Terminal)**: `Super + Grave` (or defined in `hyprland.conf`)
- **Launcher (Wofi)**: `Super + Space` / `Super + D`
- **File Manager (Dolphin Crimson Glass)**: `Super + E`
- **Notification Panel (SwayNC)**: `Super + N`
- **Wallpaper Switcher**: Click the wallpaper button in Waybar or run:
  ```bash
  ~/.config/hypr/scripts/switch-wallpaper.py
  ```
- **Toggle Waybar Capsule/Full Mode**:
  ```bash
  ~/.config/waybar/scripts/toggle-capsule.sh
  ```

---

## 🎨 Manual Compilation (Optional)

If you ever need to recompile the Dolphin Crimson Glass library manually:
```bash
cd ~/.config/dolphin
g++ -shared -fPIC -O3 dolphinglass.cpp -o ~/.local/lib/libdolphinglass.so $(pkg-config --cflags --libs Qt6Widgets)
```
