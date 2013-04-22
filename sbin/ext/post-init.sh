#!/sbin/busybox sh
# Logging
#/sbin/busybox cp /data/user.log /data/user.log.bak
#/sbin/busybox rm /data/user.log
#exec >>/data/user.log
#exec 2>&1

BB="/sbin/busybox";

# first mod the partitions then boot
#$BB sh /sbin/ext/system_tune_on_init.sh;

# oom and mem perm fix, we have auto adj code, do not allow changes in adj
$BB chmod 777 /sys/module/lowmemorykiller/parameters/cost;
$BB chmod 444 /sys/module/lowmemorykiller/parameters/adj;
$BB chmod 777 /proc/sys/vm/mmap_min_addr;

# set default JB mmap_min_addr value
echo "32768" > /proc/sys/vm/mmap_min_addr;

# protect init from oom
echo "-1000" > /proc/1/oom_score_adj; # -1000 = -17

PIDOFINIT=`pgrep -f "/sbin/ext/post-init.sh"`;
for i in $PIDOFINIT; do
echo "-600" > /proc/$i/oom_score_adj;
done;

if [ ! -d /data/.siyah ]; then
$BB mkdir -p /data/.siyah;
fi;

# reset config-backup-restore
if [ -f /data/.siyah/restore_running ]; then
rm -f /data/.siyah/restore_running;
fi;

# for dev testing
PROFILES=`$BB ls -A1 /data/.siyah/*.profile`;
for p in $PROFILES; do
cp $p $p.test;
done;

CONFIG_XML=/res/customconfig/customconfig.xml;
if [ ! -f $CONFIG_XML ]; then
mount -o remount,rw /;
  . /res/customconfig/customconfig.xml.generate > $CONFIG_XML;
fi;


. /res/customconfig/customconfig-helper

[ ! -f /data/.siyah/default.profile ] && cp /res/customconfig/default.profile /data/.siyah;

$BB chmod 0777 /data/.siyah/ -R;

read_defaults;
read_config;

# Cortex parent should be ROOT/INIT and not STweaks
nohup /sbin/ext/cortexbrain-tune.sh; 

#nohup /sbin/ext/multitaskfix.sh; 

if [ "$logger" == "on" ];then
insmod /lib/modules/logger.ko
fi

# disable debugging on some modules
if [ "$logger" == "off" ];then
  rm -rf /dev/log
  echo 0 > /sys/module/ump/parameters/ump_debug_level;
  echo 0 > /sys/module/mali/parameters/mali_debug_level;
  echo 0 > /sys/module/kernel/parameters/initcall_debug;
  echo 0 > /sys//module/lowmemorykiller/parameters/debug_level;
  echo 0 > /sys/module/earlysuspend/parameters/debug_mask;
  echo 0 > /sys/module/alarm/parameters/debug_mask;
  echo 0 > /sys/module/alarm_dev/parameters/debug_mask;
  echo 0 > /sys/module/binder/parameters/debug_mask;
  echo 0 > /sys/module/xt_qtaguid/parameters/debug_mask;
fi

if [ "$gesture_tweak" == "on" ]; then
echo "1" > /sys/devices/virtual/misc/touch_gestures/gestures_enabled;
pkill -f "/data/gesture_set.sh";
pkill -f "/sys/devices/virtual/misc/touch_gestures/wait_for_gesture";
nohup $BB sh /data/gesture_set.sh;
fi;
if [ "$exfat" == "on" ]; then
insmod /lib/modules/exfat_core.ko;
insmod /lib/modules/exfat_fs.ko;
fi;

######################################
# Loading Modules
######################################
$BB chmod -R 755 /lib;

(
	sleep 40;
	# order of modules load is important.
	$BB insmod /lib/modules/scsi_wait_scan.ko;
	$BB insmod /lib/modules/j4fs.ko;

	sleep 10;
	$BB insmod /lib/modules/auth_rpcgss.ko;
	$BB insmod /lib/modules/sunrpc.ko;
	$BB insmod /lib/modules/mvpkm.ko;
	$BB insmod /lib/modules/lockd.ko;
	$BB insmod /lib/modules/pvtcpkm.ko;
)&

if [ "$logger" == "off" ];then
rmmod /lib/modules/logger.ko
fi
if [ "$exfat" == "off" ]; then
rmmod /lib/modules/exfat_core.ko;
rmmod /lib/modules/exfat_fs.ko;
fi;
# for ntfs automounting
insmod /lib/modules/fuse.ko;
mount -o remount,rw /
mkdir -p /mnt/ntfs
chmod 777 /mnt/ntfs
mount -o mode=0777,gid=1000 -t tmpfs tmpfs /mnt/ntfs
mount -o remount,ro /

(
	$BB sh /sbin/ext/install.sh
)&

(
##### Early-init phase tweaks #####
	$BB sh /sbin/ext/tweaks.sh
)&

(
	$BB sh /sbin/ext/killing_samsung_apps.sh &
)&

#(
#        $BB sh /sbin/ext/smoothlauncher.sh &
#)&


