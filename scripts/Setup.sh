#!/usr/bin/env bash

# (C) Sergey Tyurin  2021-10-19 15:00:00

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
echo "################################# Nodes setup script ###################################"
echo "+++INFO: $(basename "$0") BEGIN $(date +%s) / $(date)"
echo
echo -e "$(DispEnvInfo)"
echo

#============================================
# Check vars settings. 
case "$NODE_TYPE" in 
    RUST)
        if [[ -z $R_DB_DIR ]];then
            echo "###-ERROR: 'R_DB_DIR' variable cannot be empty! Edit env.sh to set the variable."
            exit 1
        fi
        if [[ -z $R_LOG_DIR ]];then
            echo "###-ERROR: 'R_LOG_DIR' variable cannot be empty! Edit env.sh to set the variable."
            exit 1
        fi
        ;;
    CPP)
        if [[ -z $TON_LOG_DIR ]];then
            echo "###-ERROR: 'TON_LOG_DIR' variable cannot be empty! Edit env.sh to set the variable."
            exit 1
        fi
        if [[ -z $TON_WORK_DIR ]];then
            echo "###-ERROR: 'TON_WORK_DIR' variable cannot be empty! Edit env.sh to set the variable."
            exit 1
        fi
        ;;
    *)
        echo "###-ERROR: Unknown node type! Set NODE_TYPE= to 'RUST' or 'CPP' in env.sh"
        exit 1
        ;;
esac

#============================================
# Get OS type
OS_SYSTEM=`uname -s`
if [[ "$OS_SYSTEM" == "Linux" ]];then
    SETUP_USER="$(id -u)"
    SETUP_GROUP="$(id -g)"
else
    SETUP_USER="$(id -un)"
    SETUP_GROUP="$(id -gn)"
fi

#============================================
# Update networks global configs from github
./nets_config_update.sh

#============================================
# Info 
echo 
echo "------------- Node config parameters ------------------"
echo -e "Node type: ${BoldText}${GreeBack}${NODE_TYPE}${NormText}"
echo -e "Elector:   ${BoldText}${RedBack}${ELECTOR_TYPE}${NormText}"
echo -e "Network to connect: ${BoldText}${RedBack}${NETWORK_TYPE}${NormText}"
echo "Node IP addr: $NODE_IP_ADDR port: $ADNL_PORT"
if [[ "$NODE_TYPE" == "RUST"  ]]; then
    echo "Node DataBase dir:    ${R_DB_DIR}"
    echo "Node Logs dir:        ${R_LOG_DIR}"
    echo "Node configs dir:     ${R_CFG_DIR}"
else
    echo "Node DataBase dir:    ${TON_WORK_DIR}/db"
    echo "Node Logs dir:        ${TON_LOG_DIR}"
fi
echo "Node KEYS dir:        ${KEYS_DIR}"
echo "Node elections dir:   ${ELECTIONS_WORK_DIR}"

#============================================
# Confirm setup
# read -p "### CHECK CONFIG TWICE!!! ALL data in work and log folders will be DELETED! Think once more!  (yes/N)? " </dev/tty answer
# case ${answer:0:3} in
#     yes|YES|Yes )
#         echo
#         echo "Processing....."
#     ;;
#     * )
#         echo
#         echo "If you absolutely sure, type 'yes' "
#         echo "Cancelled."
#         exit 1
#     ;;
# esac

#######################################################
# Signal 2 is Ctrl+C
# disable it:
trap '' 2  
#######################################################
#============================================
# stop node service
OS_SYSTEM=`uname -s`
if [[ "$OS_SYSTEM" == "Linux" ]];then
    sudo service ${ServiceName} stop|cat
else
    service ${ServiceName} stop|cat
fi

