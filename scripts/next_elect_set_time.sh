#!/bin/bash 

# (C) Sergey Tyurin  2021-03-15 15:00:00

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

SCRPT_USER=$USER

DELAY_TIME=0        # Delay time from the start of elections
TIME_SHIFT=300      # Time between sequential scripts

echo
echo "############################## Set crontab for next elections ##################################"
echo "INFO: $(basename "$0") BEGIN $(date +%s) / $(date  +'%F %T %Z')"
# ===================================================
SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/functions.shinc"

#=================================================
echo "INFO from env: Network: $NETWORK_TYPE; Node: $NODE_TYPE; Elector: $ELECTOR_TYPE; Staking mode: $STAKE_MODE"
echo
echo -e "$(Determine_Current_Network)"
echo
if [[ "$NODE_TYPE" == "RUST" ]];then
    URL_for_TL="$(cat ${SCRIPT_DIR}/tonos-cli.conf.json | jq -r '.url')"
    DApp_State="$(Check_DApp_URL)"
    if [[ "$DApp_State" != "fine" ]];then
    echo "+++-ERROR(line $LINENO): DApp server has state: $DApp_State. Check network type in env.sh and URL in tonos-cli.conf.json: $URL_for_TL"
    "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server: DePool Tik:" \
        "ALARM!!! DApp server has state: $DApp_State. Check DApp, network type in env.sh and URL in tonos-cli.conf.json: $URL_for_TL" 2>&1 > /dev/null
    exit 1
    fi
fi

[[  ! -d $ELECTIONS_WORK_DIR ]] && mkdir -p $ELECTIONS_WORK_DIR
[[  ! -d $ELECTIONS_HISTORY_DIR ]] && mkdir -p $ELECTIONS_HISTORY_DIR

# ===================================================
function GET_M_H() {
    OS_SYSTEM=`uname -s`
    ival="${1}"
    if [[ "$OS_SYSTEM" == "Linux" ]];then
        echo "$(date  +'%M %H' -d @$ival)"
    else
        echo "$(date -r $ival +'%M %H')"
    fi
}

#######################################################################################################
#===================================================
# Get current electoin cycle info
elector_addr=$(Get_Elector_Address)
echo "INFO: Elector Address: $elector_addr"

election_id=$(Get_Current_Elections_ID)
echo "INFO: Current Election ID: $election_id"

