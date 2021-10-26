#!/usr/bin/env bash

# (C) Sergey Tyurin  2021-01-18 12:00:00

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

# script to rotate log in FreeBSD or manually

SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
# shellcheck source=env.sh
. "${SCRIPT_DIR}/env.sh"

LR_CFG=${SCRIPT_DIR}/rot_nodelog.cfg

LOG_DIR="$TON_LOG_DIR"
[[ "$NODE_TYPE" == "RUST" ]] && LOG_DIR="${R_LOG_DIR}"

LR_LOG=${LOG_DIR}/rot_nodelog.log
LR_STATUS=${LOG_DIR}/rot_nodelog.status

logrotate -s $LR_STATUS -l $LR_LOG -f $LR_CFG

exit 0
