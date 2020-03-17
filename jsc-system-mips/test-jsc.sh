#! /bin/bash
# Runs JSC tests on MIPS using an external buildroot toolchain
#
# Usage:
#      test-jsc.sh [ --? | -h | --help ]
#                  [ --version]
#                  [ --timeout "..." ]
#                  [ --release | --debug ]
#                  [ --filter "..." ]
#                  [ --vms "..." ]
#                  [ --port "..." ]
#                  webkit-directory
#                  buildroot-path
#

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
		 [ --timeout N ]           Set timeout per test (default: set by run-javascriptcore-tests)
		 [ --release | --debug ]   JSC test mode (default: release)
                 [ --vms N ]               Number of mips vms to start for testing
		 [ --filter REGEX ]        Filter for tests, passed unmodified to run-javascriptcore-tests
		 [ --port P ]              Starting port for VMs (ports [P, P+N-1] need to be free
		 webkit-directory          Directory with WebKit checkout
		 buildroot-directory       Directory with Buildroot install
EOF
}

TIMEOUT=
N=
P=
DEBUG=0
FILTER=

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
	--timeout )
	    shift
	    TIMEOUT=$1
	    ;;
	--release )
	    DEBUG=0
	    ;;
	--debug )
	    DEBUG=1
	    ;;
	--vms )
	    shift
	    N=$1
	    ;;
	--port )
	    shift
	    P=$1
	    ;;
	--filter )
	    shift
	    FILTER=$1
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

if [ -z "${P}" ]; then
    error "need --port"
fi

if [ -z "${N}" ]; then
    error "need --vms"
fi

if [ "$#" != "2" ]; then
    error "expected two arguments, got $#"
fi

WEBKIT_PATH=$1
BRPATH=$2

DFLAG="--release"
if [[ ${DEBUG} == "1" ]]; then
    DFLAG="--debug"
fi

FFLAG=""
if [[ -n "${FILTER}" ]]; then
    FFLAG="--filter ${FILTER}"
fi

# Tests a JSC installation using qemu-system
#
# To test we need to
# 1. Start N instances of qemu-system in the background and keep their PIDs
# 1.1 Copy the HDD image N times
# 1.2 Find N free ports
# 1.3 Start each of the qemu-system with a different HDD image on a different port
#
# 2. Create a remotes file with information from each machine
# 3. Run run-javascriptcore-tests passing in the remotes file
# 4. Kill each of the qemu-systems and remove the HDDs

TESTTMP_PATH="$(mktemp -d)"

QEMUIMG_PATH="${BRPATH}/host/bin/qemu-img"
QEMU_PATH="${BRPATH}/host/bin/qemu-system-mipsel"
HDD_PATH="${BRPATH}/images/rootfs.qcow2"
KERNEL_PATH="${BRPATH}/images/vmlinux"
REMOTES_PATH="$(mktemp)"

declare -a IMAGES
declare -a PORTS
declare -a PIDS

# Assign image paths for each worker
setup_images() {
    for i in $(seq 1 "${N}")
    do
	local p
	progress "Creating image for machine ${i} at ${p}"
	p="${TESTTMP_PATH}/rootfs-${i}.qcow2"
	"${QEMUIMG_PATH}" create -q -f qcow2 -b "${HDD_PATH}" "${p}"
	IMAGES[${i}]=$p
    done
}

# Assign free port numbers for each worker
setup_ports() {
    for i in $(seq 1 "${N}")
    do
	local port
	port=$(( P + i ))
	if lsof -i -P -n | grep LISTEN | grep -q ":${port}"; then
	    error "Port ${port} is not free to use"
	fi
	PORTS[${i}]="${port}"
    done
}

setup_images
setup_ports

# Start qemu-system and store pids in PIDS array
for i in $(seq 1 "${N}")
do
    $QEMU_PATH -M malta \
	       -m 2G \
	       -kernel "${KERNEL_PATH}" \
	       -append "nokaslr root=/dev/hda" \
	       -nographic \
	       -net nic \
	       -net user,hostfwd=tcp::${PORTS[${i}]}-:22 \
	       -serial none \
	       -monitor none \
	       -drive format=qcow2,file="${IMAGES[${i}]}" &
    PIDS[${i}]=$!
    progress "Starting virtual mips machine with pid ${PIDS[${i}]} listening to ssh on port ${PORTS[${i}]}"
done

# Wait until we can communicate with the machines
progress "Waiting for machines to boot..."
sleep 5
for i in $(seq 1 "$N"); do
    progress "Trying to reach machine ${i}"
    port=${PORTS[${i}]}
    retries=3
    
    while [[ $retries -gt 0 ]]
    do
	if ! ssh -p "$port" -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no jsc@localhost true; then
	    progress "FAILED ${i}"
	    retries=$(( retries - 1 ))
	    sleep 20
	else
	    progress "SUCCESS ${i}"
	    break
	fi
    done

    if [[ $retries == 0 ]]; then
	error "can't reach machine $i"
    fi
done

# Create json file with information about remotes
progress "Creating remotes file $REMOTES_PATH"
echo '{"remotes": ['                             >> "$REMOTES_PATH"
for i in $(seq 1 "$N"); do
    {
	echo -n '{"name": "virtual'
	echo -n "${i}"
	echo -n '", "address": "jsc@localhost:'
	echo -n ${PORTS[${i}]}
	echo -n '", "remoteDirectory": "/home/jsc"}'
	if [[ "$i" != "$N" ]]; then
	    echo ','
	fi
    } >> "$REMOTES_PATH"
done
echo '] }'                                       >> "$REMOTES_PATH"

progress "running tests with output redirected to stdout"

# Run tests through run-javascriptcore-tests
if [ -n "${TIMEOUT}" ]; then
    export JSCTEST_timeout="${TIMEOUT}"
fi
"${WEBKIT_PATH}"/Tools/Scripts/run-javascriptcore-tests --no-build --no-fail-fast "${DFLAG}" --memory-limited --remote-config-file "${REMOTES_PATH}" --no-testmasm --no-testair --no-testb3 --no-testdfg --no-testapi --jsc-only "${FFLAG}" 2>&1

# Killall qemu systems and clean up HDDs
for i in $(seq 1 "${N}"); do
    progress "Cleaning up machine ${i}"
    kill ${PIDS[${i}]}
done
progress "Removing temporary remotes file ${REMOTES_PATH}"
rm "${REMOTES_PATH}"
progress "Removing temporary path ${TESTTMP_PATH}"
rm -R "${TESTTMP_PATH}"

progress "Testing finished successfully"
