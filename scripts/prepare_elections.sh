#!/bin/bash -eE

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
echo "################################ Prepare elections script ######################################"
echo "INFO: $(basename "$0") BEGIN $(date +%s) / $(date  +'%F %T %Z')"

SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/functions.shinc"

[[ ! -d ${ELECTIONS_WORK_DIR} ]] && mkdir -p ${ELECTIONS_WORK_DIR}

#=================================================
echo "INFO from env: Network: $NETWORK_TYPE; Node: $NODE_TYPE; Elector: $ELECTOR_TYPE; Staking mode: $STAKE_MODE"
echo
echo -e "$(Determine_Current_Network)"
echo

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
# get elector address
elector_addr=$(Get_Elector_Address)
echo "INFO: Elector Address: $elector_addr"

#=================================================
# Get elections ID
elections_id=$(Get_Current_Elections_ID)
elections_id=$((elections_id))
echo "INFO:      Election ID: $elections_id"
#===========================================================
# Check staking mode
################################################################################################
############### Recovery stake for msig staking mode ###########################################
################################################################################################
if [[ "$STAKE_MODE" == "msig" ]];then
    echo "+++-WARNING(line $LINENO): Staking mode is set to $STAKE_MODE. Preparation is recover stake only. Depool will not be ticked."
    if [[ $elections_id -eq 0 ]];then
        echo "###-ERROR(line $LINENO):There is no elections now! Nothing to do!"
        exit 1
    fi
    
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
    if [[ "$Work_Chain" != "-1" ]];then
        echo "###-ERROR(line $LINENO): Staking mode: $STAKE_MODE; Validator address has to be in masterchain (-1:xx) !!!"
        exit 1
    fi
    Validator_Acc_Info="$(Get_Account_Info ${Validator_addr})"
    declare -i Validator_Acc_LT=`echo "$Validator_Acc_Info" | awk '{print $3}'`
    Val_Adrr_HEX="$(echo "${Validator_addr}" | cut -d ':' -f 2)"
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
    # check availabylity to recover amount
    case "${NODE_TYPE}" in
        RUST)
            case ${ELECTOR_TYPE} in
                "fift")
                    recover_amount=$($CALL_TC runget 0x${elector_addr} compute_returned_stake "${Val_Adrr_HEX}" 2>&1 | grep "Result:" | awk -F'"' '{print $2}')
                    ;;
                "solidity")
                    recover_amount=$($CALL_TC run 0x${elector_addr} compute_returned_stake "{\"wallet_addr\":\"${Val_Adrr_HEX}\"}" --abi ${Elector_ABI} 2>&1 | grep -i "value0" | awk '{print $2}' | tr -d '"')
                    ;;
                *)
                    echo "###-ERROR(line $LINENO): Unknown Elector type! Set ELECTOR_TYPE= to 'fift' or 'solidity' in env.sh"
                    exit 1
                    ;;
            esac
            ;;
        CPP)
            case "${ELECTOR_TYPE}" in
                fift)
                    recover_amount=`$CALL_LC -rc "runmethod $elector_addr compute_returned_stake 0x$Val_Adrr_HEX" -rc "quit" 2>/dev/null \
                        | grep "result:" | awk '{print $3}' | tee "${ELECTIONS_WORK_DIR}/${elections_id}-recover_amount"`
                    ;;
                solidity)
                    echo "###-ERROR(line $LINENO): Solidity elector for CPP node NOT implemented yet"
                    exit 1
                    ;;
                *)
                    echo "###-ERROR(line $LINENO): Unknown Elector type! Set ELECTOR_TYPE= to 'fift' or 'solidity' in env.sh"
                    exit 1
                    ;;
            esac
            ;;
        *)
            echo "###-ERROR(line $LINENO): Unknown node type! Set NODE_TYPE= to 'RUST' or 'CPP' in env.sh"
            exit 1
            ;; 
    esac
    recover_amount=$((recover_amount))
    echo "INFO: recover_amount = ${recover_amount} nanotokens ( $((recover_amount/1000000000)) Tokens )"
    #=================================================
    if [ $recover_amount -gt 0 ]; then

        #=================================================
        # prepare recovery boc
        echo -n "INFO: Prepare recovery request ..."
        if [[ "${NODE_TYPE}" == "RUST" ]];then
            $CALL_RC -c recover_stake
            mv recover-query.boc "${ELECTIONS_WORK_DIR}/recover-query.boc"
        else
            $CALL_FIFT -s recover-stake.fif "${ELECTIONS_WORK_DIR}/recover-query.boc"
        fi
        recover_query_payload=$(base64 "${ELECTIONS_WORK_DIR}/recover-query.boc" |tr -d '\n')
        if [[ -z $recover_query_payload ]];then
            echo "###-ERROR(line $LINENO): Recover query payload is empty!!"
            exit 1
        fi
        TVM_OUTPUT=$($CALL_TL message $Val_Adrr_HEX -a $SafeC_Wallet_ABI -m submitTransaction \
        -p "{\"dest\":\"$elector_addr\",\"value\":1000000000,\"bounce\":true,\"allBalance\":false,\"payload\":\"$recover_query_payload\"}" -w -1 \
        --setkey ${KEYS_DIR}/msig.keys.bin | tee ${ELECTIONS_WORK_DIR}/TVM_linker-recquery.log)
        if [[ -z $(echo $TVM_OUTPUT | grep "boc file created") ]];then
            echo "###-ERROR(line $LINENO): TVM linker CANNOT create boc file!!! Can't continue."
            exit 1
        fi
        mv "$(echo "$Val_Adrr_HEX"| cut -c 1-8)-msg-body.boc" "${ELECTIONS_WORK_DIR}/recover-msg.boc"
        echo "INFO:  DONE"

        #=================================================
        # Send request for recover stake to Elector
        Required_Signs=`Get_Account_Custodians_Info $Validator_addr | awk '{print $2}'`
        Trans_DST_Addr=$elector_addr
        Tx_Qty_Check=$Exist_El_Trans_Qty
        declare -i New_Trans_Qty=0
        function Send_Recv_Msg(){
            local Attempts_to_send=$SEND_ATTEMPTS
            while [[ $Attempts_to_send -gt 0 ]]; do
                result=`Send_File_To_BC "${ELECTIONS_WORK_DIR}/recover-msg.boc"`
                if [[ "$result" == "failed" ]]; then
                    echoerr "###-ERROR(line $LINENO): Send message for recover FAILED!!!"| tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
                fi
                sleep $LC_Send_MSG_Timeout
                # ===============================================================
                # Verifying that a transaction has been created anyway
                if [[ $Required_Signs -gt 1 ]];then
                    Trans_List="$(Get_MSIG_Trans_List ${Validator_addr})"
                    New_Trans_Qty=$(( $(echo "$Trans_List" | jq -r "[.transactions[]|select(.dest == \"$Trans_DST_Addr\")]|length") ))
                    if [[ $New_Trans_Qty -gt $Tx_Qty_Check ]];then
                        Elect_Trans_ID=$(echo "$Trans_List" | jq -r ".transactions[]|select(.dest == \"$Trans_DST_Addr\")|.id"|tail -n 1)
                        echo "Made transaction ID: $Elect_Trans_ID" >> "${ELECTIONS_WORK_DIR}/${elections_id}.log"
                        break
                    else
                        echoerr "###-ERROR(line $LINENO): Transaction does not made or timeout is too low! TransQTY=$New_Trans_Qty" | tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
                        Attempts_to_send=$((Attempts_to_send - 1))
                    fi
                else
                # ===============================================================
                # Verifying that a transaction has been sent (for 1 custodian acc) by checking change last transaction time
                    Validator_Acc_Info="$(Get_Account_Info ${Validator_addr})"
                    declare -i Validator_Acc_LT_Sent=`echo "$Validator_Acc_Info" | awk '{print $3}'`
                    if [[ $Validator_Acc_LT_Sent -gt $Validator_Acc_LT ]];then
                        echo "INFO: Sending transaction for stake recover was done SUCCESSFULLY!" >> "${ELECTIONS_WORK_DIR}/${elections_id}.log"
                        break
                    else
                        echoerr "###-ERROR(line $LINENO): Sending transaction for stake recover FAILED!!!" | tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
                        Attempts_to_send=$((Attempts_to_send - 1))
                    fi
                fi

            done
            echo $Attempts_to_send
        }
        #=================================================
        ## 5x3 attempts to make trasaction
        for (( TryToSetEl=0; TryToSetEl <= 5; TryToSetEl++ ))
        do
            echo -n "INFO: Send query to Elector... "
            #################
            Attempts_to_send=$(( $(Send_Recv_Msg | tail -n 1) ))
            #################
            echo " DONE"
            if [[ $Attempts_to_send -le 0 ]];then
                echo "###-=ERROR(line $LINENO): ALARM!!! Cannot make transaction for stake recover!!!" | tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
            else
                break
            fi
        done
        #=================================================
        # Final checking
        #=================================================
        # Verifying that a transaction has been created 
        if [[ $Required_Signs -gt 1 ]];then
            Trans_List="$(Get_MSIG_Trans_List ${Validator_addr})"
            New_Trans_Qty=$(( $(echo "$Trans_List" | jq -r "[.transactions[]|select(.dest == \"$Trans_DST_Addr\")]|length") ))
            if [[ $New_Trans_Qty -gt $Tx_Qty_Check ]];then
                Elect_Trans_ID=$(echo "$Trans_List" | jq -r ".transactions[]|select(.dest == \"$Trans_DST_Addr\")|.id"|tail -n 1)
                echo "INFO: Making transaction for elections was done SUCCESSFULLY! Trnasaction ID: $Elect_Trans_ID You have to sign this transaction!!"| tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
                echo "Made transaction ID: $Elect_Trans_ID" >> "${ELECTIONS_WORK_DIR}/${elections_id}.log"
                ${SCRIPT_DIR}/Sign_Trans.sh ${VALIDATOR_NAME} ${Elect_Trans_ID}| tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
            else
                echo "###-ERROR(line $LINENO): Transaction does not made or timeout is too low!" | tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
            fi
        else
        #=================================================
        # Verifying that a transaction has been sent (for 1 custodian acc) by cheching change last transaction time
            Validator_Acc_Info="$(Get_Account_Info ${Validator_addr})"
            declare -i Validator_Acc_LT_Sent=`echo "$Validator_Acc_Info" | awk '{print $3}'`
            if [[ $Validator_Acc_LT_Sent -gt $Validator_Acc_LT ]];then
                echo "INFO: Sending transaction for recover stake was done SUCCESSFULLY!"| tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log" 
            else
                echo "###-ERROR(line $LINENO): Sending transaction for stake recover FAILED!!!" | tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
                "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "$Tg_SOS_sign ###-ERROR(line $LINENO): Sending transaction for eletction FAILED!!!" 2>&1 > /dev/null
            fi
        fi
    else
        echo "INFO: Nothing to recover"
    fi
    echo
    echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date  +'%F %T %Z')"
    echo "================================================================================================"
    exit 0
