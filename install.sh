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
# Choose Deployment Method (Symlink vs Copy)
# ------------------------------------------------------------------------------
USE_SYMLINKS=true
read -r -p "$(echo -e "${YELLOW}?${NC} Deploy configs as live symlinks (auto-adjust on change) or copy? [S(ymlink)/c(opy)]: ")" deploy_mode
case "$deploy_mode" in
    [cC][oO][pP][yY]|[cC]) USE_SYMLINKS=false ;;
    *) USE_SYMLINKS=true ;;
esac

# ------------------------------------------------------------------------------
# 3. Deploy User Configurations (~/.config)
# ------------------------------------------------------------------------------
if confirm "Deploy dotfiles to $TARGET_HOME/.config?"; then
    mkdir -p "$TARGET_HOME/.config/quickshell" "$TARGET_HOME/.config/nvim" "$TARGET_HOME/.config/systemd/user" "$TARGET_HOME/.config/vesktop"

    # Replace hardcoded /home/gian with current user's home directory if different
    if [ "$TARGET_HOME" != "/home/gian" ]; then
        log_info "Adjusting path variables in repo to match $TARGET_HOME..."
        find "$SCRIPT_DIR/dot_config" "$SCRIPT_DIR/dot_local" -type f \( -name "*.jsonc" -o -name "*.json" -o -name "*.conf" -o -name "*.py" -o -name "*.sh" -o -name "*.service" \) \
            -exec sed -i "s|/home/gian|$TARGET_HOME|g" {} +
    fi

    for dir in hypr waybar swaync kitty wofi dolphin eww; do
        target="$TARGET_HOME/.config/$dir"
        [ -e "$target" ] && [ ! -L "$target" ] && mv "$target" "${target}.backup.$(date +%s)"
        [ -L "$target" ] && rm "$target"
        if [ "$USE_SYMLINKS" = true ]; then
            ln -s "$SCRIPT_DIR/dot_config/$dir" "$target"
        else
            cp -r "$SCRIPT_DIR/dot_config/$dir" "$target"
        fi
    done

    # Single config files
    for item in kdeglobals; do
        target="$TARGET_HOME/.config/$item"
        [ -e "$target" ] && [ ! -L "$target" ] && mv "$target" "${target}.backup.$(date +%s)"
        [ -L "$target" ] && rm "$target"
        if [ "$USE_SYMLINKS" = true ]; then
            ln -s "$SCRIPT_DIR/dot_config/$item" "$target"
        else
            cp "$SCRIPT_DIR/dot_config/$item" "$target"
        fi
    done

    # nvim/init.vim
    [ -e "$TARGET_HOME/.config/nvim/init.vim" ] && rm -f "$TARGET_HOME/.config/nvim/init.vim"
    if [ "$USE_SYMLINKS" = true ]; then
        ln -s "$SCRIPT_DIR/dot_config/nvim/init.vim" "$TARGET_HOME/.config/nvim/init.vim"
    else
        cp "$SCRIPT_DIR/dot_config/nvim/init.vim" "$TARGET_HOME/.config/nvim/init.vim"
    fi

    # quickshell/hyprquickshot
    [ -e "$TARGET_HOME/.config/quickshell/hyprquickshot" ] && rm -rf "$TARGET_HOME/.config/quickshell/hyprquickshot"
    if [ "$USE_SYMLINKS" = true ]; then
        ln -s "$SCRIPT_DIR/dot_config/quickshell/hyprquickshot" "$TARGET_HOME/.config/quickshell/hyprquickshot"
    else
        cp -r "$SCRIPT_DIR/dot_config/quickshell/hyprquickshot" "$TARGET_HOME/.config/quickshell/hyprquickshot"
    fi

    # vesktop
    mkdir -p "$TARGET_HOME/.config/vesktop"
    if [ "$USE_SYMLINKS" = true ]; then
        [ -e "$TARGET_HOME/.config/vesktop/settings.json" ] && [ ! -L "$TARGET_HOME/.config/vesktop/settings.json" ] && mv "$TARGET_HOME/.config/vesktop/settings.json" "$TARGET_HOME/.config/vesktop/settings.json.backup.$(date +%s)"
        [ -L "$TARGET_HOME/.config/vesktop/settings.json" ] && rm -f "$TARGET_HOME/.config/vesktop/settings.json"
        ln -s "$SCRIPT_DIR/dot_config/vesktop/settings.json" "$TARGET_HOME/.config/vesktop/settings.json"

        for vdir in settings themes; do
            target="$TARGET_HOME/.config/vesktop/$vdir"
            [ -e "$target" ] && [ ! -L "$target" ] && mv "$target" "${target}.backup.$(date +%s)"
            [ -L "$target" ] && rm -rf "$target"
            ln -s "$SCRIPT_DIR/dot_config/vesktop/$vdir" "$target"
        done
    else
        cp "$SCRIPT_DIR/dot_config/vesktop/settings.json" "$TARGET_HOME/.config/vesktop/settings.json"
        cp -r "$SCRIPT_DIR/dot_config/vesktop/settings" "$TARGET_HOME/.config/vesktop/"
        cp -r "$SCRIPT_DIR/dot_config/vesktop/themes" "$TARGET_HOME/.config/vesktop/"
    fi

    # systemd user
    cp -r "$SCRIPT_DIR/dot_config/systemd/user/"* "$TARGET_HOME/.config/systemd/user/" 2>/dev/null || true

    log_success "Configs deployed to $TARGET_HOME/.config."
