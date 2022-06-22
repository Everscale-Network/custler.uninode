#!/usr/bin/env bash

# (C) Sergey Tyurin  2020-08-01 11:00:00

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

Curr_UnixTime=$(date +%s)
echo
echo "############################## Rust node Reset Database script #################################"
echo "+++INFO: $(basename "$0") BEGIN $Curr_UnixTime / $(date  +'%F %T %Z')"
echo

#===========================================
# Stop rnode service
echo -n "---INFO: Stopping rnode service ..."
sudo service tonnode stop
sleep 5
echo " ..DONE"

#===========================================
# Save all configs
echo -n "---INFO: Save rnode configs to $TON_WORK_DIR/rnode_configs_backup_${Curr_UnixTime} ..."
cp -r "${R_CFG_DIR}" "$TON_WORK_DIR/rnode_configs_backup_${Curr_UnixTime}"
echo " ..DONE"

#===========================================
# Rename rnode DB folder for backup
echo -n "---INFO: Rename current DB to $TON_WORK_DIR/rnode_DB_backup_${Curr_UnixTime} ..."
mv -f "${R_DB_DIR}" "$TON_WORK_DIR/rnode_DB_backup_${Curr_UnixTime}"
echo " ..DONE"

#===========================================
# Generate generate new DB
# echo -n "---INFO: Genegate New DB..."
# $CALL_RN --ckey "$(cat "${R_CFG_DIR}/console_client_public.json")" &>/dev/null &
# sleep 10
# pkill rnode &>/dev/null
# sleep 5
# echo " ..DONE"

#===========================================
# Start rnode service
echo -n "---INFO: Starting rnode service ..."
sudo service tonnode start
sleep 5
echo " ..DONE"

echo
echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date  +'%F %T %Z')"
echo "================================================================================================"

exit 0
