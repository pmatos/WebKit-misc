#! /bin/bash

DATESTART=$(date +%s%N)

progress()
{
    local now
    now=$(date +%s%N)
    echo "=== $(( (now - DATESTART) / 1000000 )): $*"
}

error()
{
    echo "$@" 1>&2
    usage_and_exit 1
}

usage_and_exit()
{
    usage
    exit "$1"
}

version()
{
    local p
    local v
    p="$1"
    v="$2"
    echo "$p version $v"
}
