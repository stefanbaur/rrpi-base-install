#!/bin/bash

CURSYS=$(cut -c 4 /etc/ssh/banner)

if [ $UID -ne 0 ]; then
	echo "Please run this program as root or using sudo."
	exit 1
fi

if [ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/.)" ]; then
	echo "Chroot detected! You should not attempt to"
	echo "run this script inside a chroot environment."
	echo "Exiting."
	exit 1
fi

if [ -z "$1" ] ; then
        echo "This script requires you to pass the ENV number as its first parameter. Aborting."
        exit 1
fi

if [ $1 -eq $CURSYS ] && [ "$2" != "force" ] ; then
        echo "Upgrading the running system is not recommended."
        echo "Use '$0 $CURSYS force' to force an upgrade."
        exit 1
elif [ $1 -eq $CURSYS ] && [ "$2" == "force" ] ; then
        if mount | grep -q "^overlayroot" ; then
                echo "Your root file system is an overlayroot."
                echo "Upgrading this system is a waste of time, CPU power,"
                echo "RAM, and network bandwidth, as all upgrades will be gone"
                echo "after the next reboot."
                echo "Disable the overlayroot, perform a reboot, and try again."
                exit 1
        fi
        if [ "$3" == "full" ]; then
                echo "You really think this is a good idea?"
                echo "Well, you figured out the syntax for this command on your"
                echo "own, so hopefully you know what you're doing ..."
                DOFULL="yes"
        fi
        FORCE_CURSYS="yes"
elif [ "$2" == "full" ] ; then
        DOFULL="yes"
fi

if [ $1 -eq 1 ]; then
        DEST=""
else
        DEST=$1
fi

if [ "$FORCE_CURSYS" != "yes" ] ; then
        MOUNTPOINT=$(mktemp -d)
        mount /dev/disk/by-label/rootfs${DEST} /${MOUNTPOINT}
        mount /dev/disk/by-label/bootfs${DEST} /${MOUNTPOINT}/boot/firmware
        mount --bind /dev /${MOUNTPOINT}/dev
        mount --bind /sys /${MOUNTPOINT}/sys
        mount -t devpts none /${MOUNTPOINT}/dev/pts
        mount -t proc none /${MOUNTPOINT}/proc
        CHROOT_COMMAND="chroot"
else
        MOUNTPOINT=""
        CHROOT_COMMAND=""
fi

if [ "$DOFULL" == "yes" ] ; then
        APTCMDLIST="update\nfull-upgrade -d -y\nupgrade -y\nfull-upgrade -y\nclean\nautopurge -y"
else
        APTCMDLIST="update\nupgrade -d -y\nupgrade -y\nclean\nautopurge -y"
fi
OLDIFS=$IFS
IFS=$'\n'
for APTCMD in $(echo -e "$APTCMDLIST") ; do
        $CHROOT_COMMAND $MOUNTPOINT /bin/bash -c "DEBIAN_FRONTEND='noninteractive' apt $APTCMD"
done
IFS=$OLDIFS

if [ "$FORCE_CURSYS" != "yes" ] ; then
        umount -R /${MOUNTPOINT}
        rmdir /${MOUNTPOINT}
fi

