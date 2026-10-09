kind: manual

description: |
  Install first-boot systemd credential provisioning contracts into the target
  OS. Supports sysusers credentials, systemd-network-generator network.*
  credentials, and the firstboot.* credentials (locale, keymap, timezone,
  hostname).

  The systemd-firstboot.service drop-in removes upstream's interactive root
  password prompt: root ships locked, so without it every headless boot would
  wait on the console. The passwd.*.root credentials still apply.

  /usr/libexec/bluefin-firstboot-credentials applies firstboot.* credentials on
  first boot when systemd-firstboot did not run (it writes /etc/locale.conf,
  /etc/vconsole.conf, /etc/localtime) and additionally /etc/hostname plus the
  live kernel hostname from firstboot.hostname.

  /usr/libexec/bluefin-hostname and bluefin-hostname.service run on first boot
  after that: a node whose static hostname is still unset or "localhost" gets
  the firstboot.hostname or system.hostname credential, or else
  bluefin-<first 8 hex of the machine ID>, as its static hostname, so
  appliances on one LAN never share an mDNS name. An invalid provisioned
  hostname fails the unit instead of being replaced.

build-depends:
  - base/base-stack.bst

sources:
  - kind: local
    path: files/os/sysusers.d
    directory: sysusers-src
  - kind: local
    path: files/os/creds/systemd/system
    directory: systemd-src
  - kind: local
    path: files/os/libexec
    directory: libexec-src

# Disable binary stripping; this element only installs text files and the
# runtime-minimal sandbox does not include the stripper toolchain.
variables:
  strip-binaries: ""

config:
  install-commands:
    - |
      set -euo pipefail

      install -Dm0644 sysusers-src/*.conf -t "%{install-root}/usr/lib/sysusers.d/"
      mkdir -p "%{install-root}/usr/lib/systemd/system"
      cp -a systemd-src/. "%{install-root}/usr/lib/systemd/system/"
      install -Dm0755 libexec-src/bluefin-firstboot-credentials \
        "%{install-root}/usr/libexec/bluefin-firstboot-credentials"
      install -Dm0755 libexec-src/bluefin-hostname \
        "%{install-root}/usr/libexec/bluefin-hostname"