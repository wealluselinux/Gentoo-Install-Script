#!/usr/bin/env bash
#
# Gentoo Installation Script
# An unofficial, open-source, interactive installer for Gentoo Linux.
# Think "archinstall", but for Gentoo.
#
# Run it as root from a live Linux environment (ideally the Gentoo minimal ISO):
#   bash gentoo-installation-script.sh
#
# WARNING: this script ERASES the disk you choose.
#
# License: MIT (see repository)

set -Eeo pipefail

VERSION="0.2.1"
MNT="/mnt/gentoo"
ARCH="amd64"
MIRROR="${GENTOO_MIRROR:-https://distfiles.gentoo.org}"
GENTOO_RELEASE_KEY="13EBBDBE7A12775DFDB1BABB572E0E2D182910"
GENTOO_RELEASE_KEY_ALTERNATE="D99EAC7379A850BCE47DA5F29E6438C817072058"
DASHBOARD_ENABLED=yes
PROGRESS_DIR=""
PROGRESS_FILE=""
DASHBOARD_SCRIPT=""
DASHBOARD_PID=""
DASHBOARD_STARTED=no
CHROOT_PROGRESS_FILE="/tmp/.gentoo-installer-progress"

# ----------------------------------------------------------------------------
# Pretty output
# ----------------------------------------------------------------------------
if [[ -t 1 ]]; then
    B=$'\e[1m'; R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; C=$'\e[36m'; N=$'\e[0m'
else
    B=""; R=""; G=""; Y=""; C=""; N=""
