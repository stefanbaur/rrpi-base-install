#!/bin/bash

#log start
[ -f /data/INI-start ] || touch /data/INI-start

# show that we're not yet ready if the banner is not set yet
chvt 8
clear >/dev/tty8
while ! ([ -f /etc/ssh/banner ] && grep "^ENV" /etc/ssh/banner) ; do
	echo "banner not set yet $(date)"
	sleep 10
done
chvt 1

# set ENV vars once banner is available
MY_ENV=$(cat /etc/ssh/banner)
MY_ENV_NUMBER=$(sed -e 's/^ENV\([1-3]\).*$/\1/' /etc/ssh/banner)

# show ENV1 has been booted by heartbeat-flashing the ACT LED
[ "$MY_ENV_NUMBER" == "1" ] && echo heartbeat >/sys/devices/platform/leds/leds/ACT/trigger

# log our ENV and date
echo "$MY_ENV - booted and reached /data/autostart.sh - $(date)" | tee -a /data/reboot.log

### begin-of-runonce ###

# copy all output to log file as well as debug console
exec > >(tee "/data/setup.log" >/dev/tty8) 2>&1

# switch to debug console and clear it
chvt 8
clear

# make sure apt/dpkg don't try to pop up any dialog boxes
export DEBIAN_FRONTEND=noninteractive

# test if cloud-init is still running
echo "$MY_ENV - checking/waiting for cloud-init to finish - $(date)" | tee -a /data/reboot.log

# checking for the presence of this file is one of the officially supported methods
# to determine if cloud-init has finished - and the only one that works. 
while ! [ -s /var/lib/cloud/instance/boot-finished ] ; do
	echo "$MY_ENV - cloud init not done yet - $(date)" | tee -a /data/reboot.log
	date >> /data/cloud-init-processes.log
	pstree -p >> /data/cloud-init-processes.log
	ps ax >> /data/cloud-init-processes.log
	# this is because sometimes, cloud-init is too dumb to live and claims /boot/firmware/meta-data and/or 
	# /boot/firmware/user-data could not be found - EVEN THOUGH THE FILES ARE RIGHT WHERE THEY BELONG
	if (grep "No such file" /var/log/cloud-init.log | grep -q -e "user-data" -e "meta-data") ; then
		# in that case, we copy and zero the logfiles ...
		cp /var/log/cloud-init.log /data/$MY_ENV-FAIL-$(date +%F_%T|tr ':' '-')-cloud-init.log
		echo "" > /var/log/cloud-init.log
		cp /var/log/cloud-init-output.log /data/$MY_ENV-FAIL-$(date +%F_%T|tr ':' '-')-cloud-init-output.log
	        echo "" > /var/log/cloud-init-output.log
		# ... log the error in our own logfile ...
		echo "$MY_ENV - FAILURE TO RUN CLOUD-INIT, REBOOTING - $(date)" | tee -a /data/reboot.log
		# ... and trigger an immediate reboot into current ENV, because rebooting and running cloud-init again seems to fix it
		/sbin/reboot $MY_ENV_NUMBER
	fi
	sleep 5
done

# log that we're done
echo "$MY_ENV - cloud-init complete - $(date)" | tee -a /data/reboot.log

