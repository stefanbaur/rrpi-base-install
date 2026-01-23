#!/bin/bash

if [ $UID -ne 0 ] ; then
        echo "Please run this program as root or using sudo."
        exit 1
fi

if [ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/.)" ]; then
	echo "Chroot detected! You should not attempt to"
	echo "run this script inside a chroot environment."
	echo "Exiting."
	exit 1
fi

if [ "$1" == "disable-bootro" ] ; then
	if [ "$1" == "force-remount-rw" ] && ! mount -oremount,rw /boot/firmware ; then
		echo "Error remounting '/boot/firmware' in read-write mode."
		echo "No changes were made. Exiting."
		exit 1
	fi
	if raspi-config nonint disable_bootro ; then
		echo "Read-Write access to '/boot/firmware' will be enabled upon next reboot."
		echo "To make further changes, call '$0' again, preferably after a reboot."
	else
		echo "Error enabling read-write mode for '/boot/firmware'."
		exit 1
	fi
fi

if grep '/boot/firmware' /proc/mounts | grep -q "[[:space:]]rw[[:space:],]" || [ "$1" == "force-remount-rw" ] ; then
	if [ "$1" == "force-remount-rw" ] && ! mount -oremount,rw /boot/firmware ; then
		echo "Error remounting '/boot/firmware' in read-write mode."
		echo "No changes were made. Exiting."
		exit 1
	fi
	if sed -e 's#overlayroot[:=a-z0]* #overlayroot=tmpfs #' -i /boot/firmware/cmdline.txt && \
	   raspi-config nonint disable_overlayfs ; then
		echo "Overlayroot will be deactivated upon next reboot."
		echo "To reboot now, try something like 'sudo reboot'"
		exit 0
	else
		echo "Error disabling overlayroot."
		echo "Please do not reboot until you have verified that"
		echo "the file '/boot/firmware/cmdline.txt' still contains"
		echo "a valid boot configuration."
		exit 1
	fi
else
	echo "The '/boot/firmware' mountpoint is mounted read-only."
	echo "Please fix this yourself before trying to run this program again,"
	echo "or use 'sudo $0 force-remount-rw' to mount it read-write until the next reboot."
	echo "Alternatively, to mount '/boot/firmware' in read-write mode permanently, run:"
	echo "'sudo $0 disable-bootro'"
	echo "No changes were made. Exiting."
	exit 1
fi
