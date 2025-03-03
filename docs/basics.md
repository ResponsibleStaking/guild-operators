#### Architecture

The architecture for various components are already described at [docs.cardano.org](https://docs.cardano.org/explore-cardano/cardano-architecture/overview) by CF/IOHK. We will not reinvent the wheel :smile:

#### Manual software pre-requirements

Highly accurate system time is critical for operating a stake pool and therefore considered mandatory. Please install and configure chrony.

#### Pre-Requisites

!!! info "Reminder !!"
     You're expected to run the commands below from same session, using same working directories as indicated and using a `non-root user with sudo access`. You are expected to be familiar with this as part of pre-requisite skill sets for stake pool operators.

##### Set up OS packages, folder structure and fetch files from repo {: #os-prereqs}

The pre-requisites for Linux systems are automated to be executed as a single script. To download the pre-requisites scripts, execute the below:

```bash
mkdir "$HOME/tmp";cd "$HOME/tmp"
# Install curl
# CentOS / RedHat - sudo dnf -y install curl
# Ubuntu / Debian - sudo apt -y install curl
curl -sS -o prereqs.sh https://raw.githubusercontent.com/cardano-community/guild-operators/master/scripts/cnode-helper-scripts/prereqs.sh
chmod 755 prereqs.sh
```

Please familiarise with the syntax of `prereqs.sh` before proceeding. The usage syntax can be checked using `./prereqs.sh -h` , sample output below:

``` bash
Usage: prereqs.sh [-f] [-s] [-i] [-l] [-c] [-w] [-b <branch>] [-n <mainnet|testnet|guild|staging>] [-t <name>] [-m <seconds>]
Install pre-requisites for building cardano-node and using CNTools

-f    Force overwrite of all files including normally saved user config sections in env, cnode.sh and gLiveView.sh
      topology.json, config.json and genesis files normally saved will also be overwritten
-s    Skip installing OS level dependencies (Default: will check and install any missing OS level prerequisites)
-n    Connect to specified network instead of mainnet network (Default: connect to cardano mainnet network)
      eg: -n testnet
-t    Alternate name for top level folder, non alpha-numeric chars will be replaced with underscore (Default: cnode)
-m    Maximum time in seconds that you allow the file download operation to take before aborting (Default: 60s)
-l    Use system libsodium instead of IOG fork (Default: use libsodium from IOG fork)
-c    Install/Upgrade and build CNCLI with RUST
-w    Install/Upgrade Vacuumlabs cardano-hw-cli for hardware wallet support
-b    Use alternate branch of scripts to download - only recommended for testing/development (Default: master)
-i    Interactive mode (Default: silent mode)
```

Running without any parameters will run script in silent mode with OS Dependencies, install libsodium fork from IOG, and *NOT* force overwrite of all files (only static files will be overwritten, which should not contain user modifications):

``` bash
./prereqs.sh
. "${HOME}/.bashrc"
```

##### Folder structure

Running the script above will create the folder structure as per below, for your reference. You can replace the top level folder `/opt/cardano/cnode` by editing the value of `CNODE_HOME` in `~/.bashrc` and `$CNODE_HOME/files/env` files:


    /opt/cardano/cnode            # Top-Level Folder
    ├── ...
    ├── files                     # Config, genesis and topology files
    │   ├── ...
    │   ├── byron-genesis.json    # Byron Genesis file referenced in config.json
    │   ├── shelley-genesis.json  # Genesis file referenced in config.json
    │   ├── alonzo-genesis.json    # Alonzo Genesis file referenced in config.json
    │   ├── config.json           # Config file used by cardano-node
    │   └── topology.json         # Map of chain for cardano-node to boot from
    ├── db                        # DB Store for cardano-node
    ├── guild-db                  # DB Store for guild-specific tools and additions (eg: cncli, cardano-db-sync's schema)
    ├── logs                      # Logs for cardano-node
    ├── priv                      # Folder to store your keys (permission: 600)
    ├── scripts                   # Scripts to start and interact with cardano-node
    └── sockets                   # Socket files created by cardano-node