fi

# ------------------------------------------------------------------------------
# 4. Deploy User Local Files (~/.local/bin, lib, share)
# ------------------------------------------------------------------------------
if confirm "Deploy ~/.local (custom scripts, Dolphin Crimson Glass library, color schemes)?"; then
    mkdir -p "$TARGET_HOME/.local/bin"
    mkdir -p "$TARGET_HOME/.local/lib"
    mkdir -p "$TARGET_HOME/.local/share/color-schemes"

    for bin in dolphin setup-suspend-wakeup.sh; do
        target="$TARGET_HOME/.local/bin/$bin"
        [ -e "$target" ] && rm -f "$target"
        if [ "$USE_SYMLINKS" = true ]; then
            ln -s "$SCRIPT_DIR/dot_local/bin/$bin" "$target"
        else
            cp "$SCRIPT_DIR/dot_local/bin/$bin" "$target"
        fi
    done

    target_lib="$TARGET_HOME/.local/lib/libdolphinglass.so"
    [ -e "$target_lib" ] && rm -f "$target_lib"
    if [ "$USE_SYMLINKS" = true ]; then
        ln -s "$SCRIPT_DIR/dot_local/lib/libdolphinglass.so" "$target_lib"
    else
        cp "$SCRIPT_DIR/dot_local/lib/libdolphinglass.so" "$target_lib"
    fi

    target_cs="$TARGET_HOME/.local/share/color-schemes/CrimsonGlass.colors"
    [ -e "$target_cs" ] && rm -f "$target_cs"
    if [ "$USE_SYMLINKS" = true ]; then
        ln -s "$SCRIPT_DIR/dot_local/share/color-schemes/CrimsonGlass.colors" "$target_cs"
    else
        cp "$SCRIPT_DIR/dot_local/share/color-schemes/CrimsonGlass.colors" "$target_cs"
    fi

    # Ensure executable permissions
    chmod +x "$SCRIPT_DIR/dot_local/bin/"* 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/dot_config/hypr/scripts/"* 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/dot_config/waybar/scripts/"* 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/dot_config/swaync/"*.py 2>/dev/null || true

    log_success "~/.local assets and scripts deployed."
fi

