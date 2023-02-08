#!/usr/bin/env bash

# (C) Sergey Tyurin  2023-01-17 1:00:00

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

echo
echo "##################################### Postupdate Script ########################################"
echo "INFO: $(basename "$0") BEGIN $(date +%s) / $(date  +'%F %T %Z')"

SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/functions.shinc"

#===========================================================
#  Update network global config
${SCRIPT_DIR}/nets_config_update.sh

#===========================================================
# Check node version for DB reset
Node_commit_from_bin=
Node_bin_ver="$(rnode -V | grep 'Node, version' | awk '{print $4}')"
Node_bin_ver_NUM=$(echo $Node_bin_ver | awk -F'.' '{printf("%d%03d%03d\n", $1,$2,$3)}')
Node_SVC_ver="$($CALL_RC -jc getstats 2>/dev/null|cat|jq -r '.node_version' 2>/dev/null|cat)"
Node_SVC_ver_NUM=$(echo $Node_SVC_ver | awk -F'.' '{printf("%d%03d%03d\n", $1,$2,$3)}')
DB_reset_ver=0051025

#===========================================================
# Check Node Updated, GC set and restarted
if [[ $Node_bin_ver_NUM -ge $DB_reset_ver ]] && \
   [[ $Node_bin_ver_NUM -eq $Node_SVC_ver_NUM ]] && \
   [[ "$(cat ${R_CFG_DIR}/config.json | jq '.gc.enable_for_archives' 2>/dev/null|cat)" == "true" ]];then
   echo "INFO: Check Node Updated - PASSED"
   exit 0
fi

#===========================================================
# For node ver < 0.51.25 and will not set GC 
if [[ $Node_bin_ver_NUM -lt $DB_reset_ver ]] && \
   [[ $Node_bin_ver_NUM -ne $Node_SVC_ver_NUM ]];then
    echo "${Tg_SOS_sign} DANGER: Your node version is less $DB_reset_ver and contains bugs!"
    "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "$Tg_SOS_sign DANGER: Your node version is less $DB_reset_ver and contains bugs!" 2>&1 > /dev/null

    sudo service $ServiceName restart
    sleep 2
    if [[ -z "$(pgrep rnode)" ]];then
        echo "###-ERROR(line $LINENO): Node process not started!"
        "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "$Tg_SOS_sign ###-ERROR(line $LINENO): Node process not started!" 2>&1 > /dev/null
        exit 1
    fi
    ${SCRIPT_DIR}/wait_for_sync.sh
    #===========================================================
    # Check and show the Node version
    Node_bin_commit="$(rnode -V | grep 'NODE git commit:' | awk '{print $5}')"
    EverNode_Version="$(${NODE_BIN_DIR}/rnode -V | grep -i 'TON Node, version' | awk '{print $4}')"
    NodeSupBlkVer="$(rnode -V | grep 'BLOCK_VERSION:' | awk '{print $2}')"
    Console_Version="$(${NODE_BIN_DIR}/console -V | awk '{print $2}')"
    TonosCLI_Version="$(${NODE_BIN_DIR}/tonos-cli -V | grep -i 'tonos_cli' | awk '{print $2}')"
    echo "INFO: Node updated. Service restarted. Current versions: node ver: ${EverNode_Version} SupBlock: ${NodeSupBlkVer} node commit: ${Node_bin_commit}, console - ${Console_Version}, tonos-cli - ${TonosCLI_Version}"
    "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "$Tg_CheckMark INFO: Node updated. Service restarted. Current versions: node ver: ${EverNode_Version} node commit: ${Node_bin_commit}, console - ${Console_Version}, tonos-cli - ${TonosCLI_Version}" 2>&1 > /dev/null
    "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "$Tg_SOS_sign DANGER: Your node version is less $DB_reset_ver and contains bugs!" 2>&1 > /dev/null
    return 0
fi

#===========================================================
# For node ver >= 0.51.25  
if [[ $Node_bin_ver_NUM -ge $DB_reset_ver ]] && \   
   [[ $Node_bin_ver_NUM -ne $Node_SVC_ver_NUM ]];then
    GC_in_config=$(cat ${R_CFG_DIR}/config.json | jq '.gc' 2>/dev/null|cat)
    if [[ $GC_in_config == "null" ]];then
        cat /var/ton-work/rnode/configs/config.json | \
        jq '.gc = {"enable_for_archives":  true, "enable_for_shard_state_persistent": true}' > \
        /var/ton-work/rnode/configs/config.json.tmp && \
        cp -f /var/ton-work/rnode/configs/config.json.tmp /var/ton-work/rnode/configs/config.json
    fi
    echo "${Tg_Warn_sign} ATTENTION: The node going to restart and may be out of sync for a few hours if DB needs repair! "
    "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "${Tg_Warn_sign} ATTENTION: The node going to restart and may be out of sync for a few hours if DB needs repair!" 2>&1 > /dev/null

    sudo service $ServiceName restart
    sleep 2
    if [[ -z "$(pgrep rnode)" ]];then
        echo "###-ERROR(line $LINENO): Node process not started!"
        "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "$Tg_SOS_sign ###-ERROR(line $LINENO): Node process not started!" 2>&1 > /dev/null
        exit 1
    fi
    ${SCRIPT_DIR}/wait_for_sync.sh
fi
#===========================================================
# Check and show the Node version
Node_bin_commit="$(rnode -V | grep 'NODE git commit:' | awk '{print $5}')"
EverNode_Version="$(${NODE_BIN_DIR}/rnode -V | grep -i 'TON Node, version' | awk '{print $4}')"
NodeSupBlkVer="$(rnode -V | grep 'BLOCK_VERSION:' | awk '{print $2}')"
Console_Version="$(${NODE_BIN_DIR}/console -V | awk '{print $2}')"
TonosCLI_Version="$(${NODE_BIN_DIR}/tonos-cli -V | grep -i 'tonos_cli' | awk '{print $2}')"
echo "INFO: Node updated. Service restarted. Current versions: node ver: ${EverNode_Version} SupBlock: ${NodeSupBlkVer} node commit: ${Node_bin_commit}, console - ${Console_Version}, tonos-cli - ${TonosCLI_Version}"
"${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "$Tg_CheckMark INFO: Node updated. Service restarted. Current versions: node ver: ${EverNode_Version} node commit: ${Node_bin_commit}, console - ${Console_Version}, tonos-cli - ${TonosCLI_Version}" 2>&1 > /dev/null

#===========================================================
#
# ${SCRIPT_DIR}/DB_Repair_Actions.sh
#
#===========================================================

echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date  +'%F %T %Z')"
echo "================================================================================================"

exit 0
