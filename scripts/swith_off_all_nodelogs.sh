#!/bin/bash -eE

# (C) Sergey Tyurin  2021-03-15 15:00:00

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
# source "${SCRIPT_DIR}/functions.shinc"

echo -n "---INFO: Prepare log_cfg for absolutely no logging..."

cp ${R_CFG_DIR}/log_cfg.yml ${SCRIPT_DIR}/log_cfg.tmp

if [[ "$(uname -s)" == "Linux" ]];then
    sed -i 's/level: info/level: off/g' ${SCRIPT_DIR}/log_cfg.tmp
    sed -i 's/level: trace/level: off/g' ${SCRIPT_DIR}/log_cfg.tmp
    sed -i 's/level: debug/level: off/g' ${SCRIPT_DIR}/log_cfg.tmp
    sed -i 's/level: error/level: off/g' ${SCRIPT_DIR}/log_cfg.tmp
else
    sed -i.bak 's/level: info/level: off/g' ${SCRIPT_DIR}/log_cfg.tmp
    sed -i.bak 's/level: trace/level: off/g' ${SCRIPT_DIR}/log_cfg.tmp
    sed -i.bak 's/level: debug/level: off/g' ${SCRIPT_DIR}/log_cfg.tmp
    sed -i.bak 's/level: error/level: off/g' ${SCRIPT_DIR}/log_cfg.tmp
fi

mv -f ${SCRIPT_DIR}/log_cfg.tmp  ${R_CFG_DIR}/log_cfg.yml
echo " ..DONE"

exit 0