#============================================
# Remove old folders. We can't delete TON_WORK_DIR if it has been mounted on separate disk
# And make work folders
echo -n "---INFO: Prepare folders..."
sudo mkdir -p "${TON_WORK_DIR}"
sudo chown "${SETUP_USER}:${SETUP_GROUP}" "${TON_WORK_DIR}"
mkdir -p "${KEYS_DIR}"
touch ${KEYS_DIR}/watchdog.beginning
touch ${KEYS_DIR}/watchdog.blocked
mkdir -p "$ELECTIONS_WORK_DIR"
mkdir -p "${NODE_LOGS_ARCH}"
echo " ..DONE"

if [[ "$NODE_TYPE" == "RUST"  ]]; then
    echo -n "---INFO: Create Rnode folders..."
    rm -rf "${RNODE_WORK_DIR}"
    rm -rf /node_db/*
    mkdir -p "${R_DB_DIR}"
    mkdir -p "${R_LOG_DIR}"
    mkdir -p "${R_CFG_DIR}"
    echo " ..DONE :"
    echo "${RNODE_WORK_DIR} :"
    ls -alhFp ${RNODE_WORK_DIR}
    echo
    cp -f "${CONFIGS_DIR}/${NETWORK_TYPE}/ton-global.config.json" "${R_CFG_DIR}/"
else
    echo -n "---INFO: Create Cnode folders..."
    sudo rm -rf "${TON_WORK_DIR}/db"
    mkdir -p "${TON_WORK_DIR}/etc"
    mkdir -p "${TON_WORK_DIR}/db"
    mkdir -p "${TON_LOG_DIR}"
    echo " ..DONE :"
    echo "${TON_WORK_DIR} :"
    ls -alhFp ${TON_WORK_DIR}
    echo
    cp -f "${CONFIGS_DIR}/${NETWORK_TYPE}/ton-global.config.json" "${TON_WORK_DIR}/etc/"
fi
echo " ..DONE"
#============================================
# set network for tonos-cli
# tonos-cli config --url="https://${NETWORK_TYPE}"
# to be able to use old versions tonos-cli we need two config files
# special DApp server for FLD network :)
# echo -n "---INFO: Set network for tonos-cli..."
# if [[ "$NETWORK_TYPE" == "fld.ton.dev" ]];then
# #    jq -c ".url = \"https://gql.custler.net\"" tonlabs-cli.conf.json > tonlabs-cli.conf.tmp && mv -f tonlabs-cli.conf.tmp tonlabs-cli.conf.json
#     jq -c ".url = \"https://gql.custler.net\"" tonos-cli.conf.json > tonos-cli.conf.tmp && mv -f tonos-cli.conf.tmp tonos-cli.conf.json
# else
# #    jq -c ".url = \"https://${NETWORK_TYPE}\"" tonlabs-cli.conf.json > tonlabs-cli.conf.tmp && mv -f tonlabs-cli.conf.tmp tonlabs-cli.conf.json
#     jq -c ".url = \"https://${NETWORK_TYPE}\"" tonos-cli.conf.json > tonos-cli.conf.tmp && mv -f tonos-cli.conf.tmp tonos-cli.conf.json
# fi
# echo " ..DONE"

#============================================
# set log rotate
# NB! - should be log '>>' in run.sh or 'append' in service. In other case copytrancate will not work
./setup_logrotate.sh

#===========================================
# Generate initial configs
if [[ "$NODE_TYPE" == "RUST"  ]]; then
    ./R_gen_init_configs.sh
else
    ./C_gen_init_configs.sh
fi

#===========================================
# Setup service for Linux
./setup_as_service.sh

#===========================================
# Generate validator contracts addresses and keys
# Use: ./Prep-Msig.sh <Wallet name> <'Safe' or 'SetCode'> <Num of custodians> <workchain>
./Prep-Msig.sh Tik Safe 1 0
Val_WC=0
[[ "$STAKE_MODE" == "msig" ]] && Val_WC="-1"
./Prep-Msig.sh $HOSTNAME Safe 3 ${Val_WC}
./Prep-DePool.sh

#######################################################
# Enable Ctrl+C
trap 2
#######################################################

echo
echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date)"
echo "================================================================================================"

exit 0
