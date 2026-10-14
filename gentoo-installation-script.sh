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

VERSION="0.1.2"
MNT="/mnt/gentoo"
ARCH="amd64"
MIRROR="${GENTOO_MIRROR:-https://distfiles.gentoo.org}"
GENTOO_RELEASE_KEY="13EBBDBEDE7A12775DFDB1BABB572E0E2D182910"

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
die()  { printf '%s[x]%s %s\n' "$R" "$N" "$*" >&2; exit 1; }
trap 'printf "%s[x]%s Failed at line %s: %s\n" "$R" "$N" "$LINENO" "$BASH_COMMAND" >&2' ERR

usage() {
    cat <<EOF
Gentoo Installation Script v$VERSION

Usage: bash $(basename "$0") [--help] [--version]

Interactive installer: asks about your disk, init system, desktop, language,
and so on, downloads the official stage3 tarball, and installs Gentoo.

Environment:
  GENTOO_MIRROR    Mirror base URL (default: https://distfiles.gentoo.org)
EOF
}
case "${1:-}" in
    -h|--help) usage; exit 0 ;;
    -v|--version) echo "$VERSION"; exit 0 ;;
esac

# Make sure we can read from the keyboard even if piped (curl ... | bash)
[[ -t 0 ]] || exec </dev/tty

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
    for t in lsblk sfdisk wipefs blkid tar chroot sha256sum partprobe mount umount awk sed grep xz; do
        command -v "$t" >/dev/null 2>&1 || missing+=("$t")
    done
    command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || missing+=("curl or wget")
    (( ${#missing[@]} == 0 )) || die "Missing required tools: ${missing[*]}"

    if [[ -d /sys/firmware/efi/efivars ]]; then BOOT=uefi; else BOOT=bios; fi
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

    choose DE_LABEL "Desktop environment" \
        "None (command-line only / server)" \
        "KDE Plasma" \
        "GNOME" \
        "XFCE" \
        "i3 (tiling window manager)"
    case "$DE_LABEL" in
        None*)  DE=none;   DM="" ;;
        KDE*)   DE=plasma; DM=sddm ;;
        GNOME*) DE=gnome;  DM=gdm ;;
        XFCE*)  DE=xfce;   DM=lightdm ;;
        i3*)    DE=i3;     DM=lightdm ;;
    esac

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

    while :; do
        ask SWAP_GB "Swap partition size in GiB (0 for none)" "4"
        [[ $SWAP_GB =~ ^[0-9]+$ ]] && break
        warn "Enter a whole number."
    done

    choose KERNEL_LABEL "Kernel" \
        "Gentoo binary kernel (gentoo-kernel-bin, fast)" \
        "Gentoo distribution kernel, compiled from source (gentoo-kernel)"
    [[ $KERNEL_LABEL == *bin* ]] && KERNEL=sys-kernel/gentoo-kernel-bin || KERNEL=sys-kernel/gentoo-kernel

    choose BIN_LABEL "Package installation method" \
        "Use official Gentoo binary packages where possible (MUCH faster, saves RAM)" \
        "Compile everything from source (slow, optimized with -march=native)"
    [[ $BIN_LABEL == Use* ]] && BINPKG=yes || BINPKG=no

    local cores mem
    cores=$(nproc)
    mem=$(awk '/MemTotal/ {print int($2/1024/1024/2)}' /proc/meminfo)
    (( mem < 1 )) && mem=1
    JOBS=$(( cores < mem ? cores : mem ))

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

confirm_config() {
    echo
    echo "${B}================ Installation summary ================${N}"
    printf '  %-16s %s\n' "Target disk:"    "$DISK  ($(lsblk -dno SIZE "$DISK"))"
    printf '  %-16s %s\n' "Boot mode:"      "${BOOT^^}"
    printf '  %-16s %s\n' "Init system:"    "$INIT"
    printf '  %-16s %s\n' "Desktop:"        "$DE_LABEL"
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
    [[ -n $P_SWAP ]] && SWAP_UUID=$(blkid -s UUID -o value "$P_SWPS" 2>/dev/null || blkid -s UUID -o value "$P_SWAP")
    ok "Filesystems created"
}

