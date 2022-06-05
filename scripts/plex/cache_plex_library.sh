#!/bin/bash
# optimizes the databases, trims SSD, clears memory and caches into vmem.

PLEX_DATABASE="/config/Library/Application Support/Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.db"
PLEX_DATABASE_BLOBS="/config/Library/Application Support/Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.blobs.db"
#PLEX_DATABASE_TRAKT="/config/Library/Application Support/Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.trakttv.db"

TMP_PLEX_DATABASE="/tmp/com.plexapp.plugins.library.db"
TMP_PLEX_DATABASE_BLOBS="/tmp/com.plexapp.plugins.library.blobs.db"
#TMP_PLEX_DATABASE_TRAKT="/tmp/com.plexapp.plugins.trakttv.db"

BACKUPDIR="/config/backups/maintenance"

SQLITE3="/usr/bin/sqlite3"
SQLDUMP="/tmp/dump.sql"

NO_FORMAT="\033[0m"
C_ORANGE1="\033[38;5;214m"
C_SPRINGGREEN3="\033[38;5;41m"
C_RED1="\033[38;5;196m"
C_YELLOW1="\033[38;5;226m"
C_DODGERBLUE1="\033[38;5;33m"
C_PURPLE="\033[38;5;129m"

if [[ -z $OPTIMISE_LIBRARY ]]; then
    echo -e "${C_ORANGE1}Maintenance Skipped - Set OPTIMISE_LIBRARY ENV VAR with any value to run libary maintnence on container start${NO_FORMAT}!"
    exit
fi

[[ $($SQLITE3 --version) ]] || (echo -e "${C_DODGERBLUE1}Installing sqlite3 for use in library maintenance${NO_FORMAT}!" && apt install sqlite3)

#######################################################################################################################################################

vmtouch /fake/path || (echo "installing vmtouch" && apt-get update -y && apt-get install -y vmtouch)

#######################################################################################################################################################

if [ "$OPTIMISE_LIBRARY" = "FULL" ]; then

    echo -e "${C_PURPLE}Starting Maintenance${NO_FORMAT}"

    #systemctl stop plexmediaserver &&

    rm $BACKUPDIR/*
    rm $SQLDUMP

    cp -f "$PLEX_DATABASE" "$BACKUPDIR/com.plexapp.plugins.library.db"
    cp -f "$PLEX_DATABASE_BLOBS" "$BACKUPDIR/com.plexapp.plugins.library.blobs.db"
    #cp -f "$PLEX_DATABASE_TRAKT" "$BACKUPDIR/com.plexapp.plugins.trakttv.db"

    cp -f "$PLEX_DATABASE" "$TMP_PLEX_DATABASE"
    cp -f "$PLEX_DATABASE_BLOBS" "$TMP_PLEX_DATABASE_BLOBS"
    #cp -f "$PLEX_DATABASE_TRAKT" "$TMP_PLEX_DATABASE_TRAKT"

    sleep 5

    $SQLITE3 "$TMP_PLEX_DATABASE" "PRAGMA optimize"
    $SQLITE3 "$TMP_PLEX_DATABASE" "DROP index 'index_title_sort_naturalsort'"
    $SQLITE3 "$TMP_PLEX_DATABASE" "DELETE from schema_migrations where version='20180501000000'"
    $SQLITE3 "$TMP_PLEX_DATABASE" vacuum
    $SQLITE3 "$TMP_PLEX_DATABASE" .dump > "$SQLDUMP"
    rm "$TMP_PLEX_DATABASE"
    $SQLITE3 "$TMP_PLEX_DATABASE" < "$SQLDUMP"
    $SQLITE3 -header -line "$TMP_PLEX_DATABASE" "PRAGMA default_cache_size = 1000000"
    $SQLITE3 "$TMP_PLEX_DATABASE" "PRAGMA optimize"
    $SQLITE3 "$TMP_PLEX_DATABASE" "PRAGMA integrity_check"
    rm "$SQLDUMP"

    $SQLITE3 "$TMP_PLEX_DATABASE_BLOBS" "PRAGMA optimize"
    $SQLITE3 "$TMP_PLEX_DATABASE_BLOBS" vacuum
    $SQLITE3 "$TMP_PLEX_DATABASE_BLOBS" .dump > "$SQLDUMP"
    rm "$TMP_PLEX_DATABASE_BLOBS"
    $SQLITE3 "$TMP_PLEX_DATABASE_BLOBS" < "$SQLDUMP"
    $SQLITE3 "$TMP_PLEX_DATABASE_BLOBS" "PRAGMA optimize"
    $SQLITE3 "$TMP_PLEX_DATABASE" "PRAGMA integrity_check"
    rm "$SQLDUMP"

    #$SQLITE3 "$TMP_PLEX_DATABASE_TRAKT" "PRAGMA optimize"
    #$SQLITE3 "$TMP_PLEX_DATABASE_TRAKT" vacuum
    #$SQLITE3 "$TMP_PLEX_DATABASE_TRAKT" .dump > "$SQLDUMP"
    #rm "$TMP_PLEX_DATABASE_TRAKT"
    #$SQLITE3 "$TMP_PLEX_DATABASE_TRAKT" < "$SQLDUMP"
    #$SQLITE3 "$TMP_PLEX_DATABASE_TRAKT" "PRAGMA optimize"
    #$SQLITE3 "$TMP_PLEX_DATABASE" "PRAGMA integrity_check"
    #rm "$SQLDUMP"

    sleep 5

    cp -f "$TMP_PLEX_DATABASE" "$PLEX_DATABASE"
    cp -f "$TMP_PLEX_DATABASE_BLOBS" "$PLEX_DATABASE_BLOBS"
    #cp -f "$TMP_PLEX_DATABASE_TRAKT" "$PLEX_DATABASE_TRAKT"
    chown -R plex:plex "/config/Library/Application Support/Plex Media Server/Plug-in Support/Databases/"

    rm -f "$TMP_PLEX_DATABASE"
    rm -f "$TMP_PLEX_DATABASE_BLOBS"
    #rm -f "$TMP_PLEX_DATABASE_TRAKT"

    rm -rf "/config/Library/Application Support/Plex Media Server/Codecs/"*

    #fstrim -av
fi

echo "Setting Vmotuch to retain plex db in memory"

VMTOUCH_PID=$(pgrep -f "vmtouch -dfhl")
for PID in $VMTOUCH_PID; do
    /usr/bin/kill -9 $PID
done

#echo 1 > /proc/sys/vm/drop_caches && swapoff -a && swapon -a

vmtouch -dfhl "/config/Library/Application Support/Plex Media Server/Cache/PhotoTranscoder/"
vmtouch -dfhl "/config/Library/Application Support/Plex Media Server/Media/localhost/"
vmtouch -dfhl "$PLEX_DATABASE"
vmtouch -dfhl "$PLEX_DATABASE_BLOBS"
#/usr/local/bin/vmtouch -dfhl "/mnt/.cache/rclone/google-cache.db"


#systemctl start plexmediaserver &&
#sleep 15
#systemctl restart plexmediaserver &&

##update to target rclone docker containers ##
#/usr/bin/rclone rc vfs/refresh recursive=true --rc-addr 127.0.0.1:5575

echo -e "${C_PURPLE}Maintenance Finished${NO_FORMAT}!"

exit