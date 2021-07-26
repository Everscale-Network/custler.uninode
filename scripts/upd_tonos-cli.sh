#!/bin/bash -eE

BUILD_STRT_TIME=$(date +%s)
echo
echo "############################## FreeTON tonos-cli build script ##################################"
echo "+++INFO: $(basename "$0") BEGIN $(date +%s) / $(date)"

SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
source "${SCRIPT_DIR}/env.sh"

cd $HOME
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o $HOME/rust_install.sh
sh $HOME/rust_install.sh -y --default-toolchain ${RUST_VERSION}
source $HOME/.cargo/env
#=====================================================
# Build tonos-cli
[[ ! -z ${TONOS_CLI_SRC_DIR} ]] && rm -rf "${TONOS_CLI_SRC_DIR}"
git clone --recurse-submodules "${TONOS_CLI_GIT_REPO}" "${TONOS_CLI_SRC_DIR}"
cd "${TONOS_CLI_SRC_DIR}"
git checkout "${TONOS_CLI_GIT_COMMIT}"
cargo update
cargo build --release
cp -f "${TONOS_CLI_SRC_DIR}/target/release/tonos-cli" "$HOME/bin/"

echo
$HOME/bin/tonos-cli version
echo
BUILD_END_TIME=$(date +%s)
Build_mins=$(( (BUILD_END_TIME - BUILD_STRT_TIME)/60 ))
Build_secs=$(( (BUILD_END_TIME - BUILD_STRT_TIME)%60 ))
echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date)"
echo "Builds took $Build_mins min $Build_secs secs"
echo "================================================================================================"

exit 0
