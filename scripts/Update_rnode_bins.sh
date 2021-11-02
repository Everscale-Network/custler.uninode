#!/usr/bin/env bash
SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
# shellcheck source=env.sh
. "${SCRIPT_DIR}/env.sh"

OS_SYSTEM=`uname -s`

./Nodes_Build.sh rust

if [[ "$OS_SYSTEM" == "Linux" ]];then
    sudo service tonnode stop
else
    service tonnode stop
fi

cp -f ${RNODE_SRC_DIR}/target/release/ton_node ${NODE_BIN_DIR}/rnode

# ./setup_as_service.sh

if [[ "$OS_SYSTEM" == "Linux" ]];then
    sudo service tonnode start
else
    service tonnode start
fi

exit 0
