#!/bin/bash -eE

BUILD_STRT_TIME=$(date +%s)
echo
echo "############################## FreeTON tonos-cli build script ##################################"
echo "+++INFO: $(basename "$0") BEGIN $(date +%s) / $(date)"

SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
source "${SCRIPT_DIR}/env.sh"

#=====================================================
# download contracts
rm -rf "${NODE_SRC_TOP_DIR}/ton-labs-contracts"
rm -rf "${NODE_SRC_TOP_DIR}/Surf-contracts"
git clone ${CONTRACTS_GIT_REPO} "${NODE_SRC_TOP_DIR}/ton-labs-contracts"
cd "${NODE_SRC_TOP_DIR}/ton-labs-contracts"
git checkout $CONTRACTS_GIT_COMMIT 
cd ${NODE_SRC_TOP_DIR}
git clone --single-branch --branch multisig-surf-v2 https://github.com/tonlabs/ton-labs-contracts.git "${NODE_SRC_TOP_DIR}/Surf-contracts"

RustCup_El_ABI_URL="https://raw.githubusercontent.com/tonlabs/rustnet.ton.dev/main/docker-compose/ton-node/configs/Elector.abi.json"
curl -o ${Elector_ABI} ${RustCup_El_ABI_URL} &>/dev/null

BUILD_END_TIME=$(date +%s)
Build_mins=$(( (BUILD_END_TIME - BUILD_STRT_TIME)/60 ))
Build_secs=$(( (BUILD_END_TIME - BUILD_STRT_TIME)%60 ))
echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date)"
echo "Builds took $Build_mins min $Build_secs secs"
echo "================================================================================================"

exit 0
