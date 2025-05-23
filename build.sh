#!/usr/bin/env bash
set -euo pipefail

workdir=$(pwd)
exec > >(tee "$workdir/build.log") 2>&1

# Import config and functions
source "$workdir/config.sh"
source "$workdir/functions.sh"

# Set up timezone
sudo timedatectl set-timezone "$TIMEZONE"

# Clone patches
SHIRKNEKO_PATCHES=https://github.com/ShirkNeko/SukiSU_patch
log "Cloning patches from $(simplify_gh_url "$SHIRKNEKO_PATCHES")"
git clone -q --depth=1 "$SHIRKNEKO_PATCHES" "$workdir/shirkneko_patches"

# Clone kernel source
log "Cloning kernel source from $(simplify_gh_url "$KERNEL_REPO")"
git clone -q --depth=1 "$KERNEL_REPO" -b "$KERNEL_BRANCH" "$workdir/ksrc"

cd "$workdir/ksrc"
LINUX_VERSION=$(make kernelversion)
DEFCONFIG_FILE=$(find "$workdir/ksrc/arch/${KERNEL_ARCH}/configs" -name "$KERNEL_DEFCONFIG")
cd "$workdir"

# Set KernelSU variant
log "Setting KernelSU variant..."
declare -A KSU_VARIANTS=(
    ["Official"]="KSU"
    ["Next"]="KSUN"
    ["Suki"]="SUKISU"
)
VARIANT="${KSU_VARIANTS[$KSU]:-NKSU}"
[[ "$KSU_SUSFS" == "true" ]] && VARIANT+="xSUSFS"

# Replace placeholders in zip name
ZIP_NAME=${ZIP_NAME//KVER/$LINUX_VERSION}
ZIP_NAME=${ZIP_NAME//VARIANT/$VARIANT}
ZIP_NAME=${ZIP_NAME//CODENAME/$DEVICE_CODENAME}

# Download Clang
CLANG_PATH="$workdir/clang"
log "Downloading Clang..."
if [[ -z "$CLANG_BRANCH" ]]; then
    mkdir -p "$CLANG_PATH"
    wget -qO clang-tarball "$CLANG_URL" || error "Failed to download Clang."
    tar -xf clang-tarball -C "$CLANG_PATH/" || error "Failed to extract Clang."
    rm -f clang-tarball
    
    if [[ $(find "$CLANG_PATH" -mindepth 1 -maxdepth 1 -type d | wc -l) -eq 1 ]] &&
       [[ $(find "$CLANG_PATH" -mindepth 1 -maxdepth 1 -type f | wc -l) -eq 0 ]]; then
        single_dir=$(find "$CLANG_PATH" -mindepth 1 -maxdepth 1 -type d)
        mv "$single_dir"/* "$CLANG_PATH"/
        rm -rf "$single_dir"
    fi
else
    git clone --depth=1 -q "$CLANG_URL" -b "$CLANG_BRANCH" "$CLANG_PATH" || error "Failed to clone clang"
fi

export PATH="$CLANG_PATH/bin:$PATH"
COMPILER_STRING=$(clang -v 2>&1 | head -n 1 | sed 's/(https..*//' | sed 's/ version//')

cd "$workdir/ksrc"
# Install KernelSU
if [[ "$KSU" != "None" ]]; then
    log "Installing KernelSU..."
    case "$KSU" in
        "Official") install_ksu tiann/KernelSU ;;
        "Next") install_ksu rifsxd/KernelSU-Next $([[ "$KSU_SUSFS" == true ]] && echo next-susfs) ;;
        "Suki") install_ksu ShirkNeko/SukiSU-Ultra $([[ "$KSU_SUSFS" == true ]] && echo susfs-dev) ;;
        *) error "Invalid KSU value: $KSU" ;;
    esac
fi

# Apply KSU Manual Hooks patch
if [[ "$KSU_MANUAL_HOOK" == "true" ]]; then
    config --enable CONFIG_KSU_MANUAL_HOOK
    config --disable CONFIG_KSU_WITH_KPROBE
    config --disable CONFIG_KSU_SUSFS_SUS_SU
    log "Applying KSU Manual Hooks patch..."
    patch -p1 < "$workdir/patches/0001*" || error "Failed to apply KSU Manual Hooks patch."
fi

