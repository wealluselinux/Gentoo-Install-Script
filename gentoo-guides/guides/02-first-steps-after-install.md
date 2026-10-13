# 02. First steps after install

## 1. Log in and get online

The installer sets up NetworkManager. On a desktop, use the network applet. In a terminal:

```bash
nmtui                         # text interface for Wi-Fi/Ethernet
nmcli device wifi list        # or the command-line way
nmcli device wifi connect "SSID" password "PASSWORD"
```

## 2. Update everything

```bash
bash gentoo-guides/scripts/update-system.sh
```

That runs `emerge --sync`, updates `@world` (every package you asked for plus their dependencies), and offers to clean up. Do this regularly, like `pacman -Syu`.

## 3. Install the handy tools

```bash
bash gentoo-guides/scripts/install-essentials.sh
```

## 4. Understand Portage in five minutes

Gentoo's package manager is **Portage**, driven by the `emerge` command.

| Idea | Meaning |
|---|---|
| **ebuild** | A recipe for building (or fetching) a package. Like a PKGBUILD. |
| **USE flags** | On/off switches for optional features, such as `wayland`, `bluetooth`, `pipewire`. |
| **`@world`** | The set of packages you explicitly installed. |
| **`@system`** | The base packages every Gentoo needs. |
| **Profile** | A preset of defaults (desktop, systemd, and so on). Check with `eselect profile show`. |
| **Overlay** | An extra repository of ebuilds, like the AUR but managed by `eselect repository`. |

Configuration lives in `/etc/portage/`:

- `make.conf` holds global settings (compile flags, `USE`, `MAKEOPTS`, mirrors).
- `package.use/` holds per-package USE flags.
- `package.accept_keywords/` allows testing (`~amd64`) versions of specific packages.
- `package.license/` accepts licenses for specific packages.

### Everyday commands

```bash
emerge --search firefox                 # search (eix is faster: eix firefox)
sudo emerge --ask --verbose pkg         # install; shows what will happen first
sudo emerge --ask --depclean            # remove orphaned dependencies
sudo emerge --deselect pkg              # stop keeping a package in @world
sudo emerge --ask --update --deep --newuse @world   # update everything
equery belongs /usr/bin/foo             # which package owns a file (gentoolkit)
equery files pkg                        # which files a package installed
```

When emerge says config files need updating, run `sudo dispatch-conf` and review each change.

## 5. Services

| Task | OpenRC | systemd |
|---|---|---|
| Start now | `sudo rc-service NAME start` | `sudo systemctl start NAME` |
| Stop | `sudo rc-service NAME stop` | `sudo systemctl stop NAME` |
| Enable at boot | `sudo rc-update add NAME default` | `sudo systemctl enable NAME` |
| Disable at boot | `sudo rc-update del NAME default` | `sudo systemctl disable NAME` |
| Status | `rc-status` / `rc-service NAME status` | `systemctl status NAME` |

## 6. Faster installs

`bash gentoo-guides/scripts/setup-binpkgs.sh` lets emerge download official prebuilt packages when available.

## 7. More apps

See [03 Arch to Gentoo](03-arch-to-gentoo.md) and [04 Flatpak and apps](04-flatpak-and-apps.md).
