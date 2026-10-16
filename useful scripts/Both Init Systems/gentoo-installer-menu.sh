#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
BOTH_DIR="$ROOT_DIR/useful scripts/Both Init Systems"
OPENRC_DIR="$ROOT_DIR/useful scripts/OpenRC"
SYSTEMD_DIR="$ROOT_DIR/useful scripts/Systemd"

if [[ ! -r /etc/gentoo-release ]]; then
  echo 'Warning: this menu was designed for an installed Gentoo system.'
fi

init_name="$(ps -p 1 -o comm= 2>/dev/null | tr -d ' ' || true)"
case "$init_name" in
  systemd) INIT_KIND=Systemd ;;
  openrc|init) if command -v rc-update >/dev/null 2>&1; then INIT_KIND=OpenRC; else INIT_KIND=Unknown; fi ;;
  *) if command -v rc-update >/dev/null 2>&1; then INIT_KIND=OpenRC
     elif command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then INIT_KIND=Systemd
     else INIT_KIND=Unknown; fi ;;
esac

run_script() {
  local script="$1"
  if [[ -f "$script" ]]; then
    echo
    echo "Launching: $script"
    bash "$script"
  else
    echo "Script not found: $script"
    echo 'Make sure you downloaded/cloned the full repository, including the useful scripts folder.'
  fi
  echo
  read -r -p 'Press Enter to return to the menu...' _
}

echo '=== Gentoo Post-Install Toolkit ==='
echo "Detected init system: $INIT_KIND"
echo 'Read each script description and review it before running.'
echo

while true; do
  cat <<'MENU'
1) System information report (read-only)
2) Network diagnostics (read-only)
3) Gentoo maintenance helper
4) Useful apps installer
5) Gaming tools installer
6) Developer tools installer
7) Desktop setup helper (init-specific)
8) Desktop chooser (init-specific)
9) End-4 dots bootstrap (init-specific)
10) Quit
MENU
  read -r -p 'Choose [1-10]: ' choice
  case "$choice" in
    1) run_script "$BOTH_DIR/gentoo-system-info.sh" ;;
    2) run_script "$BOTH_DIR/gentoo-network-diagnostics.sh" ;;
    3) run_script "$BOTH_DIR/gentoo-maintenance-helper.sh" ;;
    4) run_script "$BOTH_DIR/gentoo-useful-apps-installer.sh" ;;
    5) run_script "$BOTH_DIR/gentoo-gaming-tools-installer.sh" ;;
    6) run_script "$BOTH_DIR/gentoo-developer-tools-installer.sh" ;;
    7)
      case "$INIT_KIND" in
        OpenRC) run_script "$OPENRC_DIR/gentoo-desktop-setup-openrc.sh" ;;
        Systemd) run_script "$SYSTEMD_DIR/gentoo-desktop-setup-systemd.sh" ;;
        *) echo 'Could not safely detect init. Run the correct script manually.' ;;
      esac
      ;;
    8)
      case "$INIT_KIND" in
        OpenRC) run_script "$OPENRC_DIR/gentoo-desktop-chooser-openrc.sh" ;;
        Systemd) run_script "$SYSTEMD_DIR/gentoo-desktop-chooser-systemd.sh" ;;
        *) echo 'Could not safely detect init. Run the correct script manually.' ;;
      esac
      ;;
    9)
      case "$INIT_KIND" in
        OpenRC) run_script "$OPENRC_DIR/gentoo-end4-dots-installer-openrc.sh" ;;
        Systemd) run_script "$SYSTEMD_DIR/gentoo-end4-dots-installer-systemd.sh" ;;
        *) echo 'Could not safely detect init. Run the correct script manually.' ;;
      esac
      ;;
    10) exit 0 ;;
    *) echo 'Choose a number from 1 to 10.' ;;
  esac
done
