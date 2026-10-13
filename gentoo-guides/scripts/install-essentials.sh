#!/usr/bin/env bash
#
# install-essentials.sh - handy tools most people want on a fresh Gentoo install.
# Part of Gentoo-Install-Script / gentoo-guides (MIT).
#
# Run as your normal user (uses sudo) or as root.
#     bash install-essentials.sh
#
# Installs:
#   app-portage/gentoolkit   equery, eclean, revdep-rebuild (query and clean Portage)
#   app-portage/eix          very fast package search
#   dev-vcs/git              needed for overlays and cloning projects
#   sys-process/htop         process viewer
#   app-misc/fastfetch       system info (for the screenshots)
#   app-shells/bash-completion  tab completion for emerge and friends

set -Eeuo pipefail
if [[ -t 1 ]]; then G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; C=$'\e[36m'; N=$'\e[0m'; else G=""; Y=""; R=""; C=""; N=""; fi
info() { printf '%s[*]%s %s\n' "$C" "$N" "$*"; }
ok()   { printf '%s[+]%s %s\n' "$G" "$N" "$*"; }
warn() { printf '%s[!]%s %s\n' "$Y" "$N" "$*" >&2; }
die()  { printf '%s[x]%s %s\n' "$R" "$N" "$*" >&2; exit 1; }
trap 'printf "%s[x]%s Failed at line %s: %s\n" "$R" "$N" "$LINENO" "$BASH_COMMAND" >&2' ERR
as_root() { if [[ $EUID -eq 0 ]]; then "$@"; else sudo "$@"; fi; }

[[ $EUID -eq 0 ]] || command -v sudo >/dev/null 2>&1 || die "sudo not found. As root, run: emerge app-admin/sudo"

PKGS=(
    app-portage/gentoolkit
    app-portage/eix
    dev-vcs/git
    sys-process/htop
    app-misc/fastfetch
    app-shells/bash-completion
)

info "Installing: ${PKGS[*]}"
as_root emerge --ask --verbose --noreplace "${PKGS[@]}"

info "Building the eix search database..."
as_root eix-update || warn "eix-update failed; run it manually later."

ok "Done. Try:  eix firefox     equery list '*' | less     fastfetch"
