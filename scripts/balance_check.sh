#!/bin/bash -eE

SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/functions.shinc"

#=================================================
echo
echo "${0##*/} Time Now: $(date  +'%F %T %Z')"
echo "INFO from env: Network: $NETWORK_TYPE; Node: $NODE_TYPE; Elector: $ELECTOR_TYPE; Staking mode: $STAKE_MODE"
echo
echo -e "$(Determine_Current_Network)"
echo

#===========================================================
# Check DApp server
DApp_State="$(Check_DApp_URL)"
if [[ "$DApp_State" != "fine" ]];then
    echo "###-ERROR(line $LINENO): DApp server has state: $DApp_State. Check network type in env.sh and URL in tonos-cli.conf.json"
#    exit 1
fi

ACCOUNT=$1
if [[ -z $ACCOUNT ]];then
    MY_ACCOUNT=`cat "${KEYS_DIR}/${VALIDATOR_NAME}.addr"`
    if [[ -z $MY_ACCOUNT ]];then
        echo " Can't find ${KEYS_DIR}/${VALIDATOR_NAME}.addr"
        exit 1
    else
        ACCOUNT=$MY_ACCOUNT
    fi
else
    acc_fmt="$(echo "$ACCOUNT" |  awk -F ':' '{print $2}')"
    [[ -z $acc_fmt ]] && ACCOUNT=`cat "${KEYS_DIR}/${ACCOUNT}.addr"`
fi
echo "Account: $ACCOUNT"

ACCOUNT_INFO="$(Get_Account_Info $ACCOUNT)"
ACC_STATUS=`echo $ACCOUNT_INFO |awk '{print $1}'`
if [[ "$ACC_STATUS" == "None" ]];then
    echo -e "${BoldText}${RedBack}Account does not exist! (no tokens, no code, nothing)${NormText}"
    echo "=================================================================================================="
    exit 0
fi
[[ "$ACC_STATUS" == "Uninit" ]] && ACC_STATUS="${BoldText}${YellowBack}Uninit${NormText}" || ACC_STATUS="${BoldText}${GreeBack}Deployed and Active${NormText}"

AMOUNT=`echo "$ACCOUNT_INFO" |awk '{print $2}'`
ACC_LAST_OP_TIME=`echo "$ACCOUNT_INFO" | gawk '{ print strftime("%Y-%m-%d %H:%M:%S", $3)}'`

echo -e "Status: $ACC_STATUS"
echo "Has balance : $(echo "scale=3; $((AMOUNT)) / 1000000000" | $CALL_BC) tokens"
echo "Last operation time: $ACC_LAST_OP_TIME"
if [[ "$(echo $ACCOUNT_INFO |awk '{print $1}')" == "Active" ]];then
    Custodians="$(Get_Account_Custodians_Info $ACCOUNT)"
    echo "Total custodians: $(echo $Custodians|awk '{print $1}'); Required to confirm: $(echo $Custodians|awk '{print $2}')"
fi

echo "=================================================================================================="
exit 0
