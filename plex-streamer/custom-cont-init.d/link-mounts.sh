#!/bin/bash

if [ -z "$RCLONE_MEDIA_PATH" ]; then RCLONE_MEDIA_PATH=/mnt/rclone/secure_media/Media; else echo "RCLONE MOUNT: $RCLONE_MEDIA_PATH"; fi
if [ -z "$PLEXDRIVE_MEDIA_PATH" ]; then PLEXDRIVE_MEDIA_PATH=/mnt/rclone/secure_media_plexdrive/Media; else echo "PLEXDRIVE MOUNT: $PLEXDRIVE_MEDIA_PATH"; fi
# PLEXDRIVE_MEDIA_FOLDERS="movies-4k tv-4k"

mkdir -p  /plex/media/Media
RCLONE_MEDIA_FOLDERS=$(ls $RCLONE_MEDIA_PATH)

for FOLDER in $PLEXDRIVE_MEDIA_FOLDERS
do
    # remove folder from rclone media folder list
    RCLONE_MEDIA_FOLDERS=$(printf '%s\n' "${RCLONE_MEDIA_FOLDERS//$FOLDER/}")

    MEDIA_MOUNT_CONTAINER_PATH=/plex/media/Media/$FOLDER
    DRIVE_MOUNT_CONTAINER_PATH=$PLEXDRIVE_MEDIA_PATH/$FOLDER

    mkdir -p  $DRIVE_MOUNT_CONTAINER_PATH

    path_found=$( ls -la $MEDIA_MOUNT_CONTAINER_PATH 2> /dev/null | grep -ic $DRIVE_MOUNT_CONTAINER_PATH )
    if [ $path_found -eq 1 ]
    then
        echo "Already linked from $DRIVE_MOUNT_CONTAINER_PATH to $MEDIA_MOUNT_CONTAINER_PATH"
    else
        if [ -d "${MEDIA_MOUNT_CONTAINER_PATH}" ]; then
            echo "replacing symbolic link to $MEDIA_MOUNT_CONTAINER_PATH with new source path $DRIVE_MOUNT_CONTAINER_PATH"
            ln -sfn $DRIVE_MOUNT_CONTAINER_PATH $MEDIA_MOUNT_CONTAINER_PATH
        else
            echo "creating symbolic link to $MEDIA_MOUNT_CONTAINER_PATH from $DRIVE_MOUNT_CONTAINER_PATH"
            ln -s $DRIVE_MOUNT_CONTAINER_PATH $MEDIA_MOUNT_CONTAINER_PATH
        fi
        # set plex user symlink as owner
        chown -h abc:users $MEDIA_MOUNT_CONTAINER_PATH
    fi
done


for FOLDER in $RCLONE_MEDIA_FOLDERS
do

    MEDIA_MOUNT_CONTAINER_PATH=/plex/media/Media/$FOLDER
    DRIVE_MOUNT_CONTAINER_PATH=$RCLONE_MEDIA_PATH/$FOLDER

    mkdir -p  $DRIVE_MOUNT_CONTAINER_PATH

    path_found=$( ls -la $MEDIA_MOUNT_CONTAINER_PATH 2> /dev/null | grep -ic $DRIVE_MOUNT_CONTAINER_PATH )
    if [ $path_found -eq 1 ]
    then
      echo "Already linked from $DRIVE_MOUNT_CONTAINER_PATH to $MEDIA_MOUNT_CONTAINER_PATH"
    else
        if [ -d "${MEDIA_MOUNT_CONTAINER_PATH}" ]; then
            echo "replacing symbolic link to $MEDIA_MOUNT_CONTAINER_PATH with new source path $DRIVE_MOUNT_CONTAINER_PATH"
            ln -sfn $DRIVE_MOUNT_CONTAINER_PATH $MEDIA_MOUNT_CONTAINER_PATH
        else
            echo "creating symbolic link to $MEDIA_MOUNT_CONTAINER_PATH from $DRIVE_MOUNT_CONTAINER_PATH"
            ln -s $DRIVE_MOUNT_CONTAINER_PATH $MEDIA_MOUNT_CONTAINER_PATH
        fi
        # set plex user symlink as owner
        chown -h abc:users $MEDIA_MOUNT_CONTAINER_PATH
    fi
done
