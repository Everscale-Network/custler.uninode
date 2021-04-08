## custler.uninode

# Universal scripts set 
#### - Support both Rust and C++ nodes
#### - Support both DePool and msig validations  
#### - Support both fift and solidity electors
#### - Run on Ubuntu 20.04, CentOS 8.2, FreeBSD 12.2/13 (for Linux - latest kernel preferable)

## 1. Setting environment
First of all you have to set the follow environment variables for certain network at the beginning of **$HOME/custler.uninode/scripts/env.sh**:  
```bash
export NETWORK_TYPE="fld.ton.dev"
export NODE_TYPE="CPP"                  # can be 'RUST' or 'CPP'
export ELECTOR_TYPE="fift"              # can be 'solidity' or 'fift'
export STAKE_MODE="depool"              # can be 'msig' or 'depool'
export MAX_FACTOR=3

export MSIG_FIX_STAKE=45000             # fixed stake for 'msig' mode (tokens). if 0 - use whole stake
export VAL_ACC_INIT_BAL=95000           # Initial balance on validator account for full balance staking (if MSIG_FIX_STAKE=0)
export VAL_ACC_RESERVED=50              # Reserved amount staying on msig account in full staking mode

export TIK_REPLANISH_AMOUNT=5           # If Tik acc balance less 2 tokens, It will be auto topup with this amount

export LC_Send_MSG_Timeout=20           # time after Lite-Client send message to BC in seconds
```
## 2. Build nodes 
To build node run **./Nodes_Build.sh** from $HOME/custler.uninode/scripts/ folder. 
This script will build all binaries needed and has 3 options:  
```bash
./Nodes_Build.sh        # build both C++ and Rust nodes
./Nodes_Build.sh rust   # build Rust node and tools
./Nodes_Build.sh cpp    # build C++ node and toolws
```
After success build all executable files will be placed to $HOME/bin directory

## 3. Setup node and accounts
All you needs to setup your node - run **./Setup.sh** script from $HOME/custler.uninode/scripts/ folder. This script has no options and does the follow:
* remove old databases and logs if any
* create all needed dirs
* set proper url in tonos-cli config file
* setup logrotate service
* setup new keys for node
* setup service **tonnode** to run node as service
* generates 3 accounts and place files to $HOME/ton-keys

Setup.sh generates 3 accounts file sets:  
* depool account files in $HOME/DPKeys
* validator msig account files in $HOME/MSKeys_${HOSTNAME}
* Tik account files in $HOME/MSKeys_Tik
* finally, script place files to $HOME/ton-keys/ if it hasn't same files already

If you have not any accounts before, you can use just generated accounts. If you already has your accounts files in $HOME/ton-keys/ it will NOT be replaced. 

## 4. Start node and check syncronization  
  
After Setup script successfully finished, you can start node by starting it service:
* **service tonnode start** for FreeBSD
* **sudo service tonnode start** for Linux (CentOS / Ubuntu)

Then you can check node syncronizanion with the blockchain: 
```bash
./check_node_sync_status.sh
```
This script looped and will show you sync status every 1 min by default. It has 1 parameter - frequency of showing status in seconds:
```bash
./check_node_sync_status.sh 10      # show info every 10 secs
```
NB! On first start sync can start after some time, up to 30-60 mins

---------------
Not finished..

... to be continue