# SUSFS for KSU setup
if [[ "$KSU_SUSFS" == "true" ]]; then
    log "Cloning susfs4ksu..."
    git clone -q --depth=1 https://gitlab.com/simonpunk/susfs4ksu -b kernel-4.14 "$workdir/susfs4ksu"
    log "Applying kernel-side susfs patch"
    patch -p1 < "$workdir/patches/0002*" || error "Failed to apply kernel-side susfs patch"
    SUSFS_VERSION=$(grep -E '^#define SUSFS_VERSION' ./include/linux/susfs.h | cut -d' ' -f3 | sed 's/\"//g')
    if [[ "$KSU" == "Official" ]]; then
        cd "$workdir/ksrc/KernelSU"
        log "Applying KernelSU-side susfs patch"
        patch -p1 < "$workdir/susfs4ksu/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch" || error "Failed to apply KernelSU-side susfs patch"
    fi
fi

cd "$workdir/ksrc"
# set localversion
if [[ "$TODO" == "kernel" ]]; then
    COMMIT_HASH=$(git rev-parse --short HEAD)
    config --set-str CONFIG_LOCALVERSION "-$KERNEL_NAME/$COMMIT_HASH"
fi

# Enable KPM for SukiSU
if [[ "$KSU" == "Suki" ]]; then
    config --enable CONFIG_KPM
fi

# Declare build info
export KBUILD_BUILD_USER="$BUILD_USER"
export KBUILD_BUILD_HOST="$BUILD_HOST"
export KBUILD_BUILD_TIMESTAMP=$(date)
export BUILD_DATE=$(date -d "$KBUILD_BUILD_TIMESTAMP" +"%Y%m%d-%H%M")

text="""*=== $KERNEL_NAME CI ===*
🐧 *Linux Version*: \`$LINUX_VERSION\`
📅 *Build Date*: \`$KBUILD_BUILD_TIMESTAMP\`
📱 *Device*: \`$DEVICE_MODEL ($DEVICE_CODENAME)\`
📛 *KernelSU*: \`${KSU}$([[ "$KSU" != "None" ]] && echo " | $KSU_VERSION")\`
ඞ *SUSFS*: \`$([[ "$KSU_SUSFS" == "true" ]] && echo "$SUSFS_VERSION" || echo "None")\`
🔰 *Compiler*: \`$COMPILER_STRING\`"""

MESSAGE_ID=$(send_msg "$text" 2>&1 | jq -r .result.message_id)

# Set build output name
ZIP_NAME=${ZIP_NAME//BUILD_DATE/$BUILD_DATE}
KERNEL_IMAGE="$workdir/ksrc/out/arch/arm64/boot/Image.gz-dtb"

# Build kernel
cd "$workdir/ksrc"
log "Generating config..."
make O=out ARCH=arm64 CC=clang LLVM=1 CROSS_COMPILE=aarch64-linux-android- CROSS_COMPILE_ARM32=arm-linux-androideabi- CLANG_TRIPLE=aarch64-linux-gnu- "$KERNEL_DEFCONFIG"

if [[ "$TODO" == "defconfig" ]]; then
    log "Uploading defconfig..."
    upload_file "$workdir/ksrc/out/.config"
    exit 0
fi

log "Building kernel..."
make -j$(nproc --all) O=out ARCH=arm64 CC=clang LLVM=1 CROSS_COMPILE=aarch64-linux-android- CROSS_COMPILE_ARM32=arm-linux-androideabi- CLANG_TRIPLE=aarch64-linux-gnu-

if [[ ! -f "$KERNEL_IMAGE" ]]; then
    error "Build failed: Kernel image not found."
fi

# Patch SUKISU
if [[ "$KSU" == "Suki" ]]; then
    mkdir -p sukisu-patch && cd sukisu-patch
    cp "$workdir/shirkneko_patches/kpm/patch_linux" .
    chmod +x patch_linux
    cp $(dirname "$KERNEL_IMAGE")/Image .
    cp $(dirname "$KERNEL_IMAGE")/dts/qcom/*.dtb .
    sudo ./patch_linux || error "Failed to patch kernel with SukiSU."
    mv oImage Image
    gzip -n -f -9 -k Image
    cat Image.gz *.dtb > Image.gz-dtb
    KERNEL_IMAGE="$(pwd)/Image.gz-dtb"
fi

cd "$workdir"
log "Cloning anykernel from $(simplify_gh_url "$ANYKERNEL_REPO")"
git clone -q --depth=1 "$ANYKERNEL_REPO" -b "$ANYKERNEL_BRANCH" anykernel

cd anykernel
log "Zipping anykernel..."
cp "$KERNEL_IMAGE" .
zip -r9 "$workdir/$ZIP_NAME" ./*

cd "$workdir"
reply_file "$MESSAGE_ID" "$workdir/$ZIP_NAME"
exit 0
