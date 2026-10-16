#!/usr/bin/env bash
set -u

printf '\n=== Gentoo System Information ===\n'
printf 'Date: '; date 2>/dev/null || printf 'unavailable\n'
printf 'Hostname: '; hostname 2>/dev/null || printf 'unavailable\n'
printf 'Kernel: '; uname -srmo 2>/dev/null || printf 'unavailable\n'
printf 'Init (PID 1): '
init_name="$(ps -p 1 -o comm= 2>/dev/null | tr -d ' ' || true)"
printf '%s\n' "${init_name:-unknown}"
printf 'Gentoo marker: '
if [[ -r /etc/gentoo-release ]]; then cat /etc/gentoo-release; else echo 'not found'; fi

echo
echo '--- CPU ---'
if command -v lscpu >/dev/null 2>&1; then lscpu | grep -E '^(Architecture|CPU\(s\)|Model name|Vendor ID):' || true
else grep -m1 -E 'model name|Hardware' /proc/cpuinfo 2>/dev/null || true; fi

echo
echo '--- Memory ---'
if command -v free >/dev/null 2>&1; then free -h; else cat /proc/meminfo 2>/dev/null | head -5; fi

echo
echo '--- Disks ---'
if command -v lsblk >/dev/null 2>&1; then lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS 2>/dev/null || lsblk; else echo 'lsblk not installed'; fi

echo
echo '--- Graphics ---'
if command -v lspci >/dev/null 2>&1; then lspci 2>/dev/null | grep -Ei 'vga|3d controller|display controller' || echo 'No PCI graphics device found'; else echo 'lspci not installed (optional: sys-apps/pciutils)'; fi

echo
echo '--- Network summary ---'
if command -v ip >/dev/null 2>&1; then ip -brief address 2>/dev/null || true; ip route 2>/dev/null | head -5 || true
else echo 'ip command unavailable'; fi

echo
echo '--- Portage ---'
if command -v emerge >/dev/null 2>&1; then emerge --version 2>/dev/null | head -2; else echo 'emerge not found'; fi
if [[ -d /var/db/repos/gentoo ]]; then echo 'Gentoo repository directory: present'; else echo 'Gentoo repository directory: not found at /var/db/repos/gentoo'; fi

echo
echo 'Read-only report complete. No settings were changed.'
echo 'Review the output before sharing it publicly; it may reveal your hostname or hardware details.'
