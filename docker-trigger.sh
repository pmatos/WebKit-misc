#! /bin/bash

IMAGE=$1
SCRIPT=$2
SCRIPT_BASE=$(basename $SCRIPT)
CONTAINERWD=/work
ARTIFACTS=/artifacts

# Start docker
NAME=$(docker run --privileged -tid $IMAGE)

# Creating working directory inside container
docker exec $NAME /bin/sh -c "mkdir $CONTAINERWD"
docker exec $NAME /bin/sh -c "mkdir $ARTIFACTS"

# Copy script
docker cp $SCRIPT $NAME:$CONTAINERWD/

# Run script
docker exec $NAME /bin/sh -c $CONTAINERWD/$SCRIPT_BASE

# Copy artifacts
docker cp $NAME:$ARTIFACTS .

# Close docker
docker stop $NAME > /dev/null
docker rm $NAME > /dev/null


