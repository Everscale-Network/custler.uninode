#!/usr/bin/env bash
set -eE

# (C) Sergey Tyurin  2022-04-22 10:00:00

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
echo "#################################### DePool deploy script ########################################"
echo "INFO: $(basename "$0") BEGIN $(date +%s) / $(date  +'%F %T %Z')"
echo 

SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/functions.shinc"

echo -e "$(DispEnvInfo)"
echo
echo -e "$(Determine_Current_Network)"
echo

SEND_ATTEMPTS=3

#===========================================================
# DePool V1 2020_12_08
# Code from commit 94bff38f9826a19a8ae55d5b48528912f21b3919
DP_2020_12_08_MD5='8cca5ef28325e90c46ad9b0e35951d21'
#-----------------------------------------------------------
# DePool V2  2020_12_08
# Code from commit a49c96de2c22c0047a9c9d04e0d354d3b22d5937 
DP_2020_12_11_MD5='206929ca364fd8fa225937ada19f30a0'
DP_Proxy_2020_12_11_MD5="3b8e08ffc4cff249e1d33ece9587fcc3"
#-----------------------------------------------------------
# DePool V3 in main 2021_02_01
DP_2021_02_01_MD5="d2bcd6b68525d3068c7cfecfe1510458"
DP_Proxy_2021_02_01_MD5="0ef3a063ea9573fc7f068cb89a075868"
#-----------------------------------------------------------
DP_RUSTCUP_2021_06_29_MD5="d466351fcf1e051c563b2054625db8f5"
DP_PROXY_RUSTCUP_2021_06_29_MD5="e614e99a3193173543670eded2094850"
#-----------------------------------------------------------
DP_RUSTCUP_2021_08_05_MD5="5f0134a55f033da266db5b16fec607fd"
DP_PROXY_RUSTCUP_2021_08_05_MD5="73279e4e669a7ba80c3c9c6956d7f57e"
#-----------------------------------------------------------
DP_RFLD_2021_10_02_MD5="48b7b03fbac93749d2ae24a23f17b9e7"
DP_PROXY_RFLD_2021_10_02_MD5="0ef3a063ea9573fc7f068cb89a075868"
#-----------------------------------------------------------

CurrDP_MD5=$DP_2021_02_01_MD5
CurrProxy_MD5=$DP_Proxy_2021_02_01_MD5

NetName="${NETWORK_TYPE%%.*}"
case "$NetName" in
    main)
        CurrDP_MD5=$DP_2021_02_01_MD5
        CurrProxy_MD5=$DP_Proxy_2021_02_01_MD5
        ;;
    net)
        CurrDP_MD5=$DP_2021_02_01_MD5
        CurrProxy_MD5=$DP_Proxy_2021_02_01_MD5
        ;;
    fld)
        CurrDP_MD5=$DP_2021_02_01_MD5
        CurrProxy_MD5=$DP_Proxy_2021_02_01_MD5
        ;;
    rustnet)
        CurrDP_MD5=$DP_RUSTCUP_2021_08_05_MD5
        CurrProxy_MD5=$DP_PROXY_RUSTCUP_2021_08_05_MD5
        ;;
    rfld)
        CurrDP_MD5=$DP_RFLD_2021_10_02_MD5
        CurrProxy_MD5=$DP_PROXY_RFLD_2021_10_02_MD5
        ;;
    *)
        echo "###-WARNING(line $LINENO in echo ${0##*/}): Unknown NETWORK_TYPE (${NETWORK_TYPE}) DePool's code set to default!"
        ;;
esac

echo "DP_MD5       = $CurrDP_MD5"
echo "DP_Proxy_MD5 = $CurrProxy_MD5"
echo

#===========================================================
# 
OS_SYSTEM=`uname`
if [[ "$OS_SYSTEM" == "Linux" ]];then
        GetMD5="md5sum --tag"
else
        GetMD5="md5"
fi

#========= Depool Deploy Parametrs ================================
echo 
echo "================= Deploy DePool contract =========================="

MinStake=`$CALL_TC -j convert tokens ${MinStakeT}|jq -r '.value'`
ValidatorAssurance=`$CALL_TC -j convert tokens ${ValidatorAssuranceT}|jq -r '.value'`

