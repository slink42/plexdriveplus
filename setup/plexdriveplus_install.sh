#!/bin/bash

# ENV_FILE=install.env
INSTALL_ENV_FILE=install.env
[[ -z "$1" ]] || INSTALL_ENV_FILE=$1
source $INSTALL_ENV_FILE
([[ -z "$DOCKER_ROOT" ]] && DOCKER_ROOT=$(pwd) && echo "error: DOCKER_ROOT not set. using current path: $DOCKER_ROOT")
echo "Using DOCKER_ROOT path: $DOCKER_ROOT"

SUDO=sudo
[[ $USER = "root" ]] && (echo "running as root user. wont use sudo " && SUDO=sudo)

## install prerequisites

# install rclone if not present
[[ $(rclone --version) ]] || (echo "installing rclone" &&  curl -fsSL https://rclone.org/install.sh | $SUDO bash)

# install docker if not present
[[ $(docker --version) ]] || (echo "installing docker" &&  curl -fsSL https://get.docker.com | $SUDO bash &&  $SUDO systemctl start docker)

# install docker-compose not found
[[ $(docker-compose --version) ]] || (echo "installing docker-compose" &&  curl -SL https://github.com/docker/compose/releases/download/v2.5.0/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose)

# install docker-compose not found
$SUDO groupadd docker
$SUDO usermod -aG docker $USER

# Install portainer
[[ $(docker container ls -f name=portainer) ]] || $SUDO docker run -d -p 8000:8000 -p 9000:9000 --name=portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:2.6.3

## prepare envrionment

# Download docker-compose and other setup file
wget --no-check-certificate --content-disposition https://github.com/slink42/plexdriveplus/archive/refs/tags/0.0.2.tar.gz -O "$DOCKER_ROOT/plexdriveplus.tar.gz"
tar xvzf "$DOCKER_ROOT/plexdriveplus.tar.gz" --strip=1 -C "$DOCKER_ROOT"
docker run --rm -it --env-file $INSTALL_ENV_FILE --name rclone-config-download -v $DOCKER_ROOT/config:/config rclone/rclone copy secure_backup:config /config --progress

# authorize rclone gdrive mount
mkdir -p "$DOCKER_ROOT/rclone"
cp "$DOCKER_ROOT/config/rclone.conf" "$DOCKER_ROOT/rclone/"
GDRIVE_ENDPOINT=$(cat $DOCKER_ROOT/config/.env | grep RCLONE_CONFIG_SECURE_MEDIA_REMOTE)
GDRIVE_ENDPOINT=${GDRIVE_ENDPOINT/RCLONE_CONFIG_SECURE_MEDIA_REMOTE=/}
# GDRIVE_ENDPOINT=$(cat $DOCKER_ROOT/config/.env | grep RCLONE_CONFIG_SECURE_MEDIA_REMOTE | cut -d "=" -f2)
echo "Using rclone gdrive endpoint: $GDRIVE_ENDPOINT"
rclone config --config "$DOCKER_ROOT/rclone/rclone.conf" reconnect $GDRIVE_ENDPOINT

## copy gdrive mount tokens to plexdrive
mkdir -p "$DOCKER_ROOT/plexdrive/config/"
# read token from config
RCLONE_CONFIG_GDRIVE=$(rclone config  --config "$DOCKER_ROOT/rclone/rclone.conf" show gdrive:)

# update plexdrive token.json
RCLONE_TOKEN=$(echo "$RCLONE_CONFIG_GDRIVE" | grep token)
# trim to value only
RCLONE_TOKEN=${RCLONE_TOKEN/token = /}
[[ -z "$RCLONE_TOKEN" ]] && echo "error: rclone token for gdrive not found in rclone.conf" && exit 1 \
    || echo "$RCLONE_TOKEN" > "$DOCKER_ROOT/plexdrive/config/token.json"

# update plexdrive config.json
RCLONE_CLIENTID=$(echo "$RCLONE_CONFIG_GDRIVE" | grep client_id)
RCLONE_CLIENTID=${RCLONE_CLIENTID/client_id = /}

RCLONE_SECRET=$(echo "$RCLONE_CONFIG_GDRIVE" | grep client_secret)
RCLONE_SECRET=${RCLONE_SECRET/client_secret = /}

if [[ -z "$RCLONE_CLIENTID" ]] || [[ -z "$RCLONE_SECRET" ]]; then
echo "error: rclone token for gdrive not found in rclone.conf"
exit 1	
else
echo "{\"ClientID\":\"$RCLONE_CLIENTID\",\"ClientSecret\":\"$RCLONE_SECRET\"}" > "$DOCKER_ROOT/plexdrive/config/config.json"
fi

# update plexdrive team_drive.id
RCLONE_TEAMDRIVE=$(echo "$RCLONE_CONFIG_GDRIVE" | grep team_drive)
RCLONE_TEAMDRIVE=${RCLONE_TEAMDRIVE/team_drive = /}
[[ -z "$RCLONE_TEAMDRIVE" ]] && echo "warning: rclone teamdrive id for gdrive not found in rclone.conf" \
    || echo "$RCLONE_TEAMDRIVE" > "$DOCKER_ROOT/plexdrive/config/team_drive.id"


## Start with updated rclone config
docker-compose --project-directory $DOCKER_ROOT/setup --project-name plexdriveplus up -d

# Stop plex while library downloads
docker stop pdp-plex

# copy generic Plex Preferences.xml
cp "$DOCKER_ROOT/setup/Preferences.xml" "$DOCKER_ROOT/plex-streamer/Library/Application Support/Plex Media Server/Preferences.xml"

while [[ $(docker ps | grep pdp-rclone-library-download) ]]
do
echo "$(date) - waiting to pdp-rclone-library-download to complete"
echo "------------------------- progress ------------------------------"
docker logs --tail 5 pdp-rclone-library-download
echo "-----------------------------------------------------------------"
sleep 30
done
echo "$(date) - pdp-rclone-library-download complete. Restarting Plex"

docker start pdp-plex

# Open plex in browser
xdg-open http://127.0.0.1:32400/web