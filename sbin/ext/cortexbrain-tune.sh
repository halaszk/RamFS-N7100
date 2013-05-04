#!/sbin/busybox sh

#Credits:
# Zacharias.maladroit
# Voku1987
# Collin_ph@xda
# Dorimanx@xda
# Gokhanmoral@xda
# Johnbeetee
# halaszk

# TAKE NOTE THAT LINES PRECEDED BY A "#" IS COMMENTED OUT.
# This script must be activated after init start =< 25sec or parameters from /sys/* will not be loaded.

# read setting from profile

# Get values from profile. since we dont have the recovery source code i cant change the .siyah dir, so just leave it there for history.
PROFILE=`cat /data/.siyah/.active.profile`;
. /data/.siyah/$PROFILE.profile;

FILE_NAME=$0;
PIDOFCORTEX=$$;
IWCONFIG=/sbin/iwconfig;
INTERFACE=wlan0;
AWAKE_LAPTOP_MODE="0";
SLEEP_LAPTOP_MODE="0";
BB=/sbin/busybox;
PROP=/system/bin/setprop;
sqlite=/sbin/sqlite3;
wifi_idle_wait=10000;
# set initial vm.dirty vales
echo "2000" > /proc/sys/vm/dirty_writeback_centisecs;
echo "1000" > /proc/sys/vm/dirty_expire_centisecs;
# init functions.
sleeprun=1;
wifi_helper_awake=1;
TELE_DATA=`dumpsys telephony.registry`;
mobile_helper_awake=1;
echo 1 > /tmp/wifi_helper;
echo 1 > /tmp/mobile_helper;
chmod 777 -R /tmp/
# check if dumpsys exist in ROM
if [ -e /system/bin/dumpsys ]; then
	DUMPSYS=1;
else
	DUMPSYS=0;
fi;

# replace kernel version info for repacked kernels
cat /proc/version | grep infra && (kmemhelper -t string -n linux_proc_banner -o 15 `cat /res/version`);

