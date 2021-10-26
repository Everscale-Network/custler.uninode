#!/bin/bash

# (C) Sergey Tyurin  2021-08-19 16:00:00

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

###################
TIMEDIFF_MAX=100
SLEEP_TIMEOUT=20
SEND_ATTEMPTS=3
###################

Tik_Payload="te6ccgEBAQEABgAACCiAmCM="
NANOSTAKE=$((1 * 1000000000))

echo
echo "################################ POH tik script ######################################"
echo "INFO: $(basename "$0") BEGIN $(date +%s) / $(date  +'%F %T %Z')"

SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/functions.shinc"

[[ ! -d ${ELECTIONS_WORK_DIR} ]] && mkdir -p ${ELECTIONS_WORK_DIR}

#=================================================
echo -e "$(DispEnvInfo)"
echo
#########################################################
GET_F_T(){
    OS_SYSTEM=`uname`
    ival="${1}"
    if [[ "$OS_SYSTEM" == "Linux" ]];then
        echo "$(date  +'%Y-%m-%d %H:%M:%S' -d @$ival)"
    else
        echo "$(date -r $ival +'%Y-%m-%d %H:%M:%S')"
    fi
}

##############################################################################
# Check node sync
TIME_DIFF=$(Get_TimeDiff)
if [[ $TIME_DIFF -gt $TIMEDIFF_MAX ]];then
    echo "###-ERROR(line $LINENO): Your node is not synced. Wait until full sync (<$TIMEDIFF_MAX) Current timediff: $TIME_DIFF"
    "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "$Tg_SOS_sign ###-ERROR(line $LINENO): Your node is not synced. Wait until full sync (<$TIMEDIFF_MAX) Current timediff: $TIME_DIFF" 2>&1 > /dev/null
    exit 1
fi
echo "INFO: Current TimeDiff: $TIME_DIFF"

#=================================================
# Get elections ID
# Elections_timings=$($CALL_TC getconfig 15 2>&1 |sed -e '1,4d'|sed "s/Config p15: //")
Elections_timings=$($CALL_RC -c "getconfig 15"|sed -e '1,/GIT_BRANCH:/d'|sed 's/config param: //'|jq '.p15')
declare -i VAL_DUR=`echo "${Elections_timings}"     | jq -r '.validators_elected_for'`	# validators_elected_for
declare -i STRT_BEFORE=`echo "${Elections_timings}" | jq -r '.elections_start_before'`	# elections_start_before
declare -i EEND_BEFORE=`echo "${Elections_timings}" | jq -r '.elections_end_before'`	# elections_end_before

el_ID_readed=false
Curr_Time=$(date +%s)
elector_addr="-1:3333333333333333333333333333333333333333333333333333333333333333"
# elections_id=$($CALL_TC -j run ${elector_addr} active_election_id {} --abi ${Elector_ABI} | jq -r ".value0")

elections_id=$(Get_Current_Elections_ID)
elections_id=$((elections_id))
prev_election_id=$((elections_id - VAL_DUR))
next_election_id=$((elections_id + VAL_DUR))

echo "INFO:      Election ID: $elections_id / $(GET_F_T ${elections_id})"
if [[ $Curr_Time -lt $((elections_id - STRT_BEFORE)) ]];then
    echo "Elections will start GET_F_T ${elections_id}. Please wait"
    exit 0
fi
echo "prev_election_id: $prev_election_id / $(GET_F_T ${prev_election_id})" | tee -a "${ELECTIONS_WORK_DIR}/${elections_id}_Emerg.log"
echo "elections_id:     $elections_id / $(GET_F_T ${elections_id})" | tee -a "${ELECTIONS_WORK_DIR}/${elections_id}_Emerg.log"
echo "next_election_id: $next_election_id / $(GET_F_T ${next_election_id})" | tee -a "${ELECTIONS_WORK_DIR}/${elections_id}_Emerg.log"

################################################################################################
########## Continue to Tik depool ########
################################################################################################
# Continue to Tik depool
if [[ $elections_id -eq 0 ]];then
    echo "+++-WARN(line $LINENO):There is no elections now! We will just spend tokens"
else
    echo "${elections_id}" >> "${ELECTIONS_WORK_DIR}/${elections_id}.log"
