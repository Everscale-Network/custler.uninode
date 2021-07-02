#!/bin/bash -eE

# (C) Sergey Tyurin  2021-09-29 22:00:00

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

# All generated executables will be placed in the $ HOME/bin folder.

BUILD_STRT_TIME=$(date +%s)

SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/functions.shinc"

echo
echo "################################### FreeTON nodes build script #####################################"
echo "+++INFO: $(basename "$0") BEGIN $(date +%s) / $(date)"

case "${@}" in
    cpp)
        CPP_NODE_BUILD=true
        RUST_NODE_BUILD=false
        ;;
    rust)
        CPP_NODE_BUILD=false
        RUST_NODE_BUILD=true
        ;;
    *)
        CPP_NODE_BUILD=true
        RUST_NODE_BUILD=true
        ;;
esac

[[ ! -d $HOME/bin ]] && mkdir -p $HOME/bin

#=====================================================
# Packages set for different OSes
PKGS_FreeBSD="mc libtool perl5 automake llvm-devel gmake git jq wget gawk base64 gflags ccache cmake curl gperf openssl ninja lzlib vim sysinfo logrotate gsl p7zip boost-all zstd"
PKGS_CentOS="curl jq wget bc vim libtool logrotate openssl-devel clang llvm-devel ccache cmake ninja-build gperf gawk gflags snappy snappy-devel zlib zlib-devel bzip2 bzip2-devel lz4-devel libmicrohttpd-devel readline-devel p7zip boost-devel boost-static libzstd-devel"
PKGS_Ubuntu="git mc curl build-essential libssl-dev automake libtool clang llvm-dev jq vim cmake ninja-build ccache gawk gperf texlive-science doxygen-latex libgflags-dev libmicrohttpd-dev libreadline-dev libz-dev pkg-config zlib1g-dev p7zip bc libboost-all-dev libzstd-dev"

PKG_MNGR_FreeBSD="sudo pkg"
PKG_MNGR_CentOS="sudo dnf"
PKG_MNGR_Ubuntu="sudo apt"
FEXEC_FLG="-executable"

#=====================================================
# Detect OS and set packages
OS_SYSTEM=`uname -s`
if [[ "$OS_SYSTEM" == "Linux" ]];then
    OS_SYSTEM="$(hostnamectl |grep 'Operating System'|awk '{print $3}')"

elif [[ ! "$OS_SYSTEM" == "FreeBSD" ]];then
    echo
    echo "###-ERROR: Unknown or unsupported OS. Can't continue."
    echo
    exit 1
fi

#=====================================================
# Set packages set & manager according to OS
case "$OS_SYSTEM" in
    FreeBSD)
        export ZSTD_LIB_DIR=/usr/local/lib
        PKGs_SET=$PKGS_FreeBSD
        PKG_MNGR=$PKG_MNGR_FreeBSD
#        $PKG_MNGR remove -y rust
        $PKG_MNGR update -f
        $PKG_MNGR upgrade -y
        FEXEC_FLG="-perm +111"
        sudo wget https://github.com/mikefarah/yq/releases/download/v4.4.0/yq_freebsd_amd64 -O /usr/local/bin/yq && sudo chmod +x /usr/local/bin/yq
        #	libmicrohttpd \ 
        #   does not build with libmicrohttpd-0.9.71
        #   build & install libmicrohttpd-0.9.70
        mkdir -p $HOME/src
        cd $HOME/src
#        sudo pkg remove -y libmicrohttpd | cat
        fetch https://ftp.gnu.org/gnu/libmicrohttpd/libmicrohttpd-0.9.70.tar.gz
        tar xf libmicrohttpd-0.9.70.tar.gz
        cd libmicrohttpd-0.9.70
        ./configure && make && sudo make install
        ;;

    CentOS)
        export ZSTD_LIB_DIR=/usr/lib64
        PKGs_SET=$PKGS_CentOS
        PKG_MNGR=$PKG_MNGR_CentOS
        $PKG_MNGR -y update --allowerasing
        $PKG_MNGR group install -y "Development Tools"
        $PKG_MNGR config-manager --set-enabled powertools
        $PKG_MNGR --enablerepo=extras install -y epel-release
        sudo wget https://github.com/mikefarah/yq/releases/download/v4.4.0/yq_linux_amd64 -O /usr/bin/yq && sudo chmod +x /usr/bin/yq
        ;;

    Ubuntu)
        export ZSTD_LIB_DIR=/usr/lib/x86_64-linux-gnu
        PKGs_SET=$PKGS_Ubuntu
        PKG_MNGR=$PKG_MNGR_Ubuntu
        $PKG_MNGR update && $PKG_MNGR upgrade -y 
        sudo wget https://github.com/mikefarah/yq/releases/download/v4.4.0/yq_linux_amd64 -O /usr/bin/yq && sudo chmod +x /usr/bin/yq
        ;;

    *)
        echo
        echo "###-ERROR: Unknown or unsupported OS. Can't continue."
        echo
        exit 1
        ;;
