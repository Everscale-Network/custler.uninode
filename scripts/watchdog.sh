#!/usr/bin/env bash

# (C) Sergey Tyurin  2021-01-25 15:00:00

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

echo
echo "################################ Watchdog script ######################################"
echo "INFO: $(basename "$0") BEGIN $(date +%s) / $(date  +'%F %T %Z')"

SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/functions.shinc"

[[ ! -d ${ELECTIONS_WORK_DIR} ]] && mkdir -p ${ELECTIONS_WORK_DIR}

#=================================================
echo "INFO from env: Network: $NETWORK_TYPE; Node: $NODE_TYPE; Elector: $ELECTOR_TYPE; Staking mode: $STAKE_MODE"
echo
echo -e "$(Determine_Current_Network)"
echo

OS_SYSTEM=`uname -s`
SLEEP_TIMEOUT=$1
SLEEP_TIMEOUT=${SLEEP_TIMEOUT:="60"}
ALARM_TIME_DIFF=$2
ALARM_TIME_DIFF=${ALARM_TIME_DIFF:=100}

Current_Net=$(echo "${NETWORK_TYPE}" | cut -d '.' -f 1)
Current_Node=$(echo "${NODE_TYPE}" | cut -c 1)
Prefix="${Current_Node} ${Current_Net}"

#########################
FC_TRY_COUNT=11
TRY_FC_Before_Reboot=4
#########################
fine_counter=$FC_TRY_COUNT
reboot_countdown=$TRY_FC_Before_Reboot
Prev_TD=1000000

function countdown_and_restart(){
    export fine_counter=$((fine_counter - 1))
    if [[ $fine_counter -le 0 ]] && [[ $reboot_countdown -gt 0 ]];then
        export fine_counter=$FC_TRY_COUNT
        export reboot_countdown=$((reboot_countdown - 1))
        "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "===== ALARM! Node service restarting!!! =====" 2>&1 > /dev/null
        if [[ "$OS_SYSTEM" == "Linux" ]];then
            sudo service tonnode restart|cat
        else
            service tonnode restart|cat
        fi
    fi
    if [[ $reboot_countdown -le 0 ]];then
        # touch ${KEYS_DIR}/watchdog.beginning
        touch ${KEYS_DIR}/watchdog.blocked
        "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "##### ALARM! REBOOT SERVER!!!! #####" 2>&1 > /dev/null
        sudo reboot
    fi
}

while(true)
do
    TIME_DIFF=$(Get_TimeDiff)
    case $TIME_DIFF in
        "Node Down")
            echo "${Prefix} Time: $(date +'%F %T %Z') ###-ALARM! NODE IS DOWN." | tee -a ${NODE_LOGS_ARCH}/time-diff.log
            if [[ ! -f ${KEYS_DIR}/watchdog.beginning  ]];then
                "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "ALARM! NODE IS DOWN." 2>&1 > /dev/null
                countdown_and_restart
                sleep $SLEEP_TIMEOUT
            fi
            ;;
        "No TimeDiff Info")
            echo "${Prefix} Time: $(date +'%F %T %Z') --- No masterchain blocks received yet." | tee -a ${NODE_LOGS_ARCH}/time-diff.log
            if [[ ! -f ${KEYS_DIR}/watchdog.beginning  ]];then
                "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "${Prefix} ALARM! No TimeDiff Info." 2>&1 > /dev/null
                countdown_and_restart
                sleep $SLEEP_TIMEOUT
            fi
            ;;
        *)
            echo "${Prefix} Time: $(date +'%F %T %Z') TimeDiff: $TIME_DIFF" | tee -a ${NODE_LOGS_ARCH}/time-diff.log
            [[ -f ${KEYS_DIR}/watchdog.beginning  ]] && rm -f ${KEYS_DIR}/watchdog.beginning
            if [[ $TIME_DIFF -gt $ALARM_TIME_DIFF ]];then
                if [[ -f ${KEYS_DIR}/watchdog.blocked  ]];then
                    if [[ $Prev_TD -gt $TIME_DIFF ]];then
                        Prev_TD=$TIME_DIFF
                        fine_counter=$FC_TRY_COUNT
                        reboot_countdown=$TRY_FC_Before_Reboot
                    else
                        Prev_TD=$TIME_DIFF
                        countdown_and_restart
                    fi
                else
                    "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "${Prefix} ALARM! NODE out of sync. TimeDiff: $TIME_DIFF" 2>&1 > /dev/null
                    countdown_and_restart
                fi
            else
                [[ -f ${KEYS_DIR}/watchdog.blocked  ]] && rm -f ${KEYS_DIR}/watchdog.blocked
                fine_counter=$FC_TRY_COUNT
                reboot_countdown=$TRY_FC_Before_Reboot
                Prev_TD=1000000
            fi
            ;;
    esac
    sleep $SLEEP_TIMEOUT
done

exit 0
