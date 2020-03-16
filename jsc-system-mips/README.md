# JSC32 MIPSel Qemu system

This set of scripts allows you to compile and run tests on JSC32 MIPS without MIPS hardware.

## Creating a MIPS toolchain and `qemu-system-mipsel` installation

The first step is to use the script `build-mips.sh` to build a MIPS toolchain and QEMU.

``` shellsession
$ export MIPSINSTALL=${HOME}/roots/jsc32-mipsel
$ ./build-mips.sh ${MIPSINSTALL}
```

This only needs to be done once and it will create an installation of a MIPS toolchain and QEMU in your home at `$HOME/roots/jsc32-mipsel`. Feel free to pass another non-existent directory to the script and it will install your brand new toolchain there.

## Compiling JSC

I am assuming you have a WebKit checkout ready to be compiled. Doing so with the above toolchain is as easy as:

``` shellsession
$ ./build-jsc.sh ${HOME}/dev/WebKit ${MIPSINSTALL}
```

Here you need to pass a path to an existing WebKit checkout and the folder to where you have your MIPS toolchain built using `build-mips.sh`.

## Testing JSC

To test JSC, you can use as many virtual machines are you want as long as you have the necessary resources. The number of virtual machines should certainly be less or equal than the number of cores you have.

For example:

``` shellsession
$ ./test-jsc.sh 16 61000 ${HOME}/dev/WebKit ${MIPSINSTALL}
```

This script receives 4 arguments:

1. the number of workers to use (`16` in the example)
2. the starting port to use (ports `[P, P+N]` should be free, `N` is the number of workers, 61000 in the example)
3. path to WebKit directory (`${HOME}/dev/WebKit` in the example)
4. ath to MIPS Buildroot (`${MIPSINSTALL}` in the example)