fi
info() { printf '%s[*]%s %s\n' "$C" "$N" "$*"; }
ok()   { printf '%s[+]%s %s\n' "$G" "$N" "$*"; }
warn() { printf '%s[!]%s %s\n' "$Y" "$N" "$*" >&2; }
progress_update() {
    local pct=${1:-0} message=${2:-}
    [[ -n ${PROGRESS_FILE:-} && -e $PROGRESS_FILE ]] || return 0
    [[ $pct =~ ^[0-9]+$ ]] || pct=0
    (( pct < 0 )) && pct=0
    (( pct > 100 )) && pct=100
    message=${message//$'\t'/ }
    message=${message//$'\r'/ }
    message=${message//$'\n'/ }
    message=${message//|/\/}
    printf '%s|%s\n' "$pct" "$message" > "$PROGRESS_FILE"
}
die()  {
    printf '%s[x]%s %s\n' "$R" "$N" "$*" >&2
    progress_update 0 "FAILED: $*" || true
    exit 1
}
on_error() {
    local line=$1 command=$2
    printf '%s[x]%s Failed at line %s: %s\n' "$R" "$N" "$line" "$command" >&2
    progress_update 0 "FAILED: Script error near line $line" || true
}
trap 'on_error "$LINENO" "$BASH_COMMAND"' ERR

usage() {
    cat <<EOF
Gentoo Installation Script v$VERSION

Usage: bash $(basename "$0") [--help] [--version] [--no-dashboard]

Interactive installer: asks about your disk, init system, desktop, language,
and so on, downloads the official stage3 tarball, and installs Gentoo.

Options:
  --no-dashboard  Do not open the separate progress dashboard.

Environment:
  GENTOO_MIRROR    Mirror base URL (default: https://distfiles.gentoo.org)
EOF
}
case "${1:-}" in
    -h|--help) usage; exit 0 ;;
    -v|--version) echo "$VERSION"; exit 0 ;;
    --no-dashboard) DASHBOARD_ENABLED=no ;;
esac

# Make sure we can read from the keyboard even if piped (curl ... | bash)
[[ -t 0 ]] || exec </dev/tty

# On a text-only live ISO, a second graphical terminal is not available. If
# tmux is installed and this is a real interactive TTY, put the installer in
# a tmux session so start_dashboard() can create a separate pane later.
# Skip this when --no-dashboard was requested or when already inside tmux.
if [[ ${DASHBOARD_ENABLED:-yes} == yes && -z ${DISPLAY:-} && -z ${WAYLAND_DISPLAY:-} \
      && -z ${TMUX:-} && ${GENTOO_INSTALLER_TMUX_BOOTSTRAPPED:-0} != 1 \
      && -t 0 && -t 1 ]] && command -v tmux >/dev/null 2>&1; then
    printf -v quoted_script '%q' "$0"
    session_name="gentoo-install-$$"
    info "No graphical desktop detected; trying a tmux session for the progress dashboard."
    if tmux new-session -s "$session_name" "GENTOO_INSTALLER_TMUX_BOOTSTRAPPED=1 bash $quoted_script"; then
        exit 0
    else
        warn "Could not start tmux; continuing in the current terminal."
    fi
fi

# ----------------------------------------------------------------------------
# Prompt helpers
# ----------------------------------------------------------------------------
ask() {
    local __var=$1 __prompt=$2 __def=${3:-} __ans=""
    if [[ -n $__def ]]; then
        read -r -p "$__prompt [$__def]: " __ans || true
        __ans=${__ans:-$__def}
    else
        while :; do
            read -r -p "$__prompt: " __ans || true
            [[ -n $__ans ]] && break
        done
    fi
    printf -v "$__var" '%s' "$__ans"
}

ask_secret() {
    local __var=$1 __p=$2 a b
    while :; do
        read -rs -p "$__p: " a; echo
        [[ -n $a ]] || { warn "Cannot be empty."; continue; }
        read -rs -p "Confirm: " b; echo
        [[ $a == "$b" ]] && break
        warn "Passwords do not match."
    done
    printf -v "$__var" '%s' "$a"
}

choose() {
    local __var=$1 __title=$2; shift 2
    local opts=("$@") i ans
    echo; echo "${B}${__title}${N}"
    for i in "${!opts[@]}"; do printf '  %d) %s\n' $((i + 1)) "${opts[$i]}"; done
    while :; do
        read -r -p "Choice [1]: " ans || true
        ans=${ans:-1}
        if [[ $ans =~ ^[0-9]+$ ]] && (( ans >= 1 && ans <= ${#opts[@]} )); then
            printf -v "$__var" '%s' "${opts[ans-1]}"
            return
        fi
        warn "Pick a number between 1 and ${#opts[@]}."
    done
}

fetch() { # fetch URL OUTFILE
    if command -v curl >/dev/null 2>&1; then
        curl -fL --retry 3 --progress-bar -o "$2" "$1"
    else
        wget -q --show-progress -O "$2" "$1"
    fi
}
fetch_text() { # fetch_text URL
    if command -v curl >/dev/null 2>&1; then curl -fsSL --retry 3 "$1"; else wget -qO- "$1"; fi
}

# The dashboard runs in a separate graphical terminal, a tmux split, or a
# separate Linux virtual console when running from a text-only live ISO.
# Installer output remains on the original terminal. During Portage merges, the
# dashboard percentage is based on actual "N of M" package progress; other
# stages use weighted milestones, so the percentage is a useful estimate rather
# than a promise of remaining time.
start_dashboard() {
    [[ ${DASHBOARD_ENABLED:-yes} == yes ]] || return 0

    PROGRESS_DIR=$(mktemp -d /tmp/gentoo-installer.XXXXXX) || {
        warn "Could not create the progress dashboard's temporary directory."
        return 0
    }
    PROGRESS_FILE="$PROGRESS_DIR/status"
    DASHBOARD_SCRIPT="$PROGRESS_DIR/dashboard.sh"
    printf '0|Starting the installer dashboard...\n' > "$PROGRESS_FILE"

    cat > "$DASHBOARD_SCRIPT" <<'DASHBOARD'
#!/usr/bin/env bash
status_file=${1:?missing status file}
last_pct=-1
last_message="Starting..."
cleanup_dashboard() {
    printf '\033[?25h\033[0m\n'
    rm -f "$status_file" "$0"
    rmdir "$(dirname "$0")" 2>/dev/null || true
}
trap cleanup_dashboard EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
printf '\033[?25l'
while :; do
    if [[ -r $status_file ]]; then
        IFS='|' read -r pct message < "$status_file" || true
        [[ $pct =~ ^[0-9]+$ ]] || pct=0
        [[ -n ${message:-} ]] || message=$last_message
        last_pct=$pct
        last_message=$message
    fi

    printf '\033[H\033[2J'
    printf '\033[1;36m  GENTOO INSTALLER\033[0m\n'
    printf '  ------------------------------------------\n\n'
    printf '  Overall progress\n\n  ['
    width=36
    filled=$(( last_pct * width / 100 ))
    for ((i=0; i<filled; i++)); do printf '\033[1;32m#\033[0m'; done
    for ((i=filled; i<width; i++)); do printf ' '; done
    printf '] %3d%%\n\n' "$last_pct"
    printf '  Current task:\n  %s\n\n' "$last_message"
    printf '  Detailed command output stays in the\n  original installer terminal.\n'

    if [[ $last_message == FAILED:* ]]; then
        printf '\n\033[1;31m  Installation stopped with an error.\033[0m\n'
        read -r -p '  Press Enter to close this dashboard: ' _ || true
        break
    fi
    if (( last_pct >= 100 )); then
        printf '\n\033[1;32m  Installation steps completed.\033[0m\n'
        read -r -p '  Press Enter to close this dashboard: ' _ || true
        break
    fi
    sleep 0.5
done
DASHBOARD
    chmod 700 "$DASHBOARD_SCRIPT"

    local title='Gentoo Installer Progress'
    if [[ -n ${DISPLAY:-} || -n ${WAYLAND_DISPLAY:-} ]]; then
        if command -v xfce4-terminal >/dev/null 2>&1 &&
            try_dashboard xfce4-terminal --disable-server --title="$title" --command="bash '$DASHBOARD_SCRIPT' '$PROGRESS_FILE'"; then
            :
        elif command -v konsole >/dev/null 2>&1 &&
            try_dashboard konsole --nofork --title "$title" -e bash "$DASHBOARD_SCRIPT" "$PROGRESS_FILE"; then
            :
        elif command -v gnome-terminal >/dev/null 2>&1 &&
            try_dashboard gnome-terminal --wait --title="$title" -- bash "$DASHBOARD_SCRIPT" "$PROGRESS_FILE"; then
            :
        elif command -v mate-terminal >/dev/null 2>&1 &&
            try_dashboard mate-terminal --wait --title="$title" -- bash "$DASHBOARD_SCRIPT" "$PROGRESS_FILE"; then
            :
        elif command -v qterminal >/dev/null 2>&1 &&
            try_dashboard qterminal -e bash "$DASHBOARD_SCRIPT" "$PROGRESS_FILE"; then
            :
        elif command -v lxterminal >/dev/null 2>&1 &&
            try_dashboard lxterminal --title="$title" --command="bash '$DASHBOARD_SCRIPT' '$PROGRESS_FILE'"; then
            :
        elif command -v kitty >/dev/null 2>&1 &&
            try_dashboard kitty --title "$title" bash "$DASHBOARD_SCRIPT" "$PROGRESS_FILE"; then
            :
        elif command -v alacritty >/dev/null 2>&1 &&
            try_dashboard alacritty --title "$title" -e bash "$DASHBOARD_SCRIPT" "$PROGRESS_FILE"; then
            :
        elif command -v xterm >/dev/null 2>&1 &&
            try_dashboard xterm -T "$title" -e bash "$DASHBOARD_SCRIPT" "$PROGRESS_FILE"; then
            :
        elif command -v x-terminal-emulator >/dev/null 2>&1 &&
            try_dashboard x-terminal-emulator -T "$title" -e bash "$DASHBOARD_SCRIPT" "$PROGRESS_FILE"; then
            :
        else
            warn "No supported graphical terminal could be opened; continuing without the separate dashboard."
        fi
    elif [[ -n ${TMUX:-} ]] && command -v tmux >/dev/null 2>&1; then
        if tmux split-window -h "bash '$DASHBOARD_SCRIPT' '$PROGRESS_FILE'"; then
            DASHBOARD_STARTED=yes
            ok "Progress dashboard opened in a tmux split."
        else
            warn "Could not create a tmux split; continuing without the dashboard."
        fi
    elif command -v openvt >/dev/null 2>&1 && [[ -t 1 ]]; then
        if ! try_openvt_dashboard; then
            warn "Could not open another virtual console; progress will remain in the original terminal."
        fi
    else
        warn "No graphical terminal, tmux session, or openvt command was available. The installer will continue in this terminal."
    fi

    if [[ $DASHBOARD_STARTED == yes ]]; then
        progress_update 2 "Dashboard ready; preparing installation..."
    else
        # Do not leak temporary helper files when no dashboard process exists.
        rm -rf "$PROGRESS_DIR"
        PROGRESS_DIR=""; PROGRESS_FILE=""; DASHBOARD_SCRIPT=""
    fi
}

try_dashboard() {
    "$@" >/dev/null 2>&1 &
    local pid=$!
    sleep 0.35
    if kill -0 "$pid" 2>/dev/null; then
        DASHBOARD_PID=$pid
        DASHBOARD_STARTED=yes
        ok "Progress dashboard opened in a separate terminal."
        return 0
    fi
    wait "$pid" 2>/dev/null || true
    return 1
}

try_openvt_dashboard() {
    local current_tty current_vt target_vt pid
    current_tty=$(tty 2>/dev/null || true)
    [[ $current_tty =~ ^/dev/tty([0-9]+)$ ]] || return 1
    current_vt=${BASH_REMATCH[1]}

    # Try common text consoles without forcibly replacing a console already
    # in use. -s switches to the dashboard VT; switch back to the original VT
    # with Ctrl+Alt+F<number> to see the installer's detailed output.
    for target_vt in 2 3 4 5 6; do
        (( target_vt == current_vt )) && continue
        openvt -s -c "$target_vt" -w -- bash "$DASHBOARD_SCRIPT" "$PROGRESS_FILE" \
            >/dev/null 2>&1 &
        pid=$!
        sleep 0.3
        if kill -0 "$pid" 2>/dev/null; then
            DASHBOARD_PID=$pid
            DASHBOARD_STARTED=yes
            ok "Progress dashboard started on virtual console $target_vt."
            warn "Detailed output remains on console $current_vt. Switch with Ctrl+Alt+F$current_vt; dashboard is on Ctrl+Alt+F$target_vt."
            return 0
        fi
        wait "$pid" 2>/dev/null || true
    done
    return 1
}

# ----------------------------------------------------------------------------
# Pre-flight
# ----------------------------------------------------------------------------
banner() {
    cat <<EOF
${B}${C}
    ____        _
   / ___| ___ _ __ | |_ ___   ___
  | |  _ / _ \ '_ \| __/ _ \ / _ \\
  | |_| |  __/ | | | || (_) | (_) |
   \____|\___|_| |_|\__\___/ \___/
${N}${B} Gentoo Installation Script v$VERSION${N}  (unofficial, open source)
EOF
}

preflight() {
    [[ $EUID -eq 0 ]] || die "Please run as root."
    [[ $(uname -m) == x86_64 ]] || die "Only x86_64 (amd64) is supported right now."
    local missing=() t
    for t in lsblk sfdisk wipefs blkid tar chroot sha256sum gpg partprobe mount umount \
             awk sed grep xz blockdev nproc udevadm sleep sync mktemp chmod cp ln sort \
             head tac swapoff swapon mkswap getent useradd groupadd chpasswd; do
        command -v "$t" >/dev/null 2>&1 || missing+=("$t")
    done
    command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || missing+=("curl or wget")
    (( ${#missing[@]} == 0 )) || die "Missing required tools: ${missing[*]}"

    if [[ -d /sys/firmware/efi ]]; then BOOT=uefi; else BOOT=bios; fi
    ok "Boot mode detected: ${BOOT^^}"

    info "Checking network connectivity..."
    fetch_text "$MIRROR/releases/$ARCH/autobuilds/latest-stage3-$ARCH-openrc.txt" >/dev/null \
        || die "Cannot reach $MIRROR. Connect to the internet first."
    ok "Network OK"
}

# ----------------------------------------------------------------------------
# Questions
# ----------------------------------------------------------------------------
part() {
    if [[ $DISK =~ [0-9]$ ]]; then echo "${DISK}p$1"; else echo "${DISK}$1"; fi
}

select_disk() {
    local pat
    choose DISK_TYPE "What type of disk are you installing to?" \
        "NVMe SSD       (/dev/nvme*)" \
        "SATA / SAS / USB drive (/dev/sd*)" \
        "eMMC / SD card (MMC)   (/dev/mmcblk*)" \
        "VirtIO disk (virtual machine)   (/dev/vd*)" \
        "Other / show everything"
    case "$DISK_TYPE" in
        NVMe*)   pat='^/dev/nvme[0-9]+n[0-9]+$' ;;
        SATA*)   pat='^/dev/sd[a-z]+$' ;;
        eMMC*)   pat='^/dev/mmcblk[0-9]+$' ;;
        VirtIO*) pat='^/dev/vd[a-z]+$' ;;
        *)       pat='^/dev/' ;;
    esac

    local cands=() name size type model mounted
    while read -r name size type model; do
        [[ $type == disk && $name =~ $pat ]] || continue
        mounted=""
        if lsblk -nro MOUNTPOINT "$name" | grep -q .; then mounted="  [HAS MOUNTED PARTITIONS]"; fi
        cands+=("$name  $size  ${model:-unknown}$mounted")
    done < <(lsblk -dpno NAME,SIZE,TYPE,MODEL)

    (( ${#cands[@]} > 0 )) || die "No matching disks found. Try 'Other / show everything'."
    local pick
    choose pick "Select the disk to ERASE and install Gentoo on:" "${cands[@]}"
    DISK=${pick%% *}

    DISK_BYTES=$(blockdev --getsize64 "$DISK")
    (( DISK_BYTES >= 20 * 1024 ** 3 )) || die "$DISK is smaller than 20 GiB; not enough for Gentoo."
}

gather_config() {
    select_disk

    choose INIT_LABEL "Init system" \
        "OpenRC  (Gentoo's default, lightweight)" \
        "systemd"
    [[ $INIT_LABEL == systemd* ]] && INIT=systemd || INIT=openrc

    choose DE_LABEL "Desktop environment / window manager" \
        "None (command-line only / server)" \
        "KDE Plasma (feature-rich; heavier)" \
        "GNOME (feature-rich; heavier)" \
        "XFCE (lightweight desktop)" \
        "LXQt (lightweight Qt desktop)" \
        "MATE (traditional desktop)" \
        "Cinnamon (traditional, modern desktop)" \
        "LXDE (very lightweight desktop)" \
        "i3 (lightweight X11 tiling window manager)" \
        "Sway (Wayland tiling compositor)" \
        "Openbox (minimal X11 window manager)"
    case "$DE_LABEL" in
        None*)      DE=none; ;;
        KDE*)       DE=plasma; ;;
        GNOME*)     DE=gnome; ;;
        XFCE*)      DE=xfce; ;;
        LXQt*)      DE=lxqt; ;;
        MATE*)      DE=mate; ;;
        Cinnamon*)  DE=cinnamon; ;;
        LXDE*)      DE=lxde; ;;
        i3*)        DE=i3; ;;
        Sway*)      DE=sway; ;;
        Openbox*)   DE=openbox; ;;
    esac

    DM=""
    if [[ $DE != none ]]; then
        case $DE in
            plasma) DM=sddm ;;
            gnome)  DM=gdm ;;
            sway)   DM="" ;;
            *)      DM=lightdm ;;
        esac
        choose DM_LABEL "Graphical login manager (not a screen locker)" \
            "Automatic (recommended for this desktop)" \
            "SDDM" \
            "LightDM" \
            "GDM (GNOME's login manager)" \
            "None (log in on a TTY and start the session manually)"
        case "$DM_LABEL" in
            Automatic*) : ;;
            SDDM*)      DM=sddm ;;
            LightDM*)   DM=lightdm ;;
            GDM*)       DM=gdm ;;
            None*)      DM="" ;;
        esac
    fi

    choose LOCALE_LABEL "Language / locale" \
        "English (US)        - en_US" \
        "English (UK)        - en_GB" \
        "Deutsch             - de_DE" \
        "Francais            - fr_FR" \
        "Espanol             - es_ES" \
        "Portugues (Brasil) - pt_BR" \
        "Italiano            - it_IT" \
        "Russian             - ru_RU" \
        "Japanese            - ja_JP" \
        "Chinese (Simpl.)    - zh_CN" \
        "Other (type it)"
    if [[ $LOCALE_LABEL == Other* ]]; then
        while :; do
            ask LOCALE "Locale code (e.g. nl_NL, pl_PL, sv_SE)"
            [[ $LOCALE =~ ^[a-z]{2,3}_[A-Z]{2}$ ]] && break
            warn "Format must look like xx_XX."
        done
    else
        LOCALE=${LOCALE_LABEL##* - }
    fi

    ask KEYMAP "Console keyboard layout (us, uk, de, fr, es, ...)" "us"

    while :; do
        ask TIMEZONE "Timezone (e.g. America/Detroit, Europe/Berlin, UTC)" "UTC"
        [[ -f /usr/share/zoneinfo/$TIMEZONE ]] && break
        warn "Unknown timezone. Look in /usr/share/zoneinfo for valid names."
    done

    while :; do
        ask HOST_NAME "Hostname" "gentoo"
        [[ $HOST_NAME =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,62}$ ]] && break
        warn "Invalid hostname."
    done

    while :; do
        ask USERNAME "Username for your regular account"
        [[ $USERNAME =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] && break
        warn "Use lowercase letters, digits, - and _ (must not start with a digit)."
    done
    ask_secret USER_PW "Password for $USERNAME"
    ask_secret ROOT_PW "Password for root"

    choose FS_LABEL "Root filesystem" \
        "ext4  (safe default)" \
        "btrfs" \
        "xfs"
    FS=${FS_LABEL%% *}

    local disk_gib max_swap_gib
    disk_gib=$(( DISK_BYTES / 1024 / 1024 / 1024 ))
    max_swap_gib=$(( disk_gib - 12 ))
    while :; do
        ask SWAP_GB "Swap partition size in GiB (0 for none; max ${max_swap_gib})" "4"
        if [[ $SWAP_GB =~ ^[0-9]+$ && ${#SWAP_GB} -le 4 ]]; then
            SWAP_GB=$((10#$SWAP_GB))
            (( SWAP_GB <= max_swap_gib )) && break
        fi
        warn "Enter a whole number between 0 and ${max_swap_gib}; leave enough space for the root filesystem."
    done

    choose KERNEL_LABEL "Kernel" \
        "Gentoo binary kernel (gentoo-kernel-bin, fast)" \
        "Gentoo distribution kernel, compiled from source (gentoo-kernel)"
    [[ $KERNEL_LABEL == *bin* ]] && KERNEL=sys-kernel/gentoo-kernel-bin || KERNEL=sys-kernel/gentoo-kernel

    choose BIN_LABEL "Package installation method" \
        "Use signed official Gentoo binary packages where available (recommended for low RAM)" \
        "Compile missing packages from source (can take a long time)"
    [[ $BIN_LABEL == Use* ]] && BINPKG=yes || BINPKG=no

    # Conservative defaults: one compiler job at <=4 GiB, and at most four
    # even on larger systems. Package merges stay serial to avoid RAM spikes.
    local cores mem_mb
    cores=$(nproc)
    mem_mb=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
    RAM_MIB=$mem_mb
    if (( mem_mb <= 4096 )); then
        JOBS=1
    else
        JOBS=$(( mem_mb / 3072 ))
        (( JOBS < 1 )) && JOBS=1
        (( JOBS > 4 )) && JOBS=4
        (( JOBS > cores )) && JOBS=$cores
    fi
    PKG_JOBS=1

    CPU_VENDOR=$(grep -m1 vendor_id /proc/cpuinfo | awk '{print $3}' || true)
    detect_video
}

detect_video() {
    local g
    g=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' || true)
    VIDEO=""
    grep -qi nvidia <<<"$g" && VIDEO+=" nouveau"
    grep -qiE 'amd|ati |radeon' <<<"$g" && VIDEO+=" amdgpu radeonsi"
    grep -qi intel <<<"$g" && VIDEO+=" intel"
    grep -qiE 'virtio|qemu' <<<"$g" && VIDEO+=" virgl"
    grep -qi vmware <<<"$g" && VIDEO+=" vmware"
    grep -qi virtualbox <<<"$g" && VIDEO+=" virtualbox"
    VIDEO=${VIDEO# }
    return 0
}

validate_selected_tools() {
    local required=() tool
    case $FS in
        ext4)  required+=(mkfs.ext4) ;;
        btrfs) required+=(mkfs.btrfs) ;;
        xfs)   required+=(mkfs.xfs) ;;
    esac
    [[ $BOOT == uefi ]] && required+=(mkfs.vfat)
    (( SWAP_GB > 0 )) && required+=(mkswap)
    for tool in "${required[@]}"; do
        command -v "$tool" >/dev/null 2>&1 || die "Required for your selections but missing from the live environment: $tool"
    done

    # Catch a missing compressor before the selected disk is erased.
    local stage3_list stage3_rel
    stage3_list="$MIRROR/releases/$ARCH/autobuilds/latest-stage3-$ARCH-$INIT.txt"
    stage3_rel=$(fetch_text "$stage3_list" | grep -E '\.tar\.(xz|zst)' | grep -v '^#' | awk '{print $1}' | head -n1 || true)
    [[ -n $stage3_rel ]] || die "Could not find a stage3 tarball at $stage3_list. No disk changes have been made."
    if [[ $stage3_rel == *.tar.zst ]]; then
        command -v zstd >/dev/null 2>&1 || die "This stage3 is zstd-compressed, but zstd is missing. Install it in the live environment before continuing."
    fi
}

confirm_config() {
    echo
    echo "${B}================ Installation summary ================${N}"
    printf '  %-16s %s\n' "Target disk:"    "$DISK  ($(lsblk -dno SIZE "$DISK"))"
    printf '  %-16s %s\n' "Boot mode:"      "${BOOT^^}"
    printf '  %-16s %s\n' "Init system:"    "$INIT"
    printf '  %-16s %s\n' "Desktop:"        "$DE_LABEL"
    printf '  %-16s %s\n' "Login manager:"  "${DM:-none (manual)}"
    printf '  %-16s %s\n' "Detected RAM:"   "${RAM_MIB} MiB"
    printf '  %-16s %s\n' "Compile jobs:"   "$JOBS"
    printf '  %-16s %s\n' "Package jobs:"   "$PKG_JOBS"
    printf '  %-16s %s\n' "Locale:"         "$LOCALE.UTF-8"
    printf '  %-16s %s\n' "Keyboard:"       "$KEYMAP"
    printf '  %-16s %s\n' "Timezone:"       "$TIMEZONE"
    printf '  %-16s %s\n' "Hostname:"       "$HOST_NAME"
    printf '  %-16s %s\n' "User:"           "$USERNAME"
    printf '  %-16s %s\n' "Filesystem:"     "$FS"
    printf '  %-16s %s\n' "Swap:"           "${SWAP_GB} GiB"
    printf '  %-16s %s\n' "Kernel:"         "$KERNEL"
    printf '  %-16s %s\n' "Binary pkgs:"    "$BINPKG"
    printf '  %-16s %s\n' "Build jobs:"     "$JOBS"
    printf '  %-16s %s\n' "Video cards:"    "${VIDEO:-(none detected)}"
    echo "${B}======================================================${N}"
    echo
    lsblk "$DISK"
    echo
    warn "ALL DATA ON $DISK WILL BE PERMANENTLY DESTROYED."
    local c
    read -r -p "Type YES (in capitals) to continue: " c || true
    [[ $c == YES ]] || die "Aborted. Nothing was changed."
}

# ----------------------------------------------------------------------------
# Disk work
# ----------------------------------------------------------------------------
partition_disk() {
    progress_update 4 "Partitioning $DISK (this erases the selected disk)"
    info "Partitioning $DISK (GPT)..."
    umount -R "$MNT" 2>/dev/null || true
    local p
    for p in $(lsblk -lnpo NAME "$DISK" | tac); do
        swapoff "$p" 2>/dev/null || true
        umount "$p" 2>/dev/null || true
    done
    wipefs -af "$DISK" >/dev/null

    local layout="label: gpt"$'\n'
    if [[ $BOOT == uefi ]]; then
        layout+="size=512MiB, type=U"$'\n'
    else
        layout+="size=1MiB, type=21686148-6449-6E6F-744E-656564454649"$'\n'
    fi
    local n=1
    P_BOOT=$(part $n); n=$((n + 1))
    if (( SWAP_GB > 0 )); then
        layout+="size=${SWAP_GB}GiB, type=S"$'\n'
        P_SWAP=$(part $n); n=$((n + 1))
    else
        P_SWAP=""
    fi
    layout+="type=L"$'\n'
    P_ROOT=$(part $n)

    printf '%s' "$layout" | sfdisk --wipe always --wipe-partitions always "$DISK" >/dev/null
    partprobe "$DISK" || true
    udevadm settle 2>/dev/null || true
    sleep 2
    ok "Partition table written"
}

format_disk() {
    progress_update 7 "Creating filesystems"
    info "Creating filesystems..."
    if [[ $BOOT == uefi ]]; then
        command -v mkfs.vfat >/dev/null || die "mkfs.vfat (dosfstools) not found."
        mkfs.vfat -F32 "$P_BOOT" >/dev/null
    fi
    [[ -n $P_SWAP ]] && mkswap -f "$P_SWAP" >/dev/null
    command -v "mkfs.$FS" >/dev/null || die "mkfs.$FS not found on this live system."
    case "$FS" in
        ext4)  mkfs.ext4 -F -q "$P_ROOT" ;;
        btrfs) mkfs.btrfs -f -q "$P_ROOT" ;;
        xfs)   mkfs.xfs -f -q "$P_ROOT" ;;
    esac
    udevadm settle 2>/dev/null || true

    ROOT_UUID=$(blkid -s UUID -o value "$P_ROOT")
    BOOT_UUID=""; SWAP_UUID=""
    [[ $BOOT == uefi ]] && BOOT_UUID=$(blkid -s UUID -o value "$P_BOOT")
    [[ -n $P_SWAP ]] && SWAP_UUID=$(blkid -s UUID -o value "$P_SWAP")
    ok "Filesystems created"
}

