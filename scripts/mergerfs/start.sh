#!/bin/sh

# [ -z $MFS_USER_OPTS ] && MFS_USER_OPTS="async_read=false,use_ino,allow_other,func.getattr=newest,category.action=all,category.create=ff,cache.files=partial,dropcacheonclose=true"
[ -z $MFS_USER_OPTS ] && MFS_USER_OPTS=allow_other,auto_cache,auto_unmount,direct_io,sync_read,uid=${USERID},gid=${GROUPID}
[ -z $MFS_BRANCHES ] && MFS_BRANCHES=/mnt/plexdrive/secure_media/=RO:/mnt/rclone/secure_media=RO:/mnt/rclone/secure_media2=RO:/mnt/rclone/secure_media3=RO
[ -z $MFS_DEST ] && MFS_DEST=/data/media

mfs_user_opts=$MFS_USER_OPTS
mfs_branches=$MFS_BRANCHES
mfs_dest=$MFS_DEST
mfs_basic_opts="uid=${PUID:-911},gid=${PGID:-911},umask=022,allow_other"

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
fusermount -uz "${mfs_dest}"
# start mergerfs mount

mount_command="mergerfs -f ${mfs_branches} ${mfs_dest} -o ${mfs_basic_opts} -o ${mfs_user_opts}"
echo "*** pooling => $mount_command"
exec $mount_command
#mergerfs -f ${mfs_branches} ${mfs_dest} -o ${mfs_basic_opts} -o ${mfs_user_opts}
echo "** mount stopped ***"
sleep 5000
