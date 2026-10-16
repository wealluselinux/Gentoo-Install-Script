#!/usr/bin/env bash
# Useful first-day apps for Gentoo. Works on both OpenRC and systemd.
# Installs selected packages through Portage; no init-system services are changed.
set -Eeuo pipefail

say()  { printf '\n[*] %s\n' "$*"; }
good() { printf '[+] %s\n' "$*"; }
warn() { printf '[!] %s\n' "$*" >&2; }
die()  { printf '[x] %s\n' "$*" >&2; exit 1; }

[[ $EUID -ne 0 ]] || die "Run as your regular user, not root. This script uses sudo."
[[ -r /etc/gentoo-release ]] || die "This script is intended for an installed Gentoo Linux system."
command -v emerge >/dev/null 2>&1 || die "Portage (emerge) was not found."
command -v sudo >/dev/null 2>&1 || die "Install and configure sudo first."

printf '%s\n' "Gentoo useful apps installer" "============================"
printf '%s\n' "Works with either OpenRC or systemd; no init services are changed."
printf '%s\n' "Portage will show its own package plan before installation."
printf '\n'
printf '%s\n' "The recommended starter set includes:"
printf '%s\n' "  Fastfetch, Flatpak, Git, curl, wget, nano, htop, tree, zip/unzip"
printf '\n'
read -r -p "Install the recommended starter set? [y/N] " answer
[[ $answer == [yY] || $answer == [yY][eE][sS] ]] || { say "Cancelled; nothing installed."; exit 0; }

packages=(
  app-misc/fastfetch
  sys-apps/flatpak
  dev-vcs/git
  net-misc/curl
  net-misc/wget
  app-editors/nano
  sys-process/htop
  app-text/tree
  app-arch/zip
  app-arch/unzip
)

say "Asking Portage to install the selected packages..."
sudo emerge --ask --verbose "${packages[@]}"

if ! command -v flatpak >/dev/null 2>&1; then
  warn "The flatpak command is not available after emerge; skipping Flathub setup."
  warn "Check the Portage output if you expected Flatpak to install."
  exit 0
fi

printf '\n'
read -r -p "Add the official Flathub remote for your user account? [y/N] " flathub_answer
if [[ $flathub_answer == [yY] || $flathub_answer == [yY][eE][sS] ]]; then
  flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  good "Flathub user remote configured."
  printf '%s\n' "You can browse apps at https://flathub.org/ and install one with:"
  printf '%s\n' "  flatpak install --user flathub APP_ID"
else
  say "Skipped Flathub setup. You can add it later from your user account."
fi

printf '\n'
good "Finished. Try 'fastfetch' and 'htop' in a terminal."
warn "This script has not been tested on every Gentoo profile. If Portage reports a missing or masked package, review the message and your profile/keywords rather than forcing installation."
