#!/usr/bin/env bash

# (C) Sergey Tyurin  2022-01-08 19:00:00

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

echo
echo -e "$(Determine_Current_Network)"
echo

SLEEP_TIMEOUT=$1
SLEEP_TIMEOUT=${SLEEP_TIMEOUT:="60"}
ALARM_TIME_DIFF=$2
ALARM_TIME_DIFF=${ALARM_TIME_DIFF:=100}
Current_Net="$(echo "${NODE_TYPE}" | cut -c 1) $(echo "${NETWORK_TYPE}" | cut -d '.' -f 1)"

while(true)
do
    TIME_DIFF=$(Get_TimeDiff)

    if [[ "$TIME_DIFF" == "Node Down" ]];then
        echo "${Current_Net} Time: $(date +'%F %T %Z') ###-ALARM! NODE IS DOWN." | tee -a ${NODE_LOGS_ARCH}/time-diff.log
        "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "ALARM! NODE IS DOWN." 2>&1 > /dev/null
        sleep $SLEEP_TIMEOUT
        continue
    fi

    if [[ "$TIME_DIFF" == "No TimeDiff Info" ]];then
        echo "${Current_Net} Time: $(date +'%F %T %Z') --- No masterchain blocks received yet." | tee -a ${NODE_LOGS_ARCH}/time-diff.log
    else
        MC_TIME_DIFF=$(echo $TIME_DIFF|awk '{print $1}')
        SH_TIME_DIFF=$(echo $TIME_DIFF|awk '{print $2}')

        echo "${Current_Net} Time: $(date +'%F %T %Z') TimeDiff: $TIME_DIFF" | tee -a ${NODE_LOGS_ARCH}/time-diff.log
        if [[ $MC_TIME_DIFF -gt $ALARM_TIME_DIFF ]] || [[ $SH_TIME_DIFF -gt $ALARM_TIME_DIFF ]];then
        :
        "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "ALARM! NODE out of sync. TimeDiffs: MC - $MC_TIME_DIFF ; WC - $SH_TIME_DIFF" 2>&1 > /dev/null
        fi
    fi

    sleep $SLEEP_TIMEOUT
done

exit 0
