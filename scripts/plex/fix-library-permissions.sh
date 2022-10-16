#!/usr/bin/with-contenv bash
. /scripts/plex/variables

# fix database ownership
chown -R ${PLEX_UID}:${PLEX_GID} "${library_db_path_local}"
