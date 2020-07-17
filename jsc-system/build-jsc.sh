#! /bin/bash
# Builds a JSC based on the buildroot toolchain
#
# Usage:
#      build-jsc.sh [ --? ]
#                   [ --version ]
#                   [ --release | --debug ]
#                   webkit-directory
#                   buildroot-path

PROGRAM=$(basename "$0")
VERSION=1.0

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# shellcheck source=./common.sh
source "${DIR}/common.sh"

usage()
{
    cat <<EOF
Usage:
	$PROGRAM 
		 [ -h | --help | --? ]            Show help and exit
		 [ --version ]                    Show version and exit
		 [ -f | --force ]                 Delete the build directory if it already exists
		 [ --release | --debug | --ra ]   JSC Build mode (default: release)
		 webkit-directory                 Directory with WebKit checkout
		 buildroot-directory              Directory with Buildroot install
EOF
}

MODEFLAG=
CLOBBER_BUILDDIR=

while test $# -gt 0
do
    case $1 in
	--version )
	    version "${PROGRAM}" "${VERSION}"
	    exit 0
	    ;;
	--help | -h | '--?' )
	    usage_and_exit 0
	    ;;
        --force | -f )
            CLOBBER_BUILDDIR=true
            ;;
	--release )
	    if [ -n "$MODEFLAG" ]; then
		error "only one of --release, --debug, --ra allows"
	    fi
	    MODEFLAG=--release
	    ;;
	--debug )
	    if [ -n "$MODEFLAG" ]; then
		error "only one of --release, --debug, --ra allows"
	    fi
	    MODEFLAG=--debug
	    ;;
	--ra )
	    if [ -n "$MODEFLAG" ]; then
		error "only one of --release, --debug, --ra allows"
	    fi
	    MODEFLAG=--ra
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


if [ -d "${WEBKIT_PATH}/WebKitBuild" ] && [ "$CLOBBER_BUILDDIR" = true ]; then
    rm -rf "${WEBKIT_PATH}/WebKitBuild"
fi

pushd "${WEBKIT_PATH}" || error "push failure"

# Looking for toolchain file
# Location varies in BRPATH, depending if we used sdk for installation
TOOLCHAINFILE=$(find "${BRPATH}" -name toolchainfile.cmake -print -quit)
if [[ -z "${TOOLCHAINFILE}" ]]; then
    error "could not find toolchain file"
fi

TMPLOG=$(mktemp)
progress "building jsc"
if ! Tools/Scripts/build-jsc "${MODEFLAG}" --jsc-only --cmakeargs="-DCMAKE_TOOLCHAIN_FILE=${TOOLCHAINFILE} -DENABLE_STATIC_JSC=ON" &> "${TMPLOG}"; then
    progress "failed to build JSC, log tail is:"
    tail "${TMPLOG}"
    error "full log can be found at: ${TMPLOG}"
fi

popd || error "popd failure"

progress "jsc build finished successfully"
