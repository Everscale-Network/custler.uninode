#!/usr/bin/env bash

BUILD_STRT_TIME=$(date +%s)
echo
echo "############################## FreeTON tonos-cli build script ##################################"
echo "+++INFO: $(basename "$0") BEGIN $(date +%s) / $(date)"

SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
source "${SCRIPT_DIR}/env.sh"

#=====================================================
# download contracts
rm -rf "${ContractsDIR}"
rm -rf "${ContractsDIR}/Surf-contracts"
git clone ${CONTRACTS_GIT_REPO} "${ContractsDIR}"
cd "${ContractsDIR}"
git checkout $CONTRACTS_GIT_COMMIT 
cd ${ContractsDIR}
git clone --single-branch --branch ${Surf_GIT_Commit} ${CONTRACTS_GIT_REPO} "${ContractsDIR}/Surf-contracts"

curl -o ${Elector_ABI} ${RustCup_El_ABI_URL} &>/dev/null

BUILD_END_TIME=$(date +%s)
Build_mins=$(( (BUILD_END_TIME - BUILD_STRT_TIME)/60 ))
Build_secs=$(( (BUILD_END_TIME - BUILD_STRT_TIME)%60 ))
echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date)"
echo "Builds took $Build_mins min $Build_secs secs"
echo "================================================================================================"

exit 0