esac

#=====================================================
# Install packages
echo "---INFO: Install packages ... "
$PKG_MNGR install -y $PKGs_SET
echo "---INFO: Install packages ... DONE"

#=====================================================
# Install or upgrade RUST
cd $HOME
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --default-toolchain ${RUST_VERSION} -y
# curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o $HOME/rust_install.sh
# sh $HOME/rust_install.sh -y --default-toolchain ${RUST_VERSION}
# curl https://sh.rustup.rs -sSf | sh -s -- --default-toolchain ${RUST_VERSION} -y

source $HOME/.cargo/env
cargo install cargo-binutils
#=====================================================
# Build C++ node
if $CPP_NODE_BUILD;then
    cd $SCRIPT_DIR
    [[ -d ${TON_SRC_DIR} ]] && rm -rf "${TON_SRC_DIR}"

    echo "---INFO: clone ${CNODE_GIT_REPO} (${CNODE_GIT_COMMIT})..."
    git clone --recursive "${CNODE_GIT_REPO}" "${TON_SRC_DIR}"
    cd "${TON_SRC_DIR}" && git checkout "${CNODE_GIT_COMMIT}"
    echo "---INFO: clone ${CNODE_GIT_REPO} (${CNODE_GIT_COMMIT})... DONE"
    echo "---INFO: build a node..."
    mkdir -p "${TON_BUILD_DIR}"
    cd "${TON_BUILD_DIR}"
    cmake .. -G "Ninja" -DCMAKE_BUILD_TYPE=Release -DPORTABLE=ON
    ninja
    echo "---INFO: build a node... DONE"
    cp -f $TON_BUILD_DIR/lite-client/lite-client $HOME/bin
    cp -f $TON_BUILD_DIR/validator-engine/validator-engine $HOME/bin
    cp -f $TON_BUILD_DIR/validator-engine-console/validator-engine-console $HOME/bin

    #=====================================================
    echo "---INFO: build utils (convert_address)..."
    cd "${NODE_SRC_TOP_DIR}/utils/convert_address"
    cargo update
    cargo build --release
    cp "${NODE_SRC_TOP_DIR}/utils/convert_address/target/release/convert_address" "$HOME/bin/"
    echo "---INFO: build utils (convert_address)... DONE"
fi
#=====================================================
# Build rust node
if $RUST_NODE_BUILD;then
    echo "---INFO: build RUST NODE ..."
    #---------------- crutch for user run
    sudo mkdir -p /node_db
    sudo chmod -R ugo+rw /node_db
    #----------------
    [[ -d ${RNODE_SRC_DIR} ]] && rm -rf "${RNODE_SRC_DIR}"
    git clone --recurse-submodules "${RNODE_GIT_REPO}" $RNODE_SRC_DIR
    cd $RNODE_SRC_DIR
    git checkout "${RNODE_GIT_COMMIT}"
    git submodule init
    git submodule update
    cargo update

    sed -i.bak 's%features = \[\"cmake_build\", \"dynamic_linking\"\]%features = \[\"cmake_build\"\]%g' Cargo.toml
    sed -i.bak 's%log = "0.4"%log = { version = "0.4", features = ["release_max_level_off"] }%'  Cargo.toml

    RUSTFLAGS="-C target-cpu=native" cargo build --release --features "compression"
    # --features "metrics"
    # --features "external_db,metrics"

    cp -f ${RNODE_SRC_DIR}/target/release/ton_node $HOME/bin/rnode

    #=====================================================
    # Build rust node console
    [[ -d ${RCONS_SRC_DIR} ]] && rm -rf "${RCONS_SRC_DIR}"
    git clone --recurse-submodules "${RCONS_GIT_REPO}" $RCONS_SRC_DIR
    cd $RCONS_SRC_DIR
    git checkout "${RCONS_GIT_COMMIT}"
    git submodule init
    git submodule update
    RUSTFLAGS="-C target-cpu=native" cargo build --release

    find $RCONS_SRC_DIR/target/release/ -maxdepth 1 -type f ${FEXEC_FLG} -exec cp -f {} $HOME/bin/ \;
    echo "---INFO: build RUST NODE ... DONE."
