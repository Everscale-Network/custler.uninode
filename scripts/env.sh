#!/usr/bin/env bash

# (C) Sergey Tyurin  2021-10-19 10:00:00

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
export NODE_TOP_DIR=$(cd "${SCRIPT_DIR}/../" && pwd -P)

OS_SYSTEM=`uname -s`
#=====================================================
# All nets configs folder
export CONFIGS_DIR=${NODE_TOP_DIR}/configs

#=====================================================
# Network related variables
export NETWORK_TYPE="rfld.ton.dev"      # can be main.* / net.* / fld.* / rustnet.* / rfld.*
export NODE_TYPE="RUST"                 # Can be CPP / RUST. Also defines network to build DApp fullnode with or w/o compression
export NODE_WC=0                        # Node WorkChain (for rust network)

export FORCE_USE_DAPP=false             # For offnode works or to use DApp Server instead of use node's console to operate
export STAKE_MODE="msig"                # can be 'msig' or 'depool'
export MAX_FACTOR=3

#=====================================================
# Networks endpoints
export Main_DApp_URL="https://main.ton.dev"
export MainNet_DApp_List="https://main2.ton.dev,https://main3.ton.dev,https://main4.ton.dev"

export DevNet_DApp_URL="https://net.ton.dev"
export DevNet_DApp_List="https://net1.ton.dev,https://net5.ton.dev"

export FLD_DApp_URL="https://gql.custler.net"
export FLD_DApp_List="https://gql.custler.net"

export RFLD_DApp_URL="https://rfld.custler.net"
export RFLD_DApp_List="https://rfld-dapp01.ds1.itgold.io"

export RustNet_DApp_URL="rustnet.ton.dev"
export RustNet_DApp_List="https://rustnet1.ton.dev,https://rustnet2.ton.dev"

#=====================================================
# Depool deploy defaults
export ValidatorAssuranceT=10000
export MinStakeT=10
export ParticipantRewardFraction=95
export BalanceThresholdT=20
export TIK_REPLANISH_AMOUNT=10          # If Tik acc balance less 2 tokens, It will be auto topup with this amount

#=====================================================
# Msig validation defaults
export MSIG_FIX_STAKE=45000             # fixed stake for 'msig' mode (tokens). if 0 - use whole stake
export VAL_ACC_INIT_BAL=99000           # Initial balance on validator account for full balance staking (if MSIG_FIX_STAKE=0)
export VAL_ACC_RESERVED=50              # Reserved amount staying on msig account in full staking mode

export DELAY_TIME=0                     # Delay time from the start of elections
export TIME_SHIFT=300                   # Time between sequential scripts
export LC_Send_MSG_Timeout=10           # time after Lite-Client send message to BC in seconds

#=====================================================
# FLD & RFLD free giver to grant 100k tokens
export Marvin_Addr="0:deda155da7c518f57cb664be70b9042ed54a92542769735dfb73d3eef85acdaf" 
[[ "${NETWORK_TYPE}" == "rfld.ton.dev" ]] && export Marvin_Addr="-1:deda155da7c518f57cb664be70b9042ed54a92542769735dfb73d3eef85acdaf"

#=====================================================
# Nets zeroblock IDs - first 16 syms of zeroblock hash
export MAIN_NET_ID="58FFCA1A178DAFF7"
export  DEV_NET_ID="B2E99A7505EDA599"
export  FLD_NET_ID="EA2CCBDD761FD4B5"
export RFLD_NET_ID="AA183E8917635635"
export  RST_NET_ID="228F05E8BCB11DEF"

#=====================================================
# Node addresses & ports
export HOSTNAME=$(hostname -s)
export VALIDATOR_NAME="${HOSTNAME%%.*}"

# if [[ "$OS_SYSTEM" == "Linux" ]];then
#     NODE_IP_ADDR="$(ip a|grep -w inet| grep global | awk '{print $2}' | cut -d "/" -f 1)"
# else
#     NODE_IP_ADDR="$(ifconfig -u |grep -w inet|grep -v '127.0.0.1'|head -1|awk '{print $2}')"
# fi
NODE_IP_ADDR=""
until [[ "$(echo "${NODE_IP_ADDR}" | grep "\." -o | wc -l)" -eq 3 ]]; do
    NODE_IP_ADDR="$(curl -4 icanhazip.com 2>/dev/null)"
done
export NODE_IP_ADDR

