#!/bin/sh

set -eu

DRY_RUN=0
NO_INSTALL=0
FORCE=0
SESSION_ONLY=0
DID_INSTALL=0

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CONFIG_HOME=${XDG_CONFIG_HOME:-"$HOME/.config"}
BACKUP_ROOT=${I3_RICE_BACKUP_ROOT:-"$HOME/.config-backup"}
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR=$BACKUP_ROOT/i3-rice-$TIMESTAMP
BACKUP_CREATED=0

APT_PACKAGES="xorg i3-wm i3blocks rofi kitty dunst picom feh xss-lock i3lock playerctl brightnessctl pavucontrol upower network-manager-gnome gsimplecal fonts-dejavu fonts-font-awesome fonts-noto-color-emoji arc-theme papirus-icon-theme build-essential ca-certificates curl unzip fontconfig git neovim ripgrep bash nginx php-cli php-fpm php-xml php-sqlite3 php-mysql vlc flameshot simplescreenrecorder obs-studio"
PACMAN_PACKAGES="xorg-server xorg-xinit i3-wm i3blocks rofi kitty dunst picom feh xss-lock i3lock playerctl brightnessctl pavucontrol upower network-manager-applet gsimplecal ttf-dejavu ttf-font-awesome noto-fonts-emoji arc-gtk-theme papirus-icon-theme base-devel ca-certificates curl unzip fontconfig git neovim ripgrep bash nginx php php-fpm php-sqlite docker docker-compose vlc flameshot simplescreenrecorder obs-studio"
DOCKER_APT_PACKAGES="docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
CHROME_DEB_URL="https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
MYSQL_APT_KEY_URL="https://repo.mysql.com/RPM-GPG-KEY-mysql-2025"
MYSQL_WORKBENCH_APT_PACKAGE="mysql-workbench-community"
NERD_FONT_NAME="JetBrainsMono Nerd Font"
NERD_FONT_VERSION="v3.4.0"
NERD_FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/$NERD_FONT_VERSION/JetBrainsMono.zip"
NERD_FONT_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
USER_FONT_DIR="$HOME/.local/share/fonts"
ASTRONVIM_TEMPLATE_URL="https://github.com/AstroNvim/template"
ASTRONVIM_CONFIG_DIR="$CONFIG_HOME/nvim"
NVM_VERSION="v0.40.4"
NVM_INSTALL_URL="https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh"
NVM_DIR=${NVM_DIR:-"$HOME/.nvm"}
XSESSION_FILE=/usr/share/xsessions/i3-rice.desktop

usage() {
    cat <<'EOF'
Usage: ./install.sh [options]

Options:
  --dry-run      Print package install and copy actions without changing files.
  --no-install   Skip dependency installation and only copy configs.
  --session-only Install only the login-screen session entry.
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
        --session-only)
            SESSION_ONLY=1
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
    elif command -v pacman >/dev/null 2>&1; then
        printf 'pacman'
    else
        return 1
    fi
}

os_release_value() {
    key=$1

    [ -r /etc/os-release ] || return 1
    # shellcheck disable=SC1091
    . /etc/os-release

    case "$key" in
        ID)
            printf '%s' "${ID:-}"
            ;;
        VERSION_CODENAME)
            printf '%s' "${VERSION_CODENAME:-}"
            ;;
        UBUNTU_CODENAME)
            printf '%s' "${UBUNTU_CODENAME:-}"
            ;;
        *)
            return 1
            ;;
    esac
}

update_upgrade_system() {
    manager=$(detect_package_manager) || die "unsupported distro: expected apt or pacman"
    sudo_cmd=$(need_sudo)

    case "$manager" in
        apt)
            if [ "$DRY_RUN" -eq 1 ]; then
                say "Would run: $sudo_cmd apt-get update"
                say "Would run: $sudo_cmd apt-get upgrade -y"
            else
                $sudo_cmd apt-get update
                $sudo_cmd apt-get upgrade -y
            fi
            ;;
        pacman)
            if [ "$DRY_RUN" -eq 1 ]; then
                say "Would run: $sudo_cmd pacman -Syu --noconfirm"
            else
                $sudo_cmd pacman -Syu --noconfirm
            fi
            ;;
    esac
}

install_dependencies() {
    manager=$(detect_package_manager) || die "unsupported distro: expected apt or pacman"
    sudo_cmd=$(need_sudo)

    say "Package manager: $manager"

    case "$manager" in
        apt)
            if [ "$DRY_RUN" -eq 1 ]; then
                say "Would run: $sudo_cmd apt-get install -y $APT_PACKAGES"
            else
                # shellcheck disable=SC2086
                $sudo_cmd apt-get install -y $APT_PACKAGES
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

