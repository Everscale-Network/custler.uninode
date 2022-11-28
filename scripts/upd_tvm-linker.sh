#!/usr/bin/env bash

# (C) Sergey Tyurin  2022-11-28 13:00:00

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
echo "############################## FreeTON TVM_Linker build script ##################################"
echo "+++INFO: $(basename "$0") BEGIN $(date +%s) / $(date)"

SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
source "${SCRIPT_DIR}/env.sh"

cd $HOME
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o $HOME/rust_install.sh
sh $HOME/rust_install.sh -y --default-toolchain ${RUST_VERSION}
source $HOME/.cargo/env
#=====================================================
# Build tvm_linker
[[ ! -z ${TVM_LINKER_SRC_DIR} ]] && rm -rf "${TVM_LINKER_SRC_DIR}"
git clone --recurse-submodules "${TVM_LINKER_GIT_REPO}" "${TVM_LINKER_SRC_DIR}"
cd "${TVM_LINKER_SRC_DIR}"
git checkout "${TVM_LINKER_GIT_COMMIT}"
git submodule init && git submodule update --recursive
git submodule foreach 'git submodule init'
git submodule foreach 'git submodule update  --recursive'

cd "${TVM_LINKER_SRC_DIR}/tvm_linker"
cargo update
cargo build --release
cp -f "${TVM_LINKER_SRC_DIR}/target/release/tvm_linker" ${NODE_BIN_DIR}/

echo
${NODE_BIN_DIR}/tvm_linker --version
echo
BUILD_END_TIME=$(date +%s)
Build_mins=$(( (BUILD_END_TIME - BUILD_STRT_TIME)/60 ))
Build_secs=$(( (BUILD_END_TIME - BUILD_STRT_TIME)%60 ))
echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date)"
echo "Builds took $Build_mins min $Build_secs secs"
echo "================================================================================================"

exit 0
