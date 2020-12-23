#! /bin/bash

# -- create ramdisk
mkdir -p /takeover
chmod 777 /takeover
mount -t tmpfs -o size=512m takeover /takeover

# -- extract rootfs to destination
exec tar -C /takeover -xvz