ProxyCode="$($CALL_TC -j decode stateinit --tvc ${DSCs_DIR}/DePoolProxy.tvc | jq -r '.code')"
[[ -z $ProxyCode ]] && echo "###-ERROR(line $LINENO): DePoolProxy.tvc not found in ${DSCs_DIR}/DePoolProxy.tvc" && exit 1
ProxyCode_hash="$($CALL_TC -j decode stateinit --tvc ${DSCs_DIR}/DePoolProxy.tvc | jq -r '.code_hash')"

DepoolCode="$($CALL_TC -j decode stateinit --tvc ${DSCs_DIR}/DePool.tvc | jq -r '.code')"
[[ -z $DepoolCode ]] && echo "###-ERROR(line $LINENO): DePool.tvc not found in ${DSCs_DIR}/DePool.tvc" && exit 1
DepoolCode_hash="$($CALL_TC -j decode stateinit --tvc ${DSCs_DIR}/DePool.tvc | jq -r '.code_hash')"
VrfDepoolCode=${DepoolCode:0:64}

DePoolMD5=$($GetMD5 ${DSCs_DIR}/DePool.tvc |awk '{print $4}')
if [[ ! "${DePoolMD5}" == "${CurrDP_MD5}" ]];then
    echo "###-ERROR(line $LINENO): DePool.tvc is not right version!! Can't continue"
    exit 1
fi

ProxyMD5=$($GetMD5 ${DSCs_DIR}/DePoolProxy.tvc |awk '{print $4}')
if [[ ! "${ProxyMD5}" == "${CurrProxy_MD5}" ]];then
    echo "###-ERROR(line $LINENO): DePoolProxy.tvc is not right version!! Can't continue"
    exit 1
fi

Validator_addr=`cat ${KEYS_DIR}/${HOSTNAME}.addr`
[[ -z $Validator_addr ]] && echo "###-ERROR(line $LINENO): Validator address not found in ${KEYS_DIR}/${HOSTNAME}.addr" && exit 1

# Validator_WC=$($CALL_RC -j -c getstats|grep 'processed workchain'|awk '{print $3}'|tr -d ',')
# [[ "${Validator_WC}" == "masterchain" ]] && Validator_WC=$((-1))
Validator_WC=$NODE_WC

# BalanceThreshold=`$CALL_TC -j convert tokens ${BalanceThresholdT}`
# echo "BalanceThreshold $BalanceThresholdT in nanoTon:  $BalanceThreshold"

#=================================================
# Addresses and vars
Depool_Name=$1
Depool_Name=${Depool_Name:="depool"}
Depool_addr=`cat ${KEYS_DIR}/${Depool_Name}.addr`
if [[ -z $Depool_addr ]];then
    echo
    echo "###-ERROR(line $LINENO): Cannot find depool address in file  ${KEYS_DIR}/${Depool_Name}.addr"
    echo
    exit 1
fi
Depool_WC=${Depool_addr%%:*}
Depoo_Keys=${KEYS_DIR}/${Depool_Name}.keys.json
Depool_Public_Key=`cat $Depoo_Keys | jq -r ".public"`
[[ -z $Depool_Public_Key ]] && echo "###-ERROR(line $LINENO): Depool_Public_Key not found in ${KEYS_DIR}/${Depool_Name}.keys.json" && exit 1

# [[ ${Validator_WC} -ne ${Depool_WC} ]] && echo "###-ERROR(line $LINENO): Depool_WC=${Depool_WC} not equal Validator_WC=${Validator_WC}" && exit 1
if [[ ${Validator_WC} -ne ${Depool_WC} ]] && [[ ${Validator_WC} -ne -1 ]] && [[ ${Depool_WC} -ne 0 ]];then
    echo -e "${BoldText}${YellowBack}###-WARNING(line $LINENO): Depool_WC=${Depool_WC} not equal Validator_WC=${Validator_WC}!! ${NormText}" 
    # exit 1
fi

#===========================================================
# Check DePool Address
DP_ADDR_from_Keys=$($CALL_TC genaddr ${DSCs_DIR}/DePool.tvc --abi ${DSCs_DIR}/DePool.abi.json --setkey $Depoo_Keys --wc "$Depool_WC" | grep "Raw address:" | awk '{print $3}')
if [[ ! "$Depool_addr" == "$DP_ADDR_from_Keys" ]];then
    echo "###-ERROR(line $LINENO): Given DePool Address and calculated address is different. Possible you prepared it for another contract. "
    echo "Given addr: $Depool_addr"
    echo "Calc  addr: $DP_ADDR_from_Keys"
    echo 
    exit 1