docker_apt_repo_id() {
    os_id=$(os_release_value ID || printf '')
    ubuntu_codename=$(os_release_value UBUNTU_CODENAME || printf '')

    case "$os_id" in
        ubuntu|debian)
            printf '%s' "$os_id"
            ;;
        *)
            if [ -n "$ubuntu_codename" ]; then
                printf 'ubuntu'
            else
                printf 'debian'
            fi
            ;;
    esac
}

docker_apt_codename() {
    ubuntu_codename=$(os_release_value UBUNTU_CODENAME || printf '')
    version_codename=$(os_release_value VERSION_CODENAME || printf '')

    if [ -n "$ubuntu_codename" ]; then
        printf '%s' "$ubuntu_codename"
    elif [ -n "$version_codename" ]; then
        printf '%s' "$version_codename"
    else
        die "could not determine apt suite from /etc/os-release"
    fi
}

mysql_workbench_apt_codename() {
    repo_suite=$(docker_apt_codename)

    case "$repo_suite" in
        noble|jammy)
            printf '%s' "$repo_suite"
            ;;
        *)
            printf 'noble'
            ;;
    esac
}

install_docker_latest() {
    manager=$(detect_package_manager) || die "unsupported distro: expected apt or pacman"
    sudo_cmd=$(need_sudo)

    case "$manager" in
        apt)
            repo_id=$(docker_apt_repo_id)
            repo_suite=$(docker_apt_codename)

            if [ "$DRY_RUN" -eq 1 ]; then
                say "Would remove conflicting Docker packages with apt if present"
                say "Would install Docker apt repo: https://download.docker.com/linux/$repo_id ($repo_suite)"
                say "Would run: $sudo_cmd apt-get update"
                say "Would run: $sudo_cmd apt-get install -y $DOCKER_APT_PACKAGES"
            else
                # shellcheck disable=SC2046
                $sudo_cmd apt-get remove -y $(dpkg --get-selections docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc 2>/dev/null | cut -f1) || true
                $sudo_cmd install -m 0755 -d /etc/apt/keyrings
                $sudo_cmd curl -fsSL "https://download.docker.com/linux/$repo_id/gpg" -o /etc/apt/keyrings/docker.asc
                $sudo_cmd chmod a+r /etc/apt/keyrings/docker.asc
                arch=$(dpkg --print-architecture)
                printf 'Types: deb\nURIs: https://download.docker.com/linux/%s\nSuites: %s\nComponents: stable\nArchitectures: %s\nSigned-By: /etc/apt/keyrings/docker.asc\n' "$repo_id" "$repo_suite" "$arch" \
                    | $sudo_cmd tee /etc/apt/sources.list.d/docker.sources >/dev/null
                $sudo_cmd apt-get update
                # shellcheck disable=SC2086
                $sudo_cmd apt-get install -y $DOCKER_APT_PACKAGES
            fi
            ;;
        pacman)
            if [ "$DRY_RUN" -eq 1 ]; then
                say "Would install Docker and Docker Compose from Arch rolling packages"
            else
                $sudo_cmd pacman -S --needed --noconfirm docker docker-compose
            fi
            ;;
    esac
}

install_google_chrome() {
    manager=$(detect_package_manager) || die "unsupported distro: expected apt or pacman"
    sudo_cmd=$(need_sudo)

    case "$manager" in
        apt)
            if [ "$DRY_RUN" -eq 1 ]; then
                say "Would download Google Chrome: $CHROME_DEB_URL"
                say "Would run: $sudo_cmd apt-get install -y ./google-chrome-stable_current_amd64.deb"
            else
                chrome_deb=$(mktemp --suffix=.deb)
                curl -fL "$CHROME_DEB_URL" -o "$chrome_deb"
                $sudo_cmd apt-get install -y "$chrome_deb"
                rm -f "$chrome_deb"
            fi
            ;;
        pacman)
            if [ "$DRY_RUN" -eq 1 ]; then
                say "Would build and install Google Chrome from AUR: https://aur.archlinux.org/google-chrome.git"
            else
                install_aur_package google-chrome
            fi
            ;;
    esac
}

