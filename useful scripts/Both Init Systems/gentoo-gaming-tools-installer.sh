#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -eq 0 ]]; then echo 'Run as your regular user, not root.' >&2; exit 1; fi
if [[ ! -r /etc/gentoo-release ]] || ! command -v emerge >/dev/null 2>&1; then echo 'This installer is for an installed Gentoo system with Portage.' >&2; exit 1; fi
if ! command -v sudo >/dev/null 2>&1; then echo 'sudo is required.' >&2; exit 1; fi

echo '=== Gentoo Gaming Tools ==='
echo 'Detected graphics devices:'
if command -v lspci >/dev/null 2>&1; then
  lspci | grep -Ei 'vga|3d controller|display controller' || echo 'No PCI graphics device found.'
else
  echo 'lspci is missing; install sys-apps/pciutils if you want hardware detection.'
fi
echo
echo 'This installs diagnostic/runtime basics only. It does not select or reconfigure GPU drivers, enable multilib, install Steam, or add overlays.'
packages=(dev-util/vulkan-tools media-libs/vulkan-loader media-libs/mesa x11-apps/mesa-progs app-arch/zip app-arch/unzip)
echo 'Recommended package set:'
printf '  %s\n' "${packages[@]}"
read -r -p 'Ask Portage to install these tools? [y/N] ' answer
if [[ ! "$answer" =~ ^[Yy]$ ]]; then echo 'Cancelled; nothing installed.'; exit 0; fi
sudo emerge --ask --verbose "${packages[@]}"

echo
echo 'After installation, you can run vulkaninfo --summary and glxinfo -B (where applicable) to inspect graphics support.'
echo 'GPU driver, 32-bit/multilib, Steam, and Wine setup varies by hardware/profile. Read Gentoo documentation before changing USE flags or adding third-party overlays.'
