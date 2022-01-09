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

####################################
# we can't work on desynced node
TIMEDIFF_MAX=100
MAX_FACTOR=${MAX_FACTOR:=3}
SEND_ATTEMPTS=3
####################################

echo
echo "#################################### Participate script ########################################"
echo "INFO: $(basename "$0") BEGIN $(date +%s) / $(date  +'%F %T %Z')"

SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/functions.shinc"

#=================================================
echo -e "$(DispEnvInfo)"
echo
echo -e "$(Determine_Current_Network)"
echo
#===========================================================
# Check staking mode and node type
case "$STAKE_MODE" in
    depool)
        echo "+++-WARNING(line $LINENO): Staking mode is set to $STAKE_MODE"
        ;;
    msig)
        echo "+++-WARNING(line $LINENO): Staking mode is set to $STAKE_MODE"
        ;;
    *)
        echo "###-ERROR(line $LINENO): Unknown staing mode $STAKE_MODE. Check STAKE_MODE in env.sh "
        ;;
esac
case "$NODE_TYPE" in
    RUST)
        echo "+++-WARNING(line $LINENO): Node type is set to $NODE_TYPE"
        ;;
    CPP)
        echo "+++-WARNING(line $LINENO): Node type is set to $NODE_TYPE"
        ;;
    *)
        echo "###-ERROR(line $LINENO): Unknown NODE TYPE!!! Check NODE_TYPE in env.sh "
        exit 1
        ;;
esac


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

##############################################################################
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
##############################################################################
# get elector address
elector_addr=$(Get_Elector_Address)
echo "INFO: Elector Address: $elector_addr"

##############################################################################
# get elections ID from elector
elections_id=$(Get_Current_Elections_ID)
elections_id=$((elections_id))
echo "INFO:      Election ID: $elections_id"
if [[ $elections_id -eq 0 ]];then
    echo
    echo "###-ERROR(line $LINENO): There are NO elections now!"
    echo
    exit 1
fi

if [[ ! -f "${ELECTIONS_WORK_DIR}/${elections_id}.log" ]];then
  touch "${ELECTIONS_WORK_DIR}/${elections_id}.log"
  echo "Election ID: $elections_id" >> "${ELECTIONS_WORK_DIR}/${elections_id}.log"
  echo "Elector address: $elector_addr" >> "${ELECTIONS_WORK_DIR}/${elections_id}.log"
fi

