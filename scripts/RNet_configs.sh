#!/usr/bin/env bash

SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
source "${SCRIPT_DIR}/env.sh"

echo "{\"rustnet_configs\":[" > RustNet_Conf_List.json

for ((i=0; i <= 255; i++ ))
do
    CurrParam="$($CALL_RC -c "getconfig ${i}" |sed -e '1,/GIT_BRANCH/d'|sed 's/config param: //')"
    if [[ "$CurrParam" == "{}" ]];then
        CurrParam="{\"p${i}}\": null}"
        continue
    fi
    echo "${CurrParam}," >> RustNet_Conf_List.json
done

truncate -s -2 RustNet_Conf_List.json
echo -e "\n]}" >> RustNet_Conf_List.json

exit 0
