#!/bin/bash
echo
echo "$(date) - Plexdriveplus install started"
echo

# set version to download a specific release of slink42/plexdriveplus, otherwise current master branch will be used
PDP_VERSION=

# set to any value to force script to use config files from cloud overwriting any local copies that exist
USE_CLOUD_CONFIG=


function logMessage() {
    message=$1
    log_level=$2
    [ -z "$log_level" ] && log_level=-d

    echo "$message"
}

function openURL() {
    web_url=$1

    if [[ $(xdg-open --version 2>/dev/null) ]]
    then
        # Open web_url in browser
        echo "opening $web_url in browser"
        xdg-open "$web_url"
    else
        echo "unable to open browser automaticly, please open $web_url in browser"
    fi
}

function updateEnvFile() {
    env_file=$1
    var=$2
    value=$3
    mode=$4
    if [ "$mode" = "force" ] 
    then
        echo "removing any existing value for $var from $env_file"
        sed -i '/$var/'d "$env_file"
    fi

    if ! [ "$mode" = "check" ] || ! [[ $(cat $env_file | grep $var) ]]
    then
        echo "adding $var=$value to $env_file"
        echo "$var=$value" >> "$env_file"
    fi
}

function configPlexRamDisk() {
    env_file=$1
    if [ $(cat /proc/meminfo | grep MemTotal  | tr -dc '[0-9]') -ge 7340032 ]
    then
        echo "7 GB Ram or more, set plex library to load to ramdisk"
        updateEnvFile "$env_file" "LOAD_LIBRARY_DB_TO_MEMORY" "YES" force
    else
        echo "Memory size: $(cat /proc/meminfo | grep MemTotal  | tr -dc '[0-9]')KB"
        echo "Less than 7 GB Ram, setting plex library to load to normal disk"
        
        updateEnvFile "$env_file" "LOAD_LIBRARY_DB_TO_MEMORY" "NO"
    fi
}


function prepareVolumeMountPath() {
    MOUNT_PATH=$1
    MOUNT_TYPE=$2
    mkdir -p "$MOUNT_PATH"
    if ! [[ $(ls -la "$MOUNT_PATH") ]]
    then
        echo "warning:inital attempt to prepare $MOUNT_PATH failed. Trying again after forcing any existing mounts to the path to disconnect"
        $SUDO fusermount -uz "$MOUNT_PATH" 2>/dev/null
        mkdir -p "$MOUNT_PATH"
        if ! [[ $(ls -la "$MOUNT_PATH") ]]
        then
            echo "error: attempts to prepare $MOUNT_PATH for used as a volume bind point failed. Manual intervention required"
            exit 1
        fi
    fi

    if [ "$MOUNT_TYPE" = 'executable_dir' ]
    then
        echo ""
        echo "********************************************************************"
        echo "setting contents of $MOUNT_PATH as executable and owned by root user"
        echo "********************************************************************"
        echo ""
        $SUDO chmod -R +x "${MOUNT_PATH}"
        $SUDO chown -R root:root "${MOUNT_PATH}" # needs to be owned by root for security
    fi
}


