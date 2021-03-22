#!/bin/bash
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

# telegram_bot_token=
# telegram_chat_id=""

telegram_bot_token=$(cat TlgChat.json|jq '.telegram_bot_token'|tr -d '"')
telegram_chat_id=$(cat TlgChat.json|jq '.telegram_chat_id'|tr -d '"')


Title="$1"
Message="$2"
URL_to_Val="$3"

if [[ ! -z ${URL_to_Val} ]];then
    MSG_JSON=$(echo "" | awk -v TITLE="$Title" -v MESSAGE="\*${Title}* \n${Message}" -v CHAT_ID="$telegram_chat_id" -v URL="$URL_to_Val"  '{
        print "{";
        print "     \"chat_id\" : " CHAT_ID ","
        print "     \"text\" : \"" MESSAGE "\","
        print "     \"parse_mode\" : \"markdown\","
        print "     \"reply_markup\" : {";
        print "         \"inline_keyboard\" : ["
        print "            ["
        print "                 {";
        print "                     \"text\" : \"Open on tone.live\","
        print "                     \"url\" : \"" URL "\""
        print "                 }";
        print "             ]"
        print "         ]"
        print "         }";
        print "}";

    }')
    
    # echo $MSG_JSON
    curl -d "$MSG_JSON" \
     -H "Content-Type: application/json" \
     -X POST https://api.telegram.org/bot${telegram_bot_token}/sendMessage 

else 
    curl -s \
     --data parse_mode=HTML \
     --data chat_id=${telegram_chat_id} \
     --data text="<b>${Title}</b>%0A${Message}" \
     --request POST https://api.telegram.org/bot${telegram_bot_token}/sendMessage 
fi

exit 0
