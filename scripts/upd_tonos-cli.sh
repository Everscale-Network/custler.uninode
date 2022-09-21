#!/usr/bin/env bash

# (C) Sergey Tyurin  2022-09-19 13:00:00

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
echo "############################## FreeTON tonos-cli build script ##################################"
echo "+++INFO: $(basename "$0") BEGIN $(date +%s) / $(date)"

SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
source "${SCRIPT_DIR}/env.sh"

#=====================================================
# Install or upgrade RUST
declare -i Curr_Rust_Ver_NUM=$(rustc -V | awk '{print $2}'| awk -F'.' '{printf("%d%03d%03d\n", $1,$2,$3)}')
declare -i ENV_Rust_Ver_NUM=$(echo $RUST_VERSION | awk -F'.' '{printf("%d%03d%03d\n", $1,$2,$3)}')
if [[ $Curr_Rust_Ver_NUM -lt ENV_Rust_Ver_NUM ]];then
    echo
    echo '################################################'
    echo "---INFO: Install RUST ${RUST_VERSION}"
    cd $HOME
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --default-toolchain ${RUST_VERSION} -y
    source $HOME/.cargo/env
    cargo install cargo-binutils
fi 

#=====================================================
# Build tonos-cli
[[ ! -z ${TONOS_CLI_SRC_DIR} ]] && rm -rf "${TONOS_CLI_SRC_DIR}"
git clone --recurse-submodules "${TONOS_CLI_GIT_REPO}" "${TONOS_CLI_SRC_DIR}"
cd "${TONOS_CLI_SRC_DIR}"
git checkout "${TONOS_CLI_GIT_COMMIT}"
git submodule init && git submodule update --recursive
git submodule foreach 'git submodule init'
git submodule foreach 'git submodule update  --recursive'

echo -e "${BoldText}${BlueBack}---INFO: TONOS git repo:   ${TONOS_CLI_GIT_REPO} ${NormText}"
echo -e "${BoldText}${BlueBack}---INFO: TONOS git commit: ${TONOS_CLI_GIT_COMMIT} ${NormText}"

cargo update
cargo build --release
cp -f "${TONOS_CLI_SRC_DIR}/target/release/tonos-cli" "${NODE_BIN_DIR}/"

echo
${NODE_BIN_DIR}/tonos-cli version
echo
BUILD_END_TIME=$(date +%s)
Build_mins=$(( (BUILD_END_TIME - BUILD_STRT_TIME)/60 ))
Build_secs=$(( (BUILD_END_TIME - BUILD_STRT_TIME)%60 ))
echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date)"
echo "Builds took $Build_mins min $Build_secs secs"
echo "================================================================================================"

exit 0
