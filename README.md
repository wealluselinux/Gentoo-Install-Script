# Gentoo Installation Script

An **unofficial**, open-source, interactive installer for [Gentoo Linux](https://www.gentoo.org/), in the spirit of `archinstall`.

You answer a few questions (disk type, desktop environment, language, and so on). The script then partitions the disk, downloads the official stage3 tarball, verifies it, and installs a bootable Gentoo system.

> **WARNING:** The script **erases the entire disk** you select. Back up your data first, and test in a virtual machine before using real hardware.
> This is an early version (v0.2.3). It is not affiliated with or endorsed by the Gentoo Foundation.

## What it asks you

| Question | Options |
|---|---|
| Disk type | NVMe, SATA/SAS/USB, eMMC/SD (MMC), VirtIO, or everything |
| Disk | Pick from a list of matching disks |
| Init system | OpenRC or systemd |
| Desktop | None, KDE Plasma, GNOME, XFCE, LXQt, MATE, Cinnamon, LXDE, i3, Sway, Openbox |
| Language / locale | en_US, en_GB, de_DE, fr_FR, es_ES, pt_BR, it_IT, ru_RU, ja_JP, zh_CN, or your own |
| Keyboard, timezone, hostname | Free input, with validation |
| User account and passwords | Regular user (in `wheel`, with sudo) plus root |
| Root filesystem | ext4, btrfs, xfs |
| Swap | Size in GiB (0 = none) |
| Kernel | Gentoo binary kernel (fast) or distribution kernel compiled from source |
| Packages | Official Gentoo binary packages (fast) or compile everything from source |

## What it does

1. Detects UEFI or BIOS boot mode and checks your network.
2. Creates a GPT partition table (ESP or BIOS-boot partition, optional swap, root).
3. Formats and mounts the partitions at `/mnt/gentoo`.
4. Downloads the latest stage3 from `distfiles.gentoo.org` and verifies its SHA256 and, when possible, its GPG signature.
5. Configures Portage (`make.conf`, profile, optional binary package host).
6. Enters a chroot and sets up timezone, locale, keyboard, hostname and `fstab`.
7. Installs the firmware, kernel (with dracut initramfs) and GRUB.
8. Installs NetworkManager, plus the desktop environment and display manager if you chose one.
9. Enables the services, creates your user, sets the passwords, unmounts and offers to reboot.

### Disk layout

| Boot mode | Partition 1 | Swap (optional) | Root |
|---|---|---|---|
| UEFI | 512 MiB EFI System Partition (FAT32, mounted at `/efi`) | yes | rest of the disk |
| BIOS | 1 MiB BIOS boot partition (GPT + GRUB) | yes | rest of the disk |

## Requirements

- An x86_64 (amd64) machine, at least 20 GiB of disk (40 GiB or more recommended with a desktop), and 2 GiB of RAM or more.
- A working internet connection during the install.
- Root access in a live environment. The [Gentoo minimal install ISO](https://www.gentoo.org/downloads/) is the intended one. Any live Linux with `bash`, `sfdisk`, `tar`, `xz`, `chroot` and `curl` or `wget` should also work.

## How to run it

### Option A: Live Gentoo USB, then download the script

1. Write the Gentoo minimal ISO to a USB drive and boot from it.
2. Get online. A wired connection usually works automatically. For Wi-Fi, follow the networking section of the [Gentoo Handbook](https://wiki.gentoo.org/wiki/Handbook:AMD64).
3. Become root and fetch the script:

   ```bash
   wget https://raw.githubusercontent.com/wealluselinux/Gentoo-Install-Script/main/gentoo-installation-script.sh
   chmod +x gentoo-installation-script.sh
   ```

4. Run it:

   ```bash
   ./gentoo-installation-script.sh
   ```

### Option B: Put the script on a USB drive

1. Download `gentoo-installation-script.sh` from this repository onto a second USB stick (or onto the same stick, in a separate partition or folder).
2. Boot the live Gentoo USB, plug in the stick with the script and find it with `lsblk`.
3. Mount it and run the script:

   ```bash
   mkdir -p /mnt/usb
   mount /dev/sdX1 /mnt/usb        # replace sdX1 with your USB partition
   bash /mnt/usb/gentoo-installation-script.sh
   ```

   Do not select that USB stick as the install target. The script labels disks that have mounted partitions.

### Then

Follow the prompts, read the summary carefully, and type `YES` to start. When it finishes, remove the USB drive and reboot.

## After the install: Gentoo Guides

New to Gentoo? The [`gentoo-guides/`](gentoo-guides/) folder has beginner guides and helper scripts for your first days:

- Updating the system (the `pacman -Syu` equivalent) and installing handy tools
- An Arch-to-Gentoo cheat sheet for getting your usual apps back
- Flatpak and Flathub, the GURU overlay (Gentoo's AUR-like repo), and binary packages
- Installing and troubleshooting Sober and Vinegar (Roblox on Linux)
- A troubleshooting guide for common Portage errors

Start with the [Gentoo Guides index](gentoo-guides/README.md).

## End-4 / illogical-impulse Hyprland dots (experimental)

The original `gentoo-end4-dots-installer.sh` and init-specific variants in `useful scripts/OpenRC/` and `useful scripts/Systemd/` are experimental post-install bootstrap helpers for preparing the official [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) checkout on an installed Gentoo system.

**Important:** these scripts only clone/update the upstream repository. They do not install the desktop, overwrite your configuration, or run upstream setup. End-4's upstream setup contains distribution-specific package logic and is not confirmed to work on Gentoo. The OpenRC/systemd variants check that the matching init tools are present; they do not yet perform a complete Gentoo-native dotfiles installation.

Run the matching script as your regular desktop user, not root. Back up `~/.config` before later attempting any dotfile installation.

## Useful post-install scripts: OpenRC and systemd

The `useful scripts/` folder is split by init system:

- [OpenRC scripts](https://github.com/wealluselinux/Gentoo-Install-Script/tree/main/useful%20scripts/OpenRC)
- [systemd scripts](https://github.com/wealluselinux/Gentoo-Install-Script/tree/main/useful%20scripts/Systemd)

Each folder currently contains:
- An End-4 dots bootstrap helper that checks for the matching init system and clones/updates the upstream repository only.
- A desktop setup helper that offers to install PipeWire, WirePlumber, ALSA support, NetworkManager, and D-Bus through Portage, then enables NetworkManager and D-Bus using the matching init system.

### Run the desktop setup helper

For OpenRC:

```bash
wget -O gentoo-desktop-setup-openrc.sh "https://raw.githubusercontent.com/wealluselinux/Gentoo-Install-Script/main/useful%20scripts/OpenRC/gentoo-desktop-setup-openrc.sh"
chmod +x gentoo-desktop-setup-openrc.sh
./gentoo-desktop-setup-openrc.sh
```

For systemd:

```bash
wget -O gentoo-desktop-setup-systemd.sh "https://raw.githubusercontent.com/wealluselinux/Gentoo-Install-Script/main/useful%20scripts/Systemd/gentoo-desktop-setup-systemd.sh"
chmod +x gentoo-desktop-setup-systemd.sh
./gentoo-desktop-setup-systemd.sh
```

These helpers run as your regular user and use `sudo` for privileged commands. Portage will show a confirmation before installing packages. They enable NetworkManager for Wi-Fi/network management and offer an optional per-connection DNS override (IPv4 defaults to Cloudflare and Quad9; IPv6 is optional). DNS settings are not changed unless you opt in.

**Limits:** PipeWire is primarily a per-user audio service and may need desktop-session integration or user-level service configuration; these scripts install the packages but do not guarantee every desktop session starts audio automatically. Wi-Fi still requires a supported adapter, kernel driver, and firmware. Changing DNS cannot fix a missing driver or broken Wi-Fi link. Review the script before running it, and test in a VM where practical.

## Useful apps installer (both init systems)

The [`useful scripts/Both Init Systems/`](https://github.com/wealluselinux/Gentoo-Install-Script/tree/main/useful%20scripts/Both%20Init%20Systems) folder contains an init-independent starter-app installer:

- [`gentoo-useful-apps-installer.sh`](https://github.com/wealluselinux/Gentoo-Install-Script/blob/main/useful%20scripts/Both%20Init%20Systems/gentoo-useful-apps-installer.sh)
- Installs Fastfetch, Flatpak, Git, curl, wget, nano, htop, tree, zip, and unzip through Portage.
- Optionally adds the official Flathub remote for your user account.
- Works with either OpenRC or systemd and does not enable or change init services.

Run it as your regular user:

```bash
wget -O gentoo-useful-apps-installer.sh "https://raw.githubusercontent.com/wealluselinux/Gentoo-Install-Script/main/useful%20scripts/Both%20Init%20Systems/gentoo-useful-apps-installer.sh"
chmod +x gentoo-useful-apps-installer.sh
./gentoo-useful-apps-installer.sh
```

The script asks before proceeding, and Portage displays its package plan before installing. The Flathub remote is also optional. Gentoo package availability can depend on your profile, repository sync, architecture, and keyword settings; review Portage messages instead of forcing masked packages.

## Post-install toolkit: diagnostics, maintenance, gaming, and desktops

The [Both Init Systems folder](https://github.com/wealluselinux/Gentoo-Install-Script/tree/main/useful%20scripts/Both%20Init%20Systems) contains scripts that do not need to enable or manage init-specific services:

- [`gentoo-installer-menu.sh`](https://github.com/wealluselinux/Gentoo-Install-Script/blob/main/useful%20scripts/Both%20Init%20Systems/gentoo-installer-menu.sh) — menu launcher for the post-install toolkit. It detects OpenRC/systemd for init-specific choices when possible.
- [`gentoo-system-info.sh`](https://github.com/wealluselinux/Gentoo-Install-Script/blob/main/useful%20scripts/Both%20Init%20Systems/gentoo-system-info.sh) — read-only system and hardware summary.
- [`gentoo-network-diagnostics.sh`](https://github.com/wealluselinux/Gentoo-Install-Script/blob/main/useful%20scripts/Both%20Init%20Systems/gentoo-network-diagnostics.sh) — read-only interface, route, DNS, and HTTPS checks.
- [`gentoo-maintenance-helper.sh`](https://github.com/wealluselinux/Gentoo-Install-Script/blob/main/useful%20scripts/Both%20Init%20Systems/gentoo-maintenance-helper.sh) — repository sync, Portage update, configuration-update review, and disk-space menu.
- [`gentoo-gaming-tools-installer.sh`](https://github.com/wealluselinux/Gentoo-Install-Script/blob/main/useful%20scripts/Both%20Init%20Systems/gentoo-gaming-tools-installer.sh) — optional Vulkan/graphics diagnostic tools; it does not configure GPU drivers, multilib, Steam, or third-party overlays.
- [`gentoo-developer-tools-installer.sh`](https://github.com/wealluselinux/Gentoo-Install-Script/blob/main/useful%20scripts/Both%20Init%20Systems/gentoo-developer-tools-installer.sh) — optional Git, Python, CMake, GCC, GDB, and Vim packages.
- [`gentoo-useful-apps-installer.sh`](https://github.com/wealluselinux/Gentoo-Install-Script/blob/main/useful%20scripts/Both%20Init%20Systems/gentoo-useful-apps-installer.sh) — basic apps including Fastfetch and Flatpak.

Desktop installation is init-specific, so the chooser scripts are kept separate:

- [OpenRC desktop chooser](https://github.com/wealluselinux/Gentoo-Install-Script/blob/main/useful%20scripts/OpenRC/gentoo-desktop-chooser-openrc.sh) — KDE Plasma, XFCE, or Hyprland. It prints OpenRC display-manager follow-up guidance instead of automatically changing service configuration.
- [systemd desktop chooser](https://github.com/wealluselinux/Gentoo-Install-Script/blob/main/useful%20scripts/Systemd/gentoo-desktop-chooser-systemd.sh) — KDE Plasma, GNOME, XFCE, or Hyprland, with optional display-manager enablement after installation.

### Run the menu

Download or clone the complete repository first; the menu needs the other scripts to be present in their folders. From the repository root, run:

```bash
bash "useful scripts/Both Init Systems/gentoo-installer-menu.sh"
```

You can also run individual scripts directly. Installer/helper scripts should be launched as your regular user, not root; scripts that need administrative access call `sudo` and ask for confirmation. The diagnostics scripts are read-only. Portage package availability and dependencies vary with profile, USE flags, architecture, and repository state, so review its proposed changes carefully.

**Testing note:** these scripts were committed as initial implementations and have not been confirmed on every Gentoo profile or real hardware. Test in a virtual machine when practical, review the shell scripts before running them, and do not treat a successful syntax check as proof that package installation or desktop startup will work on your machine.

## Tips

- **Use a different mirror:** `GENTOO_MIRROR=https://mirror.example.org/gentoo ./gentoo-installation-script.sh`
- **Test it safely:** run a Gentoo ISO in QEMU/VirtualBox/virt-manager (UEFI works with OVMF) with an empty virtual disk.
- **Compile times:** with source builds, a desktop environment can take hours. Binary packages cut this a lot.
- **Licenses:** the script sets `ACCEPT_LICENSE="*"` so firmware and binary packages install without prompts. Tighten it in `/etc/portage/make.conf` if you prefer.
- **Wayland and X11 keyboard layout:** the script sets the console keymap. Set your desktop layout in the desktop's settings after first login.

## Limitations (v0.1.1)

- amd64 only, GRUB only, no encryption or LVM, and no dual-boot detection.
- The EFI fallback path (`EFI/BOOT/BOOTX64.EFI`) is also written so the system boots on firmware that ignores NVRAM entries. This may replace another OS's fallback loader.
- Not extensively tested on real hardware yet. Please report problems.

## Roadmap ideas

- arm64 support, GRUB alternatives, encryption and LVM.
- Unattended installs from a config file.
- More desktops and window managers (Sway, Hyprland, Cinnamon, MATE).
- A complete Gentoo-native End-4/illogical-impulse dependency and service mapping.

## Contributing

Issues and pull requests are welcome. Please include your boot mode (UEFI/BIOS), disk type, the options you chose, and the error output when reporting a failure.

## License

MIT. See the [LICENSE](LICENSE) file.

## Disclaimer

Provided as-is, with no warranty. Gentoo® is a trademark of the Gentoo Foundation. This project is community-made and unofficial.
