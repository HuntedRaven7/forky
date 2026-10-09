# Handoff: what's next for the forky (homelab) fork

Repo: `git@github.com:HuntedRaven7/forky.git`, branch `main`, remote `origin`.

Fork goal: turn `projectbluefin/server` into `huntedraven7/homelab` — a single
bootc OCI image (`ghcr.io/huntedraven7/homelab`) built with BuildStream from
freedesktop-sdk 26.08, headless, x86_64 only, no k0s/kubeadm/ZFS/NVIDIA sysexts,
no sysupdate A/B / DDI / netboot / USB installer.

## State as of last session (all local gates green)

- Two commits on `main`: `07151db` (fork bootstrap) and `7b481e3` (contract fixes).
- `just validate` passes; 313 unit tests pass; `ruff`, `mypy`, `docs-checks.py` pass.
- `homelab/os-sshd-preset.bst` builds (the only element we built).
- Nothing pushed yet — this machine has no GitHub auth.

## 1. Immediate blocker: get the tree to GitHub so CI can build

CI build is the agreed path (do not build locally). Push is blocked:

```
git push origin main
# -> Permission denied (publickey)
gh auth status
# -> not logged in
```

Unblock with any one of:
1. Load an SSH key: `eval "$(ssh-agent -s)" && ssh-add ~/.ssh/<key>` then push.
2. `gh auth login` on this machine, then push.
3. Push from another machine: add the remote there, push `main`.

Then the `build.yml` workflow runs on `main`: `changes` → `validate` → `build`
(runs `just build-image` first runner; downloads the rest) → on success
`release` pushes `ghcr.io/<owner>/homelab` with tags `<version>`, `testing`,
`latest`. `nightly-status` opens a tracking issue on schedule-only failures.

## 2. After the first CI run

- Watch the `build` job. First real build compiles most of FSDK (~hours).
- Debug CI failures as they appear — we never built `oci/homelab.bst` end to
  end, so expect surprises in the final assembly step.
- Known-but-unverifiable-remotely: release job needs `packages: write` on the
  org/package — if the push is denied, grant write to the `homelab` ghcr
  package or the repo.

## 3. Local commands (when you're back at a machine with BuildStream)

```
export PATH="$HOME/.cargo/bin:$PATH"        # just is here, not on PATH
just validate                                # merge-contract graph check
/tmp/opencode/venv-tests/bin/pytest tests/unit -q      # or: just test-unit
/tmp/opencode/venv-tests/bin/python3 -m ruff check
/tmp/opencode/venv-tests/bin/python3 -m mypy
python3 .github/scripts/docs-checks.py
just bst build homelab/os-sshd-preset.bst   # single-element smoke build
```

Note: `just lint-python`/`just test-unit` use the system `python3`, which has no
`ruff`/`mypy`/`pytest` here; the venv at `/tmp/opencode/venv-tests` has the
pinned `.github/requirements-ci.txt`.

## 4. Milestones (in order)

- **M0 — bootc CI image exists** (current milestone): green `build.yml`,
  `oci/homelab.bst` assembles, `ghcr.io/huntedraven7/homelab` is pushable and
  `bootc install`-able. Verified via `just build-image`/CI artifacts and a
  manual `bootc install to-disk` in QEMU.
- **M1 — in-repo Ubuntu LTS kernel**: replace the FSDK kernel in
  `elements/homelab/kernel-modules.bst` (or `os-base.bst`) with an Ubuntu LTS
  kernel built from `include/aliases.yml` (`kernel_pub` src exists). When done,
  drop `patches/freedesktop-sdk/0006-linux-kubernetes-cilium-networking.patch`
  (its k8s options shipped in the Ubuntu config).
- **M2 — NetworkManager + WiFi**: replace the `systemd-networkd` stack
  (`os-networkd.bst`, `20-wired.network`, `80-bluefin-networkd.preset`) with
  NetworkManager (FSDK `components/network-manager.bst` exists), enable
  `NetworkManager-wait-online` / wifi via systemd presets; update
  `os-issue`/docs. This is the homelab-laptops raison d'être.
- **M3 — Secure Boot + bootc install dogfood**: real SB keys, signed bootchain,
  `bootc install to-disk` + rollback in QEMU. Reintroduce `homelab/keys/efi-keys.bst`
  signing flow and the release-signing secrets (`just gen-dev-keys` for dev keys;
  `files/dev-keys/INSECURE-*` stay committed for dev builds).

## 5. Peripheral cleanup (anytime, low risk)

- Decommission stale docs/skills that describe removed subsystems
  (sysupdate, DDI/installer, kubeadm, k0s, nvidia, homelab-profile, index.md
  table rows). WARN-only line-length overflows will vanish with them.
- Rename `files/os/ssh/sshd_config.d/bluefin-server.conf` → `homelab.conf` (and
  `os-sshd-config.bst` reference).
- Drop dead host-only leftovers: `Formula/bluefin-kubestellar.rb`,
  `files/bin/bluefin-kubestellar`, `docs/MVP_1_0_READINESS.md` (or rewrite for
  bootc), `docs/skills/architecture-roadmap.md` references to removed items.
- `elements/homelab/keys/efi-keys.bst` is only used by reproducibility gating;
  keep until M3.
- Revisit `include/image.yml` versioning: `image-version: "26.09.2"` is
  hardcoded; the CI build job overrides via `just set-version YY.MM.<run#>`.

## 6. Gotchas discovered (do not regress)

- Base-stack-only `manual`/`script` elements must set `strip-binaries: ""` —
  the runtime-minimal sandbox has no `freedesktop-sdk-stripper`. Build stacks
  (`buildsystem-make`/`autotools`) provide it via `components/stripper.bst`.
- `oci/homelab.bst` runs at `/sysroot` (tests literal-match `/sysroot` strings)
  and ends by moving `/etc` into `/usr/share/factory/etc`, generating one
  tmpfiles.d line per entry (L for `protocols`/`services`/symlinks, C otherwise).
- Tests run the factory generator on a fake sysroot by substituting `/sysroot`;
  keep that literal path if you change the element.
- `tests/unit/test_reproducibility_workflow.py` derives the shipped set from
  the build; `reproducibility.yml` `FINAL_ASSEMBLY` must list
  `oci/homelab.bst` **and** `homelab/os-filesystem.bst` (the located payload).
- Element test suite uses `git ls-files` — the git-ls-files-dependent tests
  only pass on a committed tree.