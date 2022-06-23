#!/usr/bin/env bash

# (C) Sergey Tyurin  2022-06-10 13:00:00

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
echo "################################## Update env.sh Script ########################################"
echo "INFO: $(basename "$0") BEGIN $(date +%s) / $(date  +'%F %T %Z')"

SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
source "${SCRIPT_DIR}/env.sh"

#################################################################
# This section update env.sh to satisfy new changes in scripts
# Add LINC address to env.sh if not present
if [[ -z "${LNIC_ADDRESS}" ]];then
    echo "+++ Add LNIC address"
    if [[ -z "$(cat ${SCRIPT_DIR}/env.sh | grep 'export Enable_Node_Autoupdate')" ]];then
        sed -i.bak '/Enable_Scripts_Autoupdate=/p; s/Enable_Scripts_Autoupdate=.*/export LNIC_ADDRESS="0:bdcefecaae5d07d926f1fa881ea5b61d81ea748bd02136c0dbe76604323fc347"/' ${SCRIPT_DIR}/env.sh
        sed -i.bak '/Enable_Scripts_Autoupdate=/p; s/Enable_Scripts_Autoupdate=.*/# Last Node Info Contract for safe node update/' ${SCRIPT_DIR}/env.sh
    else
        sed -i.bak '/export Enable_Scripts_Autoupdate=/p; s/export Enable_Scripts_Autoupdate=.*/export LNIC_ADDRESS="0:bdcefecaae5d07d926f1fa881ea5b61d81ea748bd02136c0dbe76604323fc347"/' ${SCRIPT_DIR}/env.sh
        sed -i.bak '/export Enable_Scripts_Autoupdate=/p; s/export Enable_Scripts_Autoupdate=.*/# Last Node Info Contract for safe node update/' ${SCRIPT_DIR}/env.sh
    fi
fi
sed -i.bak "s/export RUST_VERSION=.*/export RUST_VERSION=\"1.61.0\"/" "${SCRIPT_DIR}/env.sh"
#################################################################

echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date  +'%F %T %Z')"
echo "================================================================================================"

exit 0
