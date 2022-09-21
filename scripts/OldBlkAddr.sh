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
# source "${SCRIPT_DIR}/env.sh"
# source "${SCRIPT_DIR}/functions.shinc"

echo
echo "############################# Check Validators Block Version ###################################"
echo "+++INFO: $(basename "$0") BEGIN $(date +%s) / $(date  +'%F %T %Z')"
#================================================================
function TD_unix2human() {
    local OS_SYSTEM=`uname -s`
    local ival="$(echo ${1}|tr -d '"')"
    if [[ -z $ival ]]; then
        printf "###-Error: Zero Time"
        return
    fi
    if [[ "$OS_SYSTEM" == "Linux" ]];then
        echo "$(date  +'%F %T %Z' -d @$ival)"
    else
        echo "$(date -r $ival +'%F %T %Z')"
    fi
}
#================================================================
Net="main"
DApp_URL="https://${Net}.ton.dev"

ValAddrList_File="1656270478_AddrInfo_Validators_List.json"
ElectionsCycle_ID=${ValAddrList_File%%_*}

ValAddrList_json="$(cat "${ValAddrList_File}"|jq 'to_entries')"
declare -i NodesQty=$(echo "${ValAddrList_json}"|jq '.|length')

# looks for pubs with blk# 22
search_blk_ver=22
Time_Inerval=3600
Time_Start=$(($(date +%s) - Time_Inerval))

# curl -sS -X POST -g -H "Content-Type: application/json" "${DApp_URL}/graphql" -d "{\"query\": \"query {blocks(filter: {gen_utime: {gt: ${Time_Start}}, gen_software_version: {eq: $search_blk_ver} }limit: 1000) {id, created_by} }\"}"|jq '.data.blocks[].created_by'

# 'to_entries|map(.key) as $keys| (map(.value)|transpose) as $values |$values|map([$keys, .] | transpose| map( {(.[0]): .[1]} ) | add)'
# curl -sS -X POST -g -H "Content-Type: application/json" "${DApp_URL}/graphql" -d '{"query": "query {blocks(filter: { gen_utime: {gt: '$ElectionsCycle_ID'}, created_by: {eq: \"'$CurPub'\"} }limit: 10) {id, gen_software_version} }"}'
declare -i NoBlockNodes=0
declare -i OldBlockNodes=0
declare -i Blk_22=0
declare -i Blk_24=0
declare -i Blk_26=0
declare -i Blk_27=0
declare -i Blk_30=0
declare -i Custler_CU=0
declare -i Custler_MED=0
for (( i=0; i < NodesQty; i++ ));do
    CurPub=$(echo "${ValAddrList_json}"|jq -r ".[$i].value.pubkey")
    CurrNodeBlkVer=`curl -sS -X POST -g -H "Content-Type: application/json" "${DApp_URL}/graphql" -d \
    '{"query": "query {blocks(filter: { gen_utime: {gt: '$Time_Start'}, created_by: {eq: \"'$CurPub'\"} }limit: 1) {id, gen_software_version} }"}' \
    |jq '.data.blocks[0].gen_software_version'`
    Hoster=""
    ADNL_hex="$(echo "${ValAddrList_json}"|jq ".[$i].value.ADNL")"
    if [[ -n "$ADNL_hex" ]];then
        ADNL_B64="$(echo "$ADNL_hex" | xxd -r -p | base64)"
        # echo "$ADNL_hex"
        # echo "$ADNL_B64"
        IP_Port="$(timeout 30 ${HOME}/bin/adnl_resolve $ADNL_B64 ./common/config/ton-global.config.json 2>/dev/null | grep 'Found'|awk '{print $2}')"
        # $? -eq 124
        # echo "IP:port = $IP_Port"
        # timeout 5 $(IP_Port="$(${HOME}/bin/adnl_resolve $ADNL_B64 ./common/config/ton-global.config.json 2>/dev/null | grep 'Found'|awk '{print $2}')")
        # curl "http://ipwho.is/8.8.4.4"
        [[ -n "$IP_Port" ]] && Hoster="$(curl "http://ipwho.is/${IP_Port%%:*}" 2>/dev/null|jq '.connection.org , .city , .country'|tr -d "\n")"
        [[ "$(echo "$IP_Port"|awk -F':' '{print $2}')" == "48888" ]] && ((Custler_CU+=1))
        [[ "$(echo "$IP_Port"|awk -F':' '{print $2}')" == "49999" ]] && ((Custler_MED+=1))
    fi 
    if [[ $CurrNodeBlkVer -lt 30 ]] && [[ $CurrNodeBlkVer -gt 0 ]];then
        ((OldBlockNodes+=1))
        echo "------------------------------------------"
        Stake_nt=$(echo "${ValAddrList_json}"|jq -r ".[$i].value.stake_nt")
        echo "$OldBlockNodes BlkVer: $CurrNodeBlkVer Stake: $(echo $((Stake_nt / 1000000000))|LC_ALL=en_US.UTF-8 xargs printf "%'.f\n")"
        # echo "$CurPub"
        echo "MSIG:   $(echo "${ValAddrList_json}"|jq ".[$i].value.MSIG") "
        echo "DePool: $(echo "${ValAddrList_json}"|jq ".[$i].value.depool")"
        echo "IP:port = $IP_Port  $Hoster"
    fi
    [[ $CurrNodeBlkVer -eq 0 ]] && ((NoBlockNodes+=1))
    [[ $CurrNodeBlkVer -eq 22 ]] && ((Blk_22+=1))
    [[ $CurrNodeBlkVer -eq 24 ]] && ((Blk_24+=1))
    [[ $CurrNodeBlkVer -eq 26 ]] && ((Blk_26+=1))
    [[ $CurrNodeBlkVer -eq 27 ]] && ((Blk_27+=1))
    [[ $CurrNodeBlkVer -eq 30 ]] && ((Blk_30+=1))
