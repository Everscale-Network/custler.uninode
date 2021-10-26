#!/usr/bin/env bash

SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
source "${SCRIPT_DIR}/env.sh"
# source "${SCRIPT_DIR}/functions.shinc"

# 0 - off
# 1 - error
# 2 - info
# 3 - debug
# 4 - trace
case "$1" in
    0)
        "$SCRIPT_DIR/swith_off_all_nodelogs.sh"
        echo "!!!-ATTENTION: Node log level set to 'OFF'"
        exit 0
        ;;
    1)
        LogLevel="error"
        ;;
    2)
        LogLevel="info"
        ;;
    3)
        LogLevel="debug"
        ;;
    4)
        LogLevel="trace"
        ;;
   *)
    echo "###-ERROR(line $LINENO): Unknown Log level. Choose from 0-4"
    exit 1
    ;;
esac

"$SCRIPT_DIR/swith_off_all_nodelogs.sh"

cp ${R_CFG_DIR}/log_cfg.yml ${SCRIPT_DIR}/log_cfg.tmp

if [[ "$(uname -s)" == "Linux" ]];then
    sed -i "s/level: off/level: $LogLevel/g" ${SCRIPT_DIR}/log_cfg.tmp
else
    sed -i.bak "s/level: off/level: $LogLevel/g" ${SCRIPT_DIR}/log_cfg.tmp
fi

mv -f ${SCRIPT_DIR}/log_cfg.tmp  ${R_CFG_DIR}/log_cfg.yml
echo "!!!-ATTENTION: Node log level set to '$LogLevel'"

exit 0