function installDocker() {
    docker_user=$1
    
    # install docker if not present
    [[ $(docker --version) ]] || (echo "installing docker" &&  curl -fsSL https://get.docker.com | $SUDO bash &&  $SUDO systemctl start docker)

    # install docker-compose not found
    if ! [[ $(docker-compose --version) ]]
    then
        echo "installing docker-compose"
        curl -SL https://github.com/docker/compose/releases/download/v2.5.0/docker-compose-linux-x86_64 -o /tmp/docker-compose
        $SUDO mv  /tmp/docker-compose /usr/local/bin/docker-compose
        $SUDO chmod +x /usr/local/bin/docker-compose
    fi

    # add current user to docker security group
    # [[ $(groups root | grep docker) ]] || $SUDO groupadd docker
    if ! [[ $(groups | grep docker) ]] && ! [[ $(groups | grep root) ]]; then
        echo "Adding current user to docker management group: docker"
        $SUDO usermod -aG docker $docker_user
        read -p  "Please log out of and then back in to allow user addition to docker managememt group to apply"
        exit 1
    fi

    # if docker isn't running set it to turn on at boot
    if ! [[ $(docker ps) ]]
    then
        echo "Starting docker service and setting to run on boot"
        $SUDO systemctl enable docker.service
        $SUDO systemctl enable containerd.service
        $SUDO systemctl start docker
    fi
    
}
# ENV_FILE=install.env
INSTALL_ENV_FILE=install.env
[[ -z "$1" ]] || INSTALL_ENV_FILE=$1
[[ -f $INSTALL_ENV_FILE ]] && source $INSTALL_ENV_FILE || echo "warning $INSTALL_ENV_FILE file not found"
[[ -z "$DOCKER_ROOT" ]] && DOCKER_ROOT=$(pwd) && echo "warning: DOCKER_ROOT not set. using current path: $DOCKER_ROOT" 
echo "Using DOCKER_ROOT path: $DOCKER_ROOT"

ADMIN_USERNAME=$USER
ADMIN_USERID=$(id -u)
ADMIN_GROUPID=$(id -g)

# Run docker apps as user 99 and group 100 if installer running as root
if [ "$ADMIN_USERID" -eq "0" ]; then
    USERID=99
    GROUPID=100
else
    USERID=$ADMIN_USERID
    GROUPID=$ADMIN_GROUPID
fi



[[ $USER = "root" ]] && echo "running as root user. wont use sudo" || SUDO=sudo

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

# install docker if not present and setup to run as deamon on boot
installDocker "$ADMIN_USERID"

# add current user to docker security group
# [[ $(groups root | grep docker) ]] || $SUDO groupadd docker
if ! [[ $(groups | grep docker) ]] && ! [[ $(groups | grep root) ]]; then
    echo "Adding current user to docker management group: docker"
    $SUDO usermod -aG docker $ADMIN_USERNAME
    read -p  "Please log out of and then back in to allow user addition to docker managememt group to apply"
    exit 1
fi

## prepare envrionment

read -p 'Please select library management mode: 
1  | [Default] Slave mode. Scheduled sync library db from master copy stored on gdrive
2  | Master mode. Maintain library locally using a 2nd and upload on schedule to gdrive
3  | Solo mode. Maintain library locally using a 2nd plex instance
4  | KISS mode. Maintain library locally using a single plex instance
5  | Slave mode (without remote support). Scheduled sync library db from master copy stored on gdrive. Remote support connectin excluded.
library management mode> ' -e management_mode

case $management_mode in
        "1"|"")
                echo "Slave Library Mode Selected"
                DOCKER_COMPOSE_FILE_LIB_MANGER="-f \"$DOCKER_ROOT/setup/docker-compose-lib-slave.yml\" -f \"$DOCKER_ROOT/setup/docker-compose-support.yml\""
                ;;
        "2")
                echo "Master Library Mode Selected"
                DOCKER_COMPOSE_FILE_LIB_MANGER="-f \"$DOCKER_ROOT/setup/docker-compose-lib-scanner.yml\" -f \"$DOCKER_ROOT/setup/docker-compose-lib-master.yml\""
                ;;
        "3")
                echo "Solo Library Mode Selected"
                DOCKER_COMPOSE_FILE_LIB_MANGER="-f \"$DOCKER_ROOT/setup/docker-compose-lib-scanner.yml\""
                ;;
        "4")
                echo "KISS Library Mode Selected"
                DOCKER_COMPOSE_FILE_LIB_MANGER=
                ;;
        "5")
                echo "Slave Library Mode Selected"
                DOCKER_COMPOSE_FILE_LIB_MANGER="-f \"$DOCKER_ROOT/setup/docker-compose-lib-slave.yml\""
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
    mkdir -p "$DOCKER_ROOT/config"
    [[ -f $INSTALL_ENV_FILE ]] || (echo "error $INSTALL_ENV_FILE file not found, missing credentials required to load rclone config from cloud storage" &&  exit 1)
    docker run --rm -it \
    --env-file $INSTALL_ENV_FILE \
    --name rclone-config-download \
    -v "$DOCKER_ROOT/config:/config" \
    --user "$ADMIN_USERID:$ADMIN_GROUPID" \
    rclone/rclone \
    copy secure_backup:config /config --progress
