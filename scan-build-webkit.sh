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

cd $CWD
pip install scan-build

wait ${GITPID}
cd WebKit
Tools/Scripts/build-jsc --jsc-only --debug
cd WebKitBuild/Debug
analyze-build -v --cdb compile_commands.json -o build-analysis -analyzer-config 'crosscheck-with-z3=true'

mv build-analysis $ARTIFACTS
