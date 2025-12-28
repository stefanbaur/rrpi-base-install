#!/bin/bash

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
MY_ENV_NUMBER=$(sed -e 's/^ENV([1-3]).*$/$1/' /etc/ssh/banner)

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
		# as we already downloaded the required packages during the chroot phase, we can install these without needing internet access
		apt-get install -y bind9-host git openssl curl gawk coreutils grep jq docker.io docker-compose 2>&1 | tee /data/$MY_ENV-apt.log
		# create bind-mount destinations, if not already present
		mkdir -p /data/ENV2/opt /data/ENV2/var/lib/containerd /data/ENV2/var/lib/docker
		# stop affected services
		service docker stop
		service containerd stop
		# move /opt, /var/lib/containerd, and /var/lib/docker contents to new mountpoints
		mv /opt/* /data/ENV2/opt/
		mv /var/lib/containerd/* /data/ENV2/var/lib/containerd/
		mv /var/lib/docker/* /data/ENV2/var/lib/docker/
		# manually bind-mount the new destinations for now
		mount --bind /data/ENV2/opt/ /opt/
		mount --bind /data/ENV2/var/lib/containerd/ /var/lib/containerd/
		mount --bind /data/ENV2/var/lib/docker/ /var/lib/docker/
		# add bindmounts to fstab
		grep "^/data/ENV2/opt" || echo -e "/data/ENV2/opt\t/opt\tnone\tdefaults,bind\t0\t1" >> /etc/fstab
		grep "^/data/ENV2/var/lib/containerd" || echo -e "/data/ENV2/var/lib/containerd\t/var/lib/containerd\tnone\tdefaults,bind\t0\t1" >> /etc/fstab
		grep "^/data/ENV2/var/lib/docker" || echo -e "/data/ENV2/var/lib/docker\t/var/lib/docker\tnone\tdefaults,bind\t0\t1" >> /etc/fstab
		# start affected services again
		service containerd start
		service docker start
		# this is straight from the mailcow-dockerized installation instructions
		umask 0022
		cd /opt
		git clone https://github.com/mailcow/mailcow-dockerized
		cd mailcow-dockerized
		# set environment variables to make ./generate_config.sh non-interactive
		if hostname -f | grep -q "\." ; then
			export MAILCOW_HOSTNAME=$(hostname -f)
		else
			export MAILCOW_HOSTNAME=$(host $(hostname -s) | awk '{print $1}' | head -n 1)
			while ! echo "$MAILCOW_HOSTNAME" | grep -q "\." ; do
				echo "No FQDN set for this IP. Please fix your DNS."
				echo "Waiting here until your DNS change has propagated ..."
				sleep 30
				export MAILCOW_HOSTNAME=$(host $(hostname -s) | awk '{print $1}' | head -n 1)
			done
		fi
		if [ -a /etc/timezone ]; then
			export MAILCOW_TZ=$(cat /etc/timezone)
		elif [ -a /etc/localtime ]; then
			export MAILCOW_TZ=$(readlink /etc/localtime|sed -n 's|^.*zoneinfo/||p')
		fi
		MEM_TOTAL=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
		[ "${MEM_TOTAL}" -le "2621440" ] && export SKIP_CLAMD="y"
		export SKIP_BRANCH="n"
		export MAILCOW_BRANCH="master"
		# generate the config
		./generate_config.sh
		# run all things docker
		docker compose pull
		docker compose up -d
		echo "PLEASE FIND YOUR MAILCOW LOGIN DATA FOR ENV2 BELOW" > /data/mailcow-login.txt
		echo "Assuming there were no errors, you should be able to log in as:" | tee -a /data/mailcow-login.txt
		echo "Account name: 'admin'" | tee -a /data/mailcow-login.txt
		echo "Password: 'moohoo'" | tee -a /data/mailcow-login.txt 
		echo "URL to point your webbrowser at: https://${MAILCOW_HOSTNAME}/admin" | tee -a /data/mailcow-login.txt
		echo "Note that you will receive a browser warning as long as you do not set up proper SSL certificates (use LetsEncrypt, for example)." | tee -a /data/mailcow-login.txt
		echo "The above is the configuration when booted in ENV2. It may vary for ENV3." | tee -a /data/mailcow-login.txt
		echo "(see below)" >> /data/mailcow-login.txt
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
		# as we already downloaded the required packages during the chroot phase, we can install these without needing internet access
		apt-get install -y bind9-host git openssl curl gawk coreutils grep jq docker.io docker-compose 2>&1 | tee /data/$MY_ENV-apt.log
		# create bind-mount destinations, if not already present
		mkdir -p /data/ENV3/opt /data/ENV3/var/lib/containerd /data/ENV3/var/lib/docker
		# stop affected services
		service docker stop
		service containerd stop
		# move /opt, /var/lib/containerd, and /var/lib/docker contents to new mountpoints
		mv /opt/* /data/ENV3/opt/
		mv /var/lib/containerd/* /data/ENV3/var/lib/containerd/
		mv /var/lib/docker/* /data/ENV3/var/lib/docker/
		# manually bind-mount the new destinations for now
		mount --bind /data/ENV3/opt/ /opt/
		mount --bind /data/ENV3/var/lib/containerd/ /var/lib/containerd/
		mount --bind /data/ENV3/var/lib/docker/ /var/lib/docker/
		# add bindmounts to fstab
		grep "^/data/ENV3/opt" || echo -e "/data/ENV3/opt\t/opt\tnone\tdefaults,bind\t0\t1" >> /etc/fstab
		grep "^/data/ENV3/var/lib/containerd" || echo -e "/data/ENV3/var/lib/containerd\t/var/lib/containerd\tnone\tdefaults,bind\t0\t1" >> /etc/fstab
		grep "^/data/ENV3/var/lib/docker" || echo -e "/data/ENV3/var/lib/docker\t/var/lib/docker\tnone\tdefaults,bind\t0\t1" >> /etc/fstab
		# start affected services again
		service containerd start
		service docker start
		# this is straight from the mailcow-dockerized installation instructions
		umask 0022
		cd /opt
		git clone https://github.com/mailcow/mailcow-dockerized
		cd mailcow-dockerized
		# set environment variables to make ./generate_config.sh non-interactive
		if hostname -f | grep -q "\." ; then
			export MAILCOW_HOSTNAME=$(hostname -f)
		else
			export MAILCOW_HOSTNAME=$(host $(hostname -s) | awk '{print $1}' | head -n 1)
			while ! echo "$MAILCOW_HOSTNAME" | grep -q "\." ; do
				echo "No FQDN set for this IP. Please fix your DNS."
				echo "Waiting here until your DNS change has propagated ..."
				sleep 30
				export MAILCOW_HOSTNAME=$(host $(hostname -s) | awk '{print $1}' | head -n 1)
			done
		fi
		if [ -a /etc/timezone ]; then
			export MAILCOW_TZ=$(cat /etc/timezone)
		elif [ -a /etc/localtime ]; then
			export MAILCOW_TZ=$(readlink /etc/localtime|sed -n 's|^.*zoneinfo/||p')
		fi
		MEM_TOTAL=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
		[ "${MEM_TOTAL}" -le "2621440" ] && export SKIP_CLAMD="y"
		export SKIP_BRANCH="n"
		export MAILCOW_BRANCH="master"
		# generate the config
		./generate_config.sh
		# run all things docker
		docker compose pull
		docker compose up -d
		echo "PLEASE FIND YOUR MAILCOW LOGIN DATA FOR ENV3 BELOW" >> /data/mailcow-login.txt
		echo "Assuming there were no errors, you should be able to log in as:" | tee -a /data/mailcow-login.txt
		echo "Account name: 'admin'" | tee -a /data/mailcow-login.txt
		echo "Password: 'moohoo'" | tee -a /data/mailcow-login.txt 
		echo "URL to point your webbrowser at: https://${MAILCOW_HOSTNAME}/admin" | tee -a /data/mailcow-login.txt
		echo "Note that you will receive a browser warning as long as you do not set up proper SSL certificates (use LetsEncrypt, for example)." | tee -a /data/mailcow-login.txt
		echo "The above is the configuration when booted in ENV3. It may vary for ENV2." | tee -a /data/mailcow-login.txt
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
