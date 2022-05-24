#!/bin/bash
echo
echo "$(date) - Plexdriveplus install started"
echo

# set version to download a specific release of slink42/plexdriveplus, otherwise current master branch will be used
PDP_VERSION=

# set to any value to force script to use config files from cloud overwriting any local copies that exist
USE_CLOUD_CONFIG=

# ENV_FILE=install.env
INSTALL_ENV_FILE=install.env
[[ -z "$1" ]] || INSTALL_ENV_FILE=$1
[[ -f $INSTALL_ENV_FILE ]] && source $INSTALL_ENV_FILE || echo "warning $INSTALL_ENV_FILE file not found"
[[ -z "$DOCKER_ROOT" ]] && DOCKER_ROOT=$(pwd) && echo "warning: DOCKER_ROOT not set. using current path: $DOCKER_ROOT" 
echo "Using DOCKER_ROOT path: $DOCKER_ROOT"

ADMIN_USERID=$(id -u)
ADMIN_GROUPID=$(id -g)

USERID=99
GROUPID=100

SUDO=
# SUDO=sudo
# [[ $USER = "root" ]] && (echo "running as root user. wont use sudo " && SUDO=sudo)

# define text display colours

NO_FORMAT="\033[0m"
C_ORANGE1="\033[38;5;214m"
C_SPRINGGREEN3="\033[38;5;41m"
C_RED1="\033[38;5;196m"
C_YELLOW1="\033[38;5;226m"
C_DODGERBLUE1="\033[38;5;33m"
C_PURPLE="\033[38;5;129m"

## install prerequisites

# install rclone if not present
[[ $(rclone --version) ]] || (echo "installing rclone" &&  curl -fsSL https://rclone.org/install.sh | $SUDO bash)

# install docker if not present
[[ $(docker --version) ]] || (echo "installing docker" &&  curl -fsSL https://get.docker.com | $SUDO bash &&  $SUDO systemctl start docker)

# install docker-compose not found
[[ $(docker-compose --version) ]] || (echo "installing docker-compose" &&  curl -SL https://github.com/docker/compose/releases/download/v2.5.0/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose)

# add current user to docker security group
[[ $(groups root | grep docker) ]] || $SUDO groupadd docker
[[ $(groups | grep docker) ]] || $SUDO usermod -aG docker $ADMIN_USERID

# Install and/or start portainer
PORTAINER_CONTAINER=$(docker container ls -f ancestor=portainer/portainer-ce --format "{{.ID}}")
[ -z $PORTAINER_CONTAINER ] && $SUDO docker run -d -p 8000:8000 -p 9000:9000 --name=portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce || docker start "$PORTAINER_CONTAINER"

## prepare envrionment

read -p 'Please select library management mode: 
1  | [Default] Slave mode. Scheduled sync library db from master copy stored on gdrive 
2  | Master mode. Maintain library locally using a 2nd and upload on schedule to gdrive
3  | Solo mode. Maintain library locally using a 2nd plex instance
4  | KISS mode. Maintain library locally using a single plex instance
library management mode> ' -e management_mode

case $management_mode in
        "1"|"")
                echo "Slave Library Mode Selected"
                DOCKER_COMPOSE_FILE_LIB_MANGER="-f /"$DOCKER_ROOT/setup/docker-compose-lib-slave.yml/""
                ;;
        "2")
                echo "Master Library Mode Selected"
                DOCKER_COMPOSE_FILE_LIB_MANGER="-f /"$DOCKER_ROOT/setup/docker-compose-lib-master.yml/""
                ;;
        "3")
                echo "Solo Library Mode Selected"
                DOCKER_COMPOSE_FILE_LIB_MANGER="-f /"$DOCKER_ROOT/setup/docker-compose-lib-solo.yml/""
                ;;
        "4")
                echo "KISS Library Mode Selected"
                DOCKER_COMPOSE_FILE_LIB_MANGER=
                ;;
        *)
                echo "Invalid selection, exiting"
                DOCKER_COMPOSE_FILE_LIB_MANGER=
                exit 1
                ;;
