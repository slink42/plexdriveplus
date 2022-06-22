#!/bin/bash
echo
echo "$(date) - Wireguard client config started"
echo

# ENV_FILE=install.env
INSTALL_ENV_FILE=install.env
[[ -z "$1" ]] || INSTALL_ENV_FILE=$1
[[ -f $INSTALL_ENV_FILE ]] && source $INSTALL_ENV_FILE || echo "warning $INSTALL_ENV_FILE file not found"
[[ -z "$DOCKER_ROOT" ]] && DOCKER_ROOT=$(pwd) && echo "warning: DOCKER_ROOT not set. using current path: $DOCKER_ROOT" 
echo "Using DOCKER_ROOT path: $DOCKER_ROOT"

if [ -f $INSTALL_ENV_FILE ]
then
  export $(cat $INSTALL_ENV_FILE | xargs)
fi

PEER_LIST=$(rclone lsf secure_backup_rw:wg --config "$DOCKER_ROOT/rclone/rclone.conf")


REPLY=nothing
while ! [[ -z $REPLY ]]
do
  PEER_NUM=0
  echo "Select from the following peer config files:"
  for PEER in $PEER_LIST;
  do 
    PEER_NUM=$((PEER_NUM+1)); 
    echo "Peer $PEER_NUM: $PEER"; 
  done

  read -p 'Name of wireguard conf to load: ';
  PEER_NUM=0
  echo "Select from the following peer config files:"
  for PEER in $PEER_LIST;
  do 
    PEER_NUM=$((PEER_NUM+1)); 
    if [ "$REPLY" = $PEER ]
    then
      echo "Wireguard peer config selected - $PEER_NUM: $PEER";
      PEER_NAME=$PEER
      REPLY=
    fi
  done
  [[ -z $REPLY ]] || echo 'Invalid selection, please try again or press enter to skip loading wireguard config';
done

if [[ -z "$PEER_NAME" ]]; then
    echo "error: unable to find wireguard peer config"
else
    mkdir -p "$DOCKER_ROOT/wireguard"
    rclone copy --config "$DOCKER_ROOT/rclone/rclone.conf" "secure_backup_rw:wireguard/peers/$PEER_NAME" "$DOCKER_ROOT/rclone/rclone.conf" "$DOCKER_ROOT/wireguard/wg0.conf"
    [ -f "$DOCKER_ROOT/wireguard/wg0.conf" ] && echo "wireguard wg0.conf created sucessfully" || echo "error: unable to move wireguard peer config to $DOCKER_ROOT/wireguard/wg0.conf"
fi

echo
echo "$(date) - Wireguard client config finished"
echo