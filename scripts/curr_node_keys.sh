#!/usr/bin/env bash

# (C) Sergey Tyurin  2021-02-13 12:00:00

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

echo
echo -e "$(Determine_Current_Network)"
echo
# =====================================================
Curr_Elec="$(Get_Current_Elections_ID)"
echo "Current Elections ID: $Curr_Elec"
echo

Curr_Engine_Val_Keys=`cat ${R_CFG_DIR}/config.json | jq .validator_keys`
Curr_Engine_Key_Ring=`cat ${R_CFG_DIR}/config.json | jq .validator_key_ring`
[[ "$Curr_Engine_Val_Keys" == "null" ]] && echo "No keys found" && exit 0
ADNL_0=`echo $Curr_Engine_Val_Keys | jq .[0].validator_adnl_key_id`
Elec_0=`echo $Curr_Engine_Val_Keys | jq .[0].election_id`
ADNL_1=`echo $Curr_Engine_Val_Keys | jq .[1].validator_adnl_key_id`
Elec_1=`echo $Curr_Engine_Val_Keys | jq .[1].election_id`
if [[ "$ADNL_0" == "null" ]];then
    echo "No keys found"
    exit 0 
fi
if [[ "$ADNL_1" == "null" ]];then
    Engine_ADNL=`echo $ADNL_0 | tr -d '"'|base64 -d|od -t xC -An|tr -d '\n'|tr -d ' '`
    VAL_KEY_ID="$(cat ${R_CFG_DIR}/config.json      | jq -r ".validator_keys[]|select(.election_id == $Elec_0)|.validator_key_id")"
    Engine_KEY_ID=`echo $Curr_Engine_Val_Keys       | jq -r ".[]|select(.election_id == $Elec_0)|.validator_key_id"`
    Engine_PVT_Key_B64=`echo $Curr_Engine_Key_Ring  | jq -r ".\"${Engine_KEY_ID}\".pvt_key"`
    Engine_PUBKEY=`$CALL_RC -c "exportpub $Engine_KEY_ID"|grep -i 'imported key:'`
    Engine_PUBKEY_B64=`echo $Engine_PUBKEY| awk '{print $4}'`
    Engine_PUBKEY_HEX=`echo $Engine_PUBKEY| awk '{print $3}'`

    echo "Only one keyset in engine!"
    echo "Elections ID: $Elec_0"
    echo "     Engine ADNL: $Engine_ADNL"
    echo "  Engine Pub key: $Engine_PUBKEY_HEX"
else
    Next_Engine_Elec_ID=$((Elec_0 > Elec_1 ? Elec_0 : Elec_1))
    Curr_Engine_Elec_ID=$((Elec_0 < Elec_1 ? Elec_0 : Elec_1))
    Curr_Engine_ADNL=`echo $Curr_Engine_Val_Keys | jq -r ".[]|select(.election_id == $Curr_Engine_Elec_ID)|.validator_adnl_key_id" \
        | base64 -d|od -t xC -An|tr -d '\n'|tr -d ' '`
    Next_Engine_ADNL=`echo $Curr_Engine_Val_Keys | jq -r ".[]|select(.election_id == $Next_Engine_Elec_ID)|.validator_adnl_key_id" \
        | base64 -d|od -t xC -An|tr -d '\n'|tr -d ' '`

    Curr_Engine_KEY_ID=`echo $Curr_Engine_Val_Keys      | jq -r ".[]|select(.election_id == $Curr_Engine_Elec_ID)|.validator_key_id"`
    Next_Engine_KEY_ID=`echo $Curr_Engine_Val_Keys      | jq -r ".[]|select(.election_id == $Next_Engine_Elec_ID)|.validator_key_id"`
    Curr_Engine_PVT_Key_B64=`echo $Curr_Engine_Key_Ring | jq -r ".\"${Curr_Engine_KEY_ID}\".pvt_key"`
    Next_Engine_PVT_Key_B64=`echo $Curr_Engine_Key_Ring | jq -r ".\"${Next_Engine_KEY_ID}\".pvt_key"`

    Curr_Engine_PUBKEY=`$CALL_RC -c "exportpub $Curr_Engine_KEY_ID"    | grep -i 'imported key:'`
    Curr_Engine_PUBKEY_B64=`$CALL_RC -c "exportpub $Curr_Engine_KEY_ID"| grep -i 'imported key:'| awk '{print $4}'`
    Curr_Engine_PUBKEY_HEX=`$CALL_RC -c "exportpub $Curr_Engine_KEY_ID"| grep -i 'imported key:'| awk '{print $3}'`

    Next_Engine_PUBKEY=`$CALL_RC -c "exportpub $Next_Engine_KEY_ID"|grep -i 'imported key:'`
    Next_Engine_PUBKEY_B64=`echo $Next_Engine_PUBKEY| awk '{print $4}'`
    Next_Engine_PUBKEY_HEX=`echo $Next_Engine_PUBKEY| awk '{print $3}'`

    echo "Current Elections ID: $Curr_Engine_Elec_ID"
    echo "     Engine ADNL: $Curr_Engine_ADNL"
    echo "  Engine Pub key: $Curr_Engine_PUBKEY_HEX"
    echo 
    echo "Next Elections ID: $Next_Engine_Elec_ID"
    echo "     Engine ADNL: $Next_Engine_ADNL"
    echo "  Engine Pub key: $Next_Engine_PUBKEY_HEX"
    echo "---------------------------------------------------------------------------------------------"
fi

exit 0
