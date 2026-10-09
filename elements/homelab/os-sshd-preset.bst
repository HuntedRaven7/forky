kind: manual
description: |
  Install systemd presets ensuring sshd is present but off by default, plus
  the ssh-host-keygen unit and the drop-ins wiring its per-ed25519/keypair
  generation into socket activation (sshd.present -> sshd-generated@).

build-depends:
  - base/base-stack.bst

sources:
  - kind: local
    path: files/os/systemd/system-preset
    directory: system-preset-src
  - kind: local
    path: files/os/systemd/system/ssh-host-keygen.service
    directory: keygen-unit-src
  - kind: local
    path: files/os/systemd/system/sshd.service.d
    directory: sshd-dropin-src
  - kind: local
    path: files/os/systemd/system/sshd-generated@.service.d
    directory: sshd-generated-dropin-src

config:
  install-commands:
    - |
      set -euo pipefail
      install -Dm0644 system-preset-src/*.preset \
        -t "%{install-root}/usr/lib/systemd/system-preset/"
      install -Dm0644 keygen-unit-src/ssh-host-keygen.service \
        "%{install-root}/usr/lib/systemd/system/ssh-host-keygen.service"
      install -Dm0644 sshd-dropin-src/10-host-keygen.conf \
        "%{install-root}/usr/lib/systemd/system/sshd.service.d/10-host-keygen.conf"
      install -Dm0644 sshd-generated-dropin-src/10-host-keygen.conf \
        "%{install-root}/usr/lib/systemd/system/sshd-generated@.service.d/10-host-keygen.conf"
