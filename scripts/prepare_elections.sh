#!/usr/bin/env bash

# (C) Sergey Tyurin  2022-01-08 19:00:00

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
echo -e "$(DispEnvInfo)"
echo
echo -e "$(Determine_Current_Network)"
echo

##############################################################################
# Check node sync
# masterchain timediff
MC_TIME_DIFF=$(Get_TimeDiff|awk '{print $1}')
if [[ $MC_TIME_DIFF -gt $TIMEDIFF_MAX ]];then
    echo "###-ERROR(line $LINENO): Your node is not synced with MC. Wait until MC sync (<$TIMEDIFF_MAX) Current MC timediff: $MC_TIME_DIFF"
    "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "$Tg_SOS_sign ###-ERROR(line $LINENO): Your node is not synced. Wait until MC sync (<$TIMEDIFF_MAX) Current MC timediff: $MC_TIME_DIFF" 2>&1 > /dev/null
    exit 1
fi
echo "INFO: Current MC TimeDiff: $MC_TIME_DIFF"

# shards timediff (by worst shard)
SH_TIME_DIFF=$(Get_TimeDiff|awk '{print $2}')
if [[ $SH_TIME_DIFF -gt $TIMEDIFF_MAX ]];then
    echo -e "${YellowBack}${BoldText}###-WARNING(line $LINENO): Your node is not synced with WORKCHAIN. Wait for all shards to sync or your accounts may not be accessible (<$TIMEDIFF_MAX) Current shards (by worst shard) timediff: $SH_TIME_DIFF${NormText}"
    "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "$Tg_SOS_sign ###-ERROR(line $LINENO): Your node is not synced with WORKCHAIN. Wait for all shards to sync or your accounts may not be accessible (<$TIMEDIFF_MAX) Current shards (by worst shard) timediff: $SH_TIME_DIFF" 2>&1 > /dev/null
    # exit 1
else
    echo "INFO: Current WC TimeDiff: $SH_TIME_DIFF"