fi
#=================================================
# Addresses and vars
Depool_Name=$1
if [[ -z $Depool_Name ]];then
    Depool_Name="depool"
    Depool_addr=`cat "${KEYS_DIR}/${Depool_Name}.addr"`
    if [[ -z $Depool_addr ]];then
        echo "###-ERROR(line $LINENO): Can't find DePool address file! ${KEYS_DIR}/${Depool_Name}.addr"
        exit 1
    fi
else
    Depool_addr=$Depool_Name
    acc_fmt="$(echo "$Depool_addr" |  awk -F ':' '{print $2}')"
    [[ -z $acc_fmt ]] && Depool_addr=`cat "${KEYS_DIR}/${Depool_Name}.addr"`
fi
if [[ -z $Depool_addr ]];then
    echo "###-ERROR(line $LINENO): Can't find DePool address file! ${KEYS_DIR}/${Depool_Name}.addr"
    exit 1
fi

dpc_addr=`echo $Depool_addr | cut -d ':' -f 2`
dpc_wc=`echo $Depool_addr | cut -d ':' -f 1`
if [[ ${#dpc_addr} -ne 64 ]] || [[ ${dpc_wc} -ne 0 ]];then
    echo "###-ERROR(line $LINENO): Wrong DePool address! ${Depool_addr}"
    exit 1
fi

#=================================================
# Check that the Tik account is ready and there are enough tokens on it
Tik_addr=`cat ${KEYS_DIR}/Tik.addr`
Tik_Keys_File="${KEYS_DIR}/Tik.keys.json"
if [[ -z $Tik_addr ]];then
    echo
    echo "###-ERROR(line $LINENO): Cannot find Tik acc address in file  ${KEYS_DIR}/Tik.addr"
    echo
    exit 1
fi
echo "Tik address:    ${Tik_addr}"
tik_public=`cat $Tik_Keys_File | jq -r ".public"`
tik_secret=`cat $Tik_Keys_File | jq -r ".secret"`
if [[ -z $tik_public ]] || [[ -z $tik_secret ]];then
    echo "###-ERROR(line $LINENO): Can not find Tik public and/or secret key!"
    exit 1
fi

Work_Chain=`echo "${Tik_addr}" | cut -d ':' -f 1`

#=================================================
# prepare user signature
tik_acc_addr=`echo "${Tik_addr}" | cut -d ':' -f 2`
touch $tik_acc_addr
echo "${tik_secret}${tik_public}" > ${KEYS_DIR}/tik.keys.txt
rm -f ${KEYS_DIR}/tik.keys.bin
xxd -r -p ${KEYS_DIR}/tik.keys.txt ${KEYS_DIR}/tik.keys.bin

#=================================================
# make boc file 
function Make_BOC_file(){
    TVM_OUTPUT=$($CALL_TL message $tik_acc_addr -a $SafeC_Wallet_ABI -m submitTransaction \
        -p "{\"dest\":\"$Depool_addr\",\"value\":$NANOSTAKE,\"bounce\":true,\"allBalance\":false,\"payload\":\"$Tik_Payload\"}" \
        -w $Work_Chain --setkey ${KEYS_DIR}/tik.keys.bin \
        | tee ${ELECTIONS_WORK_DIR}/TVM_linker-tikquery.log)

    if [[ -z $(echo $TVM_OUTPUT | grep "boc file created") ]];then
        echoerr "###-ERROR(line $LINENO): TVM linker CANNOT create boc file!!! Can't continue."
        exit 2
    fi

    mv -f "$(echo "$tik_acc_addr"| cut -c 1-8)-msg-body.boc" "${ELECTIONS_WORK_DIR}/tik-msg.boc"
}

##############################################################################
################  Send TIK query to DePool  5 TIMES ##########################
##############################################################################
echo "---INFO: Send tik 5 times"
for (( i=0; i <= 5; i++ ))
do
    Make_BOC_file
    result=`Send_File_To_BC "${ELECTIONS_WORK_DIR}/tik-msg.boc"`
    if [[ "$result" == "failed" ]]; then
        echoerr "###-ERROR(line $LINENO): Send message for Tik FAILED!!!"| tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
    fi
    echo "--- Tik # $i sent .."
done

##############################################################################
################  SEND STAKE TO ELECTOR ######################################
##############################################################################

#### WAIT after Tik 2 mins
echo "---INFO: WAIT after Tik 2 mins ..."
sleep 120

#=================================================
# Load addresses and set variables
Validator_addr=`cat ${KEYS_DIR}/${VALIDATOR_NAME}.addr`
Work_Chain=`echo "${Validator_addr}" | cut -d ':' -f 1`
if [[ -z $Validator_addr ]];then
    echo "###-ERROR(line $LINENO): Can't find validator address! ${KEYS_DIR}/${VALIDATOR_NAME}.addr"
    exit 1
fi
if [[ ! -f ${SafeC_Wallet_ABI} ]];then
    echo "###-ERROR(line $LINENO): ${SafeC_Wallet_ABI} NOT FOUND! Can't continue"
    exit 1
fi
if [[ "$STAKE_MODE" == "depool" ]];then
    Depool_addr=`cat ${KEYS_DIR}/depool.addr`
    dpc_addr=`echo $Depool_addr | cut -d ':' -f 2`
    if [[ -z $Depool_addr ]];then
       echo "###-ERROR(line $LINENO): Can't find depool address! ${KEYS_DIR}/depool.addr"
       exit 1
    fi
else
    if [[ "$Work_Chain" != "-1" ]];then
        echo "###-ERROR(line $LINENO): Staking mode: $STAKE_MODE; Validator address has to be in masterchain (-1:xx) !!!"
        exit 1
    fi
fi

Val_Adrr_HEX=`echo "${Validator_addr}" | cut -d ':' -f 2`
echo "INFO: validator account address: $Validator_addr"
[[ "$STAKE_MODE" == "depool" ]] && echo "INFO: depool   contract address: $Depool_addr"
[[ ! -d ${ELECTIONS_WORK_DIR} ]] && mkdir -p ${ELECTIONS_WORK_DIR}
chmod +x ${ELECTIONS_WORK_DIR}
Validator_Acc_Info="$(Get_Account_Info ${Validator_addr})"
declare -i Validator_Acc_LT=`echo "$Validator_Acc_Info" | awk '{print $3}'`

#=================================================
# Set proxy for current election
dp_proxy0="$(cat ${KEYS_DIR}/proxy0.addr)"
dp_proxy1="$(cat ${KEYS_DIR}/proxy1.addr)"
Console_proxy="$(cat /var/ton-work/rnode/configs/console.json | jq -r '.wallet_id')"
curr_dp_proxy_id=$(cat ${ELECTIONS_WORK_DIR}/${elections_id}_proxy.id)

DP_Round_Proxy="$(cat ${KEYS_DIR}/proxy${curr_dp_proxy_id}.addr)"
echo "DP_Round_Proxy id: ${curr_dp_proxy_id}   Addr: $DP_Round_Proxy" | tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"

if [[ "${curr_dp_proxy_id}" == "0" ]];then
    echo "1" > ${ELECTIONS_WORK_DIR}/${next_election_id}_proxy.id
else
    echo "0" > ${ELECTIONS_WORK_DIR}/${next_election_id}_proxy.id
fi

#=================================================
# prepare user signature for boc
touch $Val_Adrr_HEX
msig_public=`cat ${KEYS_DIR}/${VALIDATOR_NAME}.keys.json | jq -r ".public"`
msig_secret=`cat ${KEYS_DIR}/${VALIDATOR_NAME}.keys.json | jq -r ".secret"`
if [[ -z $msig_public ]] || [[ -z $msig_secret ]];then
    echo "###-ERROR(line $LINENO): Can't find validator public and/or secret key!"
    exit 1
fi
echo "${msig_secret}${msig_public}" > ${KEYS_DIR}/msig.keys.txt
rm -f ${KEYS_DIR}/msig.keys.bin
xxd -r -p ${KEYS_DIR}/msig.keys.txt ${KEYS_DIR}/msig.keys.bin

#=================================================
#   validators_elected_for elections_start_before elections_end_before stake_held_for
CONFIG_PAR_15=$Elections_timings
declare -i validators_elected_for=`echo "$CONFIG_PAR_15" |grep 'validators_elected_for' | awk '{print $2}' | tr -d ','`
declare -i elections_start_before=`echo "$CONFIG_PAR_15" |grep 'elections_start_before' | awk '{print $2}' | tr -d ','`
declare -i elections_end_before=`echo "$CONFIG_PAR_15"   |grep 'elections_end_before'   | awk '{print $2}' | tr -d ','`
declare -i stake_held_for=`echo "$CONFIG_PAR_15"         |grep 'stake_held_for'         | awk '{print $2}' | tr -d ','`
if [[ -z $validators_elected_for ]] || [[ -z $elections_start_before ]] || [[ -z $elections_end_before ]] || [[ -z $stake_held_for ]];then
    echo "###-ERROR(line $LINENO): Get network election params (p15) FAILED!!!"
    exit 1
fi

Validating_Start=${elections_id}
Validating_Stop=$(( ${Validating_Start} + 1000 + ${validators_elected_for} + ${elections_start_before} + ${elections_end_before} + ${stake_held_for} ))
echo "Validating_Start: $Validating_Start | Validating_Stop: $Validating_Stop"

#=================================================
# Checking that query.boc already made for sending to Elector
if [[ -f ${ELECTIONS_WORK_DIR}/${elections_id}_query.boc ]];then
    echo "+++WARNING(line $LINENO): ${elections_id}_query.boc for current elections generated already. We will use the existing one."
else
    cat "${R_CFG_DIR}/console.json" | jq ".wallet_id = \"${DP_Round_Proxy}\"" > console.tmp
    mv -f console.tmp  ${R_CFG_DIR}/console.json
    $CALL_RC -c "election-bid $Validating_Start $Validating_Stop" &> "${ELECTIONS_WORK_DIR}/${elections_id}-bid.log"
    mv -f validator-query.boc "${ELECTIONS_WORK_DIR}/${elections_id}_query.boc"
fi

validator_query_payload=$(base64 "${ELECTIONS_WORK_DIR}/${elections_id}_query.boc" |tr -d "\n")
# ===============================================================
# parameters checks
if [[ -z $validator_query_payload ]];then
    echo "###-ERROR(line $LINENO): Payload is empty! It is unasseptable!"
    echo "did you have right ${elections_id}_query.boc ?"
    exit 2
fi

NANOSTAKE=$((1 * 1000000000))
Stake_DST_Addr=$Depool_addr

#####################################################################################################
###############  Send request to participate in elections ###########################################
#####################################################################################################

# ===============================================================
# make boc for sending
function Make_transaction_BOC() {
    TVM_OUTPUT=$($CALL_TL message $Val_Adrr_HEX \
        -a ${SafeC_Wallet_ABI} \
        -m submitTransaction \
        -p "{\"dest\":\"$Stake_DST_Addr\",\"value\":$NANOSTAKE,\"bounce\":true,\"allBalance\":false,\"payload\":\"$validator_query_payload\"}" \
        -w $Work_Chain --setkey ${KEYS_DIR}/msig.keys.bin)

    if [[ -z $(echo $TVM_OUTPUT | grep "boc file created") ]];then
        echo "###-ERROR(line $LINENO): TVM linker CANNOT create boc file!!! Can't continue."
        exit 3
    fi
    mv -f "$(echo "$Val_Adrr_HEX"| cut -c 1-8)-msg-body.boc" "${ELECTIONS_WORK_DIR}/${elections_id}_vaidator-query-msg.boc"
}

for (( i=1; i<6; i++));do
    echo -n "INFO: Make transaction boc ..."
    #################
    Make_transaction_BOC
    #################
    echo " DONE"
    echo -n "INFO: Send query to Elector... "
    result=`Send_File_To_BC "${ELECTIONS_WORK_DIR}/${elections_id}_vaidator-query-msg.boc"`
    if [[ "$result" == "success" ]];then
        echo " DONE"
        echo "INFO: Sending transaction for elections was done SUCCESSFULLY!" >> "${ELECTIONS_WORK_DIR}/${elections_id}.log"
        break
    fi
    echo "###-ERROR(line $LINENO): Try ${i} to send message for elections FAILED!!!"| tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
done

echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date  +'%F %T %Z')"
echo "================================================================================================"

exit 0