##############################################################################
# check depool contract status
if [[ "$STAKE_MODE" == "depool" ]];then
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

    ##############################################################################
    # Get proxy adrrs from depool
    Current_Depool_Info=$(Get_DP_Info $Depool_addr)
    dp_val_wal="$(echo "$Current_Depool_Info" | jq -r ".validatorWallet")"
    if [[ "$dp_val_wal" != "$Validator_addr" ]];then
        echo "###-ERROR(line $LINENO): Validator account is NOT owner of the DePool!!! Staking impossible!"
        exit 1
    fi
    dp_proxy0="$(echo "$Current_Depool_Info"  | jq -r "[.proxies[]]|.[0]"|tr -d '"')"
    dp_proxy1="$(echo "$Current_Depool_Info"  | jq -r "[.proxies[]]|.[1]"|tr -d '"')"

    if [[ -z $dp_proxy0 ]] || [[ -z $dp_proxy1 ]];then
        echo "###-ERROR(line $LINENO): Cannot get proxies from depool contract. Can't continue. Exit" 
        exit 1
    fi
    echo "${dp_proxy0}" > ${KEYS_DIR}/proxy0.addr
    echo "${dp_proxy1}" > ${KEYS_DIR}/proxy1.addr

    ########################################################################################
    # Check DePool ready for elections
    Depool_Rounds_Info="$(Get_DP_Rounds $Depool_addr)"
    Curr_Rounds_Info="$(Rounds_Sorting_by_ID "$Depool_Rounds_Info")"
    Curr_DP_Elec_ID=$(echo "$Curr_Rounds_Info" | jq -r ".[1].supposedElectedAt" | xargs printf "%d\n")

    if [[ $elections_id -ne $Curr_DP_Elec_ID ]]; then
        echo "###-ALARM(line $LINENO): Current elections ID from elector $elections_id ($(TD_unix2human "$elections_id")) is not equal elections ID from DP: $Curr_DP_Elec_ID ($(TD_unix2human "$Curr_DP_Elec_ID"))" \
            | tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
        echo "###- I run TIK SCRIPT for last chance..." | tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
        "${SCRIPT_DIR}/prepare_elections.sh"
    fi

    Depool_Rounds_Info="$(Get_DP_Rounds $Depool_addr)"
    Curr_Rounds_Info="$(Rounds_Sorting_by_ID "$Depool_Rounds_Info")"
    Curr_DP_Elec_ID=$(echo "$Curr_Rounds_Info" | jq -r ".[1].supposedElectedAt" | xargs printf "%d\n")

    if [[ $elections_id -ne $Curr_DP_Elec_ID ]] && [[ $elections_id -gt 0 ]]; then
        echo "###-ERROR(line $LINENO): Current elections ID from elector $elections_id ($(TD_unix2human "$elections_id")) is not equal elections ID from DP: $Curr_DP_Elec_ID ($(TD_unix2human "$Curr_DP_Elec_ID"))" \
            | tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
        echo "INFO: $(basename "$0") END $(date +%s) / $(date)"
        date +"INFO: %F %T %Z Tik DePool FALED!" | tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
        "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server: DePool Tik:" \
            "$Tg_SOS_sign ALARM!!! Current elections ID from elector $elections_id ($(TD_unix2human $elections_id)) is not equal elections ID from DePool: $Curr_DP_Elec_ID ($(TD_unix2human $Curr_DP_Elec_ID))" 2>&1 > /dev/null
        exit 1
    fi

    ##############################################################################
    # Determine DePool proxy addr for current elections
    echo "Elections ID in depool: $Curr_DP_Elec_ID"
    Curr_DP_Round_ID=$(echo  "$Curr_Rounds_Info" | jq -r ".[1].id" | xargs printf "%d\n")
    Proxy_ID=$((Curr_DP_Round_ID % 2))
    File_Round_Proxy="`cat ${KEYS_DIR}/proxy${Proxy_ID}.addr`"
    echo "Proxy addr   from file: $File_Round_Proxy" | tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
    [[ -z $File_Round_Proxy ]] && echo "###-ERROR(line $LINENO) Cannot get proxy for this round from file. Can't continue. Exit" && exit 1

    DP_Round_Proxy="$(echo "$Current_Depool_Info"|jq -r ".proxies[$Proxy_ID]")"
    echo "Proxy addr from depool: $DP_Round_Proxy" | tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
    [[ -z $DP_Round_Proxy ]] && echo "###-ERROR(line $LINENO) Cannot get proxy for this round from depool contract. Can't continue. Exit" && exit 1
fi
#####################################################################################
# Checking that are you took participate already
echo "INFO: Check you participate already ... "

# Check node ADNL present in Elector's participants list

# "CurrADNL Curr_ID Next_ADNL Next_ID"
Engine_ADNLs=$(Get_Engine_ADNL)

Next_ADNL_Key=`echo $Engine_ADNLs|awk '{print $3}'`
[[ -z $Next_ADNL_Key ]] && Next_ADNL_Key=`echo $Engine_ADNLs|awk '{print $3}'` # in case it has not prev keys

#   "stake time max_factor addr" - if found
ADNL_Found="$(Elector_ADNL_Search $Next_ADNL_Key)"

if [[ "$ADNL_Found" != "absent" ]];then
    echo
    echo "INFO: You participate already in this elections ($elections_id)"
    Your_Stake=`echo "${ADNL_Found}" | awk '{print $1 / 1000000000}'`
    You_PubKey=`echo "${ADNL_Found}" | awk '{print $4}'`
    echo "You public key in Elector: $You_PubKey"
    echo "You will start validate from $(TD_unix2human $elections_id)"
    Your_ADNL=$Next_ADNL_Key
    echo "-!-!-INFO: Your stake: $Your_Stake with ADNL: $(echo "$Next_ADNL_Key" | tr "[:upper:]" "[:lower:]")"
    echo
    exit 1
fi

########################################################################################
# Prepare for elections
date +"INFO: %F %T Current elections ID: $elections_id"

#=================================================
# Get Elections parametrs (p15)
echo "INFO: Get elections parametrs (p15)"
CONFIG_PAR_15="$(Get_NetConfig_P15)"
#   validators_elected_for elections_start_before elections_end_before stake_held_for
validators_elected_for=`echo $CONFIG_PAR_15 | awk '{print $1}'`
elections_start_before=`echo $CONFIG_PAR_15 | awk '{print $2}'`
elections_end_before=`echo $CONFIG_PAR_15   | awk '{print $3}'`
stake_held_for=`echo $CONFIG_PAR_15         | awk '{print $4}'`
if [[ -z $validators_elected_for ]] || [[ -z $elections_start_before ]] || [[ -z $elections_end_before ]] || [[ -z $stake_held_for ]];then
    echo "###-ERROR(line $LINENO): Get network election params (p15) FAILED!!!"
    exit 1
