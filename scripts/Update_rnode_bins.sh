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
# shellcheck source=env.sh
. "${SCRIPT_DIR}/env.sh"


./Nodes_Build.sh rust

sudo service tonnode stop

cp -f ${RNODE_SRC_DIR}/target/release/ton_node $HOME/bin/rnode

./setup_as_service.sh

sudo service tonnode start

exit 0
