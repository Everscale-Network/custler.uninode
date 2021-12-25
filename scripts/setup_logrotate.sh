#!/usr/bin/env bash

# (C) Sergey Tyurin  2020-10-19 10:00:00

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
echo "################################# logrotate setup script ###################################"
echo "+++INFO: $(basename "$0") BEGIN $(date +%s) / $(date)"

SETUP_USER="$(id -un)"
SETUP_GROUP="$(id -gn)"

#============================================
# set log rotate
# NB! - should be log '>>'  in run.sh or 'append' in service
CPP_NODE_LOG_FILE_NAME="${TON_LOG_DIR}/${CNODE_LOG_FILE}"
RUST_NODE_LOG_FILE_NAME="${R_LOG_DIR}/${RNODE_LOG_FILE}"

NODES_LOG_ROT=$(cat <<-_ENDNLR_
$CPP_NODE_LOG_FILE_NAME {
    su $SETUP_USER $SETUP_GROUP
    daily
    copytruncate
    dateext
    dateyesterday
    missingok
    rotate 2
    maxage 3
    maxsize 50G
    sharedscripts
    notifempty
    nocompress
    postrotate
      LFLZ="\$(ls ${CPP_NODE_LOG_FILE_NAME}-20*  2>/dev/null)"
      [ ! -z \${LFLZ} ] && 7za a -t7z -m0=ppmd -sdel "${NODE_LOGS_ARCH}/\${LFLZ##*/}.7z" "\${LFLZ}" &>/dev/null
      find ${NODE_LOGS_ARCH}/${CNODE_LOG_FILE}* -mtime +${NODE_LOGs_ARCH_KEEP_DAYS} -delete
    endscript
}

$RUST_NODE_LOG_FILE_NAME {
    su $SETUP_USER $SETUP_GROUP
    daily
    copytruncate
    dateext
    dateyesterday
    missingok
    rotate 2
    maxage 3
    maxsize 50G
    sharedscripts
    notifempty
    nocompress
    postrotate
      LFLZ="\$(ls ${RUST_NODE_LOG_FILE_NAME}-20*  2>/dev/null)"
      [ ! -z \${LFLZ} ] && 7za a -t7z -m0=ppmd -sdel "${NODE_LOGS_ARCH}/\${LFLZ##*/}.7z" "\${LFLZ}" &>/dev/null
      find ${NODE_LOGS_ARCH}/${RNODE_LOG_FILE}* -mtime +${NODE_LOGs_ARCH_KEEP_DAYS} -delete
      LFLZ="\$(ls ${RNODE_LOG_FILE%%.*}_*  2>/dev/null)"
      [ ! -z \${LFLZ} ] && 7za a -t7z -m0=ppmd -sdel "${NODE_LOGS_ARCH}/\${LFLZ##*/}.7z" "\${LFLZ}" &>/dev/null
      find ${NODE_LOGS_ARCH}/${RNODE_LOG_FILE}* -mtime +${NODE_LOGs_ARCH_KEEP_DAYS} -delete
    endscript
}
_ENDNLR_
)

echo "$NODES_LOG_ROT" > rot_nodelog.cfg

OS_SYSTEM=`uname -s`
if [[ "$OS_SYSTEM" == "Linux" ]];then
#==============================================================================
# Ubuntu, CentOS & Oracle
    Lunux_Distrib="$(hostnamectl |grep 'Operating System'|awk '{print $3}')"
    LOGROT_FILE="/etc/logrotate.d/${ServiceName}"
    Root_UN="$(id -un root)"
    Root_GN="$(id -gn root)"
    sudo cp -f rot_nodelog.cfg ${LOGROT_FILE}
    sudo chown ${Root_UN}:${Root_GN} ${LOGROT_FILE}
    sudo chmod 644 ${LOGROT_FILE}
    if [[ "${Lunux_Distrib}" == "CentOS" ]] || [[ "${Lunux_Distrib}" == "Oracle" ]];then
        # ll -Z /etc/systemd/system
        sudo chcon system_u:object_r:etc_t:s0 ${LOGROT_FILE}
    fi
Run_Script=$(cat <<-_ENDNLR_
#!/bin/sh

/usr/sbin/logrotate -l ${NODE_LOGS_ARCH}/logrotate.log -s ${NODE_LOGS_ARCH}/logrotate.status -f /etc/logrotate.conf
EXITVALUE=\$?
if [ \$EXITVALUE != 0 ]; then
    /usr/bin/logger -t logrotate "ALERT exited abnormally with [\$EXITVALUE]"
fi
exit \$EXITVALUE

_ENDNLR_
)
    Cron_Run_File="/etc/cron.daily/logrotate"
    echo "$Run_Script" > tmp.txt
    sudo mv -f tmp.txt ${Cron_Run_File}
    sudo chown ${Root_UN}:${Root_GN} ${Cron_Run_File}
    sudo chmod 755 ${Cron_Run_File}
    if [[ "${Lunux_Distrib}" == "CentOS" ]] || [[ "${Lunux_Distrib}" == "Oracle" ]];then
        # ll -Z /etc/systemd/system
        sudo chcon system_u:object_r:etc_t:s0 ${Cron_Run_File}
    fi
else
#==============================================================================
# FreeBSD
    LOGROT_FILE="/usr/local/etc/logrotate.d/${ServiceName}"
    Root_UN="$(id -un root)"
    Root_GN="$(id -gn root)"
    sudo cp -f rot_nodelog.cfg ${LOGROT_FILE}
    sudo chown ${Root_UN}:${Root_GN} ${LOGROT_FILE}
    sudo chmod 644 ${LOGROT_FILE}

Run_Script=$(cat <<-_ENDNLR_
#!/bin/sh

/usr/local/sbin/logrotate -l ${NODE_LOGS_ARCH}/logrotate.log -s ${NODE_LOGS_ARCH}/logrotate.status -f /usr/local/etc/logrotate.conf
EXITVALUE=\$?
if [ \$EXITVALUE != 0 ]; then
    /usr/bin/logger -t logrotate "ALERT exited abnormally with [\$EXITVALUE]"
fi
exit \$EXITVALUE

_ENDNLR_
)
    Cron_Run_File="/usr/local/etc/periodic/daily/logrotate"
    echo "$Run_Script" > tmp.txt
    sudo mv -f tmp.txt ${Cron_Run_File}
    sudo chown ${Root_UN}:${Root_GN} ${Cron_Run_File}
    sudo chmod 755 ${Cron_Run_File}
fi
#===========================

echo "---INFO: Logrotate file created:"
ls -alhFpZ ${LOGROT_FILE}

echo
echo "+++INFO: $(basename "$0") FINISHED $(date +%s) / $(date)"
echo "================================================================================================"

exit 0
