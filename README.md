# overlayRoot.sh
Read-only Root-FS for most Linux distributions using OverlayFS. Just like the package `overlayroot` in Ubuntu but it will work on almost all distributions.

Forked from: https://wiki.psuter.ch/doku.php?id=solve_raspbian_sd_card_corruption_issues_with_read-only_mounted_root_partition

# Installation
1. Move this script to /sbin/overlayRoot.sh or other location you want.
2. `chmod +x /sbin/overlayRoot.sh`
3. Change your boot parameter. Add/Modify `init=/sbin/init` to `init=/sbin/overlayRoot.sh`.
4. Reboot and enjoy.

# What does it actually do
In general, the script will mount a OverlayFS over the original root file system using tmpfs as upper layer. It first get all useful rootfs information from `/etc/fstab`. Then mount a tmpfs at `/mnt/overlay`, create `/mnt/overlay/upper`, `/mnt/overlay/work`, `/mnt/overlay/newroot`. Bind mount rootfs to `/mnt/lower`. Mount OverlayFS using `/mnt/lower` as lower, `/mnt/overlay/upper` and `/mnt/overlay/work` as upper and work directory, `/mnt/overlay/newroot` as merged destination. `pivot_root` to `/mnt/overlay/newroot` and put old root to `/mnt`. Move mount point `/mnt/mnt/lower`(the original `/mnt/lower`) to `/lower`, `/mnt/mnt/overlay`(the original `/mnt/overlay`) to `/overlay`. Move all other useful virtual filesystems like procfs or devfs to new root. Unmount `/mnt`(the original root file system). Finally, exec `/sbin/init` and continue the init process.

# Compatibility
The upstream project is only compatible with Raspbian and has not been updated for years. Thus I add some patches to make it work on almost all Linux distributions.
## It has been tested that it works on:
1. Systemd
2. OpenRC
3. Raspbian
4. Armbian
5. ArchLinux
## However there still may have some points to notice:
1. Do all actions in Installation part with root permissions.
2. To temporary disable overlayRoot.sh, add `noOverlayRoot` to your kernel parameter.
3. Double-check your `/etc/fstab`, this script will get rootfs mount point information from it. only UUID, PARTUUID, LABLE and raw device is supported but use PARTUUID remain not recommended.
4. If you use this script and stuck at the emergency shell or something similar, change your boot parameter back.
5. Some distribution is extremely Non-POSIX during init (such as Nix OS). Do not use this script.
## The script will stop working:
1. On some distributions whose init executable is not `/sbin/init`.
2. On some distributions doesn't have `/etc/fstab` or doesn't have it during the very early stage of init.
3. On some kernel that not support OverlayFS.
4. On some distributions call main init executable (like systemd/openrc/sysv) in initramfs.
## To fix the above problem:
1. You can simply replace all `/sbin/init` to the value your distribution use in the script (for example: `sed -i 's|/sbin/init|/init|g' overlayRoot.sh`).
2. Manually add rootfs mount information in your `/etc/fstab`.
3. Use another kernel. Change distribution. etc...
4. Move this script to initramfs.