done
echo "------------------------------------------"
echo
echo "Summary for last $((Time_Inerval / 60)) min since $(TD_unix2human $Time_Start):"
echo "Total nodes: $NodesQty"
echo " Nodes blk ver 22: $Blk_22"
echo " Nodes blk ver 24: $Blk_24"
echo " Nodes blk ver 26: $Blk_26"
echo " Nodes blk ver 27: $Blk_27"
echo " Nodes blk ver 30: $Blk_30"
echo " custler.uninode Nodes: $Custler_CU"
echo " main.evs.dev    Nodes: $Custler_MED"

echo "Total nodes in round $ElectionsCycle_ID / $(TD_unix2human $ElectionsCycle_ID) : $NodesQty"
echo "Nodes with old blocks =         $OldBlockNodes"
echo "Nodes which not made any blocks = $NoBlockNodes"
echo

echo "Nodes not make any blocks (not in MC or WC) in current round $ElectionsCycle_ID / $(TD_unix2human $ElectionsCycle_ID):  "
declare -i ZeroBlkNodes=0
for (( i=0; i < NodesQty; i++ ));do
    CurPub=$(echo "${ValAddrList_json}"|jq -r ".[$i].value.pubkey")
    CurrNodeBlkVer=`curl -sS -X POST -g -H "Content-Type: application/json" "${DApp_URL}/graphql" -d \
    '{"query": "query {blocks(filter: { gen_utime: {gt: '$ElectionsCycle_ID'}, created_by: {eq: \"'$CurPub'\"} }limit: 1) {id, gen_software_version} }"}' \
    |jq '.data.blocks[0].gen_software_version'`
    Hoster=""
    if [[ $CurrNodeBlkVer -eq 0 ]];then
        ((ZeroBlkNodes+=1))
        echo "------------------------------------------"
        Stake_nt=$(echo "${ValAddrList_json}"|jq -r ".[$i].value.stake_nt")
        echo "$ZeroBlkNodes BlkVer: $CurrNodeBlkVer Stake: $(echo $((Stake_nt / 1000000000))|LC_ALL=en_US.UTF-8 xargs printf "%'.f\n") "
        echo "MSIG:   $(echo "${ValAddrList_json}"|jq ".[$i].value.MSIG") "
        echo "DePool: $(echo "${ValAddrList_json}"|jq ".[$i].value.depool")"
        ADNL_hex="$(echo "${ValAddrList_json}"|jq ".[$i].value.ADNL")"
        if [[ -n "$ADNL_hex" ]];then
            ADNL_B64="$(echo "$ADNL_hex" | xxd -r -p | base64)"
            IP_Port="$(timeout 30 ${HOME}/bin/adnl_resolve $ADNL_B64 ./common/config/ton-global.config.json 2>/dev/null | grep 'Found'|awk '{print $2}')"
            # curl "http://ipwho.is/8.8.4.4"
            [[ -n "$IP_Port" ]] && Hoster="$(curl "http://ipwho.is/${IP_Port%%:*}" 2>/dev/null|jq '.connection.org , .city , .country'|tr -d "\n")"
        fi 
        echo "IP:port = $IP_Port  $Hoster"
    fi
done
echo "------------------------------------------"

echo
echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date)"
echo "================================================================================================"

exit 0

FOR b IN blocks
SORT b.gen_utime DESC
FILTER b.gen_utime > 1655613568 && b.gen_software_version < 25
COLLECT g = b.gen_software_version, c = b.created_by
RETURN { g, c }
#========================================
query BLK_ver_by_pubkey{
    blocks(
    filter:{
      gen_utime:{gt: 1655776517}
      created_by:{eq: "5b3fbd89262c8d479a33abb8d009c82ccaed075c18f791c01f9087f7eee35508"}
      #gen_software_version:{eq: 22}
      #workchain_id:{eq: 0}
     }
    limit: 10
  ){
    id
    gen_utime_string
    gen_software_version
 		created_by
    #signatures {signatures: }
    workchain_id
    shard
    # account_blocks
   }
}
#========================================