fi
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
Tik_Info="$(Get_Account_Info $Tik_addr)"
Tik_Status="$(echo $Tik_Info | awk '{print $1}')"
if [[ "$Tik_Status" == "None" ]];then
    echo -e "###-ERROR(line $LINENO): ${BoldText}${RedBack}Account does not exist! (no tokens, no code, nothing)${NormText}"
    echo "=================================================================================================="
    exit 1
fi
if [[ "$ACC_STATUS" == "Uninit" ]];then
    echo "###-ERROR(line $LINENO): Tik status: ${BoldText}${YellowBack}Uninit${NormText}"
    echo "=================================================================================================="
    exit 1
fi
Tik_Bal=$(echo $Tik_Info | awk '{print $2}')
Tik_Bal=$((Tik_Bal))
echo "Tik account balance: $(echo "scale=3; $Tik_Bal / 1000000000" | $CALL_BC)"
if [[ $Tik_Bal -lt 2000000000 ]];then
    echo "+++-WARNING(line $LINENO): Tik account has balance less 2 tokens!! I will topup it with 10 tokens from ${VALIDATOR_NAME} account" | tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
    "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server: DePool Tik:" \
        "WARNING!!! Tik account has balance less 2 tokens!! I will topup it with 10 tokens from ${VALIDATOR_NAME} account" 2>&1 > /dev/null
    
    TopUp_Result="$(${SCRIPT_DIR}/transfer_amount.sh ${VALIDATOR_NAME} Tik 10 | tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log")"
    Validator_addr="$(cat ${KEYS_DIR}/${VALIDATOR_NAME}.addr)"
    Custodians="$(Get_Account_Custodians_Info "$Validator_addr")"
    Val_Confirm_QTY=$(echo $Custodians|awk '{print $2}')
    if [[ $Val_Confirm_QTY -gt 1 ]];then
        Trans_ID=$(echo "$TopUp_Result"| grep 'successfully created transaction'|awk '{print $6}')
        ${SCRIPT_DIR}/Sign_Trans.sh ${VALIDATOR_NAME} $Trans_ID | tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
    fi
