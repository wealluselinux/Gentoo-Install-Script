# Gentoo Guides

Beginner-friendly guides and helper scripts for your first days on Gentoo, meant to be used after the main [Gentoo installation script](../README.md) has done its job.

Gentoo is powerful but has a learning curve. These guides cover the things people trip over first: updating the system, getting apps you used on Arch or Ubuntu, using Flatpak, enabling community overlays, and getting finicky apps (like Sober and Vinegar) running.

> The scripts ask before they change anything big (`emerge --ask` shows the package list first). Read a script before you run it. They are short on purpose.

## Guides

| Guide | What's in it |
|---|---|
| [01 Installing Gentoo](guides/01-installing-gentoo.md) | Using the installer script, and where to go for a manual install |
| [02 First steps after install](guides/02-first-steps-after-install.md) | Network, updates, how Portage works, services on OpenRC vs systemd |
| [03 Arch to Gentoo](guides/03-arch-to-gentoo.md) | `pacman`/AUR cheat sheet and how to get your usual apps back |
| [04 Flatpak and apps](guides/04-flatpak-and-apps.md) | Flatpak, Flathub, overlays (GURU) and binary packages |
| [05 Roblox: Sober and Vinegar](guides/05-roblox-sober-and-vinegar.md) | Installing and troubleshooting both on Gentoo |
| [06 Troubleshooting](guides/06-troubleshooting.md) | Common Portage errors, audio, graphics, and where to ask for help |

## Scripts

Scripts live in [`scripts/`](scripts/). Run them as your **normal user** unless noted. They call `sudo` themselves when needed.

| Script | What it does |
|---|---|
| `update-system.sh` | The `pacman -Syu` equivalent: sync, update everything, clean up |
| `install-essentials.sh` | gentoolkit, eix, git, htop, fastfetch, bash-completion |
| `setup-binpkgs.sh` | Use Gentoo's official binary packages for much faster installs |
| `setup-flatpak.sh` | Install Flatpak and add Flathub |
| `install-flatpak-apps.sh` | Menu of popular apps (Firefox, Discord, Steam, OBS, ...) from Flathub |
| `setup-overlays.sh` | Install `eselect-repository` and optionally enable GURU (Gentoo's AUR-like repo) |
| `install-sober.sh` | Sober (unofficial Roblox player) via Flatpak, with requirement checks |
| `install-vinegar.sh` | Vinegar (Roblox Studio on Linux) via Flatpak |

### Running one script

```bash
wget https://raw.githubusercontent.com/wealluselinux/Gentoo-Install-Script/main/gentoo-guides/scripts/update-system.sh
bash update-system.sh
```

Or clone the whole repository and run them from there:

```bash
git clone https://github.com/wealluselinux/Gentoo-Install-Script
cd Gentoo-Install-Script/gentoo-guides/scripts
bash setup-flatpak.sh
```

(Install git first with `sudo emerge --ask dev-vcs/git` if you don't have it.)

### Good order for a fresh install

1. `update-system.sh`
2. `setup-binpkgs.sh` (optional, big time saver)
3. `install-essentials.sh`
4. `setup-flatpak.sh`, then `install-flatpak-apps.sh`
5. `setup-overlays.sh` (only if you need something from GURU)

## Status

These scripts follow the Gentoo wiki, Flathub and the Sober/Vinegar projects' own documentation, but they are community-made and have had limited testing. If one breaks on your setup, open an issue with the error output.

## Contributing

New guide ideas welcome: Steam, NVIDIA drivers, Bluetooth, printing, dual boot, Wayland tips. Keep scripts small, readable, and ask before doing anything destructive.
