#!/bin/bash

# (C) Sergey Tyurin  2020-10-01 11:00:00

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

export LC_NUMERIC="C"
# ===================================================
dec2hex() {
    ival="${1^^}"
    ob=${2:-16}
    ib=${3:-10}
    OS_SYSTEM=`uname`
    if [[ "$OS_SYSTEM" == "Linux" ]];then
        export BC_LINE_LENGTH=0
        # set obase first before ibase -- or weird things happen.
        printf "obase=%d; ibase=%d; %s\n" $ob $ib $ival | bc
    else
        dc -e "64z ${ib}i ${ob}o ${ival} p" | tr -d "\\" | tr -d '\n'
    fi
}
# ===================================================
led_zer(){
    echo " "
}
# ===================================================


SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
# shellcheck source=env.sh
. "${SCRIPT_DIR}/env.sh"
OS_SYSTEM=`uname`
if [[ "$OS_SYSTEM" == "Linux" ]];then
    CALL_BC="bc"
else
    CALL_BC="bc -l"
fi

CALL_LC="${TON_BUILD_DIR}/lite-client/lite-client -p ${KEYS_DIR}/liteserver.pub -a 127.0.0.1:3031 -t 5"

##############################################################################
# get elector address
trap 'echo LC TIMEOUT EXIT' EXIT
elector_addr=`$CALL_LC -rc "getconfig 1" -rc "quit" 2>/dev/null | grep -i 'ConfigParam(1)' | awk '{print substr($4,15,64)}'`
trap - EXIT
elector_addr=`echo "-1:"$elector_addr`
echo "INFO: Elector Address: $elector_addr"

elections_id=$($CALL_LC -rc "runmethod $elector_addr active_election_id" -rc "quit" 2>/dev/null | grep "result:" | awk '{print $3}')

LC_OUTPUT="$($CALL_LC -rc "runmethodfull $elector_addr participant_list_extended" -rc "quit" 2>/dev/null)"

# public key : [ stake, max_factor, wallet (addr), adnl (adnl_addr) ]
PARTS_LIST="$(echo "$LC_OUTPUT" | tr '[' '\n' | awk 'NF>0' | grep ']]' | awk '{print$1 / 1000000000 " "$2 / 65536  " " $3 " " $4}'| sort -rn)"

echo "Participants list at $(date +'%F %T %Z')  for elections ID $elections_id : "
echo " '#'    'stake'   'mf'                                       'address'                     /                  'adnl'"
# echo "$(echo "$PARTS_LIST" | nl )"

total_stake=0
i=1
IFS=$'\n'
for str in $(echo "$PARTS_LIST")
do
stake=`echo "$str" | cut -d " " -f 1`
total_stake=$(echo "$total_stake + $stake"|bc)
mfctr=`echo "$str" |cut -d " " -f 2`
# mfctr=$((mfctr / 65536 ))
d_addr=`echo "$str" | cut -d " " -f 3 | awk '{ if(length<78) printf "%0*d%s\n",78-length,0,$0; else print }'`
h_addr='-1:'`dec2hex "$d_addr" | awk '{ if(length<64) printf "%0*d%s\n",64-length,0,$0; else print }' | tr "[:upper:]" "[:lower:]"`
d_adnl=`echo "$str" | cut -d " " -f 4 | tr -d ']]' | tr -d ')' | awk '{ if(length<78) printf "%0*d%s\n",78-length,0,$0; else print }'`
h_adnl=`dec2hex "$d_adnl" | awk '{ if(length<64) printf "%0*d%s\n",64-length,0,$0; else print }' | tr "[:upper:]" "[:lower:]"`

printf "%3d" "$i"
printf " %12.3f" "$stake"
echo " - $mfctr - $h_addr / $h_adnl"
i=$((i+1))
done
echo
echo "Total stake in elector: $total_stake"
echo "====================================================================================================================================="
