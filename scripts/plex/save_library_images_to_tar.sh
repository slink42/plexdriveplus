PLEX_LIBRARY_ROOT="/config/Library"
LOG_FILE=/config/backups/meta/library_files_updated.tar.gz.log

echo "$(date) ****** Starting image Libary tar file rebuild ******"
echo "$(date) ****** Starting image Libary tar file rebuild ******" > "$LOG_FILE"
cd "$PLEX_LIBRARY_ROOT"
tar -cvpzf /config/backups/meta/library_files_updated.tar.gz "./Application Support/Plex Media Server/Metadata" "./Application Support/Plex Media Server/Media" >> "$LOG_FILE"

if [ $(gzip -t /config/backups/meta/library_files_updated.tar.gz) ]
then
    echo "tar gzip compression tested ok, overwriting old version"
    mv /config/backups/meta/library_files_updated.tar.gz /config/backups/meta/library_files.tar.gz
else
    echo "error tar gzip compression failed when tested, removing instead of overwriting old version"
    rm /config/backups/meta/library_files_updated.tar.gz
fi

echo "$(date) ****** Finished image Libary tar file rebuild ******" >> "$LOG_FILE"
echo "$(date) ****** Finished image Libary tar file rebuild ******"