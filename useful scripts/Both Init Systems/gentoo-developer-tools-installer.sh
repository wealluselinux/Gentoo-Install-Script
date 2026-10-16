#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -eq 0 ]]; then echo 'Run as your regular user, not root.' >&2; exit 1; fi
if [[ ! -r /etc/gentoo-release ]] || ! command -v emerge >/dev/null 2>&1; then echo 'This installer is for an installed Gentoo system with Portage.' >&2; exit 1; fi
if ! command -v sudo >/dev/null 2>&1; then echo 'sudo is required.' >&2; exit 1; fi

packages=(
  dev-vcs/git
  dev-lang/python
  dev-build/cmake
  sys-devel/gcc
  dev-debug/gdb
  app-editors/vim
)
echo 'Optional developer toolkit: Git, Python, CMake, GCC, GDB, and Vim.'
echo 'Portage may rebuild dependencies or report package/USE-flag conflicts.'
printf 'Packages: %s\n' "${packages[*]}"
read -r -p 'Ask Portage to install this set? [y/N] ' answer
if [[ ! "$answer" =~ ^[Yy]$ ]]; then echo 'Cancelled; nothing installed.'; exit 0; fi
sudo emerge --ask --verbose "${packages[@]}"