# ------------------------------------------------------------------------------
# 5. Deploy Shell Configuration
# ------------------------------------------------------------------------------
if confirm "Deploy .bashrc and custom command cheatsheets?"; then
    [ -f "$TARGET_HOME/.bashrc" ] && [ ! -L "$TARGET_HOME/.bashrc" ] && cp "$TARGET_HOME/.bashrc" "$TARGET_HOME/.bashrc.backup.$(date +%s)"
    [ -e "$TARGET_HOME/.bashrc" ] && rm -f "$TARGET_HOME/.bashrc"

    if [ "$USE_SYMLINKS" = true ]; then
        ln -s "$SCRIPT_DIR/shell/.bashrc" "$TARGET_HOME/.bashrc"
        [ -e "$TARGET_HOME/.bash_profile" ] && rm -f "$TARGET_HOME/.bash_profile"
        ln -s "$SCRIPT_DIR/shell/.bash_profile" "$TARGET_HOME/.bash_profile"
        [ -e "$TARGET_HOME/Commands" ] && rm -rf "$TARGET_HOME/Commands"
        ln -s "$SCRIPT_DIR/shell/commands" "$TARGET_HOME/Commands"
    else
        cp "$SCRIPT_DIR/shell/.bashrc" "$TARGET_HOME/.bashrc"
        cp "$SCRIPT_DIR/shell/.bash_profile" "$TARGET_HOME/.bash_profile"
        mkdir -p "$TARGET_HOME/Commands"
        cp -r "$SCRIPT_DIR/shell/commands/"* "$TARGET_HOME/Commands/"
    fi

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

    SDDM_THEME_DIR="/usr/share/sddm/themes/sddm-astronaut-theme"
    if [ ! -d "$SDDM_THEME_DIR" ]; then
        log_info "Installing sddm-astronaut-theme from GitHub..."
        sudo git clone https://github.com/Keyitdev/sddm-astronaut-theme.git "$SDDM_THEME_DIR"
    fi

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

# ------------------------------------------------------------------------------
# 9. GRUB Bootloader Configuration  (optional — files not included in repo)
# ------------------------------------------------------------------------------
# system/grub, system/grub.d/40_custom are gitignored because they contain
# machine-specific UUIDs and hardware ACPI quirks.
# To use: copy your own /etc/default/grub into system/grub before running.
# The step will still offer to run grub-mkconfig even without the template.
if confirm "Apply GRUB configuration and regenerate grub.cfg?"; then
    if [ -f "$SCRIPT_DIR/system/grub" ]; then
        sudo cp "$SCRIPT_DIR/system/grub" /etc/default/grub
        log_success "Installed /etc/default/grub from repo template."
    else
        log_warn "system/grub not found — skipping /etc/default/grub copy."
        log_warn "Edit /etc/default/grub manually if needed, then re-run grub-mkconfig."
    fi

    if [ -f "$SCRIPT_DIR/system/grub.d/40_custom" ]; then
        sudo cp "$SCRIPT_DIR/system/grub.d/40_custom" /etc/grub.d/40_custom
        sudo chmod +x /etc/grub.d/40_custom
        log_success "Installed custom GRUB entries (40_custom)."
    else
        log_warn "system/grub.d/40_custom not found — skipping custom entries."
    fi

    if command -v grub-mkconfig >/dev/null 2>&1; then
        log_info "Regenerating GRUB config..."
        sudo grub-mkconfig -o /boot/grub/grub.cfg
        log_success "GRUB config updated."
    else
        log_warn "grub-mkconfig not found — is grub installed?"
    fi
fi

