#!/bin/bash


echo
echo "$(date) - Plex custom startup scripts started"
echo

# Link image and database folders to plex scanner, the location that the master copies are either maintained by another plex instance or downloaded to from cloud 
bash /scripts/plex/link-library-folders.sh

# Check for library corruption, if found restore from last backup
bash /scripts/plex/restore-library-backup.sh

# Ensure library files synced from cloud are accesible by plex
bash /scripts/plex/fix-library-permissions.sh

# Optimise plex database and load to memory
# bash /scripts/plex/cache_plex_library.sh


echo
echo "$(date) - Plex custom startup scripts finished"
echo
