#!/bin/bash

# get repo directory
REPO_DIR=$(realpath $(dirname $0)/..)

echo Mounting $REPO_DIR to /sedutil in the container

docker run -it \
  --user 1000:1000 \
  -v $REPO_DIR:/sedutil \
  --name sedutil-build \
  sedutil-build:latest
#--privileged \
#--cap-add CAP_SYS_ADMIN \
