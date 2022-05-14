

#!/bin/bash

# fix database ownership
chown -R ${PLEX_UID}:${PLEX_GID} /config/Library/Application\ Support/Plex\ Media\ Server/Plug-in\ Support/Databases/ 
