#!/usr/bin/env bash
set -eE

# (C) Sergey Tyurin  2021-10-19 10:00:00

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
echo "############################## Set crontab for next elections ##################################"
echo "INFO: $(basename "$0") BEGIN $(date +%s) / $(date  +'%F %T %Z')"
# ===================================================
SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/functions.shinc"

SCRPT_USER=$USER
USER_HOME=$HOME
[[ -z "$SCRPT_USER" ]] && SCRPT_USER=$LOGNAME
[[ -n $(echo "$USER_HOME"|grep 'root') ]] && SCRPT_USER="root"

#=================================================
echo -e "$(DispEnvInfo)"
echo
echo -e "$(Determine_Current_Network)"
echo


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
function GET_M_H_D() {
    OS_SYSTEM=`uname -s`
    ival="${1}"
    if [[ "$OS_SYSTEM" == "Linux" ]];then
        echo "$(date  +'%M %H %d' -d @$ival)"
    else
        echo "$(date -r $ival +'%M %H %d')"
    fi
}

#######################################################################################################
#===================================================
# Get current electoin cycle info
elector_addr=$(Get_Elector_Address)
echo "INFO: Elector Address: $elector_addr"

election_id=$(Get_Current_Elections_ID)
echo "INFO: Current Election ID: $election_id"

if $FORCE_USE_DAPP ;then
    ELECT_TIME_PAR=$($CALL_TC -j getconfig 15)
    LIST_CURR_VALS=$($CALL_TC -j getconfig 34)
    LIST_NEXT_VALS=$($CALL_TC -j getconfig 36)

    declare -i CURR_VAL_UNTIL=`echo "${LIST_CURR_VALS}" | jq -r '.utime_until'`	            # utime_until
    if [[ "$election_id" == "0" ]];then 
        CURR_VAL_UNTIL=`echo "${LIST_CURR_VALS}" | jq -r '.utime_since'`	                # utime_until
        if [[ "$(echo "${LIST_NEXT_VALS}"|head -n 1)" != 'null' ]];then
            CURR_VAL_UNTIL=`echo "${LIST_NEXT_VALS}" | jq -r '.utime_since'`	            # utime_since
        fi
    fi
    declare -i VAL_DUR=`echo "${ELECT_TIME_PAR}"        | jq -r '.validators_elected_for'`	# validators_elected_for
    declare -i STRT_BEFORE=`echo "${ELECT_TIME_PAR}"    | jq -r '.elections_start_before'`	# elections_start_before
    declare -i EEND_BEFORE=`echo "${ELECT_TIME_PAR}"    | jq -r '.elections_end_before'  `	# elections_end_before
else
    case "$NODE_TYPE" in
        RUST)
            ELECT_TIME_PAR=$($CALL_RC -j -c "getconfig 15")
            LIST_CURR_VALS=$($CALL_RC -j -c "getconfig 34")
            LIST_NEXT_VALS=$($CALL_RC -j -c "getconfig 36")

            declare -i CURR_VAL_UNTIL=`echo "${LIST_CURR_VALS}" | jq -r '.p34.utime_until'`	            # utime_until
            if [[ "$election_id" == "0" ]];then 
                CURR_VAL_UNTIL=`echo "${LIST_CURR_VALS}" | jq -r '.p34.utime_since'`	                # utime_until
                if [[ "$(echo "${LIST_NEXT_VALS}"|head -n 1)" != '{}' ]];then
                    CURR_VAL_UNTIL=`echo "${LIST_NEXT_VALS}" | jq -r '.p36.utime_since'`	            # utime_since
                fi
            fi
            declare -i VAL_DUR=`echo "${ELECT_TIME_PAR}"        | jq -r '.p15.validators_elected_for'`	# validators_elected_for
            declare -i STRT_BEFORE=`echo "${ELECT_TIME_PAR}"    | jq -r '.p15.elections_start_before'`	# elections_start_before
            declare -i EEND_BEFORE=`echo "${ELECT_TIME_PAR}"    | jq -r '.p15.elections_end_before'  `	# elections_end_before
            ;;
        CPP)
            # ConfigParam(34) = (
            # cur_validators:(validators_ext utime_since:1632812112 utime_until:1632822912 total:16 main:16 total_weight:1152921504606846968
            ELECT_TIME_PAR=`$CALL_LC -rc "getconfig 15" -t "3" -rc "quit" 2>/dev/null`
            LIST_CURR_VALS=`$CALL_LC -rc "getconfig 34" -t "3" -rc "quit" 2>/dev/null`
            LIST_NEXT_VALS=`$CALL_LC -rc "getconfig 36" -t "3" -rc "quit" 2>/dev/null`
            declare -i CURR_VAL_UNTIL=`echo "${LIST_CURR_VALS}" | grep -i "cur_validators"  | awk -F ":" '{print $4}'|awk '{print $1}'`	# utime_until
            NEXT_VAL_EXIST=`echo "${LIST_NEXT_VALS}"| grep -i "ConfigParam(36)" | grep -i 'null'`                                       # Config p36: null
            if [[ "$election_id" == "0" ]];then 
                CURR_VAL_UNTIL=`echo "${LIST_CURR_VALS}" | grep -i "cur_validators"  | awk -F ":" '{print $3}'|awk '{print $1}'`	    # utime_until
                if [[ -z "$NEXT_VAL_EXIST" ]];then
                    CURR_VAL_UNTIL=`echo "${LIST_NEXT_VALS}" | grep -i "next_validators"  | awk -F ":" '{print $3}'|awk '{print $1}'`	# next utime_since = curr utime_until
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
fi
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

