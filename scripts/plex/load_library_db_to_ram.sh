#!/usr/bin/with-contenv bash
. /scripts/plex/variables

echo 
echo "starting copy and sync of plex master library to local working library path"
echo 

mkdir -p "${library_db_path_local}"
chown -R -h ${PLEX_UID}:${PLEX_GID} "$(dirname ${library_db_path_local})"
mkdir -p "${library_db_backup_path_local}"
chown -R -h ${PLEX_UID}:${PLEX_GID} "${library_db_backup_path_local}"
mkdir -p "${library_db_backup_path_master}"
mkdir -p "${ram_disk_db_path}"
chown -R -h ${PLEX_UID}:${PLEX_GID} "${ram_disk_db_path}"


# syncPlexDB needs some work. Probably better to just use the sync plex watch history to cloud feature instead
function syncPlexDB() {
    PLEX_DB_1=${1}
    PLEX_DB_2=${2}
    if [ -f "$PLEX_DB_1" ]  && [ -f "$PLEX_DB_2" ] 
    then
        echo "making backup of backup db $PLEX_DB_2 -> $PLEX_DB_2-old2"
        cp "$PLEX_DB_2"  "$PLEX_DB_2-old2"

        [ -d /tmp/plex-db-sync ] && rm -r /tmp/plex-db-sync

        echo "starting plex library db sync between live db: $PLEX_DB_1 and db backup: $PLEX_DB_2"
        "/scripts/plex/plex_db_sync.sh" --plex-db-1 "$PLEX_DB_1" --plex-db-2 "$PLEX_DB_2" \
            --plex-start-1 "echo 'starts automaticly'" \
	        --plex-stop-1 "echo 'running prior to plex startup, expected to already be stopped.'" \
      	    --plex-start-2 "echo 'library backup, nothing to start'" \
	        --plex-stop-2 "echo 'library backup, nothing to stop.'"
        if [ -z "$SYNC_FAILURE" ]
        then
            echo "overwritng backup db with updated and synced version $PLEX_DB_1 -> $PLEX_DB_2"
            cp "$PLEX_DB_1"  "$PLEX_DB_2"
        else
            echo "error:  a failure exit code was returned by /scripts/plex/plex_db_sync.sh"
        fi
    else
        echo "error: unable to sync between $PLEX_DB_1 and $PLEX_DB_2. One of the files was not found"
    fi       
}

for  lib_file in "${library_files[@]}"
do
    library_db_backup_file_master=$(find "${library_db_backup_path_master}" -name ${lib_file}-20[0-9][0-9]-[0-9][0-9]-[0-9][0-9] | sort | tail -n 1)
    library_db_backup_file_local="${library_db_backup_path_local}/${lib_file}"
    if [ -f "${library_db_backup_file_master}" ]
    then
        if  [ "${use_ramdisk}" = "YES" ]
        then
            echo "setting ram disk as path for working copy of ${lib_file}"
            library_db_file_local="${ram_disk_db_path}/${lib_file}"

            echo "copying ${library_db_backup_file_master} to ${library_db_file_local}"
            cp --remove-destination "${library_db_backup_file_master}"  "${library_db_file_local}"

            echo "linking ${library_db_file_local} to ${library_db_path_local}/${lib_file}"
            ln --force -s "${library_db_file_local}" "${library_db_path_local}/${lib_file}"
            
            # set plex user symlink as owner
            chown -h ${PLEX_UID}:${PLEX_GID} "${library_db_path_local}/${lib_file}"
        else
            echo "setting default library path for working copy of ${lib_file}"
            library_db_file_local="${library_db_path_local}/${lib_file}"
            # if a seperate master library has been specified, of file is a symbolic link load library from the latest backup
            if [ "${library_db_backup_path_master}" != "${library_db_backup_path_local}" ] && [ -L "${library_db_file_local}" ]; then
                if [ -f "${library_db_file_local}" ]
                then
                    library_db_file_backup=$(getNewBackupFilePath "${lib_file}")
                    echo "making backup of existing ${library_db_file_local} to ${library_db_file_backup}"
                    cp --remove-destination "${library_db_file_local}"  "${library_db_file_backup}"
                fi

                echo "copying ${library_db_backup_file_master} to ${library_db_file_local}"
                cp --remove-destination "${library_db_backup_file_master}"  "${library_db_file_local}"
            fi
        fi

        # set plex user symlink as owner
        chown -h ${PLEX_UID}:${PLEX_GID} "${library_db_file_local}"

        # if [ "${lib_file}" = "com.plexapp.plugins.library.db" ]
        # then
        #     syncPlexDB "${library_db_backup_file_local}" "${library_db_file_local}" --tmp-folder "${ram_disk_path}/plex-db-sync"
        # fi
    else
        if  [ "${use_ramdisk}" = "YES" ]
        then
            echo "error: master copy of library file not found: copying ${library_db_backup_file_local} to ram disk path ${ram_disk_db_path}"
            cp "${library_db_backup_file_local}" "${ram_disk_db_path}"
        fi
    fi
done

echo 
echo "finished copy and sync of plex master library to local working library path"
echo 