install_mysql_workbench() {
    manager=$(detect_package_manager) || die "unsupported distro: expected apt or pacman"
    sudo_cmd=$(need_sudo)

    case "$manager" in
        apt)
            repo_id=$(docker_apt_repo_id)
            repo_suite=$(mysql_workbench_apt_codename)

            if [ "$repo_id" != ubuntu ]; then
                die "MySQL Workbench from MySQL APT repository is only provided for Ubuntu apt systems"
            fi

            if [ "$DRY_RUN" -eq 1 ]; then
                say "Would install MySQL APT key: $MYSQL_APT_KEY_URL"
                say "Would install MySQL Workbench apt repo: http://repo.mysql.com/apt/ubuntu/ $repo_suite mysql-tools"
                say "Would run: $sudo_cmd apt-get update"
                say "Would run: $sudo_cmd apt-get install -y $MYSQL_WORKBENCH_APT_PACKAGE"
            else
                $sudo_cmd install -m 0755 -d /etc/apt/keyrings
                $sudo_cmd curl -fsSL "$MYSQL_APT_KEY_URL" -o /etc/apt/keyrings/mysql.asc
                $sudo_cmd chmod a+r /etc/apt/keyrings/mysql.asc
                printf 'deb [arch=amd64 signed-by=/etc/apt/keyrings/mysql.asc] http://repo.mysql.com/apt/ubuntu/ %s mysql-tools\n' "$repo_suite" \
                    | $sudo_cmd tee /etc/apt/sources.list.d/mysql-workbench.list >/dev/null
                $sudo_cmd apt-get update
                $sudo_cmd apt-get install -y "$MYSQL_WORKBENCH_APT_PACKAGE"
            fi
            ;;
        pacman)
            if [ "$DRY_RUN" -eq 1 ]; then
                say "Would run: $sudo_cmd pacman -S --needed --noconfirm mysql-workbench"
            else
                $sudo_cmd pacman -S --needed --noconfirm mysql-workbench
            fi
            ;;
    esac
}

install_aur_package() {
    package=$1
    aur_user=${SUDO_USER:-${USER:-}}

    [ -n "$aur_user" ] || die "could not determine non-root user for AUR install"
    [ "$aur_user" != root ] || die "AUR package builds must run as a non-root user"

    aur_dir=$(mktemp -d)
    git clone "https://aur.archlinux.org/$package.git" "$aur_dir/$package"

    if [ "$(id -u)" -eq 0 ]; then
        chown -R "$aur_user:$aur_user" "$aur_dir"
        su "$aur_user" -c "cd '$aur_dir/$package' && makepkg -si --noconfirm --needed"
    else
        (cd "$aur_dir/$package" && makepkg -si --noconfirm --needed)
    fi

    rm -rf "$aur_dir"
}

install_external_desktop_apps() {
    install_google_chrome
    install_mysql_workbench
}

run_docker_post_install() {
    sudo_cmd=$(need_sudo)
    docker_user=${SUDO_USER:-${USER:-}}

    if [ -z "$docker_user" ] || [ "$docker_user" = root ]; then
        docker_user=$(id -un)
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        say "Would run Docker post-install: create docker group if missing"
        say "Would run Docker post-install: add $docker_user to docker group"
        say "Would run Docker post-install: enable and start docker.service"
        return 0
    fi

    $sudo_cmd groupadd -f docker
    $sudo_cmd usermod -aG docker "$docker_user"

    if command -v systemctl >/dev/null 2>&1; then
        $sudo_cmd systemctl enable --now docker
    else
        say "Skipped Docker service enable/start: systemctl not found"
    fi

    say "Docker post-install complete. Log out and back in for docker group membership to apply."
}

run_php_post_install() {
    manager=$(detect_package_manager) || die "unsupported distro: expected apt or pacman"
    sudo_cmd=$(need_sudo)
    php_ext_file=/etc/php/conf.d/99-i3-rice.ini

    if [ "$manager" != pacman ]; then
        return 0
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        say "Would enable PHP mysqli, pdo_mysql, sqlite3, and pdo_sqlite modules in $php_ext_file"
        return 0
    fi

    printf '%s\n' \
        'extension=mysqli' \
        'extension=pdo_mysql' \
        'extension=sqlite3' \
        'extension=pdo_sqlite' \
        | $sudo_cmd tee "$php_ext_file" >/dev/null
    say "Enabled PHP MySQL and SQLite extensions: $php_ext_file"
}

