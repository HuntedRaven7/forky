kind: script
description: |
  bootc initramfs for the Homelab OS: dracut with the ostree module, built
  from the signed kernel module tree (homelab/kernel-modules.bst) and stored
  back into it as /usr/lib/modules/<kver>/initramfs, where bootc's
  kernel-install picks it up when it assembles the UKI during
  `bootc install to-disk`.

  The generic (non-hostonly) image covers the hardware variety of a homelab
  of laptops: wifi, storage and (optionally later) ZFS dracut modules all
  make it in; bootc and systemd-detect-virt narrow what actually loads.

build-depends:
- base/base-stack.bst
- freedesktop-sdk.bst:public-stacks/runtime-gnu.bst
- freedesktop-sdk.bst:components/dracut.bst
- freedesktop-sdk.bst:components/e2fsprogs.bst
- freedesktop-sdk.bst:components/kmod.bst
# 95ostree, the dracut module that mounts the OSTree/bootc root, ships with
# ostree and must be present for --add ostree.
- freedesktop-sdk.bst:components/ostree.bst
- filename: homelab/kernel-modules.bst
  config:
    location: /kmods

config:
  commands:
  - |
    set -eu
    kver="$(ls /kmods/usr/lib/modules)"
    [ "$(echo "${kver}" | wc -w)" = 1 ]
    mkdir -p "%{install-root}/usr/lib/modules/${kver}"
    dracut \
      --xz --reproducible --no-machineid \
      --kernel-image "/kmods/usr/lib/modules/${kver}/vmlinuz" \
      --kver "${kver}" \
      --add ostree \
      --install 'fsck.ext4' \
      "%{install-root}/usr/lib/modules/${kver}/initramfs"
    test -s "%{install-root}/usr/lib/modules/${kver}/initramfs"
    ls -lh "%{install-root}/usr/lib/modules/${kver}/initramfs"