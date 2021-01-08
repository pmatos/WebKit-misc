[![](.github/badges/SponsoredbyIgalia.svg)](https://www.igalia.com)

# WebKit Misc Script

As part of my work as an Igalian (https://www.igalia.com) I am working on WebKit. For some specific tasks I am using a few scripts. I am adding these here as time goes by.
Some are better than others but expect the unexpected. Feel free to do PRs and open Issues.

# Scripts

## `scan-build-webkit.sh` (Status: ![Fragile](https://img.shields.io/badge/sh-Fragile-red.svg))

Run LLVM `scan-build` on WebKit. This expects a ubuntu like environment so you might want to use `docker-trigger.sh` on this one.

The special thing about this specific `scan-build` is that it uses the recent advances on SMT guided counterexample introduced by 
[SMT-based refutation of spurious bug reports in the clang static analyzer](https://dl.acm.org/citation.cfm?id=3339673).

Due to a bug in LLVM it also temporarily applies a workaround patch from [bug 41809](https://bugs.llvm.org/show_bug.cgi?id=41809).

With any PC with docker support you should be able to run:
```
./docker-trigger.sh ubuntu:latest scan-build-webkit.sh 
```

## `docker-trigger.sh` (Status: ![Fragile](https://img.shields.io/badge/sh-Fragile-red.svg))

This script will trigger another script inside a docker container and save artifacts to the current directory in `$PWD/artifacts/`.

Try
```
$ ./docker-trigger.sh ubuntu:latest ./hello-world.sh
```

## `JetStream2-cmp/cmp.rkt` (Status: ![Fragile](https://img.shields.io/badge/sh-Fragile-red.svg))

This script will compare the outputs of two cli JetStream2 runs. Inside WebKit, you can go to `PerformanceTests/JetStream2` and after build `jsc`, you can run:

```
../../WebKitBuild/Release/bin/jsc cli.js 2>&1 | tee output.log
```

If you build another version of jsc and run the same command line you can then compare the results with:

```
racket cmp.rkt VERSION1 <Path to WebKit1>/PerformanceTests/JetStream2/output.log VERSION1 <Path to WebKit2>/PerformanceTests/JetStream2/output.log 2>&1 | less
```
