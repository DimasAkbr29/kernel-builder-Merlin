#!/usr/bin/env bash

#
DEVICE_CODENAME="merlin"
DEVICE_MODEL="Redmi Note 9"
#
BUILD_USER="DimzMachine"
BUILD_HOST="Phoneix-NextKernel"
TIMEZONE="Asia/Jakarta"
#
KERNEL_NAME="Phoneix-NextKernel"
KERNEL_ARCH="arm64"
KERNEL_REPO="https://github.com/DimasAkbr29/kernel_xiaomi_mt6768m"
KERNEL_BRANCH="next"
KERNEL_DEFCONFIG="merlin_defconfig"
#
ANYKERNEL_REPO="https://github.com/DimasAkbr29/AnyKernel"
ANYKERNEL_BRANCH="main"
#
CLANG_URL="$(./clang.sh aosp)"
CLANG_BRANCH=""
#
ZIP_NAME="$KERNEL_NAME-KVER-CODENAME-VARIANT-BUILD_DATE.zip"
