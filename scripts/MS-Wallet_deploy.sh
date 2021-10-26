#!/usr/bin/env bash

# (C) Sergey Tyurin 2021-10-19 19:00:00

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
#

echo
echo "################################## Deploy wallet script ########################################"
echo "INFO: $(basename "$0") BEGIN $(date +%s) / $(date  +'%F %T %Z')"

#==================================================
# Set environment
SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/functions.shinc"

echo
echo -e "$(DispEnvInfo)"
echo

KEY_FILES_DIR=${KEYS_DIR}
SEND_ATTEMPTS=3

function show_usage(){
echo
echo " Use: MS-Wallet_deploy.sh <Wallet name> <'Safe' or 'SetCode'> <Num of custodians> <Min Num of signatures>"
echo " All fields required!"
echo " All files for deploy will search in '$KEY_FILES_DIR'. You can change var 'KEY_FILES_DIR' at the beginning of the script."
echo " If the wallet name is equal HOSTAME than files msig[1..31].keys.json will be used"
echo "   first signature file is used to sign deploy message"
echo " <Min Num of signatures> must be less or equal of <Num of custodians> and min - 2"
echo
echo " Example: MS-Wallet_deploy.sh MyWal Safe 5 3"
echo
exit 0
}
[[ $# -lt 3 ]] && show_usage

#============================================
echo "Deploy wallet to '${NETWORK_TYPE}' network"

#==================================================
# Check input parametrs
WAL_NAME=$1

CodeOfWallet="$2"
if [[ ! $CodeOfWallet == "Safe" ]] && [[ ! $CodeOfWallet == "SetCode" ]];then
    echo "###-ERROR(line $LINENO): Wrong code of wallet. Choose 'Safe' or 'SetCode'"
    show_usage
    exit 1
fi
Cust_QTY=$3
if [[ $Cust_QTY -lt 1 ]] || [[ $Cust_QTY -gt 32 ]];then
    echo "###-ERROR(line $LINENO): Wrong Num of custodians must be >= 1 and <= 31"  
    show_usage
    exit 1
fi
ReqConfirms=$4
if [[ $ReqConfirms -gt $Cust_QTY ]] || [[ $ReqConfirms -lt 1 ]];then
    echo "###-ERROR(line $LINENO): Wrong Required num of signatures."
    show_usage
    exit 1
fi
ForceDeploy=$5

#==================================================
# Get Wallet address for deploy
echo "Wallet Name: $WAL_NAME"
WALL_ADDR=`cat "${KEY_FILES_DIR}/${WAL_NAME}.addr"`
if [[ -z $WALL_ADDR ]];then
    echo
    echo "###-ERROR(line $LINENO): Cannot find wallet address in file  ${KEY_FILES_DIR}/${WAL_NAME}.addr"
    echo
    exit 1
fi
echo "Wallet addr for deploy : $WALL_ADDR"

#==================================================
# Get Wallet work chain for deploy
Work_Chain=`echo "${WALL_ADDR}" | cut -d ':' -f 1`
# if [[ ! "$Work_Chain" == "0" ]] && [[ ! "$Work_Chain" == "-1" ]];then
#     echo "###-ERROR(line $LINENO): Wrong work chain in address. Should be '0' or '-1'"
#     [[ "${ForceDeploy}" != "force" ]] && exit 1
# fi
echo "Wallet work chain for deploy : $Work_Chain"

#=================================================
# Check deployed already
ACCOUNT_INFO="$(Get_Account_Info "${WALL_ADDR}")"
AMOUNT=`echo "$ACCOUNT_INFO" |awk '{print $2}'`
ACTUAL_BALANCE=$(echo "scale=3; $((AMOUNT)) / 1000000000" | $CALL_BC)
ACC_STATUS=`echo "$ACCOUNT_INFO" | awk '{print $1}'`
if [[ "$ACC_STATUS" == "Active" ]];then
    echo
    echo -e "###-ERROR(line $LINENO): ${YellowBack}${BoldText}Wallet deployed already.${NormText} Status: \"$ACC_STATUS\"; Balance: $ACTUAL_BALANCE"
    echo
    [[ "${ForceDeploy}" != "force" ]] && exit 1
fi
echo "Wallet status : \"$ACC_STATUS\""

#=================================================
# Check wallet balance
if [[ $((AMOUNT / 100000000)) -lt 9 ]];then
    echo "###-ERROR(line $LINENO): You haven't enough tokens to deploy wallet. Current balance: $ACTUAL_BALANCE tokens. You need 0.9 at least. Exit."
    exit 1
fi
echo "Wallet balance: $ACTUAL_BALANCE"

#=================================================
# Set wallet code & ABI
Wallet_Code=${SafeSCs_DIR}/SafeMultisigWallet.tvc
Wallet_ABI=${SafeSCs_DIR}/SafeMultisigWallet.abi.json
if [[ "$CodeOfWallet" == "SetCode" ]];then
    Wallet_Code=${SetSCs_DIR}/SetcodeMultisigWallet.tvc
    Wallet_ABI=${SetSCs_DIR}/SetcodeMultisigWallet.abi.json
fi
if [[ ! -f $Wallet_Code ]] || [[ ! -f $Wallet_ABI ]];then
    echo "###-ERROR(line $LINENO): Can not find Wallet code or ABI. Check contracts folder."  
    show_usage
    exit 1
fi
echo "Wallet Code: $Wallet_Code"
echo "ABI for wallet: $Wallet_ABI"
#=================================================
# Read all pubkeys and make a string
Custodians_PubKeys=""
for (( i=1; i<=$Cust_QTY; i++))
do
    PubKey="0x$(cat ${KEY_FILES_DIR}/${WAL_NAME}_${i}.keys.json | jq '.public'| tr -d '\"')"
    SecKey="0x$(cat ${KEY_FILES_DIR}/${WAL_NAME}_${i}.keys.json | jq '.secret'| tr -d '\"')"
    if [[ "$PubKey" == "0x" ]] || [[ "$SecKey" == "0x" ]];then
        echo
        echo "###-ERROR(line $LINENO): Can't find wallet public and/or secret key No: $i !"
        echo
        exit 1
    fi

    Custodians_PubKeys+="\"${PubKey}\","
done

Custodians_PubKeys=${Custodians_PubKeys::-1}
echo "Custodians_PubKeys: '$Custodians_PubKeys'"
echo "Custodians QTY: $Cust_QTY; Required signs: $ReqConfirms"
echo

#===========================================================
# Check Wallet Address
ADDR_from_Keys=$($CALL_TC genaddr $Wallet_Code $Wallet_ABI --setkey ${KEY_FILES_DIR}/${WAL_NAME}_1.keys.json --wc "$Work_Chain" | grep "Raw address:" | awk '{print $3}')
if [[ ! "$WALL_ADDR" == "$ADDR_from_Keys" ]];then
    echo "###-ERROR(line $LINENO): Given Wallet Address and calculated address is different. Possible you prepared it for another contract type or keys. "
    echo "Given addr: $WALL_ADDR"
    echo "Calc  addr: $ADDR_from_Keys"
    echo 
    [[ "${ForceDeploy}" != "force" ]] && exit 1
fi

#=================================================
# read -p "### CHECK INFO TWICE!!! Is this a right deploy info?  (y/n)? " answer
# case ${answer:0:1} in
#     y|Y )
#         echo "Processing....."
#     ;;
#     * )
#         echo "Cancelled."
#         exit 1
#     ;;
# esac

###################################################################################################################################
# Deploy wallet

#=================================================
# make boc file 
function Make_BOC_File(){
    rm -f deploy.boc
    TC_OUTPUT=$($CALL_TC deploy_message \
        $Wallet_Code \
        "{\"owners\":[$Custodians_PubKeys],\"reqConfirms\":${ReqConfirms}}" \
        --abi $Wallet_ABI \
        --sign ${KEY_FILES_DIR}/${WAL_NAME}_1.keys.json \
        --wc $Work_Chain \
        --raw \
        --output deploy.boc \
        | tee ${KEY_FILES_DIR}/${WAL_NAME}_deploy_wallet_msg.log)
    echo "${TC_OUTPUT}"
}

echo -n "---INFO(line $LINENO): Make deploy message BOC file..."

MBF_Output="$(Make_BOC_File)"

if [[ ! -f "deploy.boc" ]];then 
    echo "###-ERROR(line $LINENO): Failed to make deploying message file!!!"
    echo "$MBF_Output"
    exit 1
fi

MBF_addr="$(echo "$MBF_Output"|grep "Contract's address:"|awk '{print $3}')"

if [[ "${MBF_addr}" != "${WALL_ADDR}" ]];then
    echo "###-ERROR(line $LINENO): Address from BOC ($MBF_addr) is not equal calc address ($WALL_ADDR) !"
    [[ "${ForceDeploy}" != "force" ]] && exit 1
else
    echo "DONE"
fi

#=================================================
# Send deploy message to BlockChain
echo -n "---INFO(line $LINENO): Send deploy message to blockchain..."
Attempts_to_send=$SEND_ATTEMPTS
while [[ $Attempts_to_send -gt 0 ]]; do
    result=`Send_File_To_BC "deploy.boc"`
    if [[ "$result" == "failed" ]]; then
        echo "###-ERROR(line $LINENO): Send deploy message FAILED!!!"
    else
        echo "DONE"
        break
    fi
    
    # Account_Status=$(Get_Account_Info ${WALL_ADDR} | awk '{print $1}')
    # if [[ "$Account_Status" != "Active" ]];then
    #     echoerr "+++-WARNING(line $LINENO): The message was not delivered. Sending again..""
    #     Attempts_to_send=$((Attempts_to_send - 1))
    # else
    #     echo "DONE"
    #     break
    # fi
done

echo
echo "Deploy message log saved to ${KEY_FILES_DIR}/${WAL_NAME}_deploy_wallet_msg.log"
echo
echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date  +'%F %T %Z')"
echo "================================================================================================"
echo

exit 0
