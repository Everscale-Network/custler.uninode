#!/bin/bash -eE

# (C) Sergey Tyurin  2021-03-15 15:00:00

# Disclaimer
##################################################################################################################
# You running this script/function means you will not blame the author(s)
# if this breaks your stuff. This script/function is provided AS IS without warranty of any kind. 
# Author(s) disclaim all implied warranties including, without limitation, 
# any implied warranties of merchantability or of fitness for a particular purpose. 
# The entire risk arising out of the use or performance of the sample scripts and documentation remains with you.
# In no event shall author(s) be held liable for any damages whatsoever 
# (including, without limitation, damages for loss of business profits, business interruption, 
# loss of business information, or other pecuniary loss) arising out of the use of or inability 
# to use the script or documentation. Neither this script/function, 
# nor any part of it other than those parts that are explicitly copied from others, 
# may be republished without author(s) express written permission. 
# Author(s) retain the right to alter this disclaimer at any time.
##################################################################################################################

# usage: tg-check_node_sync_status.sh [T - timeout sec] [alarm to tg if time > N]

SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/functions.shinc"

[[ ! -d $HOME/logs ]] && mkdir -p $HOME/logs

SLEEP_TIMEOUT=$1
SLEEP_TIMEOUT=${SLEEP_TIMEOUT:="60"}
ALARM_TIME_DIFF=$2
ALARM_TIME_DIFF=${ALARM_TIME_DIFF:=100}

# ===================================================
function Convert_Date() {
    OS_SYSTEM=`uname`
    ival="${1}"
    if [[ "$OS_SYSTEM" == "Linux" ]];then
        echo "$(date  +'%F %T %Z' -d @$ival)"
    else
        echo "$(date -r $ival +'%F %T %Z')"
    fi
}
# ===================================================
function rnode_TD_check(){
    RC_OUTPUT=$($CALL_RC -c "getstats" 2>&1 | cat)

    NODE_DOWN=$(echo "${RC_OUTPUT}" | grep 'Connection refused' | cat)
    if [[ ! -z $NODE_DOWN ]];then
        echo "Node Down"
        return
    fi

    if [[ ! -z $(echo "${RC_OUTPUT}" | grep 'timediff') ]];then
        TIME_DIFF=$(echo "${RC_OUTPUT}" | tail -n 7 | jq .timediff)
        echo "$TIME_DIFF"
    else
        echo "No TimeDiff Info"
    fi
}
# ===================================================
function cnode_TD_check() {

    VEC_OUTPUT=$($CALL_VC -c "getstats" -c "quit" 2>&1 | cat)

    NODE_DOWN=$(echo "${VEC_OUTPUT}" | grep 'Connection refused' | cat)
    if [[ ! -z $NODE_DOWN ]];then
        echo "Node Down"
        return
    fi

    CURR_TD_NOW=`echo "${VEC_OUTPUT}" | grep 'unixtime' | awk '{print $2}'`
    CHAIN_TD=`echo "${VEC_OUTPUT}" | grep 'masterchainblocktime' | awk '{print $2}'`
    TIME_DIFF=$((CURR_TD_NOW - CHAIN_TD))

    if [[ -z $CHAIN_TD ]];then
        echo "No TimeDiff Info"
    else
        echo "$TIME_DIFF"
    fi
}
# ===================================================
Current_Net=$(echo "${NETWORK_TYPE}" | cut -d '.' -f 1)

TD_check="rnode_TD_check"
[[ "${NODE_TYPE}" == "CPP" ]] && TD_check="cnode_TD_check"

while(true)
do
    TIME_DIFF=$(${TD_check})

    if [[ "$TIME_DIFF" == "Node Down" ]];then
        echo "${Current_Net} Time: $(date +'%F %T %Z') ###-ALARM! NODE IS DOWN." | tee -a ${NODE_LOGS_ARCH}/time-diff.log
        "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "ALARM! NODE IS DOWN." 2>&1 > /dev/null
        sleep $SLEEP_TIMEOUT
        continue
    fi

    if [[ "$TIME_DIFF" == "No TimeDiff Info" ]];then
        echo "${Current_Net} Time: $(date +'%F %T %Z') --- No masterchain blocks received yet." | tee -a ${NODE_LOGS_ARCH}/time-diff.log
    else
        echo "${Current_Net} Time: $(date +'%F %T %Z') TimeDiff: $TIME_DIFF" | tee -a ${NODE_LOGS_ARCH}/time-diff.log
        if [[ $TIME_DIFF -gt $ALARM_TIME_DIFF ]];then
        :
        "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "ALARM! NODE out of sync. TimeDiff: $TIME_DIFF" 2>&1 > /dev/null
        fi
    fi

    sleep $SLEEP_TIMEOUT
done

exit 0
