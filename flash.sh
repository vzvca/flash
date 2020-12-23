#! /bin/bash
# --------------------------------------------------------------------------
#   Reinstallation of a VM through SSH
#     TARGET  = remote machine
#     STUBFS  = small root file system to unpack in ramdisk - tgz format
#     PAYLOAD = raw image
# --------------------------------------------------------------------------
set -e

TARGET=$1
STUBFS=$2
PAYLOAD=$3

# 0- copy SSH key to remote system
ssh-copy-id  -i ~/.ssh/id_rsa.pub ${TARGET}

# 1- copy scripts to remote computer
scp  -p takeover.sh mkrootfs.sh ${TARGET}:/tmp/
ssh ${TARGET} sudo cp /tmp/takeover.sh /usr/local/bin/
ssh ${TARGET} sudo cp /tmp/mkrootfs.sh /usr/local/bin/

# 2 - make ramdisk with minimal filesystem
cat ${STUBFS} | ssh ${TARGET} sudo /usr/local/bin/mkrootfs.sh

# 3 - switch to ramdisk on remote system
ssh -t ${TARGET} sudo /usr/local/bin/takeover.sh

# 4 - remote system is now up. Time to deploy payload
#     payload is expected to be .tgz
#     9438 is the magic port of secondary ssh
scp -i ./ssh/flash_key -o "StrictHostKeyChecking=no" -P 9438 -p install.sh root@${TARGET}:/tmp/install.sh
cat ${PAYLOAD} | ssh -i ./ssh/flash_key -o "StrictHostKeyChecking=no" -p 9438 root@${TARGET} /tmp/install.sh -d /dev/sda -a dummy
ssh -i ./ssh/flash_key -o "StrictHostKeyChecking=no" -p 9438 root@${TARGET} '{ sleep 1; /restart; } > /dev/null &'
exit 0