# if cloud-init has completed for this ENV, remove cloud-init and check for further tasks
if grep -q "^$MY_ENV - cloud-init complete" /data/reboot.log ; then

	# this block gets executed in all ENVs
	# make sure "PasswordAuthentication no" remains set even after cloud-init purge
	mv /etc/ssh/sshd_config.d/50-cloud-init.conf /etc/ssh/sshd_config.d/50-disable-password-auth.conf
	# add additional eth interfaces to bridge, if present
	sed -e "s/bridge_ports eth0/bridge_ports $(ip a l | awk '$2~/eth/ && !/\@/ { print $2 }' | tr -s '\n:' '  ')/" -i /etc/network/interfaces
	# remove cloud-init
	apt-get purge cloud-init -y 2>&1 | tee -a /data/$MY_ENV-apt.log
	# do not use apt-get autopurge -y or apt-get clean here, or you might wipe the overlayfs packages we already downloaded during the chroot phase
	# install and configure watchdog
	apt-get install watchdog -y | tee -a /data/$MY_ENV-apt.log
	mkdir -p /etc/systemd/system.conf.d
	echo '# enable hardware watchdog' > /etc/systemd/system.conf.d/sysdwatchdog.conf
	echo '#' >> /etc/systemd/system.conf.d/sysdwatchdog.conf
	echo '# [Manager]' >> /etc/systemd/system.conf.d/sysdwatchdog.conf
	echo '# RuntimeWatchdogSec=15' >> /etc/systemd/system.conf.d/sysdwatchdog.conf
	echo '# ShutdownWatchdogSec=5min' >> /etc/systemd/system.conf.d/sysdwatchdog.conf
	sed 	-e '/#watchdog-device/a watchdog-device=/dev/watchdog' \
		-e '/#watchdog-timeout/a watchdog-timeout=15' \
		-e '/#max-load-1\W/a max-load-1=24' \
		-i /etc/watchdog.conf
	# enable overlay file system
	raspi-config nonint enable_overlayfs 2>&1 | tee -a /data/$MY_ENV-apt.log
	# make sure /data is not affected by overlayfs
	sed -e "s#overlayroot=tmpfs #overlayroot=tmpfs:recurse=0 #" -i /boot/firmware/cmdline.txt

	# the following blocks are ENV-specific
	if grep -q "^ENV1" /etc/ssh/banner; then
		# now clean up apt, as we're in ENV1 and don't want to install any extra packages here
		apt-get clean 2>&1 | tee -a /data/$MY_ENV-apt.log
		apt-get autopurge -y 2>&1 | tee -a /data/$MY_ENV-apt.log
		# set the boot partition for next boot 1->2
		if grep -q "^\[default\]$" /boot/firmware/autoboot.txt ; then
			sed ':start;N;s/^\[default\]\nboot_partition=1/[default]\nboot_partition=2/;t start;P;D' -i /boot/firmware/autoboot.txt
		else
			sed -e "s#^boot_partition=1#boot_partition=2#" -i /boot/firmware/autoboot.txt
		fi
		# perform a reboot
		if /sbin/reboot 2>&1 | tee -a /data/reboot.log ; then
			# log success
			echo "$MY_ENV - stage complete - $(date)" | tee -a /data/reboot.log
			touch /data/ENV1-stage-complete
		else
			# log failure
			echo "$MY_ENV - could not perform reboot - $(date)" | tee -a /data/reboot.log
			touch /data/ENV1-could-not-perform-reboot
		fi
	elif grep -q "^ENV2" /etc/ssh/banner; then
		# set sane defaults for xinetd and udev
		mkdir -p /etc/xinetd.d/
		COUNT=0
		while [ $COUNT -lt 4 ]; do 
			cat >/etc/xinetd.d/p910${COUNT}d <<P910ND_TEMPLATE2
service p910${COUNT}d
{
        disable         = no
        socket_type     = stream
        protocol        = tcp
        port            = 910${COUNT}
        user            = root
        wait            = no
        server          = /usr/sbin/p910nd
        server_args     = -b -f /dev/persistent_lp/lp${COUNT}
}
P910ND_TEMPLATE2
			sed -e "\#910${COUNT}/tcp#d" -i /etc/services
			echo -e "p910${COUNT}d\t910${COUNT}/tcp\t# TCP RAW print service" >>/etc/services
			COUNT=$((COUNT+1))
		done
		cat > /etc/udev/rules.d/050_persistent_printer_mappings.rules <<UDEVRULES2
# persistent printer mapping via udev rules

# enable/disable debugging
#ENV{UDEV_PPM_DEBUG}="true"
ENV{UDEV_PPM_DEBUG}="false"

# skip everything if this ...
# ... is a device removal
ACTION=="remove", GOTO="persistent_printer_mappings_end"