autoremove_packages() {
    manager=$(detect_package_manager) || die "unsupported distro: expected apt or pacman"
    sudo_cmd=$(need_sudo)

    case "$manager" in
        apt)
            if [ "$DRY_RUN" -eq 1 ]; then
                say "Would run: $sudo_cmd apt-get autoremove -y"
            else
                $sudo_cmd apt-get autoremove -y
            fi
            ;;
        pacman)
            if [ "$DRY_RUN" -eq 1 ]; then
                say "Would remove orphaned pacman packages if any exist"
            else
                orphans=$(pacman -Qtdq 2>/dev/null || true)
                if [ -n "$orphans" ]; then
                    # shellcheck disable=SC2086
                    $sudo_cmd pacman -Rns --noconfirm $orphans
                else
                    say "No orphaned pacman packages to remove."
                fi
            fi
            ;;
    esac
}

install_nerd_font() {
    if command -v fc-match >/dev/null 2>&1 && fc-match "$NERD_FONT_NAME" | grep -qi 'JetBrainsMono.*Nerd'; then
        say "Nerd Font already installed: $NERD_FONT_NAME"
        return 0
    fi

    font_zip=

    if [ "$DRY_RUN" -eq 1 ]; then
        say "Would download Nerd Font: $NERD_FONT_URL"
        say "Would extract Nerd Font to: $NERD_FONT_DIR"
        say "Would run: fc-cache -fv $USER_FONT_DIR"
        return 0
    fi

    command -v curl >/dev/null 2>&1 || die "curl is required to download $NERD_FONT_NAME"
    command -v unzip >/dev/null 2>&1 || die "unzip is required to extract $NERD_FONT_NAME"
    command -v fc-cache >/dev/null 2>&1 || die "fontconfig is required to refresh the font cache"

    mkdir -p "$NERD_FONT_DIR"
    font_zip=$(mktemp)

    if ! curl -fL "$NERD_FONT_URL" -o "$font_zip"; then
        rm -f "$font_zip"
        die "failed to download $NERD_FONT_NAME"
    fi

    unzip -oq "$font_zip" -d "$NERD_FONT_DIR"
    rm -f "$font_zip"
    fc-cache -fv "$USER_FONT_DIR"
    say "Installed Nerd Font: $NERD_FONT_NAME"
}

install_nvm_node_lts() {
    if [ "$DRY_RUN" -eq 1 ]; then
        if [ -s "$NVM_DIR/nvm.sh" ]; then
            say "Would source NVM in installer shell: $NVM_DIR/nvm.sh"
        else
            say "Would download NVM installer: $NVM_INSTALL_URL"
            say "Would run NVM installer with bash"
            say "Would source NVM in installer shell: $NVM_DIR/nvm.sh"
        fi
        say "Would export NVM_DIR=$NVM_DIR"
        say "Would run: nvm install --lts"
        say "Would run: nvm alias default 'lts/*'"
        return 0
    fi

    command -v curl >/dev/null 2>&1 || die "curl is required to install NVM"
    command -v bash >/dev/null 2>&1 || die "bash is required to install NVM"

    if [ ! -s "$NVM_DIR/nvm.sh" ]; then
        nvm_installer=$(mktemp)

        if ! curl -fL "$NVM_INSTALL_URL" -o "$nvm_installer"; then
            rm -f "$nvm_installer"
            die "failed to download NVM installer"
        fi

        bash "$nvm_installer"
        rm -f "$nvm_installer"
    fi

    export NVM_DIR
    # shellcheck disable=SC1091
    . "$NVM_DIR/nvm.sh"
    nvm install --lts
    nvm alias default 'lts/*'
    say "Installed NVM $NVM_VERSION and Node.js LTS"
}

load_nvm() {
    export NVM_DIR
    [ -s "$NVM_DIR/nvm.sh" ] || die "NVM is not installed at $NVM_DIR"
    # shellcheck disable=SC1091
    . "$NVM_DIR/nvm.sh"
}

install_global_npm_tools() {
    if [ "$DRY_RUN" -eq 1 ]; then
        say "Would source NVM in installer shell: $NVM_DIR/nvm.sh"
        say "Would run: npm install -g @openai/codex@latest @anthropic-ai/claude-code@latest opencode-ai@latest bun@latest"
        return 0
    fi

    load_nvm
    command -v npm >/dev/null 2>&1 || die "npm is required to install Codex CLI and Bun globally"
    npm install -g @openai/codex@latest @anthropic-ai/claude-code@latest opencode-ai@latest bun@latest
    say "Installed global npm tools: @openai/codex@latest @anthropic-ai/claude-code@latest opencode-ai@latest bun@latest"
}

