#!/sbin/busybox sh
# DATA on script

(
	PROFILE=`cat /data/.siyah/.active.profile`;
	. /data/.siyah/$PROFILE.profile;

	if [ "$cron_mobile_data" == "on" ]; then
	svc data disable;
	svc wifi disable;
	date +%H:%M-%D-%Z > /data/crontab/mdata_off;
	echo "Done! Mobile network disabled" >> /data/crontab/mdata_off;
	fi;
)&
