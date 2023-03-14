#!/bin/bash

# TODO: M Remove after testing
# set -x

ERROR="[ ERROR ]"
WARN="[ WARN ]"
INFO="[ INFO ]"

# Replace domain
export DOMAIN=${_DAPPNODE_GLOBAL_DOMAIN}
envsubst < /home/app/.pocket/config/config_template.json > /home/app/.pocket/config/config.json

#############
# FUNCTIONS #
#############

function start_downloading_ui () {
  echo "${INFO} Downloading snapshot UI - Starting"
  cd /home/app/dummyui && node app.js &
  echo "${INFO} Downloading snapshot UI - Started"
}

function stop_downloading_ui () {
  echo "${INFO} Downloading snapshot UI - Stopping"
  pkill node
  sleep 2
  echo "${INFO} Downloading snapshot UI - Stopped"
}

########
# MAIN #
########

[[ -d /home/app/.pocket/data/application.db ]] && is_update=true || is_update=false

echo "${INFO} isUpdate: ${is_update}"
echo "${INFO} pocket accounts list --datadir=/home/app/.pocket/"
pocket accounts list --datadir=/home/app/.pocket/
if ! [ "$?" -eq 0 ] ;then
  echo "${INFO} pocket accounts import-armored /home/app/.pocket/config/keyfile.json --datadir=/home/app/.pocket/ --pwd-decrypt --pwd-encrypt"
    pocket accounts import-armored /home/app/.pocket/config/keyfile.json --datadir=/home/app/.pocket/ --pwd-decrypt ${KEYFILE_PASSPHRASE} --pwd-encrypt ${KEYFILE_PASSPHRASE}
    if ! [ "$?" -eq 0 ] ;then
        echo "${ERROR} It has not been possible to import the wallet"
        sleep 1000
        exit 1
    fi
fi
## # Create an account if it doesn't exist
## if ! [ "$?" -eq 0 ] ;then
##  pocket accounts create --pwd ${KEYFILE_PASSPHRASE} --datadir=/home/app/.pocket/
## fi

# Set validator
echo "${INFO} pocket accounts set-validator --pwd --datadir=/home/app/.pocket/ account"
pocket accounts set-validator --pwd ${KEYFILE_PASSPHRASE} --datadir=/home/app/.pocket/ `pocket accounts list --datadir=/home/app/.pocket/ | cut -d' ' -f2- `
if ! [ "$?" -eq 0 ] ;then
    echo "${ERROR} It has not been possible to set the validator"
    sleep 1000
    exit 1
fi

# Check pocket node
echo "${INFO} pocket start --simulateRelay --datadir=/home/app/.pocket/"
pocket start --simulateRelay --datadir=/home/app/.pocket/ &
PID_SIMULATE_RELAY=$!
sleep 2
OUTPUT=$(curl -X POST --data '{"relay_network_id":"0021","payload":{"data":"{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBalance\",\"params\":[\"0x8D97689C9818892B700e27F316cc3E41e17fBeb9\", \"latest\"],\"id\":1}","method":"POST","path":"","headers":{}}}' https://pocket-pocket.${_DAPPNODE_GLOBAL_DOMAIN}/v1/client/sim)
if echo "$OUTPUT" | grep "no such host"; then
  echo "${ERROR} It has not been possible to simulate relay"
else
  echo "${INFO} OK"
fi
kill $PID_SIMULATE_RELAY

echo "${INFO} Check if initializing with SNAPSHOT..."
if [ "$NETWORK" == "mainnet" ] && ! $is_update; then
  echo "${INFO} SNAPSHOT Url: ${SNAPSHOT_URL}"
  echo "${INFO} Initializing with SNAPSHOT, it could take several hours..."
  start_downloading_ui
  mkdir -p /home/app/.pocket/data
  cd /home/app/.pocket/data

  # Use different tar arguments if the file ends with .tar.gz
  if [[ $SNAPSHOT_URL == *.tar.gz* ]]
  then
    TAR_ARGS=xvzf
  else
    TAR_ARGS=xvf
  fi

#uplink cp --access=1mg7uwv6EQNyvgCxAuXBb19BZAMne2T5Qkzc5LsahbpERiXviMvENvBKN5yTf85BRRBcetZ4NWaiBri9UyvVHFBN4vaaLTRJ5AJnWfThvqkS18ftS4hyZLJ1AGaoJpdVUp6uS7zsoHXr5E22J1cN5mj2kchajtNKK7fRB6Jq5Q6cmDd5aFS1n8y9AbG6RjJFpAcdXTssmDqqYmYcTfUs89C2SBBCHTvUyScLA3hUtFLa1Cp16okDZUzwh4miPgPjr5JboR3DJby15TAvKmFttNf9Vya5sTTtya6KnrAqtwTkbPE16Eo6VjtoWwbvgT3S2FmQw3h6LNzrT3QbXaiXzK18B49S5UXSH3RbXT2xvgTFA6pbv sj://pocket-public-blockchains-main/v0-snapshots/$(curl -s https://snapshot.nodes.pokt.network/latest.tar.gz | rev | cut -d'/' -f1|rev|cut -d'?' -f1) ./destination.tar.gz
  echo "${INFO} uplink cp --access=1mg7uwv6EQNyvgCxAuXBb19BZAMne2T5Qkzc5LsahbpERiXviMvENvBKN5yTf85BRRBcetZ4NWaiBri9UyvVHFBN4vaaLTRJ5AJnWfThvqkS18ftS4hyZLJ1AGaoJpdVUp6uS7zsoHXr5E22J1cN5mj2kchajtNKK7fRB6Jq5Q6cmDd5aFS1n8y9AbG6RjJFpAcdXTssmDqqYmYcTfUs89C2SBBCHTvUyScLA3hUtFLa1Cp16okDZUzwh4miPgPjr5JboR3DJby15TAvKmFttNf9Vya5sTTtya6KnrAqtwTkbPE16Eo6VjtoWwbvgT3S2FmQw3h6LNzrT3QbXaiXzK18B49S5UXSH3RbXT2xvgTFA6pbv sj://pocket-public-blockchains-main/v0-snapshots ${SNAPSHOT_URL} /home/app/.pocket/data/"

 # echo "${INFO} wget -qO- ${SNAPSHOT_URL} | tar ${TAR_ARGS} -"
 # wget -qO- ${SNAPSHOT_URL} | tar ${TAR_ARGS} -
 # echo "${INFO} SNAPSHOT downloaded!"
 # stop_downloading_ui
fi

echo "${INFO} pocket start"
exec supervisord -c /etc/supervisord/supervisord.conf
