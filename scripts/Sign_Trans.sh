#!/bin/bash

# (C) Sergey Tyurin  2021-02-18 15:00:00

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
# You have to have installed for confirmations by lite-client :
#   'xxd' - is a part of vim-commons ( [apt/dnf/pkg] install vim[-common] )
#   'jq'
#   'bc' for Linux
#   'dc' for FreeBSD
#   'tvm_linker' compiled binary from https://github.com/tonlabs/TVM-linker.git to $HOME/bin (must be in $PATH)
#   'lite-client'                                               
# ------------------------------------------------------------------------
# Script assumes that: 
#   - all keypairs are in ${KEYS_DIR} folder
#
#   use: Sign_Trans.sh [AccName]
#      AccName - filename of separate acc with AccName{n}.keys.json keys files
#      If AccName omitted - will use $HOSTNAME & msig{n}.keys.json
#
#  To force sign one of few transaction for specified acc
#   use: Sign_Trans.sh [AccName] [TransactionID]
# ------------------------------------------------------------------------

####################
SLEEP_TIMEOUT=10
SEND_ATTEMPTS=10
###################
function sgn_usage(){
echo
echo " use: Sign_Trans.sh [AccName]"
echo " AccName - filename of separate acc with AccName{n}.keys.json keys files"
echo " If AccName omitted - will use $HOSTNAME & msig{n}.keys.json"
echo
exit 0
}
echo
echo "######################################## Signing script ########################################"
echo "INFO: $(basename "$0") BEGIN $(date +%s) / $(date)"

SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/functions.shinc"

echo -e "$(DispEnvInfo)"
echo
echo -e "$(Determine_Current_Network)"
echo

#==================================================
# Acc by name or default 
AccName=$1
if [[ -z $AccName ]];then
    MSIG_ADDR=`cat "${KEYS_DIR}/${HOSTNAME}.addr"`
    KeyFileName="$HOSTNAME"
    if [[ -z $MSIG_ADDR ]];then
        echo "###-ERROR(line $LINENO): Can't find ${KEYS_DIR}/${HOSTNAME}.addr" && sgn_usage
        exit 1
    fi
else
    MSIG_ADDR=`cat "${KEYS_DIR}/${AccName}.addr"`
    KeyFileName="${AccName}"
    if [[ -z $MSIG_ADDR ]];then
        echo "###-ERROR(line $LINENO): Can't find ${KEYS_DIR}/${AccName}.addr" && sgn_usage
        exit 1
    fi
fi
#=================================================
# Set TransID if specified
TrID_force=$2
[[ -n ${TrID_force} ]] && echo -e "${RedBack}${BoldText}Forced to confirm transaction #: ${TrID_force}${NormText}"
#=================================================
# Test binaries
if [[ -z $(jq --help 2>/dev/null |grep -i "Usage"|cut -d ":" -f 1) ]];then
    echo "###-ERROR(line $LINENO): 'jq' not installed in PATH"
    exit 1
fi

#=================================================
# 
workchain=`echo "${MSIG_ADDR}" | cut -d ':' -f 1`
echo "MSIG_ADDR = ${MSIG_ADDR}"
echo "WorkChain:  $workchain"

##############################################################################
# Get and check Transaction ID to sign
# TC_OUTPUT="$($CALL_TC run ${MSIG_ADDR} getTransactions {} --abi $SafeC_Wallet_ABI)"
# Trans_List=`echo "$TC_OUTPUT" | sed -e "1,/Succeeded/d" | sed 's/Result: //' `
Trans_List="$(Get_MSIG_Trans_List ${MSIG_ADDR})"
Trans_QTY=`echo "$Trans_List" | jq -r ".transactions|length"`
Trans_QTY=$((Trans_QTY))
if [[ $Trans_QTY -eq 0 ]];then
    echo
    echo "###-ERROR(line $LINENO): Trans_QTY=$Trans_QTY. NO transactions to sign. Exit."
    echo
    exit 0
fi
if [[ $Trans_QTY -gt 1 ]] && [[ -z ${TrID_force} ]];then
    echo "$Trans_List"
    echo
    echo "###-ERROR(line $LINENO): Trans_QTY=$Trans_QTY. Multi transaction bulk signing not allowed now! Exit."
    echo "To force confirm one transaction, use './Sign_Trans.sh AccName TransID' "
    echo
    exit 1
fi

Trans_ID=`echo "$Trans_List" | jq -r '.transactions[].id'`
if [[ -z ${Trans_ID} ]] || [[ "${Trans_ID}" == "0" ]];then
    echo "###-ERROR(line $LINENO): Error getting transaction ID: '${Trans_ID}'. Exit."
    echo
    exit 1
fi

