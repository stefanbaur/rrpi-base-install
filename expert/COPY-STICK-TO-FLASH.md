
# Expert Task: Copying a Stick Image to (smaller) eMMC Flash Memory
  - You might find yourself in the situation that applying the rrpi script to a CM4 eMMC flash does not work properly, even when using the alternative usbboot/rpiboot method involving the mass-storage-gadget64 mode.
  - In that case, you might want to use a fast, reliable USB stick or other USB storage media to prepare everything, and dd the result over to the eMMC once you're done. Writing a continuous data stream using dd seems to work more reliably than a lot of single file writes.
  - However, your USB media will likely be larger than the eMMC flash you will be writing to.
  - This means we need to make some changes so the partition table and file system sizes will fit on your eMMC flash:
    - The easiest way to determine the proper sizes is to do some math and apply some trickery beforehand.
    - Mount your pristine eMMC flash media and check the total size using e.g. cfdisk.
    - For 8GB:
      - You will need to perform the additional steps outlined in [CREATE-8G-IMAGE.md](./CREATE-8G-IMAGE.md) - everything below WILL NOT WORK FOR YOU unless you ALSO perform the steps outlined there.
      - Set `OVERRIDE_ROOTFS_MAXSIZE="1900M"` in `base_install.conf` or `base_install_custom.conf`
      - Set `OVERRIDE_DATA_MAXSIZE="200M"` in `base_install.conf` or `base_install_custom.conf`
    - For 16GB:
      - Set `OVERRIDE_ROOTFS_MAXSIZE="4G"` in `base_install.conf` or `base_install_custom.conf`
      - Set `OVERRIDE_DATA_MAXSIZE="2G"` in `base_install.conf` or `base_install_custom.conf`
    - For 32GB:
      - You do not need to set `OVERRIDE_ROOTFS_MAXSIZE`.
      - Set `OVERRIDE_DATA_MAXSIZE="6G"` in `base_install.conf` or `base_install_custom.conf`

    - While in the rrpi repository's expert directory, and with the eMMC flash still available as `/dev/your-eMMC-flash`, run the following command (change `/dev/your-eMMC-flash` to whatever your eMMC flash device's name is): `sudo create-partition-layout.sh /dev/your-eMMC-flash`
    - Now remove your eMMC flash for the time being, write the original Raspberry Pi OS Lite image to the USB media, and run `sudo base_install.sh` on the USB media.
    - Once the script has finished:
      - Plug your eMMC flash in again and run the rpiboot/usbboot tool
      - Run `sudo dd if=/dev/your-USB-media of=/dev/your-eMMC-flash bs=4M status=progress` (note that this will error out if your USB media is larger than your eMMC flash; this is to be expected and can be ignored)
      - Run `cat ./custom/partitions.txt | sudo sfdisk /dev/your-eMMC-flash` (this should restore the proper extended partition size setting while keeping your partitions intact)
      - Run `echo "," | sudo sfdisk -N 8 /dev/your-eMMC-flash && fsck.ext4 -f /dev/your-eMMC-flash && resize2fs /dev/your-eMMC-flash` to use the maximum available space for your data partition.
