#!/usr/bin/env bash

#
DEVICE_CODENAME="merlin"
DEVICE_MODEL="Redmi Note 9"
#
BUILD_USER="Dimz"
BUILD_HOST="Phoneix"
TIMEZONE="Asia/Jakarta"
#
KERNEL_NAME="Phoneix"
KERNEL_ARCH="arm64"
KERNEL_REPO="https://github.com/DimasAkbr29/kernel_redmi_mt6768r"
KERNEL_BRANCH="lancelot-r-oss"
KERNEL_DEFCONFIG="merlin_defconfig"
#
ANYKERNEL_REPO="https://github.com/DimasAkbr29/AnyKernel"
ANYKERNEL_BRANCH="main"
#
CLANG_URL="$(./clang.sh aosp)"
CLANG_BRANCH=""
#
ZIP_NAME="$KERNEL_NAME-KVER-CODENAME-VARIANT-BUILD_DATE.zip"