mount_disk() {
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

    info "Looking up the latest stage3 ($ARCH-$INIT)..."
    local rel
    rel=$(fetch_text "$list" | grep -E '\.tar\.(xz|zst)' | grep -v '^#' | awk '{print $1}' | head -n1 || true)
    [[ -n $rel ]] || die "Could not determine the latest stage3 from $list"
    local file=${rel##*/}

    info "Downloading $file ..."
    fetch "$base/$rel" "$MNT/$file"

    info "Verifying checksum..."
    local sumfile="$MNT/$file.sums" expected=""
    if fetch "$base/$rel.sha256" "$sumfile" 2>/dev/null; then :; else
        fetch "$base/$rel.DIGESTS" "$sumfile" 2>/dev/null || die "Could not download the checksum file."
    fi
    expected=$(awk -v f="$file" 'length($1)==64 && ($2==f || $2=="*"f) {print $1; exit}' "$sumfile")
    [[ -n $expected ]] || die "Could not find the SHA256 for $file in the checksum file."
    local actual
    actual=$(sha256sum "$MNT/$file" | awk '{print $1}')
    [[ $expected == "$actual" ]] || die "SHA256 mismatch! Expected $expected, got $actual."
    ok "SHA256 verified"

    verify_signature "$base/$rel.asc" "$MNT/$file"

    info "Extracting stage3 (this takes a minute)..."
    tar xpf "$MNT/$file" -C "$MNT" --xattrs-include='*.*' --numeric-owner
    rm -f "$MNT/$file" "$sumfile" "$MNT/$file.asc"
    ok "Stage3 extracted"
}

verify_signature() {
    command -v gpg >/dev/null 2>&1 || { warn "gpg not found; skipping signature check."; return 0; }
    local gnupg; gnupg=$(mktemp -d); chmod 700 "$gnupg"
    local asc="$2.asc"
    if ! fetch "$1" "$asc" 2>/dev/null; then rm -rf "$gnupg"; return 0; fi
    if [[ -f /usr/share/openpgp-keys/gentoo-release.asc ]]; then
        gpg --homedir "$gnupg" --quiet --import /usr/share/openpgp-keys/gentoo-release.asc 2>/dev/null || true
    else
        gpg --homedir "$gnupg" --quiet --keyserver hkps://keys.gentoo.org --recv-keys "$GENTOO_RELEASE_KEY" 2>/dev/null || true
    fi
    if gpg --homedir "$gnupg" --quiet --verify "$asc" "$2" 2>/dev/null; then
        ok "GPG signature verified"
    else
        warn "Could not verify GPG signature, continuing."
    fi
    rm -rf "$gnupg"
}

# ----------------------------------------------------------------------------
# Host-side configuration & Chroot scripts
# ----------------------------------------------------------------------------
configure_target() {
    info "Writing base configuration..."
    local mc="$MNT/etc/portage/make.conf"
    if [[ $BINPKG == no ]]; then
        sed -i 's/^COMMON_FLAGS=.*/COMMON_FLAGS="-march=native -O2 -pipe"/' "$mc"
    else
        sed -i 's/^COMMON_FLAGS=.*/COMMON_FLAGS="-O2 -pipe"/' "$mc"
    fi
    {
        echo
        echo "# --- Added by Gentoo Installation Script ---"
        echo "MAKEOPTS=\"-j$JOBS\""
        echo "ACCEPT_LICENSE=\"*\""
        echo "GENTOO_MIRRORS=\"$MIRROR\""
        [[ -n $VIDEO ]] && echo "VIDEO_CARDS=\"$VIDEO\""
        if [[ $BOOT == uefi ]]; then echo 'GRUB_PLATFORMS="efi-64"'; else echo 'GRUB_PLATFORMS="pc"'; fi
        
        # Inject binary package configuration directly here if enabled!
        if [[ $BINPKG == yes ]]; then
            echo 'FEATURES="${FEATURES} getbinpkg binpkg-request-signature"'
            echo 'EMERGE_DEFAULT_OPTS="${EMERGE_DEFAULT_OPTS} --getbinpkg"'
        fi
    } >> "$mc"

    cp --dereference /etc/resolv.conf "$MNT/etc/"

    {
        for v in INIT DE DM LOCALE KEYMAP TIMEZONE HOST_NAME USERNAME FS KERNEL BOOT DISK \
                 BINPKG SWAP_GB ROOT_UUID BOOT_UUID SWAP_UUID CPU_VENDOR; do
            printf '%s=%q\n' "$v" "${!v}"
        done
    } > "$MNT/root/install.conf"
    chmod 600 "$MNT/root/install.conf"
}

mount_chroot() {
    info "Preparing chroot..."
    mount --types proc /proc "$MNT/proc"
    mount --rbind /sys "$MNT/sys";  mount --make-rslave "$MNT/sys"
    mount --rbind /dev "$MNT/dev";  mount --make-rslave "$MNT/dev"
    mount --bind  /run "$MNT/run";  mount --make-slave  "$MNT/run"
}

write_chroot_script() {
    cat > "$MNT/root/chroot-setup.sh" <<'CHROOT'
#!/usr/bin/env bash
set -Eeo pipefail
set +u
source /etc/profile
source /root/install.conf
trap 'printf "\033[31m[x] chroot step failed at line %s: %s\033[0m\n" "$LINENO" "$BASH_COMMAND" >&2' ERR
step() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

step "Syncing the Portage tree"
emerge-webrsync

step "Selecting profile"
case $DE in
    none)   base="default/linux/amd64/23.0" ;;
    plasma) base="default/linux/amd64/23.0/desktop/plasma" ;;
    gnome)  base="default/linux/amd64/23.0/desktop/gnome" ;;
    *)      base="default/linux/amd64/23.0/desktop" ;;
