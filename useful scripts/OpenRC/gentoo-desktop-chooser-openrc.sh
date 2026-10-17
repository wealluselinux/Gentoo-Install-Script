#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -eq 0 ]]; then echo 'Run as your regular user, not root.' >&2; exit 1; fi
if [[ ! -r /etc/gentoo-release ]] || ! command -v emerge >/dev/null 2>&1; then echo 'Requires an installed Gentoo system with Portage.' >&2; exit 1; fi
if ! command -v rc-update >/dev/null 2>&1; then echo 'OpenRC tools not found; this script is for OpenRC systems.' >&2; exit 1; fi
if ! command -v sudo >/dev/null 2>&1; then echo 'sudo is required.' >&2; exit 1; fi

echo '=== OpenRC Desktop Chooser ==='
echo 'GNOME is not offered here: on OpenRC it needs extra pieces (elogind, gnome-session-openrc) that this helper does not set up.'
echo 'Portage will show its package plan before installing.'
PS3='Choose a desktop (1-4): '
select desktop in 'KDE Plasma' 'XFCE' 'Hyprland (Wayland)' 'Cancel'; do
  case "$REPLY" in
    1) packages=(kde-plasma/plasma-meta x11-misc/sddm gui-libs/display-manager-init); dm=sddm; break ;;
    2) packages=(x11-base/xorg-server xfce-base/xfce4-meta x11-misc/lightdm x11-misc/lightdm-gtk-greeter gui-libs/display-manager-init); dm=lightdm; break ;;
    3) packages=(gui-wm/hyprland gui-apps/waybar gui-apps/wofi); dm=none; break ;;
    4) echo 'Cancelled.'; exit 0 ;;
    *) echo 'Choose 1-4.' ;;
  esac
done

if [[ $desktop == Hyprland* ]] && ! portageq best_visible / gui-wm/hyprland >/dev/null 2>&1; then
  echo 'gui-wm/hyprland cannot be installed with your current Portage setup.'
  echo 'It may be masked, keyworded as testing (~amd64), or no longer in the main Gentoo repository.'
  echo 'Check with: emerge --search hyprland   Read the Gentoo wiki before adding any third-party overlay.'
  exit 1
fi

echo "Selected: $desktop"
printf 'Package atoms: %s\n' "${packages[*]}"
read -r -p 'Ask Portage to install this desktop set? [y/N] ' answer
[[ "$answer" =~ ^[Yy]$ ]] || { echo 'Cancelled; nothing installed.'; exit 0; }
sudo emerge --ask --verbose "${packages[@]}"

echo
if [[ "$dm" != none ]]; then
  echo "Display manager package requested: $dm"
  echo "Next steps: set DISPLAYMANAGER=\"$dm\" in /etc/conf.d/display-manager, then run:"
  echo '  sudo rc-update add elogind boot'
  echo '  sudo rc-update add dbus default'
  echo '  sudo rc-update add display-manager default'
else
  echo 'Hyprland is a Wayland compositor and can be started from a compatible TTY/login setup; this script does not configure your login session.'
fi
echo 'This helper does not overwrite user configuration or automatically enable services.'
echo 'Package atoms and dependencies vary with Gentoo profile, USE flags, and repository state. Review Portage output carefully.'