fi
mkdir -p "$DOCKER_ROOT/rclone"

# Download docker-compose and other setup file
[[ -z "$PDP_BRANCH" ]] && PDP_BRANCH=master
[[ -z "$PDP_VERSION" ]] && PDP_URL="https://github.com/slink42/plexdriveplus/archive/$PDP_BRANCH.tar.gz" &&  echo "" && echo "loading plexdrive plus using branch: $PDP_BRANCH" \
    || (PDP_URL="https://github.com/slink42/plexdriveplus/archive/refs/tags/${PDP_VERSION}.tar.gz" &&  echo "" && echo "loading plexdrive plus using version: $PDP_VERSION")
# remove existing custom-cont-init.d scripts if they exist to ensure only scripts downloaded remain for running at plex startup
wget --no-check-certificate --content-disposition ${PDP_URL} -O "${DOCKER_ROOT}/plexdriveplus.tar.gz"
if [ -d "${DOCKER_ROOT}/plex-streamer/custom-cont-init.d/" ]; then
    if rm -r "${DOCKER_ROOT}/plex-streamer/custom-cont-init.d/"; then
        echo "sucessfully removed existing dir: ${DOCKER_ROOT}/plex-streamer/custom-cont-init.d/"
    else
        echo "failed to remove existing dir: ${DOCKER_ROOT}/plex-streamer/custom-cont-init.d/"
        echo "trying again with sudo. If this fails too library linking might not work"
        $SUDO rm -r "${DOCKER_ROOT}/plex-streamer/custom-cont-init.d/"
    fi
fi
tar xvzf "${DOCKER_ROOT}/plexdriveplus.tar.gz" --overwrite --strip=1 -C "${DOCKER_ROOT}"

### Rclone & Plexdrive setup

# authorize rclone gdrive mount
echo "setting up rclone authentication"
GDRIVE_ENDPOINT=$(cat "$DOCKER_ROOT/config/.env" | grep RCLONE_CONFIG_SECURE_MEDIA_REMOTE)
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
    SCANNER_GDRIVE_ENDPOINT=$(cat "$DOCKER_ROOT/config/.env" | grep RCLONE_CONFIG_SECURE_MEDIA_SCANNER_REMOTE)
    SCANNER_GDRIVE_ENDPOINT=${SCANNER_GDRIVE_ENDPOINT/RCLONE_CONFIG_SECURE_MEDIA_SCANNER_REMOTE=/}
    echo "Using rclone gdrive endpoint for scanner: $SCANNER_GDRIVE_ENDPOINT"
    if [[ $(rclone --config  "$DOCKER_ROOT/rclone/rclone.conf" lsd $SCANNER_GDRIVE_ENDPOINT) ]]; then 
        echo "rclone auth already present. Skipping config copy from master copy mount reconnection"
    else
        echo "reconnecting rclone mount: $SCANNER_GDRIVE_ENDPOINT"
        rclone config --config "$DOCKER_ROOT/rclone/rclone.conf" reconnect $SCANNER_GDRIVE_ENDPOINT
    fi
    if [[ $management_mode = "2" ]]; then
            # authorize rclone gdrive mount
        echo "setting up config backup rclone authentication"
        BACKUP_GDRIVE_ENDPOINT=gdrive_backup_rw:
        echo "Using rclone gdrive endpoint: $BACKUP_GDRIVE_ENDPOINT"
        if [[ $(rclone --config  "$DOCKER_ROOT/rclone/rclone.conf" lsd $BACKUP_GDRIVE_ENDPOINT) ]]; then 
            echo "rclone auth already present. Skipping config copy from master copy mount reconnection"
        else
            echo "reconnecting rclone mount: $BACKUP_GDRIVE_ENDPOINT"
            rclone config --config "$DOCKER_ROOT/rclone/rclone.conf" reconnect $BACKUP_GDRIVE_ENDPOINT
        fi
    fi


    # make sure paths aren't mounted
    prepareVolumeMountPath "$DOCKER_ROOT/mnt/rclone/scanner_secure_media"
    prepareVolumeMountPath "$DOCKER_ROOT/mnt/rclone/scanner_secure_media2"
    prepareVolumeMountPath "$DOCKER_ROOT/mnt/rclone/scanner_secure_media3"
    prepareVolumeMountPath "$DOCKER_ROOT/mnt/mergerfs/scanner_secure_media"
