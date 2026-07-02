#!/bin/bash -e

# THIS SCRIPT WILL BE EXECUTED INSIDE THE CHANGEROOT, NO NEED TO CALL chroot HERE
echo "Downloading the bridge-utils, dnsmasq, and nftables packages into ENV3, so it can be installed later - even without internet access."
apt-get install -d -y bridge-utils dnsmasq nftables
