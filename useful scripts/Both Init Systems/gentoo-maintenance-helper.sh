#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -eq 0 ]]; then echo 'Run this as your regular user; the script uses sudo when needed.' >&2; exit 1; fi
if [[ ! -r /etc/gentoo-release ]] || ! command -v emerge >/dev/null 2>&1; then echo 'This helper requires an installed Gentoo system with Portage.' >&2; exit 1; fi
if ! command -v sudo >/dev/null 2>&1; then echo 'sudo is required. Configure sudo for your account, then retry.' >&2; exit 1; fi

echo '=== Gentoo Maintenance Helper ==='
echo 'Choose an operation. Package updates are always shown by Portage before execution.'
echo
PS3='Select an option (1-5): '
select action in 'Sync Gentoo repositories' 'Preview and confirm system update' 'Review pending configuration updates (dispatch-conf)' 'Show disk space' 'Quit'; do
  case "$REPLY" in
    1)
      read -r -p 'Sync Portage repositories now? [y/N] ' answer
      [[ "$answer" =~ ^[Yy]$ ]] || { echo 'Cancelled.'; continue; }
      sudo emerge --sync
      ;;
    2)
      echo 'Portage will display the proposed update plan and ask for confirmation.'
      sudo emerge --ask --verbose --update --deep --newuse @world
      ;;
    3)
      if command -v dispatch-conf >/dev/null 2>&1; then
        echo 'dispatch-conf interactively reviews configuration file updates; read each prompt carefully.'
        sudo dispatch-conf
      else
        echo 'dispatch-conf is unavailable. Check your Portage installation and configuration.'
      fi
      ;;
    4)
      df -hT
      ;;
    5) break ;;
    *) echo 'Please select a listed number.' ;;
  esac
  echo
  echo 'Choose another operation or Quit.'
done
