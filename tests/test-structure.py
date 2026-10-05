#!/usr/bin/env python3
import json
import os
import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]


def test_compose_contract() -> None:
    env = os.environ | {"OTA_RELEASE_IMAGE": "synthetic:test"}
    rendered = subprocess.run(
        [
            "docker",
            "compose",
            "--project-directory",
            str(ROOT),
            "-f",
            str(ROOT / "compose.yaml"),
            "config",
            "--format",
            "json",
        ],
        check=True,
        capture_output=True,
        text=True,
        env=env,
    )
    config = json.loads(rendered.stdout)
    ota = config["services"]["ota"]
    assert "ports" not in ota
    assert ota["read_only"] is True
    assert ota["cap_drop"] == ["ALL"]
    assert "no-new-privileges:true" in ota["security_opt"]
    assert any(value.startswith("/tmp:") for value in ota["tmpfs"])
    assert ota["networks"]["proxy-net"]["aliases"] == ["ota-server"]
    assert config["networks"]["proxy-net"]["external"] is True
    assert config["networks"]["proxy-net"]["name"] == "proxy-net"


def test_workflow_contract() -> None:
    workflow = (ROOT / ".github/workflows/container.yml").read_text()
    assert re.search(r"(?m)^permissions:\s*\{\}\s*$", workflow)
    assert "pull_request:" in workflow
    assert "packages: write" in workflow
    assert "provenance: mode=max" in workflow
    assert "sbom: true" in workflow
    for action in re.findall(r"(?m)^\s*uses:\s*([^\s#]+)", workflow):
        assert re.fullmatch(r"[^@]+@[0-9a-f]{40}", action), action


if __name__ == "__main__":
    test_compose_contract()
    test_workflow_contract()
    print("OTA configuration contract passed")
