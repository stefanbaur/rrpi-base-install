
# Prerequisites:
  - A Debian Bookworm system (or newer) - derivatives like Devuan and Ubuntu should work, too, as long as they are at least based on Debian Bookworm
  - A microSD card or USB flash memory stick, or a Compute Module with onboard eMMC flash, at least 32 GB in size
  - Approximately 15 GB free space in a temporary directory (defaults to `/tmp` but can be overridden in a `base_install_custom.conf` file)
  - The rpi-imager tool (which can be downloaded from `https://github.com/raspberrypi/rpi-imager/releases/` - please use at least version 2.0.2, either as AppImage or `*.deb`)
  - **Only when using a Compute Module with onboard eMMC flash:**
    - Connect the CM to the CM baseboard, if you have not already done so
    - Execute the following commands *once* to prepare the connection:\
      `sudo apt install git make gcc pkg-config libusb-1.0-0-dev`\
      `git clone --depth=1 https://github.com/raspberrypi/usbboot`\
      `cd usbboot`\
      `make`
    - Keep your shell open in this directory
    - Whenever the instructions below prompt you to connect/(re)insert your media:
      - run the command `sudo ./rpiboot`
      - make sure the jumper/switch on your baseboard is in the proper position for flashing the eMMC
      - plug the USB cable into the baseboard, then into the host
      - watch the messages in the console window - if it's throwing errors and/or the connection seems unstable/your image writing process ends prematurely, try `sudo ./rpiboot -d mass-storage-gadget64`
# Required steps:
  - connect your media (microSD card/USB flash stick) to your computer
  - Make sure you are either using "pristine" media straight out of the original packaging, or wipe the entire media with zeroes - else `base_install.sh` might detect traces of previous partitions/file systems on it and abort.
  - Start rpi-imager:
    - When using the AppImage:
      - Don't forget you need to run `chmod +x imager_name_here.AppImage` first!
      - `sudo imager_name_here.AppImage`
    - When using a `*.deb` package:
      - `sudo apt install ./file_name_here.deb`
      - `sudo rpi-imager`
  - Follow our [imager setup instructions](./rpi-imager-2.0.x-manual/README.md "Instructions")
  - Remove the removable media and re-insert it after a good 10-15 seconds, if you haven't already done so (if you are using a CM with onboard eMMC flash, this means you need to re-run `sudo ./rpiboot`, as explained above)
  - Review the default settings in `base_install.conf`, if you need to make any changes, save them as `base_install_custom.conf` so they won't get overwritten by a `git pull`
  - Review the templates in the `templates` folder; if you need to make any changes, save them in the `custom` folder so they won't get overwritten by a `git pull`
  - Run `sudo ./base_install.sh 2>&1 | tee base_install.log`
  - When `base_install.sh` has finished its work, remove the media (in case of a CM with onboard eMMC flash, remove the USB cable and don't forget to move the jumper/switch back to the default, non-flashing position) and boot your Pi from it (note that it will reboot several times until the installation is complete)

# Result
  - The above steps, combined with the `base_install.sh` script in this directory, will set you up with three boot environments you can choose from.
  - These environments are called ENV1, ENV2, and ENV3:
    - ENV1 uses the first partition as /boot/firmware and the fifth partition as /
    - ENV2 uses the second partition as /boot/firmware and the sixth partition as /
    - ENV3 uses the third partition as /boot/firmware and the seventh partition as /
    - All three environments share the eight partition as /data, so you can transfer data between them by saving it to /data and rebooting to a different environment
  - You can switch between the three environments by running `sudo reboot n`, where n is a number between 1 and 3.
  - The default partition is set in the file `autoboot.txt` located on the first partition.
  - The idea behind this approach is that you leave ENV1 as a minimal installation, from which you can service/repair the other two.
  - In ENV2 and ENV3, you can install all the applications your users need:
    - Whenever you need to apply updates, do so in the environment that is currently not active, check if there were any errors, and if not, reboot into the other environment.
    - Once in the other environment, you can either set it to be the default until the next update, or apply the updates again to the now inactive environment.
  - You will need to apply updates to ENV1 as well, but hopefully, due to the minimal installation there, updates should occur way less frequently than in the other two environments.

# Customization
Please see the `README.md` files in the folders `templates` and `custom` for details on how to add your own packages and scripts.
If you're still confused:
1. Check out the branch `example`, where you can find four harmless, silly little example scripts.
2. Build an image based on the `example` branch, and boot it on the Pi. It will cycle through several reboots, starting with ENV1 (twice), ENV2 (twice), ENV3 (twice), and finally reboot a last time to settle in ENV2.
3. In ENV2, log in using the account data you provided in the rpi-image and try executing `sl` (a deliberate misspelling of `ls`).
4. Switch to ENV3, using the command `sudo reboot 3`
5. In ENV3, repeat step 3.
6. Switch to ENV1, using the command `sudo reboot 1`
7. Try repeating step 3 here - the expected result is a `command not found`.
8. Examine the files `templates/ENV*` and finally `templates/autostart.sh` in the `example` branch (not on the Pi, as `autostart.sh` is self-modifying), and you should have an epiphany.

Shield: [![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

This work is licensed under the [GNU Public License, Version 3.0](https://www.gnu.org/licenses/gpl-3.0)
