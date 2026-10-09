kind: stack
description: Everything that goes into the Homelab bootc root filesystem.

depends:
  # freedesktop-sdk userspace + signed FSDK kernel modules
  - homelab/os-base.bst

  # bootc runtime and the ostree initramfs
  - homelab/bootc.bst
  - homelab/os-initramfs.bst

  # root filesystem layout and bootc/ostree integration
  - homelab/os-bootc-config.bst
  - homelab/bootc-install-config.bst

  # useradd defaults (home under /var/home) and the wheel sudoers entry
  - freedesktop-sdk.bst:vm/config/useradd-default.bst
  - freedesktop-sdk.bst:vm/config/sudo.bst

  # Image identity
  - homelab/os-release.bst

  # Firmware: full linux-firmware (laptop wifi chipsets), SOF audio, and
  # the wireless regulatory database.
  - freedesktop-sdk.bst:components/linux-firmware.bst
  - freedesktop-sdk.bst:components/sof-firmware.bst
  - freedesktop-sdk.bst:components/wireless-regdb-bin.bst

  # Networking. systemd-networkd/wired configuration for now; NetworkManager
  # + wifi lands in its place (elements/homelab/os-networking.bst).
  - homelab/os-networkd.bst
  - homelab/os-resolved.bst
  - homelab/os-resolv-conf.bst

  # SSH enablement drop-ins (present, off by default)
  - homelab/os-sshd-preset.bst
  - homelab/os-sshd-config.bst

  # First-boot credential provisioning and sysusers drop-ins
  - homelab/os-creds-prov.bst

  # Management conveniences
  - homelab/os-justfile.bst
  - homelab/os-system-container.bst
  - homelab/os-issue.bst
  - homelab/os-prompt.bst