#!/usr/bin/env bash

# (C) Sergey Tyurin  2022-09-19 13:00:00

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

#################################################################
# Updating tonos-cli to version supported endpoint authorization
LNI_Info="$(get_LastNodeInfo)"
if [[ "$(echo "$LNI_Info"|tail -n 1)" ==  "none" ]];then
    echo "###-WARNING(line $LINENO): Last node info from contract is empty."
else
    export LNIC_present=true
    declare -i LNIC_MIN_TC_VERSION=$(( $(echo ${LNI_Info} | jq -r '.MinCLIversion') + 10000000 ))
fi

# MIN_TC_VERSION from LNIC or from env.sh
declare -i ENV_MIN_TC_VERSION=1$(echo $MIN_TC_VERSION | awk -F'.' '{printf("%d%03d%03d\n", $1,$2,$3)}')
declare -i NUM_MIN_TC_VERSION=$(( LNIC_MIN_TC_VERSION>=ENV_MIN_TC_VERSION ? LNIC_MIN_TC_VERSION : ENV_MIN_TC_VERSION ))

declare -i CurrCurr_TC_Ver_NUM=1$($NODE_BIN_DIR/tonos-cli -j version | jq -r '."tonos-cli"' | awk -F'.' '{printf("%d%03d%03d\n", $1,$2,$3)}')

if [[ $CurrCurr_TC_Ver_NUM -lt $NUM_MIN_TC_VERSION ]];then
    ./upd_tonos-cli.sh
    if [[ $? -gt 0 ]];then
        "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "$Tg_SOS_sign tonos-cli update FAILED $Tg_Exclaim_sign" 2>&1 > /dev/null
    else
        "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "$Tg_CheckMark tonos-cli updated: $(${NODE_BIN_DIR}/tonos-cli version)" 2>&1 > /dev/null
    fi
fi

# set new configs for tonos-cli
source "${SCRIPT_DIR}/functions.shinc"

echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date  +'%F %T %Z')"
echo "================================================================================================"

exit 0
