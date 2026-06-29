#!/bin/bash -e

# THIS SCRIPT WILL BE EXECUTED INSIDE THE CHANGEROOT, NO NEED TO CALL chroot HERE
echo "Downloading all required packages into ENV2, so it can be installed later - even without internet access."
apt-get install -d -y x2goserver x2goserver-xsession x2goserver-x2gokdrive xserver-x2gokdrive lxde firefox-esr firefox-esr-l10n-de chromium chromium-l10n chromium-sandbox libreoffice libreoffice-l10n-de
