#!/bin/bash
PLEX_LIBRARY_ROOT="/config/Library"
TEMP_TAR_FILE=/tmp/library_files.tar.gz
TAR_BACKUP_FOLDER=/config/backups/meta
LOG_FILE="$TEMP_TAR_FILE.log"

echo "$(date) ****** Starting image Libary tar file rebuild ******"
echo "$(date) ****** Starting image Libary tar file rebuild ******" > "$LOG_FILE"
cd "$PLEX_LIBRARY_ROOT"
tar -cvpzf "$TEMP_TAR_FILE" "./Application Support/Plex Media Server/Metadata" "./Application Support/Plex Media Server/Media" >> "$LOG_FILE"

if [ $(gzip -t "$TEMP_TAR_FILE") ]
then
    echo "tar gzip compression tested ok, overwriting old version"
    mv "$TEMP_TAR_FILE" "$TAR_BACKUP_FOLDER/"
    mv "$LOG_FILE" "$TAR_BACKUP_FOLDER/"
else
    echo "error tar gzip compression failed when tested, removing instead of overwriting old version"
    rm "$TEMP_TAR_FILE"
fi

echo "$(date) ****** Finished image Libary tar file rebuild ******" >> "$LOG_FILE"
echo "$(date) ****** Finished image Libary tar file rebuild ******"