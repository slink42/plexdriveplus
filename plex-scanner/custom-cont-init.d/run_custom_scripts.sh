#!/bin/bash

echo
echo "$(date) - Plex custom startup scripts started"
echo

# Check for library corruption, if found restore from last backup
bash /scripts/plex/restore-library-backup.sh

# Ensure library files synced from cloud are accesible by plex
bash /scripts/plex/fix-library-permissions.sh

echo
echo "$(date) - Plex custom startup scripts finished"
echo
