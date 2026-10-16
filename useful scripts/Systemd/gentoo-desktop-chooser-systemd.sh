#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -eq 0 ]]; then echo 'Run as your regular user, not root.' >&2; exit 1; fi
if [[ ! -r /etc/gentoo-release ]] || ! command -v emerge >/dev/null 2>&1; then echo 'Requires an installed Gentoo system with Portage.' >&2; exit 1; fi
if ! command -v systemctl >/dev/null 2>&1 || [[ ! -d /run/systemd/system ]]; then echo 'systemd is not running; this script is for systemd systems.' >&2; exit 1; fi
if ! command -v sudo >/dev/null 2>&1; then echo 'sudo is required.' >&2; exit 1; fi

echo '=== systemd Desktop Chooser ==='
echo 'Portage will show its package plan before installing.'
PS3='Choose a desktop (1-5): '
select desktop in 'KDE Plasma' 'GNOME' 'XFCE' 'Hyprland (Wayland)' 'Cancel'; do
  case "$REPLY" in
    1) packages=(kde-plasma/plasma-meta kde-plasma/sddm); dm=sddm; break ;;
    2) packages=(gnome-base/gnome gnome-base/gdm); dm=gdm; break ;;
    3) packages=(xfce-base/xfce4-meta x11-misc/lightdm); dm=lightdm; break ;;
    4) packages=(gui-wm/hyprland gui-apps/waybar gui-apps/wofi); dm=none; break ;;
    5) echo 'Cancelled.'; exit 0 ;;
    *) echo 'Choose 1-5.' ;;
  esac
done

echo "Selected: $desktop"
printf 'Package atoms: %s\n' "${packages[*]}"
read -r -p 'Ask Portage to install this desktop set? [y/N] ' answer
[[ "$answer" =~ ^[Yy]$ ]] || { echo 'Cancelled; nothing installed.'; exit 0; }
sudo emerge --ask --verbose "${packages[@]}"

echo
if [[ "$dm" != none ]]; then
  read -r -p "Enable $dm to start at boot using systemd? [y/N] " enable_answer
  if [[ "$enable_answer" =~ ^[Yy]$ ]]; then
    sudo systemctl enable "$dm.service"
    echo "Requested enablement of $dm.service. Reboot only after reviewing your desktop/login configuration."
  else
    echo "Not enabling $dm.service. You can configure it later if desired."
  fi
else
  echo 'Hyprland is a Wayland compositor and can be started from a compatible TTY/login setup; this script does not configure your login session.'
fi
echo 'This helper does not overwrite user configuration.'
echo 'Package atoms and dependencies vary with Gentoo profile, USE flags, and repository state. Review Portage output carefully.'
