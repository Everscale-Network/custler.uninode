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
case "${NODE_TYPE}" in
    RUST)
        ;;
    CPP)
        Zero_State_ID=`$CALL_LC -rc "time" -rc "quit" 2>&1 |grep 'zerostate id'|awk -F ':' '{print $3}'|cut -c 1-16`
        echo "$Zero_State_ID"
        ;;
    *)
        echo "###-ERROR(line $LINENO): Unknown node type! Set NODE_TYPE= to 'RUST' or 'CPP' in env.sh"
        exit 1
        ;; 
esac

exit 0
