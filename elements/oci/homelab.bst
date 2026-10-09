kind: script
description: |
  The Homelab bootc image: layers/os-filesystem.bst run through
  prepare-image.sh (initial scripts, sysusers root entry, systemd presets,
  firstboot locale/timezone), packed as an OCI image labelled
  `containers.bootc: 1` so `bootc install` / `bootc upgrade` / `bootc switch`
  accept it. The /etc produced here ships in the image; ostree keeps it per
  deployment.

(@):
- include/arch.yml
- include/image.yml

build-depends:
- base/base-stack.bst
- freedesktop-sdk.bst:components/fakecap.bst
- freedesktop-sdk.bst:components/oci-builder.bst
- freedesktop-sdk.bst:vm/prepare-image.bst
- homelab/os-initial-scripts.bst
- filename: homelab/os-filesystem.bst
  config:
    location: /layer

environment:
  LD_PRELOAD: /usr/libexec/fakecap/fakecap.so
  FAKECAP_DB: /fakecap

variables:
  sysroot-seed: 6f1b0fe2-3c2a-4f2e-9f0a-b1e5e7a5e100
  image-repo: homelab

config:
  commands:
  - mkdir /fakecap

  - |
    prepare-image.sh \
      --sysroot /layer \
      --initscripts /initial_scripts \
      --seed "%{sysroot-seed}" \
      --noroot --noboot >/dev/null

  - |
    systemd-sysusers --root /layer
    # root ships locked as "!unprovisioned" -- the value systemd-firstboot
    # treats as "root not configured", so a passwd.hashed-password.root
    # credential can still provision it; never a password or a usable hash.
    printf 'root:!unprovisioned:0:0:99999:7:::\n' > /layer/etc/shadow
    # Empty machine-id: every deployment gets a fresh one.
    : > /layer/etc/machine-id
    # Headless: homed-firstboot would block the console asking for a user.
    mkdir -p /layer/etc/systemd/system
    ln -sf /dev/null /layer/etc/systemd/system/systemd-homed-firstboot.service

  - |
    # bootc images must not ship /usr/etc; ostree generates it client-side
    # from /etc at deploy time. If any element staged /usr/etc, fold it in.
    if [ -d /layer/usr/etc ]; then
      mkdir -p /layer/etc
      cp -a /layer/usr/etc/. /layer/etc/
      rm -rf /layer/usr/etc
    fi

  - |
    # Rebuild the shared library linker cache for the sysroot. Without this,
    # any SO version bump leaves /etc/ld.so.cache stale after a `bootc switch`.
    ldconfig -r /layer -f /layer/etc/ld.so.conf

  - |
    cd "%{install-root}"
    build-oci <<EOF
    mode: oci
    gzip: disabled
    images:
    - os: linux
      architecture: "%{go-arch}"
      layer: /layer
      comment: "Import Homelab layer"
      config:
        Labels:
          'org.opencontainers.image.title': 'Homelab'
          'org.opencontainers.image.description': 'A headless bootc homelab OS for laptops'
          'org.opencontainers.image.vendor': 'HuntedRaven7'
          'org.opencontainers.image.licenses': 'Apache-2.0'
          'org.opencontainers.image.source': 'https://github.com/huntedraven7/forky'
          'containers.bootc': '1'
    index-annotations:
      'org.opencontainers.image.ref.name': 'ghcr.io/huntedraven7/%{image-repo}:latest'
    EOF