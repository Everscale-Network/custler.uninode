#!/usr/bin/env bash

# Ilya Vasilyev aka Nadz Goldman, summer, 2021
# Based on scripts by (C) Sergey Tyurin aka Custler

# Very ugly and simple script for Nagios/Icinga monitoring


# vars
ftHome="/home/freeton"
scriptsDir="${ftHome}/custler.uninode/scripts"

STATE_OK=0              # define the exit code if status is OK
STATE_WARNING=1         # define the exit code if status is Warning
STATE_CRITICAL=2        # define the exit code if status is Critical
STATE_UNKNOWN=3         # define the exit code if status is Unknown

VAL_ENGINE_CONSOLE_IP="127.0.0.1"
VAL_ENGINE_CONSOLE_PORT="3030"
KEYS_DIR="${ftHome}/ton-keys"
CALL_VC="${ftHome}/bin/validator-engine-console -k ${KEYS_DIR}/client -p ${KEYS_DIR}/server.pub -a ${VAL_ENGINE_CONSOLE_IP}:${VAL_ENGINE_CONSOLE_PORT} -t 5"

CALL_liteClientBin="${ftHome}/bin/lite-client -p ${KEYS_DIR}/liteserver.pub -a 127.0.0.1:3031 -t 5"
tonCliBin="${ftHome}/bin/tonos-cli"
tonCliConf="${scriptsDir}/tonos-cli.conf.json"

TON_LOG_DIR="/var/ton-work"

electionsDir="${ftHome}/ton-keys/elections"

validatorLogFile="${TON_LOG_DIR}/validator.log"

version="0.1.0"

isFileExist() {
  if [ -f "${1}" ]; then
      echo 1
  else 
      echo 0
  fi
}

# show usage/help info and exit
usage() {
  echo "Usage: $0, ver. ${version}
-h   -- this help
-w   -- warning
-c   -- critical
-t   -- type
        type can be
          timeDiff
          checkPartNextValidation
          checkElectionParticipation
          checkADNLInP34ViaTonCli
          checkADNLInP34ViaLiteClient
          showCurrentADNL

          adnlFromElectionLogInP34ViaTonCli
          adnlFromElectionLogInP34ViaLiteClient
          adnlFromElectionLogInP34ViaTonCliShow
          adnlFromElectionLogInP34ViaLiteClientShow

      timeDiff must be with warning and critical params

--
Disabled:
          isValidatingNext

  " 1>&2
  exit $STATE_UNKNOWN
}

# Get current Time Diff
Get_TimeDiff() { 
    VEC_OUTPUT=$( $CALL_VC -c "getstats" -c "quit" 2>&1 | cat )
    NODE_DOWN=$( echo "${VEC_OUTPUT}" | grep 'Connection refused' | cat )
    if [[ -n $NODE_DOWN ]]
    then
      echo "Node Down"
      return
    fi
    CURR_TD_NOW=$( echo "${VEC_OUTPUT}" | grep 'unixtime' | awk '{print $2}' )
    CHAIN_TD=$( echo "${VEC_OUTPUT}" | grep 'masterchainblocktime' | awk '{print $2}' )
    TIME_DIFF=$((CURR_TD_NOW - CHAIN_TD))
    if [[ -z $CHAIN_TD ]];then
      echo "No TimeDiff Info"
    else
      echo "$TIME_DIFF"
    fi
}