# give home launcher, oom protection
	ACORE_APPS=`pgrep acore`;
	if [ "a$ACORE_APPS" != "a" ]; then
		for c in `pgrep acore`; do
			echo "-900" > /proc/${c}/oom_score_adj;
		done;
	fi;

# some nice thing for dev
$BB ln -s /sys/devices/system/cpu/cpu0/cpufreq /cpufreq;
$BB ln -s /sys/devices/system/cpu/cpufreq/ /cpugov;

$BB echo 1 > /sys/class/misc/wolfson_control/switch_master;

$BB echo 1 > /sys/class/misc/wolfson_control/switch_fll_tuning;
$BB echo 1 > /sys/class/misc/wolfson_control/switch_oversampling;
$BB echo 1 > /sys/class/misc/wolfson_control/switch_dac_direct;

$BB echo 2 > /sys/class/misc/wolfson_control/eq_sp_gain_1;
$BB echo 4 > /sys/class/misc/wolfson_control/eq_sp_gain_2;
$BB echo -12 > /sys/class/misc/wolfson_control/eq_sp_gain_3;
$BB echo -8 > /sys/class/misc/wolfson_control/eq_sp_gain_4;
$BB echo 4 > /sys/class/misc/wolfson_control/eq_sp_gain_5;

$BB echo 3 > /sys/class/misc/wolfson_control/switch_eq_headphone;
$BB echo 1 > /sys/class/misc/wolfson_control/switch_eq_speaker;

# enable kmem interface for everyone by GM
echo "0" > /proc/sys/kernel/kptr_restrict;

(
	echo 0 > /tmp/uci_done;
	chmod 666 /tmp/uci_done;
	# custom boot booster
	while [ "`cat /tmp/uci_done`" != "1" ]; do
		echo "1400000" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq;
		echo "1400000" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq;
		pkill -f "com.gokhanmoral.stweaks.app";
		echo "Waiting For UCI to finish";
		sleep 20;
	done;

	# restore normal freq.
	echo "$scaling_min_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq;
	echo "$scaling_max_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq;
)&

# Stop uci.sh from running all the PUSH Buttons in stweaks on boot.
$BB mount -o remount,rw rootfs;
$BB chown root:system /res/customconfig/actions/ -R;
$BB chmod 6755 /res/customconfig/actions/*;
$BB chmod 6755 /res/customconfig/actions/push-actions/*;
$BB mv /res/customconfig/actions/push-actions/* /res/no-push-on-boot/;

# set root access script.
$BB chmod 6755 /sbin/ext/cortexbrain-tune.sh;

# some initialization code
ccxmlsum=`md5sum $CONFIG_XML | awk '{print $1}'`
if [ "a${ccxmlsum}" != "a`cat /data/.siyah/.ccxmlsum`" ];
then
#  rm -f /data/.siyah/*.profile
  echo ${ccxmlsum} > /data/.siyah/.ccxmlsum;
fi

# apply STweaks settings
echo "booting" > /data/.siyah/booting;
pkill -f "com.gokhanmoral.stweaks.app";
# apply STweaks defaults
export CONFIG_BOOTING=1
nohup $BB sh /res/uci.sh restore;
export CONFIG_BOOTING=
echo "1" > /tmp/uci_done;

# restore all the PUSH Button Actions back to there location
$BB mount -o remount,rw rootfs;
$BB mv /res/no-push-on-boot/* /res/customconfig/actions/push-actions/;
pkill -f "com.gokhanmoral.stweaks.app";
$BB rm -f /data/.siyah/booting;

# update cpu tunig after profiles load
$BB sh /sbin/ext/cortexbrain-tune.sh apply_cpu update > /dev/null;
# ==============================================================
# STWEAKS FIXING
# ==============================================================
# change USB mode MTP or Mass Storage
$BB sh /res/uci.sh usb-mode ${usb_mode};

$BB mount -t rootfs -o remount,rw rootfs;

##### EFS Backup #####
#(
#	$BB sh /sbin/ext/efs-backup.sh;
#) &


PIDOFACORE=`pgrep -f "android.process.acore"`;
for i in $PIDOFACORE; do
echo "-800" > /proc/${i}/oom_score_adj;
renice -15 -p $i;
log -p 10 i -t boot "*** do not kill -> android.process.acore ***";
done;

	# ###############################################################
	# I/O related tweaks
	# ###############################################################

	DM=`ls -d /sys/block/dm*`;
	for i in ${DM}; do
		if [ -e $i/queue/rotational ]; then
			echo "0" > ${i}/queue/rotational;
		fi;

		if [ -e $i/queue/iostats ]; then
			echo "0" > ${i}/queue/iostats;
		fi;
	done;

mount -o remount,rw /system;
mount -o remount,rw /;

if [ $cortexbrain_lmkiller == on ]; then
# correct oom tuning, if changed by apps/rom
$BB sh /res/uci.sh oom_config_screen_on $oom_config_screen_on;
$BB sh /res/uci.sh oom_config_screen_off $oom_config_screen_off;
fi;
##### init scripts #####

if [ $init_d == on ]; then
$BB sh /sbin/ext/run-init-scripts.sh;
fi;

