# Gentoo Installation Script

An **unofficial**, open-source, interactive installer for [Gentoo Linux](https://www.gentoo.org/), in the spirit of `archinstall`.

You answer a few questions (disk type, desktop environment, language, and so on). The script then partitions the disk, downloads the official stage3 tarball, verifies it, and installs a bootable Gentoo system.

> **WARNING:** The script **erases the entire disk** you select. Back up your data first, and test in a virtual machine before using real hardware.
> This is an early version (v0.2.2). It is not affiliated with or endorsed by the Gentoo Foundation.

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

The repository includes `gentoo-end4-dots-installer.sh`, an experimental post-install
bootstrap helper for preparing the official [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)
checkout on an already-installed Gentoo system.

**Important:** this is not a complete Gentoo port of illogical-impulse yet. The upstream
setup contains distribution-specific package and setup logic and is not confirmed to work
on Gentoo. The helper clones the upstream repository for review; it deliberately does not
install packages, overwrite your desktop configuration, or run the upstream setup command.

Run it as your regular desktop user (not root):

```bash
wget https://raw.githubusercontent.com/wealluselinux/Gentoo-Install-Script/main/gentoo-end4-dots-installer.sh
chmod +x gentoo-end4-dots-installer.sh
./gentoo-end4-dots-installer.sh
```

The checkout is placed at `~/.local/src/dots-hyprland`. Read the upstream documentation
and verify Gentoo package availability before attempting installation. Back up
`~/.config` first. This helper is a starting point for a Gentoo-native port, not a
claim of full End-4 compatibility.

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

- arm64 support, and systemd-boot / rEFInd as bootloader choices.
- LUKS encryption, LVM and btrfs subvolumes.
- Unattended installs from a config file.
- More desktops and window managers (Sway, Hyprland, Cinnamon, MATE).

## Contributing

Issues and pull requests are welcome. Please include your boot mode (UEFI/BIOS), disk type, the options you chose, and the error output when reporting a failure.

## License

MIT. See the [LICENSE](LICENSE) file.

## Disclaimer

Provided as-is, with no warranty. Gentoo® is a trademark of the Gentoo Foundation. This project is community-made and unofficial.
