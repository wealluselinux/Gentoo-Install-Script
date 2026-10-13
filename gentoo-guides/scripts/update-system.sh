#!/usr/bin/env bash
#
# update-system.sh - the Gentoo equivalent of "pacman -Syu".
# Part of Gentoo-Install-Script / gentoo-guides (MIT).
#
# Run as your normal user (uses sudo) or as root.
#     bash update-system.sh
#
# Steps: sync the Portage tree, update every installed package, remove packages
# nothing needs any more, then remind you about config file updates.
# Each emerge shows you what it will do and asks before it starts.

set -Eeuo pipefail
if [[ -t 1 ]]; then G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; C=$'\e[36m'; N=$'\e[0m'; else G=""; Y=""; R=""; C=""; N=""; fi
info() { printf '%s[*]%s %s\n' "$C" "$N" "$*"; }
ok()   { printf '%s[+]%s %s\n' "$G" "$N" "$*"; }
warn() { printf '%s[!]%s %s\n' "$Y" "$N" "$*" >&2; }
die()  { printf '%s[x]%s %s\n' "$R" "$N" "$*" >&2; exit 1; }
trap 'printf "%s[x]%s Failed at line %s: %s\n" "$R" "$N" "$LINENO" "$BASH_COMMAND" >&2' ERR
as_root() { if [[ $EUID -eq 0 ]]; then "$@"; else sudo "$@"; fi; }
confirm() { local a; read -r -p "$1 [y/N]: " a || true; [[ $a =~ ^[Yy]$ ]]; }

[[ $EUID -eq 0 ]] || command -v sudo >/dev/null 2>&1 || die "sudo not found. As root, run: emerge app-admin/sudo"

info "1/3  Syncing the Portage tree..."
if ! as_root emerge --sync; then
    warn "emerge --sync failed; trying emerge-webrsync (works over HTTPS snapshots)."
    as_root emerge-webrsync
fi

info "2/3  Updating all installed packages..."
as_root emerge --ask --verbose --update --deep --newuse @world

if confirm "3/3  Remove packages nothing depends on any more (emerge --depclean)?"; then
    as_root emerge --ask --depclean
fi

if command -v flatpak >/dev/null 2>&1 && [[ $EUID -ne 0 ]]; then
    if confirm "Also update your Flatpak apps?"; then flatpak update --user; fi
fi

ok "Update finished."
echo "If emerge said config files need updating, run:  sudo dispatch-conf"
echo "If a kernel was updated, reboot when convenient."