#===================================================
# Calculate update time based on validator address
Validator_addr=`cat ${KEYS_DIR}/${VALIDATOR_NAME}.addr`
declare -i Validator_Upd_Ord=$(( $(hex2dec "$(echo $Validator_addr|cut -c 33,34)") ))
declare -i Upd_Interval=$(( $VAL_DUR / 256 / 60 * 60 ))
if [[ $Upd_Interval -le 0 ]];then
    Upd_Interval=$(( $VAL_DUR / 128 / 60 * 60 ))
    Validator_Upd_Ord=$((  Validator_Upd_Ord / 2 ))
fi
NEXT_UPD_TIME=$(($PREV_ADNL_TIME + $Validator_Upd_Ord * $Upd_Interval))

#===================================================
# 

NEXT_CHG_TIME=$(($NEXT_UPD_TIME + $TIME_SHIFT))

NXT_ELECT_1=$(GET_M_H "$NEXT_ELECTION_TIME")
NXT_ELECT_2=$(GET_M_H "$NEXT_ELECTION_SECOND_TIME")
NXT_ELECT_3=$(GET_M_H "$NEXT_ADNL_TIME")
NODE_UPDATE_TIME="$(GET_M_H "$NEXT_UPD_TIME") *"
NXT_ELECT_5=$(GET_M_H "$NEXT_CHG_TIME")
GET_PART_LIST_TIME=$((election_id - EEND_BEFORE))
GPL_TIME_MH=$(GET_M_H "$GET_PART_LIST_TIME")

UpdateByCron=true
LINC_present=false
LNI_Info="$( get_LastNodeInfo )"
if [[ "$LNI_Info" ==  "none" ]];then
    echo "###-WARNING(line $LINENO): Last node info from contract not found."
else
    export LINC_present=true
    declare -i UpdateStartTime=$(echo "$LNI_Info" | jq -r '.UpdateStartTime')
    declare -i UpdateDuration=$(echo "$LNI_Info" | jq -r '.UpdateDuration')
    UpdateByCron=$(echo "$LNI_Info" | jq -r '.UpdateByCron')
fi

declare -i Curr_Node_Ver=$($CALL_RC -jc 'getstats' |jq -r '.node_version'| awk -F'.' '{printf("%d%03d%03d\n", $1,$2,$3)}')

if $LINC_present && [[ $UpdateStartTime -gt 0 ]] && [[ $UpdateDuration -gt 0 ]];then
    #=================================================
    # Calculate time to update
    declare -i UpdateStartTime=$(echo "$LNI_Info" | jq -r '.UpdateStartTime')
    declare -i UpdateDuration=$(echo "$LNI_Info" | jq -r '.UpdateDuration')
    
    declare -i UpdTimeShift=$(( UpdateDuration / 256 * Validator_Upd_Ord))
    declare -i CurrNodeUpdTime=$(( UpdTimeShift + UpdateStartTime))
    
    #--------------------------------------------------
    Prep_Elect_Time=$((CURR_VAL_UNTIL - STRT_BEFORE + DELAY_TIME))
    #--------------------------------------------------
    
    ElectionsSkip=$(( (CurrNodeUpdTime - Prep_Elect_Time) / VAL_DUR ))
    NearElectionsID=$((Prep_Elect_Time + (ElectionsSkip * VAL_DUR) ))
    NextElectionsID=$((Prep_Elect_Time + ((ElectionsSkip + 1) * VAL_DUR) ))
    TimeRest=$(( CurrNodeUpdTime - NearElectionsID ))
    
    [[ $TimeRest -lt 1800 ]] && CurrNodeUpdTime=$(( CurrNodeUpdTime + (1800 - TimeRest) ))
    [[ $TimeRest -gt $((VAL_DUR - 1800)) ]] && CurrNodeUpdTime=$(( CurrNodeUpdTime - (1800 - (VAL_DUR - TimeRest) ) ))
    # String for cron
    NODE_UPDATE_TIME="$(GET_M_H_D $CurrNodeUpdTime)"
    declare -i CurrTime=$(date +%s)
    [[ $CurrTime -gt $(( CurrNodeUpdTime + VAL_DUR )) ]] && NODE_UPDATE_TIME="$(GET_M_H "$NEXT_UPD_TIME") *"
