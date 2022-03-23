# overlayRoot.sh
Read-only Root-FS for most Linux distributions using OverlayFS. Just like the package `overlayroot` in Ubuntu but it will work on almost all distributions.

Forked from: https://wiki.psuter.ch/doku.php?id=solve_raspbian_sd_card_corruption_issues_with_read-only_mounted_root_partition

# Installation
1. Move this script to /sbin/overlayRoot.sh or other location you want.
2. `chmod +x /sbin/overlayRoot.sh`
3. Change your boot parameter. Add/Modify `init=/sbin/init` to `init=/sbin/overlayRoot.sh`.
4. Reboot and enjoy.

# What does it actually do
In general, the script will mount a OverlayFS over the original root file system using tmpfs as upper layer.
1. Get all useful rootfs information from `/etc/fstab`.
2. Mount a tmpfs at `/mnt/overlay`, create `/mnt/overlay/upper`, `/mnt/overlay/work`, `/mnt/overlay/newroot`.
3. Bind mount rootfs to `/mnt/lower`.
4. Mount OverlayFS using `/mnt/lower` as lower, `/mnt/overlay/upper` and `/mnt/overlay/work` as upper and work directory, `/mnt/overlay/newroot` as merged destination.
5. `pivot_root` to `/mnt/overlay/newroot` and put old root to `/mnt`.
6. Move mount point `/mnt/mnt/lower`(the original `/mnt/lower`) to `/lower`, `/mnt/mnt/overlay`(the original `/mnt/overlay`) to `/overlay`.
7. Move all other useful virtual filesystems like procfs or devfs to new root.
8. Unmount `/mnt`(the original root file system).
9. Exec `/sbin/init` and continue the init process.

# Compatibility
The upstream project is only compatible with Raspbian and has not been updated for years. Thus I add some patches to make it work on almost all Linux distributions.
## It has been tested that it works on:
- Systemd
- OpenRC
- Raspbian
- Armbian
- ArchLinux
# Notice
- Do all actions in Installation part with root permissions.
- To temporary disable overlayRoot.sh, add `noOverlayRoot` to your kernel parameter.
- Double-check your `/etc/fstab`, this script will get rootfs mount point information from it. only UUID, PARTUUID, LABLE and raw device is supported but use PARTUUID remain not recommended.
- If you use this script and stuck at the emergency shell or something similar, change your boot parameter back.
- Some distribution is extremely Non-POSIX during init (such as Nix OS). Do not use this script.
# Troubleshooting/FAQ
- Failed on some distributions whose init executable is not `/sbin/init`.
> FIX: Simply replace all `/sbin/init` in this script to the value of your distribution use (for example: `sed -i 's|/sbin/init|/init|g' overlayRoot.sh`).
- Failed on some distributions doesn't have `/etc/fstab` or doesn't have it during the very early stage of init.
> FIX: Manually add rootfs mount information in your `/etc/fstab`.
- Failed on some kernel that not support OverlayFS.
> FIX: Use another kernel. Change distribution. etc...
- Failed on some distributions call main init executable (like systemd/openrc/sysv) in initramfs.
> FIX: Move this script to initramfs.
- More questions?
> Ask me on Issues or Discussions.
