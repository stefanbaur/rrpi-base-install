#!/bin/bash -e

if [ -b "$1" ]; then
	export BASEDEV="$1"
else
	echo "'$1' is not a block device, aborting."
	exit 1
fi

source ../base_install.conf
[ -s ../base_install_custom.conf ] && source ../base_install_custom.conf

if [ -n "$OVERRIDE_ROOTFS_MAXSIZE" ]; then
	ROOTFS_MAXSIZE="$OVERRIDE_ROOTFS_MAXSIZE"
else
	ROOTFS_MAXSIZE="8G"
fi

if [ -n "$OVERRIDE_DATA_MAXSIZE" ]; then
	DATA_MAXSIZE="$OVERRIDE_DATA_MAXSIZE"
else
	DATA_MAXSIZE="" # empty means use remaining space
fi

if echo -n "$BASEDEV" | grep -q "mmc" ; then
	export BASEDEV=$(echo -n "$BASEDEV" | sed -e 's/p$//')
	export PARTONE="${BASEDEV}p1"
	export PARTTWO="${BASEDEV}p2"
	export PARTTHREE="${BASEDEV}p3"
	export PARTFIVE="${BASEDEV}p5"
	export PARTSIX="${BASEDEV}p6"
	export PARTSEVEN="${BASEDEV}p7"
	export PARTEIGHT="${BASEDEV}p8"
else
	export PARTONE="${BASEDEV}1"
	export PARTTWO="${BASEDEV}2"
	export PARTTHREE="${BASEDEV}3"
	export PARTFIVE="${BASEDEV}5"
	export PARTSIX="${BASEDEV}6"
	export PARTSEVEN="${BASEDEV}7"
	export PARTEIGHT="${BASEDEV}8"
fi

echo "16384,512M,c" | sfdisk -N 1 $BASEDEV >/dev/null 2>&1
while ! partprobe $BASEDEV; do sleep 1; done
echo ",512M,c" | sfdisk -N 2 $BASEDEV >/dev/null 2>&1
while ! partprobe $BASEDEV; do sleep 1; done
echo ",512M,c" | sfdisk -N 3 $BASEDEV >/dev/null 2>&1
while ! partprobe $BASEDEV; do sleep 1; done
echo "3162112,,Ex" | sfdisk -N 4 $BASEDEV >/dev/null 2>&1
echo ",$ROOTFS_MAXSIZE" | sfdisk -N 5 $BASEDEV >/dev/null 2>&1
while ! partprobe $BASEDEV; do sleep 1; done
echo ",$ROOTFS_MAXSIZE" | sfdisk -N 6 $BASEDEV >/dev/null 2>&1
while ! partprobe $BASEDEV; do sleep 1; done
echo ",$ROOTFS_MAXSIZE" | sfdisk -N 7 $BASEDEV >/dev/null 2>&1
while ! partprobe $BASEDEV; do sleep 1; done
echo ",$DATA_MAXSIZE" | sfdisk -N 8 $BASEDEV >/dev/null 2>&1
while ! partprobe $BASEDEV; do sleep 1; done

sfdisk --dump $BASEDEV | tee ./custom/partitions.txt
