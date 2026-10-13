#!/usr/bin/env bash
#
# install-flatpak-apps.sh - pick popular apps from a menu and install them from Flathub.
# Part of Gentoo-Install-Script / gentoo-guides (MIT).
#
# Run as your NORMAL user. Needs Flatpak (see setup-flatpak.sh).
#     bash install-flatpak-apps.sh

set -Eeuo pipefail
if [[ -t 1 ]]; then G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; C=$'\e[36m'; N=$'\e[0m'; else G=""; Y=""; R=""; C=""; N=""; fi
info() { printf '%s[*]%s %s\n' "$C" "$N" "$*"; }
ok()   { printf '%s[+]%s %s\n' "$G" "$N" "$*"; }
warn() { printf '%s[!]%s %s\n' "$Y" "$N" "$*" >&2; }
die()  { printf '%s[x]%s %s\n' "$R" "$N" "$*" >&2; exit 1; }
trap 'printf "%s[x]%s Failed at line %s: %s\n" "$R" "$N" "$LINENO" "$BASH_COMMAND" >&2' ERR

[[ $EUID -ne 0 ]] || die "Run this as your normal user, not root."
command -v flatpak >/dev/null 2>&1 || die "Flatpak not found. Run setup-flatpak.sh first."

if ! flatpak remotes --user --columns=name | grep -qx flathub; then
    info "Adding the Flathub remote..."
    flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
fi

# "Name|Flathub app ID"
APPS=(
    "Firefox (browser)|org.mozilla.firefox"
    "Discord|com.discordapp.Discord"
    "Spotify|com.spotify.Client"
    "Steam|com.valvesoftware.Steam"
    "VLC (video player)|org.videolan.VLC"
    "OBS Studio (recording/streaming)|com.obsproject.Studio"
    "Bottles (run Windows apps)|com.usebottles.bottles"
    "Heroic (Epic/GOG games)|com.heroicgameslauncher.hgl"
    "Flatseal (manage Flatpak permissions)|com.github.tchx84.Flatseal"
    "LibreOffice|org.libreoffice.LibreOffice"
    "GIMP (image editor)|org.gimp.GIMP"
    "Visual Studio Code|com.visualstudio.code"
    "Telegram|org.telegram.desktop"
    "Sober (Roblox player, unofficial)|org.vinegarhq.Sober"
    "Vinegar (Roblox Studio on Linux, unofficial)|org.vinegarhq.Vinegar"
)

echo
echo "Apps available:"
for i in "${!APPS[@]}"; do printf '  %2d) %s\n' $((i + 1)) "${APPS[$i]%%|*}"; done
echo
read -r -p "Numbers to install, separated by spaces (e.g. 1 2 4), or q to quit: " sel || true
[[ -n $sel && $sel != q ]] || { info "Nothing selected."; exit 0; }

ids=()
for n in $sel; do
    [[ $n =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#APPS[@]} )) || die "Invalid choice: $n"
    ids+=("${APPS[n-1]##*|}")
done

info "Installing: ${ids[*]}"
flatpak install --user --noninteractive flathub "${ids[@]}"
ok "Done. Launch them from your app menu, or with:  flatpak run <app-id>"