fi

#===========================================================
# print INFO
echo "Validator_addr:    $Validator_addr"
echo "Depool Address:    $Depool_addr"
echo "     Depool WC:    $Depool_WC"
echo "Depool_Public_Key: $Depool_Public_Key"
echo
echo "Minimal Stake:                $MinStakeT"
echo "ParticipantRewardFraction:    $ParticipantRewardFraction"
echo "ValidatorAssurance:           $ValidatorAssuranceT"
echo
echo "DePool MD5 sum:                 $DePoolMD5"
echo "DePool Proxy MD5 sum:           $ProxyMD5"
echo "First 64 syms from DePoolCode:  ${VrfDepoolCode}"
echo "First 64 syms from ProxyCode:   ${ProxyCode:0:64}"

#===========================================================
# check depool balance

Depool_INFO="$(Get_Account_Info ${Depool_addr})"
Depool_Status=`echo "$Depool_INFO" | awk '{print $1}'`
Depool_AMOUNT=`echo "$Depool_INFO" | awk '{print $2}'`

if [[ $Depool_AMOUNT -lt $((BalanceThreshold * 2  + 5000000000)) ]];then
    echo "###-ERROR(line $LINENO): You have not anought balance on depool address!"
    echo "It should have at least $((BalanceThresholdT * 2  + 5)), but now it has $((Depool_AMOUNT))"
    exit 1
fi

if [[ "$Depool_Status" != "Uninit" ]];then
    echo "###-ERROR(line $LINENO): Depool_Status not 'Uninit'. Already deployed?"
    exit 1
fi
echo "Depool balance: $((Depool_AMOUNT/1000000000)) ; status: $Depool_Status"
echo

#===========================================================
read -p "### CHECK INFO TWICE!!! Is this a right Parameters? Think once more!  (yes/n)? " </dev/tty answer
case ${answer:0:3} in
    yes|YES )
        echo
        echo "Processing....."
    ;;
    * )
        echo
        echo "If you absolutely sure, type 'yes' "
        echo "Cancelled."
        exit 1
    ;;
esac
#===========================================================


echo "{\"minStake\":$MinStake,\"validatorAssurance\":$ValidatorAssurance,\"proxyCode\":\"$ProxyCode\",\"validatorWallet\":\"$Validator_addr\",\"participantRewardFraction\":$ParticipantRewardFraction}"


###################################################################################################################################
# Deploy wallet

#=================================================
# make boc file 
function Make_BOC_File(){
    rm -f deploy.boc
    TC_OUTPUT=$($CALL_TC deploy_message \
        ${DSCs_DIR}/DePool.tvc \
        "{\"minStake\":$MinStake,\"validatorAssurance\":$ValidatorAssurance,\"proxyCode\":\"$ProxyCode\",\"validatorWallet\":\"$Validator_addr\",\"participantRewardFraction\":$ParticipantRewardFraction}" \
        --abi ${DSCs_DIR}/DePool.abi.json \
        --sign ${KEYS_DIR}/${Depool_Name}.keys.json \
        --wc ${Depool_WC} \
        --raw \
        --output deploy.boc \
        | tee ${KEYS_DIR}/${Depool_Name}_deploy_depool_msg.log)
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

if [[ "${MBF_addr}" != "${Depool_addr}" ]];then
    echo "###-ERROR(line $LINENO): Address from BOC ($MBF_addr) is not equal calc address (${Depool_addr}) !"
    exit 1
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
    sleep 5
    Account_Status=$(Get_Account_Info ${Depool_addr} | awk '{print $1}')
    if [[ "$Account_Status" != "Active" ]];then
        echoerr "+++-WARNING(line $LINENO): The message was not delivered. Sending again.."
        Attempts_to_send=$((Attempts_to_send - 1))
    else
        echo "DONE"
        break
    fi
done

echo
echo "Deploy message log saved to ${KEYS_DIR}/${Depool_Name}_deploy_depool_msg.log"
echo
echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date  +'%F %T %Z')"
echo "================================================================================================"
echo

exit 0
