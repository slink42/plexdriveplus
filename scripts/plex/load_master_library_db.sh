#!/bin/bash

echo 
echo "starting copy and sync of pelx master library to local working library path"
echo 

if [ -z "$SCANNER_LIBRARY_PATH" ]; then SCANNER_LIBRARY_PATH=/mnt/plex-scanner/Library/Application\ Support/Plex\ Media\ Server; else echo "SCANNER_LIBRARY_PATH: $SCANNER_LIBRARY_PATH"; fi
if [ -z "$STREAMER_LIBRARY_PATH" ]; then STREAMER_LIBRARY_PATH=/mnt/plex-streamer/Library/Application\ Support/Plex\ Media\ Server; else echo "STREAMER_LIBRARY_PATH: $STREAMER_LIBRARY_PATH"; fi
if [ -z "$RAM_DISK_PATH" ]; then RAM_DISK_PATH=/ram_disk; else echo "RAM_DISK_PATH: $RAM_DISK_PATH"; fi


LIBRARY_MASTER_BACKUP_PATH="$SCANNER_LIBRARY_PATH/Plug-in Support/Databases"
MEDIA_MOUNT_CONTAINER_PATH="/config/Library/Application Support/Plex Media Server/Plug-in Support/Databases"
MEDIA_MOUNT_CONTAINER_PATH_BACKUP="/config/Library/Application Support/Plex Media Server/Plug-in Support/Databases_Backup"
RAM_DISK_PLEX_DATABASE_PATH="$RAM_DISK_PATH/Plug-in Support/Databases"

mkdir -p  "$LIBRARY_MASTER_BACKUP_PATH"
mkdir -p  "$MEDIA_MOUNT_CONTAINER_PATH"
mkdir -p  "$MEDIA_MOUNT_CONTAINER_PATH_BACKUP"
mkdir -p  "$RAM_DISK_PLEX_DATABASE_PATH"

[ -z "$LOAD_LIBRARY_DB_TO_MEMORY" ] && LOAD_LIBRARY_DB_TO_MEMORY="NO"
LIBRARY_FILES=( com.plexapp.plugins.library.db com.plexapp.plugins.library.blobs.db )

mkdir -p  /config/Library/Application\ Support/Plex\ Media\ Server/

function syncPlexDB() {
    PLEX_DB_1=${1}
    PLEX_DB_2=${2}
    if [ -f "$PLEX_DB_1" ]  && [ -f "$PLEX_DB_2" ] 
    then
        PLEX_DB_SYNC_BIN=/scripts/plex/plex_db_sync.sh
        [ -f "$PLEX_DB_SYNC_BIN" ] || (wget https://raw.githubusercontent.com/Fmstrat/plex-db-sync/master/plex-db-sync -O "$PLEX_DB_SYNC_BIN")

        echo "making backup of backup db $PLEX_DB_2 -> $PLEX_DB_2-old2"
        cp "$PLEX_DB_2"  "$PLEX_DB_2-old2"

        echo "starting plex library db sync between live db: $PLEX_DB_1 and db backup: $PLEX_DB_2"
        if [ $("$PLEX_DB_SYNC_BIN" --plex-db-1 "$PLEX_DB_1" --plex-db-2 "$PLEX_DB_2" \
            --plex-start-1 "echo 'starts automaticly'" \
	        --plex-stop-1 "echo 'running prior to plex startup, expected to already be stopped.'" \
      	    --plex-start-2 "echo 'library backup, nothing to start'" \
	        --plex-stop-2 "echo 'library backup, nothing to stop.'") ]
        then
            echo "overwritng backup db with updated adn synced version $PLEX_DB_1 -> $PLEX_DB_2"
            cp "$PLEX_DB_1"  "$PLEX_DB_2"
        else
            echo "error:  a failure exit code was returned by $PLEX_DB_SYNC_BIN"
        fi
    else
        echo "error: unable to sync between $PLEX_DB_1 and $PLEX_DB_2. One of the fiels was not found"
    fi       
}

for  LIBRARY_FILE in "${LIBRARY_FILES[@]}"
do
    MASTER_BACKUP_LIBRARY_FILE_PATH=$(find "$LIBRARY_MASTER_BACKUP_PATH" -name $LIBRARY_FILE-20[0-9][0-9]-[0-9][0-9]-[0-9][0-9] | sort | tail -n 1)
    if [ -f "$MASTER_BACKUP_LIBRARY_FILE_PATH" ]
    then
        BACKUP_LIBRARY_FILE_TARGET_PATH="$MEDIA_MOUNT_CONTAINER_PATH_BACKUP/$LIBRARY_FILE"
        if  [ "$LOAD_LIBRARY_DB_TO_MEMORY" = "YES" ]
        then
            echo "setting ram disk as path for working copy of $LIBRARY_FILE"
            LIBRARY_FILE_TARGET_PATH="$RAM_DISK_PLEX_DATABASE_PATH/$LIBRARY_FILE"

            echo "copying $MASTER_BACKUP_LIBRARY_FILE_PATH to $LIBRARY_FILE_TARGET_PATH"
            cp "$MASTER_BACKUP_LIBRARY_FILE_PATH"  "$LIBRARY_FILE_TARGET_PATH"

            echo "linking $LIBRARY_FILE_TARGET_PATH to $MEDIA_MOUNT_CONTAINER_PATH/$LIBRARY_FILE"
            ln --force -s "$LIBRARY_FILE_TARGET_PATH" "$MEDIA_MOUNT_CONTAINER_PATH/$LIBRARY_FILE"
        else
        
            echo "setting default library path for working copy of $LIBRARY_FILE"
            LIBRARY_FILE_TARGET_PATH="$MEDIA_MOUNT_CONTAINER_PATH/$LIBRARY_FILE"

            if [ -f "$LIBRARY_FILE_TARGET_PATH" ]
            then
                echo "making backup of $LIBRARY_FILE_TARGET_PATH to $BACKUP_LIBRARY_FILE_TARGET_PATH"
                cp "$LIBRARY_FILE_TARGET_PATH"  "$BACKUP_LIBRARY_FILE_TARGET_PATH"
            fi

            echo "copying $MASTER_BACKUP_LIBRARY_FILE_PATH to $LIBRARY_FILE_TARGET_PATH"
            cp "$MASTER_BACKUP_LIBRARY_FILE_PATH"  "$LIBRARY_FILE_TARGET_PATH"
        fi

        # set plex user symlink as owner
        chown -h abc:users "$LIBRARY_FILE_TARGET_PATH"

        if [ "$LIBRARY_FILE" = "com.plexapp.plugins.library.db" ]
        then
            syncPlexDB "$LIBRARY_FILE_TARGET_PATH" "$BACKUP_LIBRARY_FILE_TARGET_PATH"
        fi
    else
        echo "error: master copy of library file not found: copying $RAM_DISK_PATH to ram disk path $RAM_DISK_PATH"        
    fi
done


echo 
echo "dinished copy and sync of plex master library to local working library path"
echo 