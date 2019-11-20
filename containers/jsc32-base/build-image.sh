#! /bin/bash
## $PROG 0.1 - Build WebKit-ready docker image for mipsel and arm
## 
## Usage: $PROG [ARCH]
## Commands:
##   -h, --help             Displays this help and exists
##   -v, --version          Displays output version and exists
## Examples:
##   $PROG arm
##   $PROG mips
set -Eeuo pipefail

source ./utils.sh

PROG=${0##*/}
die() { echo $@ >&2; exit 2; }

help() {
    grep "^##" "$0" | sed -e "s/^...//" -e "s/\$PROG/$PROG/g"; exit 0
}
version() {
    help | head -1
}

[ $# = 0 ] && help
while [ $# -ne 1 ]; do
    help
    exit 1
done

ARCH=$1

if [ "$ARCH" != "arm" ] && [ "$ARCH" != "mips" ]
then
    echo "Invalid architecture: $ARCH"
    help
    exit 1
fi

ROOTFS=`mktemp -d`
QEMUARCH=$(qemuarch $ARCH)
DEBIANARCH=$(debianarch $ARCH)

# Host dependencies
apt-get update
apt-get install -y qemu-user-static debootstrap binfmt-support 
debootstrap --foreign --no-check-gpg --arch=$DEBIANARCH buster $ROOTFS http://httpredir.debian.org/debian/

QEMU=`which qemu-$QEMUARCH-static`
QEMUBASE=$(dirname $QEMU)
mkdir -p $ROOTFS$QEMUBASE
cp -v $QEMU $ROOTFS$QEMUBASE
INTR=$(cat /proc/sys/fs/binfmt_misc/qemu-$QEMUARCH | grep interpreter | cut -d ' ' -f 2)
if [[ "$INTR" != "$QEMU" ]]; then
    echo -1 > /proc/sys/fs/binfmt_misc/qemu-$QEMUARCH
    if [ "$ARCH" == "mips" ]
    then
	echo ":qemu-$QEMUARCH:M:0:\\x7f\\x45\\x4c\\x46\\x01\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x08\\x00:\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\x00\\xfe\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff\\xff:$QEMU:OC" > /proc/sys/fs/binfmt_misc/register
    elif [ "$ARCH" == "arm" ]
    then
	echo ":qemu-$QEMUARCH:M:0:\\x7f\\x45\\x4c\\x46\\x01\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x28\\x00:\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\x00\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff\\xff:$QEMU:OCF" > /proc/sys/fs/binfmt_misc/register
    fi
fi
# todo check that the interpreter exists in right place
chroot $ROOTFS ./debootstrap/debootstrap --second-stage --verbose

mount -t devpts devpts $ROOTFS/dev/pts
mount -t proc proc $ROOTFS/proc
mount -t sysfs sysfs $ROOTFS/sys

chroot $ROOTFS apt-get update
chroot $ROOTFS apt-get -y upgrade
chroot $ROOTFS apt-get install -y g++ cmake libicu-dev git ruby-highline ruby-json python
chroot $ROOTFS apt-get -y autoremove
chroot $ROOTFS apt-get clean
chroot $ROOTFS find /var/lib/apt/lists -type f -delete
umount $ROOTFS/dev/pts
umount $ROOTFS/proc
umount $ROOTFS/sys

cd /artifacts
tar --numeric-owner -cvf buster-$ARCH.tar -C $ROOTFS .