fi

Validating_Start=${elections_id}
Validating_Stop=$(( ${Validating_Start} + 1000 + ${validators_elected_for} + ${elections_start_before} + ${elections_end_before} + ${stake_held_for} ))
echo "Validating_Start: $Validating_Start | Validating_Stop: $Validating_Stop"

next_election_id=$((elections_id + validators_elected_for))
if [[ "${Proxy_ID}" == "0" ]];then
    echo "1" > ${ELECTIONS_WORK_DIR}/${next_election_id}_proxy.id
else
    echo "0" > ${ELECTIONS_WORK_DIR}/${next_election_id}_proxy.id
fi

#=================================================
# Checking that query.boc already made for sending to Elector
if [[ -f ${ELECTIONS_WORK_DIR}/${elections_id}_query.boc ]];then
    echo "+++WARNING(line $LINENO): ${elections_id}_query.boc for current elections generated already. We will use the existing one."
else
# Make query.boc to send to Elector
    case "${NODE_TYPE}" in
        RUST)
            if [[ "$STAKE_MODE" == "depool" ]];then
                cat "${R_CFG_DIR}/console.json" | jq ".wallet_id = \"${DP_Round_Proxy}\"" > console.tmp
                # cp console.tmp console.${elections_id}
            else
                cat "${R_CFG_DIR}/console.json" | jq ".wallet_id = \"${Validator_addr}\"" > console.tmp
                # cp console.tmp console.${elections_id}
            fi
            mv -f console.tmp  ${R_CFG_DIR}/console.json
            $CALL_RC -c "election-bid $Validating_Start $Validating_Stop" &> "${ELECTIONS_WORK_DIR}/${elections_id}-bid.log"
            # cp -f ${R_CFG_DIR}/config.json config.${elections_id}
            ;;
        CPP)
            if [[ "$STAKE_MODE" == "depool" ]];then
                Result="$(CNode_Make_Elect_Keys_and_BOC "${DP_Round_Proxy}" "$Validating_Start" "$Validating_Stop")"
            else
                Result="$(CNode_Make_Elect_Keys_and_BOC "${Validator_addr}" "$Validating_Start" "$Validating_Stop")"
            fi
            if [[ -n "${Result}" ]];then
                echo "Elections pubkey:   $(echo "$Result"|awk '{print $1}')"
                echo "Elections ADNL key: $(echo "$Result"|awk '{print $2}')"
            else
                echo "###-ERROR(line $LINENO): Make and add elections keys to CNODE FAILED!!!"
                exit 1
            fi
            ;;
          *)
            echo "###-ERROR(line $LINENO): Unknown NODE TYPE!!!"
            exit 1
            ;;            
    esac
    mv -f validator-query.boc "${ELECTIONS_WORK_DIR}/${elections_id}_query.boc"
fi

######################################################################################################
# prepare validator query to elector contract using multisig for lite-client

validator_query_payload=$(base64 "${ELECTIONS_WORK_DIR}/${elections_id}_query.boc" |tr -d "\n")
# ===============================================================
# parameters checks
if [[ -z $validator_query_payload ]];then
    echo "###-ERROR(line $LINENO): Payload is empty! It is unasseptable!"
    echo "did you have right ${elections_id}_query.boc ?"
    exit 2
fi

# ===============================================================
# Check unsend transactins in validator contract
Trans_List="$(Get_MSIG_Trans_List ${Validator_addr})"
declare -i Trans_QTY=`echo "$Trans_List" | jq -r ".transactions|length"`
declare -i Exist_El_Trans_Qty=0
declare -i Exist_DP_Trans_Qty=0
if [[ $Trans_QTY -gt 0 ]];then
    Exist_El_Trans_Qty=$(echo "$Trans_List" | jq -r "[.transactions[]|select(.dest == \"$elector_addr\")]|length")
    [[ "$STAKE_MODE" == "depool" ]] && Exist_DP_Trans_Qty=$(echo "$Trans_List" | jq -r "[.transactions[]|select(.dest == \"$Depool_addr\")]|length")
    echo "+++WARNING(line $LINENO): You have unsigned transactions on the validator address!! Transactions: to elector: $Exist_El_Trans_Qty; To DePool: $Exist_DP_Trans_Qty"
    "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" \
        "${Tg_Warn_sign} WARNING($(basename "$0") line $LINENO): You have unsigned transactions on the validator address!! Transactions: to elector: $Exist_El_Trans_Qty; To DePool: $Exist_DP_Trans_Qty" 2>&1 > /dev/null
