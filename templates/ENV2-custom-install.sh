#!/bin/bash -e

# THIS SCRIPT WILL BE EXECUTED INSIDE THE CHANGEROOT, NO NEED TO CALL chroot HERE
echo "Downloading the required packages into ENV2, so they can be installed later - even without internet access."
apt-get install -d -y git openssl curl gawk coreutils grep jq docker.io docker-compose
