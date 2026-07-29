#!/bin/bash -e

# THIS SCRIPT WILL BE EXECUTED INSIDE THE CHANGEROOT, NO NEED TO CALL chroot HERE
apt-get install -d -y hostapd bridge-utils rfkill