case "$NODE_TYPE" in
    RUST)
        ELECT_TIME_PAR=$($CALL_TC getconfig 15 2>&1 |sed -e '1,4d'|sed "s/Config p15: //")
        LIST_PREV_VALS=$($CALL_TC getconfig 32 2>&1 |sed -e '1,4d'|sed "s/Config p32: //")
        LIST_CURR_VALS=$($CALL_TC getconfig 34 2>&1 |sed -e '1,4d'|sed "s/Config p34: //")
        LIST_NEXT_VALS=$($CALL_TC getconfig 36 2>&1 |sed -e '1,4d'|sed "s/Config p36: //")
        declare -i CURR_VAL_UNTIL=`echo "${LIST_CURR_VALS}" | jq '.utime_until'| head -n 1`	            # utime_until
        if [[ "$election_id" == "0" ]];then 
            CURR_VAL_UNTIL=`echo "${LIST_PREV_VALS}" | jq '.utime_until'| head -n 1`	                # utime_until
            if [[ "$(echo "${LIST_NEXT_VALS}"|head -n 1)" != "null" ]];then
                CURR_VAL_UNTIL=`echo "${LIST_NEXT_VALS}" | jq '.utime_since'| head -n 1`	            # utime_since
            fi
        fi
        declare -i VAL_DUR=`echo "${ELECT_TIME_PAR}"        | jq '.validators_elected_for'| head -n 1`	# validators_elected_for
        declare -i STRT_BEFORE=`echo "${ELECT_TIME_PAR}"    | jq '.elections_start_before'| head -n 1`	# elections_start_before
        declare -i EEND_BEFORE=`echo "${ELECT_TIME_PAR}"    | jq '.elections_end_before'| head -n 1`	# elections_end_before
        ;;
    CPP)
        ELECT_TIME_PAR=`$CALL_LC -rc "getconfig 15" -t "3" -rc "quit" 2>/dev/null`
        LIST_PREV_VALS=`$CALL_LC -rc "getconfig 32" -t "3" -rc "quit" 2>/dev/null`
        LIST_CURR_VALS=`$CALL_LC -rc "getconfig 34" -t "3" -rc "quit" 2>/dev/null`
        LIST_NEXT_VALS=`$CALL_LC -rc "getconfig 36" -t "3" -rc "quit" 2>/dev/null`
        declare -i CURR_VAL_UNTIL=`echo "${LIST_CURR_VALS}" | grep -i "cur_validators"  | awk -F ":" '{print $4}'|awk '{print $1}'`	# utime_until
        NEXT_VAL_EXIST=`echo "${LIST_NEXT_VALS}"| grep -i "ConfigParam(36)" | grep -i 'null'`                                       # Config p36: null
        if [[ "$election_id" == "0" ]];then 
            CURR_VAL_UNTIL=`echo "${LIST_PREV_VALS}" | grep -i "prev_validators"  | awk -F ":" '{print $4}'|awk '{print $1}'`	    # utime_until
            if [[ -z "$NEXT_VAL_EXIST" ]];then
                CURR_VAL_UNTIL=`echo "${LIST_NEXT_VALS}" | grep -i "next_validators"  | awk -F ":" '{print $3}'|awk '{print $1}'`	# utime_until
            fi
        fi
        declare -i VAL_DUR=`echo "${ELECT_TIME_PAR}"        | grep -i "ConfigParam(15)" | awk -F ":" '{print $2}' |awk '{print $1}'`	# validators_elected_for
        declare -i STRT_BEFORE=`echo "${ELECT_TIME_PAR}"    | grep -i "ConfigParam(15)" | awk -F ":" '{print $3}' |awk '{print $1}'`	# elections_start_before
        declare -i EEND_BEFORE=`echo "${ELECT_TIME_PAR}"    | grep -i "ConfigParam(15)" | awk -F ":" '{print $4}' |awk '{print $1}'`	# elections_end_before
        ;;
    *)
        echo "###-ERROR(line $LINENO): Unknown node type! Set NODE_TYPE= to 'RUST' or CPP' in env.sh"
        exit 1
        ;; 
esac
#===================================================
# 
PREV_ELECTION_TIME=$((CURR_VAL_UNTIL - STRT_BEFORE + TIME_SHIFT + DELAY_TIME))
PREV_ELECTION_SECOND_TIME=$(($PREV_ELECTION_TIME + $TIME_SHIFT))
PREV_ADNL_TIME=$(($PREV_ELECTION_SECOND_TIME + $TIME_SHIFT))
PREV_BAL_TIME=$(($PREV_ADNL_TIME + $TIME_SHIFT))
PREV_CHG_TIME=$(($PREV_BAL_TIME + $TIME_SHIFT))

PRV_ELECT_1=$(GET_M_H "$PREV_ELECTION_TIME")
PRV_ELECT_2=$(GET_M_H "$PREV_ELECTION_SECOND_TIME")
PRV_ELECT_3=$(GET_M_H "$PREV_ADNL_TIME")
PRV_ELECT_4=$(GET_M_H "$PREV_BAL_TIME")
PRV_ELECT_5=$(GET_M_H "$PREV_CHG_TIME")

#===================================================
# 
NEXT_ELECTION_TIME=$((CURR_VAL_UNTIL + VAL_DUR - STRT_BEFORE + $TIME_SHIFT + DELAY_TIME))
NEXT_ELECTION_SECOND_TIME=$(($NEXT_ELECTION_TIME + $TIME_SHIFT))
NEXT_ADNL_TIME=$(($NEXT_ELECTION_SECOND_TIME + $TIME_SHIFT))
NEXT_BAL_TIME=$(($NEXT_ADNL_TIME + $TIME_SHIFT))
NEXT_CHG_TIME=$(($NEXT_BAL_TIME + $TIME_SHIFT))

NXT_ELECT_1=$(GET_M_H "$NEXT_ELECTION_TIME")
NXT_ELECT_2=$(GET_M_H "$NEXT_ELECTION_SECOND_TIME")
NXT_ELECT_3=$(GET_M_H "$NEXT_ADNL_TIME")
NXT_ELECT_4=$(GET_M_H "$NEXT_BAL_TIME")
NXT_ELECT_5=$(GET_M_H "$NEXT_CHG_TIME")


