#!/bin/bash

NAME=ti-build
IMAGE=ti-ubuntu22

if docker ps -a --format '{{.Names}}' | grep -qx "$NAME"; then
    docker start -ai "$NAME"
else
    docker run -it \
        --name "$NAME" \
        --privileged \
        -v /dev:/dev \
        -v /home/kira9k/ieos/build_am67a/edge-ai-image-builder:/app \
        "$IMAGE"
fi