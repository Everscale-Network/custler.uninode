#!/usr/bin/env bash

DINFO_STRT_TIME=$(date +%s)

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

set -o pipefail
####################################
# we can't work on desynced node
TIMEDIFF_MAX=100
export LC_NUMERIC="C"
####################################

echo
echo "#################################### Depool INFO script ########################################"
echo "INFO: $(basename "$0") BEGIN $(date +%s) / $(date  +'%F %T %Z')"

SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/functions.shinc"

#=================================================
echo
echo -e "$(DispEnvInfo)"
echo
echo -e "$(Determine_Current_Network)"
echo

##############################################################################
# Load addresses and set variables
# net id - first 16 syms of zerostate id

Depool_Name=$1
if [[ -z $Depool_Name ]];then
    Depool_Name="depool"
    Depool_addr=`cat "${KEYS_DIR}/${Depool_Name}.addr"`
    if [[ -z $Depool_addr ]];then
        echo "###-ERROR(line $LINENO): Can't find depool address file! ${KEYS_DIR}/${Depool_Name}.addr"
        exit 1
    fi
else
    Depool_addr=$Depool_Name
    acc_fmt="$(echo "$Depool_addr" |  awk -F ':' '{print $2}')"
    [[ -z $acc_fmt ]] && Depool_addr=`cat "${KEYS_DIR}/${Depool_Name}.addr"`
fi
if [[ -z $Depool_addr ]];then
    echo "###-ERROR(line $LINENO): Can't find depool address file! ${KEYS_DIR}/${Depool_Name}.addr"
    exit 1
fi

