#!/usr/bin/env bash
#
# setup-binpkgs.sh - make emerge use Gentoo's official binary packages (much faster installs).
# Part of Gentoo-Install-Script / gentoo-guides (MIT).
#
# Run as your normal user (uses sudo) or as root.  amd64 only.
#     bash setup-binpkgs.sh
#
# What it changes:
#   /etc/portage/binrepos.conf/gentoobinhost.conf   (only created if missing)
#   /etc/portage/make.conf   gets two lines appended (only if not already there):
#       FEATURES="${FEATURES} binpkg-request-signature"
#       EMERGE_DEFAULT_OPTS="${EMERGE_DEFAULT_OPTS} --getbinpkg"
# emerge then downloads a binary when one exists and compiles from source otherwise.
# To undo it, delete those two lines from make.conf.

set -Eeuo pipefail
if [[ -t 1 ]]; then G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; C=$'\e[36m'; N=$'\e[0m'; else G=""; Y=""; R=""; C=""; N=""; fi
info() { printf '%s[*]%s %s\n' "$C" "$N" "$*"; }
ok()   { printf '%s[+]%s %s\n' "$G" "$N" "$*"; }
warn() { printf '%s[!]%s %s\n' "$Y" "$N" "$*" >&2; }
die()  { printf '%s[x]%s %s\n' "$R" "$N" "$*" >&2; exit 1; }
trap 'printf "%s[x]%s Failed at line %s: %s\n" "$R" "$N" "$LINENO" "$BASH_COMMAND" >&2' ERR
as_root() { if [[ $EUID -eq 0 ]]; then "$@"; else sudo "$@"; fi; }

[[ $(uname -m) == x86_64 ]] || die "This script only supports amd64 (x86_64)."
[[ $EUID -eq 0 ]] || command -v sudo >/dev/null 2>&1 || die "sudo not found. As root, run: emerge app-admin/sudo"
[[ -f /etc/portage/make.conf ]] || die "/etc/portage/make.conf not found. Is this a Gentoo system?"

BINREPO=/etc/portage/binrepos.conf/gentoobinhost.conf
if [[ -e $BINREPO ]]; then
    ok "Binary host config already exists ($BINREPO); leaving it alone."
else
    info "Creating $BINREPO ..."
    as_root mkdir -p /etc/portage/binrepos.conf
    printf '[gentoobinhost]\npriority = 9999\nsync-uri = https://distfiles.gentoo.org/releases/amd64/binpackages/23.0/x86-64/\n' \
        | as_root tee "$BINREPO" >/dev/null
fi

MC=/etc/portage/make.conf
if grep -q 'binpkg-request-signature' "$MC"; then
    ok "make.conf already requests signature checks."
else
    printf '\n# Added by setup-binpkgs.sh\nFEATURES="${FEATURES} binpkg-request-signature"\n' | as_root tee -a "$MC" >/dev/null
fi
if grep -Eq '^EMERGE_DEFAULT_OPTS=.*--getbinpkg' "$MC"; then
    ok "make.conf already passes --getbinpkg."
else
    printf 'EMERGE_DEFAULT_OPTS="${EMERGE_DEFAULT_OPTS} --getbinpkg"\n' | as_root tee -a "$MC" >/dev/null
fi

info "Setting up Portage's binary package signing keys (getuto)..."
as_root getuto || warn "getuto failed; emerge will retry it when it first downloads a binary."

if grep -Eq '^COMMON_FLAGS=.*-march=native' "$MC"; then
    warn "Your COMMON_FLAGS use -march=native. Official binaries are built for generic x86-64 CPUs, which is fine, but packages you compile yourself will still be tuned to this CPU."
fi

ok "Done. Try:  sudo emerge --ask --verbose <package>   (you should see binary packages marked [binary])"
