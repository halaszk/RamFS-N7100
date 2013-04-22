#!/sbin/busybox sh
#
# Loopy Smoothness Tweak for Galaxy S ver. Test 2 (Experimental)
# NeoPhyTe.x360 Edit

killall -9 smoothsystem.sh
/sbin/ext/smoothsystem.sh &
/sbin/busybox renice 19 `pidof smoothsystem.sh`





