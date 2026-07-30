# This branch has two instances of hostapd.conf and cfg80211.conf
 - one in ENV2 (`/data/ENV2/hostapd/hostapd.conf` and `/data/ENV2/modprobe.d/cfg80211.conf`)
 - one in ENV3 (`/data/ENV3/hostapd/hostapd.conf` and `/data/ENV3/modprobe.d/cfg80211.conf`)
These environments **do not** share their configuration! If you want to make changes after the initial setup, you are responsible for applying your changes to both ENVs!

Also, ENV1 **does not** include the packages required to run the Pi in accesspoint mode, it is only for maintenance!

# Defaults
A lowest-common-denominator default is stored in the file `./base_install_branch_specific.conf`. It is strongly suggested to permanently override the defaults (especially regarding the country code and the wifi password) by copying the file to `./base_install_branch_specific_custom.conf` - this will never be overwritten by a `git pull`.
