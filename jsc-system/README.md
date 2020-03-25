# JSC32 Qemu system

This set of scripts allows you to compile and run tests on JSC 32bits (MIPS or ARM) through emulation.

## Creating a toolchain and a `qemu-system` installation

The first step is to use the script `build.sh` to build a toolchain and QEMU.

``` shellsession
~ /home/pmatos/dev/WebKit-misc/jsc-system/build.sh -h
Usage:
	build.sh 
		[ -h | --help | --? ]     Show help and exit
		[ -a | --arch ]           Platform to build system for (required!)
                 [ -j ]                    Number of cores to use during build (default: 40)
		[ --br2 "..." ]           Path to custom buildroot tree (default: checkout)
		[ --br2-version "..." ]   Buildroot tag to checkout (default: 2020.02)
		[ --br2-external "..." ]  Path to custom buildroot JSC external tree (default: checkout)
		[ --temp | --tmp "..." ]  Path to custom temporary directory (default: create)
		[ --version ]             Show version and exit
		output-directory          Directory to install buildroot to
```

For example:

``` shellsession
$ export ARCH=arm
$ export INSTALL=${HOME}/roots/jsc32-${ARCH}
$ ./build.sh --arch ${ARCH} ${MIPSINSTALL}
```

This only needs to be done once and it will create an installation of a toolchain and QEMU in your home at `$HOME/roots/jsc32-${ARCH}`. Feel free to pass another non-existent directory to the script and it will install your brand new toolchain there.

`ARCH` can have two values: `arm` or `mips`. 

## Compiling JSC

To compile JSC you can use the script `build-jsc.sh`.

``` shellsession
~ /home/pmatos/dev/WebKit-misc/jsc-system/build-jsc.sh -h
Usage:
	build-jsc.sh 
		[ -h | --help | --? ]     Show help and exit
		[ --version ]             Show version and exit
		[ --release | --debug ]   JSC Build mode (default: release)
		webkit-directory          Directory with WebKit checkout
		buildroot-directory       Directory with Buildroot install
```

I am assuming you have a WebKit checkout ready to be compiled. Doing so with the above toolchain is as easy as:

``` shellsession
$ ./build-jsc.sh ${HOME}/dev/WebKit ${INSTALL}
```

Here you need to pass a path to an existing WebKit checkout and the folder to where you have your toolchain built using `build.sh`.

## Testing JSC

Testing is started with `test-jsc.sh`.

``` shellsession
~ /home/pmatos/dev/WebKit-misc/jsc-system/test-jsc.sh -h
Usage:
	test-jsc.sh 
		[ -h | --help | --? ]     Show help and exit
		[ --version ]             Show version and exit
		[ --timeout N ]           Set timeout per test (default: set by run-javascriptcore-tests)
		[ --release | --debug ]   JSC test mode (default: release)
                 [ --vms N ]               Number of vms to start for testing
		[ --filter REGEX ]        Filter for tests, passed unmodified to run-javascriptcore-tests
		[ --port P ]              Starting port for VMs (ports [P, P+N-1] need to be free
		webkit-directory          Directory with WebKit checkout
		buildroot-directory       Directory with Buildroot install
```

To test JSC, you can use as many virtual machines are you want as long as you have the necessary resources. The number of virtual machines should certainly be less or equal than the number of cores you have.

For example:

``` shellsession
$ ./test-jsc.sh --vms 16 --port 61000 ${HOME}/dev/WebKit ${INSTALL}
```

