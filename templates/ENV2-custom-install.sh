#!/bin/bash -e

# THIS SCRIPT WILL BE EXECUTED INSIDE THE CHANGEROOT, NO NEED TO CALL chroot HERE
echo "Downloading the 'p910nd' package into ENV2, so it can be installed later - even without internet access."
apt-get install -d -y p910nd
