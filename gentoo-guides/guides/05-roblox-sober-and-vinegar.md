# 05. Roblox on Gentoo: Sober and Vinegar

Two community projects, two different jobs:

| | Sober | Vinegar |
|---|---|---|
| For | **Playing** Roblox games | **Roblox Studio** (making games) |
| How it works | Runs Roblox's Android client in its own runtime (no Wine, no emulator, no VM) | A bootstrapper that runs Studio on Linux |
| Flathub ID | `org.vinegarhq.Sober` | `org.vinegarhq.Vinegar` |
| Script | `install-sober.sh` | `install-vinegar.sh` |

Both are **unofficial** and not supported by Roblox. Sober's own site calls it experimental and says it may be discontinued at any time, and its source is closed. Use them at your own risk, and expect things to break after Roblox updates. Check the projects' sites for current status:

- Sober: <https://sober.vinegarhq.org/>
- Vinegar: <https://vinegarhq.org/>

## Requirements (from the projects' docs)

**Sober**
- x86-64 CPU only (no ARM). SSE4.2 is expected. SSE4.1-only CPUs run through emulation, slowly.
- Linux kernel 5.11 or newer.
- A GPU with OpenGL ES 3.0 (minimum). Vulkan 1.1 recommended.

**Vinegar**
- x86-64 CPU, 3 GB RAM, OpenGL 4.4 (minimum).
- Recommended: Linux 6.14 or newer (for NTSync), 8 GB RAM, Vulkan 1.4.

Check your kernel with `uname -r`. The Gentoo binary kernel (`gentoo-kernel-bin`) tracks recent kernels, so you are usually fine after a normal update.

## Install

1. Set up Flatpak once:
   ```bash
   bash gentoo-guides/scripts/setup-flatpak.sh
   ```
2. Log out and back in.
3. Install what you need:
   ```bash
   bash gentoo-guides/scripts/install-sober.sh      # to play
   bash gentoo-guides/scripts/install-vinegar.sh    # for Studio
   ```
   Each script checks the requirements above first and tells you if something is off.

4. Launch from your app menu, or `flatpak run org.vinegarhq.Sober`.

On first launch Sober offers to download and install Roblox. Use the automatic option, which is the one the project recommends.

## Uninstall

```bash
bash install-sober.sh --uninstall      # keep data
bash install-sober.sh --purge          # delete data too
bash install-vinegar.sh --uninstall
bash install-vinegar.sh --purge
```

## Troubleshooting

- **"Flatpak not found" or nothing launches:** run `setup-flatpak.sh`, then log out and back in.
- **Kernel too old:** run `update-system.sh`, reboot, and check `uname -r` again.
- **Black screen, crashes, or very low FPS:** make sure your GPU driver stack is installed and working on the host. The installer sets `VIDEO_CARDS` automatically in `make.conf` (AMD, Intel, and Nouveau for NVIDIA). NVIDIA proprietary driver users need Flatpak's matching NVIDIA runtime, which Flatpak normally installs on its own when needed.
- **Slow on an older CPU:** SSE4.1-only CPUs run Sober through emulation.
- **Broke after an update:** Roblox updates can break unofficial clients. Run `flatpak update --user` and check the project's Discord or GitHub for news.
- **Want detailed logs:** run it from a terminal with `flatpak run org.vinegarhq.Sober` and read the output.

## Also on Gentoo

Vinegar is packaged in a community Gentoo overlay too, but the Vinegar maintainer does not support distro packages. The Flatpak is the simplest route.