mount_disk() {
    progress_update 10 "Mounting the new Gentoo filesystem"
    info "Mounting to $MNT..."
    mkdir -p "$MNT"
    mount "$P_ROOT" "$MNT"
    if [[ $BOOT == uefi ]]; then
        mkdir -p "$MNT/efi"
        mount "$P_BOOT" "$MNT/efi"
    fi
    [[ -n $P_SWAP ]] && swapon "$P_SWAP"
    return 0
}

# ----------------------------------------------------------------------------
# Stage3
# ----------------------------------------------------------------------------
install_stage3() {
    local base="$MIRROR/releases/$ARCH/autobuilds"
    local list="$base/latest-stage3-$ARCH-$INIT.txt"

    progress_update 12 "Finding the latest Gentoo stage3 archive"
    info "Looking up the latest stage3 ($ARCH-$INIT)..."
    local rel
    rel=$(fetch_text "$list" | grep -E '\.tar\.(xz|zst)' | grep -v '^#' | awk '{print $1}' | head -n1 || true)
    [[ -n $rel ]] || die "Could not determine the latest stage3 from $list"
    local file=${rel##*/}
    if [[ $file == *.tar.zst ]]; then
        command -v zstd >/dev/null 2>&1 || die "The listed stage3 is zstd-compressed but zstd is missing."
    fi

    progress_update 16 "Downloading Gentoo stage3 archive"
    info "Downloading $file ..."
    fetch "$base/$rel" "$MNT/$file"

    progress_update 27 "Verifying the stage3 checksum"
    info "Verifying checksum..."
    local sumfile="$MNT/$file.sums" expected=""
    if fetch "$base/$rel.sha256" "$sumfile" 2>/dev/null; then :; else
        fetch "$base/$rel.DIGESTS" "$sumfile" 2>/dev/null || die "Could not download the checksum file."
    fi
    expected=$(awk -v f="$file" '
        length($1)==64 && ($2==f || $2=="*"f) {print $1; exit}
        $1=="SHA256" && $2=="("f")" && $3=="=" && length($4)==64 {print $4; exit}
    ' "$sumfile")
    [[ -n $expected ]] || die "Could not find the SHA256 for $file in the checksum file."
    local actual
    actual=$(sha256sum "$MNT/$file" | awk '{print $1}')
    [[ $expected == "$actual" ]] || die "SHA256 mismatch! Expected $expected, got $actual."
    ok "SHA256 verified"

    progress_update 29 "Verifying the Gentoo release signature"
    verify_signature "$base/$rel.asc" "$MNT/$file"

    progress_update 32 "Extracting stage3 into the target filesystem"
    info "Extracting stage3 (this takes a minute)..."
    tar xpf "$MNT/$file" -C "$MNT" --xattrs-include='*.*' --numeric-owner
    rm -f "$MNT/$file" "$sumfile" "$MNT/$file.asc"
    ok "Stage3 extracted"
}

verify_signature() {
    command -v gpg >/dev/null 2>&1 || die "gpg is required to verify the stage3 signature."
    local gnupg asc
    gnupg=$(mktemp -d)
    chmod 700 "$gnupg"
    asc="$2.asc"
    if ! fetch "$1" "$asc" 2>/dev/null; then
        rm -rf "$gnupg"
        die "Could not download the stage3 signature. Refusing to install an unverified stage3."
    fi
    # Use the live environment's Gentoo key bundle when available, and also
    # attempt both pinned Gentoo release fingerprints. Keyserver failures are
    # tolerated individually; verification itself remains mandatory.
    if [[ -f /usr/share/openpgp-keys/gentoo-release.asc ]]; then
        gpg --homedir "$gnupg" --quiet --import /usr/share/openpgp-keys/gentoo-release.asc 2>/dev/null \
            || warn "Could not import the local Gentoo key bundle; trying pinned fingerprints."
    fi
    local release_key
    for release_key in "$GENTOO_RELEASE_KEY" "$GENTOO_RELEASE_KEY_ALTERNATE"; do
        gpg --homedir "$gnupg" --quiet --keyserver hkps://keys.gentoo.org \
            --recv-keys "$release_key" >/dev/null 2>&1 || true
    done
    if gpg --homedir "$gnupg" --quiet --verify "$asc" "$2" 2>/dev/null; then
        ok "GPG signature verified"
    else
        rm -rf "$gnupg"
        die "GPG signature verification failed. Refusing to install this stage3."
    fi
    rm -rf "$gnupg"
}

# ----------------------------------------------------------------------------
# Host-side configuration & Chroot scripts
# ----------------------------------------------------------------------------
configure_target() {
    progress_update 37 "Writing the initial Gentoo configuration"
    info "Writing base configuration..."
    local mc="$MNT/etc/portage/make.conf"
    # Replace settings managed by this installer instead of accumulating duplicate
    # assignments. Keep conservative CFLAGS; -march=native gives little benefit
    # for this install and makes installed binaries less portable.
    sed -i -E '/^[[:space:]]*(COMMON_FLAGS|MAKEOPTS|EMERGE_DEFAULT_OPTS|PORTAGE_TMPDIR|ACCEPT_LICENSE|GENTOO_MIRRORS|VIDEO_CARDS|GRUB_PLATFORMS)=/d' "$mc"
    local common_flags="-O2 -pipe"
    # Avoid GCC's extra pipe buffers on very small-memory machines.
    (( RAM_MIB <= 4096 )) && common_flags="-O2"
    {
        echo
        echo "# --- Added by Gentoo Installation Script ---"
        printf 'COMMON_FLAGS="%s"\n' "$common_flags"
        printf 'MAKEOPTS="-j%s -l%s"\n' "$JOBS" "$JOBS"
        if [[ $BINPKG == yes ]]; then
            printf 'EMERGE_DEFAULT_OPTS="${EMERGE_DEFAULT_OPTS} --jobs=%s --load-average=%s"\n' "$PKG_JOBS" "$JOBS"
            echo 'FEATURES="${FEATURES} getbinpkg binpkg-request-signature"'
        else
            printf 'EMERGE_DEFAULT_OPTS="${EMERGE_DEFAULT_OPTS} --jobs=%s --load-average=%s"\n' "$PKG_JOBS" "$JOBS"
        fi
        echo 'PORTAGE_TMPDIR="/var/tmp/portage"'
        echo 'ACCEPT_LICENSE="@FREE @BINARY-REDISTRIBUTABLE intel-ucode"'
        printf 'GENTOO_MIRRORS="%s"\n' "$MIRROR"
        [[ -n $VIDEO ]] && printf 'VIDEO_CARDS="%s"\n' "$VIDEO"
        if [[ $BOOT == uefi ]]; then echo 'GRUB_PLATFORMS="efi-64"'; else echo 'GRUB_PLATFORMS="pc"'; fi
    } >> "$mc"
    cp --dereference /etc/resolv.conf "$MNT/etc/"

    {
        for v in INIT DE DM LOCALE KEYMAP TIMEZONE HOST_NAME USERNAME FS KERNEL BOOT DISK \
                 BINPKG SWAP_GB ROOT_UUID BOOT_UUID SWAP_UUID CPU_VENDOR JOBS RAM_MIB PKG_JOBS; do
            printf '%s=%q\n' "$v" "${!v}"
        done
    } > "$MNT/root/install.conf"
    chmod 600 "$MNT/root/install.conf"
}

mount_chroot() {
    progress_update 40 "Preparing the chroot environment"
    info "Preparing chroot..."
    mount --types proc /proc "$MNT/proc"
    mount --rbind /sys "$MNT/sys";  mount --make-rslave "$MNT/sys"
    mount --rbind /dev "$MNT/dev";  mount --make-rslave "$MNT/dev"
    mount --bind  /run "$MNT/run";  mount --make-slave  "$MNT/run"
    if [[ -n ${PROGRESS_FILE:-} && -e $PROGRESS_FILE ]]; then
        mkdir -p "$MNT/tmp"
        # The status file is bind-mounted so the chroot can update the same
        # file that the dashboard reads in the live environment.
        touch "$MNT/tmp/.gentoo-installer-progress"
        mount --bind "$PROGRESS_FILE" "$MNT/tmp/.gentoo-installer-progress"
    fi
}

write_chroot_script() {
    cat > "$MNT/root/chroot-setup.sh" <<'CHROOT'
#!/usr/bin/env bash
set -Eeo pipefail
set +u
source /etc/profile
source /root/install.conf
CHROOT_PROGRESS_FILE="/tmp/.gentoo-installer-progress"
progress_update() {
    local pct=${1:-0} message=${2:-}
    [[ -e $CHROOT_PROGRESS_FILE ]] || return 0
    message=${message//$'\t'/ }
    message=${message//$'\r'/ }
    message=${message//$'\n'/ }
    message=${message//|/\/}
    printf '%s|%s\n' "$pct" "$message" > "$CHROOT_PROGRESS_FILE"
}
trap 'progress_update 0 "FAILED: chroot setup near line $LINENO" || true; printf "\033[31m[x] chroot step failed at line %s: %s\033[0m\n" "$LINENO" "$BASH_COMMAND" >&2' ERR
step() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

# Keep full emerge output in the original terminal while parsing Portage's
# "Emerging (N of M)" lines to drive the dashboard progress bar.
emerge_progress() {
    local start=$1 end=$2 label=$3
    shift 3
    progress_update "$start" "$label"
    local -a pipe_status=()
    set +e
    emerge "$@" 2>&1 | tee /dev/tty | awk -v status_file="$CHROOT_PROGRESS_FILE" \
        -v start="$start" -v end="$end" -v label="$label" '
        />>> Emerging \([0-9]+ of [0-9]+\)/ {
            line=$0
            sub(/^.*>>> Emerging \(/, "", line)
            split(line, part, /[ )]/)
            current=part[1]+0
            total=part[3]+0
            if (total > 0) {
                pct=start + int((end-start) * current / total)
                printf "%d|%s (%d of %d packages)\n", pct, label, current, total > status_file
                close(status_file)
            }
        }
        ' >/dev/null
    pipe_status=("${PIPESTATUS[@]}")
    set -e
    local emerge_status=${pipe_status[0]:-1}
    if (( emerge_status != 0 )); then
        progress_update 0 "FAILED: $label"
        return "$emerge_status"
    fi
    progress_update "$end" "$label complete"
}

progress_update 41 "Syncing the Gentoo package tree (can take a while)"
step "Syncing the Portage tree"
emerge-webrsync
progress_update 44 "Gentoo package tree synchronized"

progress_update 45 "Selecting a Gentoo profile for $DE / $INIT"
step "Selecting profile"
case $DE in
    none)   profile_base="default/linux/amd64/23.0" ;;
    plasma) profile_base="default/linux/amd64/23.0/desktop/plasma" ;;
    gnome)  profile_base="default/linux/amd64/23.0/desktop/gnome" ;;
    *)      profile_base="default/linux/amd64/23.0/desktop" ;;
esac
profile_candidates=()
if [[ $INIT == systemd ]]; then
    profile_candidates+=("$profile_base/systemd"         "default/linux/amd64/23.0/desktop/systemd"         "default/linux/amd64/23.0/systemd")
else
    profile_candidates+=("$profile_base"         "default/linux/amd64/23.0/desktop"         "default/linux/amd64/23.0")
fi
profile_list=$(eselect profile list)
profile_index=""
selected_profile=""
for candidate in "${profile_candidates[@]}"; do
    profile_line=$(grep -E "[[:space:]]${candidate}([[:space:]]|$)" <<<"$profile_list" | head -n1 || true)
    profile_index=$(sed -nE 's/^[[:space:]]*\[([0-9]+)\].*/\1/p' <<<"$profile_line")
    if [[ -n $profile_index ]]; then
        selected_profile=$candidate
        break
    fi
done
[[ -n $profile_index ]] || { echo "No compatible Gentoo profile found for $DE / $INIT." >&2; exit 1; }
eselect profile set "$profile_index"
eselect profile show
progress_update 46 "Selected profile: $selected_profile"

if [[ $BINPKG == yes ]]; then
    progress_update 47 "Configuring the official binary-package repository"
    step "Setting up Gentoo binary repository host"
    mkdir -p /etc/portage/binrepos.conf
    binhost_profile=${selected_profile#default/linux/amd64/}
    cat > /etc/portage/binrepos.conf/gentoobinhost.conf <<EOF
[gentoobinhost]
priority = 9999
sync-uri = https://distfiles.gentoo.org/releases/amd64/binpackages/${binhost_profile}/x86-64/
EOF
    getuto
    progress_update 48 "Binary repository configured"
fi

progress_update 49 "Configuring Portage package settings"
step "Portage package settings"
mkdir -p /etc/portage/package.use
echo "sys-kernel/installkernel dracut grub" > /etc/portage/package.use/installkernel
echo "net-misc/networkmanager wifi"         > /etc/portage/package.use/networkmanager
if [[ $DE == plasma && $DM != sddm ]]; then
    echo "kde-plasma/plasma-meta -sddm" > /etc/portage/package.use/desktop-display-manager
elif [[ $DE == plasma && $DM == sddm ]]; then
    echo "kde-plasma/plasma-meta +sddm" > /etc/portage/package.use/desktop-display-manager
fi
if [[ $DE == lxqt && $DM != sddm ]]; then
    echo "lxqt-base/lxqt-meta -sddm" >> /etc/portage/package.use/desktop-display-manager
elif [[ $DE == lxqt && $DM == sddm ]]; then
    echo "lxqt-base/lxqt-meta +sddm" >> /etc/portage/package.use/desktop-display-manager
fi

progress_update 50 "Configuring locale, keyboard, timezone, and hostname"
step "Timezone, locale, keyboard, hostname"
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
echo "$TIMEZONE" > /etc/timezone
{ echo "en_US.UTF-8 UTF-8"; echo "$LOCALE.UTF-8 UTF-8"; } | sort -u > /etc/locale.gen
locale-gen
printf 'LANG="%s.UTF-8"\nLC_COLLATE="C.UTF-8"\n' "$LOCALE" > /etc/env.d/02locale
env-update

if [[ $INIT == openrc ]]; then
    sed -i "s/^keymap=.*/keymap=\"$KEYMAP\"/" /etc/conf.d/keymaps || true
else
    echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf
fi
echo "$HOST_NAME" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1   localhost $HOST_NAME
::1         localhost $HOST_NAME
EOF
source /etc/profile
progress_update 52 "Base system settings configured"

step "Writing /etc/fstab"
fsck=0; [[ $FS == ext4 ]] && fsck=1
{
    echo "# <fs>  <mountpoint>  <type>  <opts>  <dump> <pass>"
    echo "UUID=$ROOT_UUID  /       $FS    defaults,noatime  0 $fsck"
    [[ $BOOT == uefi ]] && echo "UUID=$BOOT_UUID  /efi    vfat    umask=0077,noatime  0 2"
    [[ -n $SWAP_UUID ]] && echo "UUID=$SWAP_UUID  none    swap    sw  0 0"
} > /etc/fstab

step "Installing kernel and bootloader"
emerge_progress 54 58 "Installing GRUB and installkernel" sys-boot/grub sys-kernel/installkernel
fw=(sys-kernel/linux-firmware)
[[ $CPU_VENDOR == GenuineIntel ]] && fw+=(sys-firmware/intel-microcode)
emerge_progress 58 61 "Installing firmware" "${fw[@]}"
emerge_progress 61 67 "Installing the selected kernel" "$KERNEL"

if [[ $BOOT == uefi ]]; then
    grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=Gentoo || true
    grub-install --target=x86_64-efi --efi-directory=/efi --removable
else
    grub-install --target=i386-pc "$DISK"
fi
grub-mkconfig -o /boot/grub/grub.cfg

step "Installing base tools and desktop packages"
pkgs=(net-misc/networkmanager app-admin/sudo)
[[ $BOOT == uefi ]] && pkgs+=(sys-fs/dosfstools)
[[ $FS == btrfs ]] && pkgs+=(sys-fs/btrfs-progs)
[[ $FS == xfs ]]   && pkgs+=(sys-fs/xfsprogs)
[[ $INIT == openrc ]] && pkgs+=(app-admin/sysklogd sys-process/cronie)

if [[ $DE != none ]]; then
    case $DE in
        plasma)   de_pkgs=(kde-plasma/plasma-meta kde-apps/dolphin kde-apps/konsole) ;;
        gnome)    de_pkgs=(gnome-base/gnome-light) ;;
        xfce)     de_pkgs=(x11-base/xorg-server xfce-base/xfce4-meta x11-terms/xfce4-terminal) ;;
        lxqt)     de_pkgs=(x11-base/xorg-server lxqt-base/lxqt-meta) ;;
        mate)     de_pkgs=(x11-base/xorg-server mate-base/mate) ;;
        cinnamon) de_pkgs=(x11-base/xorg-server gnome-extra/cinnamon) ;;
        lxde)     de_pkgs=(x11-base/xorg-server lxde-base/lxde-meta) ;;
        i3)       de_pkgs=(x11-base/xorg-server x11-wm/i3 x11-misc/i3status x11-misc/dmenu x11-terms/xterm) ;;
        sway)     de_pkgs=(gui-wm/sway gui-apps/foot gui-apps/waybar) ;;
        openbox)  de_pkgs=(x11-base/xorg-server x11-wm/openbox x11-misc/obconf x11-terms/xterm) ;;
    esac
    case $DM in
        sddm)    de_pkgs+=(x11-misc/sddm) ;;
        lightdm) de_pkgs+=(x11-misc/lightdm x11-misc/lightdm-gtk-greeter) ;;
        gdm)     de_pkgs+=(gnome-base/gdm) ;;
    esac
    if [[ $INIT == openrc ]]; then
        de_pkgs+=(sys-auth/elogind sys-apps/dbus)
        [[ -n $DM ]] && de_pkgs+=(gui-libs/display-manager-init)
        [[ $DE == gnome ]] && de_pkgs+=(gnome-base/gnome-session-openrc)
    else
        de_pkgs+=(sys-apps/dbus)
    fi
    de_pkgs+=(www-client/firefox-bin)
    pkgs+=("${de_pkgs[@]}")
