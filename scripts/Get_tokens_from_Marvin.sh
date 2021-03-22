#!/bin/bash

# (C) Sergey Tyurin  2021-03-15 20:00:00

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
source "${SCRIPT_DIR}/functions.shinc"
#=================================================
echo
echo "Time Now: $(date  +'%F %T %Z')"
echo "INFO from env: Network: $NETWORK_TYPE; Node: $NODE_TYPE; Elector: $ELECTOR_TYPE"
echo
echo -e "$(Determine_Current_Network)"
echo

#===========================================================
# Check DApp server
DApp_State="$(Check_DApp_URL)"
if [[ "$DApp_State" != "fine" ]];then
    echo "###-ERROR(line $LINENO): DApp server has state: $DApp_State. Check network type in env.sh and URL in tonos-cli.conf.json"
    exit 1
fi
#===========================================================
# Check Marvin ABI
if [[ ! -f $Marvin_ABI ]];then
    echo "###-ERROR(line $LINENO): Can not find Wallet code or ABI. Check contracts folder."  
    exit 1
fi

DST_NAME=${VALIDATOR_NAME}
DST_KEY_FILE="${KEYS_DIR}/${VALIDATOR_NAME}.keys.json"

DST_ACCOUNT=`cat ${KEYS_DIR}/${DST_NAME}.addr`
if [[ -z $DST_ACCOUNT ]];then
    echo "###-ERROR(line $LINENO): Can't find SRC address! ${KEYS_DIR}/${DST_NAME}.addr"
    exit 1
fi
msig_public=`cat $DST_KEY_FILE | jq ".public"`
msig_secret=`cat $DST_KEY_FILE | jq ".secret"`
if [[ -z $msig_public ]] || [[ -z $msig_secret ]];then
    echo "###-ERROR(line $LINENO): Can't find public and/or secret key in ${DST_KEY_FILE}!"
    exit 1
fi

$CALL_TC call "$Marvin_Addr" grant "{\"addr\":\"$DST_ACCOUNT\"}" --abi "${Marvin_ABI}"

exit 0
