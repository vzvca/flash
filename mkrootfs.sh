#! /bin/bash

# -- create ramdisk
mkdir -p /takeover
chmod 777 /takeover
mount -t tmpfs -o size=512m takeover /takeover

# -- extract rootfs to destination
exec tar -C /takeover -xvz

# -- copy authorized_keys from current user to 
#mkdir -p /takeover/root/.ssh
#chmod ugo-rwx /takeover/root/.ssh
#cp /home/.ssh/authorized_keys /takeover/root/.ssh/
