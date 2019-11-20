#! /bin/bash
## $PROG 0.1 - Build WebKit-ready docker image for 32bits mips and arm
## 
## Usage: $PROG [ARCH]
## Commands:
##   -h, --help             Displays this help and exists
##   -v, --version          Displays output version and exists
## Examples:
##   $PROG arm
##   $PROG mips
set -eu

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

docker build -t buster-$ARCH --build-arg ARCH=$ARCH -f build-image.Dockerfile .
docker run --rm --privileged -v `pwd`/artifacts:/artifacts buster-$ARCH
docker import `pwd`/artifacts/buster-$ARCH.tar jsc32-base:$ARCH-raw
docker build -t pmatos/jsc32-base:$ARCH -f jsc32-base.Dockerfile --build-arg ARCH=$ARCH .
docker push pmatos/jsc32-base:$ARCH
