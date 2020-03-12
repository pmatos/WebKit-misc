#! /bin/bash

# Builds a JSC for MIPS based on the buildroot toolchain
# Arguments are:
# 1. WebKit checkout path
# 2. Buildroot toolchain root
WEBKIT_PATH=$1
BRPATH=$2

pushd ${WEBKIT_PATH}

if [ -d ${WEBKIT_PATH}/WebKitBuild ]; then
    echo "Build directory already exists ${WEBKIT_PATH}/WebKitBuild"
    exit 1
fi

Tools/Scripts/build-jsc --release --jsc-only --cmakeargs="-DCMAKE_TOOLCHAIN_FILE=${BRPATH}/host/share/buildroot/toolchainfile.cmake -DENABLE_STATIC_JSC=ON" 2>&1 | tee build.log

