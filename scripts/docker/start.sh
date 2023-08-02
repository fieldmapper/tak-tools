#!/bin/bash

## TODO: Separate script?
#
color() {
    STARTCOLOR="\e[$2";
    ENDCOLOR="\e[0m";
    export "$1"="$STARTCOLOR%b$ENDCOLOR"
}
color info 96m
color success 92m
color warning 93m
color danger 91m

WORK_DIR=~/tak-server
RELEASE_DIR="${WORK_DIR}/release"
TAK_DIR="${RELEASE_DIR}/tak"

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
TOOLS_DIR=$(dirname $(dirname $SCRIPT_DIR))
TEMPLATE_DIR="${TOOLS_DIR}/templates"

rm -rf $WORK_DIR
mkdir -p $WORK_DIR

unzip /tmp/takserver*.zip -d ${WORK_DIR}/
mv ${WORK_DIR}/tak* ${RELEASE_DIR}/
chown -R $USER:$USER ${WORK_DIR}
VERSION=$(cat ${TAK_DIR}/version.txt | sed 's/\(.*\)-.*-.*/\1/')

TAKADMIN=tak-admin
TAKADMIN_PASS=$(pwgen -cvy1 25)

PG_PASS=$(pwgen -cvy1 25)

echo; echo
HOSTNAME=${HOSTNAME//\./-}
read -p "What is the alias of this Tak Server [${HOSTNAME}]? " TAK_ALIAS
TAK_ALIAS=${TAK_ALIAS:-$HOSTNAME}

echo; echo
DEFAULT_NIC=$(route | grep default | awk '{print $8}')
read -p "Which Network Interface [${DEFAULT_NIC}]? " NIC
NIC=${NIC:-${DEFAULT_NIC}}

IP=$(ip addr show $NIC | grep -m 1 "inet " | awk '{print $2}' | cut -d "/" -f1)


## CoreConfig
#
cp ${TEMPLATE_DIR}/CoreConfig-${VERSION}.xml.tmpl ${TAK_DIR}/CoreConfig.xml
sed -i "s/PG_PASS/${PG_PASS}/" ${TAK_DIR}/CoreConfig.xml
sed -i "s/HOSTIP/${IP}/g" ${TAK_DIR}/CoreConfig.xml

# Replaces takserver.jks with $IP.jks
#sed -i "s/takserver.jks/$IP.jks/g" tak/CoreConfig.xml


# Better memory allocation:
# By default TAK server allocates memory based upon the *total* on a machine.
# Allocate memory based upon the available memory so this still scales
#
sed -i "s/MemTotal/MemFree/g" ${TAK_DIR}/setenv.sh

## Set variables for generating CA and client certs
#
printf $warning "SSL setup. Hit enter (x3) to accept the defaults:\n"
read -p "State (for cert generation). Default [state] :" STATE
export STATE=${STATE:-state}

read -p "City (for cert generation). Default [city]:" CITY
export CITY=${CITY:-city}

read -p "Organizational Unit (for cert generation). Default [org]:" ORGANIZATIONAL_UNIT
export ORGANIZATIONAL_UNIT=${ORGANIZATIONAL_UNIT:-orgunit}


# Writes variables to a .env file for docker-compose
#
cat << EOF > ${RELEASE_DIR}/.env
STATE=$STATE
CITY=$CITY
ORGANIZATIONAL_UNIT=$ORGANIZATIONAL_UNIT
EOF

cp ${TOOLS_DIR}/docker/compose.yml ${RELEASE_DIR}/
docker compose --file ${RELEASE_DIR}/compose.yml up --force-recreate -d

## Certs
#
INTERMEDIARY_CA=${TAK_ALIAS}-Intermediate-CA

docker compose exec tak-server bash -c "cd /opt/tak/certs && ./makeRootCa.sh --ca-name ${TAK_ALIAS}-CA"
docker compose exec tak-server bash -c "cd /opt/tak/certs && ./makeCert.sh ca ${INTERMEDIARY_CA}"
docker compose exec tak-server bash -c "cd /opt/tak/certs && ./makeCert.sh server ${TAK_ALIAS}"
docker compose exec tak-server bash -c "cd /opt/tak/certs && ./makeCert.sh client ${TAKADMIN}"
docker compose exec tak-server bash -c "useradd $USER && chown -R $USER:$USER /opt/tak/certs/"
docker compose stop tak-server