timeDiffCheck() {
  warnValue=${1}
  critValue=${2}
  TIME_DIFF=$( Get_TimeDiff )

  if [[ "$TIME_DIFF" == "Node Down" ]]
  then
    # echo "${Current_Net} Time: $(date +'%F %T %Z') ###-ALARM! NODE IS DOWN."
    echo "CRITICAL Node time diff: $TIME_DIFF | timeDiff=$TIME_DIFF;${warnValue};${critValue};;"
    exit $STATE_CRITICAL
  elif [[ "$TIME_DIFF" == "No TimeDiff Info" ]]
  then
    # echo "${Current_Net} Time: $(date +'%F %T %Z') --- No masterchain blocks received yet."
    echo "UNKNOWN - Node time diff: $TIME_DIFF | timeDiff=$TIME_DIFF;${warnValue};${critValue};;"
    exit $STATE_UNKNOWN
  elif [[ "$TIME_DIFF" -lt "$warnValue" ]]
  then
    echo "OK - Node time diff: $TIME_DIFF | timeDiff=$TIME_DIFF;${warnValue};${critValue};;"
    exit $STATE_OK
  elif [[ "$TIME_DIFF" -ge "$warnValue" && "$TIME_DIFF" -lt "$critValue" ]]
  then
    echo "WARNING - Node time diff: $TIME_DIFF | timeDiff=$TIME_DIFF;${warnValue};${critValue};;"
    exit $STATE_WARNING
  elif [[ "$TIME_DIFF" -ge "$critValue" ]]
  then
    echo "CRITICAL - Node time diff: $TIME_DIFF | timeDiff=$TIME_DIFF;${warnValue};${critValue};;"
    exit $STATE_CRITICAL
  else
    echo "UNKNOWN - Node time diff: $TIME_DIFF | timeDiff=$TIME_DIFF;${warnValue};${critValue};;"
    exit $STATE_UNKNOWN
  fi
}

checkPartNextValidation() {
  if tail -r ${validatorLogFile} | awk '!flag; /Check participations script/{flag = 1};' | tail -r | awk '1;/-----/{exit}' | grep "You will start validate" > /dev/null 2>&1
  then
    echo "OK - next validation: 1 | nextValidation=1;;;;"
    exit $STATE_OK
  else
    echo "CRITICAL - next validation: 0 | nextValidation=0;;;;"
    exit $STATE_CRITICAL
  fi  
}

checkElectionParticipation() {
  if tail -r  ${validatorLogFile} | awk '!flag; /Participate script/{flag = 1};' | tail -r | sed -n '/Participate script/,/###/p' | sed \$d | grep "SUCCESSFULLY" > /dev/null 2>&1
  then
    echo "OK - participate in election: 1 | partInElection=1;;;;"
    exit $STATE_OK
  else
    echo "CRITICAL - participate in election: 0 | partInElection=0;;;;"
    exit $STATE_CRITICAL
  fi  
}

findMyCurrentADNLInCustlerLog() {
  # node just deployed
  str=$( tail -r ${validatorLogFile} | grep -B28 "Participate script" | tail -r | grep -A2 "Validating_Start" | grep -cv "\--" )
  if [[ $str -lt 3 ]]
  then
    adnlKey=0
  elif [[ $str -eq 3 ]]
  then
    lastValues=$( tail -r ${validatorLogFile} | grep -B28 "Participate script" | tail -r | grep -A2 "Validating_Start" | grep -v "\--" | tail -n 3 )
    validatingPeriod=$( echo "${lastValues}" | grep "Validating_Start" )
    valStart=$( echo "${validatingPeriod}" | grep "Validating_Start" | awk {'print $2'} )
    valEnd=$( echo "${validatingPeriod}" | grep "Validating_Start" | awk {'print $5'} )
    curDate=$( date +%s )
    if [[ $curDate -ge $valStart && $curDate -le $valEnd ]]
    then
      adnlKey=$( echo "${lastValues}" | awk {'$4'} )
    else
      adnlKey=0
    fi
  else
    # node already working
    lastValues=$( tail -r ${validatorLogFile} | grep -B28 "Participate script" | tail -r | grep -A2 "Validating_Start" | grep -v "\--" | tail -n 6 )
    firstRange=$( echo "${lastValues}" | head -n3 )
    secondRange=$( echo "${lastValues}" | tail -n3 )

    valStart1=$( echo "${firstRange}" | grep "Validating_Start" | awk {'print $2'}  )
    valEnd1=$( echo "${firstRange}" | grep "Validating_Start" | awk {'print $5'}  )

    valStart2=$( echo "${secondRange}" | grep "Validating_Start" | awk {'print $2'}  )
    valEnd2=$( echo "${secondRange}" | grep "Validating_Start" | awk {'print $5'}  )

    curDate=$( date +%s )
    if [[ $curDate -ge $valStart1 && $curDate -le $valEnd1 ]]
    then
      adnlKey=$( echo "${firstRange}" | grep "ADNL" | awk {'print $4'} )
    elif [[ $curDate -ge $valStart2 && $curDate -le $valEnd2 ]]
    then
      adnlKey=$( echo "${secondRange}" | grep "ADNL" | awk {'print $4'} )
    else
     adnlKey=0
    fi
  fi
  echo "${adnlKey}"
}