fi

## make sure scanner rclone paths aren't mounted
# rclone
prepareVolumeMountPath "$DOCKER_ROOT/mnt/rclone/secure_media"
prepareVolumeMountPath "$DOCKER_ROOT/mnt/rclone/secure_media2"
prepareVolumeMountPath "$DOCKER_ROOT/mnt/rclone/secure_media3"
# plexdrive & it rclone crypt
prepareVolumeMountPath "$DOCKER_ROOT/mnt/plexdrive/secure_media"
prepareVolumeMountPath "$DOCKER_ROOT/mnt/plexdrive/cloud" # need to use mergerfs in plexdrive container as workaround, otherwise mount doesn't get exposed to host properly
prepareVolumeMountPath "$DOCKER_ROOT/mnt/plexdrive/local"
prepareVolumeMountPath "$DOCKER_ROOT/mnt/rclone/plexdrive_secure_media"
prepareVolumeMountPath "$DOCKER_ROOT/mnt/rclone/plexdrive_secure_media"
# mergerfs
prepareVolumeMountPath "$DOCKER_ROOT/mnt/mergerfs/secure_media"
prepareVolumeMountPath "$DOCKER_ROOT/mnt/mergerfs/streamer"
prepareVolumeMountPath "${DOCKER_ROOT}/mnt/mergerfs/streamer"

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
    mkdir -p "$DOCKER_ROOT/plexdrive/cache"
    if [[ -f $INSTALL_ENV_FILE ]]; then
        docker run --rm -it \
        --env-file $INSTALL_ENV_FILE \
        --name rclone-config-download \
        --user "$ADMIN_USERID:$ADMIN_GROUPID" \
        -v "$DOCKER_ROOT/plexdrive/cache:/plexdrive/cache" \
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

# Remove user and group id if provided in env file and running as root
if ! [ "$ADMIN_USERID" -eq "0" ]; then
    sed -i '/USERID/'d "$ENV_FILE"
    sed -i '/GROUPID/'d "$ENV_FILE"
fi

# Set user and group id if not already provided in env file
updateEnvFile "$ENV_FILE" "USERID" "$USERID" check
updateEnvFile "$ENV_FILE" "GROUPID" "$GROUPID" check

# Select if Plex should load DB to RAM or disk
configPlexRamDisk "$ENV_FILE"

## Start with updated rclone config
echo "starting containers with docker-compose"
sed -i '/DOCKER_ROOT/'d "$ENV_FILE"
echo "DOCKER_ROOT=$DOCKER_ROOT" >> "$ENV_FILE"

# Create paths mounted by docker beforehand to ensure they are owned by current user rather than root

