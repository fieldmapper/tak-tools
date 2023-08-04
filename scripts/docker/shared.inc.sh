#!/bin/bash

WORK_DIR=~/tak-server # Base directory; where everything kicks off

TAK_PATH="${WORK_DIR}/tak"
CERT_PATH="${TAK_PATH}/certs"
FILE_PATH="${CERT_PATH}/files"

DOCKER_CERT_PATH="/opt/tak/certs"

TOOLS_PATH=$(dirname $(dirname $SCRIPT_PATH))
TEMPLATE_PATH="${TOOLS_PATH}/templates"

source ${TOOLS_PATH}/scripts/color.inc.sh

PASS_OMIT="~<>/\'\`\""
PADS="abcdefghijklmnopqrstuvwxyz"

arch=$(dpkg --print-architecture)

APT_DOCKER=docker-ce
if [[ $arch == "arm64" ]];then
    APT_DOCKER=docker
fi

DOCKER_COMPOSE="docker-compose"
if [[ ! command -v docker-compose ]];then
    DOCKER_COMPOSE="docker compose"
fi


pause () {
    read -p "Press Enter to resume setup... "
}