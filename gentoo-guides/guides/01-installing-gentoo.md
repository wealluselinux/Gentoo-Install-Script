# 01. Installing Gentoo

You have two routes.

## Route A: the installer script (easiest)

The script in this repository partitions your disk, downloads and verifies the official stage3 tarball, and installs a bootable system with the desktop you choose.

1. Boot the [Gentoo minimal ISO](https://www.gentoo.org/downloads/) from a USB drive.
2. Get online (`ping -c 3 gentoo.org` should work).
3. Download and run the script:
   ```bash
   wget https://raw.githubusercontent.com/wealluselinux/Gentoo-Install-Script/main/gentoo-installation-script.sh
   chmod +x gentoo-installation-script.sh
   ./gentoo-installation-script.sh
   ```
4. Answer the prompts, check the summary, type `YES`, and wait.

The full walkthrough, requirements and options are in the [main README](../../README.md).

**Which init system?** OpenRC is Gentoo's default and works well, including with KDE Plasma and GNOME. Pick systemd if you want the same service tooling as Arch/Ubuntu/Fedora, or software that expects it.

**Binary or source?** "Use binary packages" is much faster and fine for most people. Compiling from source lets Portage tune packages to your CPU, but a desktop can take hours.

## Route B: manual install

Gentoo's [AMD64 Handbook](https://wiki.gentoo.org/wiki/Handbook:AMD64) is the official, excellent guide. Doing it once by hand teaches you how Gentoo is put together. The installer script follows the same steps, so the Handbook is also the best place to understand what the script did.

## After installing

Continue with [02 First steps after install](02-first-steps-after-install.md).