fi

emerge_progress 70 92 "Installing base tools and desktop environment" "${pkgs[@]}"

progress_update 93 "Enabling network and desktop services"
step "Enabling services"
if [[ $INIT == openrc ]]; then
    rc-update add NetworkManager default
    rc-update add sysklogd default
    rc-update add cronie default
    if [[ $DE != none ]]; then
        rc-update add elogind boot
        rc-update add dbus default
        if [[ -n $DM ]]; then
            if [[ -f /etc/conf.d/display-manager ]]; then
                if grep -q '^DISPLAYMANAGER=' /etc/conf.d/display-manager; then
                    sed -i "s/^DISPLAYMANAGER=.*/DISPLAYMANAGER=\"$DM\"/" /etc/conf.d/display-manager
                else
                    echo "DISPLAYMANAGER=\"$DM\"" >> /etc/conf.d/display-manager
                fi
            else
                echo "DISPLAYMANAGER=\"$DM\"" > /etc/conf.d/display-manager
            fi
            rc-update add display-manager default
        fi
    fi
else
    systemd-machine-id-setup
    systemctl preset-all --preset-mode=enable-only || true
    systemctl enable NetworkManager
    [[ -n $DM ]] && systemctl enable "$DM"
fi

progress_update 96 "Creating the regular user and sudo configuration"
step "Creating user $USERNAME"
getent group wheel >/dev/null || groupadd wheel
groups=()
for g in wheel users audio video input; do getent group "$g" >/dev/null && groups+=("$g"); done
useradd -m -G "$(IFS=,; echo "${groups[*]}")" -s /bin/bash "$USERNAME"
mkdir -p /etc/sudoers.d
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel
if command -v visudo >/dev/null 2>&1; then
    visudo -cf /etc/sudoers.d/wheel
