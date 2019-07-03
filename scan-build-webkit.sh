#! /bin/bash

set -e

CWD=$PWD
INSTALL_DIR=$PWD/install
mkdir $INSTALL_DIR

# Assumes it's running on a recent ubuntu image
# Use docker-trigger.sh to get one

apt-get update
apt-get upgrade -y

apt-get install -y gcc git cmake wget unzip g++ python libxml2-dev ninja-build python ruby python-pip

wget https://github.com/Z3Prover/z3/releases/download/Z3-4.8.5/z3-4.8.5-x64-debian-8.11.zip
unzip z3-4.8.5-x64-debian-8.11.zip
mv z3-4.8.5-x64-debian-8.11/bin z3-4.8.5-x64-debian-8.11/include $INSTALL_DIR

export PATH=$INSTALL_DIR/bin:$PATH
export LD_LIBRARY_PATH=$INSTALL_DIR/bin:$LD_LIBRARY_PATH
git clone --depth=1 https://github.com/llvm/llvm-project.git
cd llvm-project
wget -O bug41809.patch https://bugs.llvm.org/attachment.cgi?id=22160
patch -p1 < bug41809.patch
mkdir build
cd build
cmake -G Ninja -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR -DLLVM_ENABLE_Z3_SOLVER=ON -DLLVM_TARGETS_TO_BUILD=X86 -DLLVM_ENABLE_PROJECTS=clang -DZ3_INCLUDE_DIR=$INSTALL_DIR/include/ -DCMAKE_BUILD_TYPE=Release ../llvm/
ninja
ninja install

cd $CWD
pip install scan-build
git clone --depth=1 git://git.webkit.org/WebKit.git
cd WebKit
Tools/Scripts/build-jsc --jsc-only --release
cd WebKitBuild/Release
analyze-build -v -v -v -v --cdb compile_commands.json -o build-analysis -analyzer-config 'crosscheck-with-z3=true'

mv build-analysis /artifacts