esac
prof=$base
[[ $INIT == systemd ]] && prof="$base/systemd"
if eselect profile list | grep -qE "[[:space:]]${prof}[[:space:]]"; then
    eselect profile set "$prof"
fi
eselect profile show

if [[ $BINPKG == yes ]]; then
    step "Setting up Gentoo binary repository host"
    mkdir -p /etc/portage/binrepos.conf
    cat > /etc/portage/binrepos.conf/gentoobinhost.conf <<EOF
[gentoobinhost]
priority = 9999
sync-uri = https://distfiles.gentoo.org/releases/amd64/binpackages/23.0/x86-64/
EOF
    getuto || true
fi

step "Portage package settings"
mkdir -p /etc/portage/package.use
echo "sys-kernel/installkernel dracut grub" > /etc/portage/package.use/installkernel
echo "net-misc/networkmanager wifi"         > /etc/portage/package.use/networkmanager

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

step "Writing /etc/fstab"
fsck=0; [[ $FS == ext4 ]] && fsck=1
{
    echo "# <fs>  <mountpoint>  <type>  <opts>  <dump> <pass>"
    echo "UUID=$ROOT_UUID  /       $FS    defaults,noatime  0 $fsck"
    [[ $BOOT == uefi ]] && echo "UUID=$BOOT_UUID  /efi    vfat    umask=0077,noatime  0 2"
    [[ -n $SWAP_UUID ]] && echo "UUID=$SWAP_UUID  none    swap    sw  0 0"
} > /etc/fstab

step "Installing kernel and bootloader"
emerge -q sys-boot/grub sys-kernel/installkernel
fw=(sys-kernel/linux-firmware)
[[ $CPU_VENDOR == GenuineIntel ]] && fw+=(sys-firmware/intel-microcode)
emerge -q "${fw[@]}"
emerge -q "$KERNEL"

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
        plasma) de_pkgs=(kde-plasma/plasma-meta kde-apps/dolphin kde-apps/konsole x11-misc/sddm) ;;
        gnome)  de_pkgs=(gnome-base/gnome-light gnome-base/gdm) ;;
        xfce)   de_pkgs=(x11-base/xorg-server xfce-base/xfce4-meta x11-terms/xfce4-terminal x11-misc/lightdm x11-misc/lightdm-gtk-greeter) ;;
        i3)     de_pkgs=(x11-base/xorg-server x11-wm/i3 x11-misc/i3status x11-misc/dmenu x11-terms/xterm x11-misc/lightdm x11-misc/lightdm-gtk-greeter) ;;
    esac
    [[ $INIT == openrc ]] && de_pkgs+=(gui-libs/display-manager-init)
    de_pkgs+=(www-client/firefox-bin)
    pkgs+=("${de_pkgs[@]}")
fi

emerge -q "${pkgs[@]}"

step "Enabling services"
if [[ $INIT == openrc ]]; then
    rc-update add NetworkManager default
    rc-update add sysklogd default
    rc-update add cronie default
    if [[ $DE != none ]]; then
        rc-update add elogind boot
        rc-update add dbus default
        sed -i "s/^DISPLAYMANAGER=.*/DISPLAYMANAGER=\"$DM\"/" /etc/conf.d/display-manager
        rc-update add display-manager default
    fi
else
    systemd-machine-id-setup
    systemctl preset-all --preset-mode=enable-only || true
    systemctl enable NetworkManager
    [[ $DE != none ]] && systemctl enable "$DM"
fi

step "Creating user $USERNAME"
groups=()
for g in wheel users audio video input; do getent group "$g" >/dev/null && groups+=("$g"); done
useradd -m -G "$(IFS=,; echo "${groups[*]}")" -s /bin/bash "$USERNAME"
mkdir -p /etc/sudoers.d
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

step "Chroot setup finished"
CHROOT
    chmod +x "$MNT/root/chroot-setup.sh"
}

run_chroot() {
    write_chroot_script
    info "Entering chroot to install the system..."
    chroot "$MNT" /bin/bash /root/chroot-setup.sh \
        || die "Installation inside the chroot failed."
}

set_passwords() {
    info "Setting passwords..."
    printf 'root:%s\n' "$ROOT_PW" | chroot "$MNT" chpasswd
    printf '%s:%s\n' "$USERNAME" "$USER_PW" | chroot "$MNT" chpasswd
}

finish() {
    rm -f "$MNT/root/install.conf" "$MNT/root/chroot-setup.sh"
    sync
    info "Unmounting..."
    umount -l -R "$MNT" 2>/dev/null || true
    [[ -n $P_SWAP ]] && swapoff "$P_SWAP" 2>/dev/null || true
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
    confirm_config
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
