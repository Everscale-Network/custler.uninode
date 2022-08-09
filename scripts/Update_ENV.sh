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
# echo "Nothing to do."

#################################################################
# Fix binaries names for new release 7-zip and old p7zip
if [[ -z "$(cat env.sh|grep 'CALL_7Z')" ]];then
    echo "+++INFO: Fix binaries names for new release 7-zip and old p7zip"
    cp -f env.sh env.sh.bak
    awk '{
        if ($0 == "    export\ CALL_BC=\"bc\ -l\"") {
            print $0;
            getline;
            print $0;
            print "\n# =====================================================";
            print "# Set binary for 7-zip";
            print "export CALL_7Z=\"7z\"";
            print "Distro_Name=\"$(cat /etc/os-release | grep \"PRETTY_NAME=\"|awk -F\x27[\" ]\x27 \x27{print $2}\x27)\"";
            print "if [[ \"$Distro_Name\" == \"CentOS\" ]] || [[ \"$Distro_Name\" == \"Fedora\" ]] || [[ \"$Distro_Name\" == \"Oracle\" ]];then"
            print "    export CALL_7Z=\"7za\"";
            print "fi";
            next;
        } else {
            print $0;
        }
    }' env.sh.bak > env.sh
fi
##########################################################

echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date  +'%F %T %Z')"
echo "================================================================================================"

exit 0
