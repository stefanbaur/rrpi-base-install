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
	# remove cloud-init
	apt-get purge cloud-init -y 2>&1 | tee -a /data/$MY_ENV-apt.log
	# do not use apt-get autopurge -y or apt-get clean here, or you might wipe the overlayfs packages we already downloaded during the chroot phase
	# enable overlay file system
	raspi-config nonint enable_overlayfs 2>&1 | tee -a /data/$MY_ENV-apt.log
	# make sure /data is not affected by overlayfs
	sed -e "s#overlayroot=tmpfs #overlayroot=tmpfs:recurse=0 #" -i /boot/firmware/cmdline.txt

	# the following blocks are ENV-specific
	if grep -q "^ENV1" /etc/ssh/banner; then
		# now clean up apt, as we're in ENV1 and don't want to install any extra packages here
		apt-get clean 2>&1 | tee -a /data/$MY_ENV-apt.log
		apt-get autopurge -y 2>&1 | tee -a /data/$MY_ENV-apt.log

		# remove x2go user pubkeys from ENV1, as we are not creating x2go users here
		rm -rf /root/pubkeys

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
		# as we already downloaded the required packages during the chroot phase, we can install all required packages without needing internet access
		apt-get install -y x2goserver x2goserver-xsession x2goserver-x2gokdrive xserver-x2gokdrive lxde firefox-esr firefox-esr-l10n-de chromium chromium-l10n chromium-sandbox libreoffice libreoffice-l10n-de 2>&1 | tee /data/$MY_ENV-apt.log
		# now clean up apt, as we're done installing packages
		apt-get clean 2>&1 | tee -a /data/$MY_ENV-apt.log
		apt-get autopurge -y 2>&1 | tee -a /data/$MY_ENV-apt.log

		# add x2go users
		/usr/sbin/useradd -b /home/ -p '!' -m -U -s /bin/bash user1
		/usr/sbin/useradd -b /home/ -p '!' -m -U -s /bin/bash user2

		# add x2go users to additional groups
		for X2GOUSER in user1 user2; do
			for USERGROUP in dialout cdrom audio video plugdev games users input render; do
				/usr/sbin/adduser $X2GOUSER $USERGROUP
			done
		done

		# create .ssh directories and move pubkeys
		mkdir -p /home/user{1,2}/.ssh
		mv /root/pubkeys/user1/*.pub /home/user1/.ssh/authorized_keys
		mv /root/pubkeys/user2/*.pub /home/user2/.ssh/authorized_keys
		rm -rf /root/pubkeys

		# set proper permissions and ownership
		chmod 700 /home/user{1,2}/.ssh
		chmod 600 /home/user{1,2}/.ssh/authorized_keys
		chown -R user1:user1 /home/user1
		chown -R user2:user2 /home/user2
		# create bind-mount destinations, if not already present
		mkdir -p /data/${MY_ENV}/home/user{1,2}

		# move /home/user? contents to new mountpoints
		mv /home/user1 /data/${MY_ENV}/home/
		mv /home/user2 /data/${MY_ENV}/home/

		# recreate original directories
		mkdir -p /home/user{1,2}
		chmod 700 /home/user{1,2}

		# re-set ownership for newly recreated directories
		chown -R user1:user1 /home/user1
		chown -R user2:user2 /home/user2

		# manually bind-mount the new destinations for now
		mount --bind /data/${MY_ENV}/home/user1 /home/user1
		mount --bind /data/${MY_ENV}/home/user1 /home/user1

		# add bindmounts to fstab
		grep "^/data/${MY_ENV}/home/user1" || echo -e "/data/${MY_ENV}/home/user1\t/home/user1\tnone\tdefaults,bind\t0\t1" >> /etc/fstab
		grep "^/data/${MY_ENV}/home/user2" || echo -e "/data/${MY_ENV}/home/user2\t/home/user2\tnone\tdefaults,bind\t0\t1" >> /etc/fstab

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
		# as we already downloaded the required packages during the chroot phase, we can install all required packages without needing internet access
		apt-get install -y x2goserver x2goserver-xsession x2goserver-x2gokdrive xserver-x2gokdrive lxde firefox-esr firefox-esr-l10n-de chromium chromium-l10n chromium-sandbox libreoffice libreoffice-l10n-de 2>&1 | tee /data/$MY_ENV-apt.log
		# now clean up apt, as we're done installing packages
		apt-get clean 2>&1 | tee -a /data/$MY_ENV-apt.log
		apt-get autopurge -y 2>&1 | tee -a /data/$MY_ENV-apt.log

		# add x2go users
		/usr/sbin/useradd -b /home/ -p '!' -m -U -s /bin/bash user1
		/usr/sbin/useradd -b /home/ -p '!' -m -U -s /bin/bash user2

		# add x2go users to additional groups
		for X2GOUSER in user1 user2; do
			for USERGROUP in dialout cdrom audio video plugdev games users input render; do
				/usr/sbin/adduser $X2GOUSER $USERGROUP
			done
		done

		# create .ssh directories and move pubkeys
		mkdir -p /home/user{1,2}/.ssh
		mv /root/pubkeys/user1/*.pub /home/user1/.ssh/authorized_keys
		mv /root/pubkeys/user2/*.pub /home/user2/.ssh/authorized_keys
		rm -rf /root/pubkeys

		# set proper permissions and ownership
		chmod 700 /home/user{1,2}/.ssh
		chmod 600 /home/user{1,2}/.ssh/authorized_keys
		chown -R user1:user1 /home/user1
		chown -R user2:user2 /home/user2
		# create bind-mount destinations, if not already present
		mkdir -p /data/${MY_ENV}/home/user{1,2}

		# move /home/user? contents to new mountpoints
		mv /home/user1 /data/${MY_ENV}/home/
		mv /home/user2 /data/${MY_ENV}/home/

		# recreate original directories
		mkdir -p /home/user{1,2}
		chmod 700 /home/user{1,2}

		# re-set ownership for newly recreated directories
		chown -R user1:user1 /home/user1
		chown -R user2:user2 /home/user2

		# manually bind-mount the new destinations for now
		mount --bind /data/${MY_ENV}/home/user1 /home/user1
		mount --bind /data/${MY_ENV}/home/user1 /home/user1

		# add bindmounts to fstab
		grep "^/data/${MY_ENV}/home/user1" || echo -e "/data/${MY_ENV}/home/user1\t/home/user1\tnone\tdefaults,bind\t0\t1" >> /etc/fstab
		grep "^/data/${MY_ENV}/home/user2" || echo -e "/data/${MY_ENV}/home/user2\t/home/user2\tnone\tdefaults,bind\t0\t1" >> /etc/fstab

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
