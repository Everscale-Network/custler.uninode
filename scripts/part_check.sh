#!/bin/bash

# (C) Sergey Tyurin  2021-03-15 18:00:00

# Disclaimer
##################################################################################################################
# You running this script/function means you will not blame the author(s).
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

SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
echo
echo "#################################### Check participations script ########################################"
echo "INFO: $(basename "$0") BEGIN $(date +%s) / $(date  +'%F %T %Z')"

SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/functions.shinc"

#=================================================
echo
echo "INFO from env: Network: $NETWORK_TYPE; Node: $NODE_TYPE; Elector: $ELECTOR_TYPE; Staking mode: $STAKE_MODE"
echo
echo -e "$(Determine_Current_Network)"
echo

# =====================================================
Depool_addr=`cat ${KEYS_DIR}/depool.addr`
Validator_addr=`cat ${KEYS_DIR}/${VALIDATOR_NAME}.addr`

# =====================================================
elector_addr="$(Get_Elector_Address)"
elections_id="$(Get_Current_Elections_ID)"
echo "INFO: Elections ID: ${elections_id}"
echo "INFO: DePool Address:    $Depool_addr"
echo "INFO: Validator Address: $Validator_addr"

Engine_ADNL_Info="$(Get_Engine_ADNL)"
if [[ "$Engine_ADNL_Info" == "null" ]];then
    echo "+++-WARNING(line $LINENO): You have not participated in any elections yet!"
    echo
    exit 0
fi

ADNL_KEY="$1"
###### 
if [ "$elections_id" == "0" ]; then
    Curr_ADNL_Key=`echo $Engine_ADNL_Info|awk '{print $3}'`
    [[ -z $Curr_ADNL_Key ]] && Curr_ADNL_Key=`echo $Engine_ADNL_Info|awk '{print $1}'`
    ADNL_KEY=${ADNL_KEY:=$Curr_ADNL_Key}
    echo "INFO: Validator ADNL:    $ADNL_KEY"

    VALS_DEF="NEXT"
    echo
    date +"INFO: %F %T No current elections"
    Part_VAL="$(P36_ADNL_search $ADNL_KEY)"
    if [[ "${Part_VAL}" == "null" ]];then
        Part_VAL="$(P34_ADNL_search $ADNL_KEY)"
        VALS_DEF="CURRENT"
    fi
    
    FOUND_PUB_KEY=`echo "$Part_VAL" |awk '{print $1}'`
    if [[ "$FOUND_PUB_KEY" == "absent" ]];then
        echo "###-ERROR: Your ADNL Key NOT FOUND in current or next validators list!!!"
        "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server:" "###-ERROR: Your ADNL Key NOT FOUND in current or next validators list!!!" 2>&1 > /dev/null

        echo "-----------------------------------------------------------------------------------------------------"
        echo
        exit 1
    fi

    VAL_WEIGHT=`echo "$Part_VAL" | awk '{print $2}'`
    echo
    echo "INFO: Found you in $VALS_DEF validators with weight $(echo "scale=3; ${VAL_WEIGHT} / 10000000000000000" | $CALL_BC)%"
    echo "INFO: Your public key: $FOUND_PUB_KEY"
    echo "INFO: Your   ADNL key: $(echo "$ADNL_KEY" | tr "[:upper:]" "[:lower:]")"
    echo "-----------------------------------------------------------------------------------------------------"
    echo
    exit 0
fi

Next_ADNL_Key=`echo $Engine_ADNL_Info|awk '{print $3}'`
ADNL_KEY=${ADNL_KEY:=$Next_ADNL_Key}
echo "INFO: Validator ADNL:    $ADNL_KEY"
echo
echo "Now is $(date +'%F %T %Z')"
ADNL_FOUND="$(Elector_ADNL_Search $ADNL_KEY)"
if [[ "$ADNL_FOUND" == "absent" ]];then
    echo "###-ERROR: Can't find you in participant list in Elector. account: ${Depool_addr}"
    exit 1
fi

Your_Stake=`echo "${ADNL_FOUND}" | awk '{print $1 / 1000000000}'`
You_PubKey=`echo "${ADNL_FOUND}" | awk '{print $4}'`

echo "---INFO: Your stake: $Your_Stake with ADNL: $(echo "$ADNL_KEY" | tr "[:upper:]" "[:lower:]")"
echo "You public key in Elector: $You_PubKey"
echo "You will start validate from $(TD_unix2human ${elections_id})"

TON_LIVE_URL="https://ton.live/validators?section=details&public_key=${You_PubKey}&key_block_num=undefined"
"${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server:" "We are successfully participate in elections $election_id with stake $Your_Stake and ADNL:  $(echo "$ADNL_KEY" | tr "[:upper:]" "[:lower:]") ${TON_LIVE_URL}" 2>&1 > /dev/null
echo "-----------------------------------------------------------------------------------------------------"
exit 0
