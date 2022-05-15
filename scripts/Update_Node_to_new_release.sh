#!/usr/bin/env bash

# (C) Sergey Tyurin  2022-05-15 10:00:00

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

SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
source "${SCRIPT_DIR}/env.sh"

################################################################################################
# NB! This update script will work correctly only if RNODE_GIT_COMMIT="master" in env.sh  ! ! !
# In other case, you have to update node manually ! ! !
################################################################################################

if [[ "$RNODE_GIT_COMMIT" != "master" ]];then
    echo "###-ERROR(line $LINENO): RNODE_GIT_COMMIT != master . You have to check & update node manually!"
fi

#===========================================================
# Check github for new node release
Node_local_commit="$(git --git-dir="$RNODE_SRC_DIR/.git" rev-parse HEAD 2>/dev/null)"
Node_remote_commit="$(git --git-dir="$RNODE_SRC_DIR/.git" ls-remote 2>/dev/null | grep 'HEAD'|awk '{print $1}')"

if [[ -z $Node_local_commit ]];then
    echo "###-ERROR(line $LINENO): Cannot get LOCAL node commit!"
    exit 1
fi
if [[ -z $Node_remote_commit ]];then
    echo "###-ERROR(line $LINENO): Cannot get REMOTE node commit!"
    exit 1
fi

if [[ "$Node_local_commit" == "$Node_remote_commit" ]];then
    echo "---INFO: The Node is up to date"
    exit 0
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
#===========================================================
# Update Node, node console, tonos-cli and contracts

#################################
${SCRIPT_DIR}/Nodes_Build.sh rust
#################################

if [[ $? -gt 0 ]];then
    echo "###-ERROR(line $LINENO): Build update filed!"
    "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "$Tg_SOS_sign ###-ERROR(line $LINENO): Node update filed!! Check '/var/ton-work/validator.log' for details." 2>&1 > /dev/null
    exit 1
fi

#===========================================================
# Restart service
sudo service tonnode restart

if [[ -z "$(pgrep rnode)" ]];then
    echo "###-ERROR(line $LINENO): Node process not started!"
    "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "$Tg_SOS_sign ###-ERROR(line $LINENO): Node process not started!" 2>&1 > /dev/null
    exit 1
fi

#===========================================================
# Check and show the Node version
EverNode_Version="$(${NODE_BIN_DIR}/rnode -V | grep -i 'version' | awk '{print $4}')"
Console_Version="$(${NODE_BIN_DIR}/console -V | awk '{print $2}')"
TonosCLI_Version="$(${NODE_BIN_DIR}/tonos-cli -V | grep -i 'tonos_cli' | awk '{print $2}')"
echo "INFO: Node updated. Service restarted. Current version: node - ${EverNode_Version}, console - ${Console_Version}, tonos-cli - ${TonosCLI_Version}"
"${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "$Tg_CheckMark INFO: Node updated. Service restarted. Current version: node - ${EverNode_Version}, console - ${Console_Version}, tonos-cli - ${TonosCLI_Version}" 2>&1 > /dev/null

exit 0