esac

read -p 'Please select if library should download movie covers images from backup. Warning this will consume 150Gb+: 
1  | [Default] No. Plex should try and slowly download the pictures over time.... Very slowly
2  | Yes. Download backup and restore of Plex Library Metadata and Media folders
download library images> ' -e library_image_mode

case $library_image_mode in
        "1"|"")
                echo "Libary image download omitted"
                LIB_IMAGE_DOWNLOAD=
                ;;
        "2")
                echo "Libary image download selected"
                LIB_IMAGE_DOWNLOAD="yes"
                ;;
        *)
                echo "Invalid selection, using default - libary image download omitted"
                LIB_IMAGE_DOWNLOAD=
                ;;
esac



# Download rclone settings
if [[ -z "$USE_CLOUD_CONFIG" ]] && [[ -f "$DOCKER_ROOT/config/.env" ]] && ([[ -f "$DOCKER_ROOT/config/rclone.conf" ]] || [[ -f "$DOCKER_ROOT/rclone/rclone.conf" ]]); then
    echo "setting up rclone using local copies of rclone.conf & .env"
else
    echo "setting up rclone using rclone.conf & .env from cloud"
    [[ -f $INSTALL_ENV_FILE ]] || (echo "error $INSTALL_ENV_FILE file not found, missing credentials required to load rclone config from cloud storage" &&  exit 1)
    docker run --rm -it \
    --env-file $INSTALL_ENV_FILE \
    --name rclone-config-download \
    -v $DOCKER_ROOT/config:/config \
    rclone/rclone \
    copy secure_backup:config /config --progress
fi
mkdir -p "$DOCKER_ROOT/rclone"

# Download docker-compose and other setup file
[[ -z "$PDP_VERSION" ]] && PDP_URL="https://github.com/slink42/plexdriveplus/archive/master.tar.gz" || PDP_URL="https://github.com/slink42/plexdriveplus/archive/refs/tags/${PDP_VERSION}.tar.gz"
# remove existing custom-cont-init.d scripts if they exist to ensure only scripts downloaded remain for running at plex startup
wget --no-check-certificate --content-disposition ${PDP_URL} -O "${DOCKER_ROOT}/plexdriveplus.tar.gz"
[ -d "${DOCKER_ROOT}/plex-streamer/custom-cont-init.d/" ] && rm -r "${DOCKER_ROOT}/plex-streamer/custom-cont-init.d/"
tar xvzf "${DOCKER_ROOT}/plexdriveplus.tar.gz" --strip=1 -C "${DOCKER_ROOT}"

### Rclone & Plexdrive setup

# authorize rclone gdrive mount
echo "setting up rclone authentication"
GDRIVE_ENDPOINT=$(cat $DOCKER_ROOT/config/.env | grep RCLONE_CONFIG_SECURE_MEDIA_REMOTE)
GDRIVE_ENDPOINT=${GDRIVE_ENDPOINT/RCLONE_CONFIG_SECURE_MEDIA_REMOTE=/}
echo "Using rclone gdrive endpoint: $GDRIVE_ENDPOINT"
if [[ -f "$DOCKER_ROOT/rclone/rclone.conf" ]] && [[ $(rclone --config  "$DOCKER_ROOT/rclone/rclone.conf" lsd $GDRIVE_ENDPOINT) ]]; then 
	echo "rclone auth already present. Skipping config copy from master copy mount reconnection"
else
	echo "rclone config copy from master $GDRIVE_ENDPOINT mount reconnection"
	[[ -f "$DOCKER_ROOT/config/rclone.conf" ]] && echo "rclone config copy from master" && cp "$DOCKER_ROOT/config/rclone.conf" "$DOCKER_ROOT/rclone/"
    echo "reconnecting rclone mount: $GDRIVE_ENDPOINT"
	rclone config --config "$DOCKER_ROOT/rclone/rclone.conf" reconnect $GDRIVE_ENDPOINT