dpc_addr=`echo $Depool_addr | cut -d ':' -f 2`
dpc_wc=`echo $Depool_addr | cut -d ':' -f 1`
if [[ ${#dpc_addr} -ne 64 ]] || [[ ${dpc_wc} -lt 0 ]];then
    echo "###-ERROR(line $LINENO): Wrong depool address! ${Depool_addr}"
    exit 1
fi

[[ -f ${KEYS_DIR}/Tik.addr ]] && Tik_addr=`cat ${KEYS_DIR}/Tik.addr`
[[ -f ${KEYS_DIR}/proxy0.addr ]] && Proxy0_addr=`cat ${KEYS_DIR}/proxy0.addr`
[[ -f ${KEYS_DIR}/proxy1.addr ]] && Proxy1_addr=`cat ${KEYS_DIR}/proxy1.addr`
Validator_addr=`cat ${KEYS_DIR}/${VALIDATOR_NAME}.addr`

if [[ -z $Validator_addr ]];then
    echo "+++-WARNING(line $LINENO): Can't find local validator address file! ${KEYS_DIR}/${VALIDATOR_NAME}.addr"
fi

echo "INFO: Local validator account address: $Validator_addr"
ELECTIONS_WORK_DIR="${KEYS_DIR}/elections"
[[ ! -d ${ELECTIONS_WORK_DIR} ]] && mkdir -p ${ELECTIONS_WORK_DIR}
chmod +x ${ELECTIONS_WORK_DIR}

##############################################################################
# Check node sync
TIME_DIFF=$(Get_TimeDiff)
MC_TIME_DIFF=$(echo $TIME_DIFF|awk '{print $1}')
SH_TIME_DIFF=$(echo $TIME_DIFF|awk '{print $2}')
if [[ $SH_TIME_DIFF -gt $TIMEDIFF_MAX ]];then
    echo -e "${YellowBack}${BoldText}###-WARNING(line $LINENO): Your node is not synced with WORKCHAIN. Wait for all shards to sync or your accounts may not be accessible (<$TIMEDIFF_MAX) Current shards (by worst shard) timediff: $SH_TIME_DIFF${NormText}"
    # exit 1
fi
echo "INFO: Current TimeDiffs: MC - $MC_TIME_DIFF ; WC - $SH_TIME_DIFF"

##############################################################################
# get elector address
elector_addr=$(Get_Elector_Address)
echo "INFO:     Elector Address: $elector_addr"

##############################################################################
# Get Elections Time parameters
CONFIG_PAR_15="$(Get_NetConfig_P15)"
validators_elected_for=`echo $CONFIG_PAR_15 | awk '{print $1}'`
##############################################################################
# get elections ID from elector
echo
echo "==================== Elections Info ====================================="
elections_id=$(Get_Current_Elections_ID)
elections_id=$((elections_id))
if [[ $elections_id -eq 0 ]];then
    echo -e "   ${YellowBack}${BoldText}=> There are no Elections now.${NormText}"
else
    echo "   => Elector Elections ID: $elections_id / $(echo "$elections_id" | gawk '{print strftime("%Y-%m-%d %H:%M:%S", $1)}')"
fi
echo

Node_Keys="$(Get_Engine_ADNL)"

if [[ $Node_Keys  != "null" ]];then
    Curr_Engine_Eclec_ID=$(echo "$Node_Keys" | awk '{print $2}')
    Curr_Engine_ADNL_Key=$(echo "$Node_Keys" | awk '{print $1}'|tr "[:upper:]" "[:lower:]")
    Next_Engine_Eclec_ID=$(echo "$Node_Keys" | awk '{print $4}')
    Next_Engine_ADNL_Key=$(echo "$Node_Keys" | awk '{print $3}'|tr "[:upper:]" "[:lower:]")

    if [[ -z $Next_Engine_Eclec_ID ]];then
        echo "Current Engine Elections ID: $Curr_Engine_Eclec_ID / $(echo "$Curr_Engine_Eclec_ID" | gawk '{print strftime("%Y-%m-%d %H:%M:%S", $1)}')"
        echo "    Current Engine ADNL key: $Curr_Engine_ADNL_Key"
    else
        Curr_Engine_Eclec_ID=$(echo "$Node_Keys" | grep "validator1"| grep -i 'tempkey:' | awk '{print $2}')
        Curr_Engine_ADNL_Key=$(echo "$Node_Keys" | grep "validator1"| grep -i 'adnl:'    | awk '{print $4}'|tr "[:upper:]" "[:lower:]")

        echo "Current Engine Elections ID: $Curr_Engine_Eclec_ID / $(echo "$Curr_Engine_Eclec_ID" | gawk '{print strftime("%Y-%m-%d %H:%M:%S", $1)}')"
        echo "    Current Engine ADNL key: $Curr_Engine_ADNL_Key"
        echo
        echo "   Next Engine Elections ID: $Next_Engine_Eclec_ID / $(echo "$Next_Engine_Eclec_ID" | gawk '{print strftime("%Y-%m-%d %H:%M:%S", $1)}')"
        echo "       Next Engine ADNL key: $Next_Engine_ADNL_Key"
    fi
else
    echo "+++-WARNING(line $LINENO): There is no information about elections keys in the engine. You may not have participated in any elections yet."
fi

#######################################################################################
# Get Depool Info
# returns (
#    {"name":"poolClosed","type":"bool"},
#    {"name":"minStake","type":"uint64"},
#    {"name":"validatorAssurance","type":"uint64"},
#    {"name":"participantRewardFraction","type":"uint8"},
#    {"name":"validatorRewardFraction","type":"uint8"},
#    {"name":"balanceThreshold","type":"uint64"},
#    {"name":"validatorWallet","type":"address"},
#    {"name":"proxies","type":"address[]"},
#    {"name":"stakeFee","type":"uint64"},
#    {"name":"retOrReinvFee","type":"uint64"},
#    {"name":"proxyFee","type":"uint64"}

echo 
echo "==================== Current Depool State ====================================="
#============================================
# check depool contract status
Depool_Info="$(Get_Account_Info $Depool_addr)"
Depool_Acc_State=`echo "$Depool_Info" |awk '{print $1}'`
if [[ "$Depool_Acc_State" == "None" ]];then
    echo -e "${BoldText}${RedBack}###-ERROR(line $LINENO): Depool Account does not exist! (no tokens, no code, nothing)${NormText}"
    echo
    exit 0
elif [[ "$Depool_Acc_State" == "Uninit" ]];then
    echo -e "${BoldText}${RedBack}###-ERROR(line $LINENO): Depool Account does not deployed.${NormText}"
    echo "Has balance : $(echo "$Depool_Info" |awk '{print $2}')"
    echo
    exit 0
fi

#============================================
# get info from DePool contract state
Current_Depool_Info="$(Get_DP_Info $Depool_addr)"

PoolClosed=$(echo  "$Current_Depool_Info"|jq -r '.poolClosed')
if [[ "$PoolClosed" == "false" ]];then
    PoolState="${GreeBack}OPEN for participation!${NormText}"
fi
if [[ "$PoolClosed" == "true" ]];then
    PoolState="${RedBlink}CLOSED!!! all stakes should be return to participants${NormText}"
fi
if [[ "$PoolClosed" == "false" ]] || [[ "$PoolClosed" == "true" ]];then
    echo -e "Pool State: $PoolState"
else
    echo "###-ERROR(line $LINENO): Can't determine the Depool state!! All following data is invalid!!!"
fi
echo
echo "==================== Depool addresses ====================================="

DP_Owner_Addr=$(echo "$Current_Depool_Info" | jq -r ".validatorWallet" )
dp_proxy0=$(echo "$Current_Depool_Info"  | jq -r "[.proxies[]]|.[0]")
dp_proxy1=$(echo "$Current_Depool_Info"  | jq -r "[.proxies[]]|.[1]")

[[ ! -f ${KEYS_DIR}/proxy0.addr ]] && echo "$dp_proxy0" > ${KEYS_DIR}/proxy0.addr
[[ ! -f ${KEYS_DIR}/proxy1.addr ]] && echo "$dp_proxy1" > ${KEYS_DIR}/proxy1.addr

#============================================
# Get balances
Depool_Bal=`echo "$(Get_Account_Info "$Depool_addr")"| awk '{print $2}'`
Depool_Self_Balance=
Val_Bal=`echo "$(Get_Account_Info "$DP_Owner_Addr")"| awk '{print $2}'`
prx0_Bal=`echo "$(Get_Account_Info "$dp_proxy0")"| awk '{print $2}'`
prx1_Bal=`echo "$(Get_Account_Info "$dp_proxy1")"| awk '{print $2}'`
[[ -n $Tik_addr ]] && Tik_Bal=`echo "$(Get_Account_Info "$Tik_addr")"| awk '{print $2}'`

#============================================
# Get depool fininfo
PoolSelfMinBalance=$(echo "$Current_Depool_Info"|jq -r '.balanceThreshold')
PoolMinStake=$(echo "$Current_Depool_Info"      |jq -r '.minStake')
validatorAssurance=$(echo "$Current_Depool_Info"|jq -r '.validatorAssurance')
ValRewardFraction=$(echo "$Current_Depool_Info" |jq -r '.validatorRewardFraction')
PoolValStakeFee=$(echo "$Current_Depool_Info"   |jq -r '.stakeFee')
PoolRetOrReinvFee=$(echo "$Current_Depool_Info" |jq -r '.retOrReinvFee')

#============================================
# Get depool rounds info
Depool_Rounds_Info="$(Get_DP_Rounds $Depool_addr)"
Curr_Rounds_Info="$(Rounds_Sorting_by_ID "$Depool_Rounds_Info")"

# ------------------------------------------------------------------------------------------------------------------------
Prev_DP_Elec_ID=$(echo   "$Curr_Rounds_Info" | jq -r ".[0].supposedElectedAt" | xargs printf "%10d\n")
Prev_DP_Round_ID=$(echo  "$Curr_Rounds_Info" | jq -r ".[0].id"                | xargs printf "%d\n")
Prev_Round_P_QTY=$(echo  "$Curr_Rounds_Info" | jq -r ".[0].participantQty"    | xargs printf "%4d\n")
Prev_Round_Stake=$(echo  "$Curr_Rounds_Info" | jq -r ".[0].stake"             | xargs printf "%d\n")
# Prev_Round_Reward=$(echo "$Curr_Rounds_Info" | jq -r "[.rounds[]]|.[0].rewards"           | xargs printf "%d\n")
Prev_Round_Stake=$(printf '%12.3f' "$(echo $Prev_Round_Stake / 1000000000 | jq -nf /dev/stdin)")
# Prev_Round_Reward=$(printf '%12.3f' "$(echo $Prev_Round_Reward / 1000000000 | jq -nf /dev/stdin)")

Curr_DP_Elec_ID=$(echo   "$Curr_Rounds_Info" | jq -r ".[1].supposedElectedAt" | xargs printf "%10d\n")
Curr_Round_P_QTY=$(echo  "$Curr_Rounds_Info" | jq -r ".[1].participantQty"    | xargs printf "%4d\n")
Curr_DP_Round_ID=$(echo  "$Curr_Rounds_Info" | jq -r ".[1].id"                | xargs printf "%d\n")
Curr_Round_Stake_nT=$(echo  "$Curr_Rounds_Info" | jq -r ".[1].stake"             | xargs printf "%d\n")
# Curr_Round_Reward=$(echo "$Curr_Rounds_Info" | jq -r "[.rounds[]]|.[1].rewards"           | xargs printf "%d\n")
Curr_Round_Stake=$(printf '%12.3f' "$(echo $Curr_Round_Stake_nT / 1000000000 | jq -nf /dev/stdin)")
# Curr_Round_Reward=$(printf '%12.3f' "$(echo $Curr_Round_Reward / 1000000000 | jq -nf /dev/stdin)")

Next_DP_Elec_ID=$(echo   "$Curr_Rounds_Info"  | jq -r ".[2].supposedElectedAt"| xargs printf "%d\n")
[[ $Next_DP_Elec_ID -eq 0 ]] && Next_DP_Elec_ID=$((Curr_DP_Elec_ID + validators_elected_for))
Next_DP_Round_ID=$(echo  "$Curr_Rounds_Info"  | jq -r ".[2].id"               | xargs printf "%d\n")
Next_Round_P_QTY=$(echo  "$Curr_Rounds_Info"  | jq -r ".[2].participantQty"   | xargs printf "%4d\n")
Next_Round_Stake_nT=$(echo  "$Curr_Rounds_Info"| jq -r ".[2].stake"            | xargs printf "%d\n")
# Next_Round_Reward=$(echo "$Curr_Rounds_Info"  | jq -r "[.rounds[]]|.[2].rewards"          | xargs printf "%d\n")
Next_Round_Stake=$(printf '%12.3f' "$(echo $Next_Round_Stake_nT / 1000000000 | jq -nf /dev/stdin)")
# Next_Round_Reward=$(printf '%12.3f' "$(echo $Next_Round_Reward / 1000000000 | jq -nf /dev/stdin)")

echo "Depool contract address:     $Depool_addr  Balance: $(echo "scale=3; $((Depool_Bal - Next_Round_Stake_nT)) / 1000000000" | $CALL_BC)"
echo "Depool Owner/validator addr: $DP_Owner_Addr  Balance: $(echo "scale=3; $((Val_Bal)) / 1000000000" | $CALL_BC)"
echo "Depool proxy #0:            $dp_proxy0  Balance: $(echo "scale=3; $((prx0_Bal)) / 1000000000" | $CALL_BC)"
echo "Depool proxy #1:            $dp_proxy1  Balance: $(echo "scale=3; $((prx1_Bal)) / 1000000000" | $CALL_BC)"
[[ ! -z $Tik_addr ]] && \
echo "Local Tik account:           $Tik_addr  Balance: $(echo "scale=3; $((Tik_Bal)) / 1000000000" | $CALL_BC)"
echo
echo "================ Finance information for the depool ==========================="

echo "                Pool Min Stake (Tk): $(echo "scale=3; $((PoolMinStake)) / 1000000000" | $CALL_BC)"
echo "            Validator Comission (%): $((ValRewardFraction))"
echo "              Depool stake fee (Tk): $(echo "scale=3; $((PoolValStakeFee)) / 1000000000" | $CALL_BC)"
echo " Depool return or reinvest fee (Tk): $(echo "scale=3; $((PoolRetOrReinvFee)) / 1000000000" | $CALL_BC)"
echo " Depool min balance to operate (Tk): $(echo "scale=3; $((PoolSelfMinBalance)) / 1000000000" | $CALL_BC)"
echo "           Validator Assurance (Tk): $((validatorAssurance / 1000000000))"
echo
##################################################################################################################
echo "============================ Depool rounds info ==============================="


echo " --------------------------------------------------------------------------------------------------------------------------"
echo "|                 |              Prev Round          |           Current Round          |              Next Round          |"
echo " --------------------------------------------------------------------------------------------------------------------------"
echo "|        Seq No   |       $(printf '%12d' "$Prev_DP_Round_ID")               |       $(printf '%12d' "$Curr_DP_Round_ID")               |       $(printf '%12d' "$Next_DP_Round_ID")               |"
echo "|            ID   | $Prev_DP_Elec_ID / $(echo "$Prev_DP_Elec_ID" | gawk '{print strftime("%Y-%m-%d %H:%M:%S", $1)}') | $Curr_DP_Elec_ID / $(echo "$Curr_DP_Elec_ID" | gawk '{print strftime("%Y-%m-%d %H:%M:%S", $1)}') | $Next_DP_Elec_ID / $(echo "$Next_DP_Elec_ID" | gawk '{print strftime("%Y-%m-%d %H:%M:%S", $1)}') |"
echo "| Participant QTY |               $Prev_Round_P_QTY               |               $Curr_Round_P_QTY               |               $Next_Round_P_QTY               |"
echo "|         Stake   |           $Prev_Round_Stake           |           $Curr_Round_Stake           |           $Next_Round_Stake           |"
# echo "|        Reward   |           $Prev_Round_Reward           |           $Curr_Round_Reward           |           $Next_Round_Reward           |"
echo " --------------------------------------------------------------------------------------------------------------------------"
echo
##################################################################################################################
echo "==================== Depool Owner Ordinary, Lock & Vesting stakes info ========================"
DP_Owner_Info="$(Get_DP_Part_Info $Depool_addr $DP_Owner_Addr)"

Lock_Stake_Donor=`echo "${DP_Owner_Info}"|jq -r '.lockDonor'`
Lock_Stake_Round_0_Info=`echo "${DP_Owner_Info}"|jq '[.locks[]]|.[0]'`
if [[ "${Lock_Stake_Round_0_Info}" != "null" ]];then
    Lock_Stake_Round_1_Info=`echo "${DP_Owner_Info}"|jq '[.locks[]]|.[1]'`
    Lock_Stake_Round_0_Amount_nT=`echo "${Lock_Stake_Round_0_Info}"|jq -r '.remainingAmount'`
    Lock_Stake_Round_1_Amount_nT=`echo "${Lock_Stake_Round_1_Info}"|jq -r '.remainingAmount'`
    Lock_Stake_Round_0_Amount=`printf '%12.3f' "$(echo $Lock_Stake_Round_0_Amount_nT / 1000000000 | jq -nf /dev/stdin)"`
    Lock_Stake_Round_1_Amount=`printf '%12.3f' "$(echo $Lock_Stake_Round_1_Amount_nT / 1000000000 | jq -nf /dev/stdin)"`
    Lock_Stake_Setted=`echo $Lock_Stake_Round_0_Info |jq -r '.lastWithdrawalTime'`
    Lock_Stake_Set_For=`echo $Lock_Stake_Round_0_Info|jq -r '.withdrawalPeriod'`
    Lock_Stake_Out_Date=$((Lock_Stake_Setted + Lock_Stake_Set_For))
fi
# =================================================================================================================
Vest_Stake_Donor=`echo "${DP_Owner_Info}"|jq -r '.vestingDonor'`
Vest_Stake_Round_0_Info=`echo "${DP_Owner_Info}"|jq '[.vestings[]]|.[0]'`
if [[ "${Vest_Stake_Round_0_Info}" != "null" ]];then
    Vest_Stake_Round_1_Info=`echo "${DP_Owner_Info}"|jq '[.vestings[]]|.[1]'`
    Vest_Stake_Round_0_Amount_nT=`echo "${Vest_Stake_Round_0_Info}"|jq -r '.remainingAmount'`
    Vest_Stake_Round_1_Amount_nT=`echo "${Vest_Stake_Round_1_Info}"|jq -r '.remainingAmount'`
    Vest_Stake_Round_0_Amount=`printf '%12.3f' "$(echo $Vest_Stake_Round_0_Amount_nT / 1000000000 | jq -nf /dev/stdin)"`
    Vest_Stake_Round_1_Amount=`printf '%12.3f' "$(echo $Vest_Stake_Round_1_Amount_nT / 1000000000 | jq -nf /dev/stdin)"`
    WSWD=`echo $Vest_Stake_Round_0_Info |jq -r '.lastWithdrawalTime'`
    WSWP=`echo $Vest_Stake_Round_0_Info|jq -r '.withdrawalPeriod'`
    VS_Withdr_Date_0=$((WSWD + WSWP))
    WSWD=`echo $Vest_Stake_Round_1_Info |jq -r '.lastWithdrawalTime'`
    WSWP=`echo $Vest_Stake_Round_1_Info|jq -r '.withdrawalPeriod'`
    VS_Withdr_Date_1=$((WSWD + WSWP))
    VS_Withdr_Amount_0_nt=`echo "${Vest_Stake_Round_0_Info}"|jq -r '.withdrawalValue'`
    VS_Withdr_Amount_1_nt=`echo "${Vest_Stake_Round_1_Info}"|jq -r '.withdrawalValue'`
    VS_Withdr_Amount=$((VS_Withdr_Amount_0_nt + VS_Withdr_Amount_1_nt))
    VS_Withdr_Amount_0=`printf '%12.3f' "$(echo $VS_Withdr_Amount_0_nt / 1000000000 | jq -nf /dev/stdin)"`
    VS_Withdr_Amount_1=`printf '%12.3f' "$(echo $VS_Withdr_Amount_1_nt / 1000000000 | jq -nf /dev/stdin)"`
fi

echo " --------------------------------------------------------------------------------------------------------------------------"
echo "|                 |              Prev Round          |           Current Round          |      Lock stake return day       |"
echo " --------------------------------------------------------------------------------------------------------------------------"
echo "|                                               LOCK STAKE                                                                 |"
echo "| Donor:  $Lock_Stake_Donor                                               |"
if [[ "${Lock_Stake_Round_0_Info}" != "null" ]];then
echo "| Remain Amount   |          $Lock_Stake_Round_0_Amount            |            $Lock_Stake_Round_1_Amount          |       $(echo "$Lock_Stake_Out_Date" | gawk '{print strftime("%Y-%m-%d %H:%M:%S", $1)}')        |"
else
echo "|                                         YOU HAVE NO LOCK STAKE                                                           |"
fi
echo " --------------------------------------------------------------------------------------------------------------------------"
echo "|                                             VESTING STAKE                             |"
echo "| Donor:  $Vest_Stake_Donor            |"
if [[ "${Vest_Stake_Round_0_Info}" != "null" ]];then
echo "| Remain Amount   |          $Vest_Stake_Round_0_Amount            |            $Vest_Stake_Round_1_Amount          |"
echo "| Withdrow Date   |        $(echo "$VS_Withdr_Date_0"|gawk '{print strftime("%Y-%m-%d %H:%M:%S", $1)}')       |          $(echo "$VS_Withdr_Date_0" | gawk '{print strftime("%Y-%m-%d %H:%M:%S", $1)}')     |"
echo "| Withdrow Amount |          $VS_Withdr_Amount_0            |            $VS_Withdr_Amount_1          |"
else
echo "|                                     YOU HAVE NO VESTING STAKE                         |"
fi
echo " ---------------------------------------------------------------------------------------"

##################################################################################################################
echo
echo "=================== Current participants info in the depool ==================="

Participants_List="$(Get_DP_Parts_List $Depool_addr)"

Num_of_participants=$(echo "$Participants_List" | jq '.participants|length')
echo "Current Number of participants: $Num_of_participants"
echo

Prev_Round_Part_QTY=$(echo "$Curr_Rounds_Info" | jq -r ".[0].participantQty" | xargs printf "%d\n")
Curr_Round_Part_QTY=$(echo "$Curr_Rounds_Info" | jq -r ".[1].participantQty" | xargs printf "%d\n")
Next_Round_Part_QTY=$(echo "$Curr_Rounds_Info" | jq -r ".[2].participantQty" | xargs printf "%d\n")

##################################################################################################################
echo "===== Current Round participants QTY (prev/curr/next/lock): $((Prev_Round_Part_QTY + 1)) / $((Curr_Round_Part_QTY + 1)) / $((Next_Round_Part_QTY + 1))"

CRP_QTY=$((Curr_Round_Part_QTY - 1))
for (( i=0; i <= $CRP_QTY; i++ ))
do
    Curr_Part_Addr="$(echo "$Participants_List"| jq -r ".participants|.[$i]")"
    Current_Participant_Info="$(Get_DP_Part_Info $Depool_addr $Curr_Part_Addr)"

    Prev_Ord_Stake=$(echo "$Current_Participant_Info" | jq -r ".stakes.\"$Prev_DP_Round_ID\"")
    POS_Info=$(printf "%'9.2f" "$(echo $((Prev_Ord_Stake)) / 1000000000 | jq -nf /dev/stdin)")
    
    Curr_Ord_Stake=$(echo "$Current_Participant_Info" | jq -r ".stakes.\"$Curr_DP_Round_ID\"")
    COS_Info=$(printf "%'9.2f" "$(echo $((Curr_Ord_Stake)) / 1000000000 | jq -nf /dev/stdin)")
    
    Next_Ord_Stake=$(echo "$Current_Participant_Info" | jq -r ".stakes.\"$Next_DP_Round_ID\"")
    NOS_Info=$(printf "%'9.2f" "$(echo $((Next_Ord_Stake)) / 1000000000 | jq -nf /dev/stdin)")
    
    Reward=$(echo "$Current_Participant_Info"| jq -r ".reward")
    RWRD_Info=$(printf "%'8.2f" "$(echo $((Reward)) / 1000000000 | jq -nf /dev/stdin)")

    Reinvest=$(echo "$Current_Participant_Info" | jq -r ".reinvest")
    REINV_Info=""
    if [[ "${Reinvest}" == "false" ]];then
        REINV_Info="${RedBack}GONE${NormText}"
    elif [[ "${Reinvest}" == "true" ]];then
        REINV_Info="Stay"
    fi

    Wtdr_Val_hex=$(echo "$Current_Participant_Info" | jq -r ".withdrawValue")
    Wtdr_Val_Info=""
    if [[ $Wtdr_Val_hex -ne 0 ]];then
        Wtdr_Val_Info="; Next round withdraw: $(echo "scale=3; $((Wtdr_Val_hex)) / 1000000000" | $CALL_BC)"
    fi

    #--------------------------------------------
    echo -e "$(printf '%4d' $(($i + 1))) $Curr_Part_Addr Reward: $RWRD_Info ; Stakes(${REINV_Info}): $POS_Info / $COS_Info / $NOS_Info   $Wtdr_Val_Info"
    #--------------------------------------------
done

##################################################################################################################
echo
echo "===== Total Depool participants (prev/curr/next/lock) =============================="

CRP_QTY=$((Num_of_participants - 1))
for (( i=0; i <= $CRP_QTY; i++ ))
do
    Curr_Part_Addr="$(echo "$Participants_List"| jq -r ".participants|.[$i]")"
    Current_Participant_Info="$(Get_DP_Part_Info $Depool_addr $Curr_Part_Addr)"

    Prev_Ord_Stake=$(echo "$Current_Participant_Info" | jq -r ".stakes.\"$Prev_DP_Round_ID\"")
    POS_Info=$(printf "%'9.2f" "$(echo $((Prev_Ord_Stake)) / 1000000000 | jq -nf /dev/stdin)")
    
    Curr_Ord_Stake=$(echo "$Current_Participant_Info" | jq -r ".stakes.\"$Curr_DP_Round_ID\"")
    COS_Info=$(printf "%'9.2f" "$(echo $((Curr_Ord_Stake)) / 1000000000 | jq -nf /dev/stdin)")
    
    Next_Ord_Stake=$(echo "$Current_Participant_Info" | jq -r ".stakes.\"$Next_DP_Round_ID\"")
    NOS_Info=$(printf "%'9.2f" "$(echo $((Next_Ord_Stake)) / 1000000000 | jq -nf /dev/stdin)")

    Vesting_Stake=$(echo "$Current_Participant_Info" | jq -r '[.vestings[]][0].remainingAmount')
    VOS_Info=$(printf "%'9.2f" "$(echo $((Vesting_Stake *2)) / 1000000000 | jq -nf /dev/stdin)")

    Reward=$(echo "$Current_Participant_Info" | jq -r ".reward")
    RWRD_Info=$(printf "%'8.2f" "$(echo $((Reward)) / 1000000000 | jq -nf /dev/stdin)")

    Reinvest=$(echo "$Current_Participant_Info" | jq -r ".reinvest")
    REINV_Info=""
    if [[ "${Reinvest}" == "false" ]];then
        REINV_Info="${RedBack}GONE${NormText}"
    elif [[ "${Reinvest}" == "true" ]];then
        REINV_Info="Stay"
    fi

    Wtdr_Val_hex=$(echo "$Current_Participant_Info" | jq -r ".withdrawValue")
    Wtdr_Val_Info=""
    if [[ $Wtdr_Val_hex -ne 0 ]];then
        Wtdr_Val_Info="; Next round withdraw: $(echo "scale=3; $((Wtdr_Val_hex)) / 1000000000" | $CALL_BC)"
    fi

    #--------------------------------------------
    echo -e "$(printf '%4d' $(($i + 1))) $Curr_Part_Addr Reward: $RWRD_Info ; Stakes(${REINV_Info}): $POS_Info / $COS_Info / $NOS_Info   $Wtdr_Val_Info Vesting: $VOS_Info"
    #--------------------------------------------
done

DINFO_END_TIME=$(date +%s)
Dinfo_mins=$(( (DINFO_END_TIME - DINFO_STRT_TIME)/60 ))
Dinfo_secs=$(( (DINFO_END_TIME - DINFO_STRT_TIME)%60 ))
echo
echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date  +'%F %T %Z')"
echo "Gather info took $Dinfo_mins min $Dinfo_secs secs"
echo "================================================================================================"

exit 0

