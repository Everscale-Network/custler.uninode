#!/usr/bin/env bash
set -eE

# (C) Sergey Tyurin  2022-05-15 10:00:00

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
echo "#################################### Send tokens script ########################################"
echo "INFO: $(basename "$0") BEGIN $(date +%s) / $(date  +'%F %T %Z')"

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
echo -e "$(DispEnvInfo)"
echo
echo -e "$(Determine_Current_Network)"
echo

SEND_ATTEMPTS="10"

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

declare -i NANO_AMOUNT=`echo "$TRANSF_AMOUNT * 1000000000" | $CALL_BC|cut -d '.' -f 1`
if [[ $NANO_AMOUNT -lt 100000 ]];then
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

#================================================================
echo "Check SRC $SRC_NAME account.."
ACCOUNT_INFO="$(Get_Account_Info $SRC_ACCOUNT)"
SRC_STATUS=`echo $ACCOUNT_INFO |awk '{print $1}'`
declare -i SRC_AMOUNT=`echo "$ACCOUNT_INFO" |awk '{print $2}'`
SRC_TIME=`echo "$ACCOUNT_INFO" | gawk '{ print strftime("%Y-%m-%d %H:%M:%S", $3)}'`
SRC_Time_Unix=`echo $ACCOUNT_INFO |awk '{print $3}'`

if [[ "$SRC_STATUS" == "None" ]];then
    echo -e "###-ERROR(line $LINENO): ${BoldText}${RedBack}SRC account does not exist! (no tokens, no code, nothing)${NormText}"
    echo "=================================================================================================="
    echo 
    exit 0
fi
if [[ "$SRC_STATUS" == "Uninit" ]];then
    echo -e "###-ERROR(line $LINENO): ${BoldText}${RedBack}SRC account uninitialized!${NormText} Deploy contract code first!"
    echo "=================================================================================================="
    echo 
    exit 0
fi

# Check SRC acc Keys
Calc_Addr=$($CALL_TC genaddr $Wallet_Code --abi $Wallet_ABI --setkey $SRC_KEY_FILE --wc "$SRC_WC" | grep "Raw address:" | awk '{print $3}')
if [[ ! "$SRC_ACCOUNT" == "$Calc_Addr" ]];then
    echo "###-ERROR(line $LINENO): Given SRC account address and calculated address is different. Wrong keys. Can't continue. "
    echo "Given addr: $SRC_ACCOUNT"
    echo "Calc  addr: $Calc_Addr"
    echo 
    exit 1
fi

Custodians="$(Get_Account_Custodians_Info $SRC_ACCOUNT)"
SRC_Conf_QTY=$(echo $Custodians|awk '{print $2}')

#================================================================
echo "Check DST $DST_NAME account.."
ACCOUNT_INFO="$(Get_Account_Info $DST_ACCOUNT)"
declare -i DST_AMOUNT=`echo "$ACCOUNT_INFO" |awk '{print $2}'`
DST_TIME=`echo "$ACCOUNT_INFO" | gawk '{ print strftime("%Y-%m-%d %H:%M:%S", $3)}'`
DST_STATUS=`echo $ACCOUNT_INFO |awk '{print $1}'`
if [[ ! "$DST_STATUS" == "Active" ]] && [[ -z $NEW_ACC ]];then
    echo
    echo "###-ERROR(line $LINENO): DST account is not deployed. To transfer to undeployed account use 'new' parameter"
    tr_usage
    exit 1
fi

#================================================================
Trans_List="$(Get_MSIG_Trans_List ${SRC_ACCOUNT})"
Before_Trans_QTY=`echo "$Trans_List" | jq -r ".transactions|length"`
Before_Trans_QTY=$((Before_Trans_QTY))

[[ $Before_Trans_QTY -ne 0 ]] && echo "+++WARNING(line $LINENO): You have $Before_Trans_QTY unsigned transactions already."
echo
echo "TRANFER FROM ${SRC_NAME} :"
echo "SRC Account: $SRC_ACCOUNT"
echo "Has balance : $(echo "scale=3; $((SRC_AMOUNT)) / 1000000000" | $CALL_BC) tokens"
echo "Last operation time: $SRC_TIME"
echo
echo "TRANFER TO ${DST_NAME} :"
echo "DST Account: $DST_ACCOUNT"
echo "Has balance : $(echo "scale=3; $((DST_AMOUNT)) / 1000000000" | $CALL_BC) tokens"
echo "Last operation time: $DST_TIME"
echo
echo "Transferring $TRANSF_AMOUNT ($NANO_AMOUNT) from ${SRC_NAME} to ${DST_NAME} ..." 

