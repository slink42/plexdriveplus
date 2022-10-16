#!/usr/bin/with-contenv bash
. /scripts/plex/variables

if [ -d "${library_db_backup_path_local}" ] && [ -d "${library_db_backup_path_master}" ]; then
    echo "checking plex database under PLEX_DATABASE_PATH: ${library_db_backup_path_local}"

    BACKUP_FILE=$(find "${library_db_backup_path_master}" -name com.plexapp.plugins.library.db-20[0-9][0-9]-[0-9][0-9]-[0-9][0-9] | sort | tail -n 1)
    LIBRARY_FILE="${library_db_backup_path_local}/com.plexapp.plugins.library.db"
    BACKUP_DATE=$(basename "$BACKUP_FILE")
    BACKUP_DATE=${BACKUP_DATE#*-}

    LIBRARY_BLOB_FILE="${library_db_backup_path_local}/com.plexapp.plugins.library.blobs.db"
    BACKUP_BLOB_FILE="${LIBRARY_BLOB_FILE}-${BACKUP_DATE}"
    if ! [ -f "${BACKUP_BLOB_FILE}" ]; then
        echo "Matching blob db file for ${LIBRARY_FILE} not found. Looking for library db matching latest blob file instead."
        BACKUP_BLOB_FILE=$(find "${library_db_backup_path_master}" -name com.plexapp.plugins.library.blobs.db-20[0-9][0-9]-[0-9][0-9]-[0-9][0-9] | sort | tail -n 1)
        echo "Latest blob db file: ${BACKUP_BLOB_FILE}"
        BACKUP_DATE=$(basename "$BACKUP_FILE")
        BACKUP_DATE=${BACKUP_DATE#*-}
        BACKUP_FILE="${LIBRARY_FILE}-${BACKUP_DATE}"
    fi
    
    # check latest 2 server logs for db corruption warnings
    [[ -f "${library_path_local}/Logs/Plex Media Server.log" ]] && \
        ([[ $(cat "${library_path_local}/Logs/Plex Media Server.log" | grep "database disk image is malformed") ]] || \
        [[ $(cat "${library_path_local}/Logs/Plex Media Server.log" | grep "ERROR - Database corruption") ]]) \
        && \
        [[ -f "${library_path_local}/Logs/Plex Media Server.1.log" ]] && \
        ([[ $(cat "${library_path_local}/Logs/Plex Media Server.1.log" | grep "database disk image is malformed") ]] || \
        [[ $(cat "${library_path_local}/Logs/Plex Media Server.1.log" | grep "ERROR - Database corruption") ]]) \
        && LIBRARY_DB_CORRUPT="TRUE" || \
        LIBRARY_DB_CORRUPT=

    # check tmp dir to see if pms appears to have been immediatly crashing and starting again within the last 5 minutes
    [ $(find /tmp -type d -mmin -5 | grep pms- |  wc -l) -gt 50 ] && echo "Plex server keeps crashing immediatly. Flagging DB as possibly corrupt" && LIBRARY_DB_CORRUPT="TRUE"

    if ( [[ $LIBRARY_DB_CORRUPT = "TRUE" ]] && echo "Library DB corrupt, restoring from latest backup.") || ! [[ -z ${force_library_restore} ]]; then
        if [[ -f "$BACKUP_BLOB_FILE" ]]; then
            echo "Loaded plex library db from backup: $BACKUP_FILE"
            cp --remove-destination "$BACKUP_FILE" "$LIBRARY_FILE"
            rm "${LIBRARY_FILE}-shm"
            rm "${LIBRARY_FILE}-wal"

            echo "Loaded plex library blobs from backup: $BACKUP_BLOB_FILE"
            cp --remove-destination "$BACKUP_BLOB_FILE" "$LIBRARY_BLOB_FILE"
            rm "${LIBRARY_BLOB_FILE}-shm"
            rm "${LIBRARY_BLOB_FILE}-wal"
        else
            echo "error: com.plexapp.plugins.library.blobs.db backup with date matching com.plexapp.plugins.library.db backup not found. backup restore aborted"
        fi
    fi
else
    echo "error, unable to check/restore plex database. Plex database directory is missing: ${library_db_backup_path_local}"
fi


