 
 if  [ "$LOAD_LIBRARY_DB_TO_MEMORY" = "YES" ]
then
    # Keep in sync with paths used in load_master_library_db.sh
    if [ -z "$RAM_DISK_PATH" ]; then RAM_DISK_PATH=/ram_disk; else echo "RAM_DISK_PATH: $RAM_DISK_PATH"; fi
    PLEX_LIBRARY_PATH="/config/Library/Application Support/Plex Media Server"
    PLEX_LIBRARY_DATABASE_BACKUP_PATH="$PLEX_LIBRARY_PATH/Plug-in Support/Databases_Backup"
    RAM_DISK_PLEX_DATABASE_PATH="$RAM_DISK_PATH/Plug-in Support/Databases"

    for LIBRARY_FILE in $(ls $RAM_DISK_PLEX_DATABASE_PATH)
    do
        RAMDISK_LIBRARY_FILE_PATH="$RAM_DISK_PLEX_DATABASE_PATH/$LIBRARY_FILE "
        BACKUP_LIBRARY_FILE_PATH="$PLEX_LIBRARY_DATABASE_BACKUP_PATH/$LIBRARY_FILE"

        echo "copying ram disk $RAMDISK_LIBRARY_FILE_PATH to backup path $BACKUP_LIBRARY_FILE_PATH"

        cp --remove-destination "$RAMDISK_LIBRARY_FILE_PATH"  "$BACKUP_LIBRARY_FILE_PATH"
    done 
else
    echo "not using ramdisk, no need to save to disk"
fi