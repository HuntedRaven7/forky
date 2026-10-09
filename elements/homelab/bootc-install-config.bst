kind: manual
description: |
  bootc install defaults: systemd-boot as the bootloader and an xfs root.
  bootc no longer defaults the root filesystem type, so without this
  `bootc install to-disk` fails with "No root filesystem specified".

build-depends:
- base/base-stack.bst

sources:
- kind: local
  path: files/bootc-install

variables:
  strip-binaries: ""

config:
  install-commands:
  - install -Dm644 00-defaults.toml "%{install-root}/usr/lib/bootc/install/00-defaults.toml"