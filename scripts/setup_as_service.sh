#!/usr/bin/env bash

# (C) Sergey Tyurin  2020-02-16 13:00:00

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
source "${SCRIPT_DIR}/functions.shinc"

echo
echo "################################# service setup script ###################################"
echo "+++INFO: $(basename "$0") BEGIN $(date +%s) / $(date)"

# set log verbocity for Cnode.
# To increase log verbosity run this script as `./setup_as_service.sh <verbocity level>`` and 
#    restart the sevice 
verb="${1:-1}"

OS_SYSTEM=`uname -s`
if [[ "$OS_SYSTEM" == "Linux" ]];then
    SETUP_USER="$(id -u)"
    SETUP_GROUP="$(id -g)"
else
    SETUP_USER="$(id -un)"
    SETUP_GROUP="$(id -gn)"
fi

Net_Name="${NETWORK_TYPE%%.*}"

if [[ "${OS_SYSTEM}" == "Linux" ]];then
    V_CPU=`nproc`
########################################################################
########### Node Services for Linux (Ubuntu, CentOS & Oracle) ##########
USE_THREADS=$((V_CPU - 2))
SERVICE_FILE="/etc/systemd/system/${ServiceName}.service"
# SERVICE_FILE="/usr/lib/systemd/system/${ServiceName}.service"

if [[ "$NODE_TYPE" == "RUST"  ]]; then
#=====================================================
# Rust node on Linux ##
SVC_FILE_CONTENTS=$(cat <<-_ENDCNT_
[Unit]
Description=Everscale Validator RUST Node
After=network.target
StartLimitIntervalSec=0
[Service]
Type=simple
Restart=always
RestartSec=1
User=$USER
LimitNOFILE=2048000
ExecStart=$CALL_RN
[Install]
WantedBy=multi-user.target
_ENDCNT_
)

else   # node type select
#=====================================================
# C++ node on Linux
SVC_FILE_CONTENTS=$(cat <<-_ENDCNT_
[Unit]
Description=Everscale Validator C++ Node
After=network.target
StartLimitIntervalSec=0
[Service]
Type=simple
Restart=always
RestartSec=1
User=$USER
LimitNOFILE=2048000
ExecStart=/bin/bash -c "exec $CALL_VE -v $verb -t $USE_THREADS ${C_ENGINE_ADDITIONAL_PARAMS} -C ${TON_WORK_DIR}/etc/ton-global.config.json --db ${TON_WORK_DIR}/db >> ${TON_LOG_DIR}/${CNODE_LOG_FILE} 2>&1"
[Install]
WantedBy=multi-user.target
_ENDCNT_
)
fi
echo "${SVC_FILE_CONTENTS}" > ${SCRIPT_DIR}/tmp.txt
sudo mv -f ${SCRIPT_DIR}/tmp.txt ${SERVICE_FILE}
sudo chown root:root ${SERVICE_FILE}
sudo chmod 644 ${SERVICE_FILE}
Lunux_Distrib="$(hostnamectl |grep 'Operating System'|awk '{print $3}')"
if [[ "${Lunux_Distrib}" == "CentOS" ]] || [[ "${Lunux_Distrib}" == "Oracle" ]];then
    # ll -Z /etc/systemd/system
    sudo chcon system_u:object_r:etc_t:s0 ${SERVICE_FILE}
fi
sudo systemctl daemon-reload
sudo systemctl enable ${ServiceName}

echo
echo -e "To start node service run ${BoldText}${GreeBack}sudo service ${ServiceName} start${NormText}"
echo "To restart updated node or service - run all follow commands:"
echo
echo "sudo systemctl disable ${ServiceName}"
echo "sudo systemctl daemon-reload"
echo "sudo systemctl enable ${ServiceName}"
echo "sudo service ${ServiceName} restart"

