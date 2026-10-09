"""Invariant tests for manual and script element sandbox runtimes.

In FSDK 26.08, runtime-minimal.bst no longer ships /bin/sh. Elements of
kind: manual or kind: script execute commands within their build-time
sandbox and must depend on base/base-stack.bst in build-depends to guarantee
a working shell environment.
"""

from __future__ import annotations

from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
ELEMENTS_DIR = REPO_ROOT / "elements"


def test_manual_and_script_elements_depend_on_base_stack():
    """Ensure all manual/script elements have base/base-stack.bst in build-depends."""
    for bst_path in ELEMENTS_DIR.rglob("*.bst"):
        # Skip external junction declarations
        if bst_path.name == "freedesktop-sdk.bst":
            continue

        content = bst_path.read_text(encoding="utf-8")
        # Quick check for kind
        if "kind: manual" not in content and "kind: script" not in content:
            continue

        data = yaml.safe_load(content)
        if not isinstance(data, dict):
            continue

        kind = data.get("kind")
        if kind in ("manual", "script"):
            build_depends = data.get("build-depends", [])
            dep_names = []
            for dep in build_depends:
                if isinstance(dep, str):
                    dep_names.append(dep)
                elif isinstance(dep, dict) and "filename" in dep:
                    dep_names.append(dep["filename"])

            assert "base/base-stack.bst" in dep_names, (
                f"{bst_path.relative_to(REPO_ROOT)} is kind: {kind} but does not include "
                f"base/base-stack.bst in build-depends"
            )


def test_compose_elements_declare_integration_explicitly():
    """Compose elements must say whether integration commands run.

    Shell-less compositions must set integrate: False (FSDK 26.08
    runtime-minimal has no /bin/sh). Compositions that ship a shell and need
    integration (the ld.so cache, hwdb) opt in with integrate: True.
    """
    for bst_path in ELEMENTS_DIR.rglob("*.bst"):
        if bst_path.name == "freedesktop-sdk.bst":
            continue

        content = bst_path.read_text(encoding="utf-8")
        if "kind: compose" not in content:
            continue

        data = yaml.safe_load(content)
        if not isinstance(data, dict) or data.get("kind") != "compose":
            continue

        config = data.get("config", {})
        assert config.get("integrate") in (True, False), (
            f"{bst_path.relative_to(REPO_ROOT)} is kind: compose but does not set "
            f"'integrate:' explicitly in config"
        )


def test_os_stack_uses_fsdk_base():
    """The OS payload is pure freedesktop-sdk: os-base.bst, no Flatcar imports."""
    os_stack = ELEMENTS_DIR / "homelab" / "os-stack.bst"
    depends = yaml.safe_load(os_stack.read_text(encoding="utf-8")).get("depends", [])
    os_base = ELEMENTS_DIR / "homelab" / "os-base.bst"
    base_depends = yaml.safe_load(os_base.read_text(encoding="utf-8")).get("depends", [])

    assert "homelab/os-base.bst" in depends
    assert "freedesktop-sdk.bst:components/systemd.bst" in base_depends
    assert "homelab/kernel-modules.bst" in base_depends
    for dep in depends + base_depends:
        assert not dep.startswith("flatcar/"), (
            f"OS payload must not import Flatcar binaries ({dep})"
        )



def _build_depends(element):
    data = yaml.safe_load((ELEMENTS_DIR / element).read_text(encoding="utf-8"))
    return {d if isinstance(d, str) else d["filename"] for d in data.get("build-depends", [])}


def test_oci_image_stages_the_filesystem_payload():
    """oci/homelab.bst build-depends the composed payload at a location."""
    deps = _build_depends("oci/homelab.bst")
    assert "homelab/os-filesystem.bst" in deps

