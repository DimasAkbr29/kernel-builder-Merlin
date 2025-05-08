#!/usr/bin/env bash
workdir=$(pwd)
exec > >(tee $workdir/build.log) 2>&1

# Import config and functions
source $workdir/config.sh
source $workdir/functions.sh

# Set up timezone
sudo timedatectl set-timezone "$TIMEZONE"

# Clone patches
SHIRKNEKO_PATCHES=https://github.com/ShirkNeko/SukiSU_patch
log "Cloning patches from $(simplify_gh_url "$SHIRKNEKO_PATCHES")"
git clone -q --depth=1 $SHIRKNEKO_PATCHES $workdir/shirkneko_patches

# Clone kernel source
log "Cloning kernel source from $(simplify_gh_url "$KERNEL_REPO")"
git clone -q --depth=1 $KERNEL_REPO -b $KERNEL_BRANCH $workdir/ksrc

cd $workdir/ksrc
LINUX_VERSION=$(make kernelversion)
DEFCONFIG_FILE=$(find $workdir/ksrc/arch/${KERNEL_ARCH}/configs -name "$KERNEL_DEFCONFIG")
cd $workdir

# Set KernelSU variant
log "Setting KernelSU variant..."
declare -A KSU_VARIANTS=(
    ["Official"]="KSU"
    ["Next"]="KSUN"
    ["Suki"]="SUKISU"
)
VARIANT="${KSU_VARIANTS[$KSU]:-NKSU}"
[[ $KSU_SUSFS == "true" ]] && VARIANT+="xSUSFS"

# Replace Placeholder in zip name
ZIP_NAME=${ZIP_NAME//KVER/$LINUX_VERSION}
ZIP_NAME=${ZIP_NAME//VARIANT/$VARIANT}
ZIP_NAME=${ZIP_NAME//CODENAME/$DEVICE_CODENAME}

# Download Clang
CLANG_PATH="$workdir/clang"

log "🔽 Downloading Clang..."
if [[ -z $CLANG_BRANCH ]]; then
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
    git clone --depth=1 -q $CLANG_URL -b $CLANG_BRANCH $CLANG_PATH || error "Failed to clone clang"
fi

export PATH="$CLANG_PATH/bin:$PATH"

# Extract clang version
COMPILER_STRING=$(clang -v 2>&1 | head -n 1 | sed 's/(https..*//' | sed 's/ version//')

cd $workdir/ksrc
# Install KernelSU
if [[ $KSU != "None" ]]; then
    log "Installing KernelSU..."

    case "$KSU" in
    "Official") install_ksu tiann/KernelSU ;;
    "Next") install_ksu rifsxd/KernelSU-Next $([[ $KSU_SUSFS == true ]] && echo next-susfs) ;;
    "Suki") install_ksu ShirkNeko/SukiSU-Ultra $([[ $KSU_SUSFS == true ]] && echo susfs-dev) ;;
    *) error "Invalid KSU value: $KSU" ;;
    esac

    # Apply ksu patches
    # kata rsuntk biar modulnya gk ngilang
    log "Applying KSU Patches for 4.9 Kernel"
    for i in $workdir/ksu_patches/0002* $workdir/ksu_patches/0003*; do
        if ! patch -p1 <$i; then
            error "Failed to apply $(basename $i)"
        fi
    done
fi

# Apply KSU Manual Hooks patch
if [[ $KSU_MANUAL_HOOK == "true" ]]; then
    config --enable CONFIG_KSU_MANUAL_HOOK
    config --disable CONFIG_KSU_WITH_KPROBE
    config --disable CONFIG_KSU_SUSFS_SUS_SU

    log "Applying KSU Manual Hooks patch..."
    if ! patch -p1 <$workdir/ksu_patches/0001*; then
        error "Failed to apply KSU Manual Hooks patch."
    fi
fi

# SUSFS for KSU setup
if [[ $KSU_SUSFS == "true" ]]; then
    log "Cloning susfs4ksu..."
    git clone -q --depth=1 https://gitlab.com/simonpunk/susfs4ksu -b kernel-4.9 $workdir/susfs4ksu
    SUSFS_PATCHES="$workdir/susfs4ksu/kernel_patches"

    log "Applying kernel-side susfs patch"
    if ! patch -p1 <$workdir/susfs_patches/0001*; then
        error "Failed to apply kernel-side susfs patch"
    fi

    # Apply patch to KernelSU (KSU Side)
    if [[ $KSU == "Official" ]]; then
        cd $workdir/ksrc/KernelSU
        log "Applying KernelSU-side susfs patch"
        if ! patch -p1 <$SUSFS_PATCHES/KernelSU/10_enable_susfs_for_ksu.patch; then
            error "Failed to apply KernelSU-side susfs patch"
        fi
    fi
fi