# ************************************************************
# ************** Setup watchdog service **********************
# SERVICE_FILE="/etc/systemd/system/nodewd.service"
# SVC_FILE_CONTENTS=$(cat <<-_ENDCNT_
# [Unit]
# Description=Everscale Validator watchdog for node
# After=network.target
# StartLimitIntervalSec=0
# [Service]
# Type=simple
# PIDFile=${TON_LOG_DIR}/nodewd.pid
# Restart=always
# RestartSec=3
# User=$USER
# Group=$SETUP_GROUP
# LimitNOFILE=2048000
# Environment="HOME=$HOME"
# WorkingDirectory=${SCRIPT_DIR}
# ExecStart=/bin/bash -c "exec script --return --quiet --append --command  \"${SCRIPT_DIR}/watchdog.sh 2>&1 >> ${TON_LOG_DIR}/time_diff.log\""
# [Install]
# WantedBy=multi-user.target
# _ENDCNT_
# )
# echo "${SVC_FILE_CONTENTS}" > ${SCRIPT_DIR}/tmp.txt
# sudo mv -f ${SCRIPT_DIR}/tmp.txt ${SERVICE_FILE}
# sudo chown root:root ${SERVICE_FILE}
# sudo chmod 644 ${SERVICE_FILE}
# Lunux_Distrib="$(hostnamectl |grep 'Operating System'|awk '{print $3}')"
# if [[ "${Lunux_Distrib}" == "CentOS" ]] || [[ "${Lunux_Distrib}" == "Oracle" ]];then
#     sudo chcon system_u:object_r:etc_t:s0 ${SERVICE_FILE}
# fi
# sudo systemctl daemon-reload
# sudo systemctl enable nodewd

# echo
# echo -e "To start WATCHDOG service run ${BoldText}${GreeBack}sudo service nodewd start${NormText}"
# echo "To restart updated node or service - run all follow commands:"
# echo
# echo "sudo systemctl disable nodewd"
# echo "sudo systemctl daemon-reload"
# echo "sudo systemctl enable nodewd"
# echo "sudo service nodewd restart"

else   #  -------------------- OS select
# Next  for FreeBSD
########################################################################
############## FreeBSD rc daemon ########################################
echo "---INFO: Setup rc daemon..."
V_CPU=`sysctl -n hw.ncpu`
USE_THREADS=$((V_CPU - 2))
SERVICE_FILE="/usr/local/etc/rc.d/${ServiceName}"
cp -f ${CONFIGS_DIR}/FB_service.tmplt ${SCRIPT_DIR}/tmp.txt
sed -i.bak "s%N_LOG_DIR%${NODE_LOGS_ARCH}%" ${SCRIPT_DIR}/tmp.txt

if [[ "$NODE_TYPE" == "RUST"  ]]; then
# =====================================================
# Rust node
pidfile="$NODE_LOGS_ARCH/daemon.pid"
pidfile_child="$NODE_LOGS_ARCH/${name}.pid"
logfile="$NODE_LOGS_ARCH/${name}.log"

echo "Setup FreeBSD daemon for RNODE"
sed -i.bak "s%N_SERVICE_DESCRIPTION%Everscale RUST Node Daemon%" ${SCRIPT_DIR}/tmp.txt
sed -i.bak "s%N_USER%${USER}%g" ${SCRIPT_DIR}/tmp.txt
sed -i.bak "s%N_NODE_LOGS_ARCH%${NODE_LOGS_ARCH}%g" ${SCRIPT_DIR}/tmp.txt
sed -i.bak "s%N_NODE_LOG_FILE%${R_LOG_DIR}/${RNODE_LOG_FILE}%g" ${SCRIPT_DIR}/tmp.txt
sed -i.bak "s%N_COMMAND%$CALL_RN%" ${SCRIPT_DIR}/tmp.txt
sed -i.bak "s%N_ARGUMENTS% %" ${SCRIPT_DIR}/tmp.txt

else   #  -------------------- node type select
# =====================================================
# C++ node

