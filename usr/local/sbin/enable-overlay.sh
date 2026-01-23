#!/bin/bash

if [ $UID -ne 0 ] ; then
        echo "Please run this program as root or using sudo."
        exit 1
fi

if [ "$1" == "enable-bootro" ] ; then
	if raspi-config nonint enable_bootro ; then
		echo "Read-Only access to '/boot/firmware' will be enabled upon next reboot."
		echo "To make further changes, call '$0' again, preferably after a reboot."
	else
		echo "Error enabling read-only mode for '/boot/firmware'."
		exit 1
	fi
fi

if grep '/boot/firmware' /proc/mounts | grep -q "[[:space:]]rw[[:space:],]" || [ "$1" == "force-remount-rw" ] ; then
	if [ "$1" == "force-remount-rw" ] && ! mount -oremount,rw /boot/firmware ; then
	echo "Error remounting '/boot/firmware' in read-write mode."
		echo "No changes were made. Exiting."
		exit 1
	fi
	if raspi-config nonint enable_overlayfs ; then 
		echo "Overlayroot will be activated upon next reboot."
		echo "To mount '/boot/firmware' in read-only mode, run:"
		echo "'sudo $0 enable-bootro'"
		echo "To reboot now, try something like 'sudo reboot'"
		exit 0
	else
		echo "Error enabling overlayroot."
		echo "Please do not reboot until you have verified that"
		echo "the file '/boot/firmware/cmdline.txt' still contains"
		echo "a valid boot configuration."
		exit 1
	fi
else
	echo "The '/boot/firmware' mountpoint is mounted read-only."
	echo "Please fix this yourself before trying to run this program again,"
	echo "or use 'sudo $0 force-remount-rw'"
	echo "No changes were made. Exiting."
	exit 1
fi