export ServiceName="tonnode"
export ADNL_PORT="48888"
export NODE_ADDRESS="${NODE_IP_ADDR}:${ADNL_PORT}"
export LITESERVER_IP="127.0.0.1"
export LITESERVER_PORT="3031"
export RCONSOLE_PORT="5031"
export VAL_ENGINE_CONSOLE_IP="127.0.0.1"
export VAL_ENGINE_CONSOLE_PORT="3030"
export C_ENGINE_ADDITIONAL_PARAMS=""

#=====================================================
# GIT addresses & commits
export RUST_VERSION="1.55.0"
export BOOST_VERSION="1.76.0"
export MIN_TC_VERSION="0.22.12"

export CNODE_GIT_REPO="https://github.com/FreeTON-Network/FreeTON-Node.git"
export CNODE_GIT_COMMIT="mainnet_patch"
[[ "$NETWORK_TYPE" == "fld.ton.dev" ]] && export CNODE_GIT_COMMIT="GROTH16"

export RNODE_GIT_REPO="https://github.com/tonlabs/ton-labs-node.git"
export RNODE_GIT_COMMIT="master"
if [[ "$NETWORK_TYPE" == "rfld.ton.dev" ]] || [[ "$NETWORK_TYPE" == "fld.ton.dev" ]];then
    export RNODE_GIT_REPO="https://github.com/NilFoundation/rust-ton.git"
    export RNODE_GIT_COMMIT="1-nil-dependencies"
fi

export RCONS_GIT_REPO="https://github.com/tonlabs/ton-labs-node-tools.git"
export RCONS_GIT_COMMIT="master"

export TONOS_CLI_GIT_REPO="https://github.com/tonlabs/tonos-cli.git"
export TONOS_CLI_GIT_COMMIT="master"

export TVM_LINKER_GIT_REPO="https://github.com/tonlabs/TVM-linker.git"
export TVM_LINKER_GIT_COMMIT="master"

export SOLC_GIT_REPO="https://github.com/tonlabs/TON-Solidity-Compiler.git"
export SOLC_GIT_COMMIT="master"

export CONTRACTS_GIT_REPO="https://github.com/tonlabs/ton-labs-contracts.git"
export CONTRACTS_GIT_COMMIT="master"

[[ "$NETWORK_TYPE" == "rustnet.ton.dev" ]] &&  export CONTRACTS_GIT_COMMIT="RUSTCUP_DEPOOL_--_DO_NOT_DEPLOY_ON_MAINNET"  # ###  RUSTCUP_DEPOOL_--_DO_NOT_DEPLOY_ON_MAINNET !!!!!!!!!!!!!

export RustCup_El_ABI_URL="https://raw.githubusercontent.com/tonlabs/rustnet.ton.dev/main/docker-compose/ton-node/configs/Elector.abi.json"
export Surf_GIT_Commit="multisig-surf-v2"

#=====================================================
# Source code folders
export TON_SRC_DIR="${NODE_TOP_DIR}/cnode"
export TON_BUILD_DIR="${TON_SRC_DIR}/build"
export TONOS_CLI_SRC_DIR="${NODE_TOP_DIR}/tonos-cli"
export UTILS_DIR="${TON_BUILD_DIR}/utils"
export RNODE_SRC_DIR="${NODE_TOP_DIR}/rnode"
export RCONS_SRC_DIR="${NODE_TOP_DIR}/rcons"
export TVM_LINKER_SRC_DIR="${NODE_TOP_DIR}/TVM_Linker"
export SOLC_SRC_DIR="${NODE_TOP_DIR}/SolC"

#=====================================================
# Work folders for db, keys and conf
export NODE_BIN_DIR=$HOME/bin
#WRK_DIR=/dev/shm   # ramdisk in linux only for fast initial sync
WRK_DIR=/var

# Keep node log files after logrotate in separate folder for X days
export NODE_LOGS_ARCH="$HOME/NodeLogs"
export NODE_LOGs_ARCH_KEEP_DAYS=5
# cnode database, configs and logs folders
export TON_WORK_DIR="$WRK_DIR/ton-work"
export TON_LOG_DIR="$WRK_DIR/ton-work"
export CNODE_LOG_FILE="node.log"
# rnode database, configs and logs folders
export RNODE_WORK_DIR="$TON_WORK_DIR/rnode"
export R_DB_DIR="$RNODE_WORK_DIR/rnode_db"
export R_LOG_DIR="$RNODE_WORK_DIR/logs"
export R_CFG_DIR="$RNODE_WORK_DIR/configs"
export RNODE_LOG_FILE="rnode.log"
# addresses, keys and elections folders
export KEYS_DIR="$HOME/ton-keys"
export ELECTIONS_WORK_DIR="${KEYS_DIR}/elections"
export ELECTIONS_HISTORY_DIR="${KEYS_DIR}/elections_hist"

