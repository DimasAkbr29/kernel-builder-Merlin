#!/usr/bin/env bash

#
DEVICE_CODENAME="merlin"
DEVICE_MODEL="Redmi Note 9"
#
BUILD_USER="DimzMachine"
BUILD_HOST="[A13+]Phoneix-Next"
TIMEZONE="Asia/Jakarta"
#
KERNEL_NAME="[A13+]Phoneix-NextKernel"
KERNEL_ARCH="arm64"
KERNEL_REPO="https://github.com/DimzHereee/Kernel-merlinx"
KERNEL_BRANCH="A15"
KERNEL_DEFCONFIG="merlin_defconfig"
#
ANYKERNEL_REPO="https://github.com/DimasAkbr29/AnyKernel"
ANYKERNEL_BRANCH="main"
#
CLANG_URL="$(./clang.sh aosp)"
CLANG_BRANCH=""
#
ZIP_NAME="$KERNEL_NAME-KVER-CODENAME-VARIANT-BUILD_DATE.zip"
