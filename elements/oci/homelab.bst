kind: script
description: |
  The Homelab bootc image: layers/os-filesystem.bst run through
  prepare-image.sh (initial scripts, sysusers root entry, systemd presets,
  firstboot locale/timezone), packed as an OCI image labelled
  `containers.bootc: 1` so `bootc install` / `bootc upgrade` / `bootc switch`
  accept it. /etc ships as /usr/share/factory/etc and is materialized by a
  generated tmpfiles.d snippet on first boot; ostree keeps it per deployment.

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
    location: /sysroot

environment:
  LD_PRELOAD: /usr/libexec/fakecap/fakecap.so
  FAKECAP_DB: /fakecap

variables:
  sysroot-seed: 6f1b0fe2-3c2a-4f2e-9f0a-b1e5e7a5e100
  image-repo: homelab

config:
  commands:
  - mkdir -p /fakecap /tmp /var/tmp

  - |
    prepare-image.sh \
      --sysroot /sysroot \
      --initscripts /initial_scripts \
      --seed "%{sysroot-seed}" \
      --noroot --noboot >/dev/null

  - |
    systemd-sysusers --root /sysroot
    # root ships locked as "!unprovisioned" -- the value systemd-firstboot
    # treats as "root not configured", so a passwd.hashed-password.root
    # credential can still provision it; never a password or a usable hash.
    printf 'root:!unprovisioned:0:0:99999:7:::\n' > /sysroot/etc/shadow
    # Empty machine-id: every deployment gets a fresh one.
    : > /sysroot/etc/machine-id
    # Headless: homed-firstboot would block the console asking for a user.
    mkdir -p /sysroot/etc/systemd/system
    ln -sf /dev/null /sysroot/etc/systemd/system/systemd-homed-firstboot.service
    printf 'LANG=C.UTF-8\n' > /sysroot/etc/locale.conf
    ln -sf ../usr/share/zoneinfo/UTC /sysroot/etc/localtime

  - |
    # bootc images must not ship /usr/etc; ostree generates it client-side
    # from /etc at deploy time. If any element staged /usr/etc, fold it in.
    if [ -d /sysroot/usr/etc ]; then
      mkdir -p /sysroot/etc
      cp -a /sysroot/usr/etc/. /sysroot/etc/
      rm -rf /sysroot/usr/etc
    fi

  - |
    set -eu
    factory=/sysroot/usr/share/factory/etc
    rm -rf "${factory}"
    mkdir -p "$(dirname "${factory}")"
    mv /sysroot/etc "${factory}"
    mkdir /sysroot/etc
    conf=/sysroot/usr/lib/tmpfiles.d/00-bluefin-factory-etc.conf
    # Read-only reference data is linked, not copied. C never overwrites,
    # and a disk install keeps /etc across updates, so a copy would stay
    # at the version the node first booted; a link follows /usr. An operator
    # can still replace the link with a file, which L leaves alone.
    # protocols, services: IANA registries (homelab/iana-etc.bst).
    linked='protocols services'
    for entry in ${linked}; do
      test -f "${factory}/${entry}"
    done
    printf 'd /etc 0755 root root -\n' > "${conf}"
    for entry in $(ls -A "${factory}"); do
      if [ -L "${factory}/${entry}" ]; then
        printf 'L /etc/%s - - - - %s\n' "${entry}" "$(readlink "${factory}/${entry}")" >> "${conf}"
      elif printf '%s\n' ${linked} | grep -qxF "${entry}"; then
        printf 'L /etc/%s - - - - ../usr/share/factory/etc/%s\n' "${entry}" "${entry}" >> "${conf}"
      else
        printf 'C /etc/%s - - - - %s\n' "${entry}" "/usr/share/factory/etc/${entry}" >> "${conf}"
      fi
    done
    echo "Factory /etc entries: $(wc -l < "${conf}")"

  - |
    # Rebuild the shared library linker cache for the sysroot. Without this,
    # any SO version bump leaves /etc/ld.so.cache stale after a `bootc switch`.
    ldconfig -r /sysroot -f /sysroot/etc/ld.so.conf

  - |
    cd "%{install-root}"
    build-oci <<EOF
    mode: oci
    gzip: disabled
    images:
    - os: linux
      architecture: "%{go-arch}"
      layer: /sysroot
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