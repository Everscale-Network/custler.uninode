#!/usr/bin/env bash

SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
source "${SCRIPT_DIR}/env.sh"
# source "${SCRIPT_DIR}/functions.shinc"

echo -n "---INFO: Prepare log_cfg for absolutely no logging..."

cp ${R_CFG_DIR}/log_cfg.yml ${SCRIPT_DIR}/log_cfg.tmp

if [[ "$(uname -s)" == "Linux" ]];then
    sed -i 's/level: info/level: off/g' ${SCRIPT_DIR}/log_cfg.tmp
    sed -i 's/level: trace/level: off/g' ${SCRIPT_DIR}/log_cfg.tmp
    sed -i 's/level: debug/level: off/g' ${SCRIPT_DIR}/log_cfg.tmp
    sed -i 's/level: error/level: off/g' ${SCRIPT_DIR}/log_cfg.tmp
else
    sed -i.bak 's/level: info/level: off/g' ${SCRIPT_DIR}/log_cfg.tmp
    sed -i.bak 's/level: trace/level: off/g' ${SCRIPT_DIR}/log_cfg.tmp
    sed -i.bak 's/level: debug/level: off/g' ${SCRIPT_DIR}/log_cfg.tmp
    sed -i.bak 's/level: error/level: off/g' ${SCRIPT_DIR}/log_cfg.tmp
fi

mv -f ${SCRIPT_DIR}/log_cfg.tmp  ${R_CFG_DIR}/log_cfg.yml
echo " ..DONE"

exit 0
