#!/usr/bin/env bash

#
DEVICE_CODENAME="onclite"
DEVICE_MODEL="Redmi 7"
#
BUILD_USER="eraselk"
BUILD_HOST="gacorprjkt"
TIMEZONE="Asia/Makassar"
#
KERNEL_NAME="QuartiX"
KERNEL_ARCH="arm64"
KERNEL_REPO="https://github.com/linastorvaldz/android_kernel_xiaomi_onclite"
KERNEL_BRANCH="master"
KERNEL_DEFCONFIG="onclite-perf_defconfig"
#
ANYKERNEL_REPO="https://github.com/linastorvaldz/anykernel"
ANYKERNEL_BRANCH="onclite"
#
CLANG_URL="https://gitlab.com/LeCmnGend/clang.git"
CLANG_BRANCH="clang-17"
#
ZIP_NAME="$KERNEL_NAME-KVER-CODENAME-VARIANT-BUILD_DATE.zip"
