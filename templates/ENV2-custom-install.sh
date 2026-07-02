#!/bin/bash -e

# THIS SCRIPT WILL BE EXECUTED INSIDE THE CHANGEROOT, NO NEED TO CALL chroot HERE
echo "Downloading the required packages into ENV2, so they can be installed later - even without internet access."
apt-get install -d -y xserver-xorg-video-fbdev xserver-xorg-input-libinput openbox tint2 x11-xserver-utils x11vnc network-manager-gnome xdotool coreutils eatmydata xbindkeys alsa-utils pulseaudio-utils pulseaudio chromium chromium-l10n chromium-sandbox xterm x2goclient x2gokdriveclient nodm
