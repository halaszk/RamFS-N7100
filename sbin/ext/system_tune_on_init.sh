#!/sbin/busybox sh

# stop ROM VM from booting!
stop;

# set busybox location
BB=/sbin/busybox

$BB chmod -R 777 /tmp/;
$BB chmod 6755 /sbin/ext/*;

mount -o remount,rw,nosuid,nodev /cache;
mount -o remount,rw,nosuid,nodev /data;
mount -o remount,rw /;

# remount all partitions tweked settings
for m in $(mount | grep ext[3-4] | cut -d " " -f1); do
	mount -o remount,rw,noatime,nodiratime,noauto_da_alloc,discard,barrier=1,commit=10 $m;
done;
# cleaning
$BB rm -rf /cache/lost+found/* 2> /dev/null;
$BB rm -rf /data/lost+found/* 2> /dev/null;
$BB rm -rf /data/tombstones/* 2> /dev/null;
$BB rm -rf /data/anr/* 2> /dev/null;
$BB chmod 400 /data/tombstones -R;
$BB chown drm:drm /data/tombstones -R;

# critical Permissions fix
$BB chmod 0777 /dev/cpuctl/ -R;
$BB chmod 0766 /data/anr/ -R;
$BB chmod 0777 /data/system/inputmethod/ -R;
$BB chmod 0777 /sys/devices/system/cpu/ -R;
$BB chown root:system /sys/devices/system/cpu/ -R;
$BB chmod 0777 /data/anr -R;
$BB chown system:system /data/anr -R;

# Start ROM VM boot!
sync;
start;