fi

Work_Chain=`echo "${Tik_addr}" | cut -d ':' -f 1`

#=================================================
# Check DePool has enough balance to operate, and replenish if no
# ------------------------------------------------
# check depool contract status
# Depool_Info="$(Get_Account_Info $Depool_addr)"
# Depool_Acc_State=`echo "$Depool_Info" |awk '{print $1}'`
# if [[ "$Depool_Acc_State" == "None" ]];then
#     echo -e "${BoldText}${RedBack}###-ERROR(line $LINENO): Depool Account does not exist! (no tokens, no code, nothing)${NormText}"
#     echo
#     exit 1
# elif [[ "$Depool_Acc_State" == "Uninit" ]];then
#     echo -e "${BoldText}${RedBack}###-ERROR(line $LINENO): Depool Account does not deployed.${NormText}"
#     echo "Has balance : $(echo "$Depool_Info" |awk '{print $2}')"
#     echo
#     exit 1
# fi

# # get info from DePool contract state
# Depool_Bal=$(( $(echo "$Depool_Info" |awk '{print $2}') ))
# Current_Depool_Info="$(Get_DP_Info $Depool_addr)"
# DP_balanceThreshold=$(( $(echo "$Current_Depool_Info"|jq -r '.balanceThreshold') / 1000000000))