# ... isn't a usbmisc (what used to be usblp) subsystem device
SUBSYSTEM!="usbmisc", GOTO="persistent_printer_mappings_end"

# ... isn't a printer-type device
SUBSYSTEMS=="usb", ATTRS{bInterfaceClass}!="07", GOTO="persistent_printer_mappings_end"

ENV{UDEV_PPM_DEBUG}=="true", RUN+="/usr/bin/logger '[UDEV-PPM-DEBUG] Printer detected! Attempting to determine which Pi model we are are running on ...'"

# Pi model detection starts here

# Pi4B detected, as ...
# ... this device has a PCIe platform of the 'fd500000.pcie' type
KERNELS=="*fd500000.pcie*", GOTO="switch_pi4b"
# ... has a 'scb' subsystem in its search path
KERNELS=="*scb*", GOTO="switch_pi4b"

# Pi3B+ detected, as it has a LAN7800 hub (vendor: 0424, product: 2514) in its USB tree
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0424", ATTRS{idProduct}=="2514", GOTO="switch_pi3b_plus"

# no better matches, so we're likely on a Pi3B or Pi1
GOTO="switch_pi3b"

# actual port assignments start here

# Pi4B
LABEL="switch_pi4b"
ENV{UDEV_PPM_DEBUG}=="true", RUN+="/usr/bin/logger '[UDEV-PPM-DEBUG] SWITCH: Pi4B detected!'"
KERNELS=="1-1.3:1.0", SYMLINK+="persistent_lp/lp0", RUN+="/usr/bin/logger '[UDEV-PPM] Pi4B: assigned lp0'", GOTO="persistent_printer_mappings_end"
KERNELS=="1-1.4:1.0", SYMLINK+="persistent_lp/lp1", RUN+="/usr/bin/logger '[UDEV-PPM] Pi4B: assigned lp1'", GOTO="persistent_printer_mappings_end"
KERNELS=="2-1:1.0", SYMLINK+="persistent_lp/lp2", RUN+="/usr/bin/logger '[UDEV-PPM] Pi4B: assigned lp2 (USB3)'", GOTO="persistent_printer_mappings_end"
KERNELS=="2-2:1.0", SYMLINK+="persistent_lp/lp3", RUN+="/usr/bin/logger '[UDEV-PPM] Pi4B: assigned lp3 (USB3)'", GOTO="persistent_printer_mappings_end"
KERNELS=="1-1.1:1.0", SYMLINK+="persistent_lp/lp2", RUN+="/usr/bin/logger '[UDEV-PPM] Pi4B: assigned lp2 (USB2)'", GOTO="persistent_printer_mappings_end"
KERNELS=="1-1.2:1.0", SYMLINK+="persistent_lp/lp3", RUN+="/usr/bin/logger '[UDEV-PPM] Pi4B: assigned lp3 (USB2)'", GOTO="persistent_printer_mappings_end"
GOTO="persistent_printer_mappings_end"

#Pi3B+
LABEL="switch_pi3b_plus"
ENV{UDEV_PPM_DEBUG}=="true", RUN+="/usr/bin/logger '[UDEV-PPM-DEBUG] SWITCH: Pi3B+ detected!'"
KERNELS=="1-1.1.2:1.0", SYMLINK+="persistent_lp/lp2", RUN+="/usr/bin/logger '[UDEV-PPM] Pi3B+: assigned lp2'", GOTO="persistent_printer_mappings_end"
KERNELS=="1-1.1.3:1.0", SYMLINK+="persistent_lp/lp3", RUN+="/usr/bin/logger '[UDEV-PPM] Pi3B+: assigned lp3'", GOTO="persistent_printer_mappings_end"
KERNELS=="1-1.3:1.0", SYMLINK+="persistent_lp/lp1", RUN+="/usr/bin/logger '[UDEV-PPM] Pi3B+: assigned lp1'", GOTO="persistent_printer_mappings_end"
KERNELS=="1-1.2:1.0", SYMLINK+="persistent_lp/lp0", RUN+="/usr/bin/logger '[UDEV-PPM] Pi3B+: assigned lp0'", GOTO="persistent_printer_mappings_end"
GOTO="persistent_printer_mappings_end"

