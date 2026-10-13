# 04. Flatpak, overlays and binary packages

Three ways to get more software on Gentoo without compiling everything.

## Flatpak and Flathub

[Flatpak](https://flatpak.org/) runs apps in a sandbox with their own libraries. [Flathub](https://flathub.org/) is the main store.

```bash
bash gentoo-guides/scripts/setup-flatpak.sh        # installs sys-apps/flatpak, adds Flathub
bash gentoo-guides/scripts/install-flatpak-apps.sh # pick apps from a menu
```

By hand it is:

```bash
sudo emerge --ask --verbose sys-apps/flatpak
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install --user flathub org.mozilla.firefox
flatpak run org.mozilla.firefox
```

Log out and back in (or reboot) after installing Flatpak so launchers see the new apps.

**Good to know**

- Flatpak's sandbox needs user namespaces in the kernel. The Gentoo binary kernel has them. With a custom kernel, enable `CONFIG_USER_NS`.
- If file dialogs or fonts look wrong in some desktops, install `sys-apps/xdg-desktop-portal-gtk` (the script offers it).
- Manage per-app permissions with the Flatseal app (`com.github.tchx84.Flatseal`).
- Update with `flatpak update --user`.
- The Gentoo wiki page [Flatpak](https://wiki.gentoo.org/wiki/Flatpak) covers portals for tiling window managers such as Sway.

## Overlays (GURU)

An overlay is an extra ebuild repository. **GURU** is the community one: lots of software, but unreviewed by Gentoo developers.

```bash
bash gentoo-guides/scripts/setup-overlays.sh
```

By hand:

```bash
sudo emerge --ask app-eselect/eselect-repository dev-vcs/git
sudo eselect repository enable guru
sudo emaint sync --repo guru
```

Packages from overlays are often "testing" (`~amd64`) and may need a keyword entry. Emerge will tell you what to add. Once enabled, GURU is synced along with the main tree every time you update.

## Binary packages

Gentoo publishes official prebuilt packages for common setups, so you can skip the compile for most things.

```bash
bash gentoo-guides/scripts/setup-binpkgs.sh
```

It creates the binary host config if missing and adds these lines to `/etc/portage/make.conf`:

```
FEATURES="${FEATURES} binpkg-request-signature"
EMERGE_DEFAULT_OPTS="${EMERGE_DEFAULT_OPTS} --getbinpkg"
```

Emerge then downloads a binary when one matches your USE flags and builds from source otherwise. The more you change USE flags from the profile defaults, the more packages will compile locally. To turn it off, delete those two lines.

## Which should I use?

| Situation | Use |
|---|---|
| Popular desktop app (Discord, Spotify, OBS) | Flatpak |
| Core tools, libraries, drivers, anything system-level | Main tree via `emerge` |
| Something only on the AUR | Check GURU, then Flatpak |
| Big package you don't want to compile | Binary packages or a `-bin` ebuild |
