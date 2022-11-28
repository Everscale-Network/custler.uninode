#!/usr/bin/env bash

# (C) Sergey Tyurin  2022-06-10 18:00:00

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
echo "################################### Update RNODE Script ########################################"
echo "INFO: $(basename "$0") BEGIN $(date +%s) / $(date  +'%F %T %Z')"

SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/functions.shinc"

#===========================================================
# Check github for new node release
Node_local_commit="$(git --git-dir="$RNODE_SRC_DIR/.git" rev-parse HEAD 2>/dev/null)"
Node_remote_commit="$(git --git-dir="$RNODE_SRC_DIR/.git" ls-remote 2>/dev/null | grep 'HEAD'|awk '{print $1}')"
Node_bin_commit="$(rnode -V | grep 'NODE git commit' | awk '{print $5}')"

# if settled certain commit (not master) in env.sh 
[[ "${RNODE_GIT_COMMIT}" != "master" ]] && Node_remote_commit="${RNODE_GIT_COMMIT}"

if [[ -z $Node_local_commit ]];then
    echo "###-ERROR(line $LINENO): Cannot get LOCAL node commit!"
    exit 1
fi
if [[ -z $Node_remote_commit ]];then
    echo "###-ERROR(line $LINENO): Cannot get REMOTE node commit!"
    exit 1
fi
if [[ "$Node_bin_commit" !=  "$Node_local_commit" ]];then
    "###-WARNING(line $LINENO): Commit from binary file is not equal git dir commit ($RNODE_SRC_DIR)"
fi

#===========================================================
# Update FreeBSD daemon script to avoide node service stuck
if [[ "$OS_SYSTEM" == "FreeBSD" ]];then
    ${SCRIPT_DIR}/setup_as_service.sh
fi

#===========================================================
# check LNIC for new update and times
LNIC_present=false
Console_commit="$RCONS_GIT_COMMIT"
LNI_Info="$( get_LastNodeInfo )"
if [[ "$(echo "$LNI_Info"|tail -n 1)" ==  "none" ]];then
    echo "###-WARNING(line $LINENO): Last node info from contract is empty."
else
    export LNIC_present=true
    export Node_remote_commit=$(echo ${LNI_Info} | jq -r '.LastCommit')
    export Console_commit=$(echo ${LNI_Info} | jq -r '.ConsoleCommit')
    echo "LNIC present. New node commit: $Node_remote_commit, Console commit: $Console_commit"
fi

#===========================================================
# Checking node need update
if [[ "$Node_local_commit" == "$Node_remote_commit" ]];then
    echo "---INFO: The Node seems is up to date, but possible you have to update scripts..."
    echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date  +'%F %T %Z')"
    echo "================================================================================================"
    exit 0
fi

#===========================================================
# Checking if update is scheduled in LNIC
# if UpdateDuration == 0 just doing update now
# if no, check schedule
if $LNIC_present;then
    declare -i UpdateStartTime=$(echo "$LNI_Info" | jq -r '.UpdateStartTime')
    declare -i CurrTime=$(date +%s)
    if [[ $UpdateStartTime -gt $CurrTime ]];then
        echo "###-ERROR(line $LINENO): Update time is not come yet. Net nodes updates will start from $(TD_unix2human $UpdateStartTime)"
        echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date  +'%F %T %Z')"
        echo "================================================================================================"
        exit 0
    fi
    declare -i UpdateDuration=$(echo "$LNI_Info" | jq -r '.UpdateDuration')
    Validator_addr=`cat ${KEYS_DIR}/${VALIDATOR_NAME}.addr`
    declare -i Validator_Upd_Ord=$(( $(hex2dec "$(echo $Validator_addr|cut -c 33,34)") ))
    declare -i CurrNodeUpdateTime=$((UpdateDuration / 256 * Validator_Upd_Ord + UpdateStartTime))
    if [[ $CurrNodeUpdateTime -gt $CurrTime ]];then
        echo "###-ERROR(line $LINENO): Update time for your node is not come yet. Your node update time is $(TD_unix2human $CurrNodeUpdateTime)"
        echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date  +'%F %T %Z')"
        echo "================================================================================================"
        exit 0
    fi

    # set new commits in env.sh for Nodes_Build script
    sed -i.bak "s/export RNODE_GIT_COMMIT=.*/export RNODE_GIT_COMMIT=$Node_remote_commit/" "${SCRIPT_DIR}/env.sh"
    # sed -i.bak "/ton-labs-node.git/,/\"NETWORK_TYPE\" == \"rfld.ton.dev\"/ s/export RNODE_GIT_COMMIT=.*/export RNODE_GIT_COMMIT=\"$Node_remote_commit\"/" "${SCRIPT_DIR}/env.sh"
    sed -i.bak "s/export RCONS_GIT_COMMIT=.*/export RCONS_GIT_COMMIT=$Console_commit/" "${SCRIPT_DIR}/env.sh"
