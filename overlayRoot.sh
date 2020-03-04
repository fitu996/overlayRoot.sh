#!/bin/sh
#  Read-only Root-FS for most linux distributions using overlayfs
#  Version 1.3
#
#  Version History:
#  1.0: initial release
#  1.1: adopted new fstab style with PARTUUID. the script will now look for a /dev/xyz definiton first 
#       (old raspbian), if that is not found, it will look for a partition with LABEL=rootfs, if that
#       is not found it look for a PARTUUID string in fstab for / and convert that to a device name
#       using the blkid command. 
#  1.2: clean useless lines in fstab before read it. do not mount /proc if already mounted. some fixes to
#       fit other distributions. reformat the script to a more simple style.
#  1.3: add support for UUID in fstab. deprecated PARTUUID support because it's not safe to handle every
#       circumstances. rename /ro to /lower and /rw to /overlay. fix permission issue on /overlay.
#
#  Created 2017 by Pascal Suter @ DALCO AG, Switzerland to work on Raspian as custom init script
#  (raspbian does not use an initramfs on boot)
#  Update 1.2 and 1.3 by fitu996@github
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see
#    <http://www.gnu.org/licenses/>.
#
#
#  Tested with Raspbian mini, 2018-10-09
#
#  This script will mount the root filesystem read-only and overlay it with a temporary tempfs 
#  which is read-write mounted. This is done using the overlayFS which is part of the linux kernel 
#  since version 3.18. 
#  when this script is in use, all changes made to anywhere in the root filesystem mount will be lost 
#  upon reboot of the system. The SD card will only be accessed as read-only drive, which significantly
#  helps to prolong its life and prevent filesystem coruption in environments where the system is usually
#  not shut down properly 
#
#  Install: 
#  copy this script to /sbin/overlayRoot.sh, make it executable and add "init=/sbin/overlayRoot.sh" to the 
#  cmdline.txt file in the raspbian image's boot partition. 
#  I strongly recommend to disable swapping before using this. it will work with swap but that just does 
#  not make sens as the swap file will be stored in the tempfs which again resides in the ram.
#  run these commands on the booted raspberry pi BEFORE you set the init=/sbin/overlayRoot.sh boot option:
#  sudo dphys-swapfile swapoff
#  sudo dphys-swapfile uninstall
#  sudo update-rc.d dphys-swapfile remove
#
#  To install software, run upgrades and do other changes to the raspberry setup, simply remove the init= 
#  entry from the cmdline.txt file and reboot, make the changes, add the init= entry and reboot once more. 

echo "[overlayRoot.sh]" "setting up overlayFS to /"

fail(){
        echo "[overlayRoot.sh]" "$1"
        echo "[overlayRoot.sh]" 'there is something wrong with overlayRoot.sh. type "exit" and press enter to ignore and continue.'
        if ! /bin/bash ; then
            exit 1
        fi
}

# mount /proc
if ! mount | grep -x 'proc on /proc type proc.*' > /dev/null ; then
    mount -t proc proc /proc || \
        fail "ERROR: could not mount proc"
fi
# check if overlayRoot is needed
for x in $(cat /proc/cmdline); do
    if [ "x$x" = "xnoOverlayRoot" ] ; then
        exec /sbin/init "$@"
    fi
done
# test overlayFS compatibility
modprobe overlay || true
mount -t tmpfs none /mnt || fail "ERROR: kernel missing tmpfs functionality"
mkdir -p /mnt/lower /mnt/overlay/upper /mnt/overlay/work /mnt/newroot
mount -t overlay -o lowerdir=/mnt/lower,upperdir=/mnt/overlay/upper,workdir=/mnt/overlay/work overlayfs-root /mnt/newroot || \
    fail "ERROR: kernel missing overlay functionality"
umount /mnt/newroot
umount /mnt
# create a writable fs to then create our mountpoints 
mount -t tmpfs inittemp /mnt || \
    fail "ERROR: could not create a temporary filesystem to mount the base filesystems for overlayfs"
mkdir /mnt/lower
mkdir /mnt/overlay
mount -t tmpfs root-rw /mnt/overlay || \
    fail "ERROR: could not create tempfs for upper filesystem"
