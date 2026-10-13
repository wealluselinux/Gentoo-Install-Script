# 03. Arch to Gentoo

Coming from Arch? You already know most of the Linux side. The main change is that Gentoo's package manager builds from source by default (or fetches binaries if you enable them), and configuration is done through USE flags.

## Command cheat sheet

| Arch (`pacman`) | Gentoo (`emerge`) |
|---|---|
| `pacman -Syu` | `sudo emerge --sync` then `sudo emerge -avuDN @world` (or run `update-system.sh`) |
| `pacman -S pkg` | `sudo emerge -av pkg` |
| `pacman -Ss word` | `emerge -s word` (or `eix word`) |
| `pacman -Rns pkg` | `sudo emerge --deselect pkg` then `sudo emerge -a --depclean` |
| `pacman -Qs` / `-Q` | `equery list '*'` or `qlist -I` (gentoolkit) |
| `pacman -Qo /path` | `equery belongs /path` |
| `pacman -Ql pkg` | `equery files pkg` |
| `pacman -Qi pkg` | `equery meta pkg` / `emerge -pv pkg` |
| `paccache -r` | `sudo eclean-dist` (cleans old source files) |
| `/etc/pacman.conf` | `/etc/portage/make.conf` and `/etc/portage/repos.conf/` |
| `PKGBUILD` | `.ebuild` |
| AUR | Overlays: GURU (`setup-overlays.sh`), or Flatpak |
| `systemctl enable x` | `rc-update add x default` on OpenRC (same as Arch on systemd) |

Flags to remember: `-a` (`--ask`), `-v` (`--verbose`), `-u` (`--update`), `-D` (`--deep`), `-N` (`--newuse`), `-p` (`--pretend`, show only).

## Getting your usual apps back

There is almost always an option, usually one of these:

1. **The main Gentoo tree.** Check first with `eix <name>` or `emerge -s <name>`.
2. **A `-bin` package** in the main tree (prebuilt binary, no long compile), for example `www-client/firefox-bin`.
3. **Flatpak** from Flathub. The simplest route for Discord, Spotify, Steam, OBS and many more. See [04](04-flatpak-and-apps.md) or run `install-flatpak-apps.sh`.
4. **An overlay** such as GURU, the closest thing to the AUR.

Common apps (verify the exact atom with `eix` since package names can change):

| App | Easiest option on Gentoo |
|---|---|
| Firefox | `www-client/firefox-bin` (fast) or `www-client/firefox` (compiles) |
| Chrome / Chromium | `www-client/google-chrome` or Flatpak |
| Discord | Flatpak `com.discordapp.Discord` |
| Spotify | Flatpak `com.spotify.Client` |
| Steam | Flatpak `com.valvesoftware.Steam` (simplest). Native Steam lives in the `steam-overlay` repository. |
| VS Code | Flatpak `com.visualstudio.code` |
| OBS Studio | `media-video/obs-studio` or Flatpak |
| VLC | `media-video/vlc` |
| Telegram | `net-im/telegram-desktop` or Flatpak |
| Neovim | `app-editors/neovim` |
| fastfetch | `app-misc/fastfetch` |

For software with no ebuild, you can often build from source in your home directory, use a Flatpak or an AppImage, or write a small ebuild yourself. Writing ebuilds is a great skill to learn eventually, and the [Gentoo Handbook and Devmanual](https://devmanual.gentoo.org/) explain how.

## Mindset differences

- **USE flags replace "optional dependencies".** If a program lacks a feature, there is probably a USE flag for it. See `emerge -pv pkg` to find out what is enabled.
- **Do not "pacman -Sy" half-update.** Always update `@world` as one step.
- **Compile times are real.** Use binary packages (`setup-binpkgs.sh`) for big things like browsers and desktops.
- **Read the elog messages** emerge prints at the end of an install. They often tell you what to do next (add a user to a group, enable a service).
