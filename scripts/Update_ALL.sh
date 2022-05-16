#!/usr/bin/env bash

# (C) Sergey Tyurin  2022-05-16 13:00:00

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
echo "#################################### Full update Script ########################################"
echo "INFO: $(basename "$0") BEGIN $(date +%s) / $(date  +'%F %T %Z')"

SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
source "${SCRIPT_DIR}/env.sh"

exitVar=0

shopt -s nocasematch
if [[ ! -z ${Enable_Node_Autoupdate} || -n ${Enable_Node_Autoupdate} ]]
then
    if [[ ${Enable_Node_Autoupdate} != "true" ]]
    then
        exitVar=1
    else
        myNodeAutoupdate=1
    fi
fi

if [[ ! -z ${Enable_Scripts_Autoupdate} || -n ${Enable_Scripts_Autoupdate} ]]
then
    if [[ ${Enable_Scripts_Autoupdate} != "true" ]]
    then
        exitVar=2
    else
        myScriptsAutoupdate=1
    fi
fi

if [[ ! -z ${newReleaseSndMsg} || -n ${newReleaseSndMsg} ]]
then
    if [[ ${newReleaseSndMsg} != "true" ]]
    then
        exitVar=3
    else
      myNewReleaseSndMsg=1
    fi
fi
shopt -u nocasematch

#===========================================================
# Get scripts update info
Custler_Scripts_local_commit="$(git --git-dir="${SCRIPT_DIR}/../.git" rev-parse HEAD 2>/dev/null)"
Custler_Scripts_remote_commit="$(git --git-dir="${SCRIPT_DIR}/../.git" ls-remote 2>/dev/null | grep 'HEAD'|awk '{print $1}')"

if [[ -z $Custler_Scripts_local_commit ]];then
    echo "###-ERROR(line $LINENO): Cannot get LOCAL Scripts commit!"
    exit 1
fi
if [[ -z $Custler_Scripts_remote_commit ]];then
    echo "###-ERROR(line $LINENO): Cannot get REMOTE Scripts commit!"
    exit 1
fi

###############################################################
#===========================================================
if [[ "$Custler_Scripts_local_commit" != "$Custler_Scripts_remote_commit" ]]
then
    echo '---WARN: Set Enable_Node_Autoupdate to true in env.sh for automatically security updates!! If you fully trust me, you can enable autoupdate scripts in env.sh by set variable "Enable_Scripts_Autoupdate" to "true"'
    if [[ $myNewReleaseSndMsg -eq 1 ]]
    then
        "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "$Tg_Warn_sign"+'WARN: Security info! **NEW** release arrived! But Enable_Node_Autoupdate settled to false and you should upgrade node manually as fast as you can! If you fully trust me, you can enable autoupdate scripts in env.sh by set variable "Enable_Scripts_Autoupdate" to "true"' 2>&1 > /dev/null
    fi
fi
###############################################################

