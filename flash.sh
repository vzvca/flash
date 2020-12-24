#! /bin/bash
# --------------------------------------------------------------------------
#   Reinstallation of a VM through SSH
#     TARGET  = remote machine
#     STUBFS  = small root file system to unpack in ramdisk - tgz format
#     PAYLOAD = raw image
# --------------------------------------------------------------------------
set -e

usage ()
{
    echo $0 error: $1
    echo "      " $0 "-s stubfs.tgz -p payload.tgz -t user@remote"
    echo "         -s stubfs.tgz : minimal linux rootfs"
    echo "         -p payload.img or payload.tgz : system to install"
    echo "         -t user@remote : machine to install through SSH"
    exit 1
}

if [[ $# != 6 ]] ; then
    usage "Bad number of arguments"
fi

while getopts "s:p:t:" OPTION; do
    case $OPTION in
    s)
        STUBFS=$OPTARG
        ;;
    p)
        PAYLOAD=$OPTARG
        ;;
    t)
        TARGET=$OPTARG
        ;;
    *)
        exit 1
        ;;
    esac
done

[[ -z $PAYLOAD ]] && usage "Missing payload"
[[ -z $STUBFS  ]] && usage "Missing stubfs"
[[ -z $TARGET  ]] && usage "Missing stubfs"

TARGETMACH=$(echo $TARGET | awk 'BEGIN{FS="@"} {print $NF}')

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
scp -i ./ssh/flash_key -o "StrictHostKeyChecking=no" -P 9438 -p install.sh root@${TARGETMACH}:/tmp/install.sh
cat ${PAYLOAD} | ssh -i ./ssh/flash_key -o "StrictHostKeyChecking=no" -p 9438 root@${TARGETMACH} /tmp/install.sh -d /dev/sda -f tgz
ssh -i ./ssh/flash_key -o "StrictHostKeyChecking=no" -p 9438 root@${TARGETMACH} '{ sleep 1; /restart; } > /dev/null &'
exit 0