if [[ $SRC_AMOUNT -le $NANO_AMOUNT ]];then
    echo
    echo "###-ERROR(line $LINENO): You cannot transfer more than you have. Sorry.."
    echo
    exit 1
fi

read -p "### CHECK INFO TWICE!!! Is this a right tranfer?  (y/n)? " </dev/tty answer
case ${answer:0:1} in
    y|Y )
        echo "Processing....."
    ;;
    * )
        echo "Cancelled."
        exit 1
    ;;
esac

#================================================================
# Make BOC file to send
TA_BOC_File="${KEYS_DIR}/Transfer_Amount.boc"
rm -f "${TA_BOC_File}" &>/dev/null
TC_OUTPUT="$($CALL_TC message --raw --output ${TA_BOC_File} \
--sign "${SRC_KEY_FILE}" \
--abi "${Wallet_ABI}" \
${SRC_ACCOUNT} submitTransaction \
"{\"dest\":\"${DST_ACCOUNT}\",\"value\":${NANO_AMOUNT},\"bounce\":$BOUNCE,\"allBalance\":false,\"payload\":\"\"}" \
--lifetime 600 | grep -i 'Message saved to file')"

if [[ -z $TC_OUTPUT ]];then
    echo "###-ERROR(line $LINENO): Failed to make BOC file ${TA_BOC_File}. Can't continue."
    exit 1
fi
echo "INFO: Message BOC file created: ${TA_BOC_File}"

# ==========================================================================
for (( i=1; i<=${SEND_ATTEMPTS}; i++ )); do
    echo -n "INFO: submitTransaction attempt #${i}..."
    result=`Send_File_To_BC "${TA_BOC_File}"`
    if [[ "$result" == "failed" ]]; then
        echo " FAIL"
        echo "Now sleep $LC_Send_MSG_Timeout secs and will try again.."
        echo "--------------"
        sleep $LC_Send_MSG_Timeout
        continue
    else
        echo " PASS"
    fi
    
    echo "Now sleep $LC_Send_MSG_Timeout secs and check transactions..."
    sleep $LC_Send_MSG_Timeout

   if [[ $SRC_Conf_QTY -le 1 ]];then
        ACCOUNT_INFO="$(Get_Account_Info $SRC_ACCOUNT)"
        Time_Unix=`echo $ACCOUNT_INFO |awk '{print $3}'`
        if [[ $Time_Unix -gt $SRC_Time_Unix ]];then
            echo -e "INFO: successfully sent $TRANSF_AMOUNT tokens."
            break
        fi
   fi

    Trans_List="$(Get_MSIG_Trans_List ${SRC_ACCOUNT})"
    Trans_QTY=`echo "$Trans_List" | jq -r ".transactions|length"`
    Trans_QTY=$((Trans_QTY))
    if [[ $Trans_QTY -gt $Before_Trans_QTY ]] && [[ $SRC_Conf_QTY -gt 1 ]];then
        Last_Trans_ID=`echo "$Trans_List" | jq -r .transactions[$((Trans_QTY - 1))].id`
        echo -e "INFO: successfully created transaction # $Last_Trans_ID"
        break
   fi
done

[[ $Trans_QTY -gt 0 ]] && echo && echo "+++WARNING(line $LINENO): You have $Trans_QTY unsigned transactions now." && echo

# ==========================================================================

echo "Check SRC $SRC_NAME account.."
ACCOUNT_INFO="$(Get_Account_Info $SRC_ACCOUNT)"
SRC_AMOUNT=`echo "$ACCOUNT_INFO" |awk '{print $2}'`
SRC_TIME=`echo "$ACCOUNT_INFO" | gawk '{ print strftime("%Y-%m-%d %H:%M:%S", $3)}'`

echo "Check DST $DST_NAME account.."
ACCOUNT_INFO="$(Get_Account_Info $DST_ACCOUNT)"
DST_AMOUNT=`echo "$ACCOUNT_INFO" |awk '{print $2}'`
DST_TIME=`echo "$ACCOUNT_INFO" | gawk '{ print strftime("%Y-%m-%d %H:%M:%S", $3)}'`

echo
echo "${SRC_NAME} Account: $SRC_ACCOUNT"
echo "Has balance : $(echo "scale=3; $((SRC_AMOUNT)) / 1000000000" | $CALL_BC) tokens"
echo "Last operation time: $SRC_TIME"

echo
echo "${DST_NAME} Account: $DST_ACCOUNT"
echo "Has balance : $(echo "scale=3; $((DST_AMOUNT)) / 1000000000" | $CALL_BC) tokens"
echo "Last operation time: $DST_TIME"
echo

echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date)"
echo "=================================================================================================="
exit 0
