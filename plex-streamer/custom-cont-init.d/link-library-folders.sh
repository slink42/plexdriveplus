#!/bin/bash

echo "starting linkage plex library mount paths to library path"

if [ -z "$SCANNER_LIBRARY_PATH" ]; then SCANNER_LIBRARY_PATH=/mnt/plex-scanner/Library/Application\ Support/Plex\ Media\ Server; else echo "SCANNER_LIBRARY_PATH: $SCANNER_LIBRARY_PATH"; fi
if [ -z "$STREAMER_LIBRARY_PATH" ]; then STREAMER_LIBRARY_PATH=/mnt/plex-streamer/Library/Application\ Support/Plex\ Media\ Server; else echo "STREAMER_LIBRARY_PATH: $STREAMER_LIBRARY_PATH"; fi
SCANNER_LIBRARY_FOLDERS=( Metadata Media "Plug-in Support" )
#STREAMER_LIBRARY_FOLDERS=( Metadata Media "Plug-in Support" Cache Codecs "Crash Reports" Logs Media Metadata Plug-ins Preferences.xml )

mkdir -p  /config/Library/Application\ Support/Plex\ Media\ Server/


for  FOLDER in "${SCANNER_LIBRARY_FOLDERS[@]}"
do
    # remove folder from rclone media folder list
    #STREAMER_LIBRARY_FOLDERS=( "${STREAMER_LIBRARY_FOLDERS[@]/$FOLDER}" )
    echo "mounting $FOLDER"
    MEDIA_MOUNT_CONTAINER_PATH=/config/Library/Application\ Support/Plex\ Media\ Server/$FOLDER
    DRIVE_MOUNT_CONTAINER_PATH="$SCANNER_LIBRARY_PATH/$FOLDER"

    mkdir -p  "$DRIVE_MOUNT_CONTAINER_PATH"

    path_found=$( ls -la "$MEDIA_MOUNT_CONTAINER_PATH"  2> /dev/null | grep -ic "$DRIVE_MOUNT_CONTAINER_PATH" ) 2> /dev/null 
    if [ $path_found -eq 1 ]
    then
        echo "Already linked from $DRIVE_MOUNT_CONTAINER_PATH to $MEDIA_MOUNT_CONTAINER_PATH"
    else
        if [ -d "${MEDIA_MOUNT_CONTAINER_PATH}" ]; then
            echo "replacing symbolic link to $MEDIA_MOUNT_CONTAINER_PATH with new source path $DRIVE_MOUNT_CONTAINER_PATH"
            ln -sfn "$DRIVE_MOUNT_CONTAINER_PATH" "$MEDIA_MOUNT_CONTAINER_PATH"
        else
            echo "creating symbolic link to $MEDIA_MOUNT_CONTAINER_PATH from $DRIVE_MOUNT_CONTAINER_PATH"
            ln -s "$DRIVE_MOUNT_CONTAINER_PATH" "$MEDIA_MOUNT_CONTAINER_PATH"
        fi
        # set plex user symlink as owner
        chown -h abc:users "$MEDIA_MOUNT_CONTAINER_PATH"
    fi
done


#for  FOLDER in "${STREAMER_LIBRARY_FOLDERS[@]}"
#do
#    if [ ! -z "$FOLDER" ]; then
#        echo "mounting $FOLDER"
#        MEDIA_MOUNT_CONTAINER_PATH=/config/Library/Application\ Support/Plex\ Media\ Server/$FOLDER
#        DRIVE_MOUNT_CONTAINER_PATH="$STREAMER_LIBRARY_PATH/$FOLDER"
#        mkdir -p  "$DRIVE_MOUNT_CONTAINER_PATH"
#        path_found=$( ls -la "$MEDIA_MOUNT_CONTAINER_PATH"  2> /dev/null | grep -ic "$DRIVE_MOUNT_CONTAINER_PATH" )
#        if [ $path_found -eq 1 ]
#        then
#          echo "Already linked from $DRIVE_MOUNT_CONTAINER_PATH to $MEDIA_MOUNT_CONTAINER_PATH"
#        else
#            if [ -d "${MEDIA_MOUNT_CONTAINER_PATH}" ]; then
#                echo "replacing symbolic link to $MEDIA_MOUNT_CONTAINER_PATH with new source path $DRIVE_MOUNT_CONTAINER_PATH"
#                ln -sfn "$DRIVE_MOUNT_CONTAINER_PATH" "$MEDIA_MOUNT_CONTAINER_PATH"
#            else
#                echo "creating symbolic link to $MEDIA_MOUNT_CONTAINER_PATH from $DRIVE_MOUNT_CONTAINER_PATH"
#                ln -s "$DRIVE_MOUNT_CONTAINER_PATH" "$MEDIA_MOUNT_CONTAINER_PATH"
#            fi
#            # set plex user symlink as owner
#            chown -h abc:users "$MEDIA_MOUNT_CONTAINER_PATH"
#        fi
#    fi
#done