#===========================================================
# Update scripts, if enabled, or send msg re update
if [[ ${myScriptsAutoupdate} -eq 1 ]]
then
    if [[ "$Custler_Scripts_local_commit" == "$Custler_Scripts_remote_commit" ]];then
        echo "---INFO: Scripts is up to date"
    else
        if $Enable_Scripts_Autoupdate ;then
            echo "---INFO: SCRIPTS going to update from $Custler_Scripts_local_commit to new commit $Custler_Scripts_remote_commit"
            if [[ $myNewReleaseSndMsg -eq 1 ]]; then
                "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "$Tg_Warn_sign INFO: SCRIPTS going to update from $Custler_Scripts_local_commit to new commit $Custler_Scripts_remote_commit" 2>&1 > /dev/null
            fi
            Remote_Repo_URL="$(git remote show origin | grep 'Fetch URL' | awk '{print $3}')"
            echo "---INFO: Update scripts from repo $Remote_Repo_URL"

            #=======================================
            # Save env.sh TlgChat.json RC_Addr_list.json before update
            mkdir -p ${HOME}/Custler_tmp
            cp -f ${SCRIPT_DIR}/env.sh ${HOME}/Custler_tmp/
            cp -f ${SCRIPT_DIR}/TlgChat.json ${HOME}/Custler_tmp/
            cp -f ${SCRIPT_DIR}/RC_Addr_list.json ${HOME}/Custler_tmp/

            git reset --hard
            git pull --ff-only

            # Restore env.sh TlgChat.json RC_Addr_list.json before update
            cp -f  ${HOME}/Custler_tmp/env.sh ${SCRIPT_DIR}/
            cp -f  ${HOME}/Custler_tmp/TlgChat.json ${SCRIPT_DIR}/
            cp -f  ${HOME}/Custler_tmp/RC_Addr_list.json ${SCRIPT_DIR}/
            #=======================================

            #################################################################
            # update env.sh to satisfy new changes in scripts
            ${SCRIPT_DIR}/Update_ENV.sh
            #################################################################

            cat ${SCRIPT_DIR}/Update_Info.txt
            echo
            echo "---INFO: SCRIPTS updated. Files env.sh TlgChat.json RC_Addr_list.json keeped."
            if [[ $myNewReleaseSndMsg -eq 1 ]]; then
                "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "$Tg_CheckMark $(cat ${SCRIPT_DIR}/Update_Info.txt)" 2>&1 > /dev/null
                "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "$Tg_CheckMark INFO: SCRIPTS updated. Files env.sh TlgChat.json RC_Addr_list.json keeped." 2>&1 > /dev/null
            fi
        else
            echo '---WARN: Scripts repo was updated. Please check it and update by hand. If you fully trust me, you can enable autoupdate scripts in env.sh by set variable "Enable_Scripts_Autoupdate" to "true"'
            if [[ $myNewReleaseSndMsg -eq 1 ]]; then
                "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "$Tg_Warn_sign"+'WARN: Scripts repo was updated. Please check it and update. If you fully trust me, you can enable autoupdate scripts in env.sh by set variable "Enable_Scripts_Autoupdate" to "true"' 2>&1 > /dev/null
            fi
        fi
    fi
fi
#===========================================================
# Update NODE
${SCRIPT_DIR}/Update_Node_to_new_release.sh

#################################################################
# NB!! This section shoul be run once only with rnode commit 8135f586aa1a536393496c21cb1acba510c3f9a9
# Deprecated - 5494f43cf80e071f6e10257ef4901568d10b2385 only

Node_local_commit="$(git --git-dir="$RNODE_SRC_DIR/.git" rev-parse HEAD 2>/dev/null)"
if [[ ! -f ${SCRIPT_DIR}/rnode_commit_8135f58_DB_Restored ]] && [[ ${Node_local_commit} == "8135f586aa1a536393496c21cb1acba510c3f9a9" ]];then
    echo "---WARN: Node going to RESTORE DataBase. It is once for commit 8135f58. Approx ONE hour the node will looks like DOWN and UNSYNCED!"
    "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "${Tg_Warn_sign}---WARN: Node going to RESTORE DataBase. It is once for commit 8135f58. Approx ONE hour the node will looks like DOWN and UNSYNCED!" 2>&1 > /dev/null
    
    #===============================
    sudo service ${ServiceName} stop
    jq ".restore_db = true" ${R_CFG_DIR}/config.json > ${R_CFG_DIR}/config.json.tmp
    mv -f ${R_CFG_DIR}/config.json.tmp ${R_CFG_DIR}/config.json
    sudo service ${ServiceName} start
    ${SCRIPT_DIR}/wait_for_sync.sh
    jq ".restore_db = false" ${R_CFG_DIR}/config.json > ${R_CFG_DIR}/config.json.tmp
    mv -f ${R_CFG_DIR}/config.json.tmp ${R_CFG_DIR}/config.json
    #===============================
    touch ${SCRIPT_DIR}/rnode_commit_8135f58_DB_Restored
    
    echo "---INFO: DB restored. Node should be SYNCED!"
    "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "${Tg_Warn_sign}---INFO: DB restored. Node should be SYNCED!" 2>&1 > /dev/null
fi
#################################################################

echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date  +'%F %T %Z')"
echo "================================================================================================"

exit 0
