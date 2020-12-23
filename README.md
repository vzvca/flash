# flash
Replace a running linux system using SSH.

This work is based on **takeover.sh** which does the hard part of the job.

Using this script, one can replace a running linux system using only an SSH connection. The remote user needs to be sudoer. It works by installing and starting a minimal linux system on a ramdisk and switching to it. From the ram hosted minimal linux, the remaining processes of the initial running system are killed, the HDD is unmounted, erased and the new fresh system is deployed on it.

The new fresh system is given as a tgz archive or as a raw image. It is sent to the ram hosted minimal linux using SSH. If the new system is a tgz archive a bootloader (extlinux) is installed, if given as a raw image it is supposed to have a bootloader installed.

Development was done on debian stretch/buster.

Why this ?? I needed a tool to deploy tgz root filesystems on running VMs to update the system deployed on them as part of a CI/CD pipeline. Formerly, the VM were updated using ansible but I needed to reinstall them from scratch. I did this for fun too and to understand how takeover.sh was working.

## Content of repository

Here is a small description of what's in the repository :

   * **fakeinit.c** : taken from **takeover.sh**. A compiled version needs to be included in the minimal linux system.
   * **restart.c** : a compiled version needs to be included in the minimal linux system. It is used to reboot once the new system has been installed.
   * **mkstubfs.sh** : a script to generate the minimal linux system as a tgz archive. This archive gets unpacked in a ramdisk.
   * **flash.sh** : the script that does the job.
   * **takeover.sh** : modified version of the famous **takeover.sh**.
   * **install.sh** : installs the new linux system
   * **mkrootfs.sh** : installs the ram hosted minimal linux system.
  
## Using the script

First the minimal linux system needs to be created. Run the following command which will create a file named stubfs.tgz

    mkstubfs.sh

Then run flash.sh

    flash.sh -t user@target -s stubfs.tgz -p toinstall.tgz
    
## Credits

Thanks to **takeover.sh** !


