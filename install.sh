#!/bin/sh

set -eu

DRY_RUN=0
NO_INSTALL=0
FORCE=0

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CONFIG_HOME=${XDG_CONFIG_HOME:-"$HOME/.config"}
BACKUP_ROOT=${I3_RICE_BACKUP_ROOT:-"$HOME/.config-backup"}
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR=$BACKUP_ROOT/i3-rice-$TIMESTAMP
BACKUP_CREATED=0

APT_PACKAGES="i3-wm i3blocks rofi dunst picom feh xss-lock i3lock playerctl brightnessctl pavucontrol upower network-manager-gnome gsimplecal fonts-dejavu fonts-font-awesome fonts-noto-color-emoji arc-theme papirus-icon-theme"
DNF_PACKAGES="i3 i3blocks rofi dunst picom feh xss-lock i3lock playerctl brightnessctl pavucontrol upower network-manager-applet yad dejavu-sans-fonts fontawesome-fonts google-noto-emoji-color-fonts arc-theme papirus-icon-theme"
PACMAN_PACKAGES="i3-wm i3blocks rofi dunst picom feh xss-lock i3lock playerctl brightnessctl pavucontrol upower network-manager-applet gsimplecal ttf-dejavu ttf-font-awesome noto-fonts-emoji arc-gtk-theme papirus-icon-theme"

usage() {
    cat <<'EOF'
Usage: ./install.sh [options]

Options:
  --dry-run      Print package install and copy actions without changing files.
  --no-install   Skip dependency installation and only copy configs.
  --force        Overwrite existing configs without prompts; backups are still made.
  -h, --help     Show this help.
EOF
}

say() {
    printf '%s\n' "$*"
}

die() {
    printf 'install.sh: %s\n' "$*" >&2
    exit 1
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            ;;
        --no-install)
            NO_INSTALL=1
            ;;
        --force)
            FORCE=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "unknown option: $1"
            ;;
    esac
    shift
done

need_sudo() {
    if [ "$(id -u)" -eq 0 ]; then
        printf ''
        return 0
    fi

    if command -v sudo >/dev/null 2>&1; then
        printf 'sudo'
    elif [ "$DRY_RUN" -eq 1 ]; then
        printf 'sudo'
    else
        die "sudo is required to install packages as a non-root user"
    fi
}

detect_package_manager() {
    if command -v apt-get >/dev/null 2>&1; then
        printf 'apt'
    elif command -v dnf >/dev/null 2>&1; then
        printf 'dnf'
    elif command -v pacman >/dev/null 2>&1; then
        printf 'pacman'
    else
        return 1
    fi
}

install_dependencies() {
    manager=$(detect_package_manager) || die "unsupported distro: expected apt, dnf, or pacman"
    sudo_cmd=$(need_sudo)

    say "Package manager: $manager"

    case "$manager" in
        apt)
            if [ "$DRY_RUN" -eq 1 ]; then
                say "Would run: $sudo_cmd apt-get update"
                say "Would run: $sudo_cmd apt-get install -y $APT_PACKAGES"
            else
                # shellcheck disable=SC2086
                $sudo_cmd apt-get update
                # shellcheck disable=SC2086
                $sudo_cmd apt-get install -y $APT_PACKAGES
            fi
            ;;
        dnf)
            if [ "$DRY_RUN" -eq 1 ]; then
                say "Would run: $sudo_cmd dnf install -y $DNF_PACKAGES"
            else
                # shellcheck disable=SC2086
                $sudo_cmd dnf install -y $DNF_PACKAGES
            fi
            ;;
        pacman)
            if [ "$DRY_RUN" -eq 1 ]; then
                say "Would run: $sudo_cmd pacman -S --needed --noconfirm $PACMAN_PACKAGES"
            else
                # shellcheck disable=SC2086
                $sudo_cmd pacman -S --needed --noconfirm $PACMAN_PACKAGES
            fi
            ;;
    esac
}

confirm_replace() {
    target=$1

    if [ "$FORCE" -eq 1 ]; then
        return 0
    fi

    printf 'Replace existing %s? A backup will be made. [y/N] ' "$target"
    read answer || answer=

    case "$answer" in
        y|Y|yes|YES|Yes)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

backup_target() {
    target=$1
    label=$2
    backup_target_path=$BACKUP_DIR/$label

    if [ "$DRY_RUN" -eq 1 ]; then
        say "Would back up: $target -> $backup_target_path"
        return 0
    fi

    mkdir -p "$(dirname "$backup_target_path")"
    mv "$target" "$backup_target_path"
    BACKUP_CREATED=1
    say "Backed up: $target -> $backup_target_path"
}

copy_path() {
    source_path=$1
    target_path=$2
    label=$3

    [ -e "$source_path" ] || die "missing source path: $source_path"

    if [ -e "$target_path" ] || [ -L "$target_path" ]; then
        if [ "$DRY_RUN" -eq 0 ] && ! confirm_replace "$target_path"; then
            say "Skipped: $target_path"
            return 0
        fi
        backup_target "$target_path" "$label"
    elif [ "$DRY_RUN" -eq 1 ]; then
        say "No existing target: $target_path"
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        say "Would copy: $source_path -> $target_path"
        return 0
    fi

    mkdir -p "$(dirname "$target_path")"
    cp -R "$source_path" "$target_path"
    say "Copied: $source_path -> $target_path"
}

copy_configs() {
    say "Config home: $CONFIG_HOME"
    say "Backup path: $BACKUP_DIR"

    copy_path "$ROOT_DIR/config/i3" "$CONFIG_HOME/i3" "i3"
    copy_path "$ROOT_DIR/config/i3blocks" "$CONFIG_HOME/i3blocks" "i3blocks"
    copy_path "$ROOT_DIR/config/rofi" "$CONFIG_HOME/rofi" "rofi"
    copy_path "$ROOT_DIR/config/dunst" "$CONFIG_HOME/dunst" "dunst"
    copy_path "$ROOT_DIR/config/picom" "$CONFIG_HOME/picom" "picom"
    copy_path "$ROOT_DIR/scripts" "$CONFIG_HOME/i3/scripts" "i3/scripts"
    copy_path "$ROOT_DIR/wallpapers" "$CONFIG_HOME/wallpapers" "wallpapers"

    if [ "$DRY_RUN" -eq 0 ] && [ "$BACKUP_CREATED" -eq 1 ]; then
        say "Backups saved under: $BACKUP_DIR"
    fi
}

if [ "$NO_INSTALL" -eq 1 ]; then
    say "Skipping dependency installation."
else
    install_dependencies
fi

copy_configs

if [ "$DRY_RUN" -eq 1 ]; then
    say "Dry run complete; no files were changed."
else
    say "Install complete. Reload i3 with Super+Shift+r."
fi
