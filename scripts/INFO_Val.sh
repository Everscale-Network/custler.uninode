#!/usr/bin/env bash

# (C) Sergey Tyurin  2022-06-19 11:00:00

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
echo "############################# Check Validators Block Version ###################################"
echo "+++INFO: $(basename "$0") BEGIN $(date +%s) / $(date  +'%F %T %Z')"

#===========================================
# Get validator list from P36 during elections

elector_addr="$(Get_Elector_Address)"
declare -i elections_id=$(Get_Current_Elections_ID)
NetConfigP15="$(Get_NetConfig_P15)"
declare -i EndBefore=$(echo $NetConfigP15|awk '{print $3}')
declare -i CurrTime=$(date +%s)

while true; do

    # wait for elections
    echo "$(date  +'%F %T %Z') - Wait for elections start"
    while true; do
        elections_id=$(Get_Current_Elections_ID)
        if [[ $elections_id -gt 0 ]];then
            echo "$(date  +'%F %T %Z') - Elections #$elections_id started"
            break
        fi
        sleep 30
    done
    echo "INFO: Current Election ID: ${elections_id}"

    echo "Now going to cycle to get validators info until elections closed"
    while true; do
        CurrTime=$(date +%s)
        elections_id=$(Get_Current_Elections_ID)
        if [[ $CurrTime -le $((elections_id - EndBefore - 120)) ]];then
            Last_elections=$elections_id
            Elector_Parts_List="$($CALL_TC -j runget ${elector_addr} participant_list_extended)"
            echo "$Elector_Parts_List" |jq '.value4'|grep -v '\[\|\]'|tr -d ' '|tr -d ','|tr -d '"'|sed 's/^0x//'  > ${ELECTIONS_HISTORY_DIR}/${elections_id}_val_list.txt
        else
            break
        fi
        sleep 30
    done

    readarray -t val_array < ${ELECTIONS_HISTORY_DIR}/${Last_elections}_val_list.txt
    declare -i val_qty=$(( ${#val_array[@]} / 5))

    Val_json="{}"

    for (( i=0; i < val_qty; i++ )); do
        val_pubkey="${val_array[$((i*5))]}"
        val_stake_nt="${val_array[$((i*5+1))]}"
        val_maxft="${val_array[$((i*5+2))]}"
        val_addr="${val_array[$((i*5+3))]}"
        val_ADNL="${val_array[$((i*5+4))]}"
        Val_json=$( echo "${Val_json}" | jq " .\"${val_addr}\".addr = \"${val_addr}\" | .\"${val_addr}\".pubkey = \"${val_pubkey}\" | .\"${val_addr}\".stake_nt = \"${val_stake_nt}\" | .\"${val_addr}\".maxft = \"${val_maxft}\" | .\"${val_addr}\".ADNL = \"${val_ADNL}\" " )
    done
    echo "$Val_json" > ${ELECTIONS_HISTORY_DIR}/${Last_elections}_Validators_List.json

    echo "INFO: Found validators in elector: $val_qty"

    SafeC_Hash="80d6c47c4a25543c9b397b71716f3fae1e2c5d247174c52e2c19bd896442b105"
    Proxy_Hash="c05938cde3cee21141caacc9e88d3b8f2a4a4bc3968cb3d455d83cd0498d4375"
    DepoolHash="14e20e304f53e6da152eb95fffc993dbd28245a775d847eed043f7c78a503885"
    Proxy_V2_hash="481d7f583b458a1672ee602f66e8aa8d2f99d3cd9ece2eaa20e25c7ddf4c7f4a"
    Depool_V2_hash="a46c6872712ec49e481a7f3fc1f42469d8bd6ef3fae906aa5b9927e5a3fb3b6b"

    Validators_List=$(cat ${ELECTIONS_HISTORY_DIR}/${Last_elections}_Validators_List.json|jq)
    Val_MSIG_List=$Validators_List

    echo "INFO: Collect validator addresses... "

    for (( i=0; i < val_qty; i++ ));do
        echo -n " $i "
        hex_val_addr="$(echo "${Validators_List}" | jq -r "[.[]][$i].addr")"
        Curr_Val_Addr="-1:${hex_val_addr}"
        Curr_Val_Addr_Hash=`curl -sS -X POST -g -H "$Auth_key_Head" -H "Content-Type: application/json" ${DApp_URL}/graphql -d '{"query": "query {accounts(filter:{id: {eq: \"'${Curr_Val_Addr}'\"}}) {code_hash}}"}' 2>/dev/null |jq -r '.data.accounts | .[].code_hash'`
        if [[ "$Curr_Val_Addr_Hash" == "$SafeC_Hash" ]];then
            Val_MSIG_List=$(echo ${Val_MSIG_List}|jq ".\"${hex_val_addr}\".MSIG = \"${Curr_Val_Addr}\" | .\"${hex_val_addr}\".depool = \"0\" | .\"${hex_val_addr}\".proxy0 = \"0\" | .\"${hex_val_addr}\".proxy1 = \"0\"")
            continue
        fi
        if [[ "$Curr_Val_Addr_Hash" == "$Proxy_Hash" ]] || [[ "$Curr_Val_Addr_Hash" == "$Proxy_V2_hash" ]];then
            CounterParty_List=`curl -sS -X POST -g -H "$Auth_key_Head" -H "Content-Type: application/json" ${DApp_URL}/graphql -d '{"query": "query {counterparties(account: \"'${Curr_Val_Addr}'\") {counterparty}}"}' 2>/dev/null | jq -r '.data.counterparties'`
            CounterParty_QTY=$(echo $CounterParty_List | jq 'length')
            for (( cpi=0; cpi < CounterParty_QTY; cpi++ ));do
                echo -n "."
                curr_acc_addr=$(echo $CounterParty_List|jq -r ".[$cpi].counterparty")
                curr_acc_hash=`curl -sS -X POST -g -H "$Auth_key_Head" -H "Content-Type: application/json" ${DApp_URL}/graphql -d '{"query": "query {accounts(filter:{id: {eq: \"'${curr_acc_addr}'\"}}) {code_hash}}"}' 2>/dev/null |jq -r '.data.accounts | .[].code_hash'`
                if [[ "$curr_acc_hash" == "$DepoolHash" ]] || [[ "$curr_acc_hash" == "$Depool_V2_hash" ]];then
                    #===========================
                    # Get depool info
                    Curr_Depool_Addr=$curr_acc_addr
                    Curr_DPinfo="$(Get_DP_Info "$Curr_Depool_Addr")"
                    dp_boc_name=$(echo "$Curr_Depool_Addr"|cut -d ":" -f 2)
                    [[ -n $dp_boc_name ]] && rm -f ${dp_boc_name}.boc
                    Owner=$(echo "$Curr_DPinfo"|jq -r '.validatorWallet')
                    curr_proxy0=$(echo "$Curr_DPinfo"|jq -r '.proxies[0]')
                    curr_proxy1=$(echo "$Curr_DPinfo"|jq -r '.proxies[1]')
                fi
            done
            Val_MSIG_List=$(echo ${Val_MSIG_List}|jq ".\"${hex_val_addr}\".MSIG = \"${Owner}\" | .\"${hex_val_addr}\".depool = \"${Curr_Depool_Addr}\" | .\"${hex_val_addr}\".proxy0 = \"${curr_proxy0}\" | .\"${hex_val_addr}\".proxy1 = \"${curr_proxy1}\"")
            continue
        fi
        echo "ALARM!!! - Found no SefeMsig or proxy address in validator: $Curr_Val_Addr"
    done
    echo "${Val_MSIG_List}" > ${ELECTIONS_HISTORY_DIR}/${Last_elections}_AddrInfo_Validators_List.json

    echo "$(date  +'%F %T %Z') - Wait for elections end"
    while true; do
        elections_id=$(Get_Current_Elections_ID)
        if [[ $elections_id -eq 0 ]];then
            echo "$(date  +'%F %T %Z') - Elections ended"
            break
        fi
        sleep 30
    done

    echo
done

echo
echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date)"
echo "================================================================================================"

exit 0

FOR b IN blocks
SORT b.gen_utime DESC
FILTER b.gen_utime > 1655613568 && b.gen_software_version < 25
COLLECT g = b.gen_software_version, c = b.created_by
RETURN { g, c }