install_composer() {
    sudo_cmd=$(need_sudo)

    if [ "$DRY_RUN" -eq 1 ]; then
        say "Would download and verify Composer installer from getcomposer.org"
        say "Would install latest Composer to: /usr/local/bin/composer"
        return 0
    fi

    command -v php >/dev/null 2>&1 || die "php is required to install Composer"

    composer_installer=$(mktemp)
    expected_checksum=$(php -r "copy('https://composer.github.io/installer.sig', 'php://stdout');")
    php -r "copy('https://getcomposer.org/installer', '$composer_installer');"
    actual_checksum=$(php -r "echo hash_file('sha384', '$composer_installer');")

    if [ "$expected_checksum" != "$actual_checksum" ]; then
        rm -f "$composer_installer"
        die "Composer installer checksum verification failed"
    fi

    $sudo_cmd php "$composer_installer" --quiet --install-dir=/usr/local/bin --filename=composer
    rm -f "$composer_installer"
    say "Installed Composer: /usr/local/bin/composer"
}

install_astronvim() {
    if [ -e "$ASTRONVIM_CONFIG_DIR" ] || [ -L "$ASTRONVIM_CONFIG_DIR" ]; then
        if [ "$DRY_RUN" -eq 0 ] && ! confirm_replace "$ASTRONVIM_CONFIG_DIR"; then
            say "Skipped AstroNvim install: $ASTRONVIM_CONFIG_DIR"
            return 0
        fi
        backup_target "$ASTRONVIM_CONFIG_DIR" "nvim"
    elif [ "$DRY_RUN" -eq 1 ]; then
        say "No existing target: $ASTRONVIM_CONFIG_DIR"
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        say "Would clone AstroNvim template: $ASTRONVIM_TEMPLATE_URL -> $ASTRONVIM_CONFIG_DIR"
        say "Would remove AstroNvim template git metadata: $ASTRONVIM_CONFIG_DIR/.git"
        say "Would initialize AstroNvim: nvim --headless +q"
        return 0
    fi

    command -v git >/dev/null 2>&1 || die "git is required to install AstroNvim"
    command -v nvim >/dev/null 2>&1 || die "neovim is required to initialize AstroNvim"

    mkdir -p "$(dirname "$ASTRONVIM_CONFIG_DIR")"
    git clone --depth 1 "$ASTRONVIM_TEMPLATE_URL" "$ASTRONVIM_CONFIG_DIR"
    rm -rf "$ASTRONVIM_CONFIG_DIR/.git"
    nvim --headless +q
    say "Installed AstroNvim: $ASTRONVIM_CONFIG_DIR"
}

install_login_session() {
    sudo_cmd=$(need_sudo)

    if [ "$DRY_RUN" -eq 1 ]; then
        say "Would install login session: $XSESSION_FILE"
        return 0
    fi

    session_tmp=$(mktemp)
    cat >"$session_tmp" <<'EOF'
[Desktop Entry]
Name=i3 Rice
Comment=Log in using i3 with this rice configuration
Exec=i3
TryExec=i3
Type=XSession
X-LightDM-DesktopName=i3 Rice
DesktopNames=i3-rice
X-GDM-SessionRegisters=true
Keywords=tiling;wm;windowmanager;
EOF

    if [ -n "$sudo_cmd" ]; then
        $sudo_cmd install -Dm644 "$session_tmp" "$XSESSION_FILE"
    else
        install -Dm644 "$session_tmp" "$XSESSION_FILE"
    fi

    rm -f "$session_tmp"
    say "Installed login session: $XSESSION_FILE"
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

if [ "$SESSION_ONLY" -eq 1 ]; then
    install_login_session
    if [ "$DRY_RUN" -eq 1 ]; then
        say "Dry run complete; no files were changed."
    else
        say "Session install complete. Log out, select \"i3 Rice\" from the session menu, then log in."
    fi
    exit 0
fi

if [ "$NO_INSTALL" -eq 1 ]; then
    say "Skipping dependency installation."
else
    DID_INSTALL=1
    update_upgrade_system
    install_dependencies
    run_php_post_install
    install_docker_latest
    run_docker_post_install
    install_external_desktop_apps
    install_nerd_font
    install_nvm_node_lts
    install_global_npm_tools
    install_composer
    install_astronvim
fi

install_login_session

copy_configs

if [ "$DID_INSTALL" -eq 1 ]; then
    autoremove_packages
fi

if [ "$DRY_RUN" -eq 1 ]; then
    say "Dry run complete; no files were changed."
else
    say "Install complete. Log out, select \"i3 Rice\" from the session menu, then log in."
fi