fi

echo "INFO: Node going to update from $Node_local_commit to new commit $Node_remote_commit"
"${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "$Tg_Warn_sign INFO: Node going to update from $Node_local_commit to new commit $Node_remote_commit" 2>&1 > /dev/null

#===========================================================
# Get recommended Rust version from node repo
Node_Build_Rust_Version="$(curl https://raw.githubusercontent.com/tonlabs/ton-labs-node/master/recomended_rust 2>/dev/null)"
V1=$(echo $Node_Build_Rust_Version|awk -F'.' '{print $1}')
V2=$(echo $Node_Build_Rust_Version|awk -F'.' '{print $2}')
V3=$(echo $Node_Build_Rust_Version|awk -F'.' '{print $3}')
if [[ $V1 =~ ^[[:digit:]]+$ ]] && [[ $V2 =~ ^[[:digit:]]+$ ]] && [[ $V3 =~ ^[[:digit:]]+$ ]];then
    declare -i Rust_Version_NUM=$(echo "$Node_Build_Rust_Version" | awk -F'.' '{printf("%d%03d%03d\n", $1,$2,$3)}')
    if [[ $Rust_Version_NUM -ne 0 ]];then
        sed -i.bak "s/export RUST_VERSION=.*/export RUST_VERSION=$Node_Build_Rust_Version/" "${SCRIPT_DIR}/env.sh"
        source "${SCRIPT_DIR}/env.sh"
    fi
fi

# --features "compression,external_db,metrics"
export RNODE_FEATURES=""
#===========================================================
# Update Node, node console, tonos-cli and contracts

#################################
${SCRIPT_DIR}/Nodes_Build.sh rust
#################################

if [[ $? -gt 0 ]];then
    echo "###-ERROR(line $LINENO): Build update filed!"
    "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "$Tg_SOS_sign ###-ERROR(line $LINENO): Node update filed!! Check ${NODE_LOGS_ARCH}/NodeUpdate.log for details." 2>&1 > /dev/null
    exit 1
fi

Node_local_repo_commit="$(git --git-dir="$RNODE_SRC_DIR/.git" rev-parse HEAD 2>/dev/null)"
Node_commit_from_bin="$(rnode -V | grep 'TON NODE git commit' | awk '{print $5}')"
if [[ "${Node_local_repo_commit}" != "${Node_commit_from_bin}" ]];then
    echo "###-ERROR(line $LINENO): Build update filed! Repo commit (${Node_local_repo_commit}) not equal commit from binary (${Node_commit_from_bin})."
    "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "$Tg_SOS_sign ###-ERROR(line $LINENO): Build update filed! Repo commit (${Node_local_repo_commit}) not equal commit from binary ${Node_commit_from_bin}." 2>&1 > /dev/null
    exit 1
fi

#===========================================================
#  Update network global config
${SCRIPT_DIR}/nets_config_update.sh

#===========================================================
# Restart service
sudo service $ServiceName restart

if [[ -z "$(pgrep rnode)" ]];then
    echo "###-ERROR(line $LINENO): Node process not started!"
    "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "$Tg_SOS_sign ###-ERROR(line $LINENO): Node process not started!" 2>&1 > /dev/null
    exit 1
fi
${SCRIPT_DIR}/wait_for_sync.sh
#===========================================================
# Check and show the Node version
EverNode_Version="$(${NODE_BIN_DIR}/rnode -V | grep -i 'TON Node, version' | awk '{print $4}')"
NodeSupBlkVer="$(rnode -V | grep 'Node block version' | awk '{print $4}')"
Console_Version="$(${NODE_BIN_DIR}/console -V | awk '{print $2}')"
TonosCLI_Version="$(${NODE_BIN_DIR}/tonos-cli -V | grep -i 'tonos_cli' | awk '{print $2}')"
echo "INFO: Node updated. Service restarted. Current versions: node ver: ${EverNode_Version} SupBlock: ${NodeSupBlkVer} node commit: ${Node_commit_from_bin}, console - ${Console_Version}, tonos-cli - ${TonosCLI_Version}"
"${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "$Tg_CheckMark INFO: Node updated. Service restarted. Current versions: node ver: ${EverNode_Version} node commit: ${Node_commit_from_bin}, console - ${Console_Version}, tonos-cli - ${TonosCLI_Version}" 2>&1 > /dev/null

#===========================================================
#
# ${SCRIPT_DIR}/DB_Repair_Actions.sh
#
#===========================================================

echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date  +'%F %T %Z')"
echo "================================================================================================"

exit 0
