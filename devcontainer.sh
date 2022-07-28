#!/bin/bash

if ! [ -x "$(command -v jq)" ]; then
    printf "\x1B[31m[ERROR] jq is not installed.\x1B[0m\n"
    exit 1
fi
OPTIND=1
VERBOSE=0
PWD=$(pwd)
while getopts "vt:" opt; do
    case ${opt} in
        v ) VERBOSE=1 ;;
        t ) PWD="${OPTARG}"; pushd $PWD ;; 
    esac
done

debug() {
    if [ $VERBOSE == 1 ]; then
        printf "\x1B[33m[DEBUG] ${1}\x1B[0m\n"
    fi
}

WORKSPACE=$PWD
CURRENT_DIR=${PWD##*/}
echo "Using workspace ${WORKSPACE}"

CONFIG_DIR=./.devcontainer
debug "CONFIG_DIR: ${CONFIG_DIR}"
CONFIG_FILE=devcontainer.json
debug "CONFIG_FILE: ${CONFIG_FILE}"
if ! [ -e "$CONFIG_DIR/$CONFIG_FILE" ]; then
    echo "Folder contains no devcontainer configuration"
    exit
fi

CONFIG=$(cat $CONFIG_DIR/$CONFIG_FILE | grep -v //)
debug "CONFIG: \n${CONFIG}"

cd $CONFIG_DIR

DOCKER_FILE=$(echo $CONFIG | jq -r .dockerFile)
if [ "$DOCKER_FILE" == "null" ]; then 
    DOCKER_FILE=$(echo $CONFIG | jq -r .build.dockerfile)
fi
DOCKER_IMAGE_PRESENT=false
DOCKER_FILE=$(readlink -f $DOCKER_FILE)
debug "DOCKER_FILE: ${DOCKER_FILE}"
if ! [ -e $DOCKER_FILE ]; then
    DOCKER_IMAGE_HASH=$(echo $CONFIG | jq -r '.image')
    debug "Docker image gotten is: $DOCKER_IMAGE_HASH"
    if [ "$DOCKER_IMAGE_HASH" == "null" ];then
        echo "Can not find dockerfile ${DOCKER_FILE}"
        exit
    else
        
        DOCKER_IMAGE_PRESENT=true
    fi
fi

REMOTE_USER=$(echo $CONFIG | jq -r .remoteUser)
debug "REMOTE_USER: ${REMOTE_USER}"
if ! [ "$REMOTE_USER" == "null" ]; then
    REMOTE_USER="-u ${REMOTE_USER}"
else
    REMOTE_USER=""
fi

ARGS=$(echo $CONFIG | jq -r '.build.args | to_entries? | map("--build-arg \(.key)=\"\(.value)\"")? | join(" ")')
debug "ARGS: ${ARGS}"

SHELL=$(echo $CONFIG | jq -r '.settings."terminal.integrated.shell.linux"')
debug "SHELL: ${SHELL}"

PORTS=$(echo $CONFIG | jq -r '.forwardPorts | map("-p \(.):\(.)")? | join(" ")')
debug "PORTS: ${PORTS}"

ENVS=$(echo $CONFIG | jq -r '.remoteEnv | to_entries? | map("-e \(.key)=\(.value)")? | join(" ")')
debug "ENVS: ${ENVS}"

WORK_DIR="/workspace"
debug "WORK_DIR: ${WORK_DIR}"

MOUNT="${MOUNT} --mount type=bind,source=${WORKSPACE},target=${WORK_DIR}"
debug "MOUNT: ${MOUNT}"

echo "Building and starting container"
if ! $DOCKER_IMAGE_PRESENT ;then
    DOCKER_IMAGE_HASH=$(docker build -f $DOCKER_FILE $ARGS .)
fi
debug "DOCKER_IMAGE_HASH: ${DOCKER_IMAGE_HASH}"
debug "docker run -it $REMOTE_USER $PORTS $ENVS $MOUNT -w $WORK_DIR $DOCKER_IMAGE_HASH $SHELL"
docker run -it $REMOTE_USER $PORTS $ENVS $MOUNT -w $WORK_DIR $DOCKER_IMAGE_HASH $SHELL
