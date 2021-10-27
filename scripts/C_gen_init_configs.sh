#!/bin/bash

# (C) Sergey Tyurin  2020-01-18 18:00:00

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
echo "################################# CPP node confugure script ###################################"
echo "+++INFO: $(basename "$0") BEGIN $(date +%s) / $(date)"

#===========================================
echo "---INFO: generate initial ${TON_WORK_DIR}/db/config.json..."
"${TON_BUILD_DIR}/validator-engine/validator-engine" -C "${TON_WORK_DIR}/etc/ton-global.config.json" --db "${TON_WORK_DIR}/db" --ip "${NODE_IP_ADDR}:${ADNL_PORT}"

cd "${KEYS_DIR}"

"${UTILS_DIR}/generate-random-id" -m keys -n server > "${KEYS_DIR}/keys_s"
"${UTILS_DIR}/generate-random-id" -m keys -n liteserver > "${KEYS_DIR}/keys_l"
"${UTILS_DIR}/generate-random-id" -m keys -n client > "${KEYS_DIR}/keys_c"

find "${KEYS_DIR}"

mv -f "${KEYS_DIR}/server" "${TON_WORK_DIR}/db/keyring/$(awk '{print $1}' "${KEYS_DIR}/keys_s")"
mv -f "${KEYS_DIR}/liteserver" "${TON_WORK_DIR}/db/keyring/$(awk '{print $1}' "${KEYS_DIR}/keys_l")"

awk -v VAL_ENGINE_CONSOLE_PORT="$VAL_ENGINE_CONSOLE_PORT" -v LITESERVER_PORT="$LITESERVER_PORT" '{
    if (NR == 1) {
        server_id = $2
    } else if (NR == 2) {
        client_id = $2
    } else if (NR == 3) {
        liteserver_id = $2
    } else {
        print $0;
        if ($1 == "\"control\"") {
            print "      {";
            print "         \"id\": \"" server_id "\","
            print "         \"port\": " VAL_ENGINE_CONSOLE_PORT ","
            print "         \"allowed\": ["
            print "            {";
            print "               \"id\": \"" client_id "\","
            print "               \"permissions\": 15"
            print "            }";
            print "         ]"
            print "      }";
        } else if ($1 == "\"liteservers\"") {
            print "      {";
            print "         \"id\": \"" liteserver_id "\","
            print "         \"port\": " LITESERVER_PORT
            print "      }";
        }
    }
}' "${KEYS_DIR}/keys_s" "${KEYS_DIR}/keys_c" "${KEYS_DIR}/keys_l" "${TON_WORK_DIR}/db/config.json" > "${TON_WORK_DIR}/db/config.json.tmp"

mv -f "${TON_WORK_DIR}/db/config.json.tmp" "${TON_WORK_DIR}/db/config.json"

echo
echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date)"
echo "================================================================================================"

exit 0
