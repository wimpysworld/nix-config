#!/usr/bin/env python3
"""Refresh the HushMic packaging commit, not the application's source commit."""

import argparse
import base64
import json
import os
import re
import subprocess
import urllib.parse
from pathlib import Path

REPOSITORY = "Fovty/hushmic-nix"
PIN = re.compile(r'hushmic\.url = "github:Fovty/hushmic-nix/([0-9a-f]{40})";')
SEMVER = r"[0-9]+\.[0-9]+\.[0-9]+"


def api(path):
    response = subprocess.run(
        [
            "curl",
            "--fail",
            "--silent",
            "--show-error",
            "--max-time",
            "30",
            f"https://api.github.com/repos/{path}",
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    try:
        return json.loads(response.stdout)
    except json.JSONDecodeError as error:
        raise ValueError("GitHub returned invalid JSON") from error


def package_version(revision):
    contents = api(f"{REPOSITORY}/contents/package.nix?ref={revision}")
    source = base64.b64decode(contents["content"], validate=False).decode()
    versions = re.findall(r'^\s*version = "(' + SEMVER + r')";', source, re.MULTILINE)
    sources = re.findall(
        r"\bsrc = fetchFromGitHub \{([^{}]*(?:\$\{version\}[^{}]*)?)\};", source
    )
    if len(versions) != 1 or len(sources) != 1:
        raise ValueError("Unsupported HushMic package version or source declaration")
    # Accept only the verified upstream source form. Do not infer tag mappings.
    expected = (
        r'\s*owner = "Fovty";\s*repo = "hushmic";\s*'
        r'tag = "v\$\{version\}";\s*hash = "sha256-[A-Za-z0-9+/=]+";\s*'
    )
    if not re.fullmatch(expected, sources[0]):
        raise ValueError(
            "HushMic source declaration changed; review its release mapping"
        )
    return versions[0]


def protected_nodes(lock):
    nodes = lock["nodes"]
    root = nodes[lock["root"]]

    def resolve(edge):
        if isinstance(edge, str):
            return edge
        node = lock["root"]
        for name in edge:
            node = resolve(nodes[node]["inputs"][name])
        return node

    def reachable(starts):
        found = set()
        pending = list(starts)
        while pending:
            node = resolve(pending.pop())
            if node in found:
                continue
            found.add(node)
            pending.extend(nodes[node].get("inputs", {}).values())
        return found

    own = reachable([root["inputs"]["hushmic"]])
    shared = reachable(
        value for key, value in root["inputs"].items() if key != "hushmic"
    )
    return {key: value for key, value in nodes.items() if key not in own - shared}


def validate_lock(before, after, revision):
    if (
        before["root"] != after["root"]
        or before["version"] != after["version"]
        or protected_nodes(before) != protected_nodes(after)
    ):
        raise ValueError(
            "The update changed lock nodes outside HushMic's private dependencies"
        )
    node = after["nodes"][after["nodes"][after["root"]]["inputs"]["hushmic"]]
    for field in ("locked", "original"):
        if any(
            node[field].get(key) != value
            for key, value in {
                "owner": "Fovty",
                "repo": "hushmic-nix",
                "rev": revision,
                "type": "github",
            }.items()
        ):
            raise ValueError("The HushMic lock does not match the packaging commit")


def update(dry_run=False):
    flake = Path("flake.nix")
    lock = Path("flake.lock")
    original_flake = flake.read_text()
    matches = list(PIN.finditer(original_flake))
    if len(matches) != 1:
        raise ValueError("Expected exactly one explicit HushMic packaging commit pin")
    current = matches[0].group(1)
    repository = api(REPOSITORY)
    branch = urllib.parse.quote(repository["default_branch"], safe="")
    latest = api(f"{REPOSITORY}/commits/{branch}")["sha"]
    if not isinstance(latest, str) or not re.fullmatch(r"[0-9a-f]{40}", latest):
        raise ValueError("Invalid HushMic packaging commit")
    if latest == current:
        print("HushMic packaging is up to date")
        return None
    comparison = api(f"{REPOSITORY}/compare/{current}...{latest}")
    if comparison["status"] != "ahead":
        raise ValueError("The packaging commit is not a descendant of the current pin")
    version = package_version(latest)
    previous = package_version(current)
    if tuple(map(int, version.split("."))) < tuple(map(int, previous.split("."))):
        raise ValueError("The packaging commit would downgrade HushMic")
    release = api(f"Fovty/hushmic/releases/tags/v{version}")
    if (
        release["tag_name"] != f"v{version}"
        or release["draft"]
        or release["prerelease"]
    ):
        raise ValueError(
            "The packaging commit does not use a published stable HushMic release"
        )
    print(f"HushMic {version}: packaging {current} -> {latest}")
    if dry_run:
        return None

    original_lock = lock.read_bytes()
    try:
        start, end = matches[0].span(1)
        flake.write_text(original_flake[:start] + latest + original_flake[end:])
        subprocess.run(
            [
                "nix",
                "shell",
                "--inputs-from",
                ".",
                "--no-write-lock-file",
                "nixpkgs#just",
                "--command",
                "just",
                "update",
                "hushmic",
            ],
            check=True,
        )
        validate_lock(json.loads(original_lock), json.loads(lock.read_bytes()), latest)
    except Exception:
        flake.write_text(original_flake)
        lock.write_bytes(original_lock)
        raise
    return f"{version}-{latest[:12]}"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Read upstream metadata without file changes",
    )
    arguments = parser.parse_args()
    output = None if arguments.dry_run else Path(os.environ["GITHUB_OUTPUT"])
    version = update(arguments.dry_run)
    if output is not None:
        with output.open("a") as stream:
            stream.write(
                "updated=false\n"
                if version is None
                else f"updated=true\nversion={version}\nfiles=flake.nix flake.lock\n"
            )


if __name__ == "__main__":
    main()
