#!/usr/bin/with-contenv bash
. /scripts/plex/variables

for  lib_file in "${library_files[@]}"
do
    # delete library db files older than ${library_db_backup_retention_days} days
    find "${library_db_backup_path_local}" -name ${lib_file}-20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]  -type f -mtime +${library_db_backup_retention_days} -exec rm -f {} \;
done