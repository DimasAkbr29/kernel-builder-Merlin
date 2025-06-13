#!/usr/bin/env bash

#
DEVICE_CODENAME="merlin"
DEVICE_MODEL="Redmi Note 9"
#
BUILD_USER="DimzMachine"
BUILD_HOST="Phoneix-Next Kernel"
TIMEZONE="Asia/Jakarta"
#
KERNEL_NAME="Phoneix-Next Kernel"
KERNEL_ARCH="arm64"
KERNEL_REPO="https://github.com/DimzHereee/Kernel-merlinx"
KERNEL_BRANCH="next"
KERNEL_DEFCONFIG="merlin_defconfig"
#
ANYKERNEL_REPO="https://github.com/DimasAkbr29/AnyKernel"
ANYKERNEL_BRANCH="main"
#
CLANG_URL="$(./clang.sh zy)"
CLANG_BRANCH=""
#
ZIP_NAME="$KERNEL_NAME-KVER-CODENAME-VARIANT-BUILD_DATE.zip"