#Pi3B/Pi1
LABEL="switch_pi3b"
ENV{UDEV_PPM_DEBUG}=="true", RUN="/usr/bin/logger '[UDEV-PPM-DEBUG] SWITCH: Pi3B/Pi1 detected!'"
KERNELS=="1-1.2:1.0", SYMLINK+="persistent_lp/lp0", RUN+="/usr/bin/logger '[UDEV-PPM] Pi3B/Pi1: assigned lp0'", GOTO="persistent_printer_mappings_end"
KERNELS=="1-1.3:1.0", SYMLINK+="persistent_lp/lp1", RUN+="/usr/bin/logger '[UDEV-PPM] Pi3B/Pi1: assigned lp1'", GOTO="persistent_printer_mappings_end"
KERNELS=="1-1.4:1.0", SYMLINK+="persistent_lp/lp2", RUN+="/usr/bin/logger '[UDEV-PPM] Pi3B: assigned lp2'", GOTO="persistent_printer_mappings_end"
KERNELS=="1-1.5:1.0", SYMLINK+="persistent_lp/lp3", RUN+="/usr/bin/logger '[UDEV-PPM] Pi3B: assigned lp3'", GOTO="persistent_printer_mappings_end"

# end of ruleset marker
LABEL="persistent_printer_mappings_end"
UDEVRULES2
		# as we already downloaded the required packages during the chroot phase, we can install p910nd without needing internet access
		apt-get install -y p910nd xinetd 2>&1 | tee /data/$MY_ENV-apt.log
		# now clean up apt, as we're done installing packages
		apt-get clean 2>&1 | tee -a /data/$MY_ENV-apt.log
		apt-get autopurge -y 2>&1 | tee -a /data/$MY_ENV-apt.log
		# set the boot partition for next boot 2->3 (as we're in ENV2, we need to mount ENV1's bootfs for that)
		mount /dev/disk/by-label/bootfs /mnt
		if grep -q "^\[default\]$" /mnt/autoboot.txt ; then
			sed ':start;N;s/^\[default\]\nboot_partition=2/[default]\nboot_partition=3/;t start;P;D' -i /mnt/autoboot.txt
		else
			sed -e "s#^boot_partition=2#boot_partition=3#" -i /mnt/autoboot.txt
		fi
		umount /dev/disk/by-label/bootfs
		# perform a reboot
		if /sbin/reboot 2>&1 | tee -a /data/reboot.log ; then
			# log success
			echo "$MY_ENV - stage complete - $(date)" | tee -a /data/reboot.log
			touch /data/ENV2-stage-complete
		else
			# log failure
			echo "$MY_ENV - could not perform reboot - $(date)" | tee -a /data/reboot.log
			touch /data/ENV2-could-not-perform-reboot
		fi
	elif grep -q "^ENV3" /etc/ssh/banner; then
		# set sane defaults for xinetd and udev
		mkdir -p /etc/xinetd.d/
		COUNT=0
		while [ $COUNT -lt 4 ]; do 
			cat >/etc/xinetd.d/p910${COUNT}d <<P910ND_TEMPLATE3
service p910${COUNT}d
{
        disable         = no
        socket_type     = stream
        protocol        = tcp
        port            = 910${COUNT}
        user            = root
        wait            = no
        server          = /usr/sbin/p910nd
        server_args     = -b -f /dev/persistent_lp/lp${COUNT}
}
P910ND_TEMPLATE3
			sed -e "\#910${COUNT}/tcp#d" -i /etc/services
			echo -e "p910${COUNT}d\t910${COUNT}/tcp\t# TCP RAW print service" >>/etc/services
			COUNT=$((COUNT+1))
		done
		cat > /etc/udev/rules.d/050_persistent_printer_mappings.rules <<UDEVRULES3
# persistent printer mapping via udev rules

