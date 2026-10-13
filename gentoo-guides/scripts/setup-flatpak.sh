#!/usr/bin/env bash
#
# setup-flatpak.sh - install Flatpak and add the Flathub store on Gentoo.
# Part of Gentoo-Install-Script / gentoo-guides (MIT).
#
# Run as your NORMAL user (not root). It uses sudo only for the emerge step.
#     bash setup-flatpak.sh

set -Eeuo pipefail
if [[ -t 1 ]]; then G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; C=$'\e[36m'; N=$'\e[0m'; else G=""; Y=""; R=""; C=""; N=""; fi
info() { printf '%s[*]%s %s\n' "$C" "$N" "$*"; }
ok()   { printf '%s[+]%s %s\n' "$G" "$N" "$*"; }
warn() { printf '%s[!]%s %s\n' "$Y" "$N" "$*" >&2; }
die()  { printf '%s[x]%s %s\n' "$R" "$N" "$*" >&2; exit 1; }
trap 'printf "%s[x]%s Failed at line %s: %s\n" "$R" "$N" "$LINENO" "$BASH_COMMAND" >&2' ERR
as_root() { if [[ $EUID -eq 0 ]]; then "$@"; else sudo "$@"; fi; }
confirm() { local a; read -r -p "$1 [y/N]: " a || true; [[ $a =~ ^[Yy]$ ]]; }

[[ $EUID -ne 0 ]] || die "Run this as your normal user, not root (Flatpak apps install per user)."
command -v sudo >/dev/null 2>&1 || die "sudo not found. As root, run: emerge app-admin/sudo"

if command -v flatpak >/dev/null 2>&1; then
    ok "Flatpak is already installed."
else
    info "Installing sys-apps/flatpak (you will see the package list first)..."
    as_root emerge --ask --verbose sys-apps/flatpak
fi

# Flatpak sandboxes apps with bubblewrap, which needs user namespaces in the kernel.
if ! unshare --user true 2>/dev/null; then
    warn "User namespaces look disabled. The Gentoo binary kernel has them on; a custom kernel needs CONFIG_USER_NS=y."
fi

if confirm "Also install xdg-desktop-portal-gtk (fixes missing file dialogs / fonts in some desktops)?"; then
    as_root emerge --ask --verbose sys-apps/xdg-desktop-portal-gtk
fi

info "Adding the Flathub remote for your user..."
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
ok "Flathub added."

echo
ok "Flatpak is ready."
echo "Log out and back in (or reboot) once so app launchers pick up Flatpak apps."
echo "Then try:  flatpak install --user flathub org.mozilla.firefox"
echo "Or run:    bash install-flatpak-apps.sh   (pick apps from a menu)"
