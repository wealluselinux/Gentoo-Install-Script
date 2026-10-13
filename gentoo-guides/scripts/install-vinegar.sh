#!/usr/bin/env bash
#
# install-vinegar.sh - install Vinegar (runs Roblox Studio on Linux) via Flatpak.
# Part of Gentoo-Install-Script / gentoo-guides (MIT).
#
# Run as your NORMAL user. Needs Flatpak (see setup-flatpak.sh).
#     bash install-vinegar.sh              install
#     bash install-vinegar.sh --uninstall  remove it (keeps your data)
#     bash install-vinegar.sh --purge      remove it and delete its data
#
# Vinegar is an unofficial community project, not supported by Roblox.
# It is a Roblox STUDIO bootstrapper. To play games, see install-sober.sh.

set -Eeuo pipefail
if [[ -t 1 ]]; then G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; C=$'\e[36m'; N=$'\e[0m'; else G=""; Y=""; R=""; C=""; N=""; fi
info() { printf '%s[*]%s %s\n' "$C" "$N" "$*"; }
ok()   { printf '%s[+]%s %s\n' "$G" "$N" "$*"; }
warn() { printf '%s[!]%s %s\n' "$Y" "$N" "$*" >&2; }
die()  { printf '%s[x]%s %s\n' "$R" "$N" "$*" >&2; exit 1; }
trap 'printf "%s[x]%s Failed at line %s: %s\n" "$R" "$N" "$LINENO" "$BASH_COMMAND" >&2' ERR

APP=org.vinegarhq.Vinegar

[[ $EUID -ne 0 ]] || die "Run this as your normal user, not root."
command -v flatpak >/dev/null 2>&1 || die "Flatpak not found. Run setup-flatpak.sh first."

case "${1:-}" in
    --uninstall) flatpak uninstall --user -y "$APP"; ok "Vinegar removed (data kept)."; exit 0 ;;
    --purge)     flatpak uninstall --user -y --delete-data "$APP"; ok "Vinegar and its data removed."; exit 0 ;;
    "") ;;
    *) die "Unknown option: $1" ;;
esac

# Requirements published by the Vinegar project: x86-64, 3 GB RAM, OpenGL 4.4.
# Recommended: Linux 6.14+ (NTSync), 8 GB RAM, Vulkan 1.4.
[[ $(uname -m) == x86_64 ]] || die "Vinegar needs an x86-64 CPU."
kernel=$(uname -r | cut -d- -f1)
if [[ $(printf '%s\n6.14\n' "$kernel" | sort -V | head -n1) != 6.14 ]]; then
    warn "Kernel $kernel is older than the recommended 6.14 (needed for NTSync). It may still work, but slower."
fi

if ! flatpak remotes --user --columns=name | grep -qx flathub; then
    flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
fi

info "Installing Vinegar from Flathub..."
flatpak install --user --noninteractive flathub "$APP"

ok "Vinegar installed."
echo "Start it from your app menu, or:  flatpak run $APP"
echo "Problems? See gentoo-guides/guides/05-roblox-sober-and-vinegar.md"