fi

# authorize scanner rclone gdrive mount if required by selected library managemeent mode
if [[ $management_mode = "2" ]] || [[ $management_mode = "3" ]]; then
    echo "**********************"
    echo "${C_PURPLE}
    setting up rclone authentication from library scanner mount. This can a different account to the one used for streaming so streaming isnt impacted by api bans caused by scanning
    ${NO_FORMAT}!"
    echo "**********************"
    SCANNER_GDRIVE_ENDPOINT=$(cat $DOCKER_ROOT/config/.env | grep RCLONE_CONFIG_SECURE_MEDIA_SCANNER_REMOTE)
    SCANNER_GDRIVE_ENDPOINT=${SCANNER_GDRIVE_ENDPOINT/RCLONE_CONFIG_SECURE_MEDIA_SCANNER_REMOTE=/}
    echo "Using rclone gdrive endpoint for scanner: $SCANNER_GDRIVE_ENDPOINT"
    if [[ $(rclone --config  "$DOCKER_ROOT/rclone/rclone.conf" lsd $SCANNER_GDRIVE_ENDPOINT) ]]; then 
        echo "rclone auth already present. Skipping config copy from master copy mount reconnection"
    else
        echo "rclone onfig copy from master $SCANNER_GDRIVE_ENDPOINT mount reconnection"
        rclone config --config "$DOCKER_ROOT/rclone/rclone.conf" reconnect $SCANNER_GDRIVE_ENDPOINT
    fi
    # make sure paths aren't mounted
    fusermount -uz "$DOCKER_ROOT/mnt/rclone/scanner_secure_media" 2>/dev/null
    fusermount -uz "$DOCKER_ROOT/mnt/rclone/scanner_secure_media2" 2>/dev/null
    fusermount -uz "$DOCKER_ROOT/mnt/rclone/scanner_secure_media3" 2>/dev/null
    fusermount -uz "$DOCKER_ROOT/mnt/mergerfs/scanner_secure_media" 2>/dev/null
fi

## make sure scanner rclone paths aren't mounted
# rclone
fusermount -uz "$DOCKER_ROOT/mnt/rclone/secure_media" 2>/dev/null
fusermount -uz "$DOCKER_ROOT/mnt/rclone/secure_media2" 2>/dev/null
fusermount -uz "$DOCKER_ROOT/mnt/rclone/secure_media3" 2>/dev/null
# plexdrive & it rclone crypt
fusermount -uz "$DOCKER_ROOT/mnt/plexdrive/secure_media" 2>/dev/null
fusermount -uz "$DOCKER_ROOT/mnt/plexdrive/cloud" 2>/dev/null # need to use mergerfs in plexdrive container as workaround, otherwise mount doesnt get exposed to host properly
fusermount -uz "$DOCKER_ROOT/mnt/plexdrive/local" 2>/dev/null
fusermount -uz "$DOCKER_ROOT/mnt/rclone/plexdrive_secure_media" 2>/dev/null
# mergerfs
fusermount -uz "$DOCKER_ROOT/mnt/mergerfs/secure_media" 2>/dev/null

## copy gdrive mount tokens to plexdrive
echo "copying rclone token to plexdrive"
mkdir -p "$DOCKER_ROOT/plexdrive/config/"
# read token from config
RCLONE_CONFIG_GDRIVE=$(rclone config  --config "$DOCKER_ROOT/rclone/rclone.conf" show ${GDRIVE_ENDPOINT})

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
    && RCLONE_TEAMDRIVE=$(RCLONE_TEAMDRIVE=cat $ENV_FILE | grep PLEXDRIVE_GDRIVE_TEAM_DRIVE) \
    && RCLONE_TEAMDRIVE=${RCLONE_TEAMDRIVE/PLEXDRIVE_GDRIVE_TEAM_DRIVE=/}