fi

if ! $UpdateByCron;then
    NODE_UPDATE_TIME="# $NODE_UPDATE_TIME"
fi

################################################################################################
#===================================================
GET_F_T(){
    OS_SYSTEM=`uname`
    ival="${1}"
    if [[ "$OS_SYSTEM" == "Linux" ]];then
        echo "$(date  +'%Y-%m-%d %H:%M:%S' -d @$ival)"
    else
        echo "$(date -r $ival +'%Y-%m-%d %H:%M:%S')"
    fi
}
#===================================================

Curr_Elect_Time=$((CURR_VAL_UNTIL - STRT_BEFORE))
Next_Elect_Time=$((CURR_VAL_UNTIL + VAL_DUR - STRT_BEFORE))
echo
echo "Current elections time start: $Curr_Elect_Time / $(GET_F_T "$Curr_Elect_Time")"
echo "Next elections time start: $Next_Elect_Time / $(GET_F_T "$Next_Elect_Time")"
echo "-------------------------------------------------------------------"

#===================================================
OS_SYSTEM=`uname -s`
FB_CT_HEADER=""
if [[ "$OS_SYSTEM" == "FreeBSD" ]];then

CRONT_JOBS=$(cat <<-_ENDCRN_
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin:$NODE_BIN_DIR
HOME=$USER_HOME
$NXT_ELECT_1 * * *    cd ${SCRIPT_DIR} && ./prepare_elections.sh &>> ${TON_LOG_DIR}/validator.log
$NXT_ELECT_2 * * *    cd ${SCRIPT_DIR} && ./take_part_in_elections.sh &>> ${TON_LOG_DIR}/validator.log
$NXT_ELECT_3 * * *    cd ${SCRIPT_DIR} && ./next_elect_set_time.sh &>> ${TON_LOG_DIR}/validator.log && ./part_check.sh &>> ${TON_LOG_DIR}/validator.log
$NODE_UPDATE_TIME * *    cd ${SCRIPT_DIR} && ./Update_ALL.sh &>> ${TON_LOG_DIR}/validator.log
# $GPL_TIME_MH * * *    cd ${SCRIPT_DIR} && ./get_participant_list.sh > ${ELECTIONS_HISTORY_DIR}/${election_id}_parts.lst && chmod 444 ${ELECTIONS_HISTORY_DIR}/${election_id}_parts.lst
_ENDCRN_
)

else

CRONT_JOBS=$(cat <<-_ENDCRN_
SHELL=/bin/bash
PATH=$NODE_BIN_DIR:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin
HOME=$USER_HOME
$NXT_ELECT_1 * * *    cd ${SCRIPT_DIR} && ./prepare_elections.sh &>> ${TON_LOG_DIR}/validator.log
$NXT_ELECT_2 * * *    cd ${SCRIPT_DIR} && ./take_part_in_elections.sh &>> ${TON_LOG_DIR}/validator.log
$NXT_ELECT_3 * * *    cd ${SCRIPT_DIR} && ./next_elect_set_time.sh &>> ${TON_LOG_DIR}/validator.log && ./part_check.sh &>> ${TON_LOG_DIR}/validator.log
$NODE_UPDATE_TIME * *    cd ${SCRIPT_DIR} && ./Update_ALL.sh &>> ${TON_LOG_DIR}/validator.log
# $GPL_TIME_MH * * *    script --return --quiet --append --command "cd ${SCRIPT_DIR} && ./get_participant_list.sh > ${ELECTIONS_HISTORY_DIR}/${election_id}_parts.lst && chmod 444 ${ELECTIONS_HISTORY_DIR}/${election_id}_parts.lst"
_ENDCRN_
)

fi
#===================================================

[[ "$1" == "show" ]] && echo "$CRONT_JOBS"&& exit 0

echo "$CRONT_JOBS" | sudo crontab -u $SCRPT_USER -

sudo crontab -l -u $SCRPT_USER | tail -n 8

#=================================================
# for icinga
echo "# prepare , participation , next elections ( minute hour ) - for crontab" > "${nextElections}"
echo "INFO ELECTIONS
$NXT_ELECT_1
$NXT_ELECT_2
$NXT_ELECT_3
" >> "${nextElections}"

echo "-------------------------------------------------------------------"

echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date)"
echo "================================================================================================"

exit 0

