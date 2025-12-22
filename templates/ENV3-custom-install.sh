#!/bin/bash -e

# THIS SCRIPT WILL BE EXECUTED INSIDE THE CHANGEROOT, NO NEED TO CALL chroot HERE
echo "Downloading the required packages into ENV3, so they can be installed later - even without internet access."
apt-get install -d -y openbox tint2 x11-xserver-utils feh x11vnc onboard network-manager-gnome libcamera-tools linphone-cli baresip-core chromium chromium-sandbox chromium-l10n xdotool coreutils eatmydata xbindkeys alsa-utils pulseaudio-utils espeak pulseaudio
