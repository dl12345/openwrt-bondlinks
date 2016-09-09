#!/bin/sh

BONDIF="bond0"
TUN=${1}
SLAVES=$(cat /sys/class/net/${BONDIF}/bonding/slaves)

# Check if it's a slave and if so then remove it from the list of slaves
# Failure to do so will result in packet loss as the bonding driver continues 
# to round robin packets onto a disconnected interface

for i in ${SLAVES}; do

	if [ $i == ${TUN} ]; then
	
		ifconfig ${1} down 2> /dev/null
		echo "-${1}" > /sys/class/net/${BONDIF}/bonding/slaves 2> /dev/null

		exit $?

	fi

done

# Otherwise do nothing

exit 0
