#!/usr/bin/env bash

# (C) Sergey Tyurin  2021-09-24 10:00:00

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

function show_usage(){
echo
echo " Use: ./Prep-Msig.sh <Wallet name> <'Safe' or 'SetCode'> <Num of custodians> [<workchain>]"
echo " All fields required!"
echo "<Wallet Name> - name of wallet. use \$HOSTNAME for main validator wallet"
echo "<'Safe' or 'SetCode'> - SafeCode or SetCode multisig wallet"
echo "<num of custodians> must greater 0 or less 32"
echo "<workchain> - workchain to deploy wallet. NODE_WC or '-1' "
echo
echo "All files will be saved in $KEY_FILES_DIR"
echo "if you have file '<Wallet name>_1.keys.json' with seed phrase in this dir - it will used to generate address"
echo "if you have such files (..._2..., ..._3... etc) for each custodian, it will use for key pairs generation respectively"
echo
echo " Example: ./Prep-Msig.sh MyWal Safe 5 0"
echo
exit 1
}

[[ $# -lt 3 ]] && show_usage

SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/functions.shinc"

CodeOfWallet=$2
if [[ ! $CodeOfWallet == "Safe" ]] && [[ ! $CodeOfWallet == "SetCode" ]];then
    echo "###-ERROR(line $LINENO): Wrong code of wallet. Choose 'Safe' or 'SetCode'"
    show_usage
    exit 1
fi
CUSTODIANS=$3
if [[ $CUSTODIANS -lt 1 ]] || [[ $CUSTODIANS -gt 32 ]];then
    echo "###-ERROR(line $LINENO): Wrong Num of custodians must be >= 1 and <= 31"  
    show_usage
    exit 1
fi
WorkChain=${4:-0}
# if [[ "$WorkChain" != "-1" ]] && [[ "$WorkChain" != "0" ]];then
#     echo "###-ERROR(line $LINENO): Wrong workchain. Choose '0' or '-1'"
#     show_usage
#     exit 1
# fi

WAL_NAME=$1
KEY_FILES_DIR="$HOME/MSKeys_${WAL_NAME}"

[[ ! -d $KEY_FILES_DIR ]] && mkdir $KEY_FILES_DIR

Wallet_Code=${SafeSCs_DIR}/SafeMultisigWallet.tvc
Wallet_ABI=${SafeSCs_DIR}/SafeMultisigWallet.abi.json
if [[ "$CodeOfWallet" == "SetCode" ]];then
    Wallet_Code=${SetSCs_DIR}/SetcodeMultisigWallet.tvc
    Wallet_ABI=${SetSCs_DIR}/SetcodeMultisigWallet.abi.json
fi
if [[ ! -f $Wallet_Code ]] || [[ ! -f $Wallet_ABI ]];then
    echo "###-ERROR(line $LINENO): Can not find Wallet code or ABI. Check contracts folder."  
    show_usage
    exit 1
fi
echo "Wallet Code: $Wallet_Code"
echo "ABI for wallet: $Wallet_ABI"

#=======================================================================================
# generation cycle
for (( i=1; i <= $((CUSTODIANS)); i++ ))
do
    echo "$i"
    
    # generate or read seed phrases
    [[ ! -f ${KEY_FILES_DIR}/${WAL_NAME}_seed_${i}.txt ]] && SeedPhrase=`$CALL_TC genphrase | grep "Seed phrase:" | cut -d' ' -f3-14 | tee ${KEY_FILES_DIR}/${WAL_NAME}_seed_${i}.txt`
    [[ -f ${KEY_FILES_DIR}/${WAL_NAME}_seed_${i}.txt ]] && SeedPhrase=`cat ${KEY_FILES_DIR}/${WAL_NAME}_seed_${i}.txt`
    SeedPhrase=$(echo $SeedPhrase | tr -d '"')
    
    # generate public key
    PubKey=`$CALL_TC genpubkey "$SeedPhrase" | tee ${KEY_FILES_DIR}/${WAL_NAME}_PubKeyCard_${i}.txt | grep "Public key:" | awk '{print $3}' | tee ${KEY_FILES_DIR}/${WAL_NAME}_pub_${i}_.key`
    echo "PubKey${i}: $PubKey"
    
    # generate pub/sec keypair file
    $CALL_TC getkeypair "${KEY_FILES_DIR}/${WAL_NAME}_${i}.keys.json" "$SeedPhrase" &> /dev/null
done

cp -f "${KEY_FILES_DIR}/${WAL_NAME}_1.keys.json" "${KEY_FILES_DIR}/${WAL_NAME}.keys.json"

#=======================================================================================
# generate multisignature wallet address
WalletAddress=`$CALL_TC genaddr $Wallet_Code $Wallet_ABI \
		--setkey "${KEY_FILES_DIR}/${WAL_NAME}_1.keys.json" \
        --wc "$WorkChain" \
		| tee  ${KEY_FILES_DIR}/${WAL_NAME}_addr-card.txt \
		| grep "Raw address:" | awk '{print $3}' \
		| tee ${KEY_FILES_DIR}/${WAL_NAME}.addr`

echo
echo "All files saved in $KEY_FILES_DIR"
echo
echo "Wallet Address: $WalletAddress"

if [[ ! -f ${KEYS_DIR}/${WAL_NAME}.addr ]];then
    [[ ! -f "${KEYS_DIR}/${WAL_NAME}.addr" ]] && cp "${KEY_FILES_DIR}/${WAL_NAME}.addr" ${KEYS_DIR}/
    [[ ! -f "${KEYS_DIR}/${WAL_NAME}.keys.json" ]] && cp "${KEY_FILES_DIR}/${WAL_NAME}.keys.json" ${KEYS_DIR}/
    for (( i=1; i <= $((CUSTODIANS)); i++ ))
    do
        [[ ! -f "${KEYS_DIR}/${WAL_NAME}_${i}.keys.json" ]] && cp "${KEY_FILES_DIR}/${WAL_NAME}_${i}.keys.json" ${KEYS_DIR}/
    done
    echo "MSIG files ${WAL_NAME}.addr & ${WAL_NAME}_*.keys.json copied to ${KEYS_DIR}/"
fi
echo "If you want to replace exist wallet, you need to delete all files in ${KEY_FILES_DIR}/ and ${WAL_NAME}.addr & ${WAL_NAME}_*.keys.json in ${KEYS_DIR}/ folder"
echo
echo "To deploy wallet, send tokens to it address and use MS-Wallet_deploy.sh script"
echo
echo -e "${BoldText}${RedBack} Save all seed phrases!! ${NormText} from '${WAL_NAME}_seed_*.txt' files in ${KEY_FILES_DIR}/"
echo

exit 0
