#! /bin/bash

qemuarch() {
    if [ "$1" == "arm" ]
    then
       echo "arm"
    elif [ "$1" == "mips" ]
    then
	echo "mipsel"
    fi
}

debianarch() {
    if [ "$1" == "arm" ]
    then
       echo "armhf"
    elif [ "$1" == "mips" ]
    then
	echo "mipsel"
    fi
}    