prepareVolumeMountPath "${DOCKER_ROOT}/mnt/mergerfs/streamer/media"
prepareVolumeMountPath "${DOCKER_ROOT}/mnt/mergerfs/scanner/media"
prepareVolumeMountPath "${DOCKER_ROOT}/plex-scanner/Library/Application Support/Plex Media Server/Plug-in Support/Databases"
prepareVolumeMountPath "${DOCKER_ROOT}/plex-scanner/Library/Application Support/Plex Media Server/Metadata/"
prepareVolumeMountPath "${DOCKER_ROOT}/plex-scanner/Library/Application Support/Plex Media Server/Media/"
prepareVolumeMountPath "${DOCKER_ROOT}/mnt/rclone/plexdrive_secure_media/Media/movies-4k/"
prepareVolumeMountPath "${DOCKER_ROOT}/mnt/rclone/plexdrive_secure_media/Media/tv-4k/"

prepareVolumeMountPath "${DOCKER_ROOT}/plex-scanner/custom-cont-init.d" executable_dir
prepareVolumeMountPath "${DOCKER_ROOT}/plex-scanner/custom-services.d" executable_dir
prepareVolumeMountPath "${DOCKER_ROOT}/plex-scanner/transcode"
ls -la "${DOCKER_ROOT}/plex-scanner/"

prepareVolumeMountPath "${DOCKER_ROOT}/plex-streamer/custom-cont-init.d" executable_dir
prepareVolumeMountPath "${DOCKER_ROOT}/plex-streamer/custom-services.d" executable_dir
prepareVolumeMountPath "${DOCKER_ROOT}/plex-streamer/transcode"
ls -la "${DOCKER_ROOT}/plex-streamer/"
prepareVolumeMountPath "${DOCKER_ROOT}/scripts/" executable_dir

# copy generic Plex Preferences.xml
prepareVolumeMountPath "$DOCKER_ROOT/plex-streamer/Library/Application Support/Plex Media Server/"
PLEX_PREF_MASTER="$DOCKER_ROOT/setup/plex_streamer_Preferences.xml" 
[ -f "$PLEX_PREF_MASTER" ] || PLEX_PREF_MASTER="$DOCKER_ROOT/setup/Preferences.xml"
if [[ -z "$USE_CLOUD_CONFIG" ]] && [ -f "$DOCKER_ROOT/plex-streamer/Library/Application Support/Plex Media Server/Preferences.xml" ]; then
    echo "Using existing Preferences.xml for Plex server config"
else
    # copy default plex preference file into plex config dir
    echo "Using Preferences.xml downloaded from cloud for Plex server config"
    cp "$PLEX_PREF_MASTER" "$DOCKER_ROOT/plex-streamer/Library/Application Support/Plex Media Server/Preferences.xml"
fi

# load plex claim id env variable
if grep -qs "PlexOnlineToken" "$DOCKER_ROOT/plex-streamer/Library/Application Support/Plex Media Server/Preferences.xml"  && \
( !([[ $management_mode = "2" ]] || [[ $management_mode = "3" ]]) || grep -qs "PlexOnlineToken" "$DOCKER_ROOT/plex-scanner/Library/Application Support/Plex Media Server/Preferences.xml" ) ; then
    echo "Plex servers already claimed"
    PLEX_CLAIM_ID="claim-xxxxxxxxxxxxxxx"
else

    echo "opening plex claim in browser"
    openURL "https://www.plex.tv/claim/"
        # load plex claim ID to PLEX_CLAIM_ID variable .env file
    read -i 'claim-xxxxxxxxxxxxxxx' -p 'If you are running this headless, please enter you plex claim id generated from https://www.plex.tv/claim/. If you dont know what this means just press enter:
plex claim id> ' -e PLEX_CLAIM_ID
    echo "Using PLEX_CLAIM: $PLEX_CLAIM_ID"
fi
# write PLEX_CLAIM_ID value to .env file
updateEnvFile "$ENV_FILE" "PLEX_CLAIM" "$PLEX_CLAIM_ID" force

