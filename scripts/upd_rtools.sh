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

BUILD_STRT_TIME=$(date +%s)
echo
echo "############################## FreeTON Rnode Tools build script ##################################"
echo "+++INFO: $(basename "$0") BEGIN $(date +%s) / $(date)"

SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/functions.shinc"

FEXEC_FLG="-executable"

OS_SYSTEM=`uname -s`
if [[ "$OS_SYSTEM" == "FreeBSD" ]];then
    FEXEC_FLG="-perm +111"
fi
#=====================================================
# Build rnode console
[[ ! -z ${RCONS_SRC_DIR} ]] && rm -rf "${RCONS_SRC_DIR}"
git clone --recurse-submodules "${RCONS_GIT_REPO}" $RCONS_SRC_DIR
cd $RCONS_SRC_DIR
git checkout "${RCONS_GIT_COMMIT}"
cargo build --release

find $RCONS_SRC_DIR/target/release/ -maxdepth 1 -type f ${FEXEC_FLG} -exec cp -f {} $HOME/bin/ \;

echo
BUILD_END_TIME=$(date +%s)
Build_mins=$(( (BUILD_END_TIME - BUILD_STRT_TIME)/60 ))
Build_secs=$(( (BUILD_END_TIME - BUILD_STRT_TIME)%60 ))
echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date)"
echo "Builds took $Build_mins min $Build_secs secs"
echo "================================================================================================"

exit 0