export CRYPTO_DIR=$TON_SRC_DIR/crypto

#=====================================================
# Smart contracts paths
export ContractsDIR="${NODE_TOP_DIR}/ton-labs-contracts"

export DSCs_DIR="${ContractsDIR}/solidity/depool"
[[ "$NETWORK_TYPE" == "rfld.ton.dev" ]] && export DSCs_DIR="${CONFIGS_DIR}/depool_RFLD"
export DePool_ABI="$DSCs_DIR/DePool.abi.json"

export FSCs_DIR="${CRYPTO_DIR}/smartcont"
export FIFT_LIB="${CRYPTO_DIR}/fift/lib"

export SafeSCs_DIR="${ContractsDIR}/solidity/safemultisig"
export SafeC_Wallet_ABI="${ContractsDIR}/solidity/safemultisig/SafeMultisigWallet.abi.json"
export SetSCs_DIR="${ContractsDIR}/solidity/setcodemultisig"
export SetC_Wallet_ABI="${ContractsDIR}/solidity/setcodemultisig/SetcodeMultisigWallet.abi.json"
export SURF_ABI="${ContractsDIR}/Surf-contracts/solidity/setcodemultisig/SetcodeMultisigWallet.abi.json"
export SURF_TVC="${ContractsDIR}/Surf-contracts/solidity/setcodemultisig/SetcodeMultisigWallet2.tvc"

export Marvin_ABI="${CONFIGS_DIR}/Marvin.abi.json"
export Elector_ABI="${CONFIGS_DIR}/Elector.abi.json"

#=====================================================
# Executables
export CALL_RN="${NODE_BIN_DIR}/rnode --configs ${R_CFG_DIR}"
export CALL_RC="${NODE_BIN_DIR}/console -C ${R_CFG_DIR}/console.json"
export CALL_LC="${NODE_BIN_DIR}/lite-client -p ${KEYS_DIR}/liteserver.pub -a ${LITESERVER_IP}:${LITESERVER_PORT} -t 5"
export CALL_VC="${NODE_BIN_DIR}/validator-engine-console -k ${KEYS_DIR}/client -p ${KEYS_DIR}/server.pub -a ${VAL_ENGINE_CONSOLE_IP}:${VAL_ENGINE_CONSOLE_PORT} -t 5"
export CALL_VE="${NODE_BIN_DIR}/validator-engine"
export CALL_TC="${NODE_BIN_DIR}/tonos-cli -c $SCRIPT_DIR/tonos-cli.conf.json"
export CALL_FIFT="${NODE_BIN_DIR}/fift -I ${FIFT_LIB}:${FSCs_DIR}"
# export CALL_TL="$NODE_BIN_DIR/tvm_linker"

if [[ "$OS_SYSTEM" == "Linux" ]];then
    export CALL_BC="bc"
else
    export CALL_BC="bc -l"
fi

#=================================================
# Text modifiers & signs
export NormText="\e[0m"
export RedBlink="\e[5;101m"
export GreeBack="\e[42m"
export BlueBack="\e[44m"
export RedBack="\e[41m"
export YellowBack="\e[43m"
export BoldText="\e[1m"
export Tg_CheckMark=$(echo -e "\U0002705")
export Tg_SOS_sign=$(echo -e "\U0001F198")
export Tg_Warn_sign=$(echo -e "\U000026A0")

#=================================================
# var for icinga monitoring
export prepElections="${TON_LOG_DIR}/prepForElections"
export partInElections="${TON_LOG_DIR}/partInElections"
export nextElections="${TON_LOG_DIR}/nextElections"
export nodeStats="${TON_LOG_DIR}/nodeStats"

#=================================================
# File to keep changes of default variables from this file 
# to avoid reconfig after "git pull "
# you have to create this file by yourself and keep changes in it
# you can choose from presets
Net_Default_File="env_local.sh"
#Net_Default_File="env_main.sh"
#Net_Default_File="env_devnet.sh"
#Net_Default_File="env_fld.sh"
#Net_Default_File="env_rfld.sh"

if [[ -f "${SCRIPT_DIR}/${Net_Default_File}" ]]; then
    source "${SCRIPT_DIR}/${Net_Default_File}"
fi