fi
#=====================================================
# Build TON Solidity Compiler (solc)
# echo "---INFO: build TON Solidity Compiler ..."
# [[ ! -z ${SOLC_SRC_DIR} ]] && rm -rf "${SOLC_SRC_DIR}"
# git clone --recurse-submodules "${SOLC_GIT_REPO}" "${SOLC_SRC_DIR}"
# cd "${SOLC_SRC_DIR}"
# git checkout "${SOLC_GIT_COMMIT}"
# mkdir ${SOLC_SRC_DIR}/build
# cd "${SOLC_SRC_DIR}/build"
# cmake ../compiler/ -DCMAKE_BUILD_TYPE=Release
# if [[ "$(uname)" == "Linux" ]];then
#     V_CPU=`nproc`
# else
#     V_CPU=`sysctl -n hw.ncpu`
# fi
# cmake --build . -- -j $V_CPU
# cp -f "${SOLC_SRC_DIR}/build/solc/solc" $HOME/bin/
# cp -f "${SOLC_SRC_DIR}/lib/stdlib_sol.tvm" $HOME/bin/
# echo "---INFO: build TON Solidity Compiler ... DONE."
#=====================================================
# Build TVM-linker
echo "---INFO: build TVM-linker ..."
[[ ! -z ${TVM_LINKER_SRC_DIR} ]] && rm -rf "${TVM_LINKER_SRC_DIR}"
git clone --recurse-submodules "${TVM_LINKER_GIT_REPO}" "${TVM_LINKER_SRC_DIR}"
cd "${TVM_LINKER_SRC_DIR}"
git checkout "${TVM_LINKER_GIT_COMMIT}"
cd "${TVM_LINKER_SRC_DIR}/tvm_linker"
RUSTFLAGS="-C target-cpu=native" cargo build --release
cp -f "${TVM_LINKER_SRC_DIR}/tvm_linker/target/release/tvm_linker" $HOME/bin/
echo "---INFO: build TVM-linker ... DONE."
#=====================================================
# Build tonos-cli
echo "---INFO: build tonos-cli ... "
[[ -d ${TONOS_CLI_SRC_DIR} ]] && rm -rf "${TONOS_CLI_SRC_DIR}"
git clone --recurse-submodules "${TONOS_CLI_GIT_REPO}" "${TONOS_CLI_SRC_DIR}"
cd "${TONOS_CLI_SRC_DIR}"
git checkout "${TONOS_CLI_GIT_COMMIT}"
cargo update
RUSTFLAGS="-C target-cpu=native" cargo build --release
cp "${TONOS_CLI_SRC_DIR}/target/release/tonos-cli" "$HOME/bin/"
echo "---INFO: build tonos-cli ... DONE"

#=====================================================
# download contracts
rm -rf "${NODE_SRC_TOP_DIR}/ton-labs-contracts"
rm -rf "${NODE_SRC_TOP_DIR}/Surf-contracts"
git clone ${CONTRACTS_GIT_REPO} "${NODE_SRC_TOP_DIR}/ton-labs-contracts"
cd "${NODE_SRC_TOP_DIR}/ton-labs-contracts"
git checkout $CONTRACTS_GIT_COMMIT 
cd ${NODE_SRC_TOP_DIR}
git clone --single-branch --branch multisig-surf-v2 https://github.com/tonlabs/ton-labs-contracts.git "${NODE_SRC_TOP_DIR}/Surf-contracts"

RustCup_El_ABI_URL="https://raw.githubusercontent.com/tonlabs/rustnet.ton.dev/main/docker-compose/ton-node/configs/Elector.abi.json"
curl -o ${Elector_ABI} ${RustCup_El_ABI_URL} &>/dev/null

BUILD_END_TIME=$(date +%s)
Build_mins=$(( (BUILD_END_TIME - BUILD_STRT_TIME)/60 ))
Build_secs=$(( (BUILD_END_TIME - BUILD_STRT_TIME)%60 ))
echo
echo "+++INFO: $(basename "$0") on $HOSTNAME FINISHED $(date +%s) / $(date)"
echo "All builds took $Build_mins min $Build_secs secs"
echo "================================================================================================"

exit 0
