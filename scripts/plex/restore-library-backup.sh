#!/bin/bash
PLEX_LIBRARY_ROOT="$1"
if [ -z "$PLEX_LIBRARY_ROOT" ]; then
    PLEX_LIBRARY_ROOT=/config/Library
else
    FORCE_LIBRARY_RESTORE="TRUE"
fi
PLEX_LIBRARY_PATH="$PLEX_LIBRARY_ROOT/Application Support/Plex Media Server"
PLEX_DATABASE_PATH="$PLEX_LIBRARY_PATH/Plug-in Support/Databases"

if [ -d "$PLEX_DATABASE_PATH"]; then
    echo "checking plex database under PLEX_DATABASE_PATH: $PLEX_DATABASE_PATH"

    BACKUP_FILE=$(find "$PLEX_DATABASE_PATH" -name com.plexapp.plugins.library.db-20[0-9][0-9]-[0-9][0-9]-[0-9][0-9] | sort | tail -n 1)
    LIBRARY_FILE="$PLEX_DATABASE_PATH/com.plexapp.plugins.library.db"
    BACKUP_DATE=$(basename "$BACKUP_FILE")
    BACKUP_DATE=${BACKUP_DATE#*-}

    LIBRARY_BLOB_FILE="$PLEX_DATABASE_PATH/com.plexapp.plugins.library.blobs.db"
    BACKUP_BLOB_FILE="${LIBRARY_BLOB_FILE}-${BACKUP_DATE}"
    BACKUP_BLOB_FILE=$(find "$PLEX_DATABASE_PATH" -name com.plexapp.plugins.library.blobs.db-20[0-9][0-9]-[0-9][0-9]-[0-9][0-9] | sort | tail -n 1)

    # check latest 2 server logs for db corruption warnings
    [[ -f "$PLEX_LIBRARY_PATH/Logs/Plex Media Server.log" ]] && \
        ([[ $(cat "$PLEX_LIBRARY_PATH/Logs/Plex Media Server.log" | grep "database disk image is malformed") ]] || \
        [[ $(cat "$PLEX_LIBRARY_PATH/Logs/Plex Media Server.log" | grep "ERROR - Database corruption") ]]) \
        && \
        [[ -f "$PLEX_LIBRARY_PATH/Logs/Plex Media Server.1.log" ]] && \
        ([[ $(cat "$PLEX_LIBRARY_PATH/Logs/Plex Media Server.1.log" | grep "database disk image is malformed") ]] || \
        [[ $(cat "$PLEX_LIBRARY_PATH/Logs/Plex Media Server.1.log" | grep "ERROR - Database corruption") ]]) \
        && LIBRARY_DB_CORRUPT="TRUE" || \
        LIBRARY_DB_CORRUPT=

    # check tmp dir to see if pms appears to have been immediatly crashing and starting again within the last 5 minutes
    [ $(find /tmp -type d -mmin -5 | grep pms- |  wc -l) -gt 50 ] && echo "Plex server keeps crashing immediatly. Flagging DB as possibly corrupt" && LIBRARY_DB_CORRUPT="TRUE"

    if ( [[ $LIBRARY_DB_CORRUPT = "TRUE" ]] && echo "Library DB corrupt, restoring from latest backup.") || ! [[ -z $FORCE_LIBRARY_RESTORE ]]; then
        if [[ -f "$BACKUP_BLOB_FILE" ]]; then
            echo "Loaded plex library db from backup: $BACKUP_FILE"
            cp "$BACKUP_FILE" "$LIBRARY_FILE"
            rm "${LIBRARY_FILE}-shm"
            rm "${LIBRARY_FILE}-wal"

            echo "Loaded plex library blobs from backup: $BACKUP_BLOB_FILE"
            cp "$BACKUP_BLOB_FILE" "$LIBRARY_BLOB_FILE"
            rm "${LIBRARY_BLOB_FILE}-shm"
            rm "${LIBRARY_BLOB_FILE}-wal"
        else
            echo "error: com.plexapp.plugins.library.blobs.db backup with date matching com.plexapp.plugins.library.db backup not found. backup restore aborted"
        fi
    fi
else
    echo "error, unable to check/restore plex database. Plex database directory is missing: $PLEX_DATABASE_PATH"
fi