fi
echo "Total transactions qty:      $Trans_QTY"          | tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
echo "To DePool transactions qty:  $Exist_DP_Trans_Qty" | tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
echo "To Elector transactions qty: $Exist_El_Trans_Qty" | tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"

# ===============================================================
# Calculate stake for BOC
NANOSTAKE=$((1 * 1000000000))
Stake_DST_Addr=$Depool_addr
if [[ "$STAKE_MODE" == "msig" ]];then
    Stake_DST_Addr=$elector_addr
    MSIG_FIX_STAKE=$((MSIG_FIX_STAKE))
    Validator_Acc_Balance=`echo "$Validator_Acc_Info" | awk '{print $2}'`
    if [[ $MSIG_FIX_STAKE -gt 0 ]];then     # ================================== Fixed stake
        if [[ $Validator_Acc_Balance -gt $MSIG_FIX_STAKE ]];then
            NANOSTAKE=$((MSIG_FIX_STAKE * 1000000000))
        else
            echo "###-ERROR(line $LINENO): You have not has enouth tokens on account. You set stake $MSIG_FIX_STAKE but you have $Validator_Acc_Balance only."
            exit 1
        fi
    else                                    # ================================== Stake for full balance
        if [[ $Validator_Acc_Balance -gt $VAL_ACC_INIT_BAL ]];then    # first time staking for full balance
            NANOSTAKE=$(( ($Validator_Acc_Balance / 2 - VAL_ACC_RESERVED) * 1000000000))
        else
            NANOSTAKE=$(( ($Validator_Acc_Balance - VAL_ACC_RESERVED)  * 1000000000))
        fi
    fi
    echo "INFO: You stake: $(printf "%'9.2f" "$(echo $((NANOSTAKE)) / 1000000000 | jq -nf /dev/stdin)") Tk / $NANOSTAKE nTk"
fi

#####################################################################################################
###############  Send request to participate in elections ###########################################
#####################################################################################################

# ===============================================================
# make boc for sending
function Make_transaction_BOC() {
    # TVM_OUTPUT=$($CALL_TL message $Val_Adrr_HEX \
    #     -a ${SafeC_Wallet_ABI} \
    #     -m submitTransaction \
    #     -p "{\"dest\":\"$Stake_DST_Addr\",\"value\":$NANOSTAKE,\"bounce\":true,\"allBalance\":false,\"payload\":\"$validator_query_payload\"}" \
    #     -w $Work_Chain --setkey ${KEYS_DIR}/msig.keys.bin)

    local TC_OUTPUT="$($CALL_TC message --raw --output ${elections_id}_vaidator-query-msg.boc \
        --sign ${KEYS_DIR}/${VALIDATOR_NAME}.keys.json \
        --abi $SafeC_Wallet_ABI \
        "$(cat ${KEYS_DIR}/${VALIDATOR_NAME}.addr)" submitTransaction \
        "{\"dest\":\"$Stake_DST_Addr\",\"value\":$NANOSTAKE,\"bounce\":true,\"allBalance\":false,\"payload\":\"$validator_query_payload\"}" \
        | grep -i 'Message saved to file')"

    if [[ -z ${TC_OUTPUT} ]];then
        echo "###-ERROR(line $LINENO): tonos-cli CANNOT create boc file!!! Can't continue."
        exit 3
    fi
    mv -f ${elections_id}_vaidator-query-msg.boc ${ELECTIONS_WORK_DIR}/
}

Required_Signs=`Get_Account_Custodians_Info $Validator_addr | awk '{print $2}'`
Trans_DST_Addr=$Depool_addr
Tx_Qty_Check=$Exist_DP_Trans_Qty
if [[ "$STAKE_MODE" == "msig" ]];then
    Trans_DST_Addr=$elector_addr
    Tx_Qty_Check=$Exist_El_Trans_Qty
