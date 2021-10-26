#!/usr/bin/env bash

SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
source "${SCRIPT_DIR}/env.sh"
case "${NODE_TYPE}" in
    RUST)
        ;;
    CPP)
        Zero_State_ID=`$CALL_LC -rc "time" -rc "quit" 2>&1 |grep 'zerostate id'|awk -F ':' '{print $3}'|cut -c 1-16`
        echo "$Zero_State_ID"
        ;;
    *)
        echo "###-ERROR(line $LINENO): Unknown node type! Set NODE_TYPE= to 'RUST' or 'CPP' in env.sh"
        exit 1
        ;; 
esac

exit 0
