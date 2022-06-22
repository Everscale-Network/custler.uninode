#!/usr/bin/env bash
set -eE

# (C) Sergey Tyurin  2022-06-15 10:00:00

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

SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/functions.shinc"

# ===================================================
function GET_M_H_D() {
    OS_SYSTEM=`uname -s`
    ival="${1}"
    if [[ "$OS_SYSTEM" == "Linux" ]];then
        echo "$(date  +'%M %H %d' -d @$ival)"
    else
        echo "$(date -r $ival +'%M %H %d')"
    fi
}

#=================================================
# Get LNIC ABI from contract
# LastNodeInfo.abi.json
LNIC_ADDRESS="0:bdcefecaae5d07d926f1fa881ea5b61d81ea748bd02136c0dbe76604323fc347"
GetABI='{"ABI version":2,"version":"2.2","header":["time","expire"],"functions":[{"name":"getABI","inputs":[],"outputs":[{"name":"ABI_7z_hex","type":"string"}]},{"name":"ABI","inputs":[],"outputs":[{"name":"ABI_7z_hex","type":"string"}]}],"data":[],"events":[],"fields":[{"name":"ABI_7z_hex","type":"string"}]}'
echo $GetABI > Get_ABI.json

$CALL_TC account $LNIC_ADDRESS --dumpboc ${LNIC_ADDRESS##*:}.boc 2>&1 > /dev/null
$CALL_TC -j run --boc ${LNIC_ADDRESS##*:}.boc --abi Get_ABI.json ABI {} | jq -r '.ABI_7z_hex' > LNIC_ABI_7z_hex.txt
xxd -r -p LNIC_ABI_7z_hex.txt > LNIC_ABI.7z
7za x -y LNIC_ABI.7z 2>&1 > /dev/null

ABI="LastNodeInfo.abi.json"
if [[ ! -e "${ABI}" ]];then
    echo "###-ERROR(line $LINENO): Cannot get LNIC ABI from state. Can't continue. Sorry."
    exit 1
fi

#=================================================
# Get Last node info from saved boc
LNI_Info="$($CALL_TC -j run --boc ${LNIC_ADDRESS##*:}.boc --abi ${ABI} node_info {} | jq '.node_info')"

#############################
# SET TEST VALUES
#LNI_Info="$(echo ${LNI_Info} |jq '.UpdateStartTime = 1655378769 | .UpdateDuration = 684000')"
#DELAY_TIME=300
#############################

echo "${LNI_Info}"

rm -f ${LNIC_ADDRESS##*:}.boc Get_ABI.json LNIC_ABI_7z_hex.txt LNIC_ABI.7z LastNodeInfo.abi.json

#=================================================
# Current node info
Supp_Blocks="$(Get_Supported_Blocks_Version)"
Node_remote_commit="$(git --git-dir="$RNODE_SRC_DIR/.git" ls-remote 2>/dev/null | grep 'HEAD'|awk '{print $1}')"
Node_local_commit="$(git --git-dir="$RNODE_SRC_DIR/.git" rev-parse HEAD 2>/dev/null)"
Node_bin_commit="$(rnode -V | grep 'NODE git commit' | awk '{print $5}')"
echo "-------------------------------------------------------------------------------------------"
echo "Node remote MASTER commit: $Node_remote_commit"
echo "Node local commit:         $Node_local_commit"
echo "Node commit in BINARY:     $Node_bin_commit"
echo "Net supported blocks:     $(echo $Supp_Blocks|awk '{print $1}')"
echo "Current node blocks:      $(echo $Supp_Blocks|awk '{print $2}')"
echo "Git master branch blocks: $(echo $Supp_Blocks|awk '{print $3}')"
echo "-------------------------------------------------------------------------------------------"
#=================================================
# Node info from contract
LNIC_commit_dec=$(echo ${LNI_Info} | jq -r '.LastCommit')
LNIC_commit="$(dec2hex $LNIC_commit_dec | tr '[:upper:]' '[:lower:]')"
LNIC_Console_commit_dec=$(echo ${LNI_Info} | jq -r '.ConsoleCommit')
LNIC_Console_commit="$(dec2hex $LNIC_Console_commit_dec | tr '[:upper:]' '[:lower:]')"

echo "Node LNIC commit:          $LNIC_commit"
echo "LNIC supported blocks:    $(echo ${LNI_Info}|jq -r '.SupportedBlock')"
echo "Console LNIC commit:       $LNIC_Console_commit"
echo "-------------------------------------------------------------------------------------------"

#=================================================
# Calculate node number in update queue
Validator_addr=`cat ${KEYS_DIR}/${VALIDATOR_NAME}.addr`
declare -i Validator_Upd_Ord=$(( $(hex2dec "$(echo $Validator_addr|cut -c 33,34)") ))
echo
echo "This node queue number: $Validator_Upd_Ord"
#=================================================
# Calculate time to update
declare -i UpdateStartTime=$(echo "$LNI_Info" | jq -r '.UpdateStartTime')
declare -i UpdateDuration=$(echo "$LNI_Info" | jq -r '.UpdateDuration')

declare -i UpdTimeShift=$(( UpdateDuration / 256 * Validator_Upd_Ord))
declare -i CurrNodeUpdTime=$(( UpdTimeShift + UpdateStartTime))

#--------------------------------------------------
election_id=$(Get_Current_Elections_ID)
ELECT_TIME_PAR=$($CALL_TC -j getconfig 15)
declare -i VAL_DUR=`echo "${ELECT_TIME_PAR}"        | jq -r '.validators_elected_for'`
declare -i STRT_BEFORE=`echo "${ELECT_TIME_PAR}"    | jq -r '.elections_start_before'`
Curr_Elect_Time=$((election_id - STRT_BEFORE + DELAY_TIME))
#--------------------------------------------------

ElectionsSkip=$(( (CurrNodeUpdTime - Curr_Elect_Time) / VAL_DUR ))
NearElectionsID=$((Curr_Elect_Time + (ElectionsSkip * VAL_DUR) ))
NextElectionsID=$((Curr_Elect_Time + ((ElectionsSkip + 1) * VAL_DUR) ))
TimeRest=$(( CurrNodeUpdTime - NearElectionsID ))

[[ $TimeRest -lt 1800 ]] && CurrNodeUpdTime=$(( CurrNodeUpdTime + (1800 - TimeRest) ))
[[ $TimeRest -gt $((VAL_DUR - 1800)) ]] && CurrNodeUpdTime=$(( CurrNodeUpdTime - (1800 - (VAL_DUR - TimeRest) ) ))

echo "ElectionsSkip: $ElectionsSkip"
echo "TimeRest: $TimeRest"
echo "this node time shift: $UpdTimeShift"

echo "Current Elections Start  $Curr_Elect_Time / $(TD_unix2human $Curr_Elect_Time)"
echo "Nearest Elections Start  $NearElectionsID / $(TD_unix2human $NearElectionsID)"
echo "Next Elections Start     $NextElectionsID / $(TD_unix2human $NextElectionsID)"
echo "This node update time is $CurrNodeUpdTime / $(TD_unix2human $CurrNodeUpdTime)"

#=================================================
# String for cron
CronUpdTime="$(GET_M_H_D $CurrNodeUpdTime)"
echo
echo "Cron string:"
echo "$CronUpdTime * *    cd ${SCRIPT_DIR} && ./Update_ALL.sh &>> ${TON_LOG_DIR}/validator.log"

echo

exit 0
