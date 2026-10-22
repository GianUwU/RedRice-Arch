#!/usr/bin/env bash
# ==============================================================================
# RedRice-Arch - Automated Setup & Rice Installer for Arch Linux
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

echo -e "${RED}${BOLD}"
echo "  ____           _ ____  _             "
echo " |  _ \ ___   __| |  _ \(_) ___ ___    "
echo " | |_) / _ \ / _\` | |_) | |/ __/ _ \   "
echo " |  _ <  __/| (_| |  _ <| | (_|  __/   "
echo " |_| \_\___| \__,_|_| \_\_|\___\___|   "
echo "          Arch Linux Edition           "
echo -e "${NC}"

# Check for Arch Linux
if [ ! -f /etc/arch-release ]; then
    log_error "This script is designed for Arch Linux only."
    exit 1
fi

confirm() {
    local prompt="$1"
    read -r -p "$(echo -e "${YELLOW}?${NC} ${prompt} [y/N]: ")" response
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

# ------------------------------------------------------------------------------
# 1. Official Repository Packages
# ------------------------------------------------------------------------------
if confirm "Install official repository packages via pacman?"; then
    log_info "Updating pacman repositories..."
    sudo pacman -Sy --needed base-devel git
    log_info "Installing official packages..."
    sudo pacman -S --needed - < "$SCRIPT_DIR/packages/pkglist-repo.txt"
    log_success "Official packages installed."
fi

# ------------------------------------------------------------------------------
# 2. AUR Packages
# ------------------------------------------------------------------------------
if confirm "Install AUR packages?"; then
    if ! command -v yay >/dev/null 2>&1; then
        log_info "yay not found. Installing yay..."
        YAY_TMP="$(mktemp -d)"
        git clone https://aur.archlinux.org/yay.git "$YAY_TMP"
        (cd "$YAY_TMP" && makepkg -si --noconfirm)
        rm -rf "$YAY_TMP"
    fi
    log_info "Installing AUR packages..."
    yay -S --needed - < "$SCRIPT_DIR/packages/pkglist-aur.txt"
    log_success "AUR packages installed."
fi

# ------------------------------------------------------------------------------
# 3. Deploy User Configurations (~/.config)
# ------------------------------------------------------------------------------
if confirm "Deploy dotfiles to $TARGET_HOME/.config?"; then
    log_info "Backing up existing configs if present..."
    mkdir -p "$TARGET_HOME/.config"

    # Copy configurations
    cp -r "$SCRIPT_DIR/dot_config/"* "$TARGET_HOME/.config/"

    # Replace hardcoded /home/gian with current user's home directory
    log_info "Adjusting path variables to $TARGET_HOME..."
    find "$TARGET_HOME/.config" -type f \( -name "*.jsonc" -o -name "*.json" -o -name "*.conf" -o -name "*.py" -o -name "*.sh" -o -name "*.service" \) \
        -exec sed -i "s|/home/gian|$TARGET_HOME|g" {} +

    log_success "Configs deployed to $TARGET_HOME/.config."
fi

# ------------------------------------------------------------------------------
# 4. Deploy User Local Files (~/.local/bin, lib, share)
# ------------------------------------------------------------------------------
if confirm "Deploy ~/.local (custom scripts, Dolphin Crimson Glass library, color schemes)?"; then
    mkdir -p "$TARGET_HOME/.local/bin"
    mkdir -p "$TARGET_HOME/.local/lib"
    mkdir -p "$TARGET_HOME/.local/share/color-schemes"

    cp -r "$SCRIPT_DIR/dot_local/bin/"* "$TARGET_HOME/.local/bin/"
    cp -r "$SCRIPT_DIR/dot_local/lib/"* "$TARGET_HOME/.local/lib/"
    cp -r "$SCRIPT_DIR/dot_local/share/"* "$TARGET_HOME/.local/share/"

    # Replace hardcoded home paths
    find "$TARGET_HOME/.local/bin" -type f -exec sed -i "s|/home/gian|$TARGET_HOME|g" {} +

    # Ensure executable permissions
    chmod +x "$TARGET_HOME/.local/bin/"*
    chmod +x "$TARGET_HOME/.config/hypr/scripts/"* 2>/dev/null || true
    chmod +x "$TARGET_HOME/.config/waybar/scripts/"* 2>/dev/null || true
    chmod +x "$TARGET_HOME/.config/swaync/"*.py 2>/dev/null || true

    log_success "~/.local assets and scripts deployed."
fi

# ------------------------------------------------------------------------------
# 5. Deploy Shell Configuration
# ------------------------------------------------------------------------------
if confirm "Deploy .bashrc and custom command cheatsheets?"; then
    [ -f "$TARGET_HOME/.bashrc" ] && cp "$TARGET_HOME/.bashrc" "$TARGET_HOME/.bashrc.backup.$(date +%s)"
    cp "$SCRIPT_DIR/shell/.bashrc" "$TARGET_HOME/.bashrc"
    [ -f "$SCRIPT_DIR/shell/.bash_profile" ] && cp "$SCRIPT_DIR/shell/.bash_profile" "$TARGET_HOME/.bash_profile"

    if [ -d "$SCRIPT_DIR/shell/commands" ]; then
        mkdir -p "$TARGET_HOME/Commands"
        cp -r "$SCRIPT_DIR/shell/commands/"* "$TARGET_HOME/Commands/"
    fi

    # Adjust paths in bashrc
    sed -i "s|/home/gian|$TARGET_HOME|g" "$TARGET_HOME/.bashrc"
    log_success "Shell configuration deployed."
fi

# ------------------------------------------------------------------------------
# 6. Setup SDDM Theme & Login
# ------------------------------------------------------------------------------
if confirm "Configure SDDM and Astronaut theme?"; then
    log_info "Setting up SDDM configuration..."
    sudo mkdir -p /etc/sddm.conf.d

    if [ -f "$SCRIPT_DIR/system/sddm/sddm.conf" ]; then
        sudo cp "$SCRIPT_DIR/system/sddm/sddm.conf" /etc/sddm.conf
    fi
    if [ -f "$SCRIPT_DIR/system/sddm/virtualkbd.conf" ]; then
        sudo cp "$SCRIPT_DIR/system/sddm/virtualkbd.conf" /etc/sddm.conf.d/virtualkbd.conf
    fi

    # Check if sddm-astronaut-theme is installed
    SDDM_THEME_DIR="/usr/share/sddm/themes/sddm-astronaut-theme"
    if [ ! -d "$SDDM_THEME_DIR" ]; then
        log_info "Installing sddm-astronaut-theme from GitHub..."
        sudo git clone https://github.com/Keyitdev/sddm-astronaut-theme.git "$SDDM_THEME_DIR"
    fi

    # Copy customized theme settings and wallpaper
    if [ -d "$SDDM_THEME_DIR" ]; then
        sudo cp "$SCRIPT_DIR/system/sddm/purple_leaves.conf" "$SDDM_THEME_DIR/Themes/" 2>/dev/null || true
        sudo cp "$SCRIPT_DIR/dot_config/hypr/Wallpapers/wallpaper1.png" "$SDDM_THEME_DIR/Backgrounds/" 2>/dev/null || true
    fi

    sudo systemctl enable sddm.service
    log_success "SDDM configured."
fi

# ------------------------------------------------------------------------------
# 7. Setup Udev Rules (Disable mouse wakeup)
# ------------------------------------------------------------------------------
if confirm "Install udev rules to prevent mouse/touchpad from waking suspended system?"; then
    sudo mkdir -p /etc/udev/rules.d/
    sudo cp "$SCRIPT_DIR/system/udev/90-disable-mouse-wakeup.rules" /etc/udev/rules.d/
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    log_success "Udev rules installed."
fi

# ------------------------------------------------------------------------------
# 8. Enable User & System Services
# ------------------------------------------------------------------------------
if confirm "Enable core system and user services?"; then
    sudo systemctl enable --now NetworkManager.service 2>/dev/null || true
    sudo systemctl enable --now bluetooth.service 2>/dev/null || true

    # User systemd services
    systemctl --user daemon-reload
    systemctl --user enable --now swaync-proxy.service 2>/dev/null || true
    systemctl --user enable --now swaync.service 2>/dev/null || true

    log_success "Services enabled."
fi

# Fix ownership
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.config" "$TARGET_HOME/.local" "$TARGET_HOME/.bashrc" 2>/dev/null || true

echo -e "${GREEN}${BOLD}Setup completed successfully! Enjoy RedRice-Arch.${NC}"