checkADNLInP34ViaTonCli() {
  myADNL=$( findMyCurrentADNLInCustlerLog )
  if [[ "${myADNL}" != 0 ]]
  then
    adnlInP34ViaTonCli=$( ${tonCliBin} -c ${tonCliConf} getconfig 34 | grep -i ${myADNL} )
    if [[ -n "${adnlInP34ViaTonCli}" ]]
    then
      echo "OK - ADNL in p34 via tonos-cli: 1 | adnlInP34ViaTonCLi=1;;;;"
      exit $STATE_OK
    else
      echo "CRITICAL - ADNL in p34 via tonos-cli: 0 | adnlInP34ViaTonCLi=0;;;;"
      exit $STATE_CRITICAL
    fi
  else
    echo "UNKNOWN - ADNL in p34 via tonos-cli: 0 | adnlInP34ViaTonCLi=0;;;;"
    exit $STATE_UNKNOWN
  fi
}

checkADNLInP34ViaLiteClient() {
  myADNL=$( findMyCurrentADNLInCustlerLog )
  if [[ "${myADNL}" != 0 ]]
  then
    adnlInP34ViaLiteClient=$( $CALL_liteClientBin -rc 'getconfig 34' -rc 'quit' 2>/dev/null | grep -i ${myADNL} )
    if [[ -n "${adnlInP34ViaLiteClient}" ]]
    then
      echo "OK - ADNL in p34 via lite-client: 1 | adnlInP34ViaLiteClient=1;;;;"
      exit $STATE_OK
    else
      echo "CRITICAL - ADNL in p34 via lite-client: 0 | adnlInP34ViaLiteClient=0;;;;"
      exit $STATE_CRITICAL
    fi
  else
    echo "UNKNOWN - ADNL in p34 via lite-client: 0 | adnlInP34ViaLiteClient=0;;;;"
    exit $STATE_UNKNOWN
  fi
}