# download wireguard config if management_mode selected
[[ $management_mode = "1" ]] && "${DOCKER_ROOT}/scripts/wireguard/download_client_config.sh"

# check for host network compatibility. HOST_NETWORK env var used in docker compose
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # ...
        HOST_NETWORK=""
        HOST_NETWORK_MODE="host"
elif [[ "$OSTYPE" == "darwin"* ]]; then
        # Mac OSX
        HOST_NETWORK="bridge"
        HOST_NETWORK_MODE="bridge"
elif [[ "$OSTYPE" == "cygwin" ]]; then
        # POSIX compatibility layer and Linux environment emulation for Windows
        HOST_NETWORK="bridge"
        HOST_NETWORK_MODE="bridge"
elif [[ "$OSTYPE" == "msys" ]]; then
        # Lightweight shell and GNU utilities compiled for Windows (part of MinGW)
        HOST_NETWORK="bridge"
        HOST_NETWORK_MODE="bridge"
elif [[ "$OSTYPE" == "win32" ]]; then
        # I'm not sure this can happen.
        HOST_NETWORK="bridge"
        HOST_NETWORK_MODE="bridge"
elif [[ "$OSTYPE" == "freebsd"* ]]; then
        # ...
        HOST_NETWORK=""
        HOST_NETWORK_MODE="host"
else
        # Unknown.
        HOST_NETWORK="bridge"
        HOST_NETWORK_MODE="bridge"
fi
sed -i '/HOST_NETWORK/'d "$ENV_FILE"
echo "HOST_NETWORK=$HOST_NETWORK" >> "$ENV_FILE"
sed -i '/HOST_NETWORK_MODE/'d "$ENV_FILE"
echo "HOST_NETWORK_MODE=$HOST_NETWORK" >> "$ENV_FILE"

ls -la "${DOCKER_ROOT}/plex-streamer/"

# start docker containers
DOCKER_COMPOSE_FILE="$DOCKER_ROOT/setup/docker-compose.yml"
SLAVE_DOCKER_COMPOSE_FILE="$DOCKER_ROOT/setup/docker-compose-lib-slave.yml"
LOGGING_COMPOSE_FILE="$DOCKER_ROOT/setup/docker-compose-logging.yml"

if [[ $management_mode = "2" ]] || [[ $management_mode = "3" ]]; then
        # load plex claim ID to PLEX_CLAIM_ID variable .env file
    read -i 'Do you want to initalise library database useing copy from cloud? Type "yes" to download> ' -e MASTER_LIB_DOWNLOAD
    if [[ "$MASTER_LIB_DOWNLOAD" = "yes" ]]; then
        DOCKER_COMPOSE_COMMAND="docker-compose --env-file \"$ENV_FILE\" --project-directory \"$DOCKER_ROOT/setup\" -f \"$DOCKER_COMPOSE_FILE\" -f \"$LOGGING_COMPOSE_FILE\" -f \"$SLAVE_DOCKER_COMPOSE_FILE\" --project-name plexdriveplus up -d --force-recreate"
        echo "initialising docker containers with command: $DOCKER_COMPOSE_COMMAND"
        bash -c "$DOCKER_COMPOSE_COMMAND"
    else
         echo "library download skipped"
    fi
    
    # inialise plex-meta-manager config
    [ -f "${DOCKER_ROOT}/plex-meta-manager/config.yml" ] || cp  "${DOCKER_ROOT}/plex-meta-manager/template.config.yml"  "${DOCKER_ROOT}/plex-meta-manager/config.yml"

else
    DOCKER_COMPOSE_COMMAND="docker-compose --env-file \"$ENV_FILE\" --project-directory \"$DOCKER_ROOT/setup\" -f \"$DOCKER_COMPOSE_FILE\" -f \"$LOGGING_COMPOSE_FILE\" $DOCKER_COMPOSE_FILE_LIB_MANGER --project-name plexdriveplus up -d --remove-orphans --force-recreate"
    echo "starting docker containers with command: $DOCKER_COMPOSE_COMMAND"
    bash -c "$DOCKER_COMPOSE_COMMAND"
