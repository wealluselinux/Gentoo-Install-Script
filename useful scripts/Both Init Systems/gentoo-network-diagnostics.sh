#!/usr/bin/env bash
set -u

echo '=== Gentoo Network Diagnostics (read-only) ==='
echo 'This script does not restart services or change network settings.'
echo
echo '--- Interfaces and addresses ---'
if command -v ip >/dev/null 2>&1; then
  ip -brief link 2>&1 || true
  ip -brief address 2>&1 || true
  echo
  echo '--- Routes ---'
  ip route 2>&1 || true
  ip -6 route 2>&1 || true
else
  echo 'ip command missing. Check that iproute2 is installed.'
fi

echo
echo '--- NetworkManager ---'
if command -v nmcli >/dev/null 2>&1; then
  nmcli general status 2>&1 || true
  nmcli device status 2>&1 || true
else
  echo 'nmcli not found; NetworkManager may not be installed or running.'
fi

echo
echo '--- DNS lookup ---'
if command -v getent >/dev/null 2>&1; then
  getent ahosts gentoo.org 2>&1 | head -8 || true
else
  echo 'getent not available'
fi

echo
echo '--- HTTPS connectivity ---'
if command -v curl >/dev/null 2>&1; then
  curl --head --location --max-time 8 --silent --show-error https://www.gentoo.org/ 2>&1 | head -8 || true
elif command -v wget >/dev/null 2>&1; then
  wget --spider --timeout=8 --tries=1 https://www.gentoo.org/ 2>&1 | head -8 || true
else
  echo 'Neither curl nor wget is installed; skipping HTTPS test.'
fi

echo
echo '--- Resolver configuration ---'
if [[ -r /etc/resolv.conf ]]; then sed -n '1,20p' /etc/resolv.conf; else echo '/etc/resolv.conf is not readable'; fi

echo
echo 'Hints: no address can mean a link/driver/DHCP issue; an address without a route may mean a gateway issue; failed name lookup with working IP connectivity may indicate DNS trouble.'
echo 'No configuration was changed. Share output only after reviewing it for private network details.'
