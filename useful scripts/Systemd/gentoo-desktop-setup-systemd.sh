#!/usr/bin/env bash
# Gentoo post-install helper for systemd: PipeWire/WirePlumber + NetworkManager.
# Does not repartition disks or overwrite global DNS configuration.
set -Eeuo pipefail

say()  { printf '\n[*] %s\n' "$*"; }
warn() { printf '[!] %s\n' "$*" >&2; }
die()  { printf '[x] %s\n' "$*" >&2; exit 1; }

[[ $EUID -ne 0 ]] || die "Run as your regular user; this script uses sudo."
[[ -r /etc/gentoo-release ]] || die "This script is for Gentoo Linux."
command -v emerge >/dev/null 2>&1 || die "Portage (emerge) not found."
command -v sudo >/dev/null 2>&1 || die "sudo not found."
command -v systemctl >/dev/null 2>&1 || die "systemctl not found. Use the OpenRC version on OpenRC."

printf '%s\n' "Gentoo systemd desktop setup" "============================"
warn "Package installation uses Portage and may compile software."
warn "This cannot guarantee Wi-Fi without working kernel drivers and firmware."
read -r -p "Install PipeWire, WirePlumber, ALSA support, NetworkManager and dbus? [y/N] " answer
[[ $answer == [yY] || $answer == [yY][eE][sS] ]] || { say "Cancelled."; exit 0; }

say "Installing audio and networking packages..."
sudo emerge --ask --verbose \
  media-video/pipewire \
  media-video/wireplumber \
  media-libs/alsa-lib \
  media-plugins/alsa-plugins \
  net-misc/networkmanager \
  sys-apps/dbus

say "Enabling system services..."
sudo systemctl start dbus || warn "Could not start dbus now; it is normally already running on systemd."
sudo systemctl enable --now NetworkManager

printf '\n'
if command -v nmcli >/dev/null 2>&1; then
  say "NetworkManager connections:"
  nmcli -f NAME,TYPE,DEVICE connection show || true
  printf '\n'
  warn "DNS changes are optional. This edits only the connection you select."
  read -r -p "Set custom DNS on an existing NetworkManager connection? [y/N] " dns_answer
  if [[ $dns_answer == [yY] || $dns_answer == [yY][eE][sS] ]]; then
    nmcli -f NAME,TYPE,DEVICE connection show
    read -r -p "Enter the exact connection name: " conn
    [[ -n $conn ]] || die "Connection name cannot be empty."
    read -r -p "IPv4 DNS servers (space-separated) [1.1.1.1 9.9.9.9]: " dns
    dns=${dns:-"1.1.1.1 9.9.9.9"}
    dns_csv=${dns// /,}
    say "Applying DNS to connection: $conn"
    sudo nmcli connection modify "$conn" ipv4.dns "$dns_csv" ipv4.ignore-auto-dns yes
    read -r -p "Set IPv6 DNS too? [y/N] " ipv6_answer
    if [[ $ipv6_answer == [yY] || $ipv6_answer == [yY][eE][sS] ]]; then
      read -r -p "IPv6 DNS servers [2606:4700:4700::1111,2620:fe::fe]: " dns6
      dns6=${dns6:-"2606:4700:4700::1111,2620:fe::fe"}
      sudo nmcli connection modify "$conn" ipv6.dns "$dns6" ipv6.ignore-auto-dns yes
    fi
    sudo nmcli connection up "$conn" || warn "Reconnect failed; try reconnecting from your network menu."
  fi
else
  warn "nmcli is unavailable. Check that NetworkManager installed correctly."
fi

printf '\n'
printf '[+] Setup commands completed.\n'
warn "PipeWire is a per-user audio service: log out and back in, then check with 'wpctl status' and 'pactl info' if installed."
warn "For Wi-Fi, use 'nmtui' or your desktop network menu. Firmware/driver problems need separate diagnosis."
