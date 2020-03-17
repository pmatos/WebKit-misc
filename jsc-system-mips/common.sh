#! /bin/bash

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
    echo "$PROGRAM version $VERSION"
}
