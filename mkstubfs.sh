#! /bin/bash

set -e

ROOTDIR=/tmp/takeover

die ()
{
    echo $1
    exit 1
}

[[ $(id -u) == 0 ]] || die "You must be root to run this script !"

# -- create workspace
mkdir -p ${ROOTDIR}
chmod 777 ${ROOTDIR}
mount -t tmpfs -o size=512m takeover ${ROOTDIR}

# -- build minimal system
debootstrap --variant=minbase stretch ${ROOTDIR}

# -- add extra binaries
chroot ${ROOTDIR}/ apt-get install -y openssh-server busybox-static tcl extlinux syslinux-common parted udev
cp ${ROOTDIR}/bin/busybox ${ROOTDIR}

# -- add custom binaries
gcc -static fakeinit.c -o fakeinit
gcc -static restart.c -o restart
mv -f fakeinit restart ${ROOTDIR}/

# -- SSH configuration
# -- SSH server will listen on port 9438 
mkdir -p ${ROOTDIR}/run/sshd
cp etc/ssh/sshd_config ${ROOTDIR}/etc/ssh
mkdir -p ${ROOTDIR}/root/.ssh
chmod go-rwx ${ROOTDIR}/root/.ssh
cp ssh/flash_key.pub ${ROOTDIR}/root/.ssh/authorized_keys

# -- cleanup
find ${ROOTDIR}/var/cache/apt/archives/ -name "*.deb" -delete

# -- store result
tar -C ${ROOTDIR} --numeric-owner -czvf stubfs.tgz .

# -- cleanup
umount ${ROOTDIR}
rmdir ${ROOTDIR}