fi



if [[ "$MASTER_LIB_DOWNLOAD" = "yes" ]] || ! ([[ $management_mode = "2" ]] || [[ $management_mode = "3" ]]); then
    
    sleep 10 # get plex container time to run claim script before stopping it 

    ### Plex container setup
    # Stop plex while library downloads
    echo "stopping plex instance(s) for plex library download"
    CONTAINER_PLEX_STREAMER=$(docker container ls --format {{.Names}} | grep plex_streamer)
    docker stop "$CONTAINER_PLEX_STREAMER"

    CONTAINER_PLEX_LIBRARY_SYNC=$(docker container ls --format {{.Names}} | grep rclone_library_sync)
    while [[ $(docker ps | grep "$CONTAINER_PLEX_LIBRARY_SYNC") ]] && ! [ -z "$CONTAINER_PLEX_LIBRARY_SYNC" ]
    do
    echo "$(date) - waiting for library download using $CONTAINER_PLEX_LIBRARY_SYNC to complete"
    echo "------------------------- progress ------------------------------"
    docker logs --tail 7 "$CONTAINER_PLEX_LIBRARY_SYNC"
    echo "-----------------------------------------------------------------"
    sleep 20
    done
    echo "$(date) - library download using $CONTAINER_PLEX_LIBRARY_SYNC has completed. Restarting Plex"

    # Restore from latest backup. Current DB often corrupted in sync
    bash  "$DOCKER_ROOT/scripts/plex/restore-library-backup.sh" "$DOCKER_ROOT/plex-scanner/Library"

    docker start "$CONTAINER_PLEX_STREAMER"
fi


# copy streamer plex db copied for cloud to scanner if required by selected library managemeent mode
if [[ $management_mode = "2" ]] || [[ $management_mode = "3" ]]; then

    # replace read only backup credential values in .env file with user specific creds setup above
    echo "replacing read only backup credential values in .env file with user specific creds provided for media mount"
    sed -i '/RCLONE_CONFIG_CONFIG_BACKUP_TOKEN/'d "$ENV_FILE"
    sed -i '/RCLONE_CONFIG_CONFIG_BACKUP_CLIENT/'d "$ENV_FILE"

    echo "RCLONE_CONFIG_CONFIG_BACKUP_TOKEN=${RCLONE_TOKEN}" >> "$ENV_FILE"
    echo "RCLONE_CONFIG_CONFIG_BACKUP_CLIENT_ID=${RCLONE_CLIENTID}" >> "$ENV_FILE"
    echo "RCLONE_CONFIG_CONFIG_BACKUP_CLIENT_SECRET=${RCLONE_SECRET}" >> "$ENV_FILE"
  
    # Fix Library File Ownership library root folders not already belonging to user
    USERNAME=$(id -nu $USERID)
    if [ $(ls -l "$DOCKER_ROOT/plex-scanner/Library/Application Support/Plex Media Server/" | grep -v $USERNAME | wc -l) -ne 1 ]; then
        echo "setting library file ownership to $USERID:$GROUPID for $DOCKER_ROOT/plex-scanner/Library"
        $SUDO chown -R $USERID:$GROUPID "$DOCKER_ROOT/plex-scanner/Library"
    fi

    echo "copying streamer plex config from streamer to scanner"
    # copy generic Plex Preferences.xml
    mkdir -p "$DOCKER_ROOT/plex-scanner/Library/Application Support/Plex Media Server/"
    ([[ -z "$USE_CLOUD_CONFIG" ]] && [[ -f "$DOCKER_ROOT/plex-scanner/Library/Application Support/Plex Media Server/Preferences.xml" ]] && echo "Using existing Preferences.xml for Plex scanner server config") || \
        (cp "$DOCKER_ROOT/setup/plex_scanner_Preferences.xml" "$DOCKER_ROOT/plex-scanner/Library/Application Support/Plex Media Server/Preferences.xml"  && echo "Using Preferences.xml downloaded from cloud for Plex scanner server config")
    
    #cp -r "$DOCKER_ROOT/plex-streamer/Library/Application Support/Plex Media Server/Plug-in Support" "$DOCKER_ROOT/plex-scanner/Library/Application Support/Plex Media Server/Plug-in Support"  
    DOCKER_COMPOSE_COMMAND="docker-compose --env-file \"$ENV_FILE\" --project-directory \"$DOCKER_ROOT/setup\" -f \"$DOCKER_COMPOSE_FILE\" -f \"$LOGGING_COMPOSE_FILE\"  $DOCKER_COMPOSE_FILE_LIB_MANGER  --project-name plexdriveplus up -d --remove-orphans --force-recreate"
    echo "starting docker containers with command: $DOCKER_COMPOSE_COMMAND"
    bash -c "$DOCKER_COMPOSE_COMMAND"

    echo "open plex scanner in browser to continue configuration there: https://127.0.0.1:34400/web"