fi
declare -i New_Trans_Qty=0
########################################################################
function Send_Bid_Msg(){
    local Attempts_to_send=$SEND_ATTEMPTS
    while [[ $Attempts_to_send -gt 0 ]]; do
        result=`Send_File_To_BC "${ELECTIONS_WORK_DIR}/${elections_id}_vaidator-query-msg.boc"`
        if [[ "$result" == "failed" ]]; then
            echoerr "###-ERROR(line $LINENO): Send message for elections FAILED!!!"| tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
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
                echo "INFO: Sending transaction for elections was done SUCCESSFULLY!" >> "${ELECTIONS_WORK_DIR}/${elections_id}.log"
                break
            else
                echoerr "###-ERROR(line $LINENO): Sending transaction for elections FAILED!!!" | tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
                Attempts_to_send=$((Attempts_to_send - 1))
            fi
        fi

    done
    echo $Attempts_to_send
}
########################################################################
## 5x3 attempts to make trasaction
for (( TryToSetEl=0; TryToSetEl <= 5; TryToSetEl++ ))
do
    echo -n "INFO: Make transaction boc ..."
    #################
    Make_transaction_BOC
    #################
    echo " DONE"

    echo -n "INFO: Send query to Elector... "
    #################
    Attempts_to_send=$(( $(Send_Bid_Msg | tail -n 1) ))
    #################
    echo " DONE"
    if [[ $Attempts_to_send -le 0 ]];then
        echo "###-=ERROR(line $LINENO): ALARM!!! Cannot send transaction for elections!!!" | tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
    else
        break
    fi
done
########################################################################
# Final checking
# ===============================================================
# Verifying that a transaction has been created 

# for icinga
[[ -f ${partInElections} ]] && echo "" > "${partInElections}"

if [[ $Required_Signs -gt 1 ]];then
    Trans_List="$(Get_MSIG_Trans_List ${Validator_addr})"
    New_Trans_Qty=$(( $(echo "$Trans_List" | jq -r "[.transactions[]|select(.dest == \"$Trans_DST_Addr\")]|length") ))
    if [[ $New_Trans_Qty -gt $Tx_Qty_Check ]];then
        Elect_Trans_ID=$(echo "$Trans_List" | jq -r ".transactions[]|select(.dest == \"$Trans_DST_Addr\")|.id"|tail -n 1)
        echo "INFO: Making transaction for elections was done SUCCESSFULLY! Trnasaction ID: $Elect_Trans_ID You have to sign this transaction!!"| tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
        echo "Made transaction ID: $Elect_Trans_ID" >> "${ELECTIONS_WORK_DIR}/${elections_id}.log"
        ${SCRIPT_DIR}/Sign_Trans.sh ${VALIDATOR_NAME} ${Elect_Trans_ID}| tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
        # for icinga
        echo "INFO PARTICIPATION IN ELECTION ${elections_id} OK TRANSACTION" >> "${partInElections}"
    else
        echo "###-ERROR(line $LINENO): Transaction does not made or timeout is too low!" | tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
        "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server ALARM!!!" "$Tg_SOS_sign ###-ERROR(line $LINENO): Transaction does not made or timeout is too low!" 
        # for icinga
        echo "ERROR PARTICIPATION IN ELECTION ${elections_id} FAILED TRANSACTION" >> "${partInElections}"
    fi
else
    # ===============================================================
    # Verifying that a transaction has been sent (for 1 custodian acc) by cheching change last transaction time
    Validator_Acc_Info="$(Get_Account_Info ${Validator_addr})"
    declare -i Validator_Acc_LT_Sent=`echo "$Validator_Acc_Info" | awk '{print $3}'`
    if [[ $Validator_Acc_LT_Sent -gt $Validator_Acc_LT ]];then
        echo "INFO: Sending transaction for elections was done SUCCESSFULLY!"| tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
        # for icinga
        echo "INFO PARTICIPATION IN ELECTION ${elections_id} OK" >> "${partInElections}"
    else
        echo "###-ERROR(line $LINENO): Sending transaction for elections FAILED!!!" | tee -a "${ELECTIONS_WORK_DIR}/${elections_id}.log"
        "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "$Tg_SOS_sign ###-ERROR(line $LINENO): Sending transaction for elections FAILED!!!" 2>&1 > /dev/null
        # for icinga
        echo "ERROR PARTICIPATION IN ELECTION ${elections_id} FAILED" >> "${partInElections}"
    fi
fi

echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date  +'%F %T %Z')"
echo "================================================================================================"

exit 0
