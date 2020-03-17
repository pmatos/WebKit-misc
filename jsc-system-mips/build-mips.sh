#! /bin/bash
# Builds a MIPS based toolchain and qemu-system for testing and debugging WebKit.
#
# Usage:
#      build-mips.sh [ --? ]
#                    [ --br2 "..." ]
#                    [ --br2-version "..." ]
#                    [ --br2-external "..." ]
#                    [ --temp | --tmp "..." ]
#                    [ --version ]
#                    output-directory
#

PROGRAM=$(basename "$0")
VERSION=1.0

DATESTART=$(date +%s%N)

BR2PATH=
BR2VERSION='2020.02'
BR2EXTERNAL=
TEMPPATH=
JLEVEL=$(nproc)

source "./common.sh"

usage()
{
    cat <<EOF
Usage:
	$PROGRAM 
		 [ -h | --help | --? ]     Show help and exit
                 [ -j ]                    Number of cores to use during build (default: $(nproc))
		 [ --br2 "..." ]           Path to custom buildroot tree (default: checkout)
		 [ --br2-version "..." ]   Buildroot tag to checkout (default: $BR2VERSION)
		 [ --br2-external "..." ]  Path to custom buildroot JSC external tree (default: checkout)
		 [ --temp | --tmp "..." ]  Path to custom temporary directory (default: create)
		 [ --version ]             Show version and exit
		 output-directory          Directory to install buildroot to
EOF
}

while test $# -gt 0
do
    case $1 in
	--br2 )
	    shift
	    BR2PATH="$1"
	    ;;
	--br2-version )
	    shift
	    BR2VERSION="$1"
	    ;;
	--br2-external )
	    shift
	    BR2EXTERNAL="$1"
	    ;;
	--temp | --tmp )
	    shift
	    TEMPPATH="$1"
	    ;;
	-j )
	    shift
	    JLEVEL="$1"
	    ;;
	--version )
	    version
	    exit 0
	    ;;
	--help | -h | '--?' )
	    usage_and_exit 0
	    ;;
	-*)
	    error "Unrecognized option: $1"
	    ;;
	*)
	    break
	    ;;
    esac
    shift
done

# Argument and flag option checks

if [ "$#" != "1" ]; then
    error "expected a single argument, got $#"
fi

if [ -z "${TEMPPATH}" ]; then
    TEMPPATH=$(mktemp -d)
fi

# Receives one argument, the destination directory for the build
OUTPUT=$(realpath "$1")
if ! mkdir "${OUTPUT}" &> /dev/null; then
    error "output path already exists: ${OUTPUT}"
fi

progress "Creating MIPS toolchain in ${OUTPUT}"

pushd "${TEMPPATH}" || error "cannot pushd"
if [ -z "${BR2EXTERNAL}" ]; then
    progress "cloning jsc br2 external"
    git clone --quiet --depth=1 https://github.com/pmatos/jsc-br2-external.git
fi
if [ -z "${BR2PATH}" ]; then
    progress "cloning buildroot"
    git clone --quiet --depth=1 --branch "${BR2VERSION}" https://github.com/buildroot/buildroot
fi
popd || error "cannot popd"

pushd "${OUTPUT}" || error "cannot pushd"
progress "configuring buildroot defconfig"
if ! make O="${PWD}" -C "${TEMPPATH}/buildroot" BR2_EXTERNAL="${TEMPPATH}/jsc-br2-external" qemu-mips32elr2-jsc_defconfig &> "${TEMPPATH}/configure.log"; then
    tail "${TEMPPATH}/configure.log"
    error "failed to configure buildroot"
fi

progress "building root"
if ! make BR2_JLEVEL="${JLEVEL}" &> "${TEMPPATH}/build.log"; then
    tail "${TEMPPATH}/build.log"
    error "failed to build buildroot"
fi

# Need to convert image to use it as backing file
progress "Converting raw image to qcow2"
if ! host/bin/qemu-img -q -O qcow2 images/rootfs.ext2 images/rootfs.qcow2; then
    error "Failed to convert image"
fi
popd || error "cannot popd"

progress "Cleaning up temporary folder ${TEMPPATH}"
rm -Rf "${TEMPPATH}"