fi


# Open plex in browser
echo "opening plex in browser"
openURL "http://127.0.0.1:32400/web"
# Open heimdall in browser
echo "opening heimdall in browser"
openURL http://127.0.0.1:8889

echo "open plex in browser to continue configuration there: https://127.0.0.1:32400/web"
echo "open heimdall in browser to view web portals for use in monitoring/administration: https://127.0.0.1:8889"

# copy library images / metadata backup from master
if ! [[ -z "$LIB_IMAGE_DOWNLOAD" ]]; then
    if [[ -z "$USE_CLOUD_CONFIG" ]] && [[ -f "$DOCKER_ROOT/plex-scanner/backups/meta/library_files.tar.gz" ]]; then
        echo "using existing copy of library media covers backup tar file"
    else
        echo "downloading library media covers backup from cloud"
        mkdir -p "$DOCKER_ROOT/plex-scanner"
        [[ -f $INSTALL_ENV_FILE ]] || (echo "error $INSTALL_ENV_FILE file not found, missing credentials required to load rclone config from cloud storage" &&  exit 1)
        docker run --rm -it \
        --env-file $INSTALL_ENV_FILE \
        --name rclone-config-download \
        --user "$ADMIN_USERID:$ADMIN_GROUPID" \
        -v "$DOCKER_ROOT/plex-scanner:/plex-scanner" \
        rclone/rclone \
        copy secure_backup:plex-scanner/backups /plex-scanner/backups --progress
    fi
    
    PLEX_IMAGE_BACKUP_TAR="$DOCKER_ROOT/plex-scanner/backups/meta/library_files.tar.gz"
    [[ -f "$PLEX_IMAGE_BACKUP_TAR" ]] || echo "error: backup file not found - $PLEX_IMAGE_BACKUPS"
    tar -xzf "$PLEX_IMAGE_BACKUP_TAR" -C "$DOCKER_ROOT/plex-scanner" --checkpoint=.5000
    
    # Fix Library File Ownership
    if [ "$ADMIN_USERID" -ne "$USERID" ]; then
        echo "setting library file ownership to $USERID:$GROUPID for $DOCKER_ROOT/plex-scanner/Library"
        $SUDO -R $USERID:$GROUPID "$DOCKER_ROOT/plex-scanner/Library"
    fi
    
    # Restart plex streamer
    CONTAINER_PLEX_STREAMER=$(docker container ls --format {{.Names}} | grep plex_streamer)
    docker restart "$CONTAINER_PLEX_STREAMER"
fi
echo
echo "$(date) - Plexdriveplus install Done!!!"
echo