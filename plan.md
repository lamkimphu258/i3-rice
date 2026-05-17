# Cross-Distro Regolith-Inspired i3 Rice

## Summary

Create a portable i3 rice repo that installs dependencies, backs up existing configs, and copies Regolith-inspired configs into the current machine. It will support only `apt`, `dnf`, and `pacman`, and will not require actual Regolith packages.

## Key Changes

- Add `install.sh` with package-manager detection for `apt`, `dnf`, and `pacman`.
- Install core dependencies: `i3`, `i3blocks`, `rofi`, `dunst`, `picom`, `feh`, `xss-lock`, `i3lock`, `playerctl`, `brightnessctl`, `network-manager-applet`, common fonts, GTK theme, and icon theme where available.
- Add portable config directories: `config/i3/`, `config/i3blocks/`, `config/rofi/`, `config/dunst/`, `config/picom/`, `scripts/`, and `wallpapers/`.
- Copy configs into `$XDG_CONFIG_HOME` or `~/.config`.
- Backup existing configs before overwriting to `~/.config-backup/i3-rice-YYYYmmdd-HHMMSS/`.

## Implementation Details

- Use native i3 with Regolith-like workflow and visuals: Super-key launcher, clean workspace bindings, subtle gaps, rofi app/search menu, dunst notifications, picom compositor, i3lock screen lock, and feh wallpaper restore.
- Use `i3bar + i3blocks` as the status bar setup.
- Keep all scripts POSIX-shell-friendly where practical.
- Provide helper scripts for status blocks such as volume, brightness, network, battery, memory, CPU/load, and date/time.
- Add installer flags:
  - `--dry-run` previews package installs and copy actions.
  - `--no-install` skips dependency installation and only copies configs.
  - `--force` overwrites without interactive confirmation while still creating backups.
- Include `README.md` with install instructions, supported distros, package notes, restore instructions, and a screenshots section placeholder.

## Test Plan

- Run `./install.sh --dry-run` and verify package-manager detection, package list, backup paths, and copy targets.
- Validate i3 config with `i3 -C -c config/i3/config`.
- Validate scripts with `sh -n scripts/*`.
- After install, verify launcher opens with rofi, i3bar loads i3blocks, notifications use dunst, picom starts, wallpaper is restored, lock command works, and volume/media/brightness keys work.
- Smoke-test installer on Ubuntu/Debian, Fedora, and Arch-based systems.

## Assumptions

- Supported distros are limited to systems using `apt`, `dnf`, or `pacman`.
- Existing user configs must be backed up before replacement.
- The goal is Regolith-inspired native i3, not installing Regolith itself.
- `i3blocks` is the status bar backend.