# ==============================================================
# I/O-TWEAKS 
# ==============================================================
IO_TWEAKS()
{
	if [ "$cortexbrain_io" == on ]; then

		ZRM=`ls -d /sys/block/zram*`;
		for z in $ZRM; do
	
			if [ -e $z/queue/rotational ]; then
				echo "0" > $z/queue/rotational;
			fi;

			if [ -e $z/queue/iostats ]; then
				echo "0" > $z/queue/iostats;
			fi;

			if [ -e $z/queue/rq_affinity ]; then
				echo "1" > $z/queue/rq_affinity;
			fi;

		done;

		MMC=`ls -d /sys/block/mmc*`;
for i in $MMC; do
			if [ -e $i/queue/scheduler ]; then
				echo $scheduler > $i/queue/scheduler;
			fi;

			if [ -e $i/queue/rotational ]; then
				echo "0" > $i/queue/rotational;
			fi;

			if [ -e $i/queue/iostats ]; then
				echo "0" > $i/queue/iostats;
			fi;

			if [ -e $i/queue/read_ahead_kb ]; then
				echo "$cortexbrain_read_ahead_kb" >  $i/queue/read_ahead_kb; # default: 128
			fi;

			     	if [ -e $i/queue/nr_requests ]; then
                                        echo "3072" > $i/queue/nr_requests; # default: 128
                                fi;


			if [ "$scheduler" == "sio" ] || [ "$scheduler" == "zen" ]; then
				if [ -e $i/queue/nr_requests ]; then
					echo "64" > $i/queue/nr_requests; # default: 128
				fi;
			fi;

			if [ -e $i/queue/iosched/back_seek_penalty ]; then
				echo "1" > $i/queue/iosched/back_seek_penalty; # default: 2
			fi;

			if [ -e $i/queue/iosched/slice_idle ]; then
				echo "2" > $i/queue/iosched/slice_idle; # default: 8
			fi;

			if [ -e $i/queue/iosched/fifo_batch ]; then
				echo "1" > $i/queue/iosched/fifo_batch;
			fi;
		done;

		if [ -e /sys/devices/virtual/bdi/default/read_ahead_kb ]; then
			echo "$cortexbrain_read_ahead_kb" > /sys/devices/virtual/bdi/default/read_ahead_kb;
		fi;

		local SDCARDREADAHEAD=`ls -d /sys/devices/virtual/bdi/179*`;
		for i in $SDCARDREADAHEAD; do
			echo "$cortexbrain_read_ahead_kb" > $i/read_ahead_kb;
		done;

		for i in /sys/block/*/queue/add_random; do 
		echo "0" > $i;
		done;
		echo "0" > /proc/sys/kernel/randomize_va_space;


		echo "45" > /proc/sys/fs/lease-break-time;
		echo "0" > /proc/sys/fs/leases-enable;
		
		#echo NO_NORMALIZED_SLEEPER > /sys/kernel/debug/sched_features;
		#echo NO_NEW_FAIR_SLEEPERS > /sys/kernel/debug/sched_features;
		#echo NO_START_DEBIT > /sys/kernel/debug/sched_features;
		#echo NO_WAKEUP_PREEMPT > /sys/kernel/debug/sched_features;
		#echo NEXT_BUDDY > /sys/kernel/debug/sched_features;
		#echo SYNC_WAKEUPS > /sys/kernel/debug/sched_features;

		log -p i -t $FILE_NAME "*** IO_TWEAKS ***: enabled";
		return 0;
	else
		return 1;
	fi;
}
IO_TWEAKS;

KERNEL_TWEAKS()
{
	local state="$1";

	if [ "$cortexbrain_kernel_tweaks" == on ]; then
		if [ "${state}" == "awake" ]; then
			echo "1" > /proc/sys/vm/oom_kill_allocating_task;
			echo "0" > /proc/sys/vm/panic_on_oom;
			echo "0" > /proc/sys/kernel/panic_on_oops;
			echo "0" > /proc/sys/kernel/panic;
                        echo "64" > /proc/sys/kernel/random/read_wakeup_threshold;
                        echo "128" > /proc/sys/kernel/random/write_wakeup_threshold;
			if [ "$cortexbrain_memory" == on ]; then
				echo "32 32" > /proc/sys/vm/lowmem_reserve_ratio;
			fi;
		elif [ "${state}" == "sleep" ]; then
			echo "0" > /proc/sys/vm/oom_kill_allocating_task;
			echo "0" > /proc/sys/vm/panic_on_oom;
			echo "0" > /proc/sys/kernel/panic_on_oops;
			echo "0" > /proc/sys/kernel/panic;
                        echo "64" > /proc/sys/kernel/random/read_wakeup_threshold;
                        echo "128" > /proc/sys/kernel/random/write_wakeup_threshold;
			if [ "$cortexbrain_memory" == on ]; then
				echo "64 64" > /proc/sys/vm/lowmem_reserve_ratio;
			fi;
		else
			echo "1" > /proc/sys/vm/oom_kill_allocating_task;
			echo "0" > /proc/sys/vm/panic_on_oom;
			echo "0" > /proc/sys/kernel/panic_on_oops;
			echo "0" > /proc/sys/kernel/panic;
			echo "64" > /proc/sys/kernel/random/read_wakeup_threshold;
			echo "128" > /proc/sys/kernel/random/write_wakeup_threshold;
		fi;
	
		log -p i -t $FILE_NAME "*** KERNEL_TWEAKS ***: ${state} ***: enabled";
		return 0;
	else
		return 1;
	fi;
}
KERNEL_TWEAKS;
# ==============================================================
# SYSTEM-TWEAKS
# ==============================================================
SYSTEM_TWEAKS()
{
	if [ "$cortexbrain_system" == on ]; then
	# enable Hardware Rendering
	$PROP video.accelerate.hw 1;
	$PROP debug.performance.tuning 1;
	$PROP debug.sf.hw 1;
	$PROP persist.sys.use_dithering 1;
#	$PROP persist.sys.ui.hw true; # ->reported as problem maker in some roms.

	# render UI with GPU
	$PROP hwui.render_dirty_regions false;
	$PROP windowsmgr.max_events_per_sec 240;
	$PROP profiler.force_disable_err_rpt 1;
	$PROP profiler.force_disable_ulog 1;

	# Dialing Tweaks
	$PROP ro.telephony.call_ring.delay=0;
	$PROP ro.lge.proximity.delay=25;
	$PROP mot.proximity.delay=25;

	# more Tweaks
	$PROP dalvik.vm.execution-mode int:jit;
	$PROP persist.adb.notify 0;
	$PROP pm.sleep_mode 1;



		log -p i -t $FILE_NAME "*** SYSTEM_TWEAKS ***: enabled";
		return 0;
	else
		return 1;
	fi;
}
SYSTEM_TWEAKS;

# ==============================================================
# ECO-TWEAKS
# ==============================================================
ECO_TWEAKS()
{
	if [ "$cortexbrain_eco" == on ]; then
		local LEVEL=$(cat /sys/class/power_supply/battery/capacity);
		if [ "$LEVEL" == "$cortexbrain_eco_level" ] || [ "$LEVEL" -lt "$cortexbrain_eco_level" ]; then
			CPU_GOV_TWEAKS "sleep";
			TWEAK_HOTPLUG_ECO "sleep";
		fi;

		log -p i -t $FILE_NAME "*** ECO_TWEAKS ***: enabled";

		return 0;
	else
		return 1;
	fi;
}

# ==============================================================
# BATTERY-TWEAKS
# ==============================================================
BATTERY_TWEAKS()
{
	if [ "$cortexbrain_battery" == on ]; then
	  $BB mount -t debugfs none /sys/kernel/debug;
	  $BB umount /sys/kernel/debug;
	  # vm tweaks
	  echo "$dirty_background_ratio" > /proc/sys/vm/dirty_background_ratio; # default: 10
          echo "$dirty_ratio" > /proc/sys/vm/dirty_ratio; # default: 20

# LCD Power-Reduce
		if [ -e /sys/class/lcd/panel/power_reduce ]; then
			if [ "$power_reduce" == on ]; then
				echo "1" > /sys/class/lcd/panel/power_reduce;
			else
				echo "0" > /sys/class/lcd/panel/power_reduce;
			fi;
		fi;

		# USB power support
		local POWER_LEVEL=`ls /sys/bus/usb/devices/*/power/level`;
		for i in $POWER_LEVEL; do
			chmod 777 $i;
			echo "auto" > $i;
		done;

		local POWER_AUTOSUSPEND=`ls /sys/bus/usb/devices/*/power/autosuspend`;
		for i in $POWER_AUTOSUSPEND; do
			chmod 777 $i;
			echo "1" > $i;
		done;

		# BUS power support
		buslist="spi i2c sdio";
		for bus in $buslist; do
			local POWER_CONTROL=`ls /sys/bus/$bus/devices/*/power/control`;
			for i in $POWER_CONTROL; do
				chmod 777 $i;
				echo "auto" > $i;
			done;
		done;

		log -p i -t $FILE_NAME "*** BATTERY_TWEAKS ***: enabled";
		return 0;
	else
		return 1;
	fi;
}
if [ "$cortexbrain_background_process" == 0 ]; then
	BATTERY_TWEAKS;
fi;

# ==============================================================
# CPU-TWEAKS
# ==============================================================

CPU_GOV_TWEAKS()
{
	local state="$1";
	if [ "$cortexbrain_cpu" == on ]; then
	SYSTEM_GOVERNOR=`cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor`;
        
		# power_performance
	if [ "${state}" == "performance" ]; then

	echo "20000" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/sampling_rate;
	echo "10" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_up_rate;
	echo "10" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_down_rate;
	echo "40" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold;
	echo "20" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold_at_min_freq;
	echo "100" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_step;
	echo "800000" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_for_responsiveness;

		# sleep-settings
	elif [ "${state}" == "sleep" ]; then

	echo "$freq_for_responsiveness_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_for_responsiveness;
    echo "$freq_for_fast_down_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_for_fast_down;
    echo "$sampling_rate_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/sampling_rate;
	echo "$sampling_down_factor_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/sampling_down_factor;
	echo "$up_threshold_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold;
	echo "$down_differential_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/down_differential;
	echo "$up_threshold_at_min_freq_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold_at_min_freq;
	echo "$up_threshold_at_fast_down_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold_at_fast_down;
	echo "$freq_step_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_step;
	echo "$up_threshold_diff_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold_diff;
	echo "$freq_step_dec_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_step_dec;
	echo "$cpu_up_rate_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_up_rate;
	echo "$cpu_down_rate_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_down_rate;
	echo "$up_nr_cpus_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_nr_cpus;
	echo "$hotplug_freq_1_1_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_freq_1_1;
	echo "$hotplug_freq_2_0_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_freq_2_0;
	echo "$hotplug_freq_2_1_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_freq_2_1;
	echo "$hotplug_freq_3_0_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_freq_3_0;
	echo "$hotplug_freq_3_1_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_freq_3_1;
	echo "$hotplug_freq_4_0_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_freq_4_0;
	echo "$hotplug_rq_1_1_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_rq_1_1;
	echo "$hotplug_rq_2_0_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_rq_2_0;
	echo "$hotplug_rq_2_1_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_rq_2_1;
	echo "$hotplug_rq_3_0_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_rq_3_0;
	echo "$hotplug_rq_3_1_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_rq_3_1;
	echo "$hotplug_rq_4_0_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_rq_4_0;
	echo "$flexrate_enable_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/flexrate_enable;
	echo "$flexrate_max_freq_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/flexrate_max_freq;
	echo "$flexrate_forcerate_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/flexrate_forcerate;
	echo "$cpu_online_bias_count_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_online_bias_count;
	echo "$cpu_online_bias_up_threshold_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_online_bias_up_threshold;
	echo "$cpu_online_bias_down_threshold_sleep" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_online_bias_down_threshold;
	echo "$intelli_plug_active" > /sys/module/intelli_plug/parameters/intelli_plug_active;
	echo "$eco_mode_active" > /sys/module/intelli_plug/parameters/eco_mode_active;
	
		# awake-settings
	elif [ "${state}" == "awake" ]; then
	echo "$freq_for_responsiveness" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_for_responsiveness;
    echo "$freq_for_fast_down" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_for_fast_down;
    echo "$sampling_rate" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/sampling_rate;
	echo "$sampling_down_factor" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/sampling_down_factor;
	echo "$up_threshold" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold;
	echo "$down_differential" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/down_differential;
	echo "$up_threshold_at_min_freq" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold_at_min_freq;
	echo "$up_threshold_at_fast_down" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold_at_fast_down;
	echo "$freq_step" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_step;
	echo "$up_threshold_diff" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_threshold_diff;
	echo "$freq_step_dec" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/freq_step_dec;
	echo "$cpu_up_rate" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_up_rate;
	echo "$cpu_down_rate" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_down_rate;
	echo "$up_nr_cpus" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/up_nr_cpus;
	echo "$hotplug_freq_1_1" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_freq_1_1;
	echo "$hotplug_freq_2_0" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_freq_2_0;
	echo "$hotplug_freq_2_1" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_freq_2_1;
	echo "$hotplug_freq_3_0" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_freq_3_0;
	echo "$hotplug_freq_3_1" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_freq_3_1;
	echo "$hotplug_freq_4_0" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_freq_4_0;
	echo "$hotplug_rq_1_1" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_rq_1_1;
	echo "$hotplug_rq_2_0" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_rq_2_0;
	echo "$hotplug_rq_2_1" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_rq_2_1;
	echo "$hotplug_rq_3_0" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_rq_3_0;
	echo "$hotplug_rq_3_1" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_rq_3_1;
	echo "$hotplug_rq_4_0" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/hotplug_rq_4_0;
	echo "$flexrate_max_freq" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/flexrate_max_freq;
	echo "$flexrate_forcerate" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/flexrate_forcerate;
	echo "$boost" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/boost;
	echo "$cpu_online_bias_count" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_online_bias_count;
	echo "$cpu_online_bias_up_threshold" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_online_bias_up_threshold;
	echo "$cpu_online_bias_down_threshold" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/cpu_online_bias_down_threshold;
	echo "$max_cpu_lock" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/max_cpu_lock;
	echo "$lcdfreq" > /sys/devices/system/cpu/cpufreq/$SYSTEM_GOVERNOR/lcdfreq_enable;
	echo "$intelli_plug_active" > /sys/module/intelli_plug/parameters/intelli_plug_active;
	echo "$eco_mode_active" > /sys/module/intelli_plug/parameters/eco_mode_active;
	
	fi;

		log -p i -t $FILE_NAME "*** CPU_GOV_TWEAKS: ${state} ***: enabled";
	fi;
}
if [ "$cortexbrain_background_process" == 0 ]; then
	CPU_GOV_TWEAKS "awake";
fi;
# this needed for cpu tweaks apply from STweaks in real time.
apply_cpu=$2;
if [ "${apply_cpu}" == "update" ]; then
CPU_GOV_TWEAKS "awake";
fi;

# ==============================================================
# MEMORY-TWEAKS
# ==============================================================
MEMORY_TWEAKS()
{
	if [ "$cortexbrain_memory" == on ]; then
		echo "$dirty_background_ratio" > /proc/sys/vm/dirty_background_ratio; # default: 10
		echo "$dirty_ratio" > /proc/sys/vm/dirty_ratio; # default: 20
		echo "2" > /proc/sys/vm/min_free_order_shift; # default: 4
		echo "1" > /proc/sys/vm/overcommit_memory; # default: 0
		#echo "50" > /proc/sys/vm/overcommit_ratio; # default: 50
		echo "32 32" > /proc/sys/vm/lowmem_reserve_ratio;
		echo "3" > /proc/sys/vm/page-cluster; # default: 3
		echo "8192" > /proc/sys/vm/min_free_kbytes;

		log -p i -t $FILE_NAME "*** MEMORY_TWEAKS ***: enabled";
		return 0;
	else
		return 1;		
	fi;
}
MEMORY_TWEAKS;
# ==============================================================
# TCP-TWEAKS
# ==============================================================
TCP_TWEAKS()
{
	if [ "$cortexbrain_tcp" == on ]; then

	# Website Bypass
	$PROP net.rmnet0.dns1=8.8.8.8;
	$PROP net.rmnet0.dns2=8.8.4.4;
	$PROP net.dns1=8.8.8.8;
	$PROP net.dns2=8.8.4.4;

		# =========
	# 3G-2G and wifi network battery tweaks
	$PROP ro.ril.enable.a52 0;
	$PROP ro.ril.enable.a53 1;
	$PROP ro.ril.fast.dormancy.timeout 3;
	$PROP ro.ril.enable.sbm.feature 1;
	$PROP ro.ril.enable.sdr 0;
	$PROP ro.ril.qos.maxpdps 2;
	$PROP ro.ril.hsxpa 2;
	$PROP ro.ril.hsdpa.category 14;
	$PROP ro.ril.hsupa.category 7;
	$PROP ro.ril.hep 1;
	$PROP ro.ril.enable.dtm 0;
	$PROP ro.ril.enable.amr.wideband 1;
	$PROP ro.ril.gprsclass 12;
	$PROP ro.ril.avoid.pdp.overlap 1;
	$PROP ro.ril.enable.prl.recognition 0;
	$PROP ro.ril.def.agps.mode 2;
	$PROP ro.ril.enable.managed.roaming 1;
	$PROP ro.ril.enable.enhance.search 0;
#	$PROP ro.ril.fast.dormancy.rule 1;
	$PROP ro.ril.fd.scron.timeout 30;
	$PROP ro.ril.fd.scroff.timeout 10;
	$PROP ro.ril.emc.mode 2;
	$PROP ro.ril.att.feature 0;
	
	# Wireless Speed Tweaks
	$PROP net.tcp.buffersize.default=4096,87380,256960,4096,16384,256960;
	$PROP net.tcp.buffersize.wifi=4096,87380,256960,4096,16384,256960;
	$PROP net.tcp.buffersize.umts=4096,87380,256960,4096,16384,256960;
	$PROP net.tcp.buffersize.gprs=4096,87380,256960,4096,16384,256960;
	$PROP net.tcp.buffersize.edge=4096,87380,256960,4096,16384,256960;
	$PROP net.ipv4.tcp_ecn=0;
	$PROP net.ipv4.route.flush=1;
	$PROP net.ipv4.tcp_rfc1337=1;
	$PROP net.ipv4.ip_no_pmtu_disc=0;
	$PROP net.ipv4.tcp_sack=1;
	$PROP net.ipv4.tcp_fack=1;
	$PROP net.ipv4.tcp_window_scaling=1;
	$PROP net.ipv4.tcp_timestamps=1;
	$PROP net.ipv4.tcp_rmem=4096 39000 187000;
	$PROP net.ipv4.tcp_wmem=4096 39000 187000;
	$PROP net.ipv4.tcp_mem=187000 187000 187000;
	$PROP net.ipv4.tcp_no_metrics_save=1;
	$PROP net.ipv4.tcp_moderate_rcvbuf=1;

	echo "0" > /proc/sys/net/ipv4/tcp_timestamps;
	echo "1" > /proc/sys/net/ipv4/tcp_tw_reuse;
	echo "1" > /proc/sys/net/ipv4/tcp_sack;
	echo "1" > /proc/sys/net/ipv4/tcp_dsack;
	echo "1" > /proc/sys/net/ipv4/tcp_tw_recycle;
	echo "1" > /proc/sys/net/ipv4/tcp_window_scaling;
	echo "3" > /proc/sys/net/ipv4/tcp_keepalive_probes;
	echo "20" > /proc/sys/net/ipv4/tcp_keepalive_intvl;
	echo "30" > /proc/sys/net/ipv4/tcp_fin_timeout;
	echo "1" > /proc/sys/net/ipv4/tcp_moderate_rcvbuf;
	echo "1" > /proc/sys/net/ipv4/route/flush;
	echo "6144" > /proc/sys/net/ipv4/udp_rmem_min;
	echo "6144" > /proc/sys/net/ipv4/udp_wmem_min;
	echo "1" > /proc/sys/net/ipv4/tcp_rfc1337;
	echo "0" > /proc/sys/net/ipv4/ip_no_pmtu_disc;
	echo "0" > /proc/sys/net/ipv4/tcp_ecn;
	echo "6144 87380 2097152" > /proc/sys/net/ipv4/tcp_wmem;
	echo "6144 87380 2097152" > /proc/sys/net/ipv4/tcp_rmem;
	echo "1" > /proc/sys/net/ipv4/tcp_fack;
	echo "2" > /proc/sys/net/ipv4/tcp_synack_retries;
	echo "2" > /proc/sys/net/ipv4/tcp_syn_retries;
	echo "1" > /proc/sys/net/ipv4/tcp_no_metrics_save;
	echo "1800" > /proc/sys/net/ipv4/tcp_keepalive_time;
	echo "0" > /proc/sys/net/ipv4/ip_forward;
	echo "0" > /proc/sys/net/ipv4/conf/default/accept_source_route;
	echo "0" > /proc/sys/net/ipv4/conf/all/accept_source_route;
	echo "0" > /proc/sys/net/ipv4/conf/all/accept_redirects;
	echo "0" > /proc/sys/net/ipv4/conf/default/accept_redirects;
	echo "0" > /proc/sys/net/ipv4/conf/all/secure_redirects;
	echo "0" > /proc/sys/net/ipv4/conf/default/secure_redirects;
	echo "0" > /proc/sys/net/ipv4/ip_dynaddr;
	echo "1440000" > /proc/sys/net/ipv4/tcp_max_tw_buckets;
	echo "57344 57344 524288" > /proc/sys/net/ipv4/tcp_mem;
	echo "1440000" > /proc/sys/net/ipv4/tcp_max_tw_buckets;
#	echo "2097152" > /proc/sys/net/core/rmem_max;
#	echo "2097152" > /proc/sys/net/core/wmem_max;
#	echo "262144" > /proc/sys/net/core/rmem_default;
	echo "262144" > /proc/sys/net/core/wmem_default;
	echo "20480" > /proc/sys/net/core/optmem_max;
	echo "2500" > /proc/sys/net/core/netdev_max_backlog;
	echo "50" > /proc/sys/net/unix/max_dgram_qlen;

		log -p i -t $FILE_NAME "*** TCP_TWEAKS ***: enabled";
		return 0;
	else
		return 1;
	fi;
}
TCP_TWEAKS;

# ==============================================================
# FIREWALL-TWEAKS
# ==============================================================
FIREWALL_TWEAKS()
{
	if [ "$cortexbrain_firewall" == on ]; then
		# ping/icmp protection
		echo "1" > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts;
		echo "1" > /proc/sys/net/ipv4/icmp_echo_ignore_all;
		echo "1" > /proc/sys/net/ipv4/icmp_ignore_bogus_error_responses;

		log -p i -t $FILE_NAME "*** FIREWALL_TWEAKS ***: enabled";
		return 0;
	else
		return 1;
	fi;
}
FIREWALL_TWEAKS;

# ==============================================================
# SCREEN-FUNCTIONS
# ==============================================================

WIFI_PM()
{
	local state="$1";
	if [ "${state}" == "sleep" ]; then
		if [ "$wifi_pwr" == on ]; then
			if [ -e /sys/module/dhd/parameters/wifi_pm ]; then
				echo "1" > /sys/module/dhd/parameters/wifi_pm;
			fi;
		fi;

	elif [ "${state}" == "awake" ]; then
		if [ -e /sys/module/dhd/parameters/wifi_pm ]; then
			echo "0" > /sys/module/dhd/parameters/wifi_pm;
		fi;

	fi;

	log -p i -t $FILE_NAME "*** WIFI_PM ***: ${state}";
}

LOGGER()
{
	local state="$1";
	local dev_log_sleep="/dev/log-sleep";
	local dev_log="/dev/log";

	if [ "${state}" == "awake" ]; then
		if [ "$android_logger" == auto ] || [ "$android_logger" == debug ]; then
			if [ -e $dev_log_sleep ] && [ ! -e $dev_log ]; then
				mv $dev_log_sleep $dev_log
			fi;
		fi;
	elif [ "${state}" == "sleep" ]; then
		if [ "$android_logger" == auto ] || [ "$android_logger" == disabled ]; then
			if [ -e $dev_log ]; then
				mv $dev_log $dev_log_sleep;
			fi;
		fi;
	fi;

	log -p i -t $FILE_NAME "*** LOGGER ***: ${state}";
}

GESTURES()
{
	local state="$1";
	if [ "${state}" == "awake" ]; then
		if [ "$gesture_tweak" == on ]; then
			echo "1" > /sys/devices/virtual/misc/touch_gestures/gestures_enabled;
			pkill -f "/data/gesture_set.sh";
			pkill -f "/sys/devices/virtual/misc/touch_gestures/wait_for_gesture";
			nohup /sbin/busybox sh /data/gesture_set.sh;
		fi;
	elif [ "${state}" == "sleep" ]; then
		if [ `pgrep -f "/data/gesture_set.sh" | wc -l` != 0 ] || [ `pgrep -f "/sys/devices/virtual/misc/touch_gestures/wait_for_gesture" | wc -l` != 0 ] || [ "$gesture_tweak" == off ]; then
			pkill -f "/data/gesture_set.sh";
			pkill -f "/sys/devices/virtual/misc/touch_gestures/wait_for_gesture";
		fi;
		echo "0" > /sys/devices/virtual/misc/touch_gestures/gestures_enabled;
	fi;

	log -p i -t $FILE_NAME "*** GESTURE ***: ${state}";
}


# ==============================================================
# KSM-TWEAKS
# ==============================================================
if [ "$cortexbrain_ksm_control" == on ]; then
	KSM_NPAGES_BOOST=300;
	KSM_NPAGES_DECAY=50;

	KSM_NPAGES_MIN=32;
	KSM_NPAGES_MAX=1000;
	KSM_SLEEP_MSEC=200;
	KSM_SLEEP_MIN=2000;

	KSM_THRES_COEF=30;
	KSM_THRES_CONST=2048;

	KSM_NPAGES=0;
	KSM_TOTAL=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo);
	KSM_THRES=$(( $KSM_TOTAL * $KSM_THRES_COEF / 100 ));

	if [ $KSM_THRES_CONST -gt $KSM_THRES ]; then
		KSM_THRES=$KSM_THRES_CONST;
	fi;

	KSM_TOTAL=$(( $KSM_TOTAL / 1024 ));
	KSM_SLEEP=$(( $KSM_SLEEP_MSEC * 16 * 1024 / $KSM_TOTAL ));

	if [ $KSM_SLEEP -le $KSM_SLEEP_MIN ]; then
		KSM_SLEEP=$KSM_SLEEP_MIN;
	fi;

	KSMCTL()
	{
		case x${1} in
			xstop)
				log -p i -t $FILE_NAME "*** ksm: stop ***";
				echo 0 > /sys/kernel/mm/uksm/run;
			;;
			xstart)
				log -p i -t $FILE_NAME "*** ksm: start ${2} ${3} ***";
				echo ${2} > /sys/kernel/mm/uksm/pages_to_scan;
				echo ${3} > /sys/kernel/mm/uksm/sleep_millisecs;
				echo 1 > /sys/kernel/mm/uksm/run;
				renice -n 10 -p "$(pidof ksmd)";
			;;
			esac
	}

	INCREASE_NPAGES()
	{
		local delta=${1:-0};

		KSM_NPAGES=$(( $KSM_NPAGES + $delta ));
		if [ $KSM_NPAGES -lt $KSM_NPAGES_MIN ]; then
			KSM_NPAGES=$KSM_NPAGES_MIN;
		elif [ $KSM_NPAGES -gt $KSM_NPAGES_MAX ]; then
			KSM_NPAGES=$KSM_NPAGES_MAX;
		fi;

		echo $KSM_NPAGES;
	}

	ADJUST_KSM()
	{
		local free=$(awk '/^(MemFree|Buffers|Cached):/ {free += $2}; END {print free}' /proc/meminfo);

		if [ $free -gt $KSM_THRES ]; then
			npages=$(INCREASE_NPAGES ${KSM_NPAGES_BOOST});
			KSMCTL "stop";

			log -p i -t $FILE_NAME "*** ksm: $free > $KSM_THRES ***";

			return 1;
		else
			npages=$(INCREASE_NPAGES $KSM_NPAGES_DECAY);
			KSMCTL "start" $KSM_NPAGES $KSM_SLEEP;

			log -p i -t $FILE_NAME "*** ksm: $free < $KSM_THRES ***"

			return 0;
		fi;
	}
	ADJUST_KSM;
fi;

WIFI_PM()
{
	local state="$1";
	if [ "${state}" == "sleep" ]; then
		if [ "$wifi_pwr" == on ]; then
			if [ -e /sys/module/dhd/parameters/wifi_pm ]; then
				echo "1" > /sys/module/dhd/parameters/wifi_pm;
			fi;
		fi;

	elif [ "${state}" == "awake" ]; then
		if [ -e /sys/module/dhd/parameters/wifi_pm ]; then
			echo "0" > /sys/module/dhd/parameters/wifi_pm;
		fi;
	fi;

	log -p i -t $FILE_NAME "*** WIFI_PM ***: ${state}";
}

WIFI_TIMEOUT_TWEAKS()
{
RETURN_VALUE=$($sqlite /data/data/com.android.providers.settings/databases/settings.db "select value from secure where name='wifi_idle_ms'");
echo "Current wifi_idle_ms value: $RETURN_VALUE";
if [ $RETURN_VALUE='' ] 
then
   echo "Creating row with wifi_idle_ms value: $wifi_idle_wait";
   $sqlite /data/data/com.android.providers.settings/databases/settings.db "insert into secure (name, value) values ('wifi_idle_ms', $wifi_idle_wait )"
    log -p i -t $FILE_NAME "*** Creating row with wifi_idle_ms value: $wifi_idle_wait ***";
else
   echo "Updating wifi_idle_ms value from $RETURN_VALUE to $wifi_idle_wait";
   $sqlite /data/data/com.android.providers.settings/databases/settings.db "update secure set value=$wifi_idle_wait where name='wifi_idle_ms'"
   log -p i -t $FILE_NAME "*** Updating wifi_idle_ms value from $RETURN_VALUE to $wifi_idle_wait ***";
fi;
}
if [ "$cortexbrain_wifi" == on ]; then
WIFI_TIMEOUT_TWEAKS;
fi;
# please don't kill "cortexbrain"
DONT_KILL_CORTEX()
{
	PIDOFCORTEX=`pgrep -f "/sbin/ext/cortexbrain-tune.sh"`;
	for i in $PIDOFCORTEX; do
		echo "-950" > /proc/${i}/oom_score_adj;
	done;

	log -p i -t $FILE_NAME "*** DONT_KILL_CORTEX ***";
}

MOUNT_SD_CARD()
{
if [ "$auto_mount_sd" == on ]; then
		$PROP persist.sys.usb.config mass_storage,adb;
	if [ -e /dev/block/vold/179:49 ]; then
		echo "/dev/block/vold/179:49" > /sys/devices/virtual/android_usb/android0/f_mass_storage/lun1/file;
	fi;
	log -p i -t $FILE_NAME "*** MOUNT_SD_CARD ***";
fi;
}
MOUNT_SD_CARD;
# set wakeup booster delay to prevent mp3 music shattering when screen turned ON
WAKEUP_DELAY()
{
if [ "$wakeup_delay" != 0 ] && [ ! -e /data/.siyah/booting ]; then
log -p i -t $FILE_NAME "*** WAKEUP_DELAY ${wakeup_delay}sec ***";
sleep $wakeup_delay
fi;
}

WAKEUP_DELAY_SLEEP()
{
if [ "$wakeup_delay" != 0 ] && [ ! -e /data/.siyah/booting ]; then
log -p i -t $FILE_NAME "*** WAKEUP_DELAY_SLEEP ${wakeup_delay}sec ***";
sleep $wakeup_delay;
else
log -p i -t $FILE_NAME "*** WAKEUP_DELAY_SLEEP 3sec ***";
sleep 3;
fi;
}

# check if ROM booting now, then don't wait - creation and deletion of /data/.siyah/booting @> /sbin/ext/post-init.sh
WAKEUP_BOOST_DELAY()
{
if [ ! -e /data/.siyah/booting ] && [ "$wakeup_boost" != 0 ]; then
log -p i -t $FILE_NAME "*** WAKEUP_BOOST_DELAY ${wakeup_boost}sec ***";
sleep $wakeup_boost;
fi;
}

MALI_TIMEOUT()
{
	local state="$1";
	if [ "${state}" == "awake" ]; then
		echo "$mali_gpu_utilization_timeout" > /sys/module/mali/parameters/mali_gpu_utilization_timeout;
	elif [ "${state}" == "sleep" ]; then
		echo "300" > /sys/module/mali/parameters/mali_gpu_utilization_timeout;
	elif [ "${state}" == "performance" ]; then
		echo "100" > /sys/module/mali/parameters/mali_gpu_utilization_timeout;
	fi;

	log -p i -t $FILE_NAME "*** MALI_TIMEOUT: ${state} ***";
}

# boost CPU power for fast and no lag wakeup
MEGA_BOOST_CPU_TWEAKS()
{
if [ "$cortexbrain_cpu_boost" == on ]; then

echo "performance" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor;
CPU_GOV_TWEAKS "performance";

MALI_TIMEOUT "performance";

	# bus freq to 400MHZ in low load
echo "30" > /sys/devices/system/cpu/busfreq/dmc_max_threshold;
echo "30" > /sys/devices/system/cpu/busfreq/max_cpu_threshold;
echo "30" > /sys/devices/system/cpu/busfreq/up_cpu_threshold;

echo "1400000" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq;
echo "1400000" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq;
if [ "$mali_resume_enable" == on ]; then
echo "$gpu_res_freq" > /sys/module/mali/parameters/step0_clk;
fi;
log -p i -t $FILE_NAME "*** MEGA_BOOST_CPU_TWEAKS ***";
fi;
}
# set swappiness in case that no root installed, and zram used or disk swap used
SWAPPINESS()
{
	SWAP_CHECK=`free | grep Swap | awk '{ print $2 }'`;
	if [ "$zram" == 4 ] || [ "$SWAP_CHECK" == 0 ]; then
		echo "0" > /proc/sys/vm/swappiness;
	else
		echo "$swappiness" > /proc/sys/vm/swappiness;
	fi;
log -p i -t $FILE_NAME "*** SWAPPINESS: $swappiness ***";
}

TUNE_IPV6()
{
	CISCO_VPN=`find /data/data/com.cisco.anyconnec* | wc -l`;
	if [ "$cortexbrain_ipv6" == on ] || [ "$CISCO_VPN" != 0 ]; then
		echo "0" > /proc/sys/net/ipv6/conf/wlan0/disable_ipv6;
		$BB sysctl -w net.ipv6.conf.all.disable_ipv6=0;
		log -p i -t $FILE_NAME "*** TUNE_IPV6 ***: enabled";
	else
		echo "1" > /proc/sys/net/ipv6/conf/wlan0/disable_ipv6;
		$BB sysctl -w net.ipv6.conf.all.disable_ipv6=1;
		log -p i -t $FILE_NAME "*** TUNE_IPV6 ***: disabled";
	fi;
}

KERNEL_SCHED()
{
	local state="$1";

	# this is the correct order to input this settings, every value will be x2 after set
	if [ "${state}" == "awake" ]; then
		$BB sysctl -w kernel.sched_min_granularity_ns=1 > /dev/null 2>&1;
    		$BB sysctl -w kernel.sched_latency_ns=600000 > /dev/null 2>&1;
    		$BB sysctl -w kernel.sched_wakeup_granularity_ns=400000 > /dev/null 2>&1;
	elif [ "${state}" == "sleep" ]; then
		$BB sysctl -w kernel.sched_min_granularity_ns=1 > /dev/null 2>&1;
    		$BB sysctl -w kernel.sched_latency_ns=600000 > /dev/null 2>&1;
    		$BB sysctl -w kernel.sched_wakeup_granularity_ns=400000 > /dev/null 2>&1;
	fi;

	log -p i -t $FILE_NAME "*** KERNEL_SCHED ***: ${state}";
}

LOWMMKILLER()
{
        local state="$1";
        if [ "${state}" == "awake" ]; then
                /res/uci.sh oom_config $oom_config;
        elif [ "${state}" == "sleep" ]; then
                /res/uci.sh oom_config_sleep $oom_config_sleep;
        fi;

        log -p i -t $FILE_NAME "*** LOWMMKILLER ***: ${state}";
}

# if crond used, then give it root perent - if started by STweaks, then it will be killed in time
CROND_SAFETY()
{
	if [ "$crontab" == on ]; then
		pkill -f "crond";
		/res/crontab_service/service.sh;
		log -p i -t $FILE_NAME "*** CROND_SAFETY ***";
	fi;
}

DISABLE_NMI()
{
	if [ -e /proc/sys/kernel/nmi_watchdog ]; then
		echo "0" > /proc/sys/kernel/nmi_watchdog;
		log -p i -t $FILE_NAME "*** NMI ***: disable";
	fi;
}

ENABLE_NMI()
{
	if [ -e /proc/sys/kernel/nmi_watchdog ]; then
		echo "1" > /proc/sys/kernel/nmi_watchdog;
		log -p i -t $FILE_NAME "*** NMI ***: enabled";
	fi;
}

GAMMA_FIX()
{
	echo "$min_gamma" > /sys/class/misc/brightness_curve/min_gamma;
	echo "$max_gamma" > /sys/class/misc/brightness_curve/max_gamma;

	log -p i -t $FILE_NAME "*** GAMMA_FIX: min: $min_gamma max: $max_gamma ***: done";
}


NET()
{
	local state="$1";

	if [ "${state}" == "awake" ]; then
		echo "3" > /proc/sys/net/ipv4/tcp_keepalive_probes; # default: 3
		echo "1200" > /proc/sys/net/ipv4/tcp_keepalive_time; # default: 7200s
		echo "10" > /proc/sys/net/ipv4/tcp_keepalive_intvl; # default: 75s
		echo "10" > /proc/sys/net/ipv4/tcp_retries2; # default: 15
	elif [ "${state}" == "sleep" ]; then
		echo "2" > /proc/sys/net/ipv4/tcp_keepalive_probes;
		echo "300" > /proc/sys/net/ipv4/tcp_keepalive_time;
		echo "5" > /proc/sys/net/ipv4/tcp_keepalive_intvl;
		echo "5" > /proc/sys/net/ipv4/tcp_retries2;
	fi;

	log -p i -t $FILE_NAME "*** NET ***: ${state}";	
}

VFS_CACHE_PRESSURE()
{
	local state="$1";
	local sys_vfs_cache="/proc/sys/vm/vfs_cache_pressure";

	if [ -e $sys_vfs_cache ]; then
	if [ "${state}" == "awake" ]; then
		echo "20" > $sys_vfs_cache;
	elif [ "${state}" == "sleep" ]; then
		echo "10" > $sys_vfs_cache;
	fi;

	log -p i -t $FILE_NAME "*** VFS_CACHE_PRESSURE: ${state} ***";
			return 0;
	fi;

	return 1;
}

TWEAK_HOTPLUG_ECO()
{
	local state="$1";
	local sys_eco="/sys/module/intelli_plug/parameters/eco_mode_active";

	if [ -e $sys_eco ]; then
		if [ "${state}" == "awake" ]; then
			echo "0" > $sys_eco;
		elif [ "${state}" == "sleep" ]; then
			echo "1" > $sys_eco;
		fi;

		log -p i -t $FILE_NAME "*** TWEAK_HOTPLUG_ECO: ${state} ***";

		return 0;
	fi;

	return 1;
}

IO_SCHEDULER()
{
	local state="$1";
	local sys_mmc0_scheduler="/sys/block/mmcblk0/queue/scheduler";
	local sys_mmc1_scheduler="/sys/block/mmcblk1/queue/scheduler";

	if [ "${state}" == "awake" ]; then
		echo "$scheduler" > $sys_mmc0_scheduler;
		echo "$scheduler" > $sys_mmc1_scheduler;
	elif [ "${state}" == "sleep" ]; then
		echo "$sleep_scheduler" > $sys_mmc0_scheduler;
		echo "$sleep_scheduler" > $sys_mmc1_scheduler;
	fi;

	log -p i -t $FILE_NAME "*** IO_SCHEDULER: ${state} ***: done";	
}

# ==============================================================
# TWEAKS: if Screen-ON
# ==============================================================
AWAKE_MODE()
{
	LOGGER "awake";

	KERNEL_TWEAKS "awake"; 

	IO_TWEAKS;

	GAMMA_FIX;

	KERNEL_SCHED "awake";

	WAKEUP_DELAY;
	
	MEGA_BOOST_CPU_TWEAKS;

#	if [ "$cortexbrain_ksm_control" == on ] && [ "$KSM_TOTAL" != "" ]; then
#	ADJUST_KSM;
#	fi;
	
	GESTURES "awake";
	
	WAKEUP_BOOST_DELAY;
	
	echo "$AWAKE_LAPTOP_MODE" > /proc/sys/vm/laptop_mode;
	
	if [ "$cortexbrain_wifi" == on ]; then
	$IWCONFIG $INTERFACE frag 2345;
	$IWCONFIG $INTERFACE rts 2346;
	$IWCONFIG $INTERFACE txpower $cortexbrain_wifi_tx;
	fi;
	
	if [ "$cortexbrain_cpu_boost" == on ]; then
	echo "$scaling_governor" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor;
	fi;
	
	WIFI_PM "awake";

	TUNE_IPV6;
	
	NET "awake";
	
	TWEAK_HOTPLUG_ECO "awake";

	IO_SCHEDULER "awake";
	
	if [ "$mali_resume_enable" == on ]; then
	echo "$GPUFREQ1" > /sys/module/mali/parameters/step0_clk;
	fi;

	VFS_CACHE_PRESSURE "awake";

	if [ "$cortexbrain_cpu_boost" == on ]; then
	# set CPU speed
	echo "$scaling_min_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq;
	echo "$scaling_max_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq;
	fi;

	if [ "$cortexbrain_cpu_boost" == on ]; then
	# bus freq back to normal
	echo "$dmc_max_threshold" > /sys/devices/system/cpu/busfreq/dmc_max_threshold;
	echo "$max_cpu_threshold" > /sys/devices/system/cpu/busfreq/max_cpu_threshold;
	echo "$up_cpu_threshold" > /sys/devices/system/cpu/busfreq/up_cpu_threshold;
	MALI_TIMEOUT "awake";
	fi;
	
	ENABLE_NMI;

	DONT_KILL_CORTEX;
	
	SWAPPINESS;

	if [ "$cortexbrain_lmkiller" == on ]; then
	LOWMMKILLER "awake";
	fi;
	
		ECO_TWEAKS;
		if [ "$?" == 1 ]; then
			CPU_GOV_TWEAKS "awake";
			log -p i -t $FILE_NAME "*** AWAKE: Normal-Mode ***";
		else
			log -p i -t $FILE_NAME "*** AWAKE: ECO-Mode ***";
		fi;
}

# ==============================================================
# TWEAKS: if Screen-OFF
# ==============================================================
SLEEP_MODE()
{
	WAKEUP_DELAY_SLEEP;

	# we only read the config when screen goes off ...
	PROFILE=`cat /data/.siyah/.active.profile`;
	. /data/.siyah/$PROFILE.profile;

	if [ "$DUMPSYS" == 1 ]; then
		# check the call state, not on call = 0, on call = 2
		CALL_STATE=`dumpsys telephony.registry | awk '/mCallState/ {print $1}'`;
		if [ "$CALL_STATE" == "mCallState=0" ]; then
			CALL_STATE=0;
		else
			CALL_STATE=2;
		fi;
	else
		CALL_STATE=0;
	fi;

	if [ "$CALL_STATE" == 0 ]; then

	if [ "$cortexbrain_cpu_boost" == on ]; then
		# set CPU-Governor
	echo "$deep_sleep" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor;
	echo "$standby_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq;
		# reduce deepsleep CPU speed, SUSPEND mode
	echo "$scaling_min_suspend_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq;
	echo "$scaling_max_suspend_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq;
	fi;


	# set CPU-Tweak
	CPU_GOV_TWEAKS "sleep";
	
	if [ "$cortexbrain_cpu_boost" == on ]; then
	# bus freq to min 100Mhz
	echo "80" > /sys/devices/system/cpu/busfreq/dmc_max_threshold;
	echo "80" > /sys/devices/system/cpu/busfreq/max_cpu_threshold;
	echo "80" > /sys/devices/system/cpu/busfreq/up_cpu_threshold;
	MALI_TIMEOUT "sleep";
	fi;
	if [ "$cortexbrain_wifi" == on ]; then
	$IWCONFIG $INTERFACE frag 2345;
	$IWCONFIG $INTERFACE rts 2346;
	$IWCONFIG $INTERFACE txpower $cortexbrain_wifi_tx;
	fi;
	
	echo "$SLEEP_LAPTOP_MODE" > /proc/sys/vm/laptop_mode;

	KERNEL_SCHED "sleep";

	GESTURES "sleep";

	TUNE_IPV6;

	BATTERY_TWEAKS;

	CROND_SAFETY;
	
	SWAPPINESS;

	WIFI_PM "sleep";

#	if [ "$cortexbrain_ksm_control" == on ]; then
#			KSMCTL "stop";
#		else
#			echo 2 > /sys/kernel/mm/uksm/run;
#	fi;
	
	IO_SCHEDULER "sleep";

	VFS_CACHE_PRESSURE "sleep";
		
	TWEAK_HOTPLUG_ECO "sleep";

	DISABLE_NMI;

	if [ "$cortexbrain_lmkiller" == on ]; then
	LOWMMKILLER "sleep";
	fi;
		
	NET "sleep";

	KERNEL_TWEAKS "sleep";

	log -p i -t $FILE_NAME "*** SLEEP mode ***";

	LOGGER "sleep";

	else
		
	log -p i -t $FILE_NAME "*** On Call! SLEEP aborted! ***";

	fi;

}

# ==============================================================
# Background process to check screen state
# ==============================================================

# Dynamic value do not change/delete
cortexbrain_background_process=1;

if [ "$cortexbrain_background_process" == 1 ] && [ `pgrep -f "cat /sys/power/wait_for_fb_sleep" | wc -l` == 0 ] && [ `pgrep -f "cat /sys/power/wait_for_fb_wake" | wc -l` == 0 ]; then
	(while [ 1 ]; do
		# AWAKE State. all system ON.
		cat /sys/power/wait_for_fb_wake > /dev/null 2>&1;
		AWAKE_MODE;
		sleep 3;

		# SLEEP state. All system to power save.
		cat /sys/power/wait_for_fb_sleep > /dev/null 2>&1;
		SLEEP_MODE;
	done &);
	else
	if [ "$cortexbrain_background_process" == 0 ]; then
		echo "Cortex background disabled!"
	else
		echo "Cortex background process already running!";
	fi;
fi;

