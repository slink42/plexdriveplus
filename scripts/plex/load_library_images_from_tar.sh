#!/usr/bin/with-contenv bash
. /scripts/plex/variables

temp_filename_start="library_images"

TAR_BACKUP_FOLDER="${library_images_backup_path_master}"
LOG_FILE="${library_path_local}/library_images.log"
DONE_FILE="${library_path_local}/library_images_loaded.dat"
FOUND_FILE="${library_path_local}/library_images_found.dat"


[ -f "${DONE_FILE}" ] && loaded_tar_backup_files=$(cat ${DONE_FILE})

find "$TAR_BACKUP_FOLDER" -name ${temp_filename_start}_[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9][0-9][0-9]_to_[0-9][0-9][0-9][0-9]-20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9][0-9][0-9]_[0-9][0-9][0-9].tar.gz sort > ${FOUND_FILE}

echo "$(date) ****** Starting image Libary load from tar file ******"

cd "${library_path_local}"
while read tar_backup_file;
do 
    tar_backup_filename=$(basename ${tar_backup_file})
    if [ $(cat ${DONE_FILE} | grep ${tar_backup_filename}) ]
    then
        echo "skipping and deleted tar found in done file {$(basename ${DONE_FILE})}: ${tar_backup_file}"
        rm "${tar_backup_file}"
    else
        echo "Loading images from Image Backup TAR: $tar_backup_file"

        echo "${tar_backup_file}" >>  "${DONE_FILE}"
    fi
done < ${FOUND_FILE}

echo "$(date) ****** Finished image Libary load from tar file ******"


echo "$(date) ****** Starting image Libary load from tar file ******" > "$LOG_FILE"
cd "${library_path_local}"

if [ $(gzip -t "$LATEST_TAR_BACKUP_FOLDER_FILE") ]
then
    echo "tar gzip compression tested ok, overwriting old version"
    tar -cvpzf "$TEMP_TAR_FILE" "./Metadata" "./Media" >> "$LOG_FILE"
else
    echo "error tar gzip compression failed when tested, removing file from disk: ${LATEST_TAR_BACKUP_FOLDER_FILE}"
    rm "${LATEST_TAR_BACKUP_FOLDER_FILE}"
fi

echo "$(date) ****** Finished image Libary tar file rebuild ******" >> "$LOG_FILE"
echo "$(date) ****** Finished image Libary tar file rebuild ******"