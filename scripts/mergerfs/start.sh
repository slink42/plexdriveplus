#!/bin/bash

[ -z $MFS_USER_OPTS ] && MFS_USER_OPTS="async_read=false,use_ino,allow_other,func.getattr=newest,category.action=all,category.create=ff,cache.files=partial,dropcacheonclose=true"
[ -z $SOURCE_PATHS ] && SOURCE_PATHS="/mnt/plexdrive/secure_media/=RO:/mnt/rclone/secure_media=RO:/mnt/rclone/secure_media2=RO:/mnt/rclone/secure_media3=RO"
[ -z $DEST_PATH ] && DEST_PATH="/data/media"

#  - -o
#             - allow_other # allow access to other users
#             - -o
#             - auto_cache # enable caching based on modification times
#             - -o
#             - auto_unmount # auto unmount on process termination
#             - -o
#             - direct_io # use direct I/O
#             - -o
#             - gid=${GROUPID} # set file group
#             - -o
#             - sync_read # perform reads synchronously
#             - -o
#             - uid=${USERID} # set file owner
#             - /mnt/plexdrive/secure_media/=RO:/mnt/rclone/secure_media=RO:/mnt/rclone/secure_media2=RO:/mnt/rclone/secure_media3=RO # source paths
#             - /data/media # mergerfs mounts

# make sure old path is unmounted
echo "unmounting destination path with command: fusermount -uz $DEST_PATH"
fusermount -uz "$DEST_PATH"
# start mergerfs mount
echo "starting mergerfs mount with command: mergerfs -f -o $MFS_USER_OPTS $SOURCE_PATHS $DEST_PATH"
mergerfs -f -o "$MFS_USER_OPTS" "$SOURCE_PATHS" "$DEST_PATH"