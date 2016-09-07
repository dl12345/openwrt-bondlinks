#!/bin/sh 

# Beware - if you up and down interfaces here then it will create a loop as it blocks the 
# initscripts from finishing properly. If you wish to do this then fork a script and return 
# from this one


. $IPKG_INSTROOT/lib/functions/network.sh



get_core() 
{
	local option
	local mask

	option=$1
	case $option in
		0)
			mask=3 # 0 and 1
			;;
		1)
			mask=12 # 2 and 2
			;;
		*)
			mask=15 # 0, 1, 2, 3
			;;
	esac
	return $mask
}


set_affinity()
{
	local pid
	local pids
	local instance="0"
	local mask


	#pids="$(pidof openvpn)"
	pids="$(pidof dropbear)"
	for pid in $pids; do
		if [ -e "/proc/$pid/stat" ] 
		then
			get_core $instance
			taskset -p $? $pid
		fi
		instance=`expr $instance + 1`
	done
	return 0
}

set_affinity
