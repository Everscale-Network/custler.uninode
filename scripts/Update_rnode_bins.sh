#!/usr/bin/env bash
SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
# shellcheck source=env.sh
. "${SCRIPT_DIR}/env.sh"

OS_SYSTEM=`uname -s`

./Nodes_Build.sh rust

if [[ "$OS_SYSTEM" == "Linux" ]];then
    sudo service $ServiceName stop
else
    service $ServiceName stop
fi

cp -f ${RNODE_SRC_DIR}/target/release/ton_node ${NODE_BIN_DIR}/rnode

# ./setup_as_service.sh

if [[ "$OS_SYSTEM" == "Linux" ]];then
    sudo service $ServiceName start
else
    service $ServiceName start
fi

exit 0
