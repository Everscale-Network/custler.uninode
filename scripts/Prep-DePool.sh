#!/usr/bin/env bash

# (C) Sergey Tyurin  2022-04-22 10:00:00

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
echo "################################# DePool generate address script ############################"
echo "+++INFO: $(basename "$0") BEGIN $(date +%s) / $(date)"

echo
KEY_FILES_DIR="$HOME/DPKeys_${HOSTNAME}"

function show_usage(){
echo
echo " Use: ./Prep-DePool.sh "
echo " All files will be saved in $KEY_FILES_DIR"
echo
exit 1
}

SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/functions.shinc"
##############
Depool_WC=0
##############

OS_SYSTEM=`uname`
if [[ "$OS_SYSTEM" == "Linux" ]];then
        GetMD5="md5sum --tag"
else
        GetMD5="md5"
fi

WAL_NAME="depool"
[[ ! -d $KEY_FILES_DIR ]] && mkdir -p $KEY_FILES_DIR

Depool_Code=${DSCs_DIR}/DePool.tvc
Depool_ABI=${DSCs_DIR}/DePool.abi.json
if [[ ! -f $Depool_Code ]] || [[ ! -f $Depool_ABI ]];then
    echo "###-ERROR(line $LINENO): Can not find Depool code or ABI. Check contracts folder."  
    exit 1
fi
DePoolMD5=$($GetMD5 ${DSCs_DIR}/DePool.tvc |awk '{print $4}')
echo "Depool Code: $Depool_Code"
echo "Depool ABI : $Depool_ABI"
echo "Depool MD5 : $DePoolMD5"

#=======================================================================================
# generate files

#----------------------------------------------------------    
# generate or read seed phrases
if [[ ! -f ${KEY_FILES_DIR}/depool_seed.txt ]];then
    SeedPhrase=`$CALL_TC genphrase | grep "Seed phrase:" | cut -d' ' -f3-14 | tee ${KEY_FILES_DIR}/depool_seed.txt`
else 
    SeedPhrase=`cat ${KEY_FILES_DIR}/depool_seed.txt`
fi
SeedPhrase=$(echo $SeedPhrase | tr -d '"')

if [[ -z $SeedPhrase ]];then
    echo "###-ERROR(line $LINENO): Can not generate seed phrase."
    echo
    exit 1
fi
echo "Seed phrase saved to ${KEY_FILES_DIR}/depool_seed.txt"

#----------------------------------------------------------    
# generate public key
PubKey=`$CALL_TC genpubkey "$SeedPhrase" | tee ${KEY_FILES_DIR}/depool_PubKeyCard.txt | grep "Public key:" | awk '{print $3}' | tee ${KEY_FILES_DIR}/depool_pub.key`
if [[ -z $PubKey ]];then
    echo "###-ERROR(line $LINENO): Can not generate PubKey."
    echo
    exit 1
fi
echo "PubKey: $PubKey"
echo "Public Key saved to ${KEY_FILES_DIR}/depool_pub.txt"

#----------------------------------------------------------    
# generate pub/sec keypair file
$CALL_TC getkeypair "${KEY_FILES_DIR}/depool.keys.json" "$SeedPhrase" &> /dev/null

key_public=`cat ${KEY_FILES_DIR}/depool.keys.json | jq ".public" | tr -d '"'`
key_secret=`cat ${KEY_FILES_DIR}/depool.keys.json | jq ".secret" | tr -d '"'`
if [[ -z $key_public ]] || [[ -z $key_secret ]];then
    echo "###-ERROR(line $LINENO): Error generating keypair file!"
    exit 1
fi
echo "Key pair file saved to ${KEY_FILES_DIR}/depool.keys.json"

Validator_addr=`cat ${KEYS_DIR}/${HOSTNAME}.addr`
[[ -z $Validator_addr ]] && echo "###-ERROR(line $LINENO): Validator address not found in ${KEYS_DIR}/${HOSTNAME}.addr" && exit 1
Validator_WC=${Validator_addr%%:*}
if [[ "$Depool_WC" != "$Validator_WC" ]];then
    echo "###-WARNING(line $LINENO): Validator address WC is not equal Node WC"
fi
#=======================================================================================
# generate depool address
DepoolAddress=`$CALL_TC genaddr $Depool_Code --abi $Depool_ABI \
		--setkey "${KEY_FILES_DIR}/depool.keys.json" --wc "$Depool_WC" \
		| tee  ${KEY_FILES_DIR}/depool_addr-card.txt \
		| grep "Raw address:" | awk '{print $3}' \
		| tee ${KEY_FILES_DIR}/depool.addr`

echo "================================================================================================"
echo
echo "All files saved in $KEY_FILES_DIR"
echo
echo "Depool Address: $DepoolAddress"

if [[ ! -f ${KEYS_DIR}/depool.addr ]];then
    [[ ! -f "${KEYS_DIR}/depool.addr" ]] && cp "${KEY_FILES_DIR}/depool.addr" ${KEYS_DIR}/
    [[ ! -f "${KEYS_DIR}/depool.keys.json" ]] && cp "${KEY_FILES_DIR}/depool.keys.json" ${KEYS_DIR}/
    echo "DePool files 'depool.addr' & 'depool.keys.json' copied to ${KEYS_DIR}/"
fi

echo "If you want to replace exist depool, you need to delete all files in ${KEY_FILES_DIR}/ and 'depool.addr' & 'depool.keys.json' in ${KEYS_DIR}/ folder"
echo
echo -e "${BoldText}${RedBack} Save DePool seed phrase!! ${NormText} from 'depool_seed.txt' file in ${KEY_FILES_DIR}/"
echo
echo "To deploy Depool, send 50 tokens to this address and use 'DP5_depool_deploy.sh' script"
echo -e "${BoldText}${GreeBack}### NB! ### Do not forget to change Depool parameters at the beginning of 'DP5_depool_deploy.sh' script${NormText}"
echo
echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date)"
echo "================================================================================================"

exit 0