cd $workdir/ksrc
# set localversion
if [[ $TODO == "kernel" ]]; then
    COMMIT_HASH=$(git rev-parse --short HEAD)
    config --set-str CONFIG_LOCALVERSION "-$KERNEL_NAME/$COMMIT_HASH"
fi
# Enable KPM Supports for SukiSU
if [[ $KSU == "Suki" ]]; then
    config --enable CONFIG_KPM
fi
# Disable SuSFS Logging
if [[ $KSU_SUSFS == "true" ]]; then
    config --disable CONFIG_KSU_SUSFS_ENABLE_LOG
fi

# Declare needed variables
export KBUILD_BUILD_USER="$BUILD_USER"
export KBUILD_BUILD_HOST="$BUILD_HOST"
export KBUILD_BUILD_TIMESTAMP=$(date)

text=$(
    cat <<EOF
*=== $KERNEL_NAME CI ===*
🐧 *Linux Version*: \`$LINUX_VERSION\`
📅 *Build Date*: \`$KBUILD_BUILD_TIMESTAMP\`
📱 *Device*: \`$DEVICE_MODEL ($DEVICE_CODENAME)\`
📛 *KernelSU*: \`${KSU}$([[ $KSU != "None" ]] && echo " | $KSU_VERSION")\`
ඞ *SUSFS*: \`$([[ $KSU_SUSFS == "true" ]] && echo "$SUSFS_VERSION" || echo "None")\`
🔰 *Compiler*: \`$COMPILER_STRING\`
EOF
)

MESSAGE_ID=$(send_msg "$text" 2>&1 | jq -r .result.message_id)

# Define make args
MAKE_ARGS="
ARCH=$KERNEL_ARCH
SUBARCH=$KERNEL_ARCH
LLVM=1 
LLVM_IAS=1 
CC=clang
AS=clang 
AR=llvm-ar 
NM=llvm-nm 
LD=ld.lld 
OBJCOPY=llvm-objcopy 
OBJDUMP=llvm-objdump 
STRIP=llvm-strip 
CLANG_TRIPLE=aarch64-linux-gnu- 
CROSS_COMPILE=aarch64-linux-gnu- 
CROSS_COMPILE_ARM32=arm-linux-gnueabi- 
CROSS_COMPILE_COMPAT=arm-linux-gnueabi- 
"
KERNEL_IMAGE=$workdir/out/arch/$KERNEL_ARCH/boot/Image.gz-dtb

## Build Kernel
set +e

log "Generating config..."
make $MAKE_ARGS $KERNEL_DEFCONFIG

# Upload config file
if [[ $TODO == "defconfig" ]]; then
    log "Uploading defconfig..."
    upload_file $workdir/out/.config
    exit 0
fi

# Build the actual kernel
log "Building kernel..."
make $MAKE_ARGS
retVal=${PIPESTATUS[0]}

set -e

if [[ ! -f $KERNEL_IMAGE ]] || [[ $retVal -ne 0 ]]; then
    error "Build Failed!"
fi

# Patch SUKISU
if [[ $KSU == "Suki" ]]; then
    mkdir -p suki && cd suki
    # Set up patch_linux
    cp $workdir/shirkneko_patches/kpm/patch_linux $(pwd)
    chmod a+x $(pwd)/patch_linux
    # Patch kernel image
    cp $KERNEL_IMAGE $(pwd)/Image
    if ! sudo $(pwd)/patch_linux; then
        error "Failed to patch kernel image with SukiSU"
    fi
    mv oImage $(basename $KERNEL_IMAGE)
    KERNEL_IMAGE=$(pwd)/$(basename $KERNEL_IMAGE)
fi

cd $workdir

# Clone AnyKernel
log "Cloning anykernel from $(simplify_gh_url "$ANYKERNEL_REPO")"
git clone -q --depth=1 $ANYKERNEL_REPO -b $ANYKERNEL_BRANCH anykernel

# Set kernel string in anykernel
#if [[ $STATUS == "BETA" ]]; then
#    BUILD_DATE=$(date -d "$KBUILD_BUILD_TIMESTAMP" +"%Y%m%d-%H%M")
#    sed -i \
#        "s/kernel.string=.*/kernel.string=${KERNEL_NAME} ${LINUX_VERSION} (${BUILD_DATE}) ${VARIANT}/g" \
#        $workdir/anykernel/anykernel.sh
#else
#    sed -i \
#        "s/kernel.string=.*/kernel.string=${KERNEL_NAME} ${LINUX_VERSION} ${VARIANT}/g" \
#        $workdir/anykernel/anykernel.sh
#fi

# Zipping
cd $workdir/anykernel
log "Zipping anykernel..."
cp $KERNEL_IMAGE .
zip -r9 $workdir/$ZIP_NAME ./*

# Upload anykernel to telegram
cd $workdir
reply_file "$MESSAGE_ID" "$workdir/$ZIP_NAME"
exit 0
