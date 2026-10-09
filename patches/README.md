# freedesktop-sdk patches

Patches under `freedesktop-sdk/` are applied via `fdsdk-config.sh` on top of
the pinned FSDK junction (`elements/freedesktop-sdk.bst`). Each patch must be
rechecked on every FSDK refresh (`just validate` fails when a patch no longer
applies); see `docs/skills/bump-fsdk-version.md`.

## 0001-project.conf-Add-GNOME-CAS-servers.patch

Lets BuildStream fetch sources through the GNOME Content Addressable Store
(CAS) instead of `git://`/direct HTTPS when a junction pins a CAS ref. Keep
while FSDK component sources may come from GNOME's infrastructure.

## 0006-linux-kubernetes-cilium-networking.patch

Kernel config for the Cilium/Kubernetes datapath (VXLAN/GENEVE tunnels, tc
BPF, conntrack(8) and ss(8) socket diagnostics) appended to
`files/linux/fdsdk-config.sh`. Retained from the projectbluefin/server fork
whose k0s/kubeadm sysexts required it; the fork ships no Kubernetes payload,
so this patch is a candidate for removal at the next FSDK refresh (or when
M1 replaces the FSDK kernel with an Ubuntu LTS kernel, which carries these
options).

## 0007-linux-watchdog.patch

Enables the hardware watchdog core and common watchdog drivers in the same
`fdsdk-config.sh`, so `systemd` can arm `/dev/watchdog0` on bare-metal
homelab nodes. Appended below `0006`; refresh in order, `0006` before `0007`.