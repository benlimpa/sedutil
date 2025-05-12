#!/bin/bash

# get repo directory
REPO_DIR=$(realpath $(dirname $0)/..)

echo Mounting $REPO_DIR to /sedutil in the container

podman run -it \
    -v $REPO_DIR:/sedutil \
    --name sedutil-build \
    --privileged \
    --cap-add CAP_SYS_ADMIN \
    sedutil-build:latest
