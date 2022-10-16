#!/usr/bin/with-contenv bash
    . /scripts/plex/variables

# change directory to root path for tar file
cd "$library_path_local"

echo "$(date) ****** Starting save_library_images_to_tar.sh ******"

TAR_BACKUP_FOLDER="${library_images_backup_path_master}"

LATEST_TAR_BACKUP_FOLDER_FILE=$(find "$TAR_BACKUP_FOLDER" -name ${library_images_tar_filename_start}_[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9][0-9][0-9]_to_[0-9][0-9][0-9][0-9]-20[0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9][0-9][0-9].tar.gz | sort | tail -n 1)
LATEST_TAR_BACKUP_FOLDER_FILE=$(basename "$LATEST_TAR_BACKUP_FOLDER_FILE")
LATEST_TAR_BACKUP_DATE=$(echo $LATEST_TAR_BACKUP_FOLDER_FILE | cut -d "." -f1 | cut -d "_" -f5)

LATEST_TAR_BACKUP_DATE=${LATEST_TAR_BACKUP_DATE:-"1970-01-01 0000"}

NEW_TAR_BACKUP_DATE=$(date +"${current_datetime_format}")

max_file_mod_time=$(date --date="${NEW_TAR_BACKUP_DATE}") 
min_file_mod_time=$(date --date="${LATEST_TAR_BACKUP_DATE}")

TEMP_TAR_FILE_NO_EXT="/tmp/${library_images_tar_filename_start}_${LATEST_TAR_BACKUP_DATE}_to_${NEW_TAR_BACKUP_DATE}"
TEMP_TAR_FILE="${TEMP_TAR_FILE_NO_EXT}.tar.gz"
LOG_FILE="$TEMP_TAR_FILE.log"
LIST_FILE="${TEMP_TAR_FILE}_file_list.txt"


echo "$(date) ****** Starting image Libary tar file creation ******"
echo "$(date) ****** Starting image Libary tar file creation ******" > "$LOG_FILE"

echo "Temp Image Backup TAR: ${TEMP_TAR_FILE}"

# find files last modified between dates and send to tar
echo "Finding files modified: ${min_file_mod_time} - ${max_file_mod_time}"
echo "Finding files modified: ${min_file_mod_time} - ${max_file_mod_time}" >> "$LOG_FILE"
find "./Metadata" "./Media" -type f  -newermt "${min_file_mod_time}" ! -newermt "${max_file_mod_time}" > "${LIST_FILE}"
echo "$(date) Found $( cat "${LIST_FILE}" | wc -l) files. Adding to tar ${TEMP_TAR_FILE}" >> "$LOG_FILE"

rm -f /tmp/split_file_list_*
split "${LIST_FILE}" -a 3 -d -l 100000 /tmp/split_file_list_

for split_list_file in $(ls /tmp/split_file_list_*)
do
    split_number="${split_list_file##*_}"
    SPLIT_TEMP_TAR_FILE="${TEMP_TAR_FILE_NO_EXT}_${split_number}.tar.gz"
    echo "$(date) Adding $( cat "${split_list_file}" | wc -l) files to tar ${SPLIT_TEMP_TAR_FILE}"
    echo "$(date) Adding $( cat "${split_list_file}" | wc -l) files to tar ${SPLIT_TEMP_TAR_FILE}" >> "$LOG_FILE"
    tar --create -z --file="${SPLIT_TEMP_TAR_FILE}" --files-from="${split_list_file}" >> "$LOG_FILE"
    stat "${SPLIT_TEMP_TAR_FILE}" >> "$LOG_FILE"
    
    if  gzip -v -t "${SPLIT_TEMP_TAR_FILE}" 2> "$LOG_FILE"
    then
        echo "tar gzip compression tested ok, moving ${SPLIT_TEMP_TAR_FILE} to dir ${TAR_BACKUP_FOLDER}"
        mv "$SPLIT_TEMP_TAR_FILE" "$TAR_BACKUP_FOLDER/"
        echo "$(date) ****** Finished image Libary tar file load ******" >> "$LOG_FILE"
        echo "" >> "$LOG_FILE"
        echo "files added to tar:" >> "$LOG_FILE"
        echo "" >> "$LOG_FILE"
        cat "$split_list_file" >> "$LOG_FILE"backup
        mv "$LOG_FILE" "$TAR_BACKUP_FOLDER/"
        rm "$split_list_file"
    else
        echo "error - tar gzip compression failed when tested: removing ${SPLIT_TEMP_TAR_FILE}" >> "$LOG_FILE"
        echo "error - tar gzip compression failed when tested, removing ${SPLIT_TEMP_TAR_FILE}"
        
        echo "$(date) ****** Finished image Libary tar file rebuild ******"  >> "$LOG_FILE"
    
        rm "$SPLIT_TEMP_TAR_FILE"
        #break
    fi
done
    


echo "$(date) ****** Finished save_library_images_to_tar.sh ******"