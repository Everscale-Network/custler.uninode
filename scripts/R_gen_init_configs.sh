#!/usr/bin/env bash

# (C) Sergey Tyurin  2020-01-20 19:00:00

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
echo "################################# Rust node confugure script ###################################"
echo "+++INFO: $(basename "$0") BEGIN $(date +%s) / $(date)"

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

#===========================================
# Configs source files
DFLT_CFG_FILE="${CONFIGS_DIR}/rnode/default_config.json"
LOG_CFG_FILE="${CONFIGS_DIR}/rnode/log_cfg.yml"
CONS_TMPLT_FILE="${CONFIGS_DIR}/rnode/console_template.json"

#===========================================
# Setup default_config
echo -n "---INFO: Prepare default_config..."
rm -f default_config.tmp
cat "${DFLT_CFG_FILE}" | jq \
".log_config_name = \"$R_CFG_DIR/log_cfg.yml\" | \
.ton_global_config_name = \"$R_CFG_DIR/ton-global.config.json\" | \
.internal_db_path = \"$R_DB_DIR\" | \
.ip_address = \"${NODE_IP_ADDR}:${ADNL_PORT}\" | \
.control_server_port = $RCONSOLE_PORT" > default_config.tmp
mv -f default_config.tmp  ${R_CFG_DIR}/default_config.json
echo " ..DONE"

#===========================================
# Setup log_cfg.yml
echo -n "---INFO: Prepare log_cfg..."
rm -f log_cfg.tmp
yq e \
".appenders.logfile.path = \"${R_LOG_DIR}/${RNODE_LOG_FILE}\" | \
.appenders.rolling_logfile.path = \"${R_LOG_DIR}/${RNODE_LOG_FILE}\" | \
.appenders.rolling_logfile.policy.roller.pattern = \"${R_LOG_DIR}/rnode_{}.log\"" ${LOG_CFG_FILE} > log_cfg.tmp
mv -f log_cfg.tmp  ${R_CFG_DIR}/log_cfg.yml
echo " ..DONE"

#===========================================
# Set rnode console keys
echo -n "---INFO: Prepare console_client_keys..."
${NODE_BIN_DIR}/keygen > ${R_CFG_DIR}/${HOSTNAME}_console_client_keys.json
jq -c '.public' ${R_CFG_DIR}/${HOSTNAME}_console_client_keys.json > ${R_CFG_DIR}/console_client_public.json
echo " ..DONE"

#===========================================
# Generate rnode config.json
echo -n "---INFO: Genegate Rnode config.json..."
$CALL_RN --ckey "$(cat "${R_CFG_DIR}/console_client_public.json")" &>/dev/null &
sleep 10
pkill rnode &>/dev/null

if [ ! -f "${R_CFG_DIR}/config.json" ]; then
    echo "###-ERROR: ${R_CFG_DIR}/config.json does not created!"
    exit 1
fi

#===========================================
# Set workchain for node
# if [[ "$(jq '.workchain' "${R_CFG_DIR}/config.json")" == "null" ]];then
#     echo "{\"workchain\": $NODE_WC}" | jq '. += $inputs[]' --slurpfile inputs "${R_CFG_DIR}/config.json" > "${R_CFG_DIR}/config.json.tmp"
#     mv -f "${R_CFG_DIR}/config.json.tmp" "${R_CFG_DIR}/config.json"
# else
#     jq ".workchain = $NODE_WC" "${R_CFG_DIR}/config.json"  > "${R_CFG_DIR}/config.json.tmp"
#     mv -f "${R_CFG_DIR}/config.json.tmp" "${R_CFG_DIR}/config.json"
# fi

#===========================================
# 
if [ ! -f "${R_CFG_DIR}/console_config.json" ]; then
    echo "###-ERROR: ${R_CFG_DIR}/console_config.json does not created!"
    exit 1
fi

jq ".client_key = $(jq .private "${R_CFG_DIR}/${HOSTNAME}_console_client_keys.json")" "${R_CFG_DIR}/console_config.json" > console_config.json.tmp
jq ".config = $(cat console_config.json.tmp)" "${CONS_TMPLT_FILE}" >"${R_CFG_DIR}/console.json"

rm -f console_config.json.tmp
# rm -f "${TON_NODE_CONFIGS_DIR}/console_config.json"

echo " ..DONE"

echo
echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date)"
echo "================================================================================================"

exit 0
