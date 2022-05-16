#!/usr/bin/env bash

# (C) Sergey Tyurin  2022-05-16 13:00:00

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

# set new mainnet endpoints
echo "+++ Set mainnet endpoints"
sed -i.bak 's|^export MainNet_DApp_List=.*|export MainNet_DApp_List="https://eri01.main.everos.dev,https://gra01.main.everos.dev,https://gra02.main.everos.dev,https://lim01.main.everos.dev,https://rbx01.main.everos.dev"|' ${SCRIPT_DIR}/env.sh

# set new devnet endpoints
echo "+++ Set devnet endpoints"
sed -i.bak 's|^export DevNet_DApp_List=.*|export DevNet_DApp_List="https://eri01.net.everos.dev,https://rbx01.net.everos.dev,https://gra01.net.everos.dev"|' ${SCRIPT_DIR}/env.sh

# set new tonos-cli min version
echo "+++ Set tonos min version to 0.26.7"
sed -i.bak 's/^export MIN_TC_VERSION=.*/export MIN_TC_VERSION="0.26.7"/' ${SCRIPT_DIR}/env.sh

# set new tonos-cli min version
echo "+++ Set consol min version to 0.1.262"
sed -i.bak 's/^export MIN_RC_VERSION=.*/export MIN_RC_VERSION="0.1.262"/' ${SCRIPT_DIR}/env.sh

# Installing new node version with block version 24. Making DB restore once again.
echo "+++ Set NODE actual commit to 8135f586aa1a536393496c21cb1acba510c3f9a9"
sed -i.bak 's/^export RNODE_GIT_COMMIT=.*/export RNODE_GIT_COMMIT="8135f586aa1a536393496c21cb1acba510c3f9a9"/' ${SCRIPT_DIR}/env.sh
#################################################################

echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date  +'%F %T %Z')"
echo "================================================================================================"

exit 0
