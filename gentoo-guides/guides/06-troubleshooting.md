# 06. Troubleshooting

## Reading emerge errors

When a build fails, emerge prints the path to a build log, usually under `/var/tmp/portage/<category>/<package>/temp/build.log`. Read the last 50 lines (`tail -n 50 <path>`). The real error is almost always near the end.

Useful when asking for help: `emerge --info` and the failing log (paste to a pastebin service rather than the chat).

## "The following USE changes are necessary"

Portage is telling you a package needs a USE flag changed to satisfy dependencies. You can let it write the change:

```bash
sudo emerge --ask --autounmask-write <package>
sudo dispatch-conf       # review and accept the new entries
sudo emerge --ask <package>
```

Read the lines it adds to `/etc/portage/package.use/` before accepting.

## "Masked by: ~amd64 keyword"

The package is only available as a testing version. If you accept the risk, add it to `/etc/portage/package.accept_keywords/<name>`:

```
category/package ~amd64
```

Only do this for the specific packages you need, not globally.

## "Masked by: license"

Add the license for that package, for example in `/etc/portage/package.license/<name>`. (The installer script sets `ACCEPT_LICENSE="*"` in `make.conf`, so this is rare on installs from it.)

## Blockers and slot conflicts

Read the whole message. Often a package must be removed or updated at the same time. Try updating `@world` fully:

```bash
sudo emerge --ask --update --deep --newuse @world
```

Add `--backtrack=30` if emerge gives up early.

## Config file updates

If emerge ends with "configuration files need updating", run `sudo dispatch-conf`. Skipping this over time leaves stale configs.

## Packages broken after an update

```bash
sudo emerge --ask @preserved-rebuild
sudo revdep-rebuild      # from gentoolkit
```

## No network on the new system

```bash
nmcli device status
sudo rc-service NetworkManager status      # OpenRC
systemctl status NetworkManager            # systemd
```

## No sound

On KDE Plasma and GNOME profiles, audio usually comes up with the session. If it doesn't, the steps depend on your init system and session type, and Gentoo's PipeWire documentation has changed over time, so follow the current [Gentoo wiki PipeWire page](https://wiki.gentoo.org/wiki/PipeWire) rather than an old forum post. On OpenRC with elogind, PipeWire needs a working D-Bus user session and has to be started at login.

## Graphics

The installer sets `VIDEO_CARDS` in `make.conf` from what it detects (Intel, AMD, Nouveau for NVIDIA, and VM drivers). For the proprietary NVIDIA driver, see the Gentoo wiki's NVIDIA page and set `VIDEO_CARDS="nvidia"`, then rebuild affected packages with `sudo emerge --ask --update --deep --newuse @world`.

## Where to get help

- [Gentoo Wiki](https://wiki.gentoo.org/) (excellent, check it first)
- [Gentoo Forums](https://forums.gentoo.org/)
- `#gentoo` on Libera.Chat
- Issues on this repository, for problems with the scripts themselves