fi

progress_update 97 "Gentoo system configuration finished"
step "Chroot setup finished"
CHROOT
    chmod +x "$MNT/root/chroot-setup.sh"
}

run_chroot() {
    write_chroot_script
    progress_update 41 "Installing and configuring Gentoo inside the chroot"
    info "Entering chroot to install the system..."
    chroot "$MNT" /bin/bash /root/chroot-setup.sh \
        || die "Installation inside the chroot failed."
}

set_passwords() {
    progress_update 98 "Setting the root and user passwords"
    info "Setting passwords..."
    printf 'root:%s\n' "$ROOT_PW" | chroot "$MNT" chpasswd
    printf '%s:%s\n' "$USERNAME" "$USER_PW" | chroot "$MNT" chpasswd
}

finish() {
    progress_update 99 "Finalizing installation and unmounting filesystems"
    rm -f "$MNT/root/install.conf" "$MNT/root/chroot-setup.sh"
    sync
    info "Unmounting..."
    umount -l -R "$MNT" 2>/dev/null || true
    [[ -n $P_SWAP ]] && swapoff "$P_SWAP" 2>/dev/null || true
    progress_update 100 "Installation complete. Remove the live media and reboot when ready."
    echo
    ok "${B}Gentoo is installed.${N} Remove the installation media, then reboot."
    local c
    read -r -p "Reboot now? [y/N]: " c || true
    [[ $c =~ ^[Yy]$ ]] && reboot
    return 0
}

main() {
    banner
    preflight
    gather_config
    validate_selected_tools
    confirm_config
    start_dashboard
    progress_update 3 "Installation confirmed; preparing the selected disk"
    partition_disk
    format_disk
    mount_disk
    install_stage3
    configure_target
    mount_chroot
    run_chroot
    set_passwords
    finish
}
main "$@"
