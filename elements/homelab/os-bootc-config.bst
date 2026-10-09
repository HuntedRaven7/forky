kind: manual
description: |
  bootc/OSTree integration in the image.

  - /usr/lib/ostree/prepare-root.conf: enable composefs and mount the
    sysroot read-only, matching the composefs backend bootc installs.
  - /usr/lib/tmpfiles.d/10-bootc.conf: /var subdirectories for the symlinked
    mount points below (home, roothome, opt, ...).
  - The /boot, /run and /sysroot top-levels plus the /ostree and /var
    symlinks bootc's layered fs layout expects; /boot must stay empty in the
    image (bootc install writes the bootloader there).

build-depends:
- base/base-stack.bst

sources:
- kind: local
  path: files/oci

variables:
  strip-binaries: ""

config:
  install-commands:
  - install -Dm644 prepare-root.conf "%{install-root}%{indep-libdir}/ostree/prepare-root.conf"
  - install -Dm644 10-bootc.conf "%{install-root}%{indep-libdir}/tmpfiles.d/10-bootc.conf"

  # Directory skeleton and symlinks bootc images need. Let the compose step
  # decide ownership: elements never ship content at these paths.
  - |
    set -eu
    for d in boot run sysroot sysroot/ostree; do
      mkdir -p "%{install-root}/${d}"
    done
    ln -s sysroot/ostree "%{install-root}/ostree"
    for link in home root opt mnt srv; do
      ln -s "var/${link}" "%{install-root}/${link}"
    done
    ln -s ../var/usrlocal "%{install-root}/usr/local"
    ln -s run/media "%{install-root}/media"