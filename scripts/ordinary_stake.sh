#!/usr/bin/env bash

SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
. "${SCRIPT_DIR}/env.sh"

Dest_Name=$1
Ord_Stake=$2

$CALL_TC depool --addr $(cat ${KEYS_DIR}/${Dest_Name}.addr) stake ordinary --wallet $(cat ${KEYS_DIR}/${VALIDATOR_NAME}.addr) --sign ${KEYS_DIR}/${VALIDATOR_NAME}.keys.json --value $Ord_Stake

exit 0 