[[ -z "$RCLONE_TEAMDRIVE" ]] && echo "warning: rclone teamdrive id for gdrive not found in .env under PLEXDRIVE_GDRIVE_TEAM_DRIVE" \
    || echo "$RCLONE_TEAMDRIVE" > "$DOCKER_ROOT/plexdrive/config/team_drive.id"


# Download plexdrive cache
if [[ -z "$USE_CLOUD_CONFIG" ]] && [[ -f "$DOCKER_ROOT/plexdrive/cache/cache.bolt" ]]; then
    echo "using local plexdrive cache file"
else
    echo "local plexdrive cache file not found. Initalising with master copy from cloud"
    if [[ -f $INSTALL_ENV_FILE ]]; then
        docker run --rm -it \
        --env-file $INSTALL_ENV_FILE \
        --name rclone-config-download \
        --user $USERID:$GROUPID \
        -v $DOCKER_ROOT/plexdrive/cache:/plexdrive/cache \
        rclone/rclone \
        copy secure_backup:plexdrive/cache /plexdrive/cache --progress
    else
        echo "warning $INSTALL_ENV_FILE file not found, missing credentials required to initalise plexdrive cache file from cloud storage. Will leave to plexdrive to initalise on first run"
    fi
fi
### Docker environment setup
ENV_FILE="$DOCKER_ROOT/config/.env"

# Set rclone rc username and password if not already provided in env file
[[ $(cat $ENV_FILE | grep RCLONE_USER) ]] || echo "RCLONE_USER=rclone" >> "$ENV_FILE"
[[ $(cat $ENV_FILE | grep RCLONE_PASSWORD) ]] || echo "RCLONE_PASSWORD=rclone" >> "$ENV_FILE"

# Set user and group id if not already provided in env file
[[ $(cat $ENV_FILE | grep USERID) ]] || echo "USERID=$USERID" >> "$ENV_FILE"
[[ $(cat $ENV_FILE | grep GROUPID) ]] || echo "GROUPID=$GROUPID" >> "$ENV_FILE"

## Start with updated rclone config
echo "starting containers with docker-compose"
sed -i '/DOCKER_ROOT/'d "$ENV_FILE"
echo "DOCKER_ROOT=$DOCKER_ROOT" >> "$ENV_FILE"
mkdir -p "$DOCKER_ROOT/mnt/mergerfs/secure_media"


# copy generic Plex Preferences.xml
mkdir -p "$DOCKER_ROOT/plex-streamer/Library/Application Support/Plex Media Server/"
PLEX_PREF_MASTER="$DOCKER_ROOT/setup/plex_streamer_Preferences.xml" 
[ -f "$PLEX_PREF_MASTER" ] || PLEX_PREF_MASTER="$DOCKER_ROOT/setup/Preferences.xml"
if [[ -z "$USE_CLOUD_CONFIG" ]] && [ -f "$DOCKER_ROOT/plex-streamer/Library/Application Support/Plex Media Server/Preferences.xml" ]; then
    echo "Using existing Preferences.xml for Plex server config"
else
    # copy default plex preference file into plex config dir
    echo "Using Preferences.xml downloaded from cloud for Plex server config"
    cp "$PLEX_PREF_MASTER" "$DOCKER_ROOT/plex-streamer/Library/Application Support/Plex Media Server/Preferences.xml"
fi

# start docker containers
DOCKER_COMPOSE_FILE=$DOCKER_ROOT/setup/docker-compose.yml
SLAVE_DOCKER_COMPOSE_FILE=$DOCKER_ROOT/setup/docker-compose-lib-slave.yml
DOCKER_COMPOSE_FILE_LOGGING="-f /"$DOCKER_ROOT/setup/docker-compose-logging.yml/""

