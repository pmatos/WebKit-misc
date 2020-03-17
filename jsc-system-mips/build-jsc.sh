#! /bin/bash
# Builds a JSC for MIPS based on the buildroot toolchain
#
# Usage:
#      build-jsc.sh [ --? ]
#                   [ --version ]
#                   [ --release | --debug ]
#                   webkit-directory
#                   buildroot-path

PROGRAM=$(basename "$0")
VERSION=1.0

DATESTART=$(date +%s%N)

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

source "${DIR}/common.sh"

usage()
{
    cat <<EOF
Usage:
	$PROGRAM 
		 [ -h | --help | --? ]     Show help and exit
		 [ --version ]             Show version and exit
		 [ --release | --debug ]   JSC Build mode (default: release)
		 webkit-directory          Directory with WebKit checkout
		 buildroot-directory       Directory with Buildroot install
EOF
}

DEBUG=0

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
	--release )
	    DEBUG=0
	    ;;
	--debug )
	    DEBUG=1
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

DFLAG="--release"
if [[ ${DEBUG} == "1" ]]; then
    DFLAG="--debug"
fi

pushd "${WEBKIT_PATH}" || error "push failure"

TMPLOG=$(mktemp)
progress "building jsc"
if ! Tools/Scripts/build-jsc "${DFLAG}" --jsc-only --cmakeargs="-DCMAKE_TOOLCHAIN_FILE=${BRPATH}/host/share/buildroot/toolchainfile.cmake -DENABLE_STATIC_JSC=ON" &> "${TMPLOG}"; then
    progress "failed to build JSC, log tail is:"
    tail "${TMPLOG}"
    error "full log can be found at: ${TMPLOG}"
fi

popd || error "popd failure"

progress "jsc build finished successfully"
