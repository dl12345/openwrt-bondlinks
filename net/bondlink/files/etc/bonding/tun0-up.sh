#!/bin/sh

BONDIF="bond0"
TUN=${1}
SLAVES=$(cat /sys/class/net/${BONDIF}/bonding/slaves)

# If it's already a slave then do nothing

for i in ${SLAVES}; do

	if [ $i == ${TUN} ]; then
	
		exit 0

	fi

done

# Otherwise add it as a slave - this will occur if the link goes down and openvpn re-establishes it
# since we're removing it as a slave on a tunnel down event. 

ifconfig ${1} down 2> /dev/null
echo "+${1}" > /sys/class/net/${BONDIF}/bonding/slaves 2> /dev/null
ifconfig ${1} up 2> /dev/null


exit $?