fi
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
    Work_Chain=${Validator_addr%%:*}
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
    Val_Adrr_HEX=${Validator_addr##*:}
    
    #=================================================
    # check availabylity to recover amount

    case "${NODE_TYPE}" in
        RUST)
            LC_OUTPUT="$(Get_SC_current_state "${elector_addr}")"
            case ${ELECTOR_TYPE} in
                "fift")
                    recover_amount=$($CALL_TC runget --boc ${elector_addr##*:}.boc compute_returned_stake 0x${Val_Adrr_HEX} 2>&1 | grep "Result:" | awk -F'"' '{print $2}')
                    ;;
                "solidity")
                    recover_amount=$($CALL_TC run --boc ${elector_addr##*:}.boc compute_returned_stake "{\"wallet_addr\":\"${Val_Adrr_HEX}\"}" --abi ${Elector_ABI} 2>&1 | grep -i "value0" | awk '{print $2}' | tr -d '"')
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
    # =================================================
    # recover_amount=1
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

        TC_OUTPUT="$($CALL_TC message --raw --output recover-msg.boc \
        --sign ${KEYS_DIR}/${VALIDATOR_NAME}.keys.json \
        --abi $SafeC_Wallet_ABI \
        "$(cat ${KEYS_DIR}/${VALIDATOR_NAME}.addr)" submitTransaction \
        "{\"dest\":\"$elector_addr\",\"value\":1000000000,\"bounce\":true,\"allBalance\":false,\"payload\":\"$recover_query_payload\"}" \
        | grep -i 'Message saved to file')"

        if [[ -z ${TC_OUTPUT} ]];then
            echo "###-ERROR(line $LINENO): tonos-cli CANNOT create boc file!!! Can't continue."
            exit 3
        fi

        mv -f recover-msg.boc "${ELECTIONS_WORK_DIR}/"
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
                "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "$Tg_SOS_sign ###-ERROR(line $LINENO): Sending transaction for elections FAILED!!!" 2>&1 > /dev/null
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

dpc_addr=${Depool_addr##*:}
dpc_wc=${Depool_addr%%:*}
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
        "${Tg_Warn_sign} WARNING!!! Tik account has balance less 2 tokens!! I will topup it with 10 tokens from ${VALIDATOR_NAME} account" 2>&1 > /dev/null
    
    # TopUp_Result="$(${SCRIPT_DIR}/transfer_amount.sh ${VALIDATOR_NAME} Tik 10 | tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log")"
    #================================================================
    # Make BOC file to send
    Validator_addr="$(cat ${KEYS_DIR}/${VALIDATOR_NAME}.addr)"
    Custodians="$(Get_Account_Custodians_Info "$Validator_addr")"
    Val_Confirm_QTY=$(echo $Custodians|awk '{print $2}')

    TA_BOC_File="${KEYS_DIR}/Transfer_Amount.boc"
    rm -f "${TA_BOC_File}" &>/dev/null
    TC_OUTPUT="$($CALL_TC message --raw --output ${TA_BOC_File} \
    --sign "${KEYS_DIR}/${VALIDATOR_NAME}.keys.json" \
    --abi "${SafeC_Wallet_ABI}" \
    ${Validator_addr} submitTransaction \
    "{\"dest\":\"${Tik_addr}\",\"value\":$((10 * 1000000000)),\"bounce\":true,\"allBalance\":false,\"payload\":\"\"}" \
    --lifetime 600 | grep -i 'Message saved to file')"

    if [[ ! -f ${TA_BOC_File} ]];then
        echo "###-ERROR(line $LINENO): Failed to make BOC file ${TA_BOC_File}."
        "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server: DePool Tik:" \
            "${Tg_SOS_sign}###-ERROR(line $LINENO): Failed to make BOC file ${TA_BOC_File} for topup Tik account."
    fi
    # -------------------------------------------
    Trans_List="$(Get_MSIG_Trans_List ${Validator_addr})"
    Before_Trans_QTY=`echo "$Trans_List" | jq -r ".transactions|length"`
    Before_Trans_QTY=$((Before_Trans_QTY))

    if [[ $Before_Trans_QTY -ne 0 ]];then
        echo "+++WARNING(line $LINENO): You have $Before_Trans_QTY unsigned transactions already."
        "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server: DePool Tik:" \
            "${Tg_Warn_sign} WARNING(line $LINENO): You have $Before_Trans_QTY unsigned transactions already."
    fi

    # -------------------------------------------
    for (( i=1; i <= 5; i++ )); do
        result=`Send_File_To_BC "${TA_BOC_File}"`
        if [[ "$result" == "failed" ]]; then
            echo " FAIL"
            echo "Now sleep $LC_Send_MSG_Timeout secs and will try again.."
            echo "--------------"
            sleep $LC_Send_MSG_Timeout
            continue
        fi

       if [[ $Val_Confirm_QTY -le 1 ]];then
            ACCOUNT_INFO="$(Get_Account_Info $Validator_addr)"
            Time_Unix=`echo $ACCOUNT_INFO |awk '{print $3}'`
            if [[ $Time_Unix -gt $SRC_Time_Unix ]];then
                echo -e "INFO: successfully sent $TRANSF_AMOUNT tokens."
                break
            fi
       fi

        Trans_List="$(Get_MSIG_Trans_List ${Validator_addr})"
        Trans_QTY=`echo "$Trans_List" | jq -r ".transactions|length"`
        Trans_QTY=$((Trans_QTY))
        if [[ $Trans_QTY -gt $Before_Trans_QTY ]] && [[ $Val_Confirm_QTY -gt 1 ]];then
            Last_Trans_ID=`echo "$Trans_List" | jq -r .transactions[$((Trans_QTY - 1))].id`
            echo -e "INFO: successfully created transaction # $Last_Trans_ID"
            break
       fi
    done

    if [[ $Val_Confirm_QTY -gt 1 ]];then
        
        ${SCRIPT_DIR}/Sign_Trans.sh ${VALIDATOR_NAME} $Last_Trans_ID | tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
    fi
fi
#=================================================


#=================================================
# Check DePool has enough balance to operate, and replenish if no
# ------------------------------------------------
# check depool contract status
Depool_Info="$(Get_Account_Info $Depool_addr)"
Depool_Acc_State=`echo "$Depool_Info" |awk '{print $1}'`
if [[ "$Depool_Acc_State" == "None" ]];then
    echo -e "${BoldText}${RedBack}###-ERROR(line $LINENO): Depool Account does not exist! (no tokens, no code, nothing)${NormText}"
    echo
    exit 1
elif [[ "$Depool_Acc_State" == "Uninit" ]];then
    echo -e "${BoldText}${RedBack}###-ERROR(line $LINENO): Depool Account does not deployed.${NormText}"
    echo "Has balance : $(echo "$Depool_Info" |awk '{print $2}')"
    echo
    exit 1
fi

# get info from DePool contract state
Depool_Bal=$(( $(echo "$Depool_Info" |awk '{print $2}') ))      # nanotokens
Current_Depool_Info="$(Get_DP_Info $Depool_addr)"
DP_balanceThreshold=$(( $(echo "$Current_Depool_Info"|jq -r '.balanceThreshold') - 3000000000))       # nanotokens
DP_Above_Thresh=$(( 10 * 1000000000))

if [[ $Depool_Bal -lt $DP_balanceThreshold ]];then
    Replanish_Amount=$(( DP_balanceThreshold - Depool_Bal + DP_Above_Thresh ))
    echo "+++-WARNING(line $LINENO): DePool has balance less $((DP_balanceThreshold / 1000000000)) tokens!! I will topup it with $((DP_Above_Thresh / 1000000000)) tokens from ${VALIDATOR_NAME} account" | tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
    "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server: DePool Tik:" \
        "${Tg_Warn_sign} WARNING(line $LINENO): DePool has balance less $((DP_balanceThreshold / 1000000000)) tokens!! I will topup it with $((Replanish_Amount / 1000000000)) tokens from ${VALIDATOR_NAME} account" 2>&1 > /dev/null
    Replenish_Payload='te6ccgEBAQEABgAACGhEx+s='

    rm -f replanish.boc
    TC_OUTPUT="$($CALL_TC message --raw --output replanish.boc \
    --sign ${KEYS_DIR}/${VALIDATOR_NAME}.keys.json \
    --abi $SafeC_Wallet_ABI \
    "$(cat ${KEYS_DIR}/${VALIDATOR_NAME}.addr)" submitTransaction \
    "{\"dest\":\"$(cat ${KEYS_DIR}/depool.addr)\",\"value\":$Replanish_Amount,\"bounce\":true,\"allBalance\":false,\"payload\":\"$Replenish_Payload\"}" \
    | grep -i 'Message saved to file')"
    Send_File_To_BC replanish.boc 
    # TODO: Add signing for a few cutodians
    # Required_Signs=`Get_Account_Custodians_Info $Validator_addr | awk '{print $2}'`
    ./Sign_Trans.sh &>/dev/null
fi

#=================================================
# make boc file 
function Make_BOC_file(){
    TC_OUTPUT="$($CALL_TC message --raw --output tik-msg.boc \
            --sign ${KEYS_DIR}/Tik.keys.json \
            --abi $SafeC_Wallet_ABI \
            "$(cat ${KEYS_DIR}/Tik.addr)" submitTransaction \
            "{\"dest\":\"$Depool_addr\",\"value\":$NANOSTAKE,\"bounce\":true,\"allBalance\":false,\"payload\":\"$Tik_Payload\"}" \
            | grep -i 'Message saved to file')"

    if [[ -z $(echo $TC_OUTPUT | grep -i 'Message saved to file') ]];then
        echoerr "###-ERROR(line $LINENO): CANNOT create boc file!!! Can't continue."
        exit 2
    fi

    mv -f tik-msg.boc "${ELECTIONS_WORK_DIR}/tik-msg.boc"
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
            echoerr "+++-WARNING(line $LINENO): DePool does not receve message .. Repeat sending.."| tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
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
    echo "ERORR ELECTION $elections_id DIFFER ELECTION FROM DePOOL $Curr_DP_Elec_ID" > "${prepElections}"
else
    echo "INFO:      Election ID: $elections_id" | tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
    echo "Elections ID in DePool: $Curr_DP_Elec_ID" | tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
    date +"INFO: %F %T %Z DePool is set for current elections." | tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
    echo "INFO $elections_id" > "${prepElections}"
fi

echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date  +'%F %T %Z')"
echo "================================================================================================"

exit 0