# enable/disable debugging
#ENV{UDEV_PPM_DEBUG}="true"
ENV{UDEV_PPM_DEBUG}="false"

# skip everything if this ...
# ... is a device removal
ACTION=="remove", GOTO="persistent_printer_mappings_end"

# ... isn't a usbmisc (what used to be usblp) subsystem device
SUBSYSTEM!="usbmisc", GOTO="persistent_printer_mappings_end"

# ... isn't a printer-type device
SUBSYSTEMS=="usb", ATTRS{bInterfaceClass}!="07", GOTO="persistent_printer_mappings_end"

ENV{UDEV_PPM_DEBUG}=="true", RUN+="/usr/bin/logger '[UDEV-PPM-DEBUG] Printer detected! Attempting to determine which Pi model we are are running on ...'"

# Pi model detection starts here

# Pi4B detected, as ...
# ... this device has a PCIe platform of the 'fd500000.pcie' type
KERNELS=="*fd500000.pcie*", GOTO="switch_pi4b"
# ... has a 'scb' subsystem in its search path
KERNELS=="*scb*", GOTO="switch_pi4b"

# Pi3B+ detected, as it has a LAN7800 hub (vendor: 0424, product: 2514) in its USB tree
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0424", ATTRS{idProduct}=="2514", GOTO="switch_pi3b_plus"

# no better matches, so we're likely on a Pi3B or Pi1
GOTO="switch_pi3b"

# actual port assignments start here

# Pi4B
LABEL="switch_pi4b"
ENV{UDEV_PPM_DEBUG}=="true", RUN+="/usr/bin/logger '[UDEV-PPM-DEBUG] SWITCH: Pi4B detected!'"
KERNELS=="1-1.3:1.0", SYMLINK+="persistent_lp/lp0", RUN+="/usr/bin/logger '[UDEV-PPM] Pi4B: assigned lp0'", GOTO="persistent_printer_mappings_end"
KERNELS=="1-1.4:1.0", SYMLINK+="persistent_lp/lp1", RUN+="/usr/bin/logger '[UDEV-PPM] Pi4B: assigned lp1'", GOTO="persistent_printer_mappings_end"
KERNELS=="2-1:1.0", SYMLINK+="persistent_lp/lp2", RUN+="/usr/bin/logger '[UDEV-PPM] Pi4B: assigned lp2 (USB3)'", GOTO="persistent_printer_mappings_end"
KERNELS=="2-2:1.0", SYMLINK+="persistent_lp/lp3", RUN+="/usr/bin/logger '[UDEV-PPM] Pi4B: assigned lp3 (USB3)'", GOTO="persistent_printer_mappings_end"
KERNELS=="1-1.1:1.0", SYMLINK+="persistent_lp/lp2", RUN+="/usr/bin/logger '[UDEV-PPM] Pi4B: assigned lp2 (USB2)'", GOTO="persistent_printer_mappings_end"
KERNELS=="1-1.2:1.0", SYMLINK+="persistent_lp/lp3", RUN+="/usr/bin/logger '[UDEV-PPM] Pi4B: assigned lp3 (USB2)'", GOTO="persistent_printer_mappings_end"
GOTO="persistent_printer_mappings_end"

#Pi3B+
LABEL="switch_pi3b_plus"
ENV{UDEV_PPM_DEBUG}=="true", RUN+="/usr/bin/logger '[UDEV-PPM-DEBUG] SWITCH: Pi3B+ detected!'"
KERNELS=="1-1.1.2:1.0", SYMLINK+="persistent_lp/lp2", RUN+="/usr/bin/logger '[UDEV-PPM] Pi3B+: assigned lp2'", GOTO="persistent_printer_mappings_end"
KERNELS=="1-1.1.3:1.0", SYMLINK+="persistent_lp/lp3", RUN+="/usr/bin/logger '[UDEV-PPM] Pi3B+: assigned lp3'", GOTO="persistent_printer_mappings_end"
KERNELS=="1-1.3:1.0", SYMLINK+="persistent_lp/lp1", RUN+="/usr/bin/logger '[UDEV-PPM] Pi3B+: assigned lp1'", GOTO="persistent_printer_mappings_end"
KERNELS=="1-1.2:1.0", SYMLINK+="persistent_lp/lp0", RUN+="/usr/bin/logger '[UDEV-PPM] Pi3B+: assigned lp0'", GOTO="persistent_printer_mappings_end"
GOTO="persistent_printer_mappings_end"

