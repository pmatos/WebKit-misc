#! /bin/bash

# Receives 4 arguments
# N - number of workers to use
# P - starting port to use , ports [P, P+N] should be free
# WebKitPath - Path to WebKit directory
# MIPSBuildrootPath - Path to MIPS Buildroot

N=$1
P=$2
WEBKIT_PATH=$3
BRPATH=$4

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

TESTTMP_PATH=$(mktemp -d)

QEMUIMG_PATH=$BRPATH/host/bin/qemu-img
QEMU_PATH=$BRPATH/host/bin/qemu-system-mipsel
HDD_PATH=$BRPATH/images/rootfs.qcow2
KERNEL_PATH=$BRPATH/images/vmlinux
REMOTES_PATH=$(mktemp)

declare -a IMAGES
declare -a PORTS
declare -a PIDS

# Assign image paths for each worker
setup_images() {
    for i in `seq 1 $N`
    do
	local p=${TESTTMP_PATH}/rootfs-${i}.qcow2
	${QEMUIMG_PATH} create -q -b $HDD_PATH $p
	IMAGES[${i}]=$p
	echo "Creating image for machine ${i} at ${p}"
    done
}

# Assign free port numbers for each worker
setup_ports() {
    for i in `seq 1 $N`
    do
	local port=$(( $P + $i ))
	if $(lsof -i -P -n | grep LISTEN | grep -q ":${port}")
	then
	    echo "Port ${port} is not free to use"
	    exit 1
	fi
	PORTS[${i}]=${port}
    done
}

setup_images
setup_ports

# Start qemu-system and store pids in PIDS array
for i in `seq 1 $N`
do
    $QEMU_PATH -M malta \
	       -m 2G \
	       -kernel $KERNEL_PATH \
	       -append "nokaslr root=/dev/hda" \
	       -nographic \
	       -net nic \
	       -net user,hostfwd=tcp::${PORTS[${i}]}-:22 \
	       -serial none \
	       -monitor none \
	       -drive format=raw,file=${IMAGES[${i}]} &
    PIDS[${i}]=$!
    echo "Starting virtual mips machine with pid ${PIDS[${i}]} listening to ssh on port ${PORTS[${i}]}"
done

# Wait until we can communicate with the machines
echo "Waiting for machines to boot..."
sleep 5
for i in `seq 1 $N`
do
    echo -n "Trying to reach machine ${i}: "
    pid=${PIDS[${i}]}
    retries=3
    
    while [[ $retries > 0 ]]
    do
	if ! ssh -p ${PORTS[${i}]} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no jsc@localhost true; then
	    echo -n "FAILED "
	    retries=$(( retries - 1 ))
	    sleep 20
	else
	    echo "SUCCESS"
	    break
	fi
    done

    if [[ $retries == 0 ]]; then
	echo "can't reach machine $i"
	exit 1
    fi
done

# Create json file with information about remotes
echo "Creating remotes file $REMOTES_PATH"
echo '{"remotes": ['                             >> $REMOTES_PATH
for i in `seq 1 $N`; do
    echo -n '{"name": "virtual'                  >> $REMOTES_PATH
    echo -n ${i}                                 >> $REMOTES_PATH
    echo -n '", "address": "jsc@localhost:'      >> $REMOTES_PATH
    echo -n ${PORTS[${i}]}                       >> $REMOTES_PATH
    echo -n '", "remoteDirectory": "/home/jsc"}' >> $REMOTES_PATH
    if [[ $i != $N ]]; then
	echo ','                                 >> $REMOTES_PATH
    fi
done
echo '] }'                                       >> $REMOTES_PATH

# Run tests through run-javascriptcore-tests
${WEBKIT_PATH}/Tools/Scripts/run-javascriptcore-tests --no-build --no-fail-fast --release --memory-limited --remote-config-file $REMOTES_PATH --no-testmasm --no-testair --no-testb3 --no-testdfg --no-testapi --jsc-only 2>&1 | tee $TESTTMP_PATH/testing.log

# Killall qemu systems and clean up HDDs
for i in `seq 1 $N`; do
    echo "Cleaning up machine ${i}"
    kill ${PIDS[${i}]}
done
echo "Removing temporary remotes file ${REMOTES_PATH}"
rm ${REMOTES_PATH}
echo "Removing temporary path ${TESTTMP_PATH}"
rm -R ${TESTTMP_PATH}