echo "Setup FreeBSD daemon for CNODE"
sed -i.bak "s%N_SERVICE_DESCRIPTION%Everscale C++ Node Daemon%" ${SCRIPT_DIR}/tmp.txt
sed -i.bak "s%N_USER%${USER}%" ${SCRIPT_DIR}/tmp.txt
sed -i.bak "s%N_NODE_LOGS_ARCH%${NODE_LOGS_ARCH}%g" ${SCRIPT_DIR}/tmp.txt
sed -i.bak "s%N_NODE_LOG_FILE%${TON_LOG_DIR}/${CNODE_LOG_FILE}%g" ${SCRIPT_DIR}/tmp.txt
sed -i.bak "s%N_COMMAND%$CALL_VE%" ${SCRIPT_DIR}/tmp.txt
sed -i.bak "s%N_ARGUMENTS%-v $verb -t $USE_THREADS ${C_ENGINE_ADDITIONAL_PARAMS} -C ${TON_WORK_DIR}/etc/ton-global.config.json --db ${TON_WORK_DIR}/db >> ${TON_LOG_DIR}/${CNODE_LOG_FILE}%" ${SCRIPT_DIR}/tmp.txt

fi   # -------------------- node type select

########################################################################

sudo mv -f ${SCRIPT_DIR}/tmp.txt ${SERVICE_FILE}
sudo chown root:wheel ${SERVICE_FILE}
sudo chmod 755 ${SERVICE_FILE}
[[ -z "$(cat /etc/rc.conf | grep '${ServiceName}_enable')" ]] && sudo sh -c "echo ' ' >> /etc/rc.conf; echo '${ServiceName}_enable="YES"' >> /etc/rc.conf"
ls -al ${SERVICE_FILE}

echo -e "To start node service run ${BoldText}${GreeBack}'service ${ServiceName} start'${NormText}"
echo "To restart updated node or service run 'service ${ServiceName} restart'"
echo
# ************************************************************
# ************** Setup watchdog service **********************
# echo "Setup FreeBSD daemon for CNODE"
# SERVICE_FILE="/usr/local/etc/rc.d/nodewd"
# cp -f ${CONFIGS_DIR}/FB_service.tmplt ${SCRIPT_DIR}/tmp.txt
# sed -i.bak "s%${ServiceName}%nodewd%g" ${SCRIPT_DIR}/tmp.txt
# sed -i.bak "s%N_LOG_DIR%${NODE_LOGS_ARCH}%" ${SCRIPT_DIR}/tmp.txt
# sed -i.bak "s%N_SERVICE_DESCRIPTION%Everscale Node WatchDog Daemon%" ${SCRIPT_DIR}/tmp.txt
# sed -i.bak "s%N_USER%${USER}%" ${SCRIPT_DIR}/tmp.txt
# sed -i.bak "s%N_NODE_LOGS_ARCH%${NODE_LOGS_ARCH}%g" ${SCRIPT_DIR}/tmp.txt
# sed -i.bak "s%N_NODE_LOG_FILE%${TON_LOG_DIR}/${CNODE_LOG_FILE}%g" ${SCRIPT_DIR}/tmp.txt
# sed -i.bak "s%N_COMMAND%cd%" ${SCRIPT_DIR}/tmp.txt
# sed -i.bak "s%N_ARGUMENTS%${SCRIPT_DIR} && ${SCRIPT_DIR}/watchdog.sh%" ${SCRIPT_DIR}/tmp.txt

# sudo mv -f ${SCRIPT_DIR}/tmp.txt ${SERVICE_FILE}
# sudo chown root:wheel ${SERVICE_FILE}
# sudo chmod 755 ${SERVICE_FILE}
# [[ -z "$(cat /etc/rc.conf | grep 'nodewd_enable')" ]] && sudo sh -c "echo ' ' >> /etc/rc.conf; echo 'nodewd_enable="YES"' >> /etc/rc.conf"
# ls -al ${SERVICE_FILE}

# echo -e "To start node watchdog service run ${BoldText}${GreeBack}'service nodewd start'${NormText}"
# echo "To restart updated node or service run 'service nodewd restart'"
# echo


echo "---INFO: rc daemon setup DONE!"
fi   # ############################## OS select

echo
echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date)"
echo "================================================================================================"

exit 0