#Pi3B/Pi1
LABEL="switch_pi3b"
ENV{UDEV_PPM_DEBUG}=="true", RUN="/usr/bin/logger '[UDEV-PPM-DEBUG] SWITCH: Pi3B/Pi1 detected!'"
KERNELS=="1-1.2:1.0", SYMLINK+="persistent_lp/lp0", RUN+="/usr/bin/logger '[UDEV-PPM] Pi3B/Pi1: assigned lp0'", GOTO="persistent_printer_mappings_end"
KERNELS=="1-1.3:1.0", SYMLINK+="persistent_lp/lp1", RUN+="/usr/bin/logger '[UDEV-PPM] Pi3B/Pi1: assigned lp1'", GOTO="persistent_printer_mappings_end"
KERNELS=="1-1.4:1.0", SYMLINK+="persistent_lp/lp2", RUN+="/usr/bin/logger '[UDEV-PPM] Pi3B: assigned lp2'", GOTO="persistent_printer_mappings_end"
KERNELS=="1-1.5:1.0", SYMLINK+="persistent_lp/lp3", RUN+="/usr/bin/logger '[UDEV-PPM] Pi3B: assigned lp3'", GOTO="persistent_printer_mappings_end"

# end of ruleset marker
LABEL="persistent_printer_mappings_end"
UDEVRULES3
		# as we already downloaded the required packages during the chroot phase, we can install p910nd without needing internet access
		apt-get install -y p910nd xinetd 2>&1 | tee -a /data/$MY_ENV-apt.log
		# now clean up apt, as we're done installing packages
		apt-get clean 2>&1 | tee -a /data/$MY_ENV-apt.log
		apt-get autopurge -y 2>&1 | tee -a /data/$MY_ENV-apt.log
		# set the boot partition for next boot 3->2 (as we're in ENV3, we need to mount ENV1's bootfs for that)
		mount /dev/disk/by-label/bootfs /mnt
		if grep -q "^\[default\]$" /mnt/autoboot.txt ; then
			sed ':start;N;s/^\[default\]\nboot_partition=3/[default]\nboot_partition=2/;t start;P;D' -i /mnt/autoboot.txt
		else
			sed -e "s#^boot_partition=3#boot_partition=2#" -i /mnt/autoboot.txt
		fi
		umount /dev/disk/by-label/bootfs
		# log success
		echo "$MY_ENV - stage complete - $(date)" | tee -a /data/reboot.log
		touch /data/ENV3-stage-complete
		# this line removes all lines below the one starting with ### begin-of-runonce ### from this autostart.sh file
		if sed '/^### begin-of-runonce ###/q' -i /data/autostart.sh ; then
			# log success
			echo "$MY_ENV - runonce removed - $(date)" | tee -a /data/reboot.log
			touch /data/ENV3-runonce-removed
			# cleanup unless we detected a failure
			if ! grep -q "FAILURE TO RUN" /data/reboot.log ; then
				rm /data/cloud-init-processes.log
				rm /data/setup.log
				for ENVFILE in /data/ENV?-stage-complete ; do
					if [ -f $ENVFILE ] && ! [ -s $ENVFILE ] ; then
						rm $ENVFILE
					fi
				done
			fi
			# perform a reboot
			/sbin/reboot 2>&1 | tee -a /data/reboot.log
			echo "$MY_ENV - reboot triggered - $(date)" | tee -a /data/reboot.log
		else
			# log failure
			echo "$MY_ENV - could not remove runonce - $(date)" | tee -a /data/reboot.log
			touch /data/ENV3-could-not-remove-runonce
		fi
	fi
fi
