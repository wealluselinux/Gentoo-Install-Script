#!/usr/bin/env bash
#
# Gentoo End-4 / illogical-impulse bootstrap (experimental)
# Repository: https://github.com/wealluselinux/Gentoo-Install-Script
# Upstream dotfiles: https://github.com/end-4/dots-hyprland
#
# This helper does NOT repartition disks or install Gentoo. Run it only after
# booting into your installed Gentoo system as a normal user with sudo access.
# End-4's upstream setup is not a native Gentoo installer; this script does
# not pretend that running the upstream setup on Gentoo is fully supported.
#
# License: MIT

set -Eeuo pipefail

readonly UPSTREAM_URL="https://github.com/end-4/dots-hyprland.git"
readonly DOTS_DIR="${HOME}/.local/src/dots-hyprland"

say()  { printf '\033[1;36m[*]\033[0m %s\n' "$*"; }
good() { printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

if [[ $EUID -eq 0 ]]; then
    die "Do not run this as root. Run it as your regular desktop user."
fi

[[ -r /etc/gentoo-release ]] || die "This helper is intended for an installed Gentoo Linux system."
command -v emerge >/dev/null 2>&1 || die "Portage (emerge) was not found."
command -v sudo >/dev/null 2>&1 || die "Install and configure sudo first, then rerun this helper."
command -v git >/dev/null 2>&1 || die "Install git first: sudo emerge --ask dev-vcs/git"

printf '\n'
printf 'Gentoo + End-4 dots bootstrap (EXPERIMENTAL)\n'
printf '%s\n' '-------------------------------------------'
warn "This helper does not erase disks or reinstall Gentoo."
warn "End-4/illogical-impulse may depend on Arch-specific packages and instructions."
warn "Gentoo package availability varies by profile, repository sync, and overlays."
printf '\n'
read -r -p "Continue and prepare the upstream dotfiles checkout? [y/N] " answer
[[ $answer == [yY] || $answer == [yY][eE][sS] ]] || { say "Cancelled."; exit 0; }

say "Checking for an existing dotfiles checkout..."
if [[ -e $DOTS_DIR ]]; then
    if [[ -d $DOTS_DIR/.git ]]; then
        warn "A Git checkout already exists at $DOTS_DIR"
        read -r -p "Update it with git pull? [y/N] " update_answer
        if [[ $update_answer == [yY] || $update_answer == [yY][eE][sS] ]]; then
            git -C "$DOTS_DIR" pull --ff-only
        fi
    else
        die "$DOTS_DIR exists but is not a Git checkout. Move it aside and rerun."
    fi
else
    mkdir -p "$(dirname "$DOTS_DIR")"
    say "Cloning the official End-4 repository..."
    git clone --depth 1 "$UPSTREAM_URL" "$DOTS_DIR"
fi

good "Upstream repository is available at: $DOTS_DIR"
printf '\n'
printf '%s\n' "Next steps:"
printf '  1. Read the upstream Gentoo/distribution notes: https://ii.clsty.link\n'
printf '  2. Review the upstream setup and package scripts before running anything.\n'
printf '  3. Check Gentoo ebuild/overlay availability for each required dependency.\n'
printf '  4. Back up ~/.config before copying or replacing any configuration.\n'
printf '\n'
warn "This bootstrap intentionally does not run './setup install': upstream setup"
warn "contains distribution-specific package and setup logic and is not confirmed"
warn "to work on Gentoo. Do not run it until its Gentoo compatibility is verified."
printf '\n'
say "Finished. No system packages were installed and existing dotfiles were not overwritten."
