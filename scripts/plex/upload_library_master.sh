#!/bin/bash
echo
echo "$(date) - Plex master library upload to cloud started"
echo

# Stop plex while library downloads
CONTAINER_PLEX_STREAMER=$(docker container ls --format {{.Names}} | grep plex_streamer)
CONTAINER_PLEX_SCANNER=$(docker container ls --format {{.Names}} | grep plex_scanner)

echo "stopping plex instance(s) for plex library upload"
[ -z  "$CONTAINER_PLEX_STREAMER" ] && echo "couldn't find plex streamer container, unable to stop" || docker stop "$CONTAINER_PLEX_STREAMER"
[ -z  "$CONTAINER_PLEX_SCANNER" ] && echo "couldn't find plex scanner container, unable to stop" || docker stop "$CONTAINER_PLEX_SCANNER"

echo "starting plex library upload"
CONTAINER_PLEX_LIBRARY_SYNC=$(docker container ls --all --format {{.Names}} | grep rclone_library_sync)
docker start "$CONTAINER_PLEX_LIBRARY_SYNC"

sleep 3
while [[ $(docker ps | grep $CONTAINER_PLEX_LIBRARY_SYNC) ]]
do
echo "$(date) - waiting for library download using $CONTAINER_PLEX_LIBRARY_SYNC to complete"
echo "------------------------- progress ------------------------------"
docker logs --tail 5 "$CONTAINER_PLEX_LIBRARY_SYNC"
echo "-----------------------------------------------------------------"
sleep 20
done

echo "$(date) - library download using $CONTAINER_PLEX_LIBRARY_SYNC has completed. Restarting Plex"
docker start "$CONTAINER_PLEX_STREAMER"
docker start "$CONTAINER_PLEX_SCANNER"

echo
echo "$(date) - Plex master library upload to cloud finished"
echo