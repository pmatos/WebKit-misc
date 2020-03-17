#! /bin/bash
# Builds a JSC for MIPS based on the buildroot toolchain
#
# Usage:
#      build-jsc.sh [ --? ]
#                   [ --version ]
#                   webkit-directory
#                   buildroot-path

PROGRAM=$(basename "$0")
VERSION=1.0

DATESTART=$(date +%s%N)

source "./common.sh"

usage()
{
    cat <<EOF
Usage:
	$PROGRAM 
		 [ -h | --help | --? ]     Show help and exit
		 [ --version ]             Show version and exit
		 webkit-directory          Directory with WebKit checkout
		 buildroot-directory       Directory with Buildroot install
EOF
}

while test $# -gt 0
do
    case $1 in
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

if [ "$#" != "2" ]; then
    error "expected two arguments, got $#"
fi

WEBKIT_PATH=$(realpath "$1")
BRPATH=$(realpath "$2")

if [ ! -d "${WEBKIT_PATH}" ]; then
    error "WebKit path does not exist: ${WEBKIT_PATH}"
fi

if [ ! -d "${BRPATH}" ]; then
    error "BuildRoot path does not exist: ${BRPATH}"
fi


if [ -d "${WEBKIT_PATH}/WebKitBuild" ]; then
    echo "Build directory already exists ${WEBKIT_PATH}/WebKitBuild"
    exit 1
fi

pushd "${WEBKIT_PATH}" || error "push failure"

TMPLOG=$(mktemp)
if ! Tools/Scripts/build-jsc --release --jsc-only --cmakeargs="-DCMAKE_TOOLCHAIN_FILE=${BRPATH}/host/share/buildroot/toolchainfile.cmake -DENABLE_STATIC_JSC=ON" &> "${TMPLOG}"; then
    progress "failed to build JSC, log tail is:"
    tail "${TMPLOG}"
    error "full log can be found at: ${TMPLOG}"
fi

popd || error "popd failure"
