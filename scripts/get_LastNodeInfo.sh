#!/usr/bin/env bash
set -eE

# (C) Sergey Tyurin  2022-06-01 10:00:00

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

#=================================================
echo -e "$(DispEnvInfo)"
echo
echo -e "$(Determine_Current_Network)"
echo

#=================================================
# Get LNIC boc

if [[ "$(Get_Account_Info "$LNIC_ADDRESS"|awk '{print $1}')" != "Active" ]];then
    echo "###-ERROR(line $LINENO): LNIC account not found. Can't continue. Sorry."
    exit 1
else
    OUTPUT="$(Get_SC_current_state "$LNIC_ADDRESS")"
    if [[ $? -ne 0 ]] || [[ -z  "$(echo $OUTPUT | grep 'written StateInit of account')" ]]
    then
        echo "###-ERROR(line $LINENO): Cannot get LNIC account state. Can't continue. Sorry."
        exit 1
    fi
fi
#=================================================
# Get LNIC ABI from contract
# LastNodeInfo.abi.json
GetABI='{"ABI version":2,"version":"2.2","header":["time","expire"],"functions":[{"name":"getABI","inputs":[],"outputs":[{"name":"ABI_7z_hex","type":"string"}]},{"name":"ABI","inputs":[],"outputs":[{"name":"ABI_7z_hex","type":"string"}]}],"data":[],"events":[],"fields":[{"name":"ABI_7z_hex","type":"string"}]}'
echo $GetABI > Get_ABI.json


$CALL_TC -j run --boc ${LNIC_ADDRESS##*:}.boc --abi Get_ABI.json ABI {} | jq -r '.ABI_7z_hex' > LNIC_ABI_7z_hex.txt
xxd -r -p LNIC_ABI_7z_hex.txt > LNIC_ABI.7z
7z x -y LNIC_ABI.7z 2>&1 > /dev/null

ABI="LastNodeInfo.abi.json"
if [[ ! -e "${ABI}" ]];then
    echo "###-ERROR(line $LINENO): Cannot get LNIC ABI from state. Can't continue. Sorry."
    exit 1
fi

#=================================================
# Get Last node info and update schedule
LNI_JSON="$($CALL_TC -j run --boc ${LNIC_ADDRESS##*:}.boc --abi ${ABI} node_info {})"

echo "${LNI_JSON}"

rm -f ${LNIC_ADDRESS##*:}.boc Get_ABI.json LNIC_ABI_7z_hex.txt LNIC_ABI.7z LastNodeInfo.abi.json
exit 0

#########################################
# examples
. ./env.sh
. ./functions.shinc
./get_LastNodeInfo.sh | grep -v 'Version OK' | jq -r '.node_info.LastCommit' | xargs -I {} bash -c 'dec2hex {}'|tr "[:upper:]" "[:lower:]"
# output: c7b2a7af27063cdd0414944a8c34ceb63c7f9dba
# ))


tonos-cli -j run --abi ${Contract_Name}.abi.json $(cat ${Contract_Name}.addr) getALLinfo {}

tonos-cli -j run --abi ${Contract_Name}.abi.json $(cat ${Contract_Name}.addr) getLastNodeInfo {}
tonos-cli -j run --abi ${Contract_Name}.abi.json $(cat ${Contract_Name}.addr) node_info {}
tonos-cli -j run --abi ${Contract_Name}.abi.json $(cat ${Contract_Name}.addr) code_ver {}
tonos-cli -j run --abi ${Contract_Name}.abi.json $(cat ${Contract_Name}.addr) code_updated_time {}
tonos-cli -j run --abi ${Contract_Name}.abi.json $(cat ${Contract_Name}.addr) info_updated_time {}
tonos-cli -j run --abi ${Contract_Name}.abi.json $(cat ${Contract_Name}.addr) ABI {}
tonos-cli -j run --abi ${Contract_Name}.abi.json $(cat ${Contract_Name}.addr) ABI {}|jq -r '.ABI'|xxd -r -p > lnm.7z
tonos-cli -j run --abi ${Contract_Name}.abi.json $(cat ${Contract_Name}.addr) getABI {}
tonos-cli -j run --abi ${Contract_Name}.abi.json $(cat ${Contract_Name}.addr) getABI {}|jq -r '.value0'|xxd -r -p > lnm.7z
