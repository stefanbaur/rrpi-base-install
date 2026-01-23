#!/bin/bash

if [ $UID -ne 0 ] ; then
        echo "Please run this program as root or using sudo."
        exit 1
fi

if [ -z "$1" ] ; then
        echo "This script requires you to pass the ENV number as its first parameter. Aborting."
        exit 1
fi

NEWENV=$1

# this sets SOURCE to the device name of the current /boot/firmware mount
eval $(findmnt -P /boot/firmware  | tr ' ' '\n' | grep '^SOURCE')

# if we're not in ENV1, we need to mount ENV1's bootfs 
if ! [ "$(readlink -e /dev/disk/by-label/bootfs)" == "$SOURCE" ] ; then
	MOUNTPOINT=$(mktemp -d)
	if ! mount /dev/disk/by-label/bootfs /${MOUNTPOINT} ; then
		echo "Unable to mount '/dev/disk/by-label/bootfs'. Exiting."
		exit 1
	fi
else
	MOUNTPOINT=/boot/firmware
fi

# set the boot partition for future boots to $NEWENV
if grep -q "^\[default\]$" /${MOUNTPOINT}/autoboot.txt ; then
	sed ':start;N;s/^\[default\]\nboot_partition=./[default]\nboot_partition='${NEWENV}'/;t start;P;D' -i /${MOUNTPOINT}/autoboot.txt
else
	sed -e "s#^boot_partition=.#boot_partition="${NEWENV}"#" -i /${MOUNTPOINT}/autoboot.txt
fi

# if we're not in ENV1, we need to umount ENV1's bootfs 
if ! [ "$(readlink -e /dev/disk/by-label/bootfs)" == "$SOURCE" ] ; then
	if ! umount /dev/disk/by-label/bootfs ; then
		echo "Unable to umount '/dev/disk/by-label/bootfs'. Exiting."
		exit 1
	fi
	if ! rmdir "$MOUNTPOINT" ; then
		echo "Unable to remove mountpoint '${MOUNTPOINT}'. Exiting."
		exit 1
	fi
fi
if [ "$2" == "reboot" ]; then
	if ! reboot ; then
		echo "Unable to reboot. Exiting."
		exit 1
	else
		echo "All done. 'ENV${NEVENV}' will become active after the next reboot."
		echo "Rebooting now."
		exit 0
	fi
fi

echo "All done. 'ENV${NEVENV}' will become active after the next reboot."
echo "To trigger a reboot into 'ENV${NEWENV}' immediately after making the change, call:"
echo 'sudo $0 ${NEWENV} reboot'"
