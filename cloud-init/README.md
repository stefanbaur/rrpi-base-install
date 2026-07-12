# rpi-imager seems to make the following changes to the first partition

## cmdline.txt
Additional entry at end of line: `cfg80211.ieee80211_regdom=TWO_LETTER_COUNTRY_CODE_IN_ALL_CAPS_GOES_HERE`

## meta-data
### Original Content:
```
dsmode: local

instance_id: rpios-image
```

### After the imager had its way with it, only a single line is left:
```

instance-id: rpi-imager-xxxxxxxxxxxxx
```

where xxx... is a random numeric string.

## network-config
### Original Content:

merely commented-out lines and blank lines

### After the imager had its way with it, it looks like this:
```
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      dhcp6: true
      optional: true
  wifis:
    wlan0:
      dhcp4: true
      regulatory-domain: "TWO_LETTER_COUNTRY_CODE_IN_ALL_CAPS_GOES_HERE"
      access-points:
        "SSID_HERE":
          password: "ENCRYPTED_PASSPHRASE_STRING_GOES_HERE"
      optional: true
```

## user-data
### Original Content:

merely commented-out lines and blank lines

### After the imager had its way with it, it looks like this:
```
#cloud-config
manage_resolv_conf: false
hostname: HOSTNAME_GOES_HERE
manage_etc_hosts: true
packages:
- avahi-daemon
apt:
  preserve_sources_list: true
  conf: |
    Acquire {
      Check-Date "false";
    };
timezone: TIMEZONE_GOES_HERE
keyboard:
  model: pc105
  layout: "TWO_LETTER_COUNTRY_CODE_HERE"
users:
- name: USERNAME_GOES_HERE
  groups: users,adm,dialout,audio,netdev,video,plugdev,cdrom,games,input,gpio,spi,i2c,render,sudo
  shell: /bin/bash
  lock_passwd: false
  passwd: "ENCRYPTED_PASSWORD_STRING_GOES_HERE"
  ssh_authorized_keys:
    - SSH_PUBLIC_KEY_GOES_HERE
  sudo: ALL=(ALL) NOPASSWD:ALL
enable_ssh: true
ssh_pwauth: false
rpi:
  interfaces:
    serial: true
```