if [[ -n ${TrID_force} ]];then
    Trans_ID=${TrID_force}
    echo "Set TransID to ${Trans_ID}"
fi

if [[ -z $(echo "$Trans_List"|grep "${Trans_ID}") ]];then
    echo
    echo "###-ERROR(line $LINENO): Transaction # ${Trans_ID} not found in list. Exit."
    echo
    exit 1
fi
echo "Found $Trans_QTY transaction. Will sign transaction with ID: $Trans_ID"

##############################################################################
# Get Required number of confirmations
Confirms_QTY=`echo "$Trans_List" | jq -r ".transactions[]|select(.id == \"$Trans_ID\")|.signsRequired"`
Confirms_QTY=$((Confirms_QTY))
# Get Received number of confirmations
Conf_Recv_QTY=`echo "$Trans_List" | jq -r ".transactions[]|select(.id == \"$Trans_ID\")|.signsReceived"`
Conf_Recv_QTY=$((Conf_Recv_QTY))

echo "Required number of confirmations: $Confirms_QTY. Received confirmations: $Conf_Recv_QTY"
echo "******************************"

##############################################################################
# Send signatures one by one with checks 
# Assume that transaction was made and already signed by custodian with pubkey index # 0x0
# other custodians has keys in files 
Confirmed_Flag=false
for (( i=$((Conf_Recv_QTY + 1)); i <= ${Confirms_QTY}; i++ ))
do
    Signed_Flag=false
    for (( Attempts_to_send=1;  Attempts_to_send <= ${SEND_ATTEMPTS};  Attempts_to_send++ ))
    do
        #======================================================================
        # Send confirmations signature by tonos-cli
        echo "Try #${Attempts_to_send} to send confirmations signature #${i} from file ${KeyFileName}_${i}.keys.json"

        # TC_OUTPUT="$(
        # if $CALL_TC call ${MSIG_ADDR} confirmTransaction "{\"transactionId\":\"${Trans_ID}\"}" --abi $SafeC_Wallet_ABI --sign ${KEYS_DIR}/${KeyFileName}_${i}.keys.json 2>&1 | \
        #     tee ${ELECTIONS_WORK_DIR}/${KeyFileName}_tr_sign_${i}.log; then
        #     echo
        # fi
        # TC_OUTPUT="$($CALL_TC run ${MSIG_ADDR} getTransactions {} --abi $SafeC_Wallet_ABI)"
        # Trans_List=`echo "$TC_OUTPUT" | sed -e "1,/Succeeded/d" | sed 's/Result: //' `
        Send_MSIG_Trans_Confirm "${Trans_ID}" "${MSIG_ADDR}" "${KEYS_DIR}/${KeyFileName}_${i}.keys.json"

        Trans_List="$(Get_MSIG_Trans_List ${MSIG_ADDR})"
        CurrTransInfo=`echo "${Trans_List}" | jq ".transactions[]|select(.id == \"$Trans_ID\")"`
        if [[ -z ${CurrTransInfo} ]];then
            echo "\$\$\$-SUCCESS: Transaction # $Trans_ID signed and send"
            Confirmed_Flag=true
            Signed_Flag=true
            break
        fi
        RcvQTY=`echo "${CurrTransInfo}" | jq -r ".signsReceived"`
        RcvQTY=$((RcvQTY))
        if [[ $RcvQTY -gt $Conf_Recv_QTY ]];then
            echo "Signing transaction $Trans_ID by custodian ${i} was done SUCCESSFULLY!"
            echo
            Conf_Recv_QTY=$RcvQTY
            Signed_Flag=true
            break
        fi
        echo "###-ERROR(line $LINENO): Confirmation try # ${i} FAILED!!! Will try again..."
        echo
        sleep $SLEEP_TIMEOUT
    done
    ########################################
    if ! $Signed_Flag;then
        echo "###-ERROR(line $LINENO): CANNOT sign transaction $Trans_ID by key # ${i} from file: ${KEYS_DIR}/${KeyFileName}_${i}.keys.json"
    fi
    #======================================================================
    # Chech transaction signed and leaved
    if $Confirmed_Flag;then
        echo "\$\$\$-SUCCESS: Transaction # $Trans_ID signed and send"
        break
    fi
done

if [[ ! $Confirmed_Flag ]] ;then
    echo "###-ERROR: CANNOT sign transaction $Trans_ID by key # ${i} with pubkey: $msig_public from file: ${KEYS_DIR}/${KeyFileName}_${i}.keys.json"
    "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "$Tg_SOS_sign ALARM!!! Signing transaction $Trans_ID for election FAILED!!!" 2>&1 > /dev/null
    exit 1
fi

# "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "Transaction $Trans_ID for election confirmed." 2>&1 > /dev/null

echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date  +'%F %T %Z')"
echo "================================================================================================"

exit 0
