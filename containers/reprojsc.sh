#! /bin/bash
#
# Required Options:
# -a : arch (mips or arm)
# -q : qemu path to setup binfmt
# -b : build webkit
# -t : test webkit (assumes --build)
# -f  <regexp>: filter to be passed to the run-javascript-tests script
# Optional Options:
# -i : enters a terminal 
# Arguments:
# <path>: path to a local webkit checkout to use in building and testing
set -Eeuo pipefail

# Command line argument handling

INTERACTIVE=0
BUILD=0
TEST=0
FILTER=""
ARCH=
QEMU=
while getopts ":a:q:ibtf:" opt; do
    case ${opt} in
	a)
	    ARCH="$OPTARG"
	    ;;
	q)
	    QEMU="$OPTARG"
	    ;;
	i)
	    INTERACTIVE=1
	    ;;
	b)
	    BUILD=1
	    ;;
	t)
	    TEST=1
	    BUILD=1
	    ;;
	f)
	    TEST=1
	    BUILD=1
	    FILTER="$OPTARG"
	    ;;
	\?)
	    echo "Invalid option: $OPTARG" 1>&2
	    exit
	    ;;
	:)
	    echo "Invalid option: $OPTARG requires an argument" 1>&2
	    exit
	    ;;
    esac
done
shift $((OPTIND - 1))

if [[ $ARCH == '' ]]; then
    echo "Please specify -a <arch>"
    exit
fi

if [[ $# != 1 ]]; then
    echo "Not enough arguments"
    exit
fi
WEBKIT=$1

if [ ! -d $WEBKIT ]; then
    echo "Directory $WEBKIT does not exist"
    exit
fi

# Deal with exit
BINFMT_NAME=
function finish {
    if [[ $BINFMT_NAME != '' ]]; then
	echo "Cleaning up binfmt support"
	echo -1 > /proc/sys/fs/binfmt_misc/$BINFMT_NAME
    fi
}
trap finish EXIT SIGINT

# Output plan

echo "Using WebKit path $WEBKIT"
echo "Plan:"
if [[ $BUILD == 1 ]]; then
    echo " * Build;"
fi
if [[ $TEST == 1 ]]; then
    echo " * Test;"
    if [[ $FILTER != "" ]]; then
	echo "   Using filter: \"$FILTER\""
    fi
fi
if [[ $INTERACTIVE == 1 ]]; then
    echo " * Going into interactive mode;"
fi

read -n1 -r -p "Press any key to continue or Ctrl-C to exit..." keyign

if [[ $QEMU != '' ]]; then
    echo "Setting up $ARCH binfmt to run interpreter in $QEMU"
    BINFMT_NAME="reprojsc-qemu-$ARCH"
    if [ -f  "/proc/sys/fs/binfmt_misc/$BINFMT_NAME" ]; then
	echo -1 > /proc/sys/fs/binfmt_misc/$BINFMT_NAME
    fi

    if [[ $ARCH == "mips" ]]; then
	echo ":$BINFMT_NAME:M:0:\\x7f\\x45\\x4c\\x46\\x01\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x08\\x00:\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\x00\\xfe\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff\\xff:$QEMU:OC" > /proc/sys/fs/binfmt_misc/register
    elif [[ $ARCH == "arm" ]]; then
	echo ":$BINFMT_NAME:M:0:\\x7f\\x45\\x4c\\x46\\x01\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x28\\x00:\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\x00\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff\\xff:$QEMU:OCF" > /proc/sys/fs/binfmt_misc/register
    fi
fi

out=$(docker run --rm pmatos/jsc32-base:$ARCH /bin/true 2>&1 || true)
if `echo $out | grep -q "exec format error"`; then
    echo "binfmt/qemu are not setup for $ARCH"
    echo "use -q <qemu-path> to setup qemu using binfmt (make sure qemu-path points to the qemu with the right arch)"
    exit 1
fi

did=$(docker run --rm -di -v $WEBKIT:/WebKit pmatos/jsc32-base:$ARCH)

UNAME=
if [[ "$ARCH" == "arm" ]]; then
    UNAME="armv7l"
elif [[ "$ARCH" == "mips" ]]; then
    UNAME="mips"
fi
    

if [[ "$(docker exec $did uname -m)" != "$UNAME" ]]; then
    echo "Something is wrong - incorrect container architecture"
    docker stop $did
    exit
fi


set +e

[[ $BUILD == 1 ]] && docker exec $did /bin/bash -c "cd /WebKit && Tools/Scripts/build-jsc --release --jsc-only --cmakeargs=\"-DENABLE_STATIC_JSC=ON -DCMAKE_VERBOSE_MAKEFILE=ON -DENABLE_JIT=OFF\" $BUILD_JSC_ARGS"
echo "Build returned $?"
[[ $TEST == 1 ]] && docker exec $did /bin/bash -c "cd /WebKit && Tools/Scripts/run-javascriptcore-tests --no-build --no-fail-fast --json-output=jsc_results.json --release --memory-limited --no-testmasm --no-testair --no-testb3 --no-testdfg --no-testapi --jsc-only --no-jit-stress-tests $TEST_JSC_ARGS"
echo "Test returned $?"
[[ $INTERACTIVE == 1 ]] && docker exec -ti $did /bin/bash
docker stop $did