if [[ $management_mode = "2" ]] || [[ $management_mode = "3" ]]; then
    DOCKER_COMPOSE_COMMAND="docker-compose --env-file $ENV_FILE --project-directory $DOCKER_ROOT/setup -f "$DOCKER_COMPOSE_FILE" -f "$SLAVE_DOCKER_COMPOSE_FILE" $DOCKER_COMPOSE_FILE_LOGGING --project-name plexdriveplus up -d"
    echo "initialising docker containers with command: $DOCKER_COMPOSE_COMMAND"
    $DOCKER_COMPOSE_COMMAND
else
    DOCKER_COMPOSE_COMMAND="docker-compose --env-file $ENV_FILE --project-directory $DOCKER_ROOT/setup -f "$DOCKER_COMPOSE_FILE" $DOCKER_COMPOSE_FILE_LIB_MANGER $DOCKER_COMPOSE_FILE_LOGGING --project-name plexdriveplus up -d --remove-orphans"
    echo "starting docker containers with command: $DOCKER_COMPOSE_COMMAND"
    $DOCKER_COMPOSE_COMMAND
fi

### Plex container setup
# Stop plex while library downloads
echo "stopping plex instance(s) for plex library download"
CONTAINER_PLEX_STREAMER=$(docker container ls --format {{.Names}} | grep plex_streamer)
docker stop "$CONTAINER_PLEX_STREAMER"

sleep 7
CONTAINER_PLEX_LIBRARY_SYNC=$(docker container ls --format {{.Names}} | grep rclone_library_sync)
while [[ $(docker ps | grep $CONTAINER_PLEX_LIBRARY_SYNC) ]]
do
echo "$(date) - waiting for library download using $CONTAINER_PLEX_LIBRARY_SYNC to complete"
echo "------------------------- progress ------------------------------"
docker logs --tail 5 "$CONTAINER_PLEX_LIBRARY_SYNC"
echo "-----------------------------------------------------------------"
sleep 20
done
echo "$(date) - library download using $CONTAINER_PLEX_LIBRARY_SYNC has completed. Restarting Plex"
bash  "$DOCKER_ROOT/plex-streamer/custom-cont-init.d/03_restore-library-backup" "$DOCKER_ROOT/plex-scanner/Library"

# load plex claim id env variable
if grep -qs "PlexOnlineToken" "$DOCKER_ROOT/plex-streamer/Library/Application Support/Plex Media Server/Preferences.xml"  && \
( !([[ $management_mode = "2" ]] || [[ $management_mode = "3" ]]) || grep -qs "PlexOnlineToken" "$DOCKER_ROOT/plex-scanner/Library/Application Support/Plex Media Server/Preferences.xml" ) ; then
    echo "Plex servers already claimed"
    PLEX_CLAIM_ID="claim-xxxxxxxxxxxxxxx"
else
    # load plex claim ID to PLEX_CLAIM_ID variable .env file
read -i 'claim-xxxxxxxxxxxxxxx' -p 'If you are running this headless, please enter you plex claim id generated from https://www.plex.tv/claim/. If you dont know what this means just press enter:
plex claim id> ' -e PLEX_CLAIM_ID
    echo "Using PLEX_CLAIM: $PLEX_CLAIM_ID"
fi
# write PLEX_CLAIM_ID value to .env file
echo "PLEX_CLAIM=$PLEX_CLAIM_ID" >> "$ENV_FILE"


