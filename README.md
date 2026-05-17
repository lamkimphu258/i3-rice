# Cross-Distro Regolith-Inspired i3 Rice

Portable native i3 configuration with a Regolith-style workflow. It installs common desktop dependencies, backs up existing configs, and copies this repo's configs into your user config directory.

Supported package managers:

- `apt`
- `dnf`
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

Copy configs only:

```sh
./install.sh --no-install
```

Overwrite without prompts while still creating backups:

```sh
./install.sh --force
```

The installer copies configs into `${XDG_CONFIG_HOME:-$HOME/.config}`:

- `config/i3` -> `~/.config/i3`
- `config/i3blocks` -> `~/.config/i3blocks`
- `config/rofi` -> `~/.config/rofi`
- `config/dunst` -> `~/.config/dunst`
- `config/picom` -> `~/.config/picom`
- `scripts` -> `~/.config/i3/scripts`
- `wallpapers` -> `~/.config/wallpapers`

Existing targets are moved to:

```text
~/.config-backup/i3-rice-YYYYmmdd-HHMMSS/
```

## Package Notes

The installer uses distro-native package names for i3, i3blocks, rofi, dunst, picom, feh, xss-lock, i3lock, playerctl, brightnessctl, pavucontrol, upower, NetworkManager applet, a calendar popup helper, common fonts, Font Awesome, Arc GTK theme, and Papirus icons.

Some theme or font package names vary by distro or repository setup. If dependency installation fails, install the missing package manually or rerun with `--no-install` to copy only configs.

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
```

After installing, reload i3 with `Super+Shift+r`.

## Key Bindings

- `Super+Enter`: terminal
- `Super+d`: rofi combined launcher for apps, commands, windows, SSH hosts, and files
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