##################################################
adnlFromElectionLogInP34ViaTonCli() {
  myRes=$( checkADNLFromElectionLog "tonoscli" )
  # varLen=${#myRes}
  # if [[ $varLen -gt 2 && -n ${myRes} ]]
  if [[ -n ${myRes} ]]
  then
    echo "OK - ADNL from election log in p34 via tonos-cli: 1 | adnlInP34ViaTonosCliFromELog=1;;;;"
    exit $STATE_OK
  else
    myRes=$( lastChance "tonoscli" )
    varLen=${#myRes}
    if [[ $varLen -gt 60 ]]
    then
      echo "OK - ADNL from election log in p34 via tonos-cli: 1 | adnlInP34ViaTonosCliFromELog=1;;;;"
      exit $STATE_OK
    else
      echo "CRITICAL - ADNL from election log in p34 via tonos-cli: 0 | adnlInP34ViaTonosCliFromELog=0;;;;"
      exit $STATE_CRITICAL
    fi
  fi
}

adnlFromElectionLogInP34ViaLiteClient() {
  myRes=$( checkADNLFromElectionLog "liteclient" )
  varLen=${#myRes}
  if [[ $varLen -gt 1 && -n ${myRes} ]]
  then
    echo "OK - ADNL from election log in p34 via lite-client: 1 | adnlInP34ViaLiteClientFromELog=1;;;;"
    exit $STATE_OK
  else
    myRes=$( lastChance "liteclient" )
    varLen=${#myRes}
    if [[ $varLen -gt 60 ]]
    then
      echo "OK - ADNL from election log in p34 via lite-client: 1 | adnlInP34ViaLiteClientFromELog=1;;;;"
      exit $STATE_OK
    else
      echo "CRITICAL - ADNL from election log in p34 via lite-client: 0 | adnlInP34ViaLiteclientFromELog=0;;;;"
      exit $STATE_CRITICAL
    fi
  fi
}

adnlFromElectionLogInP34ViaTonCliShow() {
  myRes=$( checkADNLFromElectionLog "tonoscli" )
  varLen=${#myRes}
  if [[ $varLen -gt 1 && -n ${myRes} ]]
  then  
    echo "OK - ADNL from election log in p34 via tonos-cli show: ${myRes} | adnlInP34ViaTonosCliFromELogShow=${myRes};;;;"
    exit $STATE_OK
  else
    myRes=$( lastChance "tonoscli" )
    varLen=${#myRes}
    if [[ $varLen -gt 60 ]]
    then
      echo "OK - ADNL from election log in p34 via tonos-cli show: ${myRes} | adnlInP34ViaTonosCliFromELogShow=${myRes};;;;"
      exit $STATE_OK
    else
      echo "CRITICAL - ADNL from election log in p34 via tonos-cli show: 0 | adnlInP34ViaTonosCliFromELogShow=0;;;;"
      exit $STATE_CRITICAL
    fi
  fi
}

adnlFromElectionLogInP34ViaLiteClientShow() {
  myRes=$( checkADNLFromElectionLog "liteclient" )
  varLen=${#myRes}
  if [[ $varLen -gt 1 && -n ${myRes} ]]
  then
    echo "OK - ADNL from election log in p34 via lite-client: ${myRes} | adnlInP34ViaLiteClientFromELogShow=${myRes};;;;"
    exit $STATE_OK
  else
    myRes=$( lastChance "liteclient" )
    varLen=${#myRes}
    if [[ $varLen -gt 60 ]]
    then
      echo "OK - ADNL from election log in p34 via lite-client: ${myRes} | adnlInP34ViaLiteClientFromELogShow=${myRes};;;;"
      exit $STATE_OK
    else
      echo "CRITICAL - ADNL from election log in p34 via lite-client show: 0 | adnlInP34ViaLiteclientFromELogShow=0;;;;"
      exit $STATE_CRITICAL
    fi
  fi
}

checkADNLFromElectionLog() {
  checkViaClient=${1}  # can be tonoscli liteclient
  filesList=$( ls -1 ${electionsDir} | grep -o '[[:digit:]]*'.log | grep -vE "^\.log|0.log" | tail -n 6 )
  varLen=${#filesList}
  if [[ $varLen -le 1 ]]
  then
    echo 0
  else
    for fName in $filesList
    do
      adnlKey=$( grep "ADNL key" "${electionsDir}/${fName}" | awk {'print $3'} )

      if [[ ${checkViaClient} == "tonoscli" ]]
      then
        myResFromTonCli=$( findADNLInP34ViaTonCLi "${adnlKey}" )
        varLen=${#myResFromTonCli}
        if [[ $varLen -gt 2 && -n ${myResFromTonCli} ]]
        then
          echo "${adnlKey}"
        fi
      fi

      if [[ ${checkViaClient} == "liteclient" ]]
      then
        myResFromLiteClient=$( findADNLInP34ViaLiteClient "${adnlKey}" )
        varLen=${#myResFromLiteClient}
        if [[ $varLen -gt 2 && -n ${myResFromLiteClient} ]]
        then
          echo "${adnlKey}"
        fi
      fi
    done
  fi
}

findADNLInP34ViaTonCLi() {
    myADNL=${1}
    adnlInP34ViaTonCli=$( ${tonCliBin} -c ${tonCliConf} getconfig 34 2>/dev/null | grep -i "${myADNL}" )
    if [[ -n "${adnlInP34ViaTonCli}" ]]
    then
      echo "$myADNL"
    else
      echo 0
    fi
}

findADNLInP34ViaLiteClient(){
  myADNL=${1}
  adnlInP34ViaLiteClient=$( $CALL_liteClientBin -rc 'getconfig 34' -rc 'quit' 2>/dev/null | grep -i "${myADNL}" )
  if [[ -n "${adnlInP34ViaLiteClient}" ]]
  then
    echo "$myADNL"
  else
    echo 0
  fi
}

checkADNLInP34ViaTonCliFromCustlerLog() {
  myADNL=$( findMyCurrentADNLInCustlerLog )
  if [[ "${myADNL}" != 0 ]]
  then
    adnlInP34ViaTonCli=$( ${tonCliBin} -c ${tonCliConf} getconfig 34 | grep -i ${myADNL} )
    if [[ -n "${adnlInP34ViaTonCli}" ]]
    then
      echo "OK - ADNL in p34 via tonos-cli: 1 | adnlInP34ViaTonCLi=1;;;;"
      exit $STATE_OK
    else
      echo "CRITICAL - ADNL in p34 via tonos-cli: 0 | adnlInP34ViaTonCLi=0;;;;"
      exit $STATE_CRITICAL
    fi
  else
    echo "UNKNOWN - ADNL in p34 via tonos-cli: 0 | adnlInP34ViaTonCLi=0;;;;"
    exit $STATE_UNKNOWN
  fi
}

checkADNLInP34ViaLiteClientFromCustlerLog() {
  myADNL=$( findMyCurrentADNLInCustlerLog )
  if [[ "${myADNL}" != 0 ]]
  then
    adnlInP34ViaLiteClient=$( $CALL_liteClientBin -rc 'getconfig 34' -rc 'quit' 2>/dev/null | grep -i ${myADNL} )
    if [[ -n "${adnlInP34ViaLiteClient}" ]]
    then
      echo "OK - ADNL in p34 via lite-client: 1 | adnlInP34ViaLiteClient=1;;;;"
      exit $STATE_OK
    else
      echo "CRITICAL - ADNL in p34 via lite-client: 0 | adnlInP34ViaLiteClient=0;;;;"
      exit $STATE_CRITICAL
    fi
  else
    echo "UNKNOWN - ADNL in p34 via lite-client: 0 | adnlInP34ViaLiteClient=0;;;;"
    exit $STATE_UNKNOWN
  fi
}

lastChance() {
  checkVia=${1}
  lastADNLs=$( grep -i "Validator ADNL" ${validatorLogFile} | tail -n 6 | awk {'print $4'} )
  for i in $lastADNLs
  do
    if [[ $checkVia == "tonoscli" ]]
    then
      myRes=$( findADNLInP34ViaLiteClient "$i" )
    elif [[ $checkVia == "liteclient" ]]
    then
      myRes=$( findADNLInP34ViaTonCLi "$i" )
    fi
    varLen=${#myRes}
    if [[ $varLen -gt 60 ]]
    then
      echo "$myRes"
    fi
  done
}

### main script

if [ -z "${1}" ]
then
  usage
fi

while getopts ":w:c:t:h" myArgs
do
  case ${myArgs} in
    w) warnValue=${OPTARG} ;;
    c) critValue=${OPTARG} ;;
    t) typeCheck=${OPTARG} ;;
    h) usage ;;
    \?)  echo "Wrong option given. Check help ( $0 -h ) for usage."
        exit ${STATE_UNKNOWN}
        ;;
  esac
done

if [[ -n "${typeCheck}" ]]
then 
  if [[ "${typeCheck}" == "isValidatingNext" ]]
  then
    isValidatingNext
  elif [[ "${typeCheck}" == "isAddressActive" ]]
  then
    isAddressActive
  elif [[ ${typeCheck} == "timeDiff" && -n "${warnValue}" && -n "${critValue}" ]]
  then
    timeDiffCheck "${warnValue}" "${critValue}"
  elif [[ ${typeCheck} == "checkPartNextValidation" ]]
  then
    checkPartNextValidation
  elif [[ "${typeCheck}" == "checkElectionParticipation" ]]
  then
    checkElectionParticipation        
  elif [[ "${typeCheck}" == "checkADNLInP34ViaTonCli" ]]
  then
    checkADNLInP34ViaTonCli
  elif [[ "${typeCheck}" == "checkADNLInP34ViaLiteClient" ]]
  then
    checkADNLInP34ViaLiteClient
  elif [[ "${typeCheck}" == "showCurrentADNL" ]]
  then  
    findMyCurrentADNLInCustlerLog
  elif [[ "${typeCheck}" == "adnlFromElectionLogInP34ViaTonCli" ]]
  then
    adnlFromElectionLogInP34ViaTonCli
  elif [[ "${typeCheck}" == "adnlFromElectionLogInP34ViaLiteClient" ]]
  then
    adnlFromElectionLogInP34ViaLiteClient
  elif [[ "${typeCheck}" == "adnlFromElectionLogInP34ViaTonCliShow" ]]
  then
    adnlFromElectionLogInP34ViaTonCliShow
  elif [[ "${typeCheck}" == "adnlFromElectionLogInP34ViaLiteClientShow" ]]
  then
    adnlFromElectionLogInP34ViaLiteClientShow
  fi
else
  echo -e "Missing required parameter or parameters"
  usage
  exit ${STATE_UNKNOWN}
fi
