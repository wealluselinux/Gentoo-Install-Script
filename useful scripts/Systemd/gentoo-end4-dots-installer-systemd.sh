#!/usr/bin/env bash
# Systemd-labelled variant of the experimental End-4 dotfiles bootstrap.
# This only clones/updates upstream files; it does not install the desktop.
set -Eeuo pipefail
readonly UPSTREAM_URL="https://github.com/end-4/dots-hyprland.git"
readonly DOTS_DIR="${HOME}/.local/src/dots-hyprland"
say() { printf '[*] %s\n' "$*"; }
die() { printf '[x] %s\n' "$*" >&2; exit 1; }
[[ $EUID -ne 0 ]] || die "Run as your regular desktop user, not root."
[[ -r /etc/gentoo-release ]] || die "This helper is intended for Gentoo Linux."
command -v emerge >/dev/null 2>&1 || die "Portage (emerge) not found."
command -v systemctl >/dev/null 2>&1 || die "systemctl not found; use the OpenRC folder variant if appropriate."
command -v git >/dev/null 2>&1 || die "Install git first: sudo emerge --ask dev-vcs/git"
printf '%s\n' "End-4 / illogical-impulse bootstrap (systemd, experimental)"
printf '%s\n' "This does not run upstream setup or claim full Gentoo compatibility."
read -r -p "Continue? [y/N] " answer
[[ $answer == [yY] || $answer == [yY][eE][sS] ]] || exit 0
if [[ -e $DOTS_DIR ]]; then
  [[ -d $DOTS_DIR/.git ]] || die "$DOTS_DIR exists but is not a Git checkout."
  read -r -p "Update existing checkout with git pull --ff-only? [y/N] " update
  if [[ $update == [yY] || $update == [yY][eE][sS] ]]; then git -C "$DOTS_DIR" pull --ff-only; fi
else
  mkdir -p "$(dirname "$DOTS_DIR")"
  git clone --depth 1 "$UPSTREAM_URL" "$DOTS_DIR"
fi
say "Checkout ready at $DOTS_DIR"
printf '%s\n' "Review https://ii.clsty.link and the upstream setup scripts before proceeding."
printf '%s\n' "Systemd-specific service setup and Gentoo package mapping are not automated here."
