kind: collect_initial_scripts
description: |
  Collect the per-element initial scripts (setuid bits, file capabilities,
  ...) that freedesktop-sdk components declare, for oci/homelab.bst.

build-depends:
- homelab/os-stack.bst

config:
  path: /etc/fdsdk/initial_scripts