# ------------------------------------------------------------------------------
# 10. mkinitcpio — Initramfs Configuration  (optional — files not included in repo)
# ------------------------------------------------------------------------------
# system/mkinitcpio.conf and system/linux.preset are gitignored (machine-specific).
# To use: copy your /etc/mkinitcpio.conf into system/mkinitcpio.conf before running.
# If files are absent, the step will only rebuild the initramfs with existing config.
if confirm "Apply mkinitcpio config and regenerate initramfs?"; then
    if [ -f "$SCRIPT_DIR/system/mkinitcpio.conf" ]; then
        sudo cp "$SCRIPT_DIR/system/mkinitcpio.conf" /etc/mkinitcpio.conf
        log_success "Installed /etc/mkinitcpio.conf from repo template."
    else
        log_warn "system/mkinitcpio.conf not found — using existing /etc/mkinitcpio.conf."
    fi

    if [ -f "$SCRIPT_DIR/system/linux.preset" ]; then
        sudo cp "$SCRIPT_DIR/system/linux.preset" /etc/mkinitcpio.d/linux.preset
        log_success "Installed /etc/mkinitcpio.d/linux.preset from repo template."
    else
        log_warn "system/linux.preset not found — using existing preset."
    fi

    log_info "Regenerating initramfs (mkinitcpio -P)..."
    sudo mkinitcpio -P
    log_success "Initramfs rebuilt."
fi

# ------------------------------------------------------------------------------
# 11. Secure Boot — sbctl Setup
# ------------------------------------------------------------------------------
if confirm "Set up Secure Boot signing with sbctl?"; then
    if ! command -v sbctl >/dev/null 2>&1; then
        log_warn "sbctl not found — install it first (included in pkglist-repo.txt)."
    else
        SBCTL_STATUS="$(sbctl status 2>/dev/null)"
        log_info "Current sbctl status:"
        echo "$SBCTL_STATUS"

        if echo "$SBCTL_STATUS" | grep -q "Setup Mode.*Enabled"; then
            log_info "UEFI is in Setup Mode. Creating and enrolling Secure Boot keys..."
            sudo sbctl create-keys
            sudo sbctl enrol-keys -m
            log_success "Secure Boot keys created and enrolled (Microsoft keys retained)."
        else
            log_warn "UEFI is NOT in Setup Mode."
            log_warn "To enrol new keys: enter firmware settings → clear Secure Boot keys → reboot → re-run this step."
        fi

        log_info "Registering EFI binaries for automatic signing..."
        # Register all standard EFI targets
        for efi_path in \
            /boot/EFI/GRUB/grubx64.efi \
            /boot/EFI/BOOT/BOOTX64.EFI \
            /boot/vmlinuz-linux \
            /usr/lib/systemd/boot/efi/systemd-bootx64.efi; do
            if [ -f "$efi_path" ]; then
                sudo sbctl sign -s "$efi_path" 2>/dev/null && \
                    log_success "Registered + signed: $efi_path" || \
                    log_warn "Could not sign: $efi_path"
            fi
        done

        log_info "Running sbctl sign-all -g (signs all registered files)..."
        sudo sbctl sign-all -g
        log_info "Verifying signed files..."
        sbctl verify || true

        log_success "Secure Boot setup complete."
        log_warn "Remember to ENABLE Secure Boot in your UEFI firmware settings to activate it."
    fi
fi

# Fix ownership (run last, after all files are deployed)
chown -hR "$TARGET_USER:$TARGET_USER" \
    "$TARGET_HOME/.config" \
    "$TARGET_HOME/.local" \
    "$TARGET_HOME/.bashrc" \
    "$TARGET_HOME/.bash_profile" \
    "$TARGET_HOME/Commands" 2>/dev/null || true

echo -e "${GREEN}${BOLD}"
echo "  ____           _ ____  _             "
echo " |  _ \ ___   __| |  _ \(_) ___ ___    "
echo " | |_) / _ \ / _\` | |_) | |/ __/ _ \   "
echo " |  _ <  __/| (_| |  _ <| | (_|  __/   "
echo " |_| \_\___| \__,_|_| \_\_|\___\___|   "
echo "   Setup completed! Enjoy your rice.   "
echo -e "${NC}"
