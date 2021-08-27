#!/bin/bash 

# (C) Sergey Tyurin  2021-08-14 22:00:00

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
export NODE_SRC_TOP_DIR=$(cd "${SCRIPT_DIR}/../" && pwd -P)

OS_SYSTEM=`uname -s`
#=====================================================
# All nets configs folder
export CONFIGS_DIR=${NODE_SRC_TOP_DIR}/configs

#=====================================================
# Network related variables
export NETWORK_TYPE="rustnet.ton.dev"   # can be main.* / net.* / fld.* / rustnet.*
export FORCE_USE_TONOSCLI=false         # NOT IMPLEMENTED YET !!! For offnode works
export STAKE_MODE="depool"              # can be 'msig' or 'depool'
export MAX_FACTOR=3

export MSIG_FIX_STAKE=45000             # fixed stake for 'msig' mode (tokens). if 0 - use whole stake
export VAL_ACC_INIT_BAL=95000           # Initial balance on validator account for full balance staking (if MSIG_FIX_STAKE=0)
export VAL_ACC_RESERVED=50              # Reserved amount staying on msig account in full staking mode

export TIK_REPLANISH_AMOUNT=5           # If Tik acc balance less 2 tokens, It will be auto topup with this amount

export LC_Send_MSG_Timeout=20           # time after Lite-Client send message to BC in seconds

export CONTRACTS_GIT_COMMIT="master"

#=====================================================
# FLD free giver to grant 100k 
export Marvin_Addr="0:deda155da7c518f57cb664be70b9042ed54a92542769735dfb73d3eef85acdaf" 
#=====================================================
# Nets zeroblock IDs - first 16 syms of zeroblock hash
export MAIN_NET_ID="58FFCA1A178DAFF7"
export  DEV_NET_ID="B2E99A7505EDA599"
export  FLD_NET_ID="EA2CCBDD761FD4B5"
export  RST_NET_ID="228F05E8BCB11DEF"

#=====================================================
# Node addresses & ports
export HOSTNAME=$(hostname -s)
export VALIDATOR_NAME="$HOSTNAME"
if [[ "$OS_SYSTEM" == "Linux" ]];then
    export NODE_IP_ADDR="$(ip a|grep -w inet| grep global | awk '{print $2}' | cut -d "/" -f 1)"
else
    export NODE_IP_ADDR="$(ifconfig -u |grep -w inet|grep -v '127.0.0.1'|head -1|awk '{print $2}')"
fi
#"$(curl -sS ipv4bot.whatismyipaddress.com)"

export ADNL_PORT="30303"
export NODE_ADDRESS="${NODE_IP_ADDR}:${ADNL_PORT}"
export LITESERVER_IP="127.0.0.1"
export LITESERVER_PORT="3031"
export RCONSOLE_PORT="3031"
export VAL_ENGINE_CONSOLE_IP="127.0.0.1"
export VAL_ENGINE_CONSOLE_PORT="3030"
export ENGINE_ADDITIONAL_PARAMS=""

#=====================================================
# GIT addresses & commits
export RUST_VERSION="1.53.0"
export BOOST_VERSION="1.76.0"
export MIN_TC_VERSION="0.17.27"
export INSTALL_DEPENDENCIES="yes"

export CNODE_GIT_REPO="https://github.com/FreeTON-Network/FreeTON-Node.git"
export CNODE_GIT_COMMIT="eae01917c1ed1bfc019d34a6c631160a86cb41eb"

export RNODE_GIT_REPO="https://github.com/tonlabs/ton-labs-node.git"
export RNODE_GIT_COMMIT="rustnet"

export RCONS_GIT_REPO="https://github.com/tonlabs/ton-labs-node-tools.git"
export RCONS_GIT_COMMIT="use-console-for-elections"

export TONOS_CLI_GIT_REPO="https://github.com/tonlabs/tonos-cli.git"
export TONOS_CLI_GIT_COMMIT="master"

export TVM_LINKER_GIT_REPO="https://github.com/tonlabs/TVM-linker.git"
export TVM_LINKER_GIT_COMMIT="master"

export SOLC_GIT_REPO="https://github.com/tonlabs/TON-Solidity-Compiler.git"
export SOLC_GIT_COMMIT="master"

export CONTRACTS_GIT_REPO="https://github.com/tonlabs/ton-labs-contracts.git"
export CONTRACTS_GIT_COMMIT="master"

