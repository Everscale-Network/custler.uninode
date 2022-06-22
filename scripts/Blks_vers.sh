#!/usr/bin/env bash

BlkVerList="32 31 30 29 28 27 26 25 24 22 20"
Time_Window=${1:-3600}

# Net="main"
# DApp_URL="https://${Net}.ton.dev"

FORMAT="%'4.1f"
#     2022-02-01 15:12:08 MSK Blocks in main :  0.0 / 0.0  0.0 / 0.0  0.0 / 0.0  0.0 / 0.0  0.0 / 0.0  0.0 / 0.0  34.1 /15.0  55.7 /74.9   7.0 / 6.9   1.6 / 1.0   0.0 / 0.0   1.1 / 2.2   0.0 / 0.4   1.1 / 0.1 
#echo "                         Bloks versions:     26          25          24          23          22          21          20          19 "
#echo "                         Bloks chain   :   MC / WC     MC / WC     MC / WC     MC / WC     MC / WC     MC / WC     MC / WC     MC / WC "

Header1='                         Bloks versions:     '
Header2='                         Bloks chain   :   '

for BlkVer in $BlkVerList;do
    Header1=${Header1}${BlkVer}'          '
    Header2=${Header2}'MC / WC     '
done
echo "${Header1}"
echo "${Header2}"

while true
do
    for Net in main net; do
        DApp_URL="https://${Net}.ton.dev"
        curr_time=$(date +%s)
        Time_Interval=$((curr_time - Time_Window))
        # && echo ${Time_Interval}
        Total_blks_M=`curl -sS -X POST -g -H "Content-Type: application/json" "${DApp_URL}/graphql" -d "{\"query\": \"query {aggregateBlocks(filter: {gen_utime: {gt: ${Time_Interval}}, workchain_id: {eq: -1} }) }\"}"|jq -r '.data.aggregateBlocks[0]'`
        Total_blks_W=`curl -sS -X POST -g -H "Content-Type: application/json" "${DApp_URL}/graphql" -d "{\"query\": \"query {aggregateBlocks(filter: {gen_utime: {gt: ${Time_Interval}}, workchain_id: {eq:  0} }) }\"}"|jq -r '.data.aggregateBlocks[0]'`
        echo -n "$(date  +'%F %T %Z')"
        echo -n " Blocks in $(printf "%'4s" $Net) :"

        for BlkVer in $BlkVerList; do 
            Ver_M=`curl -sS -X POST -g -H "Content-Type: application/json" "${DApp_URL}/graphql" -d "{\"query\": \"query {aggregateBlocks(filter: {gen_utime: {gt: ${Time_Interval}}, gen_software_version: {eq: $BlkVer}, workchain_id: {eq: -1} }) }\"}"|jq -r '.data.aggregateBlocks[0]'`
            Ver_W=`curl -sS -X POST -g -H "Content-Type: application/json" "${DApp_URL}/graphql" -d "{\"query\": \"query {aggregateBlocks(filter: {gen_utime: {gt: ${Time_Interval}}, gen_software_version: {eq: $BlkVer}, workchain_id: {eq:  0} }) }\"}"|jq -r '.data.aggregateBlocks[0]'`
            echo -n " $(printf $FORMAT "$(echo "$Ver_M * 100 / $Total_blks_M" | jq -nf /dev/stdin)") /$(printf $FORMAT "$(echo "$Ver_W * 100 / $Total_blks_W" | jq -nf /dev/stdin)") "
        done
        echo
    done
    echo
    sleep 60
done

exit 0
