# List available commands
[group('info')]
default:
    @just --list

# Same bst2 container image FSDK/dakota CI uses -- pinned by commit-named tag.
export bst2_image := env("BST2_IMAGE", "registry.gitlab.com/freedesktop-sdk/infrastructure/freedesktop-sdk-docker-images/bst2:1775c49af80653f9cd86cbc92761eae4ab95204e")
# bats for `just test-unit` when none is installed -- pinned by digest.
export bats_image := env("BATS_IMAGE", "docker.io/bats/bats:1.14.0@sha256:5322b877351fda0cc435de8c6116de7d0a2ec79d7c680132a0ef329a633bc66f")

# Prefix for podman calls: empty when rootless podman works, "sudo" otherwise.
sudo_cmd := if `podman info >/dev/null 2>&1 && echo 1 || echo 0` == "1" { "" } else { "sudo" }

# FSDK point release of the pinned junction ref, e.g. "26.08.0".
export fsdk_version := `python3 .github/scripts/check-release-version.py --print-fsdk`
# Exact junction commit ref (full ref: value), for provenance.
export fsdk_ref := `grep -E '^\s*ref:' elements/freedesktop-sdk.bst | head -1 | sed -E 's/^\s*ref:\s*//'`

# -- BuildStream wrapper ------------------------------------------------------
# Runs any bst command inside the bst2 container via podman.
# Baseline x86_64 (no x86_64_v3) so the base image runs on the widest CPU set.
[group('dev')]
bst *ARGS:
    #!/usr/bin/env bash
    set -euo pipefail
    export CONTAINERS_CONF="${CONTAINERS_CONF:-/dev/null}"
    export CONTAINERS_CONF_OVERRIDE="${CONTAINERS_CONF_OVERRIDE:-/dev/null}"
    mkdir -p "${HOME}/.cache/buildstream"
    # On systemd-resolved hosts /etc/resolv.conf may name a stub or VPN
    # resolver that only the host's NSS path can use; hand the container the
    # real upstream list instead.
    resolv_args=()
    if [ -s /run/systemd/resolve/resolv.conf ]; then
        resolv_args=(-v /run/systemd/resolve/resolv.conf:/etc/resolv.conf:ro)
    fi
    # shellcheck disable=SC2086
    {{sudo_cmd}} podman run --rm \
        --privileged \
        --device /dev/fuse \
        --network=host \
        "${resolv_args[@]}" \
        -v "{{justfile_directory()}}:/src:rw" \
        -v "${HOME}/.cache/buildstream:/root/.cache/buildstream:rw" \
        -w /src \
        "{{bst2_image}}" \
        bash -c 'bst --colors "$@"' -- --no-interactive --error-lines 500 ${BST_FLAGS:-} {{ARGS}}

# Print the FSDK-derived point release used for asset versioning.
[group('info')]
version:
    @echo "{{fsdk_version}}"

# Print the tag set derived from the FSDK release: latest, minor line, point release.
[group('info')]
tags:
    #!/usr/bin/env bash
    set -euo pipefail
    V="{{fsdk_version}}"
    MINOR="$(echo "$V" | cut -d. -f1,2)"
    printf '%s\n%s\n%s\n' latest "$MINOR" "$V"

# ── Validate ──
# Version-invariant checks + resolve the shipped element graph.
[group('dev')]
validate: gen-dev-keys
    python3 .github/scripts/check-release-version.py
    python3 .github/scripts/check-renovate-series.py
    just bst show --deps all oci/homelab.bst

# Run the unit test suite (pytest + bats; bats from a container if not installed).
[group('dev')]
test-unit:
    #!/usr/bin/env bash
    set -euo pipefail
    python3 -m pytest tests/unit -q
    if command -v bats >/dev/null 2>&1; then
        exec bats tests/unit
    fi
    echo "==> bats is not installed; running it from ${bats_image}" >&2
    exec {{sudo_cmd}} podman run --rm --security-opt label=disable -e CI \
        -v "{{justfile_directory()}}:/code:ro" -w /code "${bats_image}" tests/unit

# Lint the Python (ruff) and type-check the scripts (mypy), as the unit-tests workflow does.
[group('dev')]
lint-python:
    python3 -m ruff check
    python3 -m mypy

# ── Build ─────────────────────────────────────────────────────────────
# Generate local Secure Boot + module signing keys in files/boot-keys/.
[group('bootc')]
gen-dev-keys *ARGS:
    bash scripts/gen-dev-keys.sh {{ARGS}}

# Build the bootc OCI image.
[group('bootc')]
build-image: gen-dev-keys
    just bst build oci/homelab.bst

# Export the OCI layout (default: dist/oci/).
[group('bootc')]
export-image OUT="dist/oci": build-image
    rm -rf {{OUT}}
    just bst artifact checkout oci/homelab.bst --directory /src/{{OUT}}
    @echo "==> wrote OCI layout:" && find {{OUT}} -maxdepth 3 -type f | sort | head

# Set the image version in include/image.yml; it must increase under
# strverscmp() (CI uses YY.MM.<run number>).
[group('bootc')]
set-version VERSION:
    #!/usr/bin/env bash
    set -euo pipefail
    [[ "{{VERSION}}" =~ ^[0-9][0-9A-Za-z.]{0,16}$ ]] || { echo "invalid version (digits/letters/dots, at most 17 chars): {{VERSION}}" >&2; exit 1; }
    sed -i 's/^  image-version: .*/  image-version: "{{VERSION}}"/' include/image.yml
    grep image-version include/image.yml