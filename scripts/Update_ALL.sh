#!/usr/bin/env bash

# (C) Sergey Tyurin  2022-02-08 19:00:00

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

################################################################################################
# NB! This update script will work correctly only if RNODE_GIT_COMMIT="master" in env.sh  ! ! !
# In other case, you have to update node manually ! ! !
################################################################################################

echo
echo "#################################### Full update Script ########################################"
echo "INFO: $(basename "$0") BEGIN $(date +%s) / $(date  +'%F %T %Z')"

SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
source "${SCRIPT_DIR}/env.sh"

[[ ! $Enable_Autoupdate ]] && exit 0
#===========================================================
# Updete scripts set
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

if [[ "$Custler_Scripts_local_commit" == "$Custler_Scripts_remote_commit" ]];then
    echo "---INFO: The Scripts is up to date"
else
    Remote_Repo_URL="$(git remote show origin | grep 'Fetch URL' | awk '{print $3}')"
    echo "INFO: Update scripts from repo $Remote_Repo_URL"

    mkdir -p ${HOME}/Custler_tmp
    cp -f ${SCRIPT_DIR}/env.sh ${HOME}/Custler_tmp/
    cp -f ${SCRIPT_DIR}/TlgChat.json ${HOME}/Custler_tmp/
    cp -f ${SCRIPT_DIR}/RC_Addr_list.json ${HOME}/Custler_tmp/

    git reset --hard
    git pull

    cp -f  ${HOME}/Custler_tmp/env.sh ${SCRIPT_DIR}/
    cp -f  ${HOME}/Custler_tmp/TlgChat.json ${SCRIPT_DIR}/
    cp -f  ${HOME}/Custler_tmp/RC_Addr_list.json ${SCRIPT_DIR}/
fi

${SCRIPT_DIR}/Update_Node_to_new_release.sh

echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date  +'%F %T %Z')"
echo "================================================================================================"

exit 0
