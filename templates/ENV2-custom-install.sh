#!/bin/bash -e

# THIS SCRIPT WILL BE EXECUTED INSIDE THE CHANGEROOT, NO NEED TO CALL chroot HERE
echo "Downloading the required packages into ENV2, so they can be installed later - even without internet access."
apt-get install -d -y openbox tint2 x11-xserver-utils x11vnc network-manager-gnome xdotool coreutils eatmydata xbindkeys alsa-utils pulseaudio-utils pulseaudio x2golient x2gokdriveclient nodm 
