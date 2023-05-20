#!/usr/bin/env bash
set -eE

# (C) Sergey Tyurin  2023-03-19 10:00:00

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
echo "############################### Print net capabilities script ##################################"
echo "INFO: $(basename "$0") BEGIN $(date +%s) / $(date  +'%F %T %Z')"
# ===================================================
SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/functions.shinc"

#=================================================
echo
echo "${0##*/} Time Now: $(date  +'%F %T %Z')"
echo -e "$(DispEnvInfo)"
echo
echo -e "$(Determine_Current_Network)"
echo
#=================================================

DecodeCap=$1

if [[ -z "$DecodeCap" ]];then
    if $FORCE_USE_DAPP;then
        declare -i NetCaps=$($CALL_TC -j getconfig 8|jq -r '.capabilities' | cut -d 'x' -f 2|tr "[:lower:]" "[:upper:]"| echo $(echo $(echo "obase=10; ibase=16; `cat`" | bc)))
    else
        declare -i NetCaps=$($CALL_RC -jc 'getconfig 8'|jq -r '.p8.capabilities_dec')
    fi
else
    NetCaps=$((DecodeCap))
fi

# from https://github.com/tonlabs/ton-labs-block/blob/master/src/config_params.rs#L350
#         0 constant CapNone                    = 0x00000000,
#         1 constant CapIhrEnabled              = 0x00000001,
#         2 constant CapCreateStatsEnabled      = 0x00000002,
#         4 constant CapBounceMsgBody           = 0x00000004,
#         8 constant CapReportVersion           = 0x00000008,
#        16 constant CapSplitMergeTransactions  = 0x00000010,
#        32 constant CapShortDequeue            = 0x00000020,
#        64 constant CapMbppEnabled             = 0x00000040,
#       128 constant CapFastStorageStat         = 0x00000080,
#       256 constant CapInitCodeHash            = 0x00000100,
#       512 constant CapOffHypercube            = 0x00000200,
#      1024 constant CapMycode                  = 0x00000400,
#      2048 constant CapSetLibCode              = 0x00000800,
#      4096 constant CapFixTupleIndexBug        = 0x00001000,
#      8192 constant CapRemp                    = 0x00002000,
#     16384 constant CapDelections              = 0x00004000,
#                    CapReserved
#     65536 constant CapFullBodyInBounced       = 0x00010000,
#    131072 constant CapStorageFeeToTvm         = 0x00020000,
#    262144 constant CapCopyleft                = 0x00040000,
#    524288 constant CapIndexAccounts           = 0x00080000,
#   1048576 constant CapDiff                    = 0x00100000, // for GOSH
#   2097152 constant CapsTvmBugfixes2022        = 0x00200000, // popsave, exception handler, loops
#   4194304 constant CapWorkchains              = 0x00400000,
#   8388608 constant CapStcontNewFormat         = 0x00800000, // support old format continuation serialization
#  16777216 constant CapFastStorageStatBugfix   = 0x01000000, // calc cell datasize using fast storage stat
#  33554432 constant CapResolveMerkleCell       = 0x02000000,
#  67108864 constant CapSignatureWithId         = 0x04000000, // use some predefined id during signature check
# 134217728 constant CapBounceAfterFailedAction = 0x08000000,
# 268435456 constant CapGroth16                 = 0x10000000,
# 536870912 constant CapFeeInGasUnits           = 0x20000000, // all fees in config are in gas units
#1073741824 constant CapBigCells                = 0x40000000,
#2147483648 constant CapSuspendedList           = 0x80000000,

CapsList=(CapIhrEnabled    \
CapCreateStatsEnabled      \
CapBounceMsgBody           \
CapReportVersion           \
CapSplitMergeTransactions  \
CapShortDequeue            \
CapMbppEnabled             \
CapFastStorageStat         \
CapInitCodeHash            \
CapOffHypercube            \
CapMycode                  \
CapSetLibCode              \
CapFixTupleIndexBug        \
CapRemp                    \
CapDelections              \
CapReserved                \
CapFullBodyInBounced       \
CapStorageFeeToTvm         \
CapCopyleft                \
CapIndexAccounts           \
CapDiff                    \
CapsTvmBugfixes2022        \
CapWorkchains              \
CapStcontNewFormat         \
CapFastStorageStatBugfix   \
CapResolveMerkleCell       \
CapSignatureWithId         \
CapBounceAfterFailedAction \
CapGroth16                 \
CapFeeInGasUnits           \
CapBigCells                \
CapSuspendedList           \
)