GET_PART_LIST_TIME=$((election_id - EEND_BEFORE))
GPL_TIME_MH=$(GET_M_H "$GET_PART_LIST_TIME")

#===================================================

CURRENT_CHG_TIME=`crontab -l |tail -n 1 | awk '{print $1 " " $2}'`

GET_F_T(){
    OS_SYSTEM=`uname`
    ival="${1}"
    if [[ "$OS_SYSTEM" == "Linux" ]];then
        echo "$(date  +'%Y-%m-%d %H:%M:%S' -d @$ival)"
    else
        echo "$(date -r $ival +'%Y-%m-%d %H:%M:%S')"
    fi
}

echo
echo "Current elections time start: $PREV_ELECTION_TIME / $(GET_F_T "$PREV_ELECTION_TIME")"
echo "Next elections time start: $NEXT_ELECTION_TIME / $(GET_F_T "$NEXT_ELECTION_TIME")"
echo "-------------------------------------------------------------------"

# if [[ ! -z $NEXT_VAL__EXIST ]] && [[ "$election_id" == "0" ]];then
#   NXT_ELECT_1=$PRV_ELECT_1
#   NXT_ELECT_2=$PRV_ELECT_2
#   NXT_ELECT_3=$PRV_ELECT_3
#   NXT_ELECT_4=$PRV_ELECT_4
# fi

# sudo crontab -u $SCRPT_USER -r

OS_SYSTEM=`uname -s`
FB_CT_HEADER=""
if [[ "$OS_SYSTEM" == "FreeBSD" ]];then

CRONT_JOBS=$(cat <<-_ENDCRN_
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin:/home/$SCRPT_USER/bin
HOME=/home/$SCRPT_USER
$NXT_ELECT_1 * * *    cd ${SCRIPT_DIR} && ./prepare_elections.sh >> ${TON_LOG_DIR}/validator.log
$NXT_ELECT_2 * * *    cd ${SCRIPT_DIR} && ./take_part_in_elections.sh >> ${TON_LOG_DIR}/validator.log
$NXT_ELECT_3 * * *    cd ${SCRIPT_DIR} && ./next_elect_set_time.sh >> ${TON_LOG_DIR}/validator.log && ./part_check.sh >> ${TON_LOG_DIR}/validator.log
$GPL_TIME_MH * * *    cd ${SCRIPT_DIR} && ./get_participant_list.sh > ${ELECTIONS_HISTORY_DIR}/${election_id}_parts.lst && chmod 444 ${ELECTIONS_HISTORY_DIR}/${election_id}_parts.lst
_ENDCRN_
)

else

CRONT_JOBS=$(cat <<-_ENDCRN_
$NXT_ELECT_1 * * *    script --return --quiet --append --command "cd ${SCRIPT_DIR} && ./prepare_elections.sh >> ${TON_LOG_DIR}/validator.log"
$NXT_ELECT_2 * * *    script --return --quiet --append --command "cd ${SCRIPT_DIR} && ./take_part_in_elections.sh >> ${TON_LOG_DIR}/validator.log"
$NXT_ELECT_3 * * *    script --return --quiet --append --command "cd ${SCRIPT_DIR} && ./next_elect_set_time.sh >> ${TON_LOG_DIR}/validator.log && ./part_check.sh >> ${TON_LOG_DIR}/validator.log"
$GPL_TIME_MH * * *    script --return --quiet --append --command "cd ${SCRIPT_DIR} && ./get_participant_list.sh > ${ELECTIONS_HISTORY_DIR}/${election_id}_parts.lst && chmod 444 ${ELECTIONS_HISTORY_DIR}/${election_id}_parts.lst"
_ENDCRN_
)

fi

[[ "$1" == "show" ]] && echo "$CRONT_JOBS"&& exit 0

echo "$CRONT_JOBS" | sudo crontab -u $SCRPT_USER -

sudo crontab -l -u $SCRPT_USER | tail -n 8

echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date)"
echo "================================================================================================"

exit 0