[[ "$NETWORK_TYPE" == "rustnet.ton.dev" ]] &&  export CONTRACTS_GIT_COMMIT="RUSTCUP_DEPOOL_--_DO_NOT_DEPLOY_ON_MAINNET"  # ###  RUSTCUP_DEPOOL_--_DO_NOT_DEPLOY_ON_MAINNET !!!!!!!!!!!!!

#=====================================================
# Source code folders
export TON_SRC_DIR="${NODE_SRC_TOP_DIR}/cnode"
export TON_BUILD_DIR="${TON_SRC_DIR}/build"
export TONOS_CLI_SRC_DIR="${NODE_SRC_TOP_DIR}/tonos-cli"
export UTILS_DIR="${TON_BUILD_DIR}/utils"
export RNODE_SRC_DIR="${NODE_SRC_TOP_DIR}/rnode"
export RCONS_SRC_DIR="${NODE_SRC_TOP_DIR}/rcons"
export TVM_LINKER_SRC_DIR="${NODE_SRC_TOP_DIR}/TVM_Linker"
export SOLC_SRC_DIR="${NODE_SRC_TOP_DIR}/SolC"

#=====================================================
# Work folders for db, keys and conf
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

#=====================================================
# Smart contracts paths
export SafeSCs_DIR=$NODE_SRC_TOP_DIR/ton-labs-contracts/solidity/safemultisig
export SetSCs_DIR=$NODE_SRC_TOP_DIR/ton-labs-contracts/solidity/setcodemultisig
export DSCs_DIR=$NODE_SRC_TOP_DIR/ton-labs-contracts/solidity/depool
export CRYPTO_DIR=$TON_SRC_DIR/crypto
export FSCs_DIR=$CRYPTO_DIR/smartcont
export FIFT_LIB=$CRYPTO_DIR/fift/lib

export SetC_Wallet_ABI="$NODE_SRC_TOP_DIR/ton-labs-contracts/solidity/setcodemultisig/SetcodeMultisigWallet.abi.json"
export SafeC_Wallet_ABI="$NODE_SRC_TOP_DIR/ton-labs-contracts/solidity/safemultisig/SafeMultisigWallet.abi.json"
export SURF_ABI="$NODE_SRC_TOP_DIR/Surf-contracts/solidity/setcodemultisig/SetcodeMultisigWallet.abi.json"
export SURF_TVC="$NODE_SRC_TOP_DIR/Surf-contracts/solidity/setcodemultisig/SetcodeMultisigWallet2.tvc"
export Marvin_ABI="$CONFIGS_DIR/Marvin.abi.json"
export Elector_ABI="$CONFIGS_DIR/Elector.abi.json"
export DePool_ABI="$DSCs_DIR/DePool.abi.json"
#=====================================================
# Executables
export CALL_RN="$HOME/bin/rnode --configs ${R_CFG_DIR}"
export CALL_RC="$HOME/bin/console -C ${R_CFG_DIR}/console.json"
export CALL_LC="$HOME/bin/lite-client -p ${KEYS_DIR}/liteserver.pub -a ${LITESERVER_IP}:${LITESERVER_PORT} -t 5"
export CALL_VC="$HOME/bin/validator-engine-console -k ${KEYS_DIR}/client -p ${KEYS_DIR}/server.pub -a ${VAL_ENGINE_CONSOLE_IP}:${VAL_ENGINE_CONSOLE_PORT} -t 5"
export CALL_VE="$HOME/bin/validator-engine"
export CALL_TL="$HOME/bin/tvm_linker"
export CALL_TC="$HOME/bin/tonos-cli -c $SCRIPT_DIR/tonos-cli.conf.json"
export CALL_FIFT="${TON_BUILD_DIR}/crypto/fift -I ${FIFT_LIB}:${FSCs_DIR}"

if [[ "$OS_SYSTEM" == "Linux" ]];then
    export CALL_BC="bc"
else
    export CALL_BC="bc -l"
fi

#=================================================
export NormText="\e[0m"
export RedBlink="\e[5;101m"
export GreeBack="\e[42m"
export BlueBack="\e[44m"
export RedBack="\e[41m"
export YellowBack="\e[43m"
export BoldText="\e[1m"
export Tg_CheckMark=$(echo -e "\U0002705")
export Tg_SOS_sign=$(echo -e "\U0001F198")