# if [[ $Depool_Bal -lt $DP_balanceThreshold ]];then
#     echo "+++-WARNING(line $LINENO): DePool has balance less $DP_balanceThreshold tokens!! I will topup it with 10 tokens from ${VALIDATOR_NAME} account" | tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
#     "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server: DePool Tik:" \
#         "WARNING(line $LINENO): DePool has balance less $DP_balanceThreshold tokens!! I will topup it with 10 tokens from ${VALIDATOR_NAME} account" 2>&1 > /dev/null

# fi

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
################  Send TIK query to DePool ###################################
##############################################################################
Last_Trans_lt=$(Get_Account_Info ${Depool_addr} | awk '{print $3}')

function Send_Tik(){
    local Attempts_to_send=$SEND_ATTEMPTS
    while [[ $Attempts_to_send -gt 0 ]]; do
        local result=`Send_File_To_BC "${ELECTIONS_WORK_DIR}/tik-msg.boc"`
        if [[ "$result" == "failed" ]]; then
            echoerr "###-ERROR(line $LINENO): Send message for Tik FAILED!!!"| tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
        fi

        local Curr_Trans_lt=$(Get_Account_Info ${Depool_addr} | awk '{print $3}')
        if [[ $Curr_Trans_lt == $Last_Trans_lt ]];then
            echoerr "+++-WARNING(line $LINENO): DePool does not crank up .. Repeat sending.."| tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
            Attempts_to_send=$((Attempts_to_send - 1))
        else
            break
        fi
    done
    echo $Attempts_to_send
}

for (( TryToSetEl=0; TryToSetEl <= 5; TryToSetEl++ ))
do
    echo -n "INFO: Make boc for lite-client ..."
    Make_BOC_file
    echo " DONE"
    echo -n "INFO: Send Tik query to DePool ..."
    #################
    Attempts_to_send=$(( $(Send_Tik | tail -n 1) ))
    #################
    echo " DONE"
    [[ $Attempts_to_send -le 0 ]] && echo "###-=ERROR(line $LINENO): ALARM!!! DePool DOES NOT CRANKED UP!!!" | tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"

    Depool_Rounds_Info="$(Get_DP_Rounds $Depool_addr)"
    Curr_Rounds_Info="$(Rounds_Sorting_by_ID "$Depool_Rounds_Info")"
    Curr_DP_Elec_ID=$(( $(echo "$Curr_Rounds_Info" |jq -r '.[1].supposedElectedAt'| xargs printf "%d\n") ))

    if [[ $elections_id -gt 0 ]];then
        echo "INFO: Checking DeePool is set to current elections..."| tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
        echo "Elections ID in DePool: $Curr_DP_Elec_ID"| tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
        [[ $elections_id -eq $Curr_DP_Elec_ID ]] && break
        echo "+++-WARNING: Not set yet. Try #${TryToSetEl}..."| tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
        sleep $SLEEP_TIMEOUT
    else
        break
    fi 
done

if [[ $elections_id -ne $Curr_DP_Elec_ID ]] && [[ $elections_id -gt 0 ]]; then
    echo "###-ERROR(line $LINENO): Current elections ID from elector $elections_id ($(TD_unix2human "$elections_id")) is not equal elections ID from DP: $Curr_DP_Elec_ID ($(TD_unix2human "$Curr_DP_Elec_ID"))" \
        | tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
    echo "INFO: $(basename "$0") END $(date +%s) / $(date)"
    date +"INFO: %F %T %Z Tik DePool FALED!" | tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
    "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server: DePool Tik:" \
        "$Tg_SOS_sign ALARM!!! Current elections ID from elector $elections_id ($(TD_unix2human $elections_id)) is not equal elections ID from DePool: $Curr_DP_Elec_ID ($(TD_unix2human $Curr_DP_Elec_ID))" 2>&1 > /dev/null
else
    echo "INFO:      Election ID: $elections_id" | tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
    echo "Elections ID in DePool: $Curr_DP_Elec_ID" | tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
    date +"INFO: %F %T %Z DePool is set for current elections." | tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
fi

echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date  +'%F %T %Z')"
echo "================================================================================================"

exit 0
