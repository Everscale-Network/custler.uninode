## custler.uninode

# Universal scripts set 
#### - Support both Rust and C++ nodes
#### - Support both DePool and msig validations  
#### - Support both fift and solidity electors
#### - Run on Ubuntu 20.04, CentOS 8.2, FreeBSD 12.2/13 (for Linux - latest kernel preferable)

## 1. Setting environment
First of all you have to set the follow environment variables for certain network at the beginning of **$HOME/custler.uninode/scripts/env.sh**: 

```bash
export NETWORK_TYPE="fld.ton.dev"   # can be main.* / net.* / fld.* / rustnet.*
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
./Nodes_Build.sh cpp    # build C++ node and tools
```  
This script also build **tonos-cli**, **tvm_linker**, **solc (Solidity compiler)** from the respective repositories , from master branch. You can set commit number in "# GIT addresses & commits " section in 'env.sh'

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
* depool account files in **`$HOME/DPKeys`**
* validator msig (SafeCode) account files in **`$HOME/MSKeys_${HOSTNAME}`** with 3 custodians 
* Tik (SafeCode) account files in **`$HOME/MSKeys_Tik`** - Safe msig with 1 custodian for tik-tok depool
* finally, script place files to **`$HOME/ton-keys/`**` if it hasn't same files already

If you have not any accounts before, you can use just generated accounts. If you already has your accounts files in **`$HOME/ton-keys/`**` it will NOT be replaced. 

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

## 5. Deploy accounts

### 5.1 Get test tokens in FLD network  
In FLD network where is free giver called **"Marvin"**. You can ask him for test 100K tokens once for each account. For example, for you validator msig (**`${KEYS_DIR}/${DST_NAME}.addr`**) you can use script **`Get_tokens_from_Marvin.sh`**

### 5.2 Deploy validator msig with few custodians  

To deploy your validator main account, after receved tokens on it, use **`MS-Wallet_deploy.sh`** script. By default, it has 3 custodians and 2 is enought to sign a transaction  

```bash
MS-Wallet_deploy.sh $VALIDATOR_NAME Safe 3 2
```

### 5.3 Setup and deploy DePool smartcontract

#### 5.3.1 Setup DePool parametrs
First of all we to have set DePool parametrs at the beginnig of deploy script **`DP4_depool_deploy.sh`**  
```bash
ValidatorAssuranceT=100000      # Assurance in tokens
MinStakeT=10                    # Min DePool assepted stake in tokens
ParticipantRewardFraction=95    # In % participant share from reward
BalanceThresholdT=20 
```
These parametrs cannot be changed after deploy the DePool.

All about Depool you can find in <a href="https://docs.ton.dev/86757ecb2/p/04040b-run-depool-v3" target="_blank">**Run DePool v3**</a>

#### 5.3.2 Send tokens to DePool account  
To send initial balance to DePool account use script **`transfer_amount.sh`**

```bash
./transfer_amount.sh $VALIDATOR_NAME depool 50 new
```
where:
* **`$VALIDATOR_NAME`** - file name of `${VALIDATOR_NAME}.addr` file with address of your msig
* **`depool`** - file name of `depool.addr` file with address of your DePool
* **50** - initial balance for deploy depool
* **new** - set transaction flag **`bounce`** to false to tranfer tokens to undeployed address

next we have to sign the transaction by script **`Sign_Trans.sh`**
```bash
./Sign_Trans.sh
```
#### 5.3.3 Depoloy DePool contract
Now you can deploy the DePool contract by 
```bash
./DP4_depool_deploy.sh
```

### 5.4 Deploy Tik account
For tik-tok DePool action we use separate SafeCode msig account with 1 custodian and address in **`${KEYS_DIR}/Tik.addr`** file  
To deploy Tik smartcontract use the same script as for msig  
```bash
./transfer_amount.sh $VALIDATOR_NAME Tik 10 new
./Sign_Trans.sh
./MS-Wallet_deploy.sh Tik Safe 1 1
```

## 6. Start validation 




---------------
Not finished..

... to be continue