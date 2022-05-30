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

PEER_NAME=$(rclone lsf secure_backup_rw:wireguard/peers --config "$DOCKER_ROOT/rclone/rclone.conf" | head -n 1)

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