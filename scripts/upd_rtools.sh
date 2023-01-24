#!/usr/bin/env bash

BUILD_STRT_TIME=$(date +%s)
echo
echo "############################## FreeTON Rnode Tools build script ##################################"
echo "+++INFO: $(basename "$0") BEGIN $(date +%s) / $(date)"

SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
source "${SCRIPT_DIR}/env.sh"
source $HOME/.cargo/env

FEXEC_FLG="-executable"

OS_SYSTEM=`uname -s`
if [[ "$OS_SYSTEM" == "FreeBSD" ]];then
    FEXEC_FLG="-perm +111"
fi
#=====================================================
# Build rnode console
[[ ! -z ${RCONS_SRC_DIR} ]] && rm -rf "${RCONS_SRC_DIR}"
git clone --recursive "${RCONS_GIT_REPO}" $RCONS_SRC_DIR
cd $RCONS_SRC_DIR
git checkout "${RCONS_GIT_COMMIT}"
git submodule init && git submodule update --recursive
git submodule foreach 'git submodule init'
git submodule foreach 'git submodule update  --recursive'

cargo update
cargo build --release

find $RCONS_SRC_DIR/target/release/ -maxdepth 1 -type f ${FEXEC_FLG} -exec cp -f {} ${NODE_BIN_DIR}/ \;

echo
BUILD_END_TIME=$(date +%s)
Build_mins=$(( (BUILD_END_TIME - BUILD_STRT_TIME)/60 ))
Build_secs=$(( (BUILD_END_TIME - BUILD_STRT_TIME)%60 ))
echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date)"
echo "Builds took $Build_mins min $Build_secs secs"
echo "================================================================================================"

exit 0