# copy streamer plex db copied for cloud to scanner if required by selected library managemeent mode
if [[ $management_mode = "2" ]] || [[ $management_mode = "3" ]]; then

    # Fix Library File Ownership library root folders not already belonging to user
    USERNAME=$(id -nu $USERID)
    if [ $(ls -l "$DOCKER_ROOT/plex-scanner/Library/Application Support/Plex Media Server/" | grep -v $USERNAME | wc -l) -ne 1 ]; then
        echo "setting library file ownership to $USERID:$GROUPID for $DOCKER_ROOT/plex-scanner/Library"
        chown -R $USERID:$GROUPID "$DOCKER_ROOT/plex-scanner/Library"
    fi

    echo "copying streamer plex config from streamer to scanner"
    # copy generic Plex Preferences.xml
    mkdir -p "$DOCKER_ROOT/plex-scanner/Library/Application Support/Plex Media Server/"
    ([[ -z "$USE_CLOUD_CONFIG" ]] && [[ -f "$DOCKER_ROOT/plex-scanner/Library/Application Support/Plex Media Server/Preferences.xml" ]] && echo "Using existing Preferences.xml for Plex scanner server config") || \
        (cp "$DOCKER_ROOT/setup/plex_scanner_Preferences.xml" "$DOCKER_ROOT/plex-scanner/Library/Application Support/Plex Media Server/Preferences.xml"  && echo "Using Preferences.xml downloaded from cloud for Plex scanner server config")
    
    #cp -r "$DOCKER_ROOT/plex-streamer/Library/Application Support/Plex Media Server/Plug-in Support" "$DOCKER_ROOT/plex-scanner/Library/Application Support/Plex Media Server/Plug-in Support"

    DOCKER_COMPOSE_COMMAND="docker-compose --env-file $ENV_FILE --project-directory $DOCKER_ROOT/setup -f "$DOCKER_COMPOSE_FILE" $DOCKER_COMPOSE_FILE_LIB_MANGER $DOCKER_COMPOSE_FILE_LOGGING --project-name plexdriveplus up -d --remove-orphans"
    echo "starting docker containers with command: $DOCKER_COMPOSE_COMMAND"
    $DOCKER_COMPOSE_COMMAND

    echo "open plex scanner in browser to continue configuration there: https://127.0.0.1:34400/web"
fi

docker start "$CONTAINER_PLEX_STREAMER"

# Open plex in browser
echo "please open portainer in web browser to set admin user and password for docker management web gui: https://127.0.0.1:9999"
( [ $(xdg-open --version) ] && xdg-open https://127.0.0.1:32400/web && echo "opening plex in browser" && exit 0 ) 2>/dev/null
echo "open plex in browser to continue configuration there: https://127.0.0.1:32400/web"


# copy library images / metadata backup from master
if ! [[ -z "$LIB_IMAGE_DOWNLOAD" ]]; then
    if [[ -z "$USE_CLOUD_CONFIG" ]] && [[ -f "$DOCKER_ROOT/plex-scanner/backups/meta/library_files.tar.gz" ]]; then
        echo "using existing copy of library media covers backup tar file"
    else
        echo "downloading library media covers backup from cloud"
        [[ -f $INSTALL_ENV_FILE ]] || (echo "error $INSTALL_ENV_FILE file not found, missing credentials required to load rclone config from cloud storage" &&  exit 1)
        docker run --rm -it \
        --env-file $INSTALL_ENV_FILE \
        --name rclone-config-download \
        --user $USERID:$GROUPID \
        -v $DOCKER_ROOT/plex-scanner:/plex-scanner \
        rclone/rclone \
        copy secure_backup:plex-scanner/backups /plex-scanner/backups --progress
    fi
    tar -xzf $DOCKER_ROOT/plex-scanner/backups/meta/library_files.tar.gz -C $DOCKER_ROOT/plex-scanner --checkpoint=.5000
    
    # Fix Library File Ownership
    echo "setting library file ownership to $USERID:$GROUPID for $DOCKER_ROOT/plex-scanner/Library"
    chown -R $USERID:$GROUPID "$DOCKER_ROOT/plex-scanner/Library"
    
    # Restart plex streamer
    docker restart "$CONTAINER_PLEX_STREAMER"
fi
echo
echo "$(date) - Plexdriveplus install Done!!!"
echo