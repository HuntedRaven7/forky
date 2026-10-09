kind: manual
description: |
  Homelab os-release and image identity. IMAGE_ID/IMAGE_VERSION identify the
  image to bootc and the container tooling; the image-info.json mirrors the
  bootc ref so the countme/uboot tooling of the wider family (if adopted)
  can identify the running stream.

(@):
- include/arch.yml
- include/image.yml

build-depends:
- base/base-stack.bst

variables:
  strip-binaries: ""

config:
  install-commands:
  - mkdir -p "%{install-root}%{indep-libdir}" "%{install-root}%{sysconfdir}" "%{install-root}%{datadir}/ublue-os"
  - |
    cat <<EOF > "%{install-root}%{indep-libdir}/os-release"
    NAME="Homelab"
    ID=homelab
    VERSION="%{image-version}"
    VERSION_ID=%{image-version}
    PRETTY_NAME="Homelab %{image-version}"
    IMAGE_ID=homelab
    IMAGE_VERSION=%{image-version}
    ARCHITECTURE=%{systemd-arch}
    DEFAULT_HOSTNAME=homelab
    IMAGE_NAME=homelab
    IMAGE_VENDOR=huntedraven7
    IMAGE_REF=ostree-image-signed:docker://ghcr.io/huntedraven7/homelab
    IMAGE_FLAVOR=main
    IMAGE_TAG=latest
    ANSI_COLOR="0;38;5;33"
    HOME_URL="https://github.com/huntedraven7/forky"
    BUG_REPORT_URL="https://github.com/huntedraven7/forky/issues"
    EOF
    ln -sf ../usr/lib/os-release "%{install-root}%{sysconfdir}/os-release"
  - |
    cat >"%{install-root}%{datadir}/ublue-os/image-info.json" <<'JSON'
    {
      "image-name": "homelab",
      "image-ref": "ostree-image-signed:docker://ghcr.io/huntedraven7/homelab",
      "image-flavor": "main",
      "image-vendor": "huntedraven7",
      "image-tag": "latest"
    }
    JSON