mkdir /mnt/overlay/upper
mkdir /mnt/overlay/work
mkdir /mnt/newroot
# mount root filesystem readonly 
rootDev="`grep -v -x -E '^(#.*)|([[:space:]]*)$' /etc/fstab | awk '$2 == "/" {print $1}'`"
rootMountOpt="`grep -v -x -E '^(#.*)|([[:space:]]*)$' /etc/fstab | awk '$2 == "/" {print $4}'`"
rootFsType="`grep -v -x -E '^(#.*)|([[:space:]]*)$' /etc/fstab | awk '$2 == "/" {print $3}'`"
echo "[overlayRoot.sh]" "check if we can locate the root device based on fstab"
if ! blkid $rootDev ; then
    echo "[overlayRoot.sh]" "root device in fstab is not block device file"
    echo "[overlayRoot.sh]" "try if fstab contains a LABEL definition"
    rootDevFstab="$rootDev"
    rootDev="$( echo "$rootDev" | sed 's/^LABEL=//g' )"
    rootDev="$( blkid -L "$rootDev" )"
    if [ $? -gt 0 ]; then
        echo "[overlayRoot.sh]" "root device in fstab is not partition label"
        echo "[overlayRoot.sh]" "try if fstab contains a PARTUUID definition"
        if ! echo "$rootDevFstab" | grep 'PARTUUID=\(.*\)-\([0-9]\{2\}\)' > /dev/null ; then 
            echo "[overlayRoot.sh]" "root device in fstab is not PARTUUID"
            echo "[overlayRoot.sh]" "try if fstab contains a UUID definition"
            if ! echo "$rootDevFstab" | grep '^UUID=[0-9a-zA-Z-]*$' > /dev/null ; then
                echo "[overlayRoot.sh]" "no success, try if a filesystem with label 'rootfs' is avaialble"
                rootDev="$(blkid -L "rootfs")"
                if [ $? -gt 0 ]; then
                    fail "could not find a root filesystem device in fstab. Make sure that fstab contains a valid device definition for / or that the root filesystem has a label 'rootfs' assigned to it"
                fi
            else
                rootDev="$(blkid -U "$(echo "$rootDevFstab" | sed 's/^UUID=\([0-9a-zA-Z-]*\)$/\1/')")"
                if [ $? -gt 0 ]; then
                    fail "The UUID entry in fstab could not be converted into a valid device name. Make sure that fstab contains a valid device definition for / or that the root filesystem has a label 'rootfs' assigned to it"
                fi
            fi
        else
            echo "[overlayRoot.sh]" "WARNING: The use of PARTUUID in overlayRoot.sh is deprecated. It cannot handle every circumstances."
            device=""
            partition=""
            eval `echo "$rootDevFstab" | sed -e 's/PARTUUID=\(.*\)-\([0-9]\{2\}\)/device=\1;partition=\2/'`
            rootDev=`blkid -t "PTUUID=$device" | awk -F : '{print $1}'`p$(($partition))
            blkid $rootDev
            if [ $? -gt 0 ]; then
                fail "The PARTUUID entry in fstab could not be converted into a valid device name. Make sure that fstab contains a valid device definition for / or that the root filesystem has a label 'rootfs' assigned to it"
            fi
        fi
    fi
fi
mount -t "${rootFsType}" -o "${rootMountOpt},ro" "${rootDev}" /mnt/lower || \
    fail "ERROR: could not ro-mount original root partition"
mount -t overlay -o lowerdir=/mnt/lower,upperdir=/mnt/overlay/upper,workdir=/mnt/overlay/work overlayfs-root /mnt/newroot || \
    fail "ERROR: could not mount overlayFS"
# create mountpoints inside the new root filesystem-overlay
mkdir /mnt/newroot/lower
mkdir /mnt/newroot/overlay
# remove root mount from fstab (this is already a non-permanent modification)
echo "# the original root mount has been removed by overlayRoot.sh" > /mnt/newroot/etc/fstab
echo "# this is only a temporary modification, the original fstab" >> /mnt/newroot/etc/fstab
echo "# stored on the disk can be found in /lower/etc/fstab" >> /mnt/newroot/etc/fstab
grep -v -x -E '^(#.*)|([[:space:]]*)$' /mnt/lower/etc/fstab | awk '$2 != "/" {print}' >> /mnt/newroot/etc/fstab
# change to the new overlay root
cd /mnt/newroot
pivot_root . mnt
exec chroot . sh -c "$(cat <<END
fail(){
        echo -e "[overlayRoot.sh]" "\$1"
        echo "[overlayRoot.sh]" "there is something wrong with overlayRoot.sh. type exit and press enter to ignore and continue."
        if ! /bin/bash ; then
            exit 1
        fi
}
# move ro, rw and other necessary mounts to the new root
mount --move /mnt/mnt/lower/ /lower || \
    fail "ERROR: could not move ro-root into newroot"
mount --move /mnt/mnt/overlay /overlay || \
    fail "ERROR: could not move tempfs rw mount into newroot"
chmod 755 /overlay
mount --move /mnt/proc /proc || \
    fail "ERROR: could not move proc mount into newroot"
mount --move /mnt/dev /dev || true
# unmount unneeded mounts so we can unmout the old readonly root
mount | sed -E -e 's/^.* on //g' -e 's/ type .*\$//g' | grep -x '^/mnt.*\$' | sort -r | while read xx ; do echo -n "\$xx\0" ; done | xargs -0 -t -n 1 umount || \
    fail "ERROR: could not umount old root"
# continue with regular init
exec /sbin/init "\$@"
END
)" "$@"