# echo ${CapsList[@]}

declare -A DecCaps=(
[CapIhrEnabled]=1                       \
[CapCreateStatsEnabled]=2               \
[CapBounceMsgBody]=4                    \
[CapReportVersion]=8                    \
[CapSplitMergeTransactions]=16          \
[CapShortDequeue]=32                    \
[CapMbppEnabled]=64                     \
[CapFastStorageStat]=128                \
[CapInitCodeHash]=256                   \
[CapOffHypercube]=512                   \
[CapMycode]=1024                        \
[CapSetLibCode]=2048                    \
[CapFixTupleIndexBug]=4096              \
[CapRemp]=8192                          \
[CapDelections]=16384                   \
[CapReserved]=32768                     \
[CapFullBodyInBounced]=65536            \
[CapStorageFeeToTvm]=131072             \
[CapCopyleft]=262144                    \
[CapIndexAccounts]=524288               \
[CapDiff]=1048576                       \
[CapsTvmBugfixes2022]=2097152           \
[CapWorkchains]=4194304                 \
[CapStcontNewFormat]=8388608            \
[CapFastStorageStatBugfix]=16777216     \
[CapResolveMerkleCell]=33554432         \
[CapSignatureWithId]=67108864           \
[CapBounceAfterFailedAction]=134217728  \
[CapGroth16]=268435456                  \
[CapFeeInGasUnits]=536870912            \
[CapBigCells]=1073741824                \
[CapSuspendedList]=2147483648           \
)

declare -A CapsHEX=(
[CapNone]="0x00000000"
[CapIhrEnabled]="0x00000001"
[CapCreateStatsEnabled]="0x00000002"
[CapBounceMsgBody]="0x00000004"
[CapReportVersion]="0x00000008"
[CapSplitMergeTransactions]="0x00000010"
[CapShortDequeue]="0x00000020"
[CapMbppEnabled]="0x00000040"
[CapFastStorageStat]="0x00000080"
[CapInitCodeHash]="0x00000100"
[CapOffHypercube]="0x00000200"
[CapMycode]="0x00000400"
[CapSetLibCode]="0x00000800"
[CapFixTupleIndexBug]="0x00001000"
[CapRemp]="0x00002000"
[CapDelections]="0x00004000"
[CapReserved]="0x00008000"
[CapFullBodyInBounced]="0x00010000"
[CapStorageFeeToTvm]="0x00020000"
[CapCopyleft]="0x00040000"
[CapIndexAccounts]="0x00080000"
[CapDiff]="0x00100000"
[CapsTvmBugfixes2022]="0x00200000"
[CapWorkchains]="0x00400000"
[CapStcontNewFormat]="0x00800000"
[CapFastStorageStatBugfix]="0x01000000"
[CapResolveMerkleCell]="0x02000000"
[CapSignatureWithId]="0x04000000"
[CapBounceAfterFailedAction]="0x08000000"
[CapGroth16]="0x10000000"
[CapFeeInGasUnits]="0x20000000"
[1073741824]="0x40000000"
[CapSuspendedList]="0x80000000"
)
# echo ${DecCaps[@]}

declare -i Cups_sum=0
for CurCup in "${CapsList[@]}"; do
    #echo "{NetCaps}: ${NetCaps}, DecCaps: ${DecCaps[$CurCup]}"
    if [[ $((${NetCaps} & ${DecCaps[$CurCup]})) -ne 0 ]];then
        Cups_sum=$(($Cups_sum + ${DecCaps[$CurCup]}))
        echo "$(printf '%26s' "$CurCup")  $(printf '%8s' "${CapsHEX[$CurCup]}")  $(printf '%10d' "${DecCaps[$CurCup]}")  "
    fi
done
echo "-------------------------------------------"
echo "Sum from net: $(printf 0x'%X' "$NetCaps") ($NetCaps) , Calc: $(printf 0x'%X' "$Cups_sum") ($Cups_sum)"
echo
echo "=================================================================================================="
exit 0
