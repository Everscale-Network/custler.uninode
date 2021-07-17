#!/bin/bash
# (C) Sergey Tyurin  2021-01-22 10:00:00

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
 
echo "################################### Send tokens script ########################################"

function tr_usage(){
    echo
    echo " use: transfer_amount.sh <SRC> <DST> <AMOUNT> [new]"
    echo " new - for transfer to not activated account (for creation)"
    echo
    exit 0
}

[[ $# -le 2 ]] && tr_usage

SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/functions.shinc"
echo
echo "Time Now: $(date  +'%F %T %Z')"
echo "INFO from env: Network: $NETWORK_TYPE; Node: $NODE_TYPE; Elector: $ELECTOR_TYPE"
echo
echo -e "$(Determine_Current_Network)"
echo


#===========================================================
# Check wallet code & ABI
Wallet_Code=${SafeSCs_DIR}/SafeMultisigWallet.tvc
Wallet_ABI=${SafeSCs_DIR}/SafeMultisigWallet.abi.json
if [[ ! -f $Wallet_Code ]] || [[ ! -f $Wallet_ABI ]];then
    echo "###-ERROR(line $LINENO): Can not find Wallet code or ABI. Check contracts folder."  
    show_usage
    exit 1
fi
echo "Wallet Code: $Wallet_Code"
echo "ABI for wallet: $Wallet_ABI"

#===========================================================
# 
SRC_NAME=$1
DST_NAME=$2
TRANSF_AMOUNT="$3"
NEW_ACC=$4
[[ -z $TRANSF_AMOUNT ]] && tr_usage

NANO_AMOUNT=`$CALL_TC convert tokens $TRANSF_AMOUNT|grep -v 'Config'| grep "[0-9]"`
if [[ $NANO_AMOUNT -lt 100000000 ]];then
    echo "###-ERROR(line $LINENO): Can't transfer too small amount of nanotokens! (${NANO_AMOUNT})nt"
    exit 1
fi
echo "Nanotokens to transfer: $NANO_AMOUNT"

if [[ "$NEW_ACC" == "new" ]];then
    BOUNCE="false"
else
    BOUNCE="true"
fi

SRC_ACCOUNT=`cat ${KEYS_DIR}/${SRC_NAME}.addr`
if [[ -z $SRC_ACCOUNT ]];then
    echo "###-ERROR(line $LINENO): Can't find SRC address! ${KEYS_DIR}/${SRC_ACCOUNT}.addr"
    exit 1
fi
SRC_WC=`echo "$SRC_ACCOUNT" | cut -d ':' -f 1`

DST_ACCOUNT=$DST_NAME
acc_fmt="$(echo "$DST_ACCOUNT" |  awk -F ':' '{print $2}')"
[[ -z $acc_fmt ]] && DST_ACCOUNT=`cat "${KEYS_DIR}/${DST_NAME}.addr"`
if [[ -z $DST_ACCOUNT ]];then
    echo "###-ERROR(line $LINENO): Can't find DST_ACCOUNT address file! ${KEYS_DIR}/${DST_NAME}.addr"
    exit 1
fi
dst_addr=`echo $DST_ACCOUNT | cut -d ':' -f 2`
dst_wc=`echo $DST_ACCOUNT | cut -d ':' -f 1`
if [[ ${#dst_addr} -ne 64 ]] || [[ ${dpc_wc} -ne 0 ]];then
    echo "###-ERROR(line $LINENO): Wrong DST address! ${DST_ACCOUNT}"
    exit 1
fi

SRC_KEY_FILE="${KEYS_DIR}/${1}.keys.json"
msig_public=`cat $SRC_KEY_FILE | jq -r ".public"`
msig_secret=`cat $SRC_KEY_FILE | jq -r ".secret"`
if [[ -z $msig_public ]] || [[ -z $msig_secret ]];then
    echo "###-ERROR(line $LINENO): Can't find SRC public and/or secret key!"
    exit 1
fi

echo "Check SRC $SRC_NAME account.."
SRC_BALANCE_INFO=`$CALL_TC account $SRC_ACCOUNT || echo "ERROR get balance" && exit 0`
SRC_AMOUNT=`echo "$SRC_BALANCE_INFO" | grep balance | awk '{ print $2 }'`
SRC_TIME=`echo "$SRC_BALANCE_INFO" | grep last_paid | gawk '{ print strftime("%Y-%m-%d %H:%M:%S", $2)}'`

echo "Check DST $DST_NAME account.."
DST_BALANCE_INFO=`$CALL_TC account $DST_ACCOUNT || echo "ERROR get balance" && exit 0`
DST_AMOUNT=`echo "$DST_BALANCE_INFO" | grep balance | awk '{ print $2 }'`
DST_TIME=`echo "$DST_BALANCE_INFO" | grep last_paid | gawk '{ print strftime("%Y-%m-%d %H:%M:%S", $2)}'`
DST_STATUS=`echo "$DST_BALANCE_INFO" | grep 'acc_type:'|awk '{print $2}'`
if [[ ! "$DST_STATUS" == "Active" ]] && [[ -z $NEW_ACC ]];then
    echo
    echo "###-ERROR(line $LINENO): DST account is not deployed. To transfer to undeployed account use 'new' parameter"
    tr_usage
    exit 1
fi

#================================================================
# Check Keys
Calc_Addr=$($CALL_TC genaddr $Wallet_Code $Wallet_ABI --setkey $SRC_KEY_FILE --wc "$SRC_WC" | grep "Raw address:" | awk '{print $3}')
if [[ ! "$SRC_ACCOUNT" == "$Calc_Addr" ]];then
    echo "###-ERROR(line $LINENO): Given account address and calculated address is different. Wrong keys. Can't continue. "
    echo "Given addr: $SRC_ACCOUNT"
    echo "Calc  addr: $Calc_Addr"
    echo 
    exit 1
fi

#================================================================

echo "TRANFER FROM ${SRC_NAME} :"
echo "SRC Account: $SRC_ACCOUNT"
echo "Has balance : $((SRC_AMOUNT/1000000000)) tokens"
echo "Last operation time: $SRC_TIME"
echo
echo "TRANFER TO ${DST_NAME} :"
echo "DST Account: $DST_ACCOUNT"
echo "Has balance : $((DST_AMOUNT/1000000000)) tokens"
echo "Last operation time: $DST_TIME"
echo
echo "Transferring $TRANSF_AMOUNT ($NANO_AMOUNT) from ${SRC_NAME} to ${DST_NAME} ..." 

# read -p "### CHECK INFO TWICE!!! Is this a right tranfer?  (y/n)? " </dev/tty answer
# case ${answer:0:1} in
#     y|Y )
#         echo "Processing....."
#     ;;
#     * )
#         echo "Cancelled."
#         exit 1
#     ;;
# esac

# ==========================================================================
TC_OUTPUT="$($CALL_TC run ${SRC_ACCOUNT} getTransactions {} --abi $SafeC_Wallet_ABI)"
Trans_List=`echo "$TC_OUTPUT" | sed -e "1,/Succeeded/d" | sed 's/Result: //' `
Before_Trans_QTY=`echo "$Trans_List" | jq -r ".transactions|length"`
Before_Trans_QTY=$((Before_Trans_QTY))

TONOS_CLI_SEND_ATTEMPTS="10"

for i in $(seq ${TONOS_CLI_SEND_ATTEMPTS}); do
    echo "INFO: tonos-cli submitTransaction attempt #${i}..."
    if ! $CALL_TC call ${SRC_ACCOUNT} submitTransaction \
        "{\"dest\":\"${DST_ACCOUNT}\",\"value\":\"${NANO_AMOUNT}\",\"bounce\":$BOUNCE,\"allBalance\":false,\"payload\":\"\"}" \
        --abi "${Wallet_ABI}" \
        --sign "${SRC_KEY_FILE}"; then
        echo "INFO: tonos-cli submitTransaction attempt #${i}... FAIL"
    else
        echo "INFO: tonos-cli submitTransaction attempt #${i}... PASS"
        break
    fi
    TC_OUTPUT="$($CALL_TC run ${SRC_ACCOUNT} getTransactions {} --abi $SafeC_Wallet_ABI)"
    Trans_List=`echo "$TC_OUTPUT" | sed -e "1,/Succeeded/d" | sed 's/Result: //' `
    Trans_QTY=`echo "$Trans_List" | jq -r ".transactions|length"`
    Trans_QTY=$((Trans_QTY))
    if [[ $Trans_QTY -gt $Before_Trans_QTY ]];then
        Last_Trans_ID=`echo "$Trans_List" | grep '"id":'| tail -n 1 | awk '{print $2}'|tr -d '"'|tr -d ','`
        echo -e "INFO: tonos-cli successfully created transaction # $Last_Trans_ID"
        break
   fi
    sleep 5s
done
# ==========================================================================

echo "Check SRC $SRC_NAME account.."
SRC_BALANCE_INFO=`$CALL_TC account $SRC_ACCOUNT || echo "ERROR get balance" && exit 0`
SRC_AMOUNT=`echo "$SRC_BALANCE_INFO" | grep balance | awk '{ print $2 }'`
SRC_TIME=`echo "$SRC_BALANCE_INFO" | grep last_paid | gawk '{ print strftime("%Y-%m-%d %H:%M:%S", $2)}'`

echo "Check DST $DST_NAME account.."
DST_BALANCE_INFO=`$CALL_TC account $DST_ACCOUNT || echo "ERROR get balance" && exit 0`
DST_AMOUNT=`echo "$DST_BALANCE_INFO" | grep balance | awk '{ print $2 }'`
DST_TIME=`echo "$DST_BALANCE_INFO" | grep last_paid | gawk '{ print strftime("%Y-%m-%d %H:%M:%S", $2)}'`

echo
echo "${SRC_NAME} Account: $SRC_ACCOUNT"
echo "Has balance : $((SRC_AMOUNT/1000000000)) tokens"
echo "Last operation time: $SRC_TIME"
echo

echo
echo "${DST_NAME} Account: $DST_ACCOUNT"
echo "Has balance : $((DST_AMOUNT/1000000000)) tokens"
echo "Last operation time: $DST_TIME"
echo

exit 0
