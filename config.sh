#!/usr/bin/env bash

#
DEVICE_CODENAME="merlin"
DEVICE_MODEL="Redmi Note 9"
#
BUILD_USER="DimzMachine"
BUILD_HOST="PhoneixKernel"
TIMEZONE="Asia/Jakarta"
#
KERNEL_NAME="PhoneixKernel betaa"
KERNEL_ARCH="arm64"
KERNEL_REPO="https://github.com/DimzHereee/android_kernel_xiaomi_mt6768-merlinx"
KERNEL_BRANCH="aosp-14/lts"
KERNEL_DEFCONFIG="merlin_defconfig"
#
ANYKERNEL_REPO="https://github.com/DimasAkbr29/AnyKernel"
ANYKERNEL_BRANCH="main"
#
CLANG_URL="$(./clang.sh zy)"
CLANG_BRANCH=""
#
ZIP_NAME="$KERNEL_NAME-KVER-CODENAME-VARIANT-BUILD_DATE.zip"
