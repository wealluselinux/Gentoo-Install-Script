#!/usr/bin/env bash
#
# install-sober.sh - install Sober (an unofficial Roblox player for Linux) via Flatpak.
# Part of Gentoo-Install-Script / gentoo-guides (MIT).
#
# Run as your NORMAL user. Needs Flatpak (see setup-flatpak.sh).
#     bash install-sober.sh              install
#     bash install-sober.sh --uninstall  remove it (keeps your data)
#     bash install-sober.sh --purge      remove it and delete its data
#
# Sober is unofficial, experimental, closed-source and not supported by Roblox.
# It may stop working or be discontinued at any time. Use at your own risk.

set -Eeuo pipefail
if [[ -t 1 ]]; then G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; C=$'\e[36m'; N=$'\e[0m'; else G=""; Y=""; R=""; C=""; N=""; fi
info() { printf '%s[*]%s %s\n' "$C" "$N" "$*"; }
ok()   { printf '%s[+]%s %s\n' "$G" "$N" "$*"; }
warn() { printf '%s[!]%s %s\n' "$Y" "$N" "$*" >&2; }
die()  { printf '%s[x]%s %s\n' "$R" "$N" "$*" >&2; exit 1; }
trap 'printf "%s[x]%s Failed at line %s: %s\n" "$R" "$N" "$LINENO" "$BASH_COMMAND" >&2' ERR

APP=org.vinegarhq.Sober

[[ $EUID -ne 0 ]] || die "Run this as your normal user, not root."
command -v flatpak >/dev/null 2>&1 || die "Flatpak not found. Run setup-flatpak.sh first."

case "${1:-}" in
    --uninstall) flatpak uninstall --user -y "$APP"; ok "Sober removed (data kept)."; exit 0 ;;
    --purge)     flatpak uninstall --user -y --delete-data "$APP"; ok "Sober and its data removed."; exit 0 ;;
    "") ;;
    *) die "Unknown option: $1" ;;
esac

# Requirements published by the Sober project: x86-64 only, Linux 5.11+, SSE4.2 recommended.
[[ $(uname -m) == x86_64 ]] || die "Sober supports x86-64 only (no ARM)."
kernel=$(uname -r | cut -d- -f1)
[[ $(printf '%s\n5.11\n' "$kernel" | sort -V | head -n1) == 5.11 ]] \
    || die "Kernel $kernel is too old. Sober needs Linux 5.11 or newer."
if ! grep -qw sse4_2 /proc/cpuinfo; then
    if grep -qw sse4_1 /proc/cpuinfo; then
        warn "Your CPU has SSE4.1 but not SSE4.2. Sober will run through emulation and be slow."
    else
        die "Your CPU lacks SSE4.1, which Sober needs."
    fi
fi

if ! flatpak remotes --user --columns=name | grep -qx flathub; then
    flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
fi

info "Installing Sober from Flathub..."
flatpak install --user --noninteractive flathub "$APP"

ok "Sober installed."
echo "Start it from your app menu, or:  flatpak run $APP"
echo "On first launch it offers to download and install Roblox; accept the automatic install."
echo "Problems? See gentoo-guides/guides/05-roblox-sober-and-vinegar.md"
