#!/bin/bash -e
IFACENAME=uplink-wlan
/usr/sbin/wpa_cli -i ${IFACENAME} list_networks
read -p "Select number: " NUMBER
/usr/sbin/wpa_cli -i ${IFACENAME} select_network ${NUMBER//[!0-9]/}
sudo dhclient -v ${IFACENAME}
/usr/sbin/wpa_cli -i ${IFACENAME} list_networks
read -p "Press Enter when done."
