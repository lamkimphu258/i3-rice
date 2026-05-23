# Cross-Distro Regolith-Inspired i3 Rice

Portable native i3 configuration with a Regolith-style workflow. It installs common desktop dependencies, sets up AstroNvim, backs up existing configs, and copies this repo's configs into your user config directory.

Supported package managers:

- `apt`
- `pacman`

This does not install Regolith packages.

## Install

Preview the actions first:

```sh
./install.sh --dry-run
```

Install dependencies and copy configs:

```sh
./install.sh
```

This also installs NVM, installs the latest Node.js LTS release with `nvm install --lts`, and installs AstroNvim from the official template into `~/.config/nvim`.

On Ubuntu's default GDM login screen, choose the session after logging out:

1. Click your user.
2. Click the gear icon in the lower-right corner.
3. Select `i3 Rice`.
4. Enter your password and log in.

Copy configs only:

```sh
./install.sh --no-install
```

Overwrite without prompts while still creating backups:

```sh
./install.sh --force
```

The installer copies configs into `${XDG_CONFIG_HOME:-$HOME/.config}`:

- AstroNvim template -> `~/.config/nvim`
- `config/i3` -> `~/.config/i3`
- `config/i3blocks` -> `~/.config/i3blocks`
- `config/kitty` -> `~/.config/kitty`
- `config/rofi` -> `~/.config/rofi`
- `config/dunst` -> `~/.config/dunst`
- `config/picom` -> `~/.config/picom`
- `config/shell/x11-session-env.sh` -> `~/.config/i3-rice/x11-session-env.sh`
- `scripts` -> `~/.config/i3/scripts`
- `wallpapers` -> `~/.config/wallpapers`
- `applications/google-chrome.desktop` -> `~/.local/share/applications/google-chrome.desktop`

It also installs this display-manager session entry:

- `/usr/share/xsessions/i3-rice.desktop`

The installer also makes `~/.zshrc`, `~/.profile`, `~/.zprofile`, and `~/.xsessionrc` source the i3 Rice X11 environment file. This keeps `XDG_SESSION_TYPE=x11` and `QT_QPA_PLATFORM=xcb` for zsh, i3 sessions, and Qt apps such as Flameshot.

Existing targets are moved to:

```text
~/.config-backup/i3-rice-YYYYmmdd-HHMMSS/
```

## Package Notes

The installer uses distro-native package names for i3, i3blocks, rofi, Kitty, dunst, picom, feh, xss-lock, i3lock, playerctl, brightnessctl, pavucontrol, upower, NetworkManager applet, a calendar popup helper, common fonts, Font Awesome, Arc GTK theme, Papirus icons, Git, curl, bash, zsh, Neovim, ripgrep, nginx, PHP-FPM, PHP XML, PHP SQLite, PHP MySQL extensions, VLC, Flameshot, SimpleScreenRecorder, and OBS Studio.

Before installing packages, the installer updates package metadata and upgrades existing packages with `apt-get update && apt-get upgrade -y` or `pacman -Syu --noconfirm`. At the end, it runs `apt-get autoremove -y` on apt systems or removes orphaned packages on pacman systems.

Google Chrome is downloaded from Google's current stable Linux `.deb` on apt systems. On Arch-based systems, Google Chrome is built and installed from the `google-chrome` AUR package, so the installer must run with a non-root user available for `makepkg`.

MySQL Workbench is installed from MySQL's official APT `mysql-tools` repository on Ubuntu apt systems as `mysql-workbench-community`. On Arch-based systems, it is installed from the official `extra` repository as `mysql-workbench`.

Docker Engine, Docker Buildx, and Docker Compose are installed as the latest stable packages from Docker's official apt repository where available. On Arch-based systems, Docker and Compose are installed from Arch's rolling packages. The installer also runs Docker's Linux post-install steps: it creates the `docker` group if needed, adds the installing user to it, and enables/starts `docker.service` when systemd is available. Log out and back in before running Docker without `sudo`.

It also installs `JetBrainsMono Nerd Font` into `~/.local/share/fonts/JetBrainsMonoNerdFont` so i3, i3bar, rofi, and terminal apps can render icon glyphs consistently.

Native compiler tools are installed as well: `build-essential` on apt systems and `base-devel` on pacman systems. These are needed by Neovim/AstroNvim Tree-sitter parser builds. AstroNvim currently requires Neovim 0.11 or newer; if your distro package is older, install a newer Neovim build before launching it.

NVM is installed from the versioned upstream installer, sourced inside the installer shell, and then used to install the latest Node.js LTS release. After Node is available, npm installs the latest global `@openai/codex`, `@anthropic-ai/claude-code`, `opencode-ai`, and `bun` packages. NVM also updates your shell profile so new terminals can load `nvm`.

Oh My Zsh is cloned from the upstream `ohmyzsh/ohmyzsh` repository into `~/.oh-my-zsh`, and `~/.zshrc` is updated to load it.

Composer is installed from the upstream installer, verified against the official installer checksum, and written to `/usr/local/bin/composer`. After Composer is available, it globally installs Laravel's `laravel/installer` package.

Some theme, font, PHP, Docker, Chrome, or MySQL Workbench package names vary by distro or repository setup. If dependency installation fails, install the missing package manually or rerun with `--no-install` to copy only configs. `--no-install` skips package installation, Chrome and MySQL Workbench setup, Docker setup, Nerd Font setup, NVM/Node setup, global npm tools, Composer, Laravel installer setup, AstroNvim setup, compiler tools, and the display-manager session entry.

## Wallpaper Rotation

i3 starts `~/.config/i3/scripts/wallpaper rotate`, which changes the wallpaper immediately and then every 15 minutes.

The script cycles through supported image files in `~/.config/wallpapers`. To use a different directory or interval, set these before i3 starts:

```sh
export I3_WALLPAPER_DIR="$HOME/Pictures/wallpapers"
export I3_WALLPAPER_INTERVAL=900
```

## Restore

To restore a backed-up config, move it from the backup directory back into your config directory. For example:

```sh
mv ~/.config-backup/i3-rice-YYYYmmdd-HHMMSS/i3 ~/.config/i3
```

Use the matching backup path printed by the installer.

## Useful Checks

```sh
./install.sh --dry-run
i3 -C -c config/i3/config
sh -n scripts/*
nvim --headless "+TSUpdateSync" +qa
```

After installing, reload i3 with `Super+Shift+r`.

## Key Bindings

- `Super+Enter`: Kitty terminal
- `Super+Space`: rofi combined launcher for apps, commands, windows, SSH hosts, and files
- `Super+Tab`: toggle focus between tiling and floating windows
- `Super+Shift+q`: close focused window
- `Super+Shift+x`: lock screen
- `Super+Shift+s`: lock screen and suspend
- i3blocks volume: scroll adjusts volume, left click toggles mute, right click opens the mixer
- i3blocks brightness: scroll or left/right click adjusts brightness
- i3blocks network: click opens the NetworkManager connection editor
- i3blocks battery: click shows battery details
- i3blocks calendar: click toggles the calendar popup
- `Super+1` through `Super+0`: switch workspaces
- `Super+Shift+1` through `Super+Shift+0`: move window to workspace
- `Super+h/j/k/l` or arrow keys: focus windows
- `Super+Shift+h/j/k/l` or arrow keys: move windows

## Screenshots

Placeholder for screenshots.
