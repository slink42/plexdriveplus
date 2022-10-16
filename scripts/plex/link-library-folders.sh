#!/bin/bash

echo "starting linkage plex library mount paths to library path"

SCANNER_LIBRARY_FOLDERS=( Metadata Media )

mkdir -p  "${library_path_local}"


for  FOLDER in "${SCANNER_LIBRARY_FOLDERS[@]}"
do
    # remove folder from rclone media folder list
    #STREAMER_LIBRARY_FOLDERS=( "${STREAMER_LIBRARY_FOLDERS[@]/$FOLDER}" )
    echo "mounting $FOLDER"
    MEDIA_MOUNT_CONTAINER_PATH="${library_path_local}/$FOLDER"
    MEDIA_MOUNT_CONTAINER_PATH_BACKUP="${library_path_local}/${FOLDER}_OLD"
    DRIVE_MOUNT_CONTAINER_PATH="${library_path_master}/$FOLDER"

    mkdir -p  "$DRIVE_MOUNT_CONTAINER_PATH"

    path_found=$( ls -la "$MEDIA_MOUNT_CONTAINER_PATH"  2> /dev/null | grep -ic "$DRIVE_MOUNT_CONTAINER_PATH" ) 2> /dev/null 
    if  [ -L "${MEDIA_MOUNT_CONTAINER_PATH}" ] && [ $path_found -eq 1 ]
    then
        echo "Already linked from $DRIVE_MOUNT_CONTAINER_PATH to $MEDIA_MOUNT_CONTAINER_PATH"
    else
        if [ -L "${MEDIA_MOUNT_CONTAINER_PATH}" ]; then
            echo "replacing symbolic link to $MEDIA_MOUNT_CONTAINER_PATH with new source path $DRIVE_MOUNT_CONTAINER_PATH"
            ln -sfn "$DRIVE_MOUNT_CONTAINER_PATH" "$MEDIA_MOUNT_CONTAINER_PATH"
        else
            if [ -d "${MEDIA_MOUNT_CONTAINER_PATH}" ]; then
                echo "moving directory found in location for symbolic link target"
                [ -d "${MEDIA_MOUNT_CONTAINER_PATH_BACKUP}" ] && rm -r "$MEDIA_MOUNT_CONTAINER_PATH_BACKUP"
                mv "$MEDIA_MOUNT_CONTAINER_PATH" "$MEDIA_MOUNT_CONTAINER_PATH_BACKUP"
            fi

            echo "creating symbolic link to $MEDIA_MOUNT_CONTAINER_PATH from $DRIVE_MOUNT_CONTAINER_PATH"
            ln -s "$DRIVE_MOUNT_CONTAINER_PATH" "$MEDIA_MOUNT_CONTAINER_PATH"
            
        fi
        # set plex user symlink as owner
        chown -h ${PLEX_UID}:${PLEX_GID} "$MEDIA_MOUNT_CONTAINER_PATH"
    fi
done