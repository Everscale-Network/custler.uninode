#!/usr/bin/env bash

# (C) Sergey Tyurin  2022-02-08 19:00:00

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

export LC_NUMERIC="C"

Addr_List=${KEYS_DIR}/Addr_list.json
if [[ "$1" == "all" ]];then
    Addr_List=${KEYS_DIR}/All_nodes_Addr_list.json
fi
if [[ ! -f "$Addr_List" ]];then
    echo "Error: No file with address list `$Addr_List` "
    exit 1
fi

Addr_QTY=`cat $Addr_List | jq '[.Addresses[]]|length'`

echo
echo "Now is $(date +'%F %T %Z')"
declare -i MSIG_Total_Balance=0
declare -i Tik_Total_Balance=0
declare -i DP_Total_Balance=0
echo "       Name      MSIG         Tik       DePool"
for (( i=0; i<$Addr_QTY; i++ ))
do
    Name=`cat $Addr_List|jq -r "[.Addresses[]]|.[${i}]|keys[]"`

    MSIG_Addr=`cat $Addr_List|jq -r "[.Addresses[]]|.[${i}].${Name}.msig"`
    MSIG_Balance_nT=`$CALL_TC account "$MSIG_Addr" |grep -i 'balance'|awk '{print $2}'`
    MSIG_Total_Balance=$((MSIG_Total_Balance + MSIG_Balance_nT))
    MSIG_Balance=$(printf "%'9.2f" "$(echo $((MSIG_Balance_nT)) / 1000000000 | jq -nf /dev/stdin)")

    TIK_Balance=""
    TIK_Addr=`cat $Addr_List|jq -r "[.Addresses[]]|.[${i}].${Name}.Tik"`
    if [[ -n $TIK_Addr ]];then
        TIK_Balance_nT=`$CALL_TC account "$TIK_Addr" |grep -i 'balance'|awk '{print $2}'`
        TIK_Total_Balance=$((TIK_Total_Balance + TIK_Balance_nT))
        TIK_Balance=$(printf "%'9.2f" "$(echo $((TIK_Balance_nT)) / 1000000000 | jq -nf /dev/stdin)")
    fi
    
    DP_Balance=""
    DP_Addr=`cat $Addr_List|jq -r "[.Addresses[]]|.[${i}].${Name}.depool"`
    if [[ -n $DP_Addr ]];then
        DP_Balance_nT=`$CALL_TC account "$DP_Addr" |grep -i 'balance'|awk '{print $2}'`
        DP_Total_Balance=$((DP_Total_Balance + DP_Balance_nT))
        DP_Balance=$(printf "%'9.2f" "$(echo $((DP_Balance_nT)) / 1000000000 | jq -nf /dev/stdin)")
    fi

    echo "$(printf "%'10s" "$Name"): $MSIG_Balance   $TIK_Balance    $DP_Balance"
done
echo "---------------------------------------------------------------------------"
echo "     TOTAL: $(printf "%'9.2f" "$(echo $((MSIG_Total_Balance)) / 1000000000 | jq -nf /dev/stdin)")"
echo "========================================================="
exit 0
