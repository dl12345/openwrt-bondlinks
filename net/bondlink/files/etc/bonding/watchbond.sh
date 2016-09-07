#!/bin/sh 
# Adapted from /usr/bin/watchcat.sh

watchbond() 
{
	local period="$1"; local pinghosts="$2"; local pingperiod="$3"; local command="${4}"

	time_now="$(cat /proc/uptime)"
	time_now="${time_now%%.*}"
	time_lastcheck="$time_now"
	time_lastcheck_withinternet="$time_now"

	logger -p daemon.info -t "watchbond[$$]" "Monitoring bond link every ${pingperiod} seconds. Restart enabled after ${period} seconds"

	# sleep for 10 seconds to give the tunnels time to initialize 

	sleep 10

	while true
	do
		# account for the time ping took to return. With a ping time of 5s, ping might take more 
		# than that, so it is important to avoid even more delay.

		time_now="$(cat /proc/uptime)"
		time_now="${time_now%%.*}"
		time_diff="$((time_now-time_lastcheck))"

		[ "$time_diff" -lt "$pingperiod" ] && {
			sleep_time="$((pingperiod-time_diff))"
			sleep "$sleep_time"
		}

		time_now="$(cat /proc/uptime)"
		time_now="${time_now%%.*}"
		time_lastcheck="$time_now"

		for host in "$pinghosts"
		do
			if ping -c 1 "$host" &> /dev/null 
			then 
				time_lastcheck_withinternet="$time_now"
			else
				time_diff="$((time_now-time_lastcheck_withinternet))"
				logger -p daemon.info -t "watchbond[$$]" "no internet connectivity for $time_diff seconds. Resetting bond when reaching $period"       
			fi
		done

		time_diff="$((time_now-time_lastcheck_withinternet))"
		if [ "$time_diff" -ge "$period" ]; then
			logger -p daemon.info -t "watchbond[$$]" "Resetting with ${4}"
			eval "${4}"
		fi

	done
}

watchbond "$1" "$2" "$3" "$4"
