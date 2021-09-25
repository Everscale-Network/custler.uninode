#!/bin/bash -eE

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

cd "${TVM_LINKER_SRC_DIR}/tvm_linker"
cargo update
cargo build --release
cp -f "${TVM_LINKER_SRC_DIR}/tvm_linker/target/release/tvm_linker" $HOME/bin/

echo
$HOME/bin/tvm_linker --version
echo
BUILD_END_TIME=$(date +%s)
Build_mins=$(( (BUILD_END_TIME - BUILD_STRT_TIME)/60 ))
Build_secs=$(( (BUILD_END_TIME - BUILD_STRT_TIME)%60 ))
echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date)"
echo "Builds took $Build_mins min $Build_secs secs"
echo "================================================================================================"

exit 0

{
  "name": "getDePoolBalance",
  "inputs": [
  ],
  "outputs": [
    {"name":"value0","type":"int256"}
]
},
