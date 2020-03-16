#! /bin/bash

# Builds a MIPS based toolchain and qemu-system for testing and debugging Webkit
# Receives one argument, the destination directory for the build
DEST=$(realpath $1)
if ! mkdir ${DEST} &> /dev/null; then
    echo "Path ${DEST} already exists"
    exit 1
fi

echo "Creating MIPS toolchain in ${DEST}"

TMP_PATH=$(mktemp -d)
BR2VERSION='2020.02'
pushd ${TMP_PATH}
git clone --depth=1 https://github.com/pmatos/jsc-br2-external.git
git clone --depth=1 --branch ${BR2VERSION} https://github.com/buildroot/buildroot
popd

pushd ${DEST}
make O=$PWD -C ${TMP_PATH}/buildroot BR2_EXTERNAL=${TMP_PATH}/jsc-br2-external qemu-mips32elr2-jsc_defconfig 2>&1 | tee configure.log
make BR2_JLEVEL=16 2>&1 | tee build.log

# Need to convert image to use it as backing file
echo "Converting raw image to qcow2"
if ! host/bin/qemu-img -O qcow2 images/rootfs.ext2 images/rootfs.qcow2; then
    echo "Failed to convert image"
    exit 1
fi
popd

echo "Cleaning up temporary folder ${TMP_PATH}"
rm -Rf ${TMP_PATH}
