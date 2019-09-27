#! /bin/bash

set -e

if [ -z $1 ]; then
    ARTIFACTS=/artifacts
else
    ARTIFACTS=$1
fi
CWD=$PWD
INSTALL_DIR=$PWD/install
mkdir $INSTALL_DIR

# Assumes it's running on a recent ubuntu image
# Use docker-trigger.sh to get one

apt-get update
apt-get upgrade -y

apt-get install -y git
git clone --progress --depth=1 git://git.webkit.org/WebKit.git 2> out.log &
GITPID=$!

apt-get install -y gcc cmake wget unzip g++ python libxml2-dev ninja-build python ruby python-pip

wget https://github.com/Z3Prover/z3/releases/download/z3-4.8.6/z3-4.8.6-x64-ubuntu-16.04.zip
unzip z3-4.8.6-x64-ubuntu-16.04.zip
mv z3-4.8.6-x64-ubuntu-16.04/bin z3-4.8.6-x64-ubuntu-16.04/include $INSTALL_DIR

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

wait ${GITPID}
cd WebKit
Tools/Scripts/build-jsc --jsc-only --debug
cd WebKitBuild/Debug
analyze-build -v --cdb compile_commands.json -o build-analysis -analyzer-config 'crosscheck-with-z3=true'

mv build-analysis $ARTIFACTS
