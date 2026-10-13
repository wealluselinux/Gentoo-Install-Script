#!/usr/bin/env bash
#
# setup-overlays.sh - set up eselect-repository and (optionally) enable the GURU overlay.
# GURU is Gentoo's community repository, the closest thing to Arch's AUR.
# Part of Gentoo-Install-Script / gentoo-guides (MIT).
#
# Run as your normal user (uses sudo) or as root.
#     bash setup-overlays.sh

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

info "Installing eselect-repository and git (needed to sync overlays)..."
as_root emerge --ask --verbose --noreplace app-eselect/eselect-repository dev-vcs/git

echo
warn "GURU packages are written by community volunteers. They are NOT reviewed by Gentoo developers."
warn "Only enable it if you need something that is not in the main tree."
if confirm "Enable the GURU overlay now?"; then
    as_root eselect repository enable guru
    as_root emaint sync --repo guru
    ok "GURU enabled. Search it with:  emerge --search <name>   (or install eix and run eix-update)"
else
    info "Skipped. Later, run:  sudo eselect repository enable guru && sudo emaint sync --repo guru"
fi

echo
info "Other overlays:  eselect repository list -i     (list ones you already have)"
info "                 eselect repository list         (everything available)"
info "                 sudo eselect repository enable <name>"
