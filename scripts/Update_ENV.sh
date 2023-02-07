#!/usr/bin/env bash

# (C) Sergey Tyurin  2023-02-07 13:00:00

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
# Set versions
sed -i.bak "s|export RUST_VERSION=.*|export RUST_VERSION=\"1.66.1\"|; \
            s|export MIN_RC_VERSION=.*|export MIN_RC_VERSION=\"0.1.300\"|; \
            s|export MIN_TC_VERSION=.*|export MIN_TC_VERSION=\"0.32.00\"|; \
            s|export RNODE_GIT_REPO=.*|export RNODE_GIT_REPO=\"https://github.com/tonlabs/ever-node.git\"|g; \
            s|export RCONS_GIT_REPO=.*|export RCONS_GIT_REPO=\"https://github.com/tonlabs/ever-node-tools.git\"|g; \
            s|export Node_Blk_Min_Ver=.*|export Node_Blk_Min_Ver=35|" "${SCRIPT_DIR}/env.sh"

#################################################################
# Add DAPP_Project_id & DAPP_access_key variables 
# if [[ -z "$(cat ${SCRIPT_DIR}/env.sh | grep 'export DAPP_access_key')" ]];then
#     sed -i.bak '/# Networks endpoints/p; s/# Networks endpoints.*/export DAPP_access_key=""/' ${SCRIPT_DIR}/env.sh
# fi

# if [[ -z "$(cat ${SCRIPT_DIR}/env.sh | grep 'export DAPP_Project_id')" ]];then
#     sed -i.bak '/# Networks endpoints/p; s/# Networks endpoints.*/export DAPP_Project_id=""/' ${SCRIPT_DIR}/env.sh
# fi

# if [[ -z "$(cat ${SCRIPT_DIR}/env.sh | grep 'export Auth_key_Head')" ]];then
#     sed -i.bak '/# Networks endpoints/p; s/# Networks endpoints.*/export Auth_key_Head="Authorization: Basic "/' ${SCRIPT_DIR}/env.sh
# fi

# sed -i.bak 's|export Main_DApp_URL=.*|export Main_DApp_URL="https://mainnet.evercloud.dev"|' "${SCRIPT_DIR}/env.sh"
# sed -i.bak 's|export MainNet_DApp_List=.*|export MainNet_DApp_List="https://https://mainnet.evercloud.dev,https://eri01.main.everos.dev,https://gra01.main.everos.dev,https://gra02.main.everos.dev,https://lim01.main.everos.dev,https://rbx01.main.everos.dev"|' "${SCRIPT_DIR}/env.sh"

# sed -i.bak 's|export DevNet_DApp_URL=.*|export DevNet_DApp_URL="https://net.evercloud.dev"|' "${SCRIPT_DIR}/env.sh"
# sed -i.bak 's|export DevNet_DApp_List=.*|export DevNet_DApp_List="https://https://net.evercloud.dev,https://eri01.net.everos.dev,https://rbx01.net.everos.dev,https://gra01.net.everos.dev"|' "${SCRIPT_DIR}/env.sh"

# if [[ -z "$(cat ${SCRIPT_DIR}/env.sh | grep 'export Tg_Exclaim_sign')" ]];then
#     sed -i.bak '/export Tg_Warn_sign/p; s/export Tg_Warn_sign.*/export Tg_Exclaim_sign=$(echo -e "\\U000203C")/' ${SCRIPT_DIR}/env.sh
# fi

source "${SCRIPT_DIR}/env.sh"

if [[ -z "$DAPP_Project_id" ]];then
    "${SCRIPT_DIR}/Send_msg_toTelBot.sh" "$HOSTNAME Server" "$Tg_Exclaim_sign $(cat ${SCRIPT_DIR}/Update_Info.txt) $Tg_Exclaim_sign" 2>&1 > /dev/null
fi